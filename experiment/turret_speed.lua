lastDirection = Vector3.up

function Update(I)
    turret = I:GetWeaponInfo(0)
    omega = math.acos(Vector3.Dot(turret.CurrentDirection.normalized, lastDirection.normalized)) * 40.0 * 180 / math.pi
    I:Log(omega)
    I:LogToHud(omega)
    lastDirection = turret.CurrentDirection
end
