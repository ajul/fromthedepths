-- Weapon slot to use. Only cannons will be controlled regardless.
weaponSlot = 1

-- Restrict the maximum azimuth of spinblock rotation. This is in absolute value degrees.
maximumAzimuth = 180

-- What order polynomial to use. 1 = linear (similar to stock), 2 = quadratic (acceleration)
predictionOrder = 3

-- Extra time to lead the target by.
extraLeadTime = 2/40

-- How many iterations to refine the aim estimate.
leadIterations = 16

-- Will attempt to aim this proportion of the way towards the target each frame.
-- Should be below 1.
-- The closer to 1, the faster it will converge.
spinGain = 0.9

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
myVectors = {
    x = Vector3.right,
    y = Vector3.up,
    z = Vector3.forward,
}

-- Used for computing azimuth restrictions. Will be set only once.
myLocalCenter = nil

-- Current target.
target = nil

-- Position, velocity, acceleration... of the current target.
targetDerivatives = {}

-- Velocity is special because cannon projectiles inherit our velocity.
relativeVelocity = Vector3.zero

-- Weapon speed for computing spinner lead. Will be overwritten by the actual projectile speed.
spinnerWeaponSpeed = 600

WEAPON_TYPE_CANNON = 0

function Update(Iarg)
    I = Iarg
    
    UpdateInfo()

    if target ~= nil then
        for turretSpinnerIndex = 0, I:GetTurretSpinnerCount() - 1 do
            for weaponIndex = 0, I:GetWeaponCountOnTurretOrSpinner(turretSpinnerIndex) do
                local weaponInfo = I:GetWeaponInfoOnTurretOrSpinner(turretSpinnerIndex, weaponIndex)
                if weaponInfo.WeaponSlot == weaponSlot and weaponInfo.WeaponType == WEAPON_TYPE_CANNON then
                    AimSpinnerWeapon(turretSpinnerIndex, weaponIndex)
                end
            end
        end
    end
    
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
    myVectors.x = I:GetConstructRightVector()
    myVectors.y = I:GetConstructUpVector()
    myVectors.z = I:GetConstructForwardVector()
    
    if myLocalCenter == nil then
        -- myLocalCenter = ComputeLocalPosition(I:GetConstructCenterOfMass())
        myLocalCenter = (I:GetConstructMaxDimensions() + I:GetConstructMinDimensions()) / 2
        -- LogBoth(string.format('Nominal local center: %s', tostring(myLocalCenter)))
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
    local aim, t = ComputeAim(spinner.Position, spinnerWeaponSpeed)
    -- Project onto spinner plane.
    
    local neutralAim = ComputeSpinnerNeutralAim(spinner)
    
    -- LogBoth(string.format('Neutral aim: %s', tostring(neutralAim)))
    
    local targetAngle = neutralAngle
    if aim ~= nil then
        local spinnerUp = Vector3.Cross(spinner.Forwards, spinnerRight).normalized
        aim = Vector3.ProjectOnPlane(aim, spinnerUp)
        if ComputeAngleDegrees(aim, neutralAim) > maximumAzimuth then
            aim = neutralAim
        end
    else
        -- Return to neutral if no target.
        aim = neutralAim
    end
    
    local targetAngle = ComputeAzimuth(aim, spinner.Forwards, spinnerRight)
    local spinSpeed = targetAngle * spinGain / nominalFrameDuration
    I:SetSpinnerContinuousSpeed(spinnerIndex, spinSpeed)
end

-- Computes the spinner's neutral aim.
function ComputeSpinnerNeutralAim(spinner)
    local centerPosition = spinner.LocalPosition - (myLocalCenter or Vector3.zero)
    
    if math.abs(centerPosition.z) + 0.25 > math.abs(centerPosition.x) then
        return (centerPosition.z >= 0 and myVectors.z) or -myVectors.z
    else
        return (centerPosition.x >= 0 and myVectors.x) or -myVectors.x
    end
end

function ComputeAngleDegrees(v0, v1)
    return math.deg(math.acos(Vector3.Dot(v0.normalized, v1.normalized)))
end

function ComputeAzimuth(aim, forward, right)
    local c = Vector3.Dot(aim.normalized, forward.normalized)
    local s = Vector3.Dot(aim.normalized, right.normalized)
    -- domain is [-pi, pi]
    return math.atan2(s, c)
end

function AimSpinnerWeapon(turretSpinnerIndex, weaponIndex)
    local weapon = I:GetWeaponInfoOnTurretOrSpinner(turretSpinnerIndex, weaponIndex)
    spinnerWeaponSpeed = weapon.Speed
    local aim, t = ComputeAim(weapon.GlobalPosition, weapon.Speed)
    
    if aim ~= nil then
        I:AimWeaponInDirectionOnTurretOrSpinner(turretSpinnerIndex, weaponIndex, 
                                                aim.x, aim.y, aim.z, 
                                                weaponSlot)
        I:FireWeaponOnTurretOrSpinner(turretSpinnerIndex, weaponIndex, weaponSlot)
    end
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
    local timeCoefficient = t
    for i = 3, #targetDerivatives do
        timeCoefficient = timeCoefficient * t / (i - 1)
        result = result + targetDerivatives[i] * timeCoefficient
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
        local upper = vertex + width
        return (lower >= 0 and math.sqrt(lower) + extraLeadTime) or 
               -- (upper >= 0 and math.sqrt(upper) + extraLeadTime) or 
               nil
    else
        return nil
    end
end

function ComputeLocalPosition(position)
    local relativePosition = position - myPosition
    return Vector3(Vector3.Dot(relativePosition, myVectors.x),
                   Vector3.Dot(relativePosition, myVectors.y),
                   Vector3.Dot(relativePosition, myVectors.z))
end

function QuaternionRightVector(quaternion)
    local x = 1 - 2 * (quaternion.y * quaternion.y - quaternion.z * quaternion.z) 
    local y = 2 * (quaternion.x * quaternion.y + quaternion.z * quaternion.w )
    local z = 2 * (quaternion.x * quaternion.z - quaternion.y * quaternion.w )
    return Vector3(x, y, z)
end

function LogBoth(s)
    I:Log(s)
    I:LogToHud(s)
end
