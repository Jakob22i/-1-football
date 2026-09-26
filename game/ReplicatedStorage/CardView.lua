-- The player card: our own design, drawn in UI frames so it scales to any
-- size. Used for the small card in the corner, the big card in the upgrade
-- moment, the "My Card" window and (compact) the cards over players' heads.
--
--   local card = CardView.new(parent, { Size = UDim2.fromOffset(150, 210) })
--   card:Set({ OVR = 67, Position = "ST", Name = "JAKOB", Stats = {...}, Season = 1 })
--   card:Animate(t)   -- every frame, for the shine, shimmer, sparks and lightning
--
-- Layout (fractions of the card): a tier tab on the top edge, the OVR and
-- position in the top left, the avatar window, a name ribbon, then the six
-- stats in two columns. Corners are round, the body has diagonal stripes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))
local FKit = require(ReplicatedStorage:WaitForChild("FKit"))

local new = FKit.new
local C = FKit.Color

local CardView = {}
CardView.__index = CardView

CardView.Ratio = 300 / 420 -- width / height

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

-- Every tier's colours: the body (top to bottom), the border, the ribbon
-- under the name, the glow round the card and the accent for details.
CardView.Styles = {
	Bronze = {
		Body = { rgb(240, 180, 120), rgb(196, 120, 60), rgb(128, 68, 30) },
		Border = { rgb(92, 48, 18) }, Ribbon = rgb(110, 56, 20), Accent = rgb(255, 214, 170),
		Stripe = 0.86,
	},
	Silver = {
		Body = { rgb(250, 252, 255), rgb(200, 208, 222), rgb(132, 142, 162) },
		Border = { rgb(70, 80, 100) }, Ribbon = rgb(92, 102, 124), Accent = rgb(255, 255, 255),
		Stripe = 0.8, Shine = true,
	},
	Gold = {
		Body = { rgb(255, 246, 170), rgb(255, 206, 60), rgb(206, 132, 8) },
		Border = { rgb(120, 66, 0) }, Ribbon = rgb(160, 92, 0), Accent = rgb(255, 250, 200),
		Stripe = 0.78, Shine = true, Shimmer = true,
	},
	Special = {
		Body = { rgb(48, 48, 84), rgb(20, 20, 44), rgb(6, 6, 18) },
		Border = { rgb(0, 255, 220), rgb(255, 0, 200) }, Ribbon = rgb(30, 30, 64), Accent = rgb(0, 255, 220),
		Stripe = 0.9, Neon = true, Glow = rgb(0, 255, 220),
	},
	Elite = {
		Body = { rgb(255, 255, 245), rgb(255, 228, 150), rgb(255, 160, 50) },
		Border = { rgb(255, 255, 255), rgb(255, 210, 90) }, Ribbon = rgb(210, 110, 10), Accent = rgb(255, 255, 255),
		Stripe = 0.75, Shine = true, Glow = rgb(255, 230, 140), Sparks = true,
	},
	WorldClass = {
		Body = { rgb(150, 70, 255), rgb(50, 170, 255), rgb(255, 60, 200) },
		Border = { rgb(255, 255, 255), rgb(170, 230, 255) }, Ribbon = rgb(60, 20, 140), Accent = rgb(200, 250, 255),
		Stripe = 0.82, Shine = true, Glow = rgb(140, 120, 255), Rainbow = true, Lightning = true,
	},
	Legend = {
		Body = { rgb(40, 34, 20), rgb(20, 16, 6), rgb(0, 0, 0) },
		Border = { rgb(255, 60, 120), rgb(255, 220, 40), rgb(60, 255, 140), rgb(40, 160, 255), rgb(200, 80, 255) },
		Ribbon = rgb(150, 100, 0), Accent = rgb(255, 220, 60),
		Stripe = 0.88, Shine = true, Glow = rgb(255, 210, 60), Sparks = true, Lightning = true, NeonRainbow = true,
	},
}

local function frame(parent, props)
	local f = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Parent = parent })
	for k, v in pairs(props or {}) do f[k] = v end
	return f
end

