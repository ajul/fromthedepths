weaponSpeed = 200

-- Will attempt to aim this proportion of the way towards the target each frame.
spinGain = 0.9

-- The I in Update(I).
I = nil

targetingMainframe = 0
targetPosition = nil
targetVelocity = nil

frameTime = 1 / 40

function QuaternionRightVector(quaternion)
    local x = 1 - 2 * (quaternion.y * quaternion.y - quaternion.z * quaternion.z) 
    local y = 2 * (quaternion.x * quaternion.y + quaternion.z * quaternion.w )
    local z = 2 * (quaternion.x * quaternion.z - quaternion.y * quaternion.w )
    return Vector3(x, y, z)
end

function Update(Iarg)
    I = Iarg
    local target = I:GetTargetInfo(targetingMainframe, 0)
    if target.Valid then
        targetPosition = target.AimPointPosition
        targetVelocity = target.Velocity
    else
        -- If idle, point towards front.
        targetPosition = I:GetConstructPosition() + I:GetConstructForwardVector() * 1000.0
        targetVelocity = Vector3.zero
    end
    for spinnerIndex = 0, I:GetSpinnerCount() - 1 do
        if not I:IsSpinnerDedicatedHelispinner(spinnerIndex) then
            AimSpinner(spinnerIndex)
        end
    end
end

function AimSpinner(spinnerIndex)
    local spinner = I:GetSpinnerInfo(spinnerIndex)
    local spinnerRight = QuaternionRightVector(spinner.Rotation)
    
    -- todo: lead computation
    local relativeTargetPosition = targetPosition - spinner.Position
    local interceptTime = InterceptTime(weaponSpeed, relativeTargetPosition, targetVelocity)
    local aimVector = relativeTargetPosition + targetVelocity * interceptTime
    
    local c = Vector3.Dot(aimVector.normalized, spinner.Forwards.normalized)
    local s = Vector3.Dot(aimVector.normalized, spinnerRight.normalized)
    -- domain is [-pi, pi]
    local targetAngle = math.atan2(s, c)
    local spinSpeed = targetAngle * spinGain / frameTime
    I:SetSpinnerContinuousSpeed(spinnerIndex, spinSpeed)
end


function InterceptTime(weaponSpeed, relativeTargetPosition, targetVelocity)
    -- Computes the time needed to intercept the target.
    a = targetVelocity.sqrMagnitude - weaponSpeed * weaponSpeed
    b = 2 * Vector3.Dot(targetVelocity, relativeTargetPosition)
    c = relativeTargetPosition.sqrMagnitude
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