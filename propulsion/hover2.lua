-- Desired altitudes.
desiredASL = 10 -- from bottom of hull
desiredAGL = 10

desiredPitch = 0
desiredRoll = 0

-- Minimum distance from CoM to use for pitch/roll.
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

-- Distance to look around to avoid collision.
collisionAvoidanceDistance = 100
-- Time to look ahead to avoid collision.
collisionAvoidanceTime = 2
-- Try to go this high above the potential collision.
collisionAvoidanceHeight = 50

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

AXES = {'x', 'y', 'z'}

function Update(Iarg)
    I = Iarg
    UpdateInfo()
    UpdateAltitude()
    
    for spinnerIndex = 0, I:GetSpinnerCount() - 1 do
        if I:IsSpinnerDedicatedHelispinner(spinnerIndex) then
            local spinner = I:GetSpinnerInfo(spinnerIndex)
            local pitchQuadrant, rollQuadrant = ComQuadrantPitchRoll(spinner.Position)
            
            local spinnerTotalThrottle = altitudePID.MV - pitchPID.MV * pitchQuadrant + rollPID.MV * rollQuadrant
            I:SetSpinnerContinuousSpeed(spinnerIndex, spinnerTotalThrottle * 30)
            I:SetSpinnerPowerDrive(spinnerIndex, 10)
            I:SetDedicatedHelispinnerUpFraction(spinnerIndex, 1)
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

function UpdateAltitude()
    local terrainAltitude = I:GetTerrainAltitudeForLocalPosition(Vector3.zero)
    local lookaheadTerrainAltitude = I:GetTerrainAltitudeForPosition(myPosition + myVelocity * collisionAvoidanceTime)
    local desiredAltitude = math.max(desiredASL, math.max(terrainAltitude, lookaheadTerrainAltitude) + desiredAGL)
    desiredAltitude = math.max(desiredAltitude, CollisionAvoidanceAltitude())
    local currentAltitude = myPosition.y + GetLowestPointOffset()
    
    local maxMV = 1
    
    UpdatePID(altitudePID, desiredAltitude, currentAltitude, myVelocity.y, maxMV)
    
    -- maxMV = 1 - math.abs(altitudePID.MV)
    UpdatePID(pitchPID, desiredPitch, myPitch, math.deg(myLocalAngularVelocity.x), maxMV)
    
    maxMV = maxMV - math.abs(pitchPID.MV)
    
    local pitchCos = math.cos(math.rad(myPitch))
    UpdatePID(rollPID, desiredRoll, myRoll * pitchCos, math.deg(myLocalAngularVelocity.z) * pitchCos, maxMV)
    
    -- LogBoth(string.format("Pitch: %0.2f, Roll: %0.2f", myPitch, myRoll))
    -- LogBoth(string.format("Lowest offset: %0.2f", GetLowestPointOffset()))
    -- LogBoth(string.format("Altitude: PV %0.2f, MV %0.2f, EMA %0.2f", currentAltitude, altitudePID.MV, altitudePID.EMA))
    -- LogBoth(string.format("MVs: %0.2f, %0.2f, %0.2f", altitudePID.MV, pitchPID.MV, rollPID.MV))
end

function CollisionAvoidanceAltitude()
    local result = desiredASL
    for targetIndex = 0, I:GetNumberOfTargets(0) - 1 do
        local target = I:GetTargetInfo(0, targetIndex)
        local closeTime = ComputeCloseTime(target.Position, target.Velocity)
        if closeTime < collisionAvoidanceTime and target.Position.y < myPosition.y + math.abs(collisionAvoidanceHeight) then
            result = math.max(result, target.Position.y + collisionAvoidanceHeight)
        end
    end
    
    for friendlyIndex = 0, I:GetFriendlyCount() - 1 do
        local friendly = I:GetFriendlyInfo(friendlyIndex)
        -- Higher vehicle jumps.
        if friendly.ReferencePosition.y < myPosition.y then
            local closeTime = ComputeCloseTime(friendly.CenterOfMass, friendly.Velocity)
            if closeTime < collisionAvoidanceTime then
                result = math.max(result, friendly.CenterOfMass.y + collisionAvoidanceHeight)
            end
        end
    end
    
    return result
end

function ComputeCloseTime(targetPosition, targetVelocity)
    local relativeVelocity = targetVelocity - myVelocity
    local relativePosition = targetPosition - myPosition
    local closeRate = Vector3.Dot(-relativeVelocity, relativePosition.normalized)
    local distance = math.max(0, relativePosition.magnitude - collisionAvoidanceDistance)
    return distance / math.max(closeRate, 1.0)
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