-- Scaled text: TextScaled inside its box, with an outline that scales too.
local function label(card, parent, text, props, strokeRatio)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = FKit.Font,
		Text = text,
		TextScaled = true,
		TextColor3 = C.White,
		Parent = parent,
	})
	for k, v in pairs(props or {}) do l[k] = v end
	local s = new("UIStroke", { Name = "TextStroke", Color = C.Ink, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	table.insert(card.Strokes, { s, strokeRatio or 0.012 })
	return l
end

function CardView.new(parent, opts)
	opts = opts or {}
	local self = setmetatable({ Strokes = {}, Compact = opts.Compact == true, Data = {} }, CardView)

	local root = frame(parent, {
		Name = opts.Name or "Card",
		Size = opts.Size or UDim2.fromOffset(150, 210),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.new(),
		ZIndex = opts.ZIndex or 1,
	})
	new("UIAspectRatioConstraint", { AspectRatio = CardView.Ratio, Parent = root })
	self.Frame = root
	local z = root.ZIndex

	-- glow behind the card (the top tiers)
	self.Glow = frame(root, {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.14, 1.1),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.55,
		Visible = false,
		ZIndex = z,
	})
	FKit.corner(self.Glow, UDim.new(0.12, 0))
	FKit.gradient(self.Glow, C.White, 90, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.3),
	}))

	local body = frame(root, {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		ZIndex = z,
	})
	FKit.corner(body, UDim.new(0.09, 0))
	self.Body = body
	self.BodyGradient = FKit.gradient(body, { C.White, C.Grey }, 60)
	self.Border = new("UIStroke", { Name = "Border", ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = C.White, Parent = body })
	self.BorderGradient = FKit.gradient(self.Border, { C.White, C.White }, 45)
	table.insert(self.Strokes, { self.Border, 0.03 })

	-- diagonal stripes
	self.StripeFrames = {}
	for i = 1, 3 do
		local s = frame(body, {
			Name = "Stripe",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.15 + i * 0.28, 0.5),
			Size = UDim2.fromScale(0.08 + i * 0.03, 1.8),
			Rotation = 28,
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0.85,
			ZIndex = z,
		})
		table.insert(self.StripeFrames, s)
	end

	-- a shine that sweeps across (Silver and up)
	self.Shine = frame(body, {
		Name = "Shine",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.4, 0.5),
		Size = UDim2.fromScale(0.16, 2),
		Rotation = 24,
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.5,
		Visible = false,
		ZIndex = z + 4,
	})
	FKit.gradient(self.Shine, C.White, 0, NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1),
	}))

	-- the avatar window
	local window = frame(root, {
		Name = "Window",
		Position = UDim2.fromScale(self.Compact and 0.1 or 0.3, self.Compact and 0.3 or 0.08),
		Size = UDim2.fromScale(self.Compact and 0.8 or 0.62, self.Compact and 0.4 or 0.5),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0,
		ZIndex = z + 1,
	})
	FKit.corner(window, UDim.new(0.14, 0))
	self.WindowGradient = FKit.gradient(window, { rgb(40, 80, 160), rgb(10, 20, 60) }, 90)
	local windowStroke = new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = C.Ink, Transparency = 0.3, Parent = window })
	table.insert(self.Strokes, { windowStroke, 0.012 })
	self.Window = window
	-- a soft spotlight in the window
	local spot = frame(window, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromScale(0.9, 0.9),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.82,
		ZIndex = z + 1,
	})
	FKit.corner(spot, UDim.new(0.5, 0))
	if opts.Viewport then
		local vp = new("ViewportFrame", {
			Name = "Avatar",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Ambient = rgb(200, 205, 220),
			LightColor = rgb(255, 250, 240),
			LightDirection = Vector3.new(-0.4, -0.6, -1),
			ZIndex = z + 2,
			Parent = window,
		})
		local cam = new("Camera", { FieldOfView = 26, Parent = vp })
		vp.CurrentCamera = cam
		self.Viewport, self.Camera = vp, cam
	end
	-- the player's own avatar, head and shoulders (ShowPlayer)
	self.Photo = new("ImageLabel", {
		Name = "Photo",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Crop,
		Image = "",
		Visible = false,
		ZIndex = z + 2,
		Parent = window,
	})
	-- a simple silhouette until the avatar is there
	self.Silhouette = frame(window, { Name = "Silhouette", Size = UDim2.fromScale(1, 1), ZIndex = z + 2, Visible = not opts.Viewport })
	local head = frame(self.Silhouette, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.16), Size = UDim2.fromScale(0.3, 0.36),
		BackgroundColor3 = C.White, BackgroundTransparency = 0.35, ZIndex = z + 2,
	})
	FKit.corner(head, UDim.new(0.5, 0))
	local shoulders = frame(self.Silhouette, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(0.7, 0.6),
		BackgroundColor3 = C.White, BackgroundTransparency = 0.35, ZIndex = z + 2,
	})
	FKit.corner(shoulders, UDim.new(0.35, 0))

	-- OVR and position (top left)
	self.OVR = label(self, root, "60", {
		Name = "OVR",
		Position = UDim2.fromScale(0.05, self.Compact and 0.04 or 0.07),
		Size = UDim2.fromScale(self.Compact and 0.9 or 0.3, self.Compact and 0.26 or 0.17),
		TextXAlignment = self.Compact and Enum.TextXAlignment.Center or Enum.TextXAlignment.Center,
		ZIndex = z + 5,
	}, 0.018)
	self.Position = label(self, root, "ST", {
		Name = "Pos",
		Position = UDim2.fromScale(self.Compact and 0.05 or 0.05, self.Compact and 0.7 or 0.24),
		Size = UDim2.fromScale(self.Compact and 0.9 or 0.3, self.Compact and 0.13 or 0.08),
		ZIndex = z + 5,
	})

	-- tier tab on the top edge
	local tab = frame(root, {
		Name = "Tab",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(self.Compact and 0.7 or 0.44, self.Compact and 0.1 or 0.065),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0,
		ZIndex = z + 6,
	})
	FKit.corner(tab, UDim.new(0.5, 0))
	self.TabGradient = FKit.gradient(tab, { C.White, C.Grey }, 90)
	local tabStroke = new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = C.Ink, Parent = tab })
	table.insert(self.Strokes, { tabStroke, 0.012 })
	self.TabLabel = label(self, tab, "BRONZE", { Size = UDim2.fromScale(1, 0.84), Position = UDim2.fromScale(0, 0.08), ZIndex = z + 7 }, 0.008)
	self.Tab = tab

	-- season badge (top right)
	local badge = frame(root, {
		Name = "Season",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(self.Compact and 0.86 or 0.87, self.Compact and 0.1 or 0.1),
		Size = UDim2.fromScale(self.Compact and 0.3 or 0.16, self.Compact and 0.21 or 0.114),
		BackgroundColor3 = C.White,
		Rotation = 45,
		Visible = false,
		ZIndex = z + 6,
	})
	FKit.corner(badge, UDim.new(0.2, 0))
	self.SeasonGradient = FKit.gradient(badge, { C.White, C.Grey }, 90)
	local badgeStroke = new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = C.Ink, Parent = badge })
	table.insert(self.Strokes, { badgeStroke, 0.01 })
	self.SeasonLabel = label(self, badge, "S1", { Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.05, 0.05), Rotation = -45, ZIndex = z + 7 }, 0.008)
	self.Badge = badge

	-- name ribbon
	local ribbon = frame(root, {
		Name = "Ribbon",
		Position = UDim2.fromScale(0, self.Compact and 0.84 or 0.6),
		Size = UDim2.fromScale(1, self.Compact and 0.16 or 0.09),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0,
		ZIndex = z + 3,
	})
	if self.Compact then FKit.corner(ribbon, UDim.new(0.3, 0)) end
	self.Ribbon = ribbon
	self.Name = label(self, ribbon, "PLAYER", { Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), ZIndex = z + 4 }, 0.009)

	-- the six stats
	self.StatLabels = {}
	if not self.Compact then
		for i, stat in ipairs(Config.StatOrder) do
			local col = (i - 1) // 3
			local row = (i - 1) % 3
			local cell = frame(root, {
				Name = stat,
				Position = UDim2.fromScale(0.08 + col * 0.46, 0.715 + row * 0.085),
				Size = UDim2.fromScale(0.4, 0.078),
				ZIndex = z + 4,
			})
			local value = label(self, cell, "60", {
				Name = "Value",
				Size = UDim2.fromScale(0.42, 1),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = z + 5,
			}, 0.01)
			local name = label(self, cell, stat, {
				Name = "Stat",
				Position = UDim2.fromScale(0.48, 0.1),
				Size = UDim2.fromScale(0.52, 0.8),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = C.White,
				ZIndex = z + 5,
			}, 0.008)
			self.StatLabels[stat] = { Cell = cell, Value = value, Name = name }
		end
		-- a thin line between the two columns
		self.Divider = frame(root, {
			Position = UDim2.fromScale(0.497, 0.72),
			Size = UDim2.fromScale(0.006, 0.24),
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0.5,
			ZIndex = z + 4,
		})
	end

	-- sparks (Elite and Legend) and lightning (World Class and Legend)
	self.FX = frame(root, { Name = "FX", Size = UDim2.fromScale(1, 1), ZIndex = z + 8 })
	self.Sparks = {}
	for i = 1, 10 do
		local s = frame(self.FX, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(0.025, 0.018),
			BackgroundColor3 = C.White,
			Visible = false,
			ZIndex = z + 8,
		})
		FKit.corner(s, UDim.new(0.5, 0))
		table.insert(self.Sparks, { Frame = s, Seed = i * 1.618 })
	end
	self.Bolts = {}
	for i = 1, 2 do
		local bolt = frame(self.FX, { Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = z + 8 })
		local x, y = (i == 1) and 0.04 or 0.9, (i == 1) and 0.35 or 0.2
		for k = 1, 4 do
			local seg = frame(bolt, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(x + ((k % 2 == 0) and 0.03 or -0.02), y + k * 0.05),
				Size = UDim2.fromScale(0.012, 0.065),
				Rotation = (k % 2 == 0) and -30 or 30,
				BackgroundColor3 = rgb(230, 250, 255),
				ZIndex = z + 8,
			})
			FKit.corner(seg, UDim.new(0.5, 0))
		end
		table.insert(self.Bolts, bolt)
	end

	-- keep outlines in step with the card's size
	local function sizeStrokes()
		local w = root.AbsoluteSize.X
		if w <= 0 then return end
		for _, entry in ipairs(self.Strokes) do
			entry[1].Thickness = math.max(1, w * entry[2])
		end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeStrokes)
	self.SizeStrokes = sizeStrokes
	task.defer(sizeStrokes)

	self:Set({})
	return self
