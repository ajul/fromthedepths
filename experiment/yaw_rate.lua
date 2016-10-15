tau = 0.5 -- exponential time to average over
minDisplayYawRate = 0.5 -- don't display anything if yaw rate is under this threshold

I = nil
prevGameTime = nil
prevYaw = 0.0
meanYawRate = 0.0

function Update(Iarg)
    I = Iarg
    
    local yaw = I:GetConstructYaw()
    local speed = I:GetVelocityMagnitude()
    local gameTime = I:GetGameTime()
    
    if prevGameTime ~= nil then
        local dt = gameTime - prevGameTime
        local yawChange = math.abs(yaw - prevYaw)
        if yawChange >= 180.0 then
            yawChange = math.abs(yawChange - 360.0)
        end
        local yawRate = yawChange / dt
        local alpha = math.exp(-dt / tau)
        meanYawRate = alpha * meanYawRate + (1.0 - alpha) * yawRate
        if meanYawRate >= minDisplayYawRate then
            local turnRadius = speed / math.rad(meanYawRate)
            local turnAcceleration = speed * math.rad(meanYawRate)
            LogBoth(string.format('Yaw rate: %0.1f, turn radius %d, turn acceleration %0.2f', meanYawRate, turnRadius, turnAcceleration))
        end
    end
    
    prevYaw = yaw
    prevGameTime = gameTime
end

function LogBoth(s)
    I:Log(s)
    I:LogToHud(s)
end