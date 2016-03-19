-- Weapon slot to use. Only cannons will be controlled regardless. 0 controls all slots.
weaponSlot = 1

-- What order polynomial to use. 1 = linear (similar to stock), 2 = quadratic (acceleration)
predictionOrder = 2

-- Don't fire beyond this range.
maximumRange = 3000

-- How many iterations to run algorithm.
iterationCount = 16

-- Altitude accuracy required to fire.
altitudeTolerance = 1

-- The I in Update(I).
I = nil

-- Time and duration of the current frame.
frameTime = 0
frameDuration = 1/40

myPosition = Vector3.zero

-- Current target.
target = nil

-- Position, velocity, acceleration... of the current target.
targetDerivatives = {}

-- Velocity is special because cannon projectiles inherit our velocity.
relativeVelocity = Vector3.zero

-- Constants.
g = 9.81
suborbitalStart = 500
orbitalStart = 900
epsilon = 0.01

suborbitalHeight = orbitalStart - suborbitalStart
suborbitalTau = math.sqrt(suborbitalHeight / g)
suborbitalEnergy = 0.5 * g * suborbitalHeight

projectileLifetime = 20

-- Fake speed for missiles.
missileSpeed = 100

function Update(Iarg)
    I = Iarg
    
    UpdateInfo()

    if target ~= nil then
        for weaponIndex = 0, I:GetWeaponCount() - 1 do
            local weapon = I:GetWeaponInfo(weaponIndex)
			if ((weaponSlot == 0 or weapon.WeaponSlot == weaponSlot) and
			    weapon.Speed > 0 and weapon.Speed ~= missileSpeed) then
				ControlWeapon(weaponIndex, weapon)
			end
        end
    end
end