end

-- data: OVR, Position, Name, Stats, Season, Tier (optional), Border, Background
function CardView:Set(data)
	for k, v in pairs(data) do self.Data[k] = v end
	local d = self.Data
	local ovr = d.OVR or Config.StartLevel
	local tier = d.Tier or Config.TierFor(ovr)
	local style = CardView.Styles[tier] or CardView.Styles.Bronze
	self.Tier = tier
	self.Style = style

	self.BodyGradient.Color = FKit.sequence(style.Body)
	local borderColors = style.Border
	local cosmetic = d.Border and Config.Cosmetics[d.Border]
	if cosmetic and cosmetic.Colors then borderColors = cosmetic.Colors end
	self.BorderGradient.Color = FKit.sequence(#borderColors == 1 and { borderColors[1], borderColors[1] } or borderColors)
	self.Border.Color = C.White
	local seasonColor = Config.SeasonColor(d.Season or 0)
	self.Ribbon.BackgroundColor3 = style.Ribbon
	self.TabGradient.Color = FKit.sequence({ style.Body[1], style.Body[2] })
	self.TabLabel.Text = Config.Tiers[tier].Label
	for _, s in ipairs(self.StripeFrames) do s.BackgroundTransparency = style.Stripe end

	local background = d.Background and Config.Cosmetics[d.Background]
	local bg = background and background.Colors or { rgb(40, 80, 160), rgb(10, 20, 60) }
	self.WindowGradient.Color = FKit.sequence(bg)

	self.OVR.Text = tostring(ovr)
	self.Position.Text = d.Position or "ST"
	self.Name.Text = string.upper(d.Name or "PLAYER")
	if tier == "Legend" then
		self.OVR.TextColor3 = rgb(255, 220, 60)
	else
		self.OVR.TextColor3 = C.White
	end

	self.Badge.Visible = (d.Season or 0) > 0
	if (d.Season or 0) > 0 then
		self.SeasonLabel.Text = "S" .. d.Season
		self.SeasonGradient.Color = FKit.sequence({ seasonColor:Lerp(C.White, 0.4), seasonColor })
	end

	for stat, cell in pairs(self.StatLabels) do
		cell.Value.Text = tostring(d.Stats and d.Stats[stat] or Config.StartLevel)
		cell.Name.TextColor3 = style.Accent
	end

	self.Glow.Visible = style.Glow ~= nil
	if style.Glow then self.Glow.BackgroundColor3 = style.Glow end
	self.Shine.Visible = style.Shine == true
	for _, spark in ipairs(self.Sparks) do spark.Frame.Visible = style.Sparks == true end
	for _, bolt in ipairs(self.Bolts) do bolt.Visible = false end
end

-- Moving details, called every frame with the time in seconds.
function CardView:Animate(t)
	local style = self.Style
	if not style then return end
	if style.Shine then
		local cycle = (t % 3.4) / 1.2
		self.Shine.Position = UDim2.fromScale(-0.4 + math.min(cycle, 1) * 1.8, 0.5)
	end
	if style.Shimmer then
		self.BodyGradient.Offset = Vector2.new(0, math.sin(t * 1.6) * 0.12)
	end
	if style.Neon or style.NeonRainbow then
		self.BorderGradient.Rotation = (t * 120) % 360
	end
	if style.Rainbow then
		self.BodyGradient.Rotation = 60 + math.sin(t * 0.8) * 50
		self.BodyGradient.Offset = Vector2.new(math.sin(t * 0.7) * 0.25, 0)
	end
	if style.Glow then
		self.Glow.BackgroundTransparency = 0.55 + math.sin(t * 3) * 0.15
	end
	if style.Sparks then
		for _, spark in ipairs(self.Sparks) do
			local k = (t * 0.35 + spark.Seed) % 1
			spark.Frame.Position = UDim2.fromScale(0.08 + ((spark.Seed * 7.3) % 1) * 0.84, 1 - k * 1.05)
			spark.Frame.BackgroundTransparency = 0.1 + k * 0.85
		end
	end
	if style.Lightning then
		local flash = (t % 2.3) < 0.12 or ((t + 1.1) % 2.9) < 0.1
		for i, bolt in ipairs(self.Bolts) do
			bolt.Visible = flash and ((math.floor(t / 2.3) + i) % 2 == 0 or style.NeonRainbow)
		end
	end
end

-- Puts the player's own Roblox avatar on the card (head and shoulders, like
-- a real player card). Works on every card, the ones over players' heads
-- too. A test player in Studio has no avatar picture (UserId 0 or below),
-- so those cards fall back to ShowCharacter.
function CardView:ShowPlayer(userId)
	if not (userId and userId > 0) then return false end
	self.Photo.Image = ("rbxthumb://type=AvatarBust&id=%d&w=420&h=420"):format(userId)
	self.Photo.Visible = true
	self.Silhouette.Visible = false
	if self.Viewport then self.Viewport.Visible = false end
	return true
end

-- Puts a copy of a character in the card's avatar window, head and
-- shoulders.
function CardView:ShowCharacter(character)
	if not (self.Viewport and character) then return end
	self.Viewport:ClearAllChildren()
	local cam = new("Camera", { FieldOfView = 26, Parent = self.Viewport })
	self.Viewport.CurrentCamera = cam
	self.Camera = cam
	local archivable = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function() return character:Clone() end)
	character.Archivable = archivable
	if not ok or not copy then return end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local root = copy:FindFirstChild("HumanoidRootPart") or copy.PrimaryPart
	local head = copy:FindFirstChild("Head")
	if not (root and head) then
		copy:Destroy()
		return
	end
	copy:PivotTo(CFrame.new(0, 0, 0))
	copy.Parent = self.Viewport
	self.Viewport.Visible = true
	self.Photo.Visible = false
	local focus = head.Position + Vector3.new(0, -0.9, 0)
	cam.CFrame = CFrame.lookAt(focus + Vector3.new(-1.2, 0.6, -7.4), focus)
	self.Silhouette.Visible = false
end

return CardView
