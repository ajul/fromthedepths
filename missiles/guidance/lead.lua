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

function InterceptTime(missilePosition, missileSpeed, targetPosition, targetVelocity)
    -- Computes the time needed to intercept the target.
    
    relativePosition = targetPosition - missilePosition
    
    -- Time for the target to reach closest approach to the missile's current position. May be negative.
    closestTime = -Vector3.Dot(relativePosition, targetVelocity.normalized) / targetVelocity.magnitude
    -- Distance at closest approach.
    closestApproach = relativePosition + targetVelocity * closestTime
    
    -- Solve quadratic equation.
    a = targetVelocity.sqrMagnitude - missileSpeed * missileSpeed
    b = 2 * closestApproach.magnitude * targetVelocity.magnitude
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
    -- missile: MissileWarningInfo
    -- target: TargetInfo, TargetPositionInfo, or MissileWarningInfo of the target
    
    -- Compute the proportion of lead to use.
    leadAlpha = (missile.Id % (leadFactorResolution + 1)) / leadFactorResolution
    leadFactor = leadFactorMin + leadAlpha * leadFactorRange
    
    t = InterceptTime(missile.Position, missile.Velocity.magnitude, targetInfo.AimPointPosition, targetInfo.Velocity)
    
    if t >= terminalGuidanceTime then
        t = 0
    else
        t = math.max(0, t * leadFactor)
    end
    t = t + frameTime -- add one frame
    return targetInfo.AimPointPosition + targetInfo.Velocity * t
end

function Update(I)
    target = I:GetTargetInfo(mainframeToUse, 0)
    for t = 0, I:GetLuaTransceiverCount() - 1 do
        for m = 0, I:GetLuaControlledMissileCount(t) - 1 do
            missile = I:GetLuaControlledMissileInfo(t, m)
            if Vector3.Distance(missile.Position + missile.Velocity * detonationLookaheadTime, target.AimPointPosition) < detonationRadius then
                I:DetonateLuaControlledMissile(t, m)
            else
                leadPosition = LeadPosition(missile, target)
                I:SetLuaControlledMissileAimPoint(t, m, leadPosition.x, leadPosition.y, leadPosition.z)
            end
        end
    end
end
