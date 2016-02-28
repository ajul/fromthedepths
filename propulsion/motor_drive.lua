I = nil

function Update(Iarg)
    I = Iarg
    
    for spinnerIndex = 0, I:GetSpinnerCount() - 1 do
        if I:IsSpinnerDedicatedHelispinner(spinnerIndex) then
            I:SetSpinnerPowerDrive(spinnerIndex, 10)
        end
    end
end