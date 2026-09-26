-- Helpers for building the map out of parts: blocks, cylinders, rings,
-- painted lines, signs with text, glowing gates.

local MapKit = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
MapKit.rgb = rgb

MapKit.Colors = {
	Grass = rgb(84, 176, 72),
	GrassDark = rgb(70, 156, 62),
	GrassLight = rgb(98, 192, 84),
	Line = rgb(250, 250, 250),
	Concrete = rgb(214, 214, 208),
	ConcreteDark = rgb(170, 170, 166),
	Path = rgb(196, 198, 190),
	Track = rgb(196, 78, 58),
	Navy = rgb(22, 36, 88),
	NavyDark = rgb(12, 20, 54),
	Blue = rgb(40, 130, 255),
	White = rgb(255, 255, 255),
	Gold = rgb(255, 200, 40),
	Red = rgb(230, 50, 60),
	Orange = rgb(255, 130, 20),
	Rubber = rgb(52, 54, 66),
	Metal = rgb(150, 156, 170),
	Wood = rgb(160, 110, 60),
}
local COL = MapKit.Colors

function MapKit.part(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color or COL.Concrete
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false -- nothing listens for touches on the map
	for k, v in pairs(props or {}) do p[k] = v end
	p.Parent = parent
	return p
end
local part = MapKit.part

-- A flat patch on the ground (the baseplate's top is y = 0).
function MapKit.patch(parent, name, width, depth, cf, color, material, height, props)
	height = height or 0.2
	return part(parent, name, Vector3.new(width, height, depth), cf * CFrame.new(0, height / 2, 0), color, material or Enum.Material.SmoothPlastic, props)
end

-- A painted line from a to b (points on the ground), `width` wide.
function MapKit.line(parent, a, b, width, y, color)
	local mid = (a + b) / 2
	local length = (b - a).Magnitude
	if length < 0.05 then return nil end
	local cf = CFrame.lookAt(Vector3.new(mid.X, y or 0.24, mid.Z), Vector3.new(b.X, y or 0.24, b.Z))
	return part(parent, "Line", Vector3.new(width or 0.5, 0.05, length), cf, color or COL.Line, Enum.Material.SmoothPlastic,
		{ CanCollide = false, CanQuery = false, CanTouch = false })
end

-- A standing cylinder: `at` is the centre of its base.
function MapKit.cylinder(parent, name, height, diameter, at, color, material, props)
	local cf = CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local p = part(parent, name, Vector3.new(height, diameter, diameter), cf, color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A cylinder between two points (posts, bars).
function MapKit.rod(parent, name, a, b, diameter, color, material, props)
	local length = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	local p = part(parent, name, Vector3.new(length, diameter, diameter), cf, color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function MapKit.ball(parent, name, diameter, at, color, material, props)
	local p = part(parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(at), color, material, props)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A flat ring on the ground made of short blocks.
function MapKit.ring(parent, name, center, radius, width, color, segments, y, height, material)
	segments = segments or 36
	height = height or 0.05
	local parts = {}
	local step = 2 * math.pi / segments
	local chord = 2 * radius * math.sin(step / 2) + 0.15
	for i = 0, segments - 1 do
		local a = i * step
		local pos = center + Vector3.new(math.cos(a) * radius, (y or 0.24) + height / 2 - 0.025, math.sin(a) * radius)
		local cf = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
		table.insert(parts, part(parent, name, Vector3.new(width, height, chord), cf, color, material or Enum.Material.SmoothPlastic,
			{ CanCollide = height > 0.5, CanQuery = height > 0.5 }))
	end
	return parts
end

-- A filled disc on the ground.
function MapKit.disc(parent, name, center, diameter, color, height, material, props)
	height = height or 0.2
	local p = part(parent, name, Vector3.new(height, diameter, diameter),
		CFrame.new(center + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

--------------------------------------------------------------------------------
-- Text on parts
--------------------------------------------------------------------------------

local function uiText(parent, text, size, color, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color or COL.White
	l.Size = UDim2.fromScale(1, 1)
	for k, v in pairs(props or {}) do l[k] = v end
	local s = Instance.new("UIStroke")
	s.Thickness = size or 4
	s.Color = COL.NavyDark
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = l
	l.Parent = parent
	return l
end
MapKit.uiText = uiText

function MapKit.surface(target, face, pps)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps or 30
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Adornee = target
	gui.Parent = target
	return gui
end

-- A big sign board on two posts. cf: the middle of the board's bottom edge,
-- facing the way people read it from (LookVector toward them).
-- lines = { { text, color, share of the height }, ... }
function MapKit.sign(parent, name, width, height, cf, lines, colors, raise)
	raise = raise or 6
	local folder = Instance.new("Model")
	folder.Name = name
	folder.Parent = parent
	colors = colors or { COL.Navy, COL.Gold }
	for _, side in ipairs({ -1, 1 }) do
		local foot = cf * CFrame.new(side * (width / 2 - 0.8), 0, 0.4)
		MapKit.cylinder(folder, "Post", raise + height, 1, foot.Position, COL.Metal, Enum.Material.Metal)
	end
	local board = part(folder, "Board", Vector3.new(width, height, 0.8), cf * CFrame.new(0, raise + height / 2, 0), colors[1], Enum.Material.SmoothPlastic)
	part(folder, "Trim", Vector3.new(width + 0.6, height + 0.6, 0.6), cf * CFrame.new(0, raise + height / 2, 0.25), colors[2], Enum.Material.SmoothPlastic)
	local gui = MapKit.surface(board, Enum.NormalId.Front, 28)
	local y = 0.06
	local share = 0
	for _, entry in ipairs(lines) do share += entry[3] or 1 end
	for _, entry in ipairs(lines) do
		local h = (entry[3] or 1) / share * 0.88
		uiText(gui, entry[1], entry[4] or 5, entry[2] or COL.White, {
			Position = UDim2.fromScale(0.04, y),
			Size = UDim2.fromScale(0.92, h),
		})
		y += h
	end
	folder.PrimaryPart = board
	return folder, board, gui
end

-- A prompt on an invisible part: what you walk up to and press E on.
function MapKit.prompt(parent, name, at, action, object, distance)
	local anchor = part(parent, name, Vector3.new(1, 1, 1), CFrame.new(at), COL.White, Enum.Material.SmoothPlastic, {
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object or ""
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = distance or 10
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = anchor
	return prompt, anchor
end

-- A glowing START pad: a disc, a ring and a floating label.
function MapKit.startPad(parent, at, color, text)
	-- a white rim under a coloured disc (two parts, not a ring of 24)
	MapKit.disc(parent, "PadRing", at, 8, COL.White, 0.3, Enum.Material.Neon, { CanCollide = false, CanQuery = false, CanTouch = false })
	local pad = MapKit.disc(parent, "StartPad", at, 6.6, color or COL.Gold, 0.36, Enum.Material.Neon, { CanCollide = false, CanTouch = false })
	local anchor = part(parent, "PadLabel", Vector3.new(1, 1, 1), CFrame.new(at + Vector3.new(0, 5.5, 0)), COL.White,
		Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.LightInfluence = 0
	gui.MaxDistance = 70
	gui.Adornee = anchor
	gui.Parent = anchor
	uiText(gui, text or "\u{25B6} START", 3, COL.White)
	return pad
end

return MapKit
