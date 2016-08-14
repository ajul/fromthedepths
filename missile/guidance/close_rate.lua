targetingMainframe = 0
velocityPredictTime = 10

minAltitude = 3
throttleUpdatePeriod = 0.5 -- how often to update throttle in ticks
reserveFuelFraction = 0.1
cullDelay = 1.0 -- time to wait after fuel expended before culling

gameTime = 0
lastCleanup = 0
cleanupPeriod = 1.0

numberOfTargets = 0
targetsByIndex = {}
targetsById = {}

missileDatas = {}

I = nil

function InterceptTime(missile, target)
    local relativePosition = target.Position - missile.Position
    local relativeVelocity = target.Velocity - missile.Velocity
    local closeRate = -Vector3.Dot(relativeVelocity, relativePosition.normalized)
    if closeRate <= 0 then
        return 0
    else
        return relativePosition.magnitude / closeRate
    end
end

function ComputeLead(missile, target)
    local closeTime = InterceptTime(missile, target)
    local result = target.AimPointPosition
    if not closeTime then
        return result, closeTime
    end
    
    if closeTime < velocityPredictTime then
        result = result + target.Velocity * closeTime
    end
    
    return result, closeTime
end

function UpdateTargets()
    targetsByIndex = {}
    targetsById = {}
    numberOfTargets = I:GetNumberOfTargets(targetingMainframe)
    for targetIndex = 0, numberOfTargets - 1 do
        target = I:GetTargetInfo(targetingMainframe, targetIndex)
        -- insert new info
        targetsByIndex[targetIndex] = target
        targetsById[target.Id] = target
    end
end

function SelectTarget(I, missile)
    local target = targetsById[missileDatas[missile.Id].target]
    if target then
        return target
    end
    target = targetsByIndex[missile.Id % numberOfTargets] 
    missileDatas[missile.Id].target = target
    return target
end

function SetNewThrottle(transceiverIndex, missileIndex, missileData, newThrottle)
    if missileData.fuel > 0 then
        local missileParts = I:GetMissileInfo(transceiverIndex, missileIndex)
        
        missileData.fuel = missileData.fuel - missileData.throttle * (gameTime - missileData.lastThrottleUpdate)
        
        for k, v in pairs(missileParts.Parts) do
            if string.find(v.Name, 'variable') then
                v:SendRegister(2, newThrottle)
                break
            end
        end
        
        missileData.throttle = newThrottle
        missileData.lastThrottleUpdate = gameTime
    elseif gameTime >= missileData.lastThrottleUpdate + cullDelay then
        I:DetonateLuaControlledMissile(transceiverIndex, missileIndex)
    end
end

function Cleanup()
    for k, v in pairs(missileDatas) do
        if v.gameTime ~= gameTime then
            missileDatas[k] = nil
        end
    end
end

function Update(Iarg)
    I = Iarg
    gameTime = I:GetGameTime()
    
    UpdateTargets()
    
    for transceiverIndex = 0, I:GetLuaTransceiverCount() - 1 do
        for missileIndex = 0, I:GetLuaControlledMissileCount(transceiverIndex) - 1 do
            local missile = I:GetLuaControlledMissileInfo(transceiverIndex, missileIndex)
            
            -- Initialization.
            if missileDatas[missile.Id] == nil then
                local fuel = 0
                local initialThrottle = 0
                local missileParts = I:GetMissileInfo(transceiverIndex, missileIndex) -- EXPENSIVE!!!
                for k, v in pairs(missileParts.Parts) do
                    if string.find(v.Name, 'fuel') then
                        fuel = fuel + 5000
                    elseif string.find(v.Name, 'variable') then
                        initialThrottle = initialThrottle + v.Registers[2]
                    end
                end
                
                missileDatas[missile.Id] = {
                    fuel = fuel,
                    -- reserveFuel = fuel * reserveFuelFraction,
                    throttle = initialThrottle,
                    defaultThrottle = initialThrottle,
                    lastThrottleUpdate = gameTime,
                }
            end

            local target = SelectTarget(I, missile)
            
            local missileData = missileDatas[missile.Id]
            
            if target and target.Valid then
                local leadPosition, closeTime = ComputeLead(missile, target)
                
                I:SetLuaControlledMissileAimPoint(transceiverIndex, missileIndex, 
                                                  leadPosition.x, math.max(leadPosition.y, minAltitude), leadPosition.z)
                
                if gameTime >= missileData.lastThrottleUpdate + throttleUpdatePeriod then

                    local newThrottle
                    if closeTime <= 0 then
                        newThrottle = 0
                    else
                        newThrottle = (1.0 - reserveFuelFraction) * missileData.fuel / math.max(closeTime, throttleUpdatePeriod)
                    end
                    newThrottle = math.max(newThrottle, missileData.defaultThrottle)
                    
                    SetNewThrottle(transceiverIndex, missileIndex, missileData, newThrottle)
                end
            else
                -- No target found.
                I:SetLuaControlledMissileAimPoint(transceiverIndex, missileIndex, missile.Position.x, 1000 * missile.Position.y, missile.Position.z)
                
                if gameTime >= missileData.lastThrottleUpdate + throttleUpdatePeriod then
                    SetNewThrottle(transceiverIndex, missileIndex, missileData, 50)
                end
            end
            
            missileData.gameTime = gameTime
        end
    end
    
    if gameTime >= lastCleanup + cleanupPeriod then
        Cleanup()
    end
end

function LogBoth(s)
    I:Log(s)
    I:LogToHud(s)
end
