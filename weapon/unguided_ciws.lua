-- All turrets in this weapon slot are assumed to be interceptors.
interceptorWeaponSlot = 5
-- We crudely assume constant interceptor speed.
interceptorSpeed = 250.0
-- Detonate interceptors after this time to save resources.
interceptorLifetime = 3.0
-- How far we will consider throwing interceptors.
interceptorRange = 500.0
-- The maximum deviation in aim time at which we will open fire.
maximumAimTimeDeviation = 0.2

interceptorRangeTime = interceptorRange / interceptorSpeed

WEAPON_TYPE_TURRET = 4
turretTurnRate = math.rad(40.0)
-- How far interceptors can destroy missiles.
interceptorRadius = 20.0
-- Which mainframe is providing warning info.
interceptorMainframeIndex = 0

-- Table of known enemy missiles.
warnings = {}
-- The I in Update(I).
Info = nil

function UpdateWarnings()
    -- Called first. This updates the warning table. Elements are warningIndex -> warningInfo.
    warnings = {}
    for mainframeIndex = 0, Info:GetNumberOfMainframes() - 1 do
        local numberOfWarnings = Info:GetNumberOfWarnings(mainframeIndex)
        if numberOfWarnings > 0 then
            for warningIndex = 0, numberOfWarnings - 1 do
                warnings[warningIndex] = Info:GetMissileWarning(mainframeIndex, warningIndex)
            end
            interceptorMainframeIndex = mainframeIndex
            return
        end
    end
end

function ControlInterceptorTurrets()
    -- Aims interceptor turrets and fires missiles if appropriate.
    for weaponIndex = 0, Info:GetWeaponCount() - 1 do
        turret = Info:GetWeaponInfo(weaponIndex)
        if turret.WeaponType == WEAPON_TYPE_TURRET and turret.WeaponSlot == interceptorWeaponSlot then
            -- aim at soonest target
            -- need lead
            target = SelectTurretTarget(turret)
            if target ~= nil then
                local interceptTime = InterceptTime(turret.GlobalPosition, interceptorSpeed, target)
                if interceptTime < interceptorRangeTime then
                    -- If in range, aim to intercept.
                    local aimPosition = target.Position + target.Velocity * interceptTime
                    local relativeAimPosition = aimPosition - turret.GlobalPosition
                    Info:AimWeaponInDirection(weaponIndex, relativeAimPosition.x, relativeAimPosition.y, relativeAimPosition.z, interceptorWeaponSlot)
                    if TurretAimTime(turret.CurrentDirection, relativeAimPosition) < maximumAimTimeDeviation then
                        Info:FireWeapon(weaponIndex, interceptorWeaponSlot)
                    end
                else
                    -- Otherwise look directly at the missile.
                    local relativePosition = target.Position - turret.GlobalPosition
                    Info:AimWeaponInDirection(weaponIndex, relativePosition.x, relativePosition.y, relativePosition.z, interceptorWeaponSlot)
                end
            end
        end
    end
end

function SelectTurretTarget(turret)
    local target = nil
    local targetEngageTime = 60
    for _, warning in ipairs(warnings) do
        if warning.Valid then
            local engageTime = TurretEngageTime(turret, warning)
            if engageTime ~= nil and engageTime < targetEngageTime then
                target = warning
                targetEngageTime = engageTime
            end
        end
    end
    return target
end

function TurretEngageTime(turret, warning)
    -- Estimate how long it would take until the turret can fire at the target.
    
    local relativePosition = warning.Position - turret.GlobalPosition
    
    -- How long until the target will be in range?
    local closeRate = -Vector3.Dot(warning.Velocity, relativePosition)
    -- Only fire at approaching targets.
    if closeRate <= 0 then
        return nil
    end
    local rangeTime = math.max(relativePosition.magnitude - interceptorRange, 0) / closeRate
    
    -- Is the target traveling towards us?
    local targetVelocityAimTime = TurretAimTime(relativePosition.normalized, -warning.Velocity)
    
    -- How long until we can aim at the target?
    -- local closestApproach = Vector3.ProjectOnPlane(relativePosition, warning.Velocity.normalized)
    -- local closestApproachAimTime = TurretAimTime(turret.CurrentDirection, closestApproach)
    
    return math.max(rangeTime, targetVelocityAimTime)
end

function TurretAimTime(turretDirection, relativePosition)
    -- Computes how long it would take the turret to aim at aimPosition. 
    -- Conservative since we can aim in both axes at the same time.
    local relativeAngle = math.acos(Vector3.Dot(relativePosition.normalized, turretDirection))
    return math.abs(relativeAngle / turretTurnRate)
end

function InterceptTime(missilePosition, missileSpeed, target)
    -- Computes the time needed to intercept the target.
    
    local relativePosition = target.Position - missilePosition
    
    -- Relative position at closest approach.
    local closestApproach = Vector3.ProjectOnPlane(relativePosition, target.Velocity.normalized)
    
    -- Solve quadratic equation.
    local a = target.Velocity.sqrMagnitude - missileSpeed * missileSpeed
    local b = 2 * closestApproach.magnitude * target.Velocity.magnitude
    local c = relativePosition.sqrMagnitude
    local vertex = -b / (2 * a)
    local discriminant = vertex*vertex - c / a
    if discriminant > 0 then
        local width = math.sqrt(discriminant)
        local lower = vertex - width
        local upper = vertex + width
        return (lower >= 0 and lower) or (upper >= 0 and upper) or nil
    else
        return nil
    end
end

function ControlInterceptors(I)
    -- Controls interceptors. Since they are not powered, this is only fuse and culling.
    for transceiverIndex = 0, Info:GetLuaTransceiverCount() - 1 do
        for interceptorIndex = 0, Info:GetLuaControlledMissileCount(transceiverIndex) - 1 do
            local interceptor = Info:GetLuaControlledMissileInfo(transceiverIndex, interceptorIndex)
            if Info:IsLuaControlledMissileAnInterceptor(transceiverIndex, interceptorIndex) then
                if interceptor.TimeSinceLaunch > interceptorLifetime then
                    Info:DetonateLuaControlledMissile(transceiverIndex, interceptorIndex)
                else
                    local targetIndex = SelectInterceptorTarget(interceptor)
                    if targetIndex ~= nil then
                        Info:SetLuaControlledMissileInterceptorTarget(transceiverIndex, interceptorIndex, interceptorMainframeIndex, targetIndex)
                    end
                end
            end
        end
    end
end

function SelectInterceptorTarget(missile)
    -- Selects the nearest known missile within destruction radius.
    local resultIndex = nil
    local minDistance = interceptorRadius
    for warningIndex, warning in ipairs(warnings) do
        local thisDistance = Vector3.Distance(warning.Position, missile.Position) 
        if thisDistance < minDistance then
            minDistance = thisDistance
            resultIndex = warningIndex
        end
    end
    return resultIndex
end

function Update(I)
    Info = I
    UpdateWarnings()
    ControlInterceptorTurrets()
    ControlInterceptors()
end