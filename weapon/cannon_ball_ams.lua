-- Which slot's cannons to use.
amsWeaponSlot = 5

-- Azimuth limits in degrees. Neutral direction is determined by which quarter the cannon falls in when an "X" is drawn on the bounding box from above.
-- Note that these apply to aiming and only aiming.
-- If you want a turret to not even turn behind itself you will need to set the field of fire restriction on the turret itself.
azimuthLimits = {
    forward = 180,
    back = 180,
    right = 180,
    left = 180,
}

-- What offset (m) to consider firing weapon, where 0 is (hopefully) a direct hit.
-- Recommended to set this high enough so every warning gets a few frames in range.
-- But limit fire rate on the cannon so that the cannon only fires once per warning.
minFireOffset = -5.0
maxFireOffset = 5.0
maxFireDeviation = 5.0

-- Length of the barrel (m).
barrelLength = 6.0

-- Timed fuse length (s).
fuseTime = 1
-- Extra time (s) to lead the target.
extraLeadTime = 0.02
totalLeadTime = fuseTime + extraLeadTime

-- How much time (s) to wait before returning to neutral.
resetTime = 30

-- Minimum lateral acceleration (m/s^2) to consider warning to be turning in a circle.
minCircularAcceleration = 50 -- 2 * maxFireDeviation / totalLeadTime / totalLeadTime
-- Minimum angle (deg) away from aiming at us to consider warning to be turning in a circle.
minCircularDeflection = 15

-- Gravity, and drop after the fuse time.
g = 9.81
gravityAdjustment = Vector3(0.0, 0.5 * fuseTime * fuseTime * g, 0.0) 

-- The I in Update(I).
I = nil

-- Timestamp of the current frame.
frameTimestamp = 0
-- Duration of the last frame.
frameDuration = 1/40
-- Timestamp to reset to neutral.
resetTimestamp = resetTime

myPosition = Vector3.zero
myVelocity = Vector3.zero
myMinDimensions = Vector3.one
myMaxDimensions = Vector3.one
myBoxLocalCenter = Vector3.zero
myBoxSize = Vector3.one

myVectors = {
    x = Vector3.right,
    y = Vector3.up,
    z = Vector3.forward,
}

-- Table of known enemy missiles. Id -> warning.
warnings = {}
-- Table for previous frame. Id -> warning.
previousWarnings = {}

-- Position to aim at each warning. Index -> aim position.
warningAims = {}

-- Weapon speed and range for computing turret lead.
turretWeaponSpeed = 150
turretWeaponRange = 150

WEAPON_TYPE_CANNON = 0
WEAPON_TYPE_TURRET = 4

function Update(Iarg)
    I = Iarg
    UpdateInfo()
    
    for weaponIndex = 0, I:GetWeaponCount() - 1 do
        local weapon = I:GetWeaponInfo(weaponIndex)
        if weapon.WeaponType == WEAPON_TYPE_TURRET and weapon.WeaponSlot == amsWeaponSlot then
            -- LogBoth(string.format("Weapon position %d: %s", weaponIndex, tostring(weapon.LocalPosition)))
            AimTurret(weaponIndex, weapon)
        end
    end

    for turretSpinnerIndex = 0, I:GetTurretSpinnerCount() - 1 do
        for weaponIndex = 0, I:GetWeaponCountOnTurretOrSpinner(turretSpinnerIndex) do
            local weapon = I:GetWeaponInfoOnTurretOrSpinner(turretSpinnerIndex, weaponIndex)
            if weapon.WeaponType == WEAPON_TYPE_CANNON and weapon.WeaponSlot == amsWeaponSlot then
                MaybeFireCannon(turretSpinnerIndex, weaponIndex, weapon)
            end
        end
    end
end

