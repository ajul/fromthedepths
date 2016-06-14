-- Points a turret so that it acts as a range gauge.
-- Pointer should be a bare turret, or an unloaded advanced cannon on a turret.

-- Which weapon slot to use.
weaponSlot = 5

-- Range at extremes of gauge.
minRange = 1000
maxRange = 5000

-- Angle at minimum and maximum range.
minAngle = 135
maxAngle = 45

myVectors = {
    x = Vector3.right,
    y = Vector3.up,
    z = Vector3.forward,
}

currentTarget = nil

WEAPON_TYPE_TURRET = 4

function Update(Iarg)
    I = Iarg
    
    local range = ComputeTargetRange()
    
    SetGauges(range or maxRange)
end

function ComputeTargetRange()
    local target = nil
    for mainframeIndex = 0, I:GetNumberOfMainframes() - 1 do
        local firstTarget = I:GetTargetInfo(mainframeIndex, 0)
        if firstTarget.Valid and (target == nil or target.Score ~= 0) then
            target = firstTarget
            if target.Score ~= 0 then
                break
            end
        end
    end
    
    if target == nil then
        return nil
    else
        return Vector3.Distance(target.Position, I:GetConstructPosition())
    end
end



function SetGauges(range)
    local rangeFraction = (range - minRange) / (maxRange - minRange)
    if rangeFraction < 0 then
        rangeFraction = 0
    elseif rangeFraction > 1 then
        rangeFraction = 1
    end
    local angle = math.rad(minAngle + rangeFraction * (maxAngle - minAngle))
    local aimDirection = I:GetConstructRightVector() * math.cos(angle) + I:GetConstructUpVector() * math.sin(angle)
    
    for weaponIndex = 0, I:GetWeaponCount() - 1 do
        local weapon = I:GetWeaponInfo(weaponIndex)
        if weapon.WeaponType == WEAPON_TYPE_TURRET and (weapon.Speed == 0 or weapon.Speed == 50) then
            I:AimWeaponInDirection(weaponIndex, aimDirection.x, aimDirection.y, aimDirection.z, weaponSlot)
        end
    end
end
