-- Which weapon slot contains the rockets.
rocketWeaponSlot = 4
-- We crudely assume constant rocket speed.
rocketSpeed = 300.0
-- When to detonate rockets. This should be a frame past burn time.
rocketLifetime = 0.53
-- Minimum velocity to consider a missile a rocket.
rocketMinimumVelocity = 300.0
-- How far we will consider firing rockets.
rocketRange = 450.0
-- The maximum deviation in aim time at which we will open fire.
maximumAimTimeDeviation = 0.2
-- The minimum altitude of a target.
targetMinimumAltitude = 0
-- Extra lead time to account for boost phase.
extraLeadTime = 0.3

rocketRangeTime = rocketRange / rocketSpeed + extraLeadTime

-- Which mainframe to use.
targetingMainframe = 0
WEAPON_TYPE_TURRET = 4
turretTurnRate = math.rad(40.0)

-- The I in Update(I).
Info = nil

targets = {}

function UpdateTargets()
    -- Called first. This updates the warning table. Elements are warningIndex -> warningInfo.
    targets = {}
    for targetIndex0 = 0, Info:GetNumberOfTargets(targetingMainframe) - 1 do
        targets[targetIndex0 + 1] = Info:GetTargetInfo(targetingMainframe, targetIndex0)
    end
end

function ControlRocketTurrets()
    -- Aims rocket turrets and fires if appropriate.
    for weaponIndex = 0, Info:GetWeaponCount() - 1 do
        local turret = Info:GetWeaponInfo(weaponIndex)
        if turret.WeaponType == WEAPON_TYPE_TURRET and turret.WeaponSlot == rocketWeaponSlot then
            local selected, selectedInterceptTime, selectedTurretAimTime = SelectTurretTarget(turret)
            if selected ~= nil then
                local aimPosition = selected.Position + selected.Velocity * selectedInterceptTime
                local relativeAimPosition = aimPosition - turret.GlobalPosition
                Info:AimWeaponInDirection(weaponIndex, relativeAimPosition.x, relativeAimPosition.y, relativeAimPosition.z, rocketWeaponSlot)
                if selectedInterceptTime < rocketRangeTime and selectedTurretAimTime < maximumAimTimeDeviation then
                    Info:FireWeapon(weaponIndex, rocketWeaponSlot)
                end
            end
        end
    end
end

function SelectTurretTarget(turret)
    local selected = nil
    local selectedInterceptTime = nil
    local selectedTurretAimTime = nil
    local bestTime = 60
    for _, target in ipairs(targets) do
        if target.Valid and target.Protected and target.Position.y >= targetMinimumAltitude then
            local relativePosition = target.Position - turret.GlobalPosition
            local interceptTime = InterceptTime(turret.GlobalPosition, rocketSpeed, target, extraLeadTime)
            local turretAimTime = TurretAimTime(turret.CurrentDirection, relativePosition)
            if interceptTime ~= nil and interceptTime < bestTime then
                selected = target
                bestTime = interceptTime
                selectedInterceptTime = interceptTime
                selectedTurretAimTime = turretAimTime
            end
        end
    end
    return selected, selectedInterceptTime, selectedTurretAimTime
end

function InterceptTime(missilePosition, missileSpeed, target, extraLeadTime)
    -- Computes the time needed to intercept the target.
    
    local relativePosition = (target.Position + target.Velocity * extraLeadTime) - missilePosition
    
    -- Solve quadratic equation.
    local a = target.Velocity.sqrMagnitude - missileSpeed * missileSpeed
    local b = 2 * Vector3.Dot(target.Velocity, relativePosition)
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

function TurretAimTime(turretDirection, relativePosition)
    -- Computes how long it would take the turret to aim at aimPosition. 
    -- Conservative since we can aim in both axes at the same time.
    local relativeAngle = math.acos(Vector3.Dot(relativePosition.normalized, turretDirection))
    return math.abs(relativeAngle / turretTurnRate)
end

function ControlRockets(I)
    -- Controls rockets. Since they are not guided, this is only fuse.
    for transceiverIndex = 0, Info:GetLuaTransceiverCount() - 1 do
        for rocketIndex = 0, Info:GetLuaControlledMissileCount(transceiverIndex) - 1 do
            local rocket = Info:GetLuaControlledMissileInfo(transceiverIndex, rocketIndex)
            if rocket.TimeSinceLaunch >= rocketLifetime and rocket.Velocity.magnitude >= rocketMinimumVelocity then
                Info:DetonateLuaControlledMissile(transceiverIndex, rocketIndex)
            end
        end
    end
end

function Update(I)
    Info = I
    UpdateTargets()
    ControlRocketTurrets()
    ControlRockets()
end