-- Called first. This updates the warning tables and other info.
function UpdateInfo()
    local newframeTimestamp = I:GetGameTime()
    frameDuration = newframeTimestamp - frameTimestamp
    frameTimestamp = newframeTimestamp
    
    myPosition = I:GetConstructPosition()
    myVelocity = I:GetVelocityVector()
    
    myVectors.x = I:GetConstructRightVector()
    myVectors.y = I:GetConstructUpVector()
    myVectors.z = I:GetConstructForwardVector()
    
    local myMinDimensions = I:GetConstructMinDimensions()
    local myMaxDimensions = I:GetConstructMaxDimensions()
    
    myBoxLocalCenter = (myMinDimensions + myMaxDimensions) / 2
    myBoxSize = myMaxDimensions - myMinDimensions
    
    previousWarnings = warnings
    warnings = {}
    warningAims = {}
    for mainframeIndex = 0, I:GetNumberOfMainframes() - 1 do
        local numberOfWarnings = I:GetNumberOfWarnings(mainframeIndex)
        if numberOfWarnings > 0 then
            resetTimestamp = frameTimestamp + resetTime
            -- I:Log(tostring(numberOfWarnings))
            for warningIndex1 = 1, numberOfWarnings do
                local warning = I:GetMissileWarning(mainframeIndex, warningIndex1 - 1)
                warnings[warning.Id] = warning
                warningAims[warningIndex1] = WarningAim(warning)
            end
            interceptorMainframeIndex = mainframeIndex
            return
        end
    end
end

-- Determines the (global) position to aim at a warning after the fuse time, accounting for movement and gravity.
function WarningAim(warning)
    local previousWarning = previousWarnings[warning.Id]
    -- Decide whether to use circular prediction.
    if previousWarning ~= nil and not IsComingRightForUs(warning) then
        local acceleration = (warning.Velocity - previousWarning.Velocity) / frameDuration
        local lateralAcceleration = Vector3.ProjectOnPlane(acceleration, warning.Velocity)
        --LogBoth(string.format("Lateral acceleration: %f", lateralAcceleration.magnitude))
        if lateralAcceleration.magnitude > minCircularAcceleration then
            -- Vector from current position to center of turn.
            local radius = lateralAcceleration * warning.Velocity.sqrMagnitude / acceleration.sqrMagnitude
            -- LogBoth(string.format("Radius: %s", tostring(radius.magnitude)))
            local center = warning.Position + radius
            local turnAngle = warning.Velocity.magnitude / radius.magnitude * totalLeadTime
            local turnPosition = center - radius * math.cos(turnAngle) + (warning.Velocity.normalized * radius.magnitude) * math.sin(turnAngle)
            local leadPosition = turnPosition - myVelocity * totalLeadTime
            local aimPosition = leadPosition + gravityAdjustment
            return aimPosition
        end
    end
    -- Fallthrough: use linear prediction.
    local relativeVelocity = warning.Velocity - myVelocity
    local leadPosition = warning.Position + relativeVelocity * totalLeadTime
    local aimPosition = leadPosition + gravityAdjustment
    return aimPosition
end

function IsComingRightForUs(warning)
    return Vector3.Dot(warning.Velocity.normalized, (myPosition - warning.Position).normalized) > math.cos(math.rad(minCircularDeflection))
end

-- Aim turret at the nearest warning aim position that isn't below minimum range.
function AimTurret(weaponIndex, weapon)
    local neutralAim, azimuthLimitCos = GetNeutralAimInfo(weapon)
    -- LogBoth(string.format("Neutral aim %d: %s", weaponIndex, tostring(neutralAim)))
    local bestOffset = 10000
    local bestAim = nil
    for _, warningAim in ipairs(warningAims) do
        local offset = Vector3.Distance(weapon.GlobalPosition, warningAim) - barrelLength - turretWeaponRange
        if offset < bestOffset and offset > minFireOffset then
            local aim = warningAim - weapon.GlobalPosition
            if IsLegalAim(aim, neutralAim, azimuthLimitCos) then
                bestAim = aim
                bestOffset = offset
            end
        end
    end
    
    if bestAim ~= nil then
        I:AimWeaponInDirection(weaponIndex, bestAim.x, bestAim.y, bestAim.z, amsWeaponSlot)
    elseif frameTimestamp < resetTimestamp then
        I:AimWeaponInDirection(weaponIndex, weapon.CurrentDirection.x, weapon.CurrentDirection.y, weapon.CurrentDirection.z, amsWeaponSlot)
    else
        I:AimWeaponInDirection(weaponIndex, neutralAim.x, neutralAim.y, neutralAim.z, amsWeaponSlot)
    end
