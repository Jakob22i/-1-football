-- The maths the drills share between the server (which decides) and the
-- client (which draws the same thing): where a moving target is at a time,
-- where an attacker is, the gym marker, and how a shot or a pass lands.
-- Times are workspace:GetServerTimeNow() on both sides.

local DrillMath = {}

function DrillMath.Right(dir)
	return dir:Cross(Vector3.yAxis)
end

function DrillMath.Flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- A point on the goal mouth: u across (0 = middle), v up from the ground.
function DrillMath.GoalPoint(goalCF, u, v)
	return (goalCF * CFrame.new(u, v, 0)).Position
end

-- Shooting targets drift about on the goal mouth.
-- target = { U0, V0, AU, AV, W, Phase, T0, R }
function DrillMath.TargetPos(target, t)
	local k = t - target.T0
	local u = target.U0 + target.AU * math.sin(target.W * k + target.Phase)
	local v = target.V0 + target.AV * math.sin(target.W * 0.8 * k + target.Phase * 1.3)
	return u, v
end

-- An attacker running from Start to End, weaving less as it gets close.
-- att = { Start, End, T0, Duration, Amp, Freq }
function DrillMath.AttackerPos(att, t)
	local k = math.clamp((t - att.T0) / att.Duration, 0, 1)
	local base = att.Start:Lerp(att.End, k)
	local dir = DrillMath.Flat(att.End - att.Start)
	if dir.Magnitude < 0.01 then return base end
	local side = DrillMath.Right(dir.Unit)
	local weave = att.Amp * math.sin(att.Freq * math.max(0, t - att.T0)) * (1 - k)
	return base + side * weave
end

function DrillMath.AttackerDone(att, t)
	return t >= att.T0 + att.Duration
end

-- The gym marker: 0..1 across the bar and back again.
-- rep = { Start, Period }
function DrillMath.Marker(rep, t)
	local x = math.max(0, t - rep.Start) / rep.Period % 2
	return x <= 1 and x or 2 - x
end

-- A number from a normal distribution (mean 0, sd 1).
function DrillMath.Gauss(rng)
	local u1 = math.max(rng:NextNumber(), 1e-9)
	local u2 = rng:NextNumber()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

-- How a shot lands. aim: u, v on the goal mouth; power 0..1; spread in studs
-- at a perfect power. Returns the landing u, v.
function DrillMath.ShotLanding(u, v, power, spread, green, rng)
	local off = 0
	if power < green[1] then off = green[1] - power elseif power > green[2] then off = power - green[2] end
	local s = spread * (1 + math.min(off, 0.45) * 4)
	-- too little power drops the ball, too much lifts it
	local lift = (power - (green[1] + green[2]) / 2) * 5
	local r = s * math.sqrt(rng:NextNumber())
	local a = rng:NextNumber() * math.pi * 2
	return u + math.cos(a) * r, v + math.sin(a) * r + lift
end

-- How a pass lands on the ground: from `spot` toward the aim point with
-- `power` of the full distance, with some sideways and length error.
function DrillMath.PassLanding(spot, aim, power, maxDistance, sideSd, lengthSd, rng)
	local dir = DrillMath.Flat(aim - spot)
	if dir.Magnitude < 0.5 then dir = Vector3.new(0, 0, -1) end
	dir = dir.Unit
	local length = math.max(2, power * maxDistance + DrillMath.Gauss(rng) * lengthSd)
	local sideAngle = DrillMath.Gauss(rng) * sideSd / math.max(length, 8)
	local cosA, sinA = math.cos(sideAngle), math.sin(sideAngle)
	local rotated = Vector3.new(dir.X * cosA - dir.Z * sinA, 0, dir.X * sinA + dir.Z * cosA)
	return DrillMath.Flat(spot) + rotated * length
end

-- Where a landing is compared with a target: how far along the line to it
-- and how far off to the side.
function DrillMath.PassError(spot, target, landing)
	local to = DrillMath.Flat(target - spot)
	local distance = to.Magnitude
	local u = to.Unit
	local rel = DrillMath.Flat(landing - spot)
	local along = rel:Dot(u)
	local side = rel:Dot(DrillMath.Right(u))
	return along - distance, side, distance
end

return DrillMath
