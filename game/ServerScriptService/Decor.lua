-- Low-poly props in the Pet Simulator style: trees and pines made of tilted
-- blocks, faceted rocks, grass tufts, gold coins, little trophies, plank
-- benches, flat hexagon stones, raised garden beds with a stone rim, and
-- string lights with glowing bulbs. All plain parts, a few each.

local MapKit = require(script.Parent:WaitForChild("MapKit"))

local part, ball, cylinder = MapKit.part, MapKit.ball, MapKit.cylinder
local rgb = MapKit.rgb
local V = Vector3.new
local rad = math.rad

local Decor = {}

Decor.Colors = {
	Paving = rgb(216, 216, 242),
	PavingDark = rgb(178, 180, 222),
	Stone = rgb(150, 154, 196),
	Rock = rgb(128, 132, 172),
	Grass = rgb(84, 222, 96),
	GrassDark = rgb(58, 190, 84),
	Leaves = { rgb(76, 214, 92), rgb(96, 228, 104), rgb(62, 196, 88) },
	Pine = { rgb(58, 196, 104), rgb(74, 212, 112), rgb(92, 226, 120) },
	Trunk = rgb(186, 92, 82),
	Wood = rgb(236, 128, 70),
	WoodDark = rgb(196, 96, 52),
	Gold = rgb(255, 208, 40),
	GoldDark = rgb(236, 160, 20),
	Bulb = rgb(255, 238, 196),
	Rope = rgb(222, 120, 60),
}
local C = Decor.Colors

local SMOOTH = Enum.Material.SmoothPlastic

-- a random tilt of up to `deg` degrees
local function tilt(rnd, deg)
	return CFrame.Angles(rad((rnd() - 0.5) * 2 * deg), rad(rnd() * 360), rad((rnd() - 0.5) * 2 * deg))
end

