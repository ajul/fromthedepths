lastShotTime = 0
shotsFired = 0
shotsToFire = 100
hits = 0
firePeriod = 0.25
ready = true

lastShotTime = 0

function Update(I)
    if I:Component_GetCount(4) > 0 then
        -- oil drill
        ready = true
    else
        if ready == true then
            hits = hits + 1
            hitString = string.format("Hit #%d.", hits)
            I:Log(hitString)
            I:LogToHud(hitString)
            ready = false
        end
    end
    weaponInfo = I:GetWeaponInfo(0)
    if weaponInfo.Valid then
        if weaponInfo.PlayerCurrentlyControllingIt then
            if shotsFired > 0 then
                shotsFired = 0
                hits = 0
                I:LogToHud("Reset shot counter.")
            end
            lastShotTime = I:GetGameTime()
        else
            -- Aim down
            I:AimWeaponInDirection(0, 0, -1, 0, 0)
            local currentTime = I:GetGameTime()
            if ready and currentTime > lastShotTime + firePeriod and shotsFired < shotsToFire then
                lastShotTime = currentTime
                I:FireWeapon(0, 0)
                shotsFired = shotsFired + 1
                if shotsFired == 1 then
                    I:LogToHud("Start shots.")
                elseif shotsFired == shotsToFire then
                    I:LogToHud("End shots.")
                end
                I:LogToHud(string.format("Shot #%d @%f.", shotsFired, currentTime))
            end
        end
    end
end
