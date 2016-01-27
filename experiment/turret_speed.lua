lastDirection = Vector3.up

I = nil

function Update(Iarg)
    I = Iarg
    turret = I:GetWeaponInfo(0)
    omega = math.acos(Vector3.Dot(turret.CurrentDirection.normalized, lastDirection.normalized)) * 40.0 * 180 / math.pi
    if math.abs(omega) > 1 then
        LogBoth(omega)
    end
    lastDirection = turret.CurrentDirection
end

function LogBoth(s)
    I:Log(s)
    I:LogToHud(s)
end