-- A round tree: a leaning trunk and a crown of three tilted blocks.
function Decor.tree(parent, at, size, rnd)
	local m = Instance.new("Model")
	m.Name = "Tree"
	m.Parent = parent
	local lean = CFrame.Angles(rad((rnd() - 0.5) * 10), rad(rnd() * 360), rad((rnd() - 0.5) * 10))
	local trunkH = 7 * size
	local base = CFrame.new(at) * lean
	part(m, "Trunk", V(1.8, trunkH, 1.8) * V(size, 1, size), base * CFrame.new(0, trunkH / 2, 0), C.Trunk, SMOOTH)
	local top = base * CFrame.new(0, trunkH, 0)
	local g = C.Leaves[math.floor(rnd() * #C.Leaves) + 1]
	part(m, "Leaves", V(9, 7, 9) * size, CFrame.new((top * CFrame.new(0, 2 * size, 0)).Position) * tilt(rnd, 18), g, SMOOTH)
	part(m, "Leaves", V(6.5, 5.5, 6.5) * size, CFrame.new((top * CFrame.new(1.6 * size, 5.6 * size, 0.8 * size)).Position) * tilt(rnd, 22),
		g:Lerp(rgb(255, 255, 255), 0.1), SMOOTH)
	part(m, "Leaves", V(5, 4.5, 5) * size, CFrame.new((top * CFrame.new(-2.6 * size, 3.4 * size, -1.4 * size)).Position) * tilt(rnd, 25),
		g:Lerp(rgb(0, 60, 30), 0.12), SMOOTH)
	return m
end

-- A tall pine: blocks stacked up, each smaller and turned a little.
function Decor.pine(parent, at, size, rnd)
	local m = Instance.new("Model")
	m.Name = "Tree"
	m.Parent = parent
	part(m, "Trunk", V(1.6, 4, 1.6) * size, CFrame.new(at + V(0, 2 * size, 0)), C.Trunk, SMOOTH)
	local y = 3.2 * size
	for i = 1, 4 do
		local w = (8.4 - i * 1.5) * size
		local h = 4 * size
		local jitter = V((rnd() - 0.5) * 0.8, 0, (rnd() - 0.5) * 0.8) * size
		part(m, "Needles", V(w, h, w), CFrame.new(at + jitter + V(0, y + h / 2, 0)) * tilt(rnd, 9), C.Pine[(i - 1) % #C.Pine + 1], SMOOTH)
		y += h * 0.78
	end
	return m
end

-- A faceted rock: two or three tilted blocks.
function Decor.rock(parent, at, size, rnd)
	local m = Instance.new("Model")
	m.Name = "Rock"
	m.Parent = parent
	local n = rnd() < 0.5 and 2 or 3
	for i = 1, n do
		local s = (i == 1 and 1 or 0.65) * size
		local off = i == 1 and V(0, 0, 0) or V((rnd() - 0.5) * 3, 0, (rnd() - 0.5) * 3) * size
		part(m, "Rock", V(3.4, 2.8, 3) * s, CFrame.new(at + off + V(0, 1 * s, 0)) * tilt(rnd, 20),
			C.Rock:Lerp(C.Stone, rnd() * 0.6), SMOOTH)
	end
	return m
end

-- A grass tuft: three blades leaning out.
function Decor.tuft(parent, at, size, rnd)
	local yaw = rnd() * 360
	for i = 0, 2 do
		local a = rad(yaw + i * 120)
		local blade = Instance.new("WedgePart")
		blade.Name = "Tuft"
		blade.Anchored = true
		blade.CanCollide = false
		blade.CanTouch = false
		blade.CanQuery = false
		blade.CastShadow = false
		blade.Material = SMOOTH
		blade.Color = C.GrassDark:Lerp(C.Grass, rnd())
		blade.Size = V(0.3, 2.2, 1) * size
		blade.CFrame = CFrame.new(at) * CFrame.Angles(0, a, 0) * CFrame.new(0, 1 * size, 0.4 * size) * CFrame.Angles(rad(18), 0, 0)
		blade.Parent = parent
	end
end

-- A little pile of gold coins.
function Decor.coins(parent, at, rnd)
	for i = 1, 3 do
		local off = V((rnd() - 0.5) * 2.4, 0, (rnd() - 0.5) * 2.4)
		local coin = cylinder(parent, "Coin", 0.35, 1.9, at + off + V(0, 0.15 + i * 0.05, 0), C.Gold, SMOOTH,
			{ CanCollide = false, CastShadow = false, Reflectance = 0.1 })
		coin.CFrame = CFrame.new(coin.Position) * CFrame.Angles(rad((rnd() - 0.5) * 30), rad(rnd() * 360), rad(90 + (rnd() - 0.5) * 30))
	end
	-- one standing up
	local up = cylinder(parent, "Coin", 0.35, 1.9, at + V(0, 0.95, 0), C.Gold, SMOOTH, { CanCollide = false, CastShadow = false, Reflectance = 0.1 })
	up.CFrame = CFrame.new(up.Position) * CFrame.Angles(0, rad(rnd() * 360), 0)
	cylinder(parent, "CoinFace", 0.4, 1.2, at + V(0, 0.95, 0), C.GoldDark, SMOOTH, { CanCollide = false, CastShadow = false }).CFrame = up.CFrame
end

-- A small gold trophy on a dark base.
function Decor.trophy(parent, at, size, rnd)
	local m = Instance.new("Model")
	m.Name = "Trophy"
	m.Parent = parent
	local yaw = CFrame.Angles(0, rad(rnd() * 360), 0)
	local base = CFrame.new(at) * yaw
	part(m, "Base", V(1.6, 0.7, 1.6) * size, base * CFrame.new(0, 0.35 * size, 0), rgb(40, 44, 80), SMOOTH)
	part(m, "Stem", V(0.5, 1.1, 0.5) * size, base * CFrame.new(0, 1.2 * size, 0), C.Gold, SMOOTH)
	local cup = cylinder(m, "Cup", 1.6 * size, 1.8 * size, at + V(0, 1.7 * size, 0), C.Gold, SMOOTH, { Reflectance = 0.15 })
	cup.CFrame = cup.CFrame * CFrame.new(0, 0, 0)
	for _, sx in ipairs({ -1, 1 }) do
		part(m, "Handle", V(0.3, 0.9, 0.3) * size, base * CFrame.new(sx * 1.05 * size, 2.5 * size, 0), C.GoldDark, SMOOTH)
	end
	return m
end

-- A flat hexagon stone (three thin boards turned 60 degrees apart).
function Decor.hexStone(parent, at, width, yaw, color, height)
	height = height or 0.2
	local len = width / math.sqrt(3)
	for i = 0, 2 do
		part(parent, "Stone", V(width, height, len), CFrame.new(at + V(0, height / 2, 0)) * CFrame.Angles(0, rad(yaw + i * 60), 0),
			color or C.PavingDark, SMOOTH, { CastShadow = false, CanCollide = false })
	end
end

-- A plank bench (three seat planks, two back planks, dark legs).
function Decor.bench(parent, cf)
	local m = Instance.new("Model")
	m.Name = "Bench"
	m.Parent = parent
	for i = -1, 1 do
		part(m, "Plank", V(5.6, 0.35, 0.5), cf * CFrame.new(0, 1.45, i * 0.55), i == 0 and C.WoodDark or C.Wood, SMOOTH)
	end
	for i = 0, 1 do
		part(m, "BackPlank", V(5.6, 0.45, 0.3), cf * CFrame.new(0, 2.1 + i * 0.6, 0.95) * CFrame.Angles(rad(-12), 0, 0), C.Wood, SMOOTH)
	end
	for _, sx in ipairs({ -1, 1 }) do
		part(m, "Leg", V(0.45, 1.3, 1.8), cf * CFrame.new(sx * 2.3, 0.65, 0.1), C.WoodDark, SMOOTH)
		part(m, "BackLeg", V(0.4, 1.8, 0.3), cf * CFrame.new(sx * 2.3, 2.2, 1.05), C.WoodDark, SMOOTH)
	end
	return m
end

-- A raised garden bed: an octagon of grass on a wider octagon of stone.
-- cf: the middle of the bed on the ground.
local function octagon(parent, name, cf, w, d, bevel, height, color, material)
	part(parent, name, V(w, height, d - bevel * 2), cf * CFrame.new(0, height / 2, 0), color, material)
	part(parent, name, V(w - bevel * 2, height, d), cf * CFrame.new(0, height / 2, 0), color, material)
	local side = bevel * math.sqrt(2)
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		part(parent, name, V(side, height, side),
			cf * CFrame.new(c[1] * (w / 2 - bevel), height / 2, c[2] * (d / 2 - bevel)) * CFrame.Angles(0, rad(45), 0), color, material)
	end
end
function Decor.bed(parent, cf, w, d, bevel, height)
	local m = Instance.new("Model")
	m.Name = "GardenBed"
	m.Parent = parent
	height = height or 1
	octagon(m, "BedRim", cf, w, d, bevel, height, C.Stone, SMOOTH)
	octagon(m, "BedGrass", cf, w - 1.6, d - 1.6, bevel * 0.8, height + 0.12, C.Grass, SMOOTH)
	return m, height + 0.12
end

-- String lights from `a` to `b` (hanging `sag` studs in the middle), with a
-- glowing bulb every few studs.
function Decor.stringLights(parent, a, b, sag, bulbs)
	local m = Instance.new("Model")
	m.Name = "StringLights"
	m.Parent = parent
	local segments = bulbs + 1
	local function at(t) return a:Lerp(b, t) - V(0, sag * 4 * t * (1 - t), 0) end
	for i = 0, segments - 1 do
		local p0, p1 = at(i / segments), at((i + 1) / segments)
		MapKit.rod(m, "Rope", p0, p1, 0.18, C.Rope, SMOOTH, { CanCollide = false, CastShadow = false, CanQuery = false })
		if i > 0 then
			ball(m, "Bulb", 0.9, p0 - V(0, 0.45, 0), C.Bulb, Enum.Material.Neon, { CanCollide = false, CastShadow = false, CanQuery = false })
		end
	end
	return m
end

return Decor
