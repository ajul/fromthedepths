-- Will attempt to reach the desired altitude at this time.
-- Lower = stiffer.
altitudeLookaheadTime = 0.1

waterAltitude = 10
landAltitude = 20

-- Will prioritize correcting pitch above this threshold.
pitchThreshold = 30
-- Will prioritize correcting roll above this threshold.
rollThreshold = 60

-- The I in Update(I).
Info = nil

-- index -> altitude at last frame
previousTime = 0
-- length of the last frame
frameTime = 1/40
previousAltitudes = {}

function Update(I)
    Info = I
    local currentTime = Info:GetGameTime()
    frameTime = currentTime - previousTime
    previousTime = currentTime
    ControlDediblades()
end

function ControlDediblades()
    local roll = Info:GetConstructRoll()
    if roll > 180 then
        roll = roll - 360
    end
    local pitch = Info:GetConstructPitch()
    if pitch > 180 then
        pitch = pitch - 360
    end
    for dedibladeIndex = 0, Info:GetSpinnerCount() - 1 do
        if Info:IsSpinnerDedicatedHelispinner(dedibladeIndex) then
            local dediblade = Info:GetSpinnerInfo(dedibladeIndex)
            if previousAltitudes[dedibladeIndex] == nil then
                -- only set once---api calls are expensive
                Info:SetDedicatedHelispinnerUpFraction(dedibladeIndex, 1)
                Info:SetSpinnerPowerDrive(dedibladeIndex, 10)
            end
            
            if math.abs(pitch) >= pitchThreshold and math.abs(pitch) <= 180 - pitchThreshold then
                -- try to pitch right side up
                if dediblade.LocalPosition.z * pitch < 0 then
                    Info:SetSpinnerContinuousSpeed(dedibladeIndex, 0)
                else
                    Info:SetSpinnerContinuousSpeed(dedibladeIndex, 30)
                end
            elseif math.abs(roll) >= rollThreshold then
                -- try to roll right side up
                if dediblade.LocalPosition.x * roll < 0 then
                    Info:SetSpinnerContinuousSpeed(dedibladeIndex, 0)
                else
                    Info:SetSpinnerContinuousSpeed(dedibladeIndex, 30)
                end
            else
                local desiredAltitude = math.max(waterAltitude, landAltitude + Info:GetTerrainAltitudeForPosition(dediblade.Position.x, dediblade.Position.y, dediblade.Position.z))
                local effectiveAltitude = dediblade.Position.y - dediblade.LocalPosition.y
                local velocity = (effectiveAltitude - (previousAltitudes[dedibladeIndex] or effectiveAltitude)) / frameTime
                local lookaheadAltitude = effectiveAltitude + velocity * altitudeLookaheadTime
                
                if lookaheadAltitude < desiredAltitude then
                    Info:SetSpinnerContinuousSpeed(dedibladeIndex, 30)
                else
                    Info:SetSpinnerContinuousSpeed(dedibladeIndex, -30)
                end
            end
            
            previousAltitudes[dedibladeIndex] = effectiveAltitude
        end
    end
end
