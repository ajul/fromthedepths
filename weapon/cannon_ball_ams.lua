-- Which slot's cannons to use.
amsWeaponSlot = 5

-- Azimuth limit in degrees. Does not currently apply to turrets which neutrally face up/down.
-- Neutral direction is the nearest cardinal direction when turret is first detected by the script.
-- Note that these apply to aiming and only aiming.
-- If you want a turret to not even turn behind itself you will need to set the field of fire restriction on the turret itself.
azimuthLimitCos = math.cos(math.rad(180))

-- Weapon speed and range for computing turret lead.
weaponSpeed = 150

-- What offset (m) to consider firing weapon, where 0 is (hopefully) a direct hit.
-- Recommended to set this high enough so every warning gets a few frames in range.
-- But limit fire rate on the cannon so that the cannon only fires once per warning.
minFireOffset = -5.0
maxFireOffset = 5.0
maxFireDeviation = 5.0

-- Start tracking when missile gets within this distance of the engagement surface.
maxTrackOffset = 1000

-- Length of the cannon compared to the turret (m).
cannonLength = 5.0

-- Timed fuse length (s).
fuseTime = 1
-- Extra time (s) to lead the target.
extraLeadTime = 0.1
totalLeadTime = fuseTime + extraLeadTime

-- Minimum lateral acceleration to use circular prediction.
minCircularAcceleration = 5

-- Gravity, and drop after the fuse time.
g = 9.81
gravityAdjustment = Vector3(0.0, 0.5 * fuseTime * fuseTime * g, 0.0) 

-- The I in Update(I).
I = nil

-- Timestamp of the current frame.
frameTimestamp = 0
-- Duration of the last frame.
frameDuration = 1/40

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

-- Neutral positions of turrets.
turretNeutrals = {}

closestTarget = nil

-- Distance at which burst happens.
fuseDistance = weaponSpeed * fuseTime + cannonLength

WEAPON_TYPE_CANNON = 0
WEAPON_TYPE_TURRET = 4

AXES = {'x', 'y', 'z'}

