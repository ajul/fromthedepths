-- Anti-missile script, made to be relatively cheap to compute.

-- Maximum number of interceptors to assign to each incoming missile.
-- Interceptors will be assigned evenly up to this number.
maximumInterceptorsPerWarning = 4

-- Id of the last interceptor fired from each transceiver.
lastInterceptorIds = {}
warningMainframeIndex = 0
I = nil

-- Id -> {Index, NumberOfAssignedInterceptors}
warnings = {}

warningsUpToDate = false

function Update(Iarg)
    I = Iarg
    warningsUpToDate = false
    TargetInterceptors()
end

function UpdateWarnings()
    -- Called first. This updates the warning table. Elements are warningIndex -> warningInfo.
    local newWarnings = {}
    for mainframeIndex = 0, Info:GetNumberOfMainframes() - 1 do
        numberOfWarnings = Info:GetNumberOfWarnings(mainframeIndex)
        if numberOfWarnings > 0 then
            warningMainframeIndex = mainframeIndex
            for warningIndex = 0, numberOfWarnings - 1 do
                warningInfo = Info:GetMissileWarning(mainframeIndex, warningIndex)
                previousWarning = warnings[warningInfo.Id]
                warning = {
                    Index = warningIndex,
                    NumberOfAssignedInterceptors = (previousWarning and previousWarning.NumberOfAssignedInterceptors) or 0
                }
                newWarnings[warningInfo.Id] = warning
            end
            warnings = newWarnings
            warningsUpToDate = true
            return
        end
    end
end

function TargetInterceptors()
    for transceiverIndex = 0, I:GetLuaTransceiverCount() - 1 do
        local interceptorIndex = I:GetLuaControlledMissileCount(transceiverIndex) - 1
        if I:IsLuaControlledMissileAnInterceptor(transceiverIndex, interceptorIndex) then
            local interceptor = I:GetLuaControlledMissileInfo(transceiverIndex, interceptorIndex)
            if interceptor.Id ~= lastInterceptorIds[transceiverIndex] then
                local selected = TakeNextInterceptorTarget()
                if selected ~= nil then
                    --I:LogToHud(string.format("Assigning interceptor id %d to warning index %d", interceptor.Id, selected.Index))
                    I:SetLuaControlledMissileInterceptorTarget(transceiverIndex, interceptorIndex, warningMainframeIndex, selected.Index)
                    lastInterceptorIds[transceiverIndex] = interceptor.Id
                end
            end
        end
    end
end

function TakeNextInterceptorTarget()
    if not warningsUpToDate then
        UpdateWarnings()
    end
    local fewestInterceptorsAssigned = maximumInterceptorsPerWarning
    local selected = nil
    for warningId, warning in pairs(warnings) do
        if warning.NumberOfAssignedInterceptors < fewestInterceptorsAssigned then
            selected = warning
            fewestInterceptorsAssigned = selected.NumberOfAssignedInterceptors
        end
    end
    if selected ~= nil then
        selected.NumberOfAssignedInterceptors = selected.NumberOfAssignedInterceptors + 1
    end
    return selected
end
