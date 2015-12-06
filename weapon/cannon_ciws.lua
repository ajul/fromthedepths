-- All turrets in this weapon slot are assumed to be CIWS.
ciwsWeaponSlot = 5

-- Weapon speed for computing spinner lead.
spinnerWeaponSpeed = 290

-- What radius to consider firing weapon.
weaponRadius = 10.0

-- Timed fuse.
fuseTime = 1.0

-- Will attempt to aim this proportion of the way towards the target each frame.
-- Should be below 1.
-- The closer to 1, the faster it will converge.
spinGain = 0.9

g = 9.81
gravityDrop = 0.5 * fuseTime * fuseTime * g
frameTime = 1 / 40

-- The I in Update(I).
I = nil

-- Table of known enemy missiles.
warnings = {}

function UpdateWarnings()
    -- Called first. This updates the warning table. Elements are warningIndex1 -> warningInfo.
    warnings = {}
    for mainframeIndex = 0, I:GetNumberOfMainframes() - 1 do
        local numberOfWarnings = I:GetNumberOfWarnings(mainframeIndex)
        if numberOfWarnings > 0 then
            for warningIndex0 = 0, numberOfWarnings - 1 do
                -- add one... dammit Lua
                warnings[warningIndex0 + 1] = I:GetMissileWarning(mainframeIndex, warningIndex0)
            end
            interceptorMainframeIndex = mainframeIndex
            return
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
    for spinnerIndex = 0, I:GetSpinnerCount() - 1 do
        if not I:IsSpinnerDedicatedHelispinner(spinnerIndex) then
            AimSpinner(spinnerIndex)
        end
    end
    for turretSpinnerIndex = 0, I:GetTurretSpinnerCount() - 1 do
        for weaponIndex = 0, I:GetWeaponCountOnTurretOrSpinner(turretSpinnerIndex) do
            local weaponInfo = I:GetWeaponInfoOnTurretOrSpinner(turretSpinnerIndex, weaponIndex)
            if weaponInfo.WeaponSlot == ciwsWeaponSlot then
                AimSpinnerWeapon(turretSpinnerIndex, weaponIndex)
            end
        end
    end
end

function AimSpinner(spinnerIndex)
    local spinner = I:GetSpinnerInfo(spinnerIndex)
    -- Find a target.
    local selectedWarning, _ = SelectWarning(spinner.Position, spinnerWeaponSpeed)
    if selectedWarning ~= nil then
        local relativeTargetPosition = selectedWarning.Position - spinner.Position + selectedWarning.Velocity * fuseTime
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
    local selectedWarning, selectedRadius = SelectWarning(weapon.GlobalPosition, weapon.Speed)
    if selectedWarning ~= nil then
        local relativeTargetPosition = selectedWarning.Position - weapon.GlobalPosition + selectedWarning.Velocity * fuseTime
        
        I:AimWeaponInDirectionOnTurretOrSpinner(turretSpinnerIndex, weaponIndex, 
                                                relativeTargetPosition.x, relativeTargetPosition.y + gravityDrop, relativeTargetPosition.z, 
                                                ciwsWeaponSlot)
        if math.abs(selectedRadius) < weaponRadius then
            I:LogToHud(selectedRadius)
            I:FireWeaponOnTurretOrSpinner(turretSpinnerIndex, weaponIndex, ciwsWeaponSlot)
        end
    end
end

function SelectWarning(position, weaponSpeed)
    local selectedWarning = nil
    local selectedRadius = 10000
    for _, warning in ipairs(warnings) do
        local relativePosition = warning.Position - position
        local closeRate = -Vector3.Dot(warning.Velocity, relativePosition.normalized)
        -- How far warning will be after fuseTime, relative to center of intercept window.
        local interceptRadius = relativePosition.magnitude - fuseTime * (closeRate + weaponSpeed)
        -- I:Log(string.format("Close in %0.1f seconds, intercept radius %0.1f", closeTime, interceptRadius))
        -- Pick closest missile that is not too late to intercept.
        if closeRate > 0 and interceptRadius < selectedRadius and interceptRadius > -weaponRadius then
            selectedWarning = warning
            selectedRadius = interceptRadius
        end
    end
    
    return selectedWarning, selectedRadius
end
