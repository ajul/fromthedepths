-- Time between messages.
messagePeriod = 1.0

previousMessageTime = 0.0

function Update(I)
    currentTime = I:GetGameTime()
    if currentTime < previousMessageTime + messagePeriod then
        return
    end
    
    previousMessageTime = currentTime
    
    if I:GetNumberOfMainframes() == 0 then
        I:Log('No mainframe found!')
        I:LogToHud('No mainframe found!')
        return
    end

    -- Find closest target.
    local closestTarget = nil

    for targetIndex = 0, I:GetNumberOfTargets(0) - 1 do
        target = I:GetTargetPositionInfo(0, targetIndex)
        if closestTarget == nil or target.Range < closestTarget.Range then
            closestTarget = target
        end
    end
    
    -- Display information.
    if closestTarget == nil then
        I:Log('No hostiles detected.')
        I:LogToHud('No hostiles detected.')
    else
        oclock = math.ceil(-closestTarget.Azimuth / 30 - 0.5)
        if oclock < 1 then
            oclock = oclock + 12
        end
        message = string.format([[Hostile %d o'clock, distance %d m, altitude %d m]], oclock, closestTarget.Range, closestTarget.AltitudeAboveSeaLevel)
        I:Log(message)
        I:LogToHud(message)
    end
end
