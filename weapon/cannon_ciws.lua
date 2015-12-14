-- All turrets in this weapon slot are assumed to be CIWS.
ciwsWeaponSlot = 5

-- What offset to consider firing weapon, where 0 is (hopefully) a direct hit.
-- Min offset should be negative and slightly smaller than the explosive radius.
-- Max offset should be zero or a small number.
minFireOffset = -8.0
maxFireOffset = 2.0

-- If greater than 0, we will attack vehicles if no missile can be fired at.
vehicleFireOffset = 15.0

-- Length of the barrel.
barrelLength = 8.0

-- Timed fuse length.
fuseTime = 1.02

-- Will attempt to aim this proportion of the way towards the target each frame.
-- Should be below 1.
-- The closer to 1, the faster it will converge.
spinGain = 0.9

frameTime = 1/40

g = 9.81
gravityDrop = Vector3(0.0, 0.5 * fuseTime * fuseTime * g, 0.0) 

-- The I in Update(I).
I = nil

-- Table of known enemy missiles.
warnings = {}

-- Target vehicle.
targets = {}

-- Weapon speed for computing spinner lead.
spinnerWeaponSpeed = 200

function UpdateWarnings()
    -- Called first. This updates the warning table. Elements are warningIndex1 -> warningInfo.
    warnings = {}
    for mainframeIndex = 0, I:GetNumberOfMainframes() - 1 do
        local numberOfWarnings = I:GetNumberOfWarnings(mainframeIndex)
        if numberOfWarnings > 0 then
            -- I:Log(tostring(numberOfWarnings))
            for warningIndex0 = 0, numberOfWarnings - 1 do
                -- add one... dammit Lua
                warnings[warningIndex0 + 1] = I:GetMissileWarning(mainframeIndex, warningIndex0)
            end
            interceptorMainframeIndex = mainframeIndex
            return
        end
    end
end

function UpdateTargets()
    targets = {}
    for mainframeIndex = 0, I:GetNumberOfMainframes() - 1 do
        local potentialTarget = I:GetTargetInfo(mainframeIndex, 0)
        if potentialTarget.Valid then
            for targetIndex0 = 0, I:GetNumberOfTargets(mainframeIndex) - 1 do
                local target = I:GetTargetInfo(mainframeIndex, targetIndex0)
                targets[targetIndex0 + 1] = {
                    Position = target.AimPointPosition,
                    Velocity = target.Velocity,
                }
            end
            break
        end
    end
end

function QuaternionRightVector(quaternion)
    local x = 1 - 2 * (quaternion.y * quaternion.y - quaternion.z * quaternion.z) 
    local y = 2 * (quaternion.x * quaternion.y + quaternion.z * quaternion.w )
    local z = 2 * (quaternion.x * quaternion.z - quaternion.y * quaternion.w )
    return Vector3(x, y, z)
end

function Update(Iarg)
    I = Iarg
    UpdateWarnings()
    UpdateTargets()
    for turretSpinnerIndex = 0, I:GetTurretSpinnerCount() - 1 do
        for weaponIndex = 0, I:GetWeaponCountOnTurretOrSpinner(turretSpinnerIndex) do
            local weaponInfo = I:GetWeaponInfoOnTurretOrSpinner(turretSpinnerIndex, weaponIndex)
            if weaponInfo.WeaponSlot == ciwsWeaponSlot then
                AimSpinnerWeapon(turretSpinnerIndex, weaponIndex)
            end
        end
    end
    for spinnerIndex = 0, I:GetSpinnerCount() - 1 do
        if not I:IsSpinnerDedicatedHelispinner(spinnerIndex) then
            AimSpinner(spinnerIndex)
        end
    end
end

function AimSpinner(spinnerIndex)
    local spinner = I:GetSpinnerInfo(spinnerIndex)
    -- Find a target.
    local selectedWarning, _ = SelectWarning(spinner.Position, spinnerWeaponSpeed)
    if selectedWarning ~= nil then
        local relativeTargetPosition = selectedWarning.Position - spinner.Position + selectedWarning.Velocity * fuseTime + gravityDrop
        -- rotate spinner
        local spinnerRight = QuaternionRightVector(spinner.Rotation)
    
        local c = Vector3.Dot(relativeTargetPosition.normalized, spinner.Forwards.normalized)
        local s = Vector3.Dot(relativeTargetPosition.normalized, spinnerRight.normalized)
        -- domain is [-pi, pi]
        local targetAngle = math.atan2(s, c)
        local spinSpeed = targetAngle * spinGain / frameTime
        I:SetSpinnerContinuousSpeed(spinnerIndex, spinSpeed)
    else
        I:SetSpinnerContinuousSpeed(spinnerIndex, 0)
    end
end

function AimSpinnerWeapon(turretSpinnerIndex, weaponIndex)
    local weapon = I:GetWeaponInfoOnTurretOrSpinner(turretSpinnerIndex, weaponIndex)
    local selectedWarning, shouldFire = SelectWarning(weapon.GlobalPosition, weapon.Speed)
    spinnerWeaponSpeed = weapon.Speed
    if selectedWarning ~= nil then
        local relativeTargetPosition = selectedWarning.Position - weapon.GlobalPosition + selectedWarning.Velocity * fuseTime + gravityDrop
        
        I:AimWeaponInDirectionOnTurretOrSpinner(turretSpinnerIndex, weaponIndex, 
                                                relativeTargetPosition.x, relativeTargetPosition.y, relativeTargetPosition.z, 
                                                ciwsWeaponSlot)
        if shouldFire then
            I:FireWeaponOnTurretOrSpinner(turretSpinnerIndex, weaponIndex, ciwsWeaponSlot)
        end
    end
end

function ComputeCloseRateAndOffset(warning, position, weaponSpeed)
    local relativePosition = warning.Position - position
    local closeRate = -Vector3.Dot(warning.Velocity, relativePosition.normalized)
    -- Adjust position for gravity.
    local adjustedRelativePosition = relativePosition + gravityDrop
    -- How far warning will be after fuseTime, relative to center of intercept window.
    local interceptOffset = adjustedRelativePosition.magnitude - fuseTime * (weaponSpeed + closeRate) - barrelLength
    return closeRate, interceptOffset
end

function SelectWarning(position, weaponSpeed)
    local selectedWarning = nil
    local selectedOffset = 10000
    local shouldFire = false
    for warningIndex, warning in ipairs(warnings) do
        closeRate, interceptOffset = ComputeCloseRateAndOffset(warning, position, weaponSpeed)
        -- I:LogToHud(string.format("Warning %d: %0.1f", warningIndex, interceptOffset))
        if interceptOffset < selectedOffset and interceptOffset > minFireOffset then
            if interceptOffset < maxFireOffset then
                shouldFire = true
            end
            selectedWarning = warning
            selectedOffset = interceptOffset
        end
    end
    if not shouldFire and vehicleFireOffset > 0.0 then
        for targetIndex, target in ipairs(targets) do
            _, interceptOffset = ComputeCloseRateAndOffset(target, position, weaponSpeed)
            -- I:LogToHud(string.format("Target %d: %0.1f", targetIndex, interceptOffset))
            if math.abs(interceptOffset) < vehicleFireOffset then
                shouldFire = true
                selectedWarning = target
                break
            end
        end
    end
    return selectedWarning, shouldFire
end
