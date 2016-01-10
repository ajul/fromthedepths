I = nil

WEAPON_TYPE_CANNON = 0

function AnyEnemyDetected()
    for mainframeIndex = 0, I:GetNumberOfMainframes() - 1 do
        if I:GetNumberOfTargets(mainframeIndex) > 0 then
            return true
        end
    end
    return false
end

function Update(Iarg)
    I = Iarg
    
    if not AnyEnemyDetected() then
        return
    end
    
    for weaponIndex = 0, I:GetWeaponCount() - 1 do
        local weapon = I:GetWeaponInfo(weaponIndex)
        
        if weapon.WeaponType == WEAPON_TYPE_CANNON then
            if weapon.Speed > 0 and weapon.Speed < 12 then
                local weaponDirection = weapon.CurrentDirection
                I:AimWeaponInDirection(weaponIndex, weaponDirection.x, weaponDirection.y, weaponDirection.z, 0)
                I:FireWeapon(weaponIndex, 0)
            end
        end
    end
end