function Update(Iarg)
    I = Iarg
    UpdateInfo()
    
    for weaponIndex = 0, I:GetWeaponCount() - 1 do
        local weapon = I:GetWeaponInfo(weaponIndex)
        if weapon.WeaponType == WEAPON_TYPE_TURRET and weapon.WeaponSlot == amsWeaponSlot then
            ControlTurret(weaponIndex, weapon)
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
            -- I:Log(tostring(numberOfWarnings))
            for warningIndex1 = 1, numberOfWarnings do
                local warning = I:GetMissileWarning(mainframeIndex, warningIndex1 - 1)
                warnings[warning.Id] = warning
                warningAims[#warningAims+1] = WarningLinearAim(warning)
                warningAims[#warningAims+1] = WarningCircularAim(warning)
            end
            interceptorMainframeIndex = mainframeIndex
            return
        end
    end
    
    closestTarget = nil
    local closestDistance = 10000
    
    for targetIndex = 0, I:GetNumberOfTargets(0) - 1 do
        local target = I:GetTargetInfo(0, targetIndex)
        local distance = Vector3.Distance(myPosition, target.Position)
        if distance < closestDistance then
            closestTarget = target
            closestDistance = distance
        end
    end
end

function WarningLinearAim(warning)
    local relativeVelocity = warning.Velocity - myVelocity
    local leadPosition = warning.Position + relativeVelocity * totalLeadTime
    local aimPosition = leadPosition + gravityAdjustment
    return aimPosition
end

function WarningCircularAim(warning)
    local previousWarning = previousWarnings[warning.Id]
    if previousWarning == nil then
        return nil
    end
    local acceleration = (warning.Velocity - previousWarning.Velocity) / frameDuration
    local lateralAcceleration = Vector3.ProjectOnPlane(acceleration, warning.Velocity)
    if lateralAcceleration.magnitude < minCircularAcceleration then
        return nil
    end
    local radius = lateralAcceleration * warning.Velocity.sqrMagnitude / acceleration.sqrMagnitude
    -- LogBoth(string.format("Radius: %s", tostring(radius.magnitude)))
    local center = warning.Position + radius
    local turnAngle = warning.Velocity.magnitude / radius.magnitude * totalLeadTime
    local turnPosition = center - radius * math.cos(turnAngle) + (warning.Velocity.normalized * radius.magnitude) * math.sin(turnAngle)
    local leadPosition = turnPosition - myVelocity * totalLeadTime
    local aimPosition = leadPosition + gravityAdjustment
    return aimPosition
end

-- Aim turret at the nearest warning aim position that isn't below minimum range.
function ControlTurret(weaponIndex, weapon)
    local turretKey = VectorIntegerString(ComputeLocalPosition(weapon.GlobalPosition))
    if turretNeutrals[turretKey] == nil then
        turretNeutrals[turretKey] = ComputeLocalCardinalDirection(weapon.CurrentDirection)
        -- LogBoth(string.format("Weapon %d at position %s with cardinal direction %s %d", weaponIndex, turretKey, turretNeutrals[turretKey].axis, turretNeutrals[turretKey].polarity))
    end
    
    -- LogBoth(string.format("Neutral aim %d: %s", weaponIndex, tostring(neutralAim)))
    local bestOffset = maxTrackOffset
    local bestAim = nil
    for _, warningAim in ipairs(warningAims) do
        local offset = Vector3.Distance(weapon.GlobalPosition, warningAim) - fuseDistance
        if offset < bestOffset and offset > minFireOffset then
            local aim = warningAim - weapon.GlobalPosition
            if IsLegalAim(aim, turretNeutrals[turretKey]) then
                -- LogBoth(string.format("Legal: %0.1f", offset))
                bestAim = aim
                bestOffset = offset
            else
                -- LogBoth(string.format("Illegal: %0.1f", offset))
            end
        end
    end
    
    if bestAim ~= nil then
        -- LogBoth(string.format("Aim %d: %s", weaponIndex, tostring(bestAim)))
        I:AimWeaponInDirection(weaponIndex, bestAim.x, bestAim.y, bestAim.z, amsWeaponSlot)
        if bestOffset < maxFireOffset then
            local aimCos = Vector3.Dot(weapon.CurrentDirection.normalized, bestAim.normalized)
            local aimSinSq = 1.0 - aimCos * aimCos
            local aimDeviationSq = aimSinSq * fuseDistance * fuseDistance
            if aimCos > 0 and aimDeviationSq < maxFireDeviation then
                I:FireWeapon(weaponIndex, amsWeaponSlot)
            end
        end
    elseif closestTarget ~= nil then
        local targetAim = closestTarget.Position - weapon.GlobalPosition
        I:AimWeaponInDirection(weaponIndex, targetAim.x, targetAim.y, targetAim.z, amsWeaponSlot)
    end
end

-- Do the azimuth limits allow the turret to aim this way?
function IsLegalAim(aim, turretNeutral)
    if turretNeutral.axis ~= "y" then
        local azimuthAim = Vector3.ProjectOnPlane(aim, myVectors.y)
        local neutralAim = myVectors[turretNeutral.axis] * turretNeutral.polarity
        local neutralAimCos = Vector3.Dot(azimuthAim.normalized, neutralAim.normalized)
        return neutralAimCos >= azimuthLimitCos
    end
    -- up/down turrets can aim anywhere for now
    return true
end

function ComputeLocalCardinalDirection(globalVector)
    -- Computes the local cardinal direction closest to the global direction.
    local localVector = ComputeLocalVector(globalVector)
    local bestScore = 0
    local bestAxis = nil
    local polarity = 0
    for _, axis in ipairs(AXES) do
        local thisScore = math.abs(localVector[axis])
        if thisScore >= bestScore then
            bestAxis = axis
            polarity = (localVector[axis] < 0 and -1) or 1
            bestScore = thisScore
        end
    end
    return {
        axis = bestAxis, 
        polarity = polarity,
    }
end

function ComputeLocalVector(globalVector)
    return Vector3(Vector3.Dot(globalVector, myVectors.x),
                   Vector3.Dot(globalVector, myVectors.y),
                   Vector3.Dot(globalVector, myVectors.z))
end


function ComputeLocalPosition(globalPosition)
    local relativePosition = globalPosition - myPosition
    return Vector3(Vector3.Dot(relativePosition, myVectors.x),
                   Vector3.Dot(relativePosition, myVectors.y),
                   Vector3.Dot(relativePosition, myVectors.z))
end

function VectorIntegerString(v)
    return string.format("%d,%d,%d",
                         math.floor(v.x + 0.5),
                         math.floor(v.y + 0.5),
                         math.floor(v.z + 0.5))
end
                         

function LogBoth(s)
    I:Log(s)
    I:LogToHud(s)
end
