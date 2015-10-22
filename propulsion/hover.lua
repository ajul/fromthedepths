powerDriveAltitude = 20
spinAltitude = 25

-- The I in Update(I).
Info = nil

function Update(I)
    Info = I
    ControlDediblades()
end

function ControlDediblades()
    for dedibladeIndex = 0, Info:GetSpinnerCount() - 1 do
        if Info:IsSpinnerDedicatedHelispinner(dedibladeIndex) then
            dediblade = Info:GetSpinnerInfo(dedibladeIndex)
            Info:SetDedicatedHelispinnerUpFraction(dedibladeIndex, 1)
            effectiveAltitude = dediblade.Position.y - dediblade.LocalPosition.y
            if effectiveAltitude < spinAltitude then
                Info:SetSpinnerContinuousSpeed(dedibladeIndex, 30)
            else
                Info:SetSpinnerContinuousSpeed(dedibladeIndex, 0)
            end
            if effectiveAltitude < powerDriveAltitude then
                Info:SetSpinnerPowerDrive(dedibladeIndex, 10)
            else
                Info:SetSpinnerPowerDrive(dedibladeIndex, 0)
            end
        end
    end
end
