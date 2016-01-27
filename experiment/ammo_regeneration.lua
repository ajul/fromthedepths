lastFrame = 0
lastAmmo = -1

I = nil

function Update(Iarg)
    I = Iarg
    local currentFrame = I:GetTimeSinceSpawn()
    local currentAmmo = I:GetAmmoFraction()
    if currentAmmo ~= lastAmmo then
        LogBoth(string.format("Regenerated %0.2f%% ammo in %0.2fs.", 100.0 * (currentAmmo - lastAmmo), currentFrame - lastFrame))
        lastFrame = currentFrame
        lastAmmo = currentAmmo
    end
end

function LogBoth(s)
    I:Log(s)
    I:LogToHud(s)
end
