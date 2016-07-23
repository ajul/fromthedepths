function Update(I)
    for missileIndex = 0, I:GetLuaControlledMissileCount(0) - 1 do
        local missile = I:GetMissileInfo(0, missileIndex)
        for k, v in ipairs(missile.Parts) do
            if string.find(v.Name, 'magnet') then
                v:SendRegister(1, 1000)
            end
        end
    end
end
