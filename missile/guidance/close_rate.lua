targetingMainframe = 0
velocityPredictTime = 10

detonationLookaheadTime = 0.25
detonationRadius = 5

tick = 0
cleanupPeriod = 40

missileCullTime = 5
missileCullVelocity = 40

numberOfTargets = 0
targetsByIndex = {}
targetsById = {}

missileTargets = {}
missileTicks = {}

function InterceptTime(missile, target)
    relativePosition = target.Position - missile.Position
    relativeVelocity = target.Velocity - missile.Velocity
    closeRate = -Vector3.Dot(relativeVelocity, relativePosition.normalized)
    if closeRate <= 0 then
        return 0
    else
        return relativePosition.magnitude / closeRate
    end
end

function LeadPosition(missile, target)
    t = InterceptTime(missile, target)
    result = target.Position
    if not t then
        return result
    end
    
    if t < velocityPredictTime then
        result = result + target.Velocity * t
    end
    
    return result
end

function UpdateTargets(I)
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
    local target = targetsById[missileTargets[missile.Id]]
    if target then
        return target
    end
    target = targetsByIndex[missile.Id % numberOfTargets] 
    missileTargets[missile.Id] = target
    return target
end

function Cleanup()
    for k, v in pairs(missileTicks) do
        if v ~= tick then
            missileTargets[k] = nil
            missileTicks[k] = nil
        end
    end
end

function Update(I)
    tick = tick + 1
    
    UpdateTargets(I)
    
    for transceiverIndex = 0, I:GetLuaTransceiverCount() - 1 do
        for missileIndex = 0, I:GetLuaControlledMissileCount(transceiverIndex) - 1 do
            missile = I:GetLuaControlledMissileInfo(transceiverIndex, missileIndex)
            if missile.TimeSinceLaunch > missileCullTime and (missile.Velocity.magnitude < missileCullVelocity) then
                I:DetonateLuaControlledMissile(transceiverIndex, missileIndex)
            else
                target = SelectTarget(I, missile)
                if target and target.Valid then
                    if Vector3.Distance(missile.Position + missile.Velocity * detonationLookaheadTime, target.AimPointPosition + target.Velocity * detonationLookaheadTime) < detonationRadius then
                        I:DetonateLuaControlledMissile(transceiverIndex, missileIndex)
                    end
                    leadPosition = LeadPosition(missile, target)
                    I:SetLuaControlledMissileAimPoint(transceiverIndex, missileIndex, leadPosition.x, leadPosition.y, leadPosition.z)
                else
                    I:SetLuaControlledMissileAimPoint(transceiverIndex, missileIndex, missile.Position.x, 1000 * missile.Position.y, missile.Position.z)
                end
                
                missileTicks[missile.Id] = tick
            end
        end
    end
    
    if tick % cleanupPeriod == 0 then
        Cleanup()
    end
end
