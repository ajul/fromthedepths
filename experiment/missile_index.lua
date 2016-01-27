function Update(I)
    missileCount = I:GetLuaControlledMissileCount(0)
    if missileCount > 0 then
        missile = I:GetLuaControlledMissileInfo(0, 0)
        if missile.TimeSinceLaunch < 1.0 then
            I:Log(string.format("%d, %d", missile.Id, missile.TimeSinceLaunch))
        else
            I:DetonateLuaControlledMissile(0, 0)
        end
    end
end