function UpdateInfo()
    local newFrameTime = I:GetGameTime()
    frameDuration = newFrameTime - frameTime
    frameTime = newFrameTime
	
	myPosition = I:GetConstructPosition()

    -- Find a target. Prefer AIs with scores, and take the last AI otherwise.
    local newTarget = nil
    local targetingMainframeIndex = nil
    for mainframeIndex = 0, I:GetNumberOfMainframes() - 1 do
        local firstTarget = I:GetTargetInfo(mainframeIndex, 0)
        if firstTarget.Valid then
            if newTarget == nil or firstTarget.Score ~= 0 then
                newTarget = firstTarget
                targetingMainframeIndex = mainframeIndex
            end 
        end
    end
    
    -- Limit range.
    if newTarget ~= nil and Vector3.Distance(newTarget.Position, myPosition) > maximumRange then
        newTarget = nil
    end

    if newTarget ~= nil then
        -- compute derivatives
        local newTargetDerivatives = { newTarget.Position }
        if (target ~= nil and newTarget.Id == target.Id) then
            for i = 1, math.min(#newTargetDerivatives, predictionOrder) do
                newTargetDerivatives[i+1] = (newTargetDerivatives[i] - targetDerivatives[i]) / frameDuration
            end
        end
        targetDerivatives = newTargetDerivatives
    else
        -- No target.
        targetDerivatives = {}
    end
    
    relativeVelocity = (targetDerivatives[2] or Vector3.zero) - I:GetVelocityVector()
    
    target = newTarget
end

function ControlWeapon(weaponIndex, weapon)
	local aim = ComputeAim(weapon)
	if aim ~= nil then
		if I:AimWeaponInDirection(weaponIndex, aim.x, aim.y, aim.z, weaponSlot) then
			I:FireWeapon(weaponIndex, weaponSlot)
		end
	end
end

function PredictPosition(t)
    -- Predicted position of target after time t.
    local result = targetDerivatives[0] + relativeVelocity * t
    local timeFactor = t
    for i = 3, #targetDerivatives do
        timeFactor = timeFactor * t / (i - 1)
        result = result + targetDerivatives[i] * timeFactor
    end
    return result
end

function ComputeAim(weapon)
	local t = Vector3.Distance(target.Position, weapon.GlobalPosition) / weapon.Speed
	
	local vx, vy0, altitudeError, relativePosition
	
	for i=1,iterationCount do
		t = math.min(projectileLifetime, t)
		t = math.max(0, t)
		
		local predictedPosition = PredictPosition(t)
		relativePosition = predictedPosition - weapon.GlobalPosition
		local x = HorizontalMagnitude(relativePosition)
		local vx = x / t
		
		if (weapon.Speed >= vx) then
			local vy0 = math.sqrt(weapon.Speed * weapon.Speed - vx * vx)
			
			if weapon.GlobalPosition.y <= target.Position then
				altitudeError = AltitudeAtTime(weapon.GlobalPosition.y, vy0, t) - predictedPosition.y
			else
				altitudeError = AltitudeAtTime(predictedPosition.y, vy0, t) - weapon.GlobalPosition.y
			end
			
			-- Compute error derivative.
			local horizontalRangeRate = relativeVelocity.x * relativePosition.normalized.x + relativeVelocity.z * relativePosition.normalized.z
			local dvx_dt = (horizontalRangeRate - x / t) / t
			local altitudeErrorDerivative = -(vx / vy0) * dvx_dt - targetVelocity.y
			t = t - altitudeError / altitudeDerivative
		else
			return nil
		end
	end
	
	if altitudeError < altitudeTolerance then
		return Vector3(relativePosition.x, t * vy0, relativePosition.z)
	end
end

function AltitudeAtTime(y0, vy0, t)
	if t <= epsilon then
		return y0
	end

	if y0 <= suborbitalStart then
		-- Aerial segment.
		local suborbitalT = AirToSuborbitalTime(y0, vy0)
		if suborbitalT and t > suborbitalT then
			-- Advance to suborbital.
			local new_vy0 = vy0 - g * suborbitalT
			return AltitudeAtTime(suborbitalStart + epsilon, new_vy0, t - suborbitalT)
		else
			return y0 + (vy0 - 0.5 * g * t) * t
		end
	elseif y0 <= orbitalStart then
		-- Suborbital segment.
		local vertexT, transition_vy, shortfallY = SuborbitalVertex(y0, vy0)
		
		if shortfallY == nil then
			-- Hyperbolic sine trajectory.
			if vertexT > 0 then
				-- Heading towards orbit.
				if t > vertexT then
					-- We reach orbit.
					return AltitudeAtTime(orbitalStart + epsilon, transition_vy, t - vertexT)
				else
					-- Not enough time to reach orbit.
					local timeBeforeOrbit = vertexT - t
					local altitudeBeforeOrbit = suborbitalTau * transition_vy * math.sinh(timeBeforeOrbit / suborbitalTau)
					return orbitalStart - altitudeBeforeOrbit
				end
			else
				-- Heading away from orbit.
				local transitionT = suborbitalTau * arcsinh(suborbitalHeight / (suborbitalTau * transition_vy)) + vertexT
				if t > transitionT then
					-- We reach air.
					return AltitudeAtTime(suborbitalStart - epsilon, -transition_vy, t - transitionT)
				else
					-- Not enough time to reach air.
					local timeSinceOrbital = t - vertexT
					local fallSinceOrbital = suborbitalTau * transition_vy * math.sinh(timeSinceOrbital / suborbitalTau)
					return orbitalStart - fallSinceOrbital
				end
			end
		else
			-- Hyperbolic cosine trajectory.
			local vertexToSuborbitalT = suborbitalTau * arccosh(suborbitalHeight / shortfallY)
			local transitionT = vertexToSuborbitalT + vertexT
			if t > transitionT then
				-- We reach air.
				return AltitudeAtTime(suborbitalStart - epsilon, -transition_vy, t - transitionT)
			else
				-- Not enough time to reach air.
				local timeSinceVertex = t - vertexT
				local fallSinceVertex = shortfallY * math.cosh(timeSinceVertex / suborbitalTau)
				return orbitalStart - fallSinceVertex
			end
		end
	else
		-- Orbital segment.
		if vy0 < 0 then
			local suborbitalT = (orbitalStart - y0) / vy0
			if t > suborbitalT then
				-- We enter suborbital.
				return AltitudeAtTime(orbitalStart - epsilon, vy0, t - suborbitalT)
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
    local c = suborbitalStart - y0
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

function SuborbitalVertex(y0, vy0)
	-- Returns time to vertex (may be negative), absolute velocity at transition, shortfall relative to orbit (only if not enough energy to reach orbit)

	-- Altitude relative to orbital altitude.
	local orbital_y = y0 - orbitalStart
	-- Energy needed to escape to orbit from current altitude.
	local escapeEnergy = 0.5 * g * orbital_y * orbital_y / suborbitalHeight
	-- Energy relative to that needed to escape into orbit.
	local excessEnergy = 0.5 * vy0 * vy0 - escapeEnergy
	
	if excessEnergy > 0 then
		-- Trajectory is a hyperbolic sine.
		local excess_vy = math.sqrt(2 * excessEnergy)
		local vertexT = suborbitalTau * arcsinh(escapeAltitudeChange / (suborbitalTau * excess_vy))
		if vy0 < 0 then
			vertexT = -vertexT
		end
		return vertexT, excess_vy, nil
	else
		-- Trajectory is a hyperbolic cosine.
		
		-- Velocity when dropping back into air.
		local air_vy = math.sqrt(2.0 * (suborbitalEnergy + excessEnergy))
		-- How far short of orbit.
		local shortfallY = math.sqrt(-2.0 * excessEnergy * suborbitalHeight / g)
		local vertexY = orbitalStart - shortfallY
		local vertexT = suborbitalTau * arccosh(escapeAltitudeChange / shortfallY)
		if vy0 < 0 then
			vertexT = -vertexT
		end
		return vertexT, air_vy, shortfallY
	end
end

function HorizontalMagnitude(v)
	return math.sqrt(v.x * v.x + v.z * v.z)
end

function arcsinh(x)
	return math.log(x + math.sqrt(x*x + 1))
end

function arccosh(x)
	return math.log(x + math.sqrt(x*x - 1))
end

function LogBoth(s)
    I:Log(s)
    I:LogToHud(s)
end