-- A footballer made of parts, for the drills: the attackers you tackle, the
-- keeper, your teammates in the stadium and the passing dummies. Hair, a
-- face, a kit with a trim and a number on the back, shorts, socks, boots
-- with coloured soles, and a keeper with gloves. Arms and legs swing when it
-- runs (PlayerFigure.Pose with a stride).
--
--   local fig = PlayerFigure.Build(folder, { Shirt = red, Accent = white }, { Local = true, Seed = 3 })
--   PlayerFigure.Pose(fig, CFrame.lookAt(pos + Vector3.new(0, 3, 0), ...), os.clock() * 12)
--
-- The model is built facing -Z with its feet at y = 0; its pivot (and
-- PrimaryPart) is the torso, 3 studs up.

local PlayerFigure = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local SKIN = { rgb(255, 214, 170), rgb(234, 184, 146), rgb(198, 140, 100), rgb(150, 98, 64), rgb(104, 66, 44) }
local HAIR = { rgb(30, 22, 18), rgb(72, 46, 28), rgb(140, 92, 50), rgb(226, 190, 110), rgb(20, 20, 24), rgb(170, 60, 30) }
local STYLES = { "Short", "Short", "Mohawk", "Afro", "Spiky", "Bald" }
local BOOT = rgb(24, 24, 30)
local FACE = "rbxasset://textures/face.png"

-- the joints, from the torso's centre
local JOINTS = {
	LL = Vector3.new(-0.5, -1, 0), RL = Vector3.new(0.5, -1, 0),
	LA = Vector3.new(-1.5, 0.8, 0), RA = Vector3.new(1.5, 0.8, 0),
}
local SWING = { LL = 1, RL = -1, LA = -0.8, RA = 0.8 }

local rigs = setmetatable({}, { __mode = "k" }) -- model -> { { part, offset, limb } }

