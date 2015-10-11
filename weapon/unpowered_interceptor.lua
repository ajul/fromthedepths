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
    
    -- Time to enter range.
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
            end
        end
    end
end

function Update(I)
    Info = I
    UpdateWarnings(I)
    ControlInterceptorTurrets(I)
end
