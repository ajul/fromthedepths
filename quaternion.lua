function QuaternionUpVector(quaternion)
    local x = 2 * (quaternion.x * quaternion.y - quaternion.z * quaternion.w)
    local y = 1 - 2 * (quaternion.x * quaternion.x + quaternion.z * quaternion.z)
    local z = 2 * (quaternion.y * quaternion.z + quaternion.x * quaternion.w)
    return Vector3(x, y, z).normalized
end
