angleThreshold = 5

CONTROL_MODE_WATER = 0

CONTROL_YAW_LEFT = 0
CONTROL_YAW_RIGHT = 1
CONTROL_THROTTLE = 8

function Update(Iarg)
    I = Iarg
    
    I:TellAiThatWeAreTakingControl()
    
    if I:GetNumberOfMainframes() == 0 then
        return
    end
    
    local closestTargetPosition = nil
    
    for targetIndex = 0, I:GetNumberOfTargets(0) - 1 do
        local targetPosition = I:GetTargetPositionInfo(0, targetIndex)
        if closestTarget == nil or targetPosition.Range < closestTargetPosition.Range then
            closestTargetPosition = targetPosition
        end
    end
    
    if closestTargetPosition == nil then
        I:RequestControl(CONTROL_MODE_WATER, CONTROL_THROTTLE, 1)
        I:RequestControl(CONTROL_MODE_WATER, CONTROL_YAW_LEFT, 0.01)
        I:Log('no target')
        return
    end
    
    
    
    
    if closestTargetPosition.Range < 1000 then
        I:RequestControl(CONTROL_MODE_WATER, CONTROL_THROTTLE, 1)
        I:Log('overfly')
    else
        if closestTargetPosition.Range > 12000 then
            I:RequestControl(CONTROL_MODE_WATER, CONTROL_THROTTLE, 1)
            I:Log('close')
        else
            I:RequestControl(CONTROL_MODE_WATER, CONTROL_THROTTLE, 0)
            I:Log('hold')
        end
        
        if closestTargetPosition.Azimuth > angleThreshold then
            I:RequestControl(CONTROL_MODE_WATER, CONTROL_YAW_LEFT, 1)
            I:Log('left')
        elseif closestTargetPosition.Azimuth < -angleThreshold then
            I:RequestControl(CONTROL_MODE_WATER, CONTROL_YAW_RIGHT, 1)
            I:Log('right')
        end
    end
end
