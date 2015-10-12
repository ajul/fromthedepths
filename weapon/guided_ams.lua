loiterAltitude = 100.0

-- Maximum seconds of lead to use.
maximumInterceptPredictionTime = 5.0

-- Detonate interceptors after this time to save resources.
interceptorLifetime = 15.0

-- How far interceptors can destroy missiles.
interceptorRadius = 20.0
-- Which mainframe is providing warning info.
interceptorMainframeIndex = 0

-- Table of known enemy missiles.
warnings = {}
-- The I in Update(I).
Info = nil

interceptorMainframePosition = Vector3()

function UpdateWarnings()
    -- Called first. This updates the warning table. Elements are warningIndex -> warningInfo.
    warnings = {}
    for mainframeIndex = 0, Info:GetNumberOfMainframes() - 1 do
        local numberOfWarnings = Info:GetNumberOfWarnings(mainframeIndex)
        if numberOfWarnings > 0 then
            for warningIndex = 0, numberOfWarnings - 1 do
                warnings[warningIndex] = Info:GetMissileWarning(mainframeIndex, warningIndex)
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
                    local aimPosition = SelectInterceptorAimTarget(transceiver, interceptor)
                    Info:SetLuaControlledMissileAimPoint(transceiverIndex, interceptorIndex, aimPosition.x, aimPosition.y, aimPosition.z)
                    -- Fuse.
                    local targetIndex = SelectInterceptorFuseTarget(interceptor)
                    if targetIndex ~= nil then
                        Info:SetLuaControlledMissileInterceptorTarget(transceiverIndex, interceptorIndex, interceptorMainframeIndex, targetIndex)
                    end
                end
            end
        end
    end
end

function SelectInterceptorAimTarget(transceiver, interceptor)
    -- Persistent selection?
    local target = nil
    local bestScore = -1000
    for warningIndex, warning in ipairs(warnings) do
        if warning.Valid then
            local score = InterceptorTargetScore(interceptor, warning)
            if score > bestScore then
                target = warning
                bestScore = score
            end
        end
    end
    
    if target ~= nil then
        -- Predict interception.
        local interceptTime = InterceptTime(transceiver.Position, interceptor.Velocity.magnitude, target)
        if interceptTime == nil  or interceptTime > maximumInterceptPredictionTime then
            interceptTime = maximumInterceptPredictionTime
        end
        local aimPosition = target.Position + target.Velocity * interceptTime
        return aimPosition
    end
    
    -- Loiter above the launcher.
    -- Or fly towards origin of enemy missiles?
    local aimPosition = Vector3(transceiver.Position.x, transceiver.Position.y + loiterAltitude, transceiver.Position.z)
    
    return aimPosition
end

function InterceptorTargetScore(interceptor, warning)
    -- Higher is better.
    
    relativePosition = warning.Position - interceptor.Position
    
    -- Temporary hax: things we are pointing towards
    return Vector3.Dot(interceptor.Velocity.normalized, relativePosition.normalized)
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
    for warningIndex, warning in ipairs(warnings) do
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