function PlayerFigure.Build(parent, kit, opts)
	kit = kit or {}
	opts = opts or {}
	local seed = opts.Seed or math.random(1, 100000)
	local function pick(list, salt) return list[(seed * 7 + salt * 13) % #list + 1] end

	local shirt = kit.Shirt or rgb(230, 40, 50)
	local accent = kit.Accent or rgb(255, 255, 255)
	local shorts = kit.Shorts or accent
	local socks = kit.Socks or shirt
	local skin = kit.Skin or pick(SKIN, 1)
	local hair = kit.Hair or pick(HAIR, 2)
	local style = kit.HairStyle or pick(STYLES, 3)
	local number = kit.Number or (seed % 11) + 1

	local m = Instance.new("Model")
	m.Name = opts.Name or "Figure"
	local entries = {}

	local function add(name, size, pos, color, limb, props)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if opts.Local then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
		end
		for k, v in pairs(props or {}) do p[k] = v end
		p.CFrame = CFrame.new(pos)
		p.Parent = m
		table.insert(entries, { p, CFrame.new(pos - Vector3.new(0, 3, 0)), limb })
		return p
	end

	-- legs: shorts, knee, sock with a band, boot with a coloured sole
	for _, side in ipairs({ -1, 1 }) do
		local limb = side < 0 and "LL" or "RL"
		local x = side * 0.5
		add("Shorts", Vector3.new(1, 0.8, 1.05), Vector3.new(x, 1.65, 0), shorts, limb)
		add("Knee", Vector3.new(0.86, 0.36, 0.86), Vector3.new(x, 1.08, 0), skin, limb)
		add("Sock", Vector3.new(0.92, 0.72, 0.92), Vector3.new(x, 0.6, 0), socks, limb)
		add("SockBand", Vector3.new(0.95, 0.14, 0.95), Vector3.new(x, 0.9, 0), accent, limb)
		add("Boot", Vector3.new(0.98, 0.36, 1.3), Vector3.new(x, 0.22, -0.14), BOOT, limb)
		add("Sole", Vector3.new(1, 0.08, 1.32), Vector3.new(x, 0.04, -0.14), kit.Sole or accent, limb)
	end

	-- torso: the shirt with a collar, side stripes, a badge and the number
	local torso = add("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), shirt)
	add("Collar", Vector3.new(1, 0.2, 1.04), Vector3.new(0, 3.92, 0), accent)
	for _, side in ipairs({ -1, 1 }) do
		add("Stripe", Vector3.new(0.14, 2, 1.04), Vector3.new(side * 0.95, 3, 0), accent)
	end
	add("Badge", Vector3.new(0.34, 0.4, 0.06), Vector3.new(-0.5, 3.45, -0.52), rgb(255, 204, 40))
	local numberGui = Instance.new("SurfaceGui")
	numberGui.Name = "Number"
	numberGui.Face = Enum.NormalId.Back
	numberGui.CanvasSize = Vector2.new(100, 100)
	numberGui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = tostring(number)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = accent
	label.Parent = numberGui
	numberGui.Parent = torso

	-- arms: sleeve with a cuff, forearm, hand (a keeper has long sleeves and gloves)
	for _, side in ipairs({ -1, 1 }) do
		local limb = side < 0 and "LA" or "RA"
		local x = side * 1.5
		add("Sleeve", Vector3.new(0.95, 0.9, 1), Vector3.new(x, 3.52, 0), shirt, limb)
		add("Cuff", Vector3.new(0.97, 0.14, 1.02), Vector3.new(x, 3.08, 0), accent, limb)
		add("Arm", Vector3.new(0.86, 1.1, 0.88), Vector3.new(x, 2.46, 0), kit.Keeper and shirt or skin, limb)
		if kit.Keeper then
			add("Glove", Vector3.new(1.1, 0.62, 1.1), Vector3.new(x, 1.72, 0), kit.Gloves or rgb(255, 255, 255), limb)
		else
			add("Hand", Vector3.new(0.8, 0.42, 0.84), Vector3.new(x, 1.72, 0), skin, limb)
		end
	end

	-- head with a face, then hair
	local head = add("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.62, 0), skin)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = FACE
	face.Parent = head
	if style == "Short" then
		add("Hair", Vector3.new(1.34, 0.36, 1.34), Vector3.new(0, 5.2, 0.04), hair)
		add("Hair", Vector3.new(1.34, 0.7, 0.3), Vector3.new(0, 4.95, 0.56), hair)
	elseif style == "Mohawk" then
		add("Hair", Vector3.new(0.34, 0.6, 1.36), Vector3.new(0, 5.36, 0.05), hair)
	elseif style == "Afro" then
		add("Hair", Vector3.new(1.9, 1.9, 1.9), Vector3.new(0, 5.25, 0.18), hair, nil, { Shape = Enum.PartType.Ball })
	elseif style == "Spiky" then
		add("Hair", Vector3.new(1.34, 0.3, 1.34), Vector3.new(0, 5.18, 0.04), hair)
		for i = -1, 1 do
			local spike = add("Hair", Vector3.new(0.45, 0.45, 0.45), Vector3.new(i * 0.42, 5.42, 0.05), hair)
			spike.CFrame = CFrame.new(spike.Position) * CFrame.Angles(0, 0, math.rad(45))
			entries[#entries][2] = CFrame.new(spike.Position - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(45))
		end
	end
	if kit.Headband then
		add("Headband", Vector3.new(1.3, 0.2, 1.3), Vector3.new(0, 4.98, 0), kit.Headband)
	end

	m.PrimaryPart = torso
	rigs[m] = entries
	m.Parent = parent
	return m
end

-- Puts the figure's torso at `cf`. With a stride (an angle that keeps
-- growing while it runs) the arms and legs swing; without one it stands.
function PlayerFigure.Pose(fig, cf, stride)
	local entries = rigs[fig]
	if not entries then
		fig:PivotTo(cf)
		return
	end
	local swing = stride and math.sin(stride) * 0.75 or 0
	local limbs = {}
	for limb, joint in pairs(JOINTS) do
		limbs[limb] = CFrame.new(joint) * CFrame.Angles(swing * SWING[limb], 0, 0) * CFrame.new(-joint)
	end
	for _, e in ipairs(entries) do
		local part, offset, limb = e[1], e[2], e[3]
		if part.Parent then
			part.CFrame = limb and (cf * limbs[limb] * offset) or (cf * offset)
		end
	end
end

-- The kits used in the drills.
PlayerFigure.Kits = {
	Attacker = { Shirt = rgb(220, 36, 48), Accent = rgb(255, 255, 255), Shorts = rgb(255, 255, 255), Socks = rgb(220, 36, 48), Sole = rgb(255, 210, 40) },
	Teammate = { Shirt = rgb(36, 110, 240), Accent = rgb(255, 255, 255), Shorts = rgb(16, 30, 80), Socks = rgb(36, 110, 240), Sole = rgb(80, 255, 140) },
	Keeper = { Shirt = rgb(60, 220, 90), Accent = rgb(12, 18, 48), Shorts = rgb(12, 18, 48), Socks = rgb(60, 220, 90), Keeper = true, Gloves = rgb(255, 255, 255), Number = 1 },
	Dummy = { Shirt = rgb(255, 214, 60), Accent = rgb(22, 36, 88), Shorts = rgb(22, 36, 88), Socks = rgb(255, 214, 60) },
}

return PlayerFigure
