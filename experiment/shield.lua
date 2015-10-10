shots = 0
shotsToTake = 100

function Update(I)
    -- health-based hit count doesn't seem to work well enough
    
    -- reset if player controlling weapon
    weaponInfo = I:GetWeaponInfo(0)
    if weaponInfo.PlayerCurrentlyControllingIt then
        shots = 0
    else
        -- otherwise aim and fire weapon
        forward = I:GetConstructForwardVector()
        I:AimWeaponInDirection(0, forward.x, forward.y, forward.z, 0)
        if shots < shotsToTake then
            fired = I:FireWeapon(0, 0)
            if fired then
                shots = shots + 1
            end
        end
    end
end
