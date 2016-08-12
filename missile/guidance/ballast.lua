maxTargetHeight = 2

maxRunningHeight = -6

ballastUpdatePeriod = 40 --frames
ballastTime = 2.0
ballastWidth = 0.05

targetingMainframe = 0

tick = 0
cleanupPeriod = 40

targetsByIndex = {}
targetsById = {}

missileTargets = {}
missileTicks = {}

I = nil

function Update(Iarg)
    I = Iarg
    tick = tick + 1
    
    UpdateTargets()
    
    for transceiverIndex = 0, I:GetLuaTransceiverCount() - 1 do
        for missileIndex = 0, I:GetLuaControlledMissileCount(transceiverIndex) - 1 do
            local missile = I:GetLuaControlledMissileInfo(transceiverIndex, missileIndex)
            

            local target = SelectTarget(missile)
            
            local x, y, z
            
            if target ~= nil then
                x = target.AimPointPosition.x
                y = math.min(target.AimPointPosition.y, maxRunningHeight)
                z = target.AimPointPosition.z
            else
                x = missile.Position.x + 1000.0 * missile.Velocity.x
                y = maxRunningHeight
                z = missile.Position.z + 1000.0 * missile.Velocity.z
                -- LogBoth('No target!')
            end
            
            I:SetLuaControlledMissileAimPoint(transceiverIndex, missileIndex, x, missile.Position.y, z)
            local relativeHeight =  y - missile.Position.y
            local buoyancy = (relativeHeight - missile.Velocity.y * ballastTime) / ballastWidth
            
            if (tick + missile.Id) % ballastUpdatePeriod == 0 then
                local missileParts = I:GetMissileInfo(transceiverIndex, missileIndex) -- EXPENSIVE!!!
                for k, v in pairs(missileParts.Parts) do
                    if string.find(v.Name, 'ballast') then
                        v:SendRegister(2, buoyancy)
                    end
                end
            end
            
            missileTicks[missile.Id] = tick
        end
    end
    
    if tick % cleanupPeriod == 0 then
        Cleanup()
    end
end

function UpdateTargets()
    targetsByIndex = {}
    targetsById = {}
    local numberOfTargets = I:GetNumberOfTargets(targetingMainframe)
    for targetIndex = 0, numberOfTargets - 1 do
        local target = I:GetTargetInfo(targetingMainframe, targetIndex)
        -- insert new info
        targetsByIndex[#targetsByIndex + 1] = target
        targetsById[target.Id] = target
    end
end

function SelectTarget(missile)
    local target = targetsById[missileTargets[missile.Id]]
    if target then
        return target
    end
    target = targetsByIndex[(missile.Id % #targetsByIndex) + 1] 
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

function LogBoth(s)
    I:Log(s)
    I:LogToHud(s)
end