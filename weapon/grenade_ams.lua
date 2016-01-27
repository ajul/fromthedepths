-- All turrets in this weapon slot are assumed to be interceptors.
amsWeaponSlot = 5
-- We crudely assume constant interceptor speed.
interceptorSpeed = 200.0
-- Cull interceptors after this time to save resources.
interceptorLifetime = 3.0
-- Detonate (attack) within this radius. Maximum is 20.
interceptorRadius = 20

-- Extra time (s) to lead the target.
extraLeadTime = 0.1

-- Azimuth limit in degrees. Does not currently apply to turrets which neutrally face up/down.
-- Note that these apply to aiming and only aiming.
-- If you want a turret to not even turn behind itself you will need to set the field of fire restriction on the turret itself.
azimuthLimitCos = math.cos(math.rad(180))

-- How many seconds attack time to start pointing towards missiles.
maxTrackInterceptTime = 6
-- How far to start firing at missiles.
maxFireInterceptTime = 2
-- What accuracy in m is required to start firing.
maxFireLateralDeviation = 5.0

-- Only fire if target is heading at most this many degrees towards us.
approachLimitCos = math.cos(math.rad(45))

-- Timestamp of the current frame.
currentTimestamp = 0
-- Duration of the last frame.
frameDuration = 1/40

g = 9.81

-- The I in Update(I).
I = nil

-- Index -> warning.
warnings = {}

myPosition = Vector3.zero

myVectors = {
    x = Vector3.right,
    y = Vector3.up,
    z = Vector3.forward,
}

-- Neutral positions of turrets.
turretNeutrals = {}

-- Closest target, will point here if no missile is detected.
closestTarget = nil

-- Which mainframe is providing the warnings.
interceptorMainframeIndex = 0

WEAPON_TYPE_TURRET = 4
MISSILE_WEAPON_SPEED = 100
AXES = {'x', 'y', 'z'}

function Update(Iarg)
    I = Iarg
    UpdateInfo()
    
    for weaponIndex = 0, I:GetWeaponCount() - 1 do
        local weapon = I:GetWeaponInfo(weaponIndex)
        -- LogBoth(string.format("Weapon %d type: %d speed: %f", weaponIndex, weapon.WeaponType, weapon.Speed))
        if weapon.WeaponType == WEAPON_TYPE_TURRET --[[ and weapon.WeaponSlot == amsWeaponSlot and weapon.Speed == MISSILE_WEAPON_SPEED ]] then
            ControlTurret(weaponIndex, weapon)
        end
    end
    
    for transceiverIndex = 0, I:GetLuaTransceiverCount() - 1 do
        for interceptorIndex = 0, I:GetLuaControlledMissileCount(transceiverIndex) - 1 do
            local interceptor = I:GetLuaControlledMissileInfo(transceiverIndex, interceptorIndex)
            if I:IsLuaControlledMissileAnInterceptor(transceiverIndex, interceptorIndex) then
                if interceptor.TimeSinceLaunch > interceptorLifetime then
                    -- Cull after lifetime.
                    I:DetonateLuaControlledMissile(transceiverIndex, interceptorIndex)
                else
                    local warningIndex = SelectInterceptorTarget(interceptor)
                    if warningIndex ~= nil then
                        I:SetLuaControlledMissileInterceptorTarget(transceiverIndex, interceptorIndex, interceptorMainframeIndex, warningIndex)
                    end
                end
            end
        end
    end
end

function UpdateInfo()
    local newTimestamp = I:GetGameTime()
    frameDuration = newTimestamp - currentTimestamp
    currentTimestamp = newTimestamp
    
    myPosition = I:GetConstructPosition()
    myVectors.x = I:GetConstructRightVector()
    myVectors.y = I:GetConstructUpVector()
    myVectors.z = I:GetConstructForwardVector()
    
    -- Index warnings.
    warnings = {}
    for mainframeIndex = 0, Info:GetNumberOfMainframes() - 1 do
        local numberOfWarnings = Info:GetNumberOfWarnings(mainframeIndex)
        if numberOfWarnings > 0 then
            for warningIndex0 = 0, numberOfWarnings - 1 do
                -- add one... dammit Lua
                warnings[warningIndex0 + 1] = Info:GetMissileWarning(mainframeIndex, warningIndex0)
            end
            interceptorMainframeIndex = mainframeIndex
            return
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

