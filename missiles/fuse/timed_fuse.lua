fuseTime = 5

function Update(I)
    for t = 0, I:GetLuaTransceiverCount() - 1 do
        for m = 0, I:GetLuaControlledMissileCount(t) - 1 do
            missile = I:GetLuaControlledMissileInfo(t, m)
            if missile.TimeSinceLaunch >= fuseTime then
                I:LogToHud(missile.Velocity.magnitude)
                I:Log(missile.Velocity.magnitude)
                I:DetonateLuaControlledMissile(t, m)
            end
        end
    end
end
