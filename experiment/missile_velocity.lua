function Update(I)
    missileCount = I:GetLuaControlledMissileCount(0)
    if missileCount > 0 then
        missile = I:GetLuaControlledMissileInfo(0, 0)
        if missile.TimeSinceLaunch < 2.0 and missile.Position.y > 0 then
            local horizontalVelocity = math.sqrt(missile.Velocity.x * missile.Velocity.x + missile.Velocity.z * missile.Velocity.z )
            I:Log(string.format("%f: %f, %f", missile.TimeSinceLaunch, horizontalVelocity, missile.Velocity.y))
        else
            I:DetonateLuaControlledMissile(0, 0)
        end
    end
end