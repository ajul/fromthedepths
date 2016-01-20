-- Which slot's cannons to use.
amsWeaponSlot = 5

-- What offset (m) to consider firing weapon, where 0 is (hopefully) a direct hit.
-- Recommended to set this high enough so every missile gets a few frames.
-- But limit fire rate on the cannon so that the cannon only fires once per missile.
minFireOffset = -5.0
maxFireOffset = 5.0
maxFireDeviation = 5.0

-- Length of the barrel (m).
barrelLength = 6.0

-- Timed fuse length.
fuseTime = 1

-- Extra time to lead the target.
extraLeadTime = 0.02

-- Gravity, and drop after the fuse time.
g = 9.81
gravityAdjustment = Vector3(0.0, 0.5 * fuseTime * fuseTime * g, 0.0) 

-- The I in Update(I).
I = nil

frameDuration = 0
frameTime = 0

-- Velocity of our construct.
myVelocity = Vector3.zero

-- Table of known enemy missiles. Id -> warning.
warnings = {}
-- Table for previous frame. Id -> warning.
previousWarnings = {}

-- Position to aim at each missile. Index -> aim position.
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

function UpdateInfo()
    -- Called first. This updates the warning table and other info.
    local newFrameTime = I:GetGameTime()
    frameDuration = newFrameTime - frameTime
    frameTime = newFrameTime
    
    myVelocity = I:GetVelocityVector()
    
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
                warningAims[warningIndex1] = WarningAim(warning)
            end
            interceptorMainframeIndex = mainframeIndex
            return
        end
    end
end

-- Determines the (global) position to aim at a warning after the fuse time, accounting for movement and gravity.
function WarningAim(warning)
    local relativeVelocity = warning.Velocity - myVelocity
    local leadPosition = warning.Position + relativeVelocity * (fuseTime + extraLeadTime)
    local previousWarning = previousWarnings[warning.Id]
    if previousWarning ~= nil then
        -- Account for turning.
        local acceleration = warning.Velocity - previousWarning.Velocity
    end
    local aimPosition = leadPosition + gravityAdjustment
    return aimPosition
end

function AimTurret(weaponIndex, weapon)
    local bestOffset = 10000
    local bestWarningAim = nil
    for _, warningAim in ipairs(warningAims) do
        local offset = Vector3.Distance(weapon.GlobalPosition, warningAim) - barrelLength - turretWeaponRange
        if offset < bestOffset and offset > minFireOffset then
            bestWarningAim = warningAim
            bestOffset = offset
        end
    end
    
    if bestWarningAim ~= nil then
        local aim = bestWarningAim - weapon.GlobalPosition
        I:AimWeaponInDirection(weaponIndex, aim.x, aim.y, aim.z, amsWeaponSlot)
    end
end

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