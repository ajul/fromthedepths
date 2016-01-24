-- Which slot's turrets/cannons to use (both need to be set).
amsWeaponSlot = 5

-- Azimuth limit in degrees. Does not currently apply to turrets which neutrally face up/down.
-- Note that these apply to aiming and only aiming.
-- If you want a turret to not even turn behind itself you will need to set the field of fire restriction on the turret itself.
azimuthLimitCos = math.cos(math.rad(180))

-- What offset (m) to consider firing weapon, where 0 is (hopefully) a direct hit.
minFireOffset = -7.5
maxFireOffset = 2.5
-- What lateral deviation (m) is acceptable to fire weapon.
maxFireLateralDeviation = 5.0

-- Start tracking when missile gets within this distance of the engagement surface.
maxTrackOffset = 1000

-- Approximate speed of the turrets. We will not attempt to traverse to missiles that we cannot aim at before the kill zone.
-- Set higher to attempt more aggressive traverses.
traverseSpeed = math.rad(90)

-- Length of the cannon compared to the turret (m).
cannonLength = 5.0

-- Timed fuse length (s). You may want to add an extra frame.
fuseTime = 1
-- Add an extra frame?
extraFuseFrames = 1
-- Extra time (s) to lead the target.
extraLeadTime = 0.0

-- Don't fire another burst at a warning unless this time has passed since the start of the last burst.
-- Set to a negative value to fire as fast as possible.
minBurstIntervalPerWarning = fuseTime
-- How many shots to fire per burst.
shotsPerBurst = 1

-- Minimum lateral acceleration to use circular prediction.
minCircularAcceleration = 5

-- Weapon speed and range for computing turret lead when no shell loaded.
defaultWeaponSpeed = 150

-- Gravity, and drop after the fuse time.
g = 9.81
gravityAdjustment = Vector3(0.0, 0.5 * fuseTime * fuseTime * g, 0.0) 

-- The I in Update(I).
I = nil

-- Timestamp of the current frame.
currentTimestamp = 0
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
-- When next burst may be fired at each warning. Id -> timestamp.
burstTimestamps = {}
-- Number of shots fired in the current burst against each warning.
burstCounts = {}

-- Position to aim at each warning. Index -> aim position.
warningAims = {}
-- warningAim indexes -> warningIds.
warningAimsIds = {}

-- Neutral positions of turrets.
turretNeutrals = {}

closestTarget = nil

totalLeadTime = fuseTime + extraFuseFrames * frameDuration + extraLeadTime 

WEAPON_TYPE_TURRET = 4

-- Dummy weapon speed that the game returns for missiles.
MISSILE_WEAPON_SPEED = 100

AXES = {'x', 'y', 'z'}

function Update(Iarg)
    I = Iarg
    UpdateInfo()
    
    for weaponIndex = 0, I:GetWeaponCount() - 1 do
        local weapon = I:GetWeaponInfo(weaponIndex)
        if weapon.WeaponType == WEAPON_TYPE_TURRET and weapon.WeaponSlot == amsWeaponSlot and not (weapon.Speed == MISSILE_WEAPON_SPEED) then
            ControlTurret(weaponIndex, weapon)
        end
    end
end

-- Called first. This updates the warning tables and other info.
function UpdateInfo()
    local newTimestamp = I:GetGameTime()
    frameDuration = newTimestamp - currentTimestamp
    currentTimestamp = newTimestamp
    
    totalLeadTime = fuseTime + extraFuseFrames * frameDuration + extraLeadTime 
    
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
                warningAimsIds[#warningAims] = warning.Id
                warningAims[#warningAims+1] = WarningCircularAim(warning)
                warningAimsIds[#warningAims] = warning.Id
            end
            return
        end
    end
    
    -- Clean up fire times.
    for id, _ in pairs(burstTimestamps) do
        if warnings[id] == nil then
            burstTimestamps[id] = nil
            burstCounts[id] = nil
        end
    end
    
    -- Compute closest target for aiming at if no missiles are around.
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
    local previousWarning = previousWarnings[warning.Id]
    if previousWarning ~= nil then
        local acceleration = (warning.Velocity - previousWarning.Velocity) / frameDuration
        local linearAcceleration = Vector3.Project(acceleration, warning.Velocity)
        
        -- A little less than full acceleration to account for drag.
        leadPosition = leadPosition + linearAcceleration * (0.45 * totalLeadTime * totalLeadTime)
    end
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
    local weaponSpeed = (weapon.Speed > 0 and weapon.Speed) or defaultWeaponSpeed
    local fuseDistance = weaponSpeed * (fuseTime + extraFuseFrames * frameDuration) + cannonLength
    if turretNeutrals[turretKey] == nil then
        turretNeutrals[turretKey] = ComputeLocalCardinalDirection(weapon.CurrentDirection)
        -- LogBoth(string.format("Weapon %d at position %s with cardinal direction %s %d", weaponIndex, turretKey, turretNeutrals[turretKey].axis, turretNeutrals[turretKey].polarity))
    end
    
    -- LogBoth(string.format("Neutral aim %d: %s", weaponIndex, tostring(neutralAim)))
    local bestOffset = maxTrackOffset
    local bestAim = nil
    local bestWarningAimIndex = nil
    local bestWarningId = nil
    for warningAimIndex, warningAim in ipairs(warningAims) do
        local warningId = warningAimsIds[warningAimIndex]
        -- Allow fire if burst has recharged, or shots remaining in burst.
        if currentTimestamp > (burstTimestamps[warningId] or 0) or (burstCounts[warningId] or 0) < shotsPerBurst then
            local offset = Vector3.Distance(weapon.GlobalPosition, warningAim) - fuseDistance
            if offset < bestOffset and offset > minFireOffset then
                local aim = warningAim - weapon.GlobalPosition
                if IsLegalAim(aim, turretNeutrals[turretKey]) then
                    local warning = warnings[warningId]
                    if CanTraverseInTime(weapon, warning, aim, offset) then
                        -- LogBoth(string.format("Legal: %0.1f", offset))
                        bestAim = aim
                        bestOffset = offset
                        bestWarningAimIndex = warningAimIndex
                        bestWarningId = warningId
                    end
                end
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
            if aimCos > 0 and aimDeviationSq < maxFireLateralDeviation then
                local fired = I:FireWeapon(weaponIndex, amsWeaponSlot)
                if fired then
                    if currentTimestamp > (burstTimestamps[bestWarningId] or 0) then
                        -- If recharged, start new burst.
                        burstTimestamps[bestWarningId] = currentTimestamp + minBurstIntervalPerWarning
                        burstCounts[bestWarningId] = 1
                    else
                        -- Otherwise use up a burst shot.
                        burstCounts[bestWarningId] = burstCounts[bestWarningId] + 1
                    end
                end
            end
        end
    elseif closestTarget ~= nil then
        local aim = closestTarget.Position - weapon.GlobalPosition
        if IsLegalAim(aim, turretNeutrals[turretKey]) then
            I:AimWeaponInDirection(weaponIndex, aim.x, aim.y, aim.z, amsWeaponSlot)
        end
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

function CanTraverseInTime(weapon, warning, aim, offset)
    local closeTime = (offset - minFireOffset) / (warning.Velocity.magnitude + 1)
    local angle = math.acos(Vector3.Dot(aim.normalized, weapon.CurrentDirection.normalized))
    local aimTime = angle / traverseSpeed
    -- if aimTime >= closeTime then LogBoth(string.format("Unable to traverse in time! (need %0.2fs, close %0.2fs)", aimTime, closeTime)) end
    return aimTime < closeTime
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
