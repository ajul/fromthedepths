-- For testing turn rates.

prevVelocities = {}

function Update(I)
    for t=0,I:GetLuaTransceiverCount() do
        for m=0,I:GetLuaControlledMissileCount(t) do
            missileInfo = I:GetLuaControlledMissileInfo(t,m)
            if missileInfo.Valid then
                -- turn the missile
                -- I:LogToHud(missileInfo.TimeSinceLaunch)
                
                aimTarget = Vector3.zero
                I:SetLuaControlledMissileAimPoint(t, m, aimTarget.x, aimTarget.y, aimTarget.z)
                
                -- acceleration computation
                currVelocity = missileInfo.Velocity
                prevVelocity = prevVelocities[missileInfo.Id]
                if prevVelocity ~= nil then
                    acceleration = (currVelocity - prevVelocities[missileInfo.Id]) * 40
                    lateralAcceleration = acceleration - currVelocity.normalized * (Vector3.Dot(acceleration, currVelocity.normalized))
                    if lateralAcceleration.magnitude > 0.001 then
                        message = string.format("%0.2f, %0.2f", currVelocity.magnitude, lateralAcceleration.magnitude)
                        I:LogToHud(message)
                        I:Log(message)
                    elseif missileInfo.currVelocity.y < 0.0 then
                        I:DetonateLuaControlledMissile(t,m)
                    end
                end
                prevVelocities[missileInfo.Id] = currVelocity
            end
        end
    end
end
