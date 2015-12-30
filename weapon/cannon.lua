-- Weapon slot to use. Only cannons will be controlled regardless.
weaponSlot = 1

-- Extra time to lead the target by.
extraLeadTime = 1/40

-- Will attempt to aim this proportion of the way towards the target each frame.
-- Should be below 1.
-- The closer to 1, the faster it will converge.
spinGain = 0.9

leadIterations = 16

g = 9.81

-- The I in Update(I).
I = nil

nominalFrameDuration = 1/40

-- Last frame for which there was acceleration.
lastAccelerationTime = nil

DEFAULT_ACCELERATION_DURATION = 0.5

-- Current target.
target = nil
targetAcceleration = Vector3.zero
relativeVelocity = Vector3.zero

-- Weapon speed for computing spinner lead.
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
        
        for spinnerIndex = 0, I:GetSpinnerCount() - 1 do
            if not I:IsSpinnerDedicatedHelispinner(spinnerIndex) then
                AimSpinner(spinnerIndex)
            end
        end
    else
        -- Stop spinners.
        for spinnerIndex = 0, I:GetSpinnerCount() - 1 do
            if not I:IsSpinnerDedicatedHelispinner(spinnerIndex) then
                I:SetSpinnerContinuousSpeed(spinnerIndex, 0)
            end
        end
    end
end

function UpdateInfo()
    local newTarget = nil
    for mainframeIndex = 0, I:GetNumberOfMainframes() - 1 do
        local firstTarget = I:GetTargetInfo(mainframeIndex, 0)
        if firstTarget.Valid then
            if newTarget == nil or firstTarget.Score ~= 0 then
                newTarget = firstTarget
            end 
        end
    end
    
    -- Update acceleration if target is same as previous update.
    if newTarget ~= nil and target ~= nil and newTarget.Id == target.Id then
        local velocityChange = newTarget.Velocity - target.Velocity
        if velocityChange.magnitude > 0 then
            local currentTime = I:GetGameTime()
            local accelerationDuration
            if lastAccelerationTime ~= nil then 
                accelerationDuration = currentTime - lastAccelerationTime
            else
                accelerationDuration = DEFAULT_ACCELERATION_DURATION
            end
            lastAccelerationTime = currentTime
            targetAcceleration = velocityChange / accelerationDuration
            
            I:LogToHud(string.format("Acceleration: %f (for %0.3f s)", targetAcceleration.magnitude, accelerationDuration))
        end
        relativeVelocity = target.Velocity - I:GetVelocityVector()
    else
        lastAccelerationTime = nil
        targetAcceleration = Vector3.zero
        relativeVelocity = Vector3.zero
    end
    
    target = newTarget
end

function AimSpinner(spinnerIndex)
    local spinner = I:GetSpinnerInfo(spinnerIndex)
    local aim, t = ComputeAim(spinner.Position, spinnerWeaponSpeed)
    
    if t ~= nil then
        -- rotate spinner
        local spinnerRight = QuaternionRightVector(spinner.Rotation)
        local c = Vector3.Dot(aim.normalized, spinner.Forwards.normalized)
        local s = Vector3.Dot(aim.normalized, spinnerRight.normalized)
        -- domain is [-pi, pi]
        local targetAngle = math.atan2(s, c)
        local spinSpeed = targetAngle * spinGain / nominalFrameDuration
        I:SetSpinnerContinuousSpeed(spinnerIndex, spinSpeed)
        
        return
    end
    
    -- Fallback: stop the spinner.
    I:SetSpinnerContinuousSpeed(spinnerIndex, 0)
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
    --I:LogToHud(string.format("Lead time: %0.3f s", t))
    --I:LogToHud(string.format("Acceleration: %f, frame time %f", targetAcceleration.magnitude, lastFrameTime))
    return aim, t
end

function ComputeLead(t)
    -- How much to lead the target by given a time t.
    return relativeVelocity * t + targetAcceleration * (0.5 * t * t)
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
               (upper >= 0 and math.sqrt(upper) + extraLeadTime) or 
               nil
    else
        return nil
    end
end

function QuaternionRightVector(quaternion)
    local x = 1 - 2 * (quaternion.y * quaternion.y - quaternion.z * quaternion.z) 
    local y = 2 * (quaternion.x * quaternion.y + quaternion.z * quaternion.w )
    local z = 2 * (quaternion.x * quaternion.z - quaternion.y * quaternion.w )
    return Vector3(x, y, z)
end
