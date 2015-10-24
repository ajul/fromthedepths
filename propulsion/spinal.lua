minimumAltitude = 200
minimumVelocityY = -10

-- As cosines.
azimuthTolerance = 0.1
elevationTolerance = 0.1
rollTolerance = 0.5

previousTime = 0
-- length of the last frame
frameTime = 1/40

targetingMainframe = 0

COMPONENT_TYPE_PROPULSION = 9

THRUST_CONTROL_FORWARDS = 0
THRUST_CONTROL_BACKWARDS = 1
THRUST_CONTROL_RIGHT = 2
THRUST_CONTROL_LEFT = 3
THRUST_CONTROL_UP = 4
THRUST_CONTROL_DOWN = 5
THRUST_CONTROL_ROLL_RIGHT = 6
THRUST_CONTROL_ROLL_LEFT = 7
THRUST_CONTROL_YAW_RIGHT = 8
THRUST_CONTROL_YAW_LEFT = 9
THRUST_CONTROL_PITCH_UP = 10
THRUST_CONTROL_PITCH_DOWN = 11

-- construct info
construct = {
    CenterOfMass = Vector3.zero,
    Position = Vector3.zero,
    LocalCenterOfMass = Vector3.zero,
    Right = Vector3.right,
    Up = Vector3.up,
    Forward = Vector3.forward,
    Velocity = Vector3.zero,
    Roll = 0,
}

function Update(I)
    Info = I
    UpdateGlobals()
    ControlPropulsion()
end

function UpdateGlobals()
    local currentTime = Info:GetGameTime()
    frameTime = currentTime - previousTime
    previousTime = currentTime
    
    construct.CenterOfMass = Info:GetConstructCenterOfMass()
    construct.Position = Info:GetConstructPosition()
    construct.Right = Info:GetConstructRightVector()
    construct.Up = Info:GetConstructUpVector()
    construct.Forward = Info:GetConstructForwardVector()
    construct.Velocity = Info:GetVelocityVector()
    
    -- Compute local center of mass.
    local relativeCenterOfMass = construct.CenterOfMass - construct.Position
    
    local x = Vector3.Dot(relativeCenterOfMass, construct.Right)
    local y = Vector3.Dot(relativeCenterOfMass, construct.Up)
    local z = Vector3.Dot(relativeCenterOfMass, construct.Forward)
    
    construct.LocalCenterOfMass = Vector3(x, y, z)
    
    -- Compute target vector.
    local futureAltitudeError = construct.Position.y + construct.Velocity.y * desiredAltitudeTime - desiredAltitude
end

function ControlPropulsion()
    if construct.Position.y < minimumAltitude or construct.Velocity.y < minimumVelocityY then
        ThrustUp()
    else
        local targetPositionInfo = Info:GetTargetPositionInfo(targetingMainframe, 0)
        if not targetPositionInfo.Valid then
            -- Return to level.
            targetPositionInfo = Info:GetTargetPositionInfoForPosition(targetingMainframe, 
                construct.Position.x + 1000.0 * construct.Forward.x, 
                construct.Position.y, 
                construct.Position.z + 1000.0 * construct.Forward.z)
        end
        
        PointAzimuth(targetPositionInfo)
        PointElevation(targetPositionInfo)
        -- CancelRoll()
    end
end

function ThrustUp()
    if construct.Forward.y > 0 then
        Info:RequestThrustControl(THRUST_CONTROL_FORWARDS)
    else
        Info:RequestThrustControl(THRUST_CONTROL_BACKWARDS)
    end
    
    if construct.Right.y > 0 then
        Info:RequestThrustControl(THRUST_CONTROL_RIGHT)
    else
        Info:RequestThrustControl(THRUST_CONTROL_LEFT)
    end
    
    if construct.Up.y > 0 then
        Info:RequestThrustControl(THRUST_CONTROL_UP)
    else
        Info:RequestThrustControl(THRUST_CONTROL_DOWN)
    end
end

function PointAzimuth(targetPositionInfo)
    local relativePosition = targetPositionInfo.Position - construct.Position
    local azimuthCosine = Vector3.Dot(relativePosition.normalized, construct.Right.normalized)
    if azimuthCosine > azimuthTolerance then
        Info:RequestThrustControl(THRUST_CONTROL_YAW_RIGHT)
    elseif azimuthCosine < -azimuthTolerance then
        Info:RequestThrustControl(THRUST_CONTROL_YAW_LEFT)
    end
end

function PointElevation(targetPositionInfo)
    local relativePosition = targetPositionInfo.Position - construct.Position
    local elevationCosine = Vector3.Dot(relativePosition.normalized, construct.Up.normalized)
    if elevationCosine > elevationTolerance then
        Info:RequestThrustControl(THRUST_CONTROL_PITCH_UP)
    elseif elevationCosine < -elevationTolerance then
        Info:RequestThrustControl(THRUST_CONTROL_PITCH_DOWN)
    end
end

function CancelRoll()
    local rollCosine = construct.Right.normalized.y
    if rollCosine > rollTolerance then
        Info:RequestThrustControl(THRUST_CONTROL_ROLL_RIGHT)
    elseif rollCosine < -rollTolerance then
        Info:RequestThrustControl(THRUST_CONTROL_ROLL_LEFT)
    end
end
