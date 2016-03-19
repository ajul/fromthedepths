g = 9.81
suborbitalAltitude = 500
orbitalAltitude = 900
epsilon = 1e-3

suborbitalHeight = orbitalAltitude - suborbitalAltitude
suborbitalTau = math.sqrt(suborbitalHeight / g)
suborbitalEnergy = 0.5 * g * suborbitalHeight

function AltitudeAtTime(y0, vy0, t)
	if y0 <= suborbitalAltitude then
		local suborbitalT = AirToSuborbitalTime(y0, vy0)
		if suborbitalT and t > suborbitalT then
			-- Advance to suborbital.
			local new_vy0 = vy0 - g * suborbitalT
			return AltitudeAtTime(suborbitalAltitude + epsilon, new_vy0, t - suborbitalT)
		else
			return y0 + (vy0 - 0.5 * g * t) * t
		end
	elseif y0 <= orbitalAltitude then
		local orbitalT, excess_vy = SuborbitalSinhVertex(y0, vy0)
		if orbitalT then
			-- Hyperbolic sine trajectory.
			if orbitalT > 0 then
				-- We are able to reach orbit.
				if t > orbitalT then
					-- We enter orbital.
					return AltitudeAtTime(orbitalAltitude + epsilon, excess_vy, t - orbitalT)
				else
					-- Not enough time to enter orbital.
					local shortfallT = orbitalT - t
					local shortfallY = suborbitalTau * excess_vy * math.sinh(shortfallT / suborbitalTau)
					return orbitalAltitude - shortfallY
				end
			else
				-- We are returning from an orbital trajectory.
				local suborbitalT = suborbitalTau * arcsinh(suborbitalHeight / (suborbitalTau * excess_vy)) + orbitalT
				if t > suborbitalT then
					return AltitudeAtTime(suborbitalAltitude - epsilon, -excess_vy, t - suborbitalT)
				else
					local timeSinceOrbital = t - orbitalT
					local fallSinceOrbital = suborbitalTau * excess_vy * math.sinh(timeSinceOrbital / suborbitalTau)
					return orbitalAltitude - fallSinceOrbital
				end
			end
		else
			-- Hyperbolic cosine trajectory.
			local vertexT, shortfallY = SuborbitalCoshVertex(y0, vy0)
			
			local vertexToSuborbitalT = suborbitalTau * arccosh(suborbitalHeight / shortfallY)
			local suborbitalT = vertexToSuborbitalT + vertexT
			if t > suborbitalT then
				return AltitudeAtTime(suborbitalAltitude - epsilon, ???, t - suborbitalT)
			else
				
			end
		end
	else
		if vy0 < 0 then
			local suborbitalT = (orbitalAltitude - y0) / vy0
			if t > suborbitalT then
				-- We enter suborbital.
				return AltitudeAtTime(orbitalAltitude - epsilon, vy0, t - suborbitalT)
			end
		end
		-- We do not exit orbit in the given time.
		return y0 + vy0 * t
	end
end

function AirToSuborbitalTime(y0, vy0)
	-- Computes time to reach air-suborbital boundary from the air side.
	if vy0 < 0 then
		-- Wrong direction.
		return nil
	end
	local a = 0.5 * g
    local b = vy
    local c = suborbitalAltitude - y0
    local vertex = -b / (2 * a)
    local discriminant = vertex*vertex - c / a
    if discriminant > 0 then
        local width = math.sqrt(discriminant)
        return vertex - width
    else
		-- Not enough energy.
        return nil
    end
end

function SuborbitalSinhVertex(y0, vy0)
	-- Returns time to reach orbit (may be negative), absolute vertical velocity when reaching orbit.
	
	-- Energy needed to escape into orbital.
	local escapeAltitudeChange = orbitalAltitude - y0
	local escapeEnergy = 0.5 * g * escapeAltitudeChange * escapeAltitudeChange / suborbitalHeight
	local excessEnergy = 0.5 * vy0 * vy0 - escapeEnergy
	if excessEnergy < 0 then
		return nil, nil
	end
	
	local excess_vy = math.sqrt(2 * excessEnergy)
	local suborbitalT = suborbitalTau * arcsinh(escapeAltitudeChange / (suborbitalTau * excess_vy))
	if vy0 < 0 then
		suborbitalT = -suborbitalT
	end
	return suborbitalT, excess_vy
end

function SuborbitalCoshVertex(y0, vy0)
	-- Returns time to reach suborbital.
	local escapeAltitudeChange = orbitalAltitude - y0
	local escapeEnergy = 0.5 * g * escapeAltitudeChange * escapeAltitudeChange / suborbitalHeight
	local shortfallEnergy = escapeEnergy - 0.5 * vy0 * vy0
	
	local shortfallY = math.sqrt(2.0 * shortfallEnergy * suborbitalHeight / g)
	local vertexY = orbitalAltitude - shortfallY
	local vertexT = suborbitalTau * arccosh(escapeAltitudeChange / shortfallY)
	if vy0 < 0 then
		vertexT = -vertexT
	end
	return vertexT, vertexY
end

function arcsinh(x)
	return math.log(x + math.sqrt(x*x + 1))
end

function arccosh(x)
	return math.log(x + math.sqrt(x*x - 1))
end