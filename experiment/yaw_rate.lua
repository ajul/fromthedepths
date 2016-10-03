tau = 0.5 -- exponential time to average over
minDisplayYawRate = 0.5 -- don't display anything if yaw rate is under this threshold

I = nil
prevGameTime = nil
prevYaw = 0.0
prevYawRate = 0.0

function Update(Iarg)
    I = Iarg
    
    local yaw = I:GetConstructYaw()
    local gameTime = I:GetGameTime()
    
    if prevGameTime ~= nil then
        local dt = gameTime - prevGameTime
        local yawChange = math.abs(yaw - prevYaw)
        if yawChange >= 180.0 then
            yawChange = math.abs(yawChange - 360.0)
        end
        local yawRate = yawChange / dt
        local alpha = math.exp(-dt / tau)
        prevYawRate = alpha * prevYawRate + (1.0 - alpha) * yawRate
        if prevYawRate >= minDisplayYawRate then
            LogBoth(string.format('Yaw rate: %0.1f', prevYawRate))
        end
    end
    
    prevYaw = yaw
    prevGameTime = gameTime
end

function LogBoth(s)
    I:Log(s)
    I:LogToHud(s)
end