function ControlTurret(weaponIndex, weapon)
    local turretKey = VectorIntegerString(ComputeLocalPosition(weapon.GlobalPosition))
    if turretNeutrals[turretKey] == nil then
        turretNeutrals[turretKey] = ComputeLocalCardinalDirection(weapon.CurrentDirection)
        -- LogBoth(string.format("Weapon %d at position %s with cardinal direction %s %d", weaponIndex, turretKey, turretNeutrals[turretKey].axis, turretNeutrals[turretKey].polarity))
    end
    
    local bestInterceptTime = maxTrackInterceptTime
    local bestWarning = nil
    for warningIndex1, warning in ipairs(warnings) do
        local interceptTime = ComputeInterceptTime(weapon, warning)
        if interceptTime ~= nil and interceptTime < bestInterceptTime then
            bestInterceptTime = interceptTime
            bestWarning = warning
        end
    end
    
    if bestWarning ~= nil then
        local relativePosition = bestWarning.Position - weapon.GlobalPosition
        local approachCos = -Vector3.Dot(relativePosition.normalized, bestWarning.Velocity.normalized)
        if approachCos > approachLimitCos then
            local aim = bestWarning.Position 
                        + bestWarning.Velocity * bestInterceptTime 
                        + Vector3.up * (0.5 * g * bestInterceptTime * bestInterceptTime)
                        - weapon.GlobalPosition
            I:AimWeaponInDirection(weaponIndex, aim.x, aim.y, aim.z, amsWeaponSlot)
            local aimCos = Vector3.Dot(weapon.CurrentDirection.normalized, aim.normalized)
            local aimSinSq = 1.0 - aimCos * aimCos
            local aimDeviationSq = aimSinSq * aim.sqrMagnitude
            if aimCos > 0 and aimDeviationSq < maxFireLateralDeviation then
                I:FireWeapon(weaponIndex, amsWeaponSlot)
            end
        end
    elseif closestTarget ~= nil then
        local aim = closestTarget.Position - weapon.GlobalPosition
        I:AimWeaponInDirection(weaponIndex, aim.x, aim.y, aim.z, amsWeaponSlot)
    end
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

function ComputeInterceptTime(weapon, warning)
    -- Computes the time needed to intercept the warning.
    
    local relativePosition = (warning.Position + warning.Velocity * extraLeadTime) - weapon.GlobalPosition
    
    -- Solve quadratic equation.
    local a = warning.Velocity.sqrMagnitude - interceptorSpeed * interceptorSpeed
    local b = 2 * Vector3.Dot(warning.Velocity, relativePosition)
    local c = relativePosition.sqrMagnitude
    local vertex = -b / (2 * a)
    local discriminant = vertex*vertex - c / a
    if discriminant > 0 then
        local width = math.sqrt(discriminant)
        local lower = vertex - width + extraLeadTime
        local upper = vertex + width + extraLeadTime
        return (lower >= 0 and lower) or (upper >= 0 and upper) or nil
    else
        return nil
    end
end

function SelectInterceptorTarget(interceptor)
    -- Selects the nearest known missile within destruction radius.
    local warningIndex = nil
    local minDistance = interceptorRadius
    for warningIndex1, warning in ipairs(warnings) do
        if warning.Valid then
            local thisDistance = Vector3.Distance(warning.Position, interceptor.Position) 
            if thisDistance < minDistance then
                minDistance = thisDistance
                warningIndex = warningIndex1 - 1
            end
        end
    end
    return warningIndex
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
