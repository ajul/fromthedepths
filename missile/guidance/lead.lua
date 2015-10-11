-- Which mainframe's target to use.
mainframeToUse = 0

-- Minimum and maximum lead factors. 
-- 0 aims directly at the target (pure pursuit).
-- 1 computes lead. 
-- Intermediate values linearly interpolate.
-- A lead factor will be chosen based on the missile id.
leadFactorMin = 0.5
leadFactorMax = 1.0
leadFactorRange = leadFactorMax - leadFactorMin
-- The size of lead factor increments is leadFactorRange / leadFactorResolution.
leadFactorResolution = 8

detonationLookaheadTime = 0.25
detonationRadius = 5

-- Time for one frame.
frameTime = 1/40
-- If intercept time is above this value, do a pure pursuit.
terminalGuidanceTime = 15
-- Lowest height to target before terminal guidance
minTravelHeight = terminalGuidanceTime * 2

tick = 0
cleanupPeriod = 40

missileCullTime = 5
missileCullVelocityAir = 65
missileCullVelocityWater = 10

missileTargets = {}
missileTicks = {}

function SelectNewTarget(I, missile)
    -- Choose a target using modulus
    numTargets = I:GetNumberOfTargets(mainframeToUse)
    targetIndex = missile.Id % numTargets
    targetInfo = I:GetTargetInfo(mainframeToUse, targetIndex)
    missileTargets[missile.Id] = targetInfo.Id
    return targetInfo
end

function SelectTarget(I, t, m, missile)
    if missileTargets[missile.Id] == nil then
        return SelectNewTarget(I, missile)
    end
        
    for targetIndex = 0, I:GetNumberOfTargets(mainframeToUse) - 1 do
        targetInfo = I:GetTargetInfo(mainframeToUse, targetIndex)
        if targetInfo.Id == missileTargets[missile.Id] then
            return targetInfo
        end
    end
    
    return SelectNewTarget(I, missile)
end

function InterceptTime(missilePosition, missileSpeed, targetPosition, targetVelocity)
    -- Computes the time needed to intercept the target.
    
    relativePosition = targetPosition - missilePosition
    
    -- Solve quadratic equation.
    a = targetVelocity.sqrMagnitude - missileSpeed * missileSpeed
    b = 2 * Vector3.Dot(targetVelocity, relativePosition)
    c = relativePosition.sqrMagnitude
    vertex = -b / (2 * a)
    discriminant = vertex*vertex - c / a
    if discriminant > 0 then
        width = math.sqrt(discriminant)
        lower = vertex - width
        upper = vertex + width
        return (lower >= 0 and lower) or (upper >= 0 and upper) or 0
    else
        return 0
    end
end

function LeadPosition(missile, targetInfo)
    -- Computes what position to lead the target at.
    -- missile: MissileWarningInfo
    -- target: TargetInfo, TargetPositionInfo, or MissileWarningInfo of the target
    
    -- Compute the proportion of lead to use.
    leadAlpha = (missile.Id % (leadFactorResolution + 1)) / leadFactorResolution
    leadFactor = leadFactorMin + leadAlpha * leadFactorRange
    
    t = InterceptTime(missile.Position, missile.Velocity.magnitude, targetInfo.AimPointPosition, targetInfo.Velocity)
    
    if t >= terminalGuidanceTime then
        return Vector3(targetInfo.AimPointPosition.x, math.max(minTravelHeight, targetInfo.AimPointPosition.y), targetInfo.AimPointPosition.z)
    else
        t = math.max(0, t * leadFactor)
    end
    t = t + frameTime -- add one frame
    return targetInfo.AimPointPosition + targetInfo.Velocity * t
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
    target = I:GetTargetInfo(mainframeToUse, 0)
    for t = 0, I:GetLuaTransceiverCount() - 1 do
        for m = 0, I:GetLuaControlledMissileCount(t) - 1 do
            missile = I:GetLuaControlledMissileInfo(t, m)
            if missile.TimeSinceLaunch > missileCullTime and (missile.Velocity.magnitude < missileCullVelocityWater or (missile.Velocity.magnitude < missileCullVelocityAir and missile.Position.y > 50)) then
                I:DetonateLuaControlledMissile(t, m)
            else
                target = SelectTarget(I, t, m, missile)
                if target.Valid then
                    if Vector3.Distance(missile.Position + missile.Velocity * detonationLookaheadTime, target.AimPointPosition + target.Velocity * detonationLookaheadTime) < detonationRadius then
                        I:DetonateLuaControlledMissile(t, m)
                    end
                    leadPosition = LeadPosition(missile, target)
                    I:SetLuaControlledMissileAimPoint(t, m, leadPosition.x, leadPosition.y, leadPosition.z)
                else
                    I:SetLuaControlledMissileAimPoint(t, m, missile.Position.x, 1000 * missile.Position.y, missile.Position.z)
                end
                
                missileTicks[missile.Id] = tick
            end
        end
    end
    
    if tick % cleanupPeriod == 0 then
        Cleanup()
    end
end
