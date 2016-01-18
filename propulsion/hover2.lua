-- Desired altitudes.
desiredASL = 10
desiredAGL = 50

desiredPitch = 0
desiredRoll = 0

minimumMomentArm = 0.25

altitudePID = {
    P = 2, -- Metres. The difference at which 100% throttle is applied. Lower = stiffer.
    I = 0.5, -- Seconds. Offset is a moving exponential average with this time constant. Lower = more aggressive.
    D = 1, -- Seconds. Will attempt to reach the target point in this time. Higher = more damping.
    
    MV = 0,  -- Throttle to apply in this direction.
    EMA = 0, -- Exponential moving average of throttle.
}

pitchPID = {
    P = 60,  -- Degrees.
    I = 1,   -- Seconds.
    D = 2, -- Seconds.
    
    MV = 0,  -- Throttle to apply in this direction.
    EMA = 0, -- Exponential moving average of throttle.
}

rollPID = {
    P = 60,  -- Degrees.
    I = 1,   -- Seconds.
    D = 2, -- Seconds.
    
    MV = 0,  -- Throttle to apply in this direction.
    EMA = 0, -- Exponential moving average of throttle.
}

-- The I in Update(I).
I = nil

myVectors = {
    x = Vector3.right,
    y = Vector3.up,
    z = Vector3.forward,
    
    horizontalZ = Vector3.forward,
    horizontalX = Vector3.right,
}
myPosition = Vector3.zero
myCom = Vector3.zero
myLocalCom = Vector3.zero
myVelocity = Vector3.zero
myLocalAngularVelocity = Vector3.zero
myPitch = 0
myRoll = 0

-- Time and duration of the current frame.
frameTime = 0
frameDuration = 1/40

altitudeThrottleOffset = 0
altitudeThrottle = 0

pitchThrottleOffset = 0
pitchThrottle = 0

rollThrottleOffset = 0
rollThrottle = 0

firstRun = true
state = nil

AXES = {'x', 'y', 'z'}

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
    local newFrameTime = I:GetGameTime()
    frameDuration = newFrameTime - frameTime
    frameTime = newFrameTime
    
    myVectors.x = I:GetConstructRightVector()
    myVectors.y = I:GetConstructUpVector()
    myVectors.z = I:GetConstructForwardVector()
    
    myVectors.horizontalZ = Vector3(myVectors.z.x, 0, myVectors.z.z).normalized
    myVectors.horizontalX = Vector3.Cross(Vector3.up, myVectors.horizontalZ).normalized
    
    myPosition = I:GetConstructPosition()
    myCom = I:GetConstructCenterOfMass()
    myLocalCom = ComputeLocalVector(myCom - myPosition)
    
    myVelocity = I:GetVelocityVector()
    
    myPitch = I:GetConstructPitch()
    if myPitch > 180 then
        myPitch = myPitch - 360
    end
    myRoll = I:GetConstructRoll()
    if myRoll > 180 then
        myRoll = myRoll - 360
    end
    myLocalAngularVelocity = I:GetLocalAngularVelocity()
end

function ChooseState()
    if firstRun then
        firstRun = false
        state = StateInit
    else
        local terrainAltitude = I:GetTerrainAltitudeForLocalPosition(Vector3.zero)
        local desiredAltitude = math.max(desiredASL, terrainAltitude + desiredAGL)
        local currentAltitude = myPosition.y + GetLowestPointOffset()
        
        UpdatePID(altitudePID, desiredAltitude, currentAltitude, myVelocity.y, 1)
        
        local maxMV = 1 - math.abs(altitudePID.MV)
        UpdatePID(pitchPID, desiredPitch, myPitch, math.deg(myLocalAngularVelocity.x), maxMV)
        
        maxMV = maxMV - math.abs(pitchPID.MV)
        
        local pitchCos = math.cos(math.rad(myPitch))
        UpdatePID(rollPID, desiredRoll, myRoll * pitchCos, math.deg(myLocalAngularVelocity.z) * pitchCos, maxMV)
        
        -- LogBoth(string.format("Pitch: %0.2f, Roll: %0.2f", myPitch, myRoll))
        -- LogBoth(string.format("Lowest offset: %0.2f", GetLowestPointOffset()))
        -- LogBoth(string.format("Altitude: PV %0.2f, MV %0.2f, EMA %0.2f", currentAltitude, altitudePID.MV, altitudePID.EMA))
        -- LogBoth(string.format("MVs: %0.2f, %0.2f, %0.2f", altitudePID.MV, pitchPID.MV, rollPID.MV))
        
        state = StateMain
    end
end

-- Computes the lowest point on the bounding box relative to construct position.
function GetLowestPointOffset()
    local myMinDimensions = I:GetConstructMinDimensions()
    local myMaxDimensions = I:GetConstructMaxDimensions()
    local result = 0
    for _, axis in ipairs(AXES) do
        local axisSin = myVectors[axis].normalized.y
        if axisSin > 0 then
            result = result + myMinDimensions[axis] * axisSin
        else
            result = result + myMaxDimensions[axis] * axisSin
        end
    end
    return result
end

function UpdatePID(pid, setPoint, PV, derivative, maxAbs)
    pid.MV = pid.EMA + ((setPoint - PV - pid.D * derivative)) / pid.P
    pid.MV = ClipAbs(pid.MV, maxAbs)
    local emaWeight = frameDuration / pid.I
    pid.EMA = pid.EMA * (1 - emaWeight) + pid.MV * emaWeight
end

function StateInit(spinnerIndex)
    I:SetSpinnerPowerDrive(spinnerIndex, 10)
    I:SetDedicatedHelispinnerUpFraction(spinnerIndex, 1)
end

function StateMain(spinnerIndex)
    local spinner = I:GetSpinnerInfo(spinnerIndex)
    local pitchQuadrant, rollQuadrant = ComQuadrantPitchRoll(spinner.Position)
    
    local spinnerTotalThrottle = altitudePID.MV - pitchPID.MV * pitchQuadrant + rollPID.MV * rollQuadrant
    I:SetSpinnerContinuousSpeed(spinnerIndex, spinnerTotalThrottle * 30)
end

function ComQuadrantPitchRoll(position)
    local comPosition = position - myCom
    local rollOffset = Vector3.Dot(comPosition, myVectors.horizontalX)
    local pitchOffset = Vector3.Dot(comPosition, myVectors.horizontalZ)
    local rollQuadrant = (rollOffset < -minimumMomentArm and -1) or (rollOffset > minimumMomentArm and 1) or 0
    local pitchQuadrant = (pitchOffset < -minimumMomentArm and -1) or (pitchOffset > minimumMomentArm and 1) or 0
    return pitchQuadrant, rollQuadrant
end

-- Utility functions.

function ComputeLocalVector(v)
    return Vector3(Vector3.Dot(v, myVectors.x),
                   Vector3.Dot(v, myVectors.y),
                   Vector3.Dot(v, myVectors.z))
end

function ClipAbs(x, a)
    return math.min(math.max(x, -a), a)
end

function Clip1(x)
    return math.min(math.max(x, -1), 1)
end

function Clip01(x)
    return math.min(math.max(x, 0), 1)
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