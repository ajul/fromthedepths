turretTurnRate = math.rad(40.0)

interceptorWeaponSlot = 5
interceptorSpeed = 200.0
interceptorLifetime = 3.0
interceptorRange = interceptorSpeed * interceptorLifetime

warnings = {}

WEAPON_TYPE_TURRET = 4

function UpdateWarnings(I)
    warnings = {}
    for mainframeIndex = 0, I:GetNumberOfMainframes() - 1 do
        numberOfWarnings = I:GetNumberOfWarnings(mainframeIndex)
        Info:LogToHud(numberOfWarnings)
        if numberOfWarnings > 0 then
            for warningIndex = 0, numberOfWarnings - 1 do
                warnings[warningIndex] = I:GetMissileWarning(mainframeIndex, warningIndex)
            end
            -- Only consider one mainframe.
            return
        end
    end
end

-- TODO: compute lead

function WarningTime(turret, warning)
    -- Estimate the time before warning can be addressed.
    
    -- Turret turn time.
    relativePosition = warning.Position - turret.GlobalPosition
    relativeAngle = math.acos(Vector3.Dot(relativePosition.normalized, turret.CurrentDirection))
    
    turnTime = math.abs(relativeAngle / turretTurnRate)
    
    closeRate = -Vector3.Dot(warning.Velocity, relativePosition.normalized)
    if closeRate < 0 then
        return 60
    end
    
    return turnTime
end

function SelectTurretTarget(turret)
    -- Select a target for the current turret.
    targetTime = 60
    target = nil
    for _, warning in ipairs(warnings) do
        if warning.Valid then
            warningTime = WarningTime(turret, warning)
            if warningTime < targetTime then
                targetTime = warningTime
                target = warning
            end
        end
    end
    return target
end

function ControlInterceptorTurrets(I)
    for weaponIndex = 0, I:GetWeaponCount() - 1 do
        turret = I:GetWeaponInfo(weaponIndex)
        if turret.WeaponType == WEAPON_TYPE_TURRET and turret.WeaponSlot == interceptorWeaponSlot then
            -- aim at soonest target
            target = SelectTurretTarget(turret)
            if target ~= nil then
                relativePosition = target.Position - turret.GlobalPosition
                I:AimWeaponInDirection(weaponIndex, relativePosition.x, relativePosition.y, relativePosition.z, interceptorWeaponSlot)
                I:FireWeapon(weaponIndex, interceptorWeaponSlot)
            end
        end
    end
end

function SelectInterceptorTarget(missile)
    -- selects the nearest known missile
    resultIndex = nil
    minDistance = 1000
    for warningIndex, warning in ipairs(warnings) do
        thisDistance = Vector3.Distance(warning.Position, missile.Position) 
        if thisDistance < minDistance then
            minDistance = thisDistance
            resultIndex = warningIndex
        end
    end
    return resultIndex
end

function ControlInterceptors(I)
    for transceiverIndex = 0, I:GetLuaTransceiverCount() - 1 do
        for missileIndex = 0, I:GetLuaControlledMissileCount(transceiverIndex) - 1 do
            missile = I:GetLuaControlledMissileInfo(transceiverIndex, missileIndex)
            if I:IsLuaControlledMissileAnInterceptor(transceiverIndex, missileIndex) then
                if missile.TimeSinceLaunch > interceptorLifetime then
                    I:DetonateLuaControlledMissile(transceiverIndex, missileIndex)
                else
                    targetIndex = SelectInterceptorTarget(missile)
                    if targetIndex ~= nil then
                        I:SetLuaControlledMissileInterceptorTarget(transceiverIndex, missileIndex, mainframeIndex, targetIndex)
                    end
                end
            end
        end
    end
end

function Update(I)
    Info = I
    UpdateWarnings(I)
    ControlInterceptorTurrets(I)
    ControlInterceptors(I)
end
