-- Desired altitudes.
desiredASL = 10
desiredAGL = 50

-- The I in Update(I).
I = nil

myVectors = {
    x = Vector3.right,
    y = Vector3.up,
    z = Vector3.forward,
}
myPosition = Vector3.zero
myCom = Vector3.zero
myLocalCom = Vector3.zero
myVelocity = Vector3.zero
myPreviousVelocity = Vector3.zero

desiredAltitude = 10

-- Lift throttle in previous frame.
previousThrottle = 0
-- Estimate of the throttle needed to maintain altitude.
gravityThrottle = 0

firstRun = true
previousState = nil
state = nil

function Update(Iarg)
    I = Iarg
    UpdateInfo()
    ChooseState()
    
    for spinnerIndex = 0, I:GetSpinnerCount() - 1 do
        if I:IsSpinnerDedicatedHelispinner(spinnerIndex) then
            state(spinnerIndex)
        end
    end
end

function UpdateInfo()
    myVectors.x = I:GetConstructRightVector()
    myVectors.y = I:GetConstructUpVector()
    myVectors.z = I:GetConstructForwardVector()
    
    myPosition = I:GetConstructPosition()
    myCom = I:GetConstructCenterOfMass()
    myLocalCom = ComputeLocalVector(myCom - myPosition)
    
    myPreviousVelocity = myVelocity
    myVelocity = I:GetVelocityVector()
    
    local terrainAltitude = I:GetTerrainAltitudeForLocalPosition(Vector3.zero)
    desiredAltitude = math.max(desiredASL, terrainAltitude + desiredAGL)
end

function ChooseState()
    previousState = state
    if firstRun then
        firstRun = false
        state = StateInit
    else
        if previousState == StateLift then
            -- Update gravity estimate.
            local netThrottle = previousThrottle - gravityThrottle
            local acceleration = myVelocity.y - myPreviousVelocity.y
            -- If we are accelerating away from expected net direction and drag...
            if (acceleration > 0) != (netThrottle > 0) and (acceleration > 0) != (myPreviousVelocity.y < 0) then
                -- Push the gravity estimate towards the net throttle.
                gravityThrottle = gravityThrottle + 0.5 * netThrottle
                LogBoth(string.format("%f", gravityThrottle))
            end
        end
        
        previousThrottle = throttle
        state = StateLift
    end
end

function StateInit(spinnerIndex)
    I:SetSpinnerPowerDrive(spinnerIndex, 10)
    I:SetDedicatedHelispinnerUpFraction(spinnerIndex, 1)
end

function StateLift(spinnerIndex)
    I:SetSpinnerContinuousSpeed(spinnerIndex, gravityThrottle * 30)
end

function StateStabilize(spinnerIndex)
    
end

function ControlDediblade(spinnerIndex)
    local spinner = I:GetSpinnerInfo(spinnerIndex)
    local spinnerComPosition = spinner.LocalPosition - myLocalCom
end

-- Utility functions.

function ComputeLocalVector(v)
    return Vector3(Vector3.Dot(v, myVectors.x),
                   Vector3.Dot(v, myVectors.y),
                   Vector3.Dot(v, myVectors.z))
end

function QuaternionUpVector(quaternion)
    local x = 2 * (quaternion.x * quaternion.y - quaternion.z * quaternion.w)
    local y = 1 - 2 * (quaternion.x * quaternion.x + quaternion.z * quaternion.z)
    local z = 2 * (quaternion.y * quaternion.z + quaternion.x * quaternion.w)
    return Vector3(x, y, z).normalized
end

function LogBoth(s)
    I:Log(s)
    I:LogToHud(s)
end