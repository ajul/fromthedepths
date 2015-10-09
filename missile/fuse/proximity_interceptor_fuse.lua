-- proximity fuse for interceptors; simply targets the nearest known missile

mainframeIndex = 0
cullTime = 5
warningInfos = {}

function UpdateWarnings(I)
    warnings = {}
    for warningIndex = 0, I:GetNumberOfWarnings(mainframeIndex) do
        warningInfos[warningIndex] = I:GetMissileWarning(mainframeIndex, warningIndex)
    end
end

function SelectInterceptorTarget(missileInfo)
    -- selects the nearest known missile
    minDistance = 1000
    for warningIndex, warningInfo in ipairs(warningInfos) do
        thisDistance = Vector3.Distance(warningInfo.Position, missileInfo.Position) 
        if thisDistance < minDistance then
            minDistance = thisDistance
            resultIndex = warningIndex
        end
    end
    return resultIndex
end

function Update(I)
    for transceiverIndex = 0, I:GetLuaTransceiverCount() - 1 do
        for missileIndex = 0, I:GetLuaControlledMissileCount(transceiverIndex) - 1 do
            missileInfo = I:GetLuaControlledMissileInfo(transceiverIndex, missileIndex)
            if I:IsLuaControlledMissileAnInterceptor(transceiverIndex, missileIndex) then
                targetIndex = SelectInterceptorTarget(missileInfo)
                if targetIndex ~= nil then
                    I:SetLuaControlledMissileInterceptorTarget(transceiverIndex, missileIndex, mainframeIndex, targetIndex)
                end
            end
            if missileInfo.TimeSinceLaunch > cullTime then
                I:DetonateLuaControlledMissile(transceiverIndex, missileIndex)
            end
        end
    end
end