end

function GetNeutralAimInfo(weapon)
    -- weapon.LocalPosition doesn't work for turrets.
    local localPosition = ComputeLocalOffset(weapon.GlobalPosition - myPosition)
    local boxPosition = localPosition - myBoxLocalCenter
    -- LogBoth(string.format("Box position: %s", tostring(boxPosition)))
    local normalizedBoxPositionX = (math.abs(boxPosition.x) + 0.25) / myBoxSize.x
    local normalizedBoxPositionZ = (math.abs(boxPosition.z) + 0.25) / myBoxSize.z 
    -- LogBoth(string.format("Normalized box position: %0.1f, %0.1f", normalizedBoxPositionX, normalizedBoxPositionZ))
    local neutralAim, azimuthLimitCos
    if normalizedBoxPositionZ > normalizedBoxPositionX then
        if boxPosition.z < 0 then
            neutralAim = -myVectors.z
            azimuthLimitCos = math.cos(azimuthLimits.back)
        else
            neutralAim = myVectors.z
            azimuthLimitCos = math.cos(azimuthLimits.forward)
        end
    else
        if boxPosition.x < 0 then
            neutralAim = -myVectors.x
            azimuthLimitCos = math.cos(azimuthLimits.left)
        else
            neutralAim = myVectors.x
            azimuthLimitCos = math.cos(azimuthLimits.right)
        end
    end
    return neutralAim, azimuthLimitCos
end

-- Do the azimuth limits allow the turret to aim this way?
function IsLegalAim(aim, neutralAim, azimuthLimitCos)
    local azimuthAim = Vector3.ProjectOnPlane(aim, myVectors.y)
    local neutralAimCos = Vector3.Dot(azimuthAim.normalized, neutralAim.normalized)
    return neutralAimCos >= azimuthLimitCos
end

-- Fire cannon if any warning is hittable.
function MaybeFireCannon(turretSpinnerIndex, weaponIndex, weapon)
    local fuseDistance = weapon.Speed * fuseTime
    local fuseDistanceSq = fuseDistance * fuseDistance
    for _, warningAim in ipairs(warningAims) do
        local aim = warningAim - weapon.GlobalPosition
        local offset = aim.magnitude - barrelLength - fuseDistance
        if offset < maxFireOffset and offset > minFireOffset then
            local aimCos = Vector3.Dot(weapon.CurrentDirection.normalized, aim.normalized)
            local aimSinSq = 1.0 - aimCos * aimCos
            local aimDeviationSquared = aimSinSq * fuseDistanceSq
            if aimCos > 0 and aimDeviationSquared < maxFireDeviation then
                local aimable = I:AimWeaponInDirectionOnTurretOrSpinner(turretSpinnerIndex, weaponIndex, aim.x, aim.y, aim.z, amsWeaponSlot)
                if aimable then
                    I:FireWeaponOnTurretOrSpinner(turretSpinnerIndex, weaponIndex, amsWeaponSlot)
                    return
                end
            end
        end
    end
end

function ComputeLocalOffset(v)
    return Vector3(Vector3.Dot(v, myVectors.x),
                   Vector3.Dot(v, myVectors.y),
                   Vector3.Dot(v, myVectors.z))
end

function LogBoth(s)
    I:Log(s)
    I:LogToHud(s)
end
