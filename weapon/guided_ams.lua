-- Detonate interceptors after this time to save resources.
interceptorLifetime = 15.0
-- Estimated turn radius of interceptors.
interceptorTurnRadius = 100.0

-- How far interceptors can destroy missiles.
interceptorRadius = 20.0
-- Which mainframe is providing warning info.
interceptorMainframeIndex = 0

maximumVelocityPredictionTime = 1.0

-- Table of known enemy missiles.
numberOfWarnings = 0
warningsByIndex = {}
warningsById = {}
-- Interceptor targets: interceptor.Id -> target.Id
previousInterceptorTargets = {}
currentInterceptorTargets = {}
-- The I in Update(I).
Info = nil

interceptorMainframePosition = Vector3()

function UpdateWarnings()
    -- Called first. This updates the warning table. Elements are warningIndex -> warningInfo.
    warningsByIndex = {}
    warningsById = {}
    for mainframeIndex = 0, Info:GetNumberOfMainframes() - 1 do
        numberOfWarnings = Info:GetNumberOfWarnings(mainframeIndex)
        if numberOfWarnings > 0 then
            for warningIndex = 0, numberOfWarnings - 1 do
                warning = Info:GetMissileWarning(mainframeIndex, warningIndex)
                warningsByIndex[warningIndex] = warning
                warningsById[warning.Id] = warning
            end
            interceptorMainframeIndex = mainframeIndex
            return
        end
    end
end

function ControlInterceptors()
    -- Controls interceptors.
    for transceiverIndex = 0, Info:GetLuaTransceiverCount() - 1 do
        local transceiver = Info:GetLuaTransceiverInfo(transceiverIndex)
        for interceptorIndex = 0, Info:GetLuaControlledMissileCount(transceiverIndex) - 1 do
            local interceptor = Info:GetLuaControlledMissileInfo(transceiverIndex, interceptorIndex)
            if Info:IsLuaControlledMissileAnInterceptor(transceiverIndex, interceptorIndex) then
                if interceptor.TimeSinceLaunch > interceptorLifetime then
                    Info:DetonateLuaControlledMissile(transceiverIndex, interceptorIndex)
                else
                    Info:SetLuaControlledMissileInterceptorStandardGuidanceOnOff(transceiverIndex, interceptorIndex, false)
                    -- Aim.
                    local target = SelectInterceptorAimTarget(transceiver, interceptor)
                    local aimPoint = SelectInterceptorAimPoint(transceiver, interceptor, target)
                    Info:SetLuaControlledMissileAimPoint(transceiverIndex, interceptorIndex, aimPoint.x, aimPoint.y, aimPoint.z)
                    -- Fuse.
                    local targetIndex = SelectInterceptorFuseTarget(interceptor)
                    if targetIndex ~= nil then
                        Info:SetLuaControlledMissileInterceptorTarget(transceiverIndex, interceptorIndex, interceptorMainframeIndex, targetIndex)
                    end
                end
            end
        end
    end
    
    previousInterceptorTargets = currentInterceptorTargets
end

function SelectInterceptorAimTarget(transceiver, interceptor)
    local target = nil
    local previousTarget = warningsById[previousInterceptorTargets[interceptor.Id]]
    if previousTarget then
        target = previousTarget
    else
        -- Select a new target.
        target = warningsByIndex[interceptor.Id % numberOfWarnings]
    end
    
    if target ~= nil then
        currentInterceptorTargets[interceptor.Id] = target.Id
    end
    return target
end

function SelectInterceptorAimPoint(transceiver, interceptor, target)
    if target == nil then
        return transceiver.Position + Vector3.up * interceptorTurnRadius
    else
        local interceptTime = InterceptTime(interceptor.Position, interceptor.Velocity.magnitude, target)
        if interceptTime == nil or interceptTime > maximumVelocityPredictionTime then
            interceptTime = maximumVelocityPredictionTime
        end
        return target.Position + target.Velocity * interceptTime
    end
end

function InterceptTime(missilePosition, missileSpeed, target)
    -- Computes the time needed to intercept the target.
    
    local relativePosition = target.Position - missilePosition
    
    -- Solve quadratic equation.
    local a = target.Velocity.sqrMagnitude - missileSpeed * missileSpeed
    local b = 2 * Vector3.Dot(target.Velocity, relativePosition)
    local c = relativePosition.sqrMagnitude
    local vertex = -b / (2 * a)
    local discriminant = vertex*vertex - c / a
    if discriminant > 0 then
        local width = math.sqrt(discriminant)
        local lower = vertex - width
        local upper = vertex + width
        return (lower >= 0 and lower) or (upper >= 0 and upper) or nil
    else
        return nil
    end
end

function SelectInterceptorFuseTarget(interceptor)
    -- Selects the nearest known missile within destruction radius.
    local resultIndex = nil
    local minDistance = interceptorRadius
    for warningIndex, warning in ipairs(warningsByIndex) do
        if warning.Valid then
            local thisDistance = Vector3.Distance(warning.Position, interceptor.Position) 
            if thisDistance < minDistance then
                minDistance = thisDistance
                resultIndex = warningIndex
            end
        end
    end
    return resultIndex
end

function Update(I)
    Info = I
    UpdateWarnings()
    ControlInterceptors()
end