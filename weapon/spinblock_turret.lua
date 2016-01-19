-- Weapon slot to use. Only cannons will be controlled regardless.
weaponSlot = 1

-- Restrict the maximum azimuth of spinblock rotation. This is in absolute value degrees relative to the neutral facing.
-- Neutral facing is determined as if drawing an 'X' on each face of the ship's bounding box and seeing which sector the spinblock falls in.
maximumAzimuths = {
    x = 180, -- turrets that face right/left at neutral
    y = 180, -- turrets that face up/down at neutral
    z = 180, -- turrets that face forward/back at neutral
}

-- Don't fire beyond this range.
maximumRange = 3000

-- What order polynomial to use. 1 = linear (similar to stock), 2 = quadratic (acceleration)
predictionOrder = 3

-- Extra time to lead the target by.
extraLeadTime = 2/40

-- How many iterations to refine the aim estimate.
leadIterations = 16

-- Limit the spin speed for aesthetic purposes. Radians per second.
maximumSpinSpeed = 30

-- Gravitational acceleration.
g = 9.81

-- The I in Update(I).
I = nil

-- Normal frame duration.
nominalFrameDuration = 1/40

-- Time and duration of the current frame.
frameTime = 0
frameDuration = 1/40

-- Our own position and local frame.
myPosition = Vector3.zero
myAngularVelocity = Vector3.zero
myVectors = {
    x = Vector3.right,
    y = Vector3.up,
    z = Vector3.forward,
}

-- Used for computing azimuth restrictions. Will be set only once.
myLocalCenter = nil

-- Used for determining neutral facing. Will be set only once.
mySize = Vector3.one

-- Current target.
target = nil

-- Position, velocity, acceleration... of the current target.
targetDerivatives = {}

-- Velocity is special because cannon projectiles inherit our velocity.
relativeVelocity = Vector3.zero

-- Weapon speed for computing spinner lead.
spinnerWeaponSpeed = 400

WEAPON_TYPE_CANNON = 0

AXES = {'x', 'y', 'z'}

function Update(Iarg)
    I = Iarg
    
    UpdateInfo()
    
    for spinnerIndex = 0, I:GetSpinnerCount() - 1 do
        if not I:IsSpinnerDedicatedHelispinner(spinnerIndex) then
            AimSpinner(spinnerIndex)
        end
    end
end

