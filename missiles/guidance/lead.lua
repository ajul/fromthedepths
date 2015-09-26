-- Which mainframe's target to use.
mainframeToUse = 0

-- Minimum and maximum lead factors. 
-- 0 aims directly at the target (pure pursuit).
-- 1 computes lead. 
-- Intermediate values linearly interpolate.
-- A lead factor will be chosen based on the missile id.
leadFactorMin = 0
leadFactorMax = 1
leadFactorRange = leadFactorMax - leadFactorMin
-- The size of lead factor increments is leadFactorRange / leadFactorResolution.
leadFactorResolution = 8

-- Minimum effective time to intercept.
minTime = 1/40

function InterceptTime(missilePosition, missileSpeed, targetPosition, targetVelocity)
    -- Computes the time needed to intercept the target.
    
    relativePosition = targetPosition - missilePosition
    
    -- Time for the target to reach closest approach to the missile's current position. May be negative.
    closestTime = Vector3.Dot(relativePosition, targetVelocity.normalized) / targetVelocity.magnitude
    closestApproach = relativePosition + targetVelocity * closestTime
    
    -- Solve quadratic equation.
    a = targetVelocity.sqrMagnitude - missileSpeed * missileSpeed
    b = 2 * closestApproach * targetVelocity.magnitude
    c = relativePosition.sqrMagnitude
    vertex = -b / (2 * a)
    discriminant = vertex*vertex - c
    if discriminant > 0
        width = math.sqrt(discriminant)
        lower = vertex - width
        upper = vertex + width
        return (lower >= 0 and lower) or (upper >= 0 and upper) or 0
    else
        return 0
    end
end

function LeadPosition(missile, targetInfo)
    -- missile: MissileWarningInfo
    -- target: TargetInfo, TargetPositionInfo, or MissileWarningInfo of the target
    leadFactor = (missile.Id % (leadFactorResolution + 1)) / leadFactorResolution
    
    t = InterceptTime(missile.Position, missile.Velocity.magnitude, targetInfo.Position, targetInfo.Velocity)
    t = math.max(minTime, t  * leadFactor)
    return targetPosition + targetVelocity * t
end

function Update(I)
    target = I:GetTargetInfo(mainframeIndex, 0)
    for t = 0, I:GetLuaTransceiverCount() - 1 do
        for m = 0, I:GetLuaControlledMissileCount(t) do
            missile = I:GetLuaControlledMissileInfo(t, m)
            leadPosition = LeadPosition(missile, target)
            I:SetLuaControlledMissileAimPoint(t, m, leadPosition.x, leadPosition.y, leadPosition.z)
        end
    end
end
