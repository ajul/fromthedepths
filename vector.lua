function ComputeLocalVector(globalVector)
    return Vector3(Vector3.Dot(globalVector, myVectors.x),
                   Vector3.Dot(globalVector, myVectors.y),
                   Vector3.Dot(globalVector, myVectors.z))
end

function ComputeLocalPosition(globalPosition)
    local relativePosition = globalPosition - myPosition
    return Vector3(Vector3.Dot(relativePosition, myVectors.x),
                   Vector3.Dot(relativePosition, myVectors.y),
                   Vector3.Dot(relativePosition, myVectors.z))
end

function ComputeGlobalVector(localPosition)
    return myVectors.x * localPosition.x
           + myVectors.y * localPosition.y
           + myVectors.z * localPosition.z
end

function ComputeGlobalPosition(localPosition)
    return myPosition + myVectors.x * localPosition.x
                      + myVectors.y * localPosition.y
                      + myVectors.z * localPosition.z
end