function UpdateInfo()
    local newFrameTime = I:GetGameTime()
    frameDuration = newFrameTime - frameTime
    frameTime = newFrameTime
    
    myPosition = I:GetConstructPosition()
    myAngularVelocity = I:GetAngularVelocity()
    myVectors.x = I:GetConstructRightVector()
    myVectors.y = I:GetConstructUpVector()
    myVectors.z = I:GetConstructForwardVector()
    
    if myLocalCenter == nil then
        -- myLocalCenter = ComputeLocalPosition(I:GetConstructCenterOfMass())
        local maxDimensions = I:GetConstructMaxDimensions()
        local minDimensions = I:GetConstructMinDimensions()
        myLocalCenter = (maxDimensions + minDimensions) / 2
        mySize = maxDimensions - minDimensions
    end

    -- Find a target. Prefer AIs with scores, and take the last AI otherwise.
    local newTarget = nil
    local targetingMainframeIndex = nil
    for mainframeIndex = 0, I:GetNumberOfMainframes() - 1 do
        local firstTarget = I:GetTargetInfo(mainframeIndex, 0)
        if firstTarget.Valid then
            if newTarget == nil or firstTarget.Score ~= 0 then
                newTarget = firstTarget
                targetingMainframeIndex = mainframeIndex
            end 
        end
    end
    
    -- Limit range.
    if newTarget ~= nil and Vector3.Distance(newTarget.Position, myPosition) > maximumRange then
        newTarget = nil
    end

    if newTarget ~= nil then
        -- compute derivatives
        local newTargetDerivatives = { newTarget.Position }
        if (target ~= nil and newTarget.Id == target.Id) then
            for i = 1, math.min(#newTargetDerivatives, predictionOrder) do
                newTargetDerivatives[i+1] = (newTargetDerivatives[i] - targetDerivatives[i]) / frameDuration
            end
        end
        targetDerivatives = newTargetDerivatives
    else
        -- No target.
        targetDerivatives = {}
    end
    
    relativeVelocity = (targetDerivatives[2] or Vector3.zero) - I:GetVelocityVector()
    
    target = newTarget
end

function AimSpinner(spinnerIndex)
    local spinner = I:GetSpinnerInfo(spinnerIndex)
    
    local spinnerRight = QuaternionRightVector(spinner.Rotation)
    local spinnerUp = Vector3.Cross(spinner.Forwards, spinnerRight).normalized
    local spinnerUpLocal = ComputeLocalVector(spinnerUp).normalized
    
    local centerPosition = spinner.LocalPosition - (myLocalCenter or Vector3.zero)
    
    local bestScore = 0
    local neutralAim, maximumAzimuth
    
    for _, axis in ipairs(AXES) do
        local thisScore = ((math.abs(centerPosition[axis]) + 0.25) / mySize[axis]) * (1.0 - spinnerUpLocal[axis] * spinnerUpLocal[axis])
        if thisScore >= bestScore then
            neutralAim = (centerPosition[axis] >= 0 and myVectors[axis]) or -myVectors[axis]
            maximumAzimuth = maximumAzimuths[axis]
            bestScore = thisScore
        end
    end
    
    --LogBoth(string.format('Right vector: %s', tostring(spinnerRight)))
    --LogBoth(string.format('Local neutral aim: %s', tostring(ComputeLocalVector(neutralAim))))
    
    local targetAngle = neutralAngle
    local aim, t = ComputeAim(spinner.Position, spinnerWeaponSpeed)
    if aim ~= nil then
        aim = Vector3.ProjectOnPlane(aim, spinnerUp)
        if ComputeAngleDegrees(aim, neutralAim) > maximumAzimuth then
            aim = neutralAim
        end
    else
        -- Return to neutral if no target.
        aim = neutralAim
    end
    
    local targetAngle = ComputeAzimuth(aim, spinner.Forwards, spinnerRight)
    local spinSpeed = targetAngle / nominalFrameDuration
    -- LogBoth(string.format("frameDuration: %0.3f, targetAngle: %0.2f, Spin speed: %0.2f", frameDuration, targetAngle, spinSpeed))
    spinSpeed = math.max(spinSpeed, -maximumSpinSpeed)
    spinSpeed = math.min(spinSpeed, maximumSpinSpeed)
    I:SetSpinnerContinuousSpeed(spinnerIndex, spinSpeed)
end

function ComputeAzimuth(aim, forward, right)
    local c = Vector3.Dot(aim.normalized, forward.normalized)
    local s = Vector3.Dot(aim.normalized, right.normalized)
    -- domain is [-pi, pi]
    return math.atan2(s, c)
end

function ComputeAim(weaponPosition, weaponSpeed)
    -- return aim (relative position to aim at) and flight time
    if target == nil then
        return nil, nil
    end
    
    local relativePosition = target.AimPointPosition - weaponPosition
    local t = 0
    local aim = relativePosition
    for i = 1, leadIterations do
        t = ComputeFlightTime(aim, weaponSpeed)
        if t == nil then
            return nil, nil
        end
        aim = relativePosition + ComputeLead(t)
    end
    -- Add compensation for gravity.
    aim = aim + Vector3.up * (0.5 * g * t * t)
    --LogBoth(string.format("Lead time: %0.3f s", t))
    --LogBoth(string.format("Acceleration: %f, frame time %f", targetAcceleration.magnitude, lastFrameTime))
    return aim, t
end

function ComputeLead(t)
    -- How much to lead the target by given a time t.
    local result = relativeVelocity * t
    local timeFactor = t
    for i = 3, #targetDerivatives do
        timeFactor = timeFactor * t / (i - 1)
        result = result + targetDerivatives[i] * timeFactor
    end
    return result
end

function ComputeFlightTime(aim, weaponSpeed)
    local a = 0.25 * g * g
    local b = (aim.y * g - weaponSpeed * weaponSpeed)
    local c = aim.sqrMagnitude
    local vertex = -b / (2 * a)
    local discriminant = vertex*vertex - c / a
    if discriminant > 0 then
        local width = math.sqrt(discriminant)
        local lower = vertex - width
        -- local upper = vertex + width
        if lower >= 0 then
            return math.sqrt(lower) + extraLeadTime
        else
            -- LogBoth("Out of range!")
            return nil
        end
    else
        -- LogBoth(string.format("Out of range! Weapon speed: %f", spinnerWeaponSpeed))
        return nil
    end
end

function ComputeLocalVector(v)
    return Vector3(Vector3.Dot(v, myVectors.x),
                   Vector3.Dot(v, myVectors.y),
                   Vector3.Dot(v, myVectors.z))
end

function ComputeLocalPosition(position)
    local relativePosition = position - myPosition
    return ComputeLocalVector(relativePosition)
end

function QuaternionRightVector(quaternion)
    local x = 1 - 2 * (quaternion.y * quaternion.y + quaternion.z * quaternion.z) 
    local y = 2 * (quaternion.x * quaternion.y + quaternion.z * quaternion.w )
    local z = 2 * (quaternion.x * quaternion.z - quaternion.y * quaternion.w )
    return Vector3(x, y, z).normalized
end

function ComputeAngleDegrees(v0, v1)
    local c = Vector3.Dot(v0.normalized, v1.normalized)
    c = (c < -1 and -1) or (c > 1 and 1) or c
    return math.deg(math.acos(c))
end

function LogBoth(s)
    I:Log(s)
    I:LogToHud(s)
end
