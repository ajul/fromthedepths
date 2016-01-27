-- All turrets in this weapon slot are assumed to be interceptors.
interceptorWeaponSlot = 5
-- We crudely assume constant interceptor speed. Figure ~200 for grenades and ~250 for rockets.
interceptorSpeed = 200.0
-- Cull interceptors after this time to save resources.
interceptorLifetime = 3.0
-- Detonate (attack) within this radius. Maximum is 20.
interceptorRadius = 20

-- Index -> warning.
warnings = {}

-- Which mainframe is providing the warnings.
interceptorMainframeIndex = 0

WEAPON_TYPE_TURRET = 4

function UpdateInfo()
    local newTimestamp = I:GetGameTime()
    frameDuration = newTimestamp - currentTimestamp
    currentTimestamp = newTimestamp
    
end

function UpdateWarnings()
    warnings = {}
    for mainframeIndex = 0, Info:GetNumberOfMainframes() - 1 do
        local numberOfWarnings = Info:GetNumberOfWarnings(mainframeIndex)
        if numberOfWarnings > 0 then
            for warningIndex0 = 0, numberOfWarnings - 1 do
                -- add one... dammit Lua
                warnings[warningIndex0 + 1] = Info:GetMissileWarning(mainframeIndex, warningIndex0)
            end
            interceptorMainframeIndex = mainframeIndex
            return
        end
    end
end

function ControlInterceptors()
    -- Controls interceptors. Since they are not guided, this is only fuse and culling.
    for transceiverIndex = 0, I:GetLuaTransceiverCount() - 1 do
        for interceptorIndex = 0, I:GetLuaControlledMissileCount(transceiverIndex) - 1 do
            local interceptor = I:GetLuaControlledMissileInfo(transceiverIndex, interceptorIndex)
            if I:IsLuaControlledMissileAnInterceptor(transceiverIndex, interceptorIndex) then
                if interceptor.TimeSinceLaunch > interceptorLifetime then
                    -- Cull after lifetime.
                    I:DetonateLuaControlledMissile(transceiverIndex, interceptorIndex)
                else
                    local warningIndex = SelectInterceptorTarget(interceptor)
                    if warningIndex ~= nil then
                        I:SetLuaControlledMissileInterceptorTarget(transceiverIndex, interceptorIndex, interceptorMainframeIndex, warningIndex)
                    end
                end
            end
        end
    end
end

function SelectInterceptorTarget(interceptor)
    -- Selects the nearest known missile within destruction radius.
    local warningIndex = nil
    local minDistance = interceptorRadius
    for warningIndex1, warning in ipairs(warnings) do
        if warning.Valid then
            local thisDistance = Vector3.Distance(warning.Position, interceptor.Position) 
            if thisDistance < minDistance then
                minDistance = thisDistance
                warningIndex = warningIndex1 - 1
            end
        end
    end
    return warningIndex
end
