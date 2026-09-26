-- Drawn icons for the buttons and windows, in place of emoji: the same
-- things (a card, a gift, a trophy, a cart, a bolt, a ball ...) made of
-- rounded shapes with fresh colours, a light top and one dark outline round
-- the whole silhouette.
--
--   local icon = Icons.new(button, "gift", { Size = UDim2.fromOffset(40, 40) })
--   Icons.set(icon, "lock")
--
-- Each icon is a list of pieces on a 100 x 100 canvas:
--   { x, y, w, h, colour, rot = degrees, r = corner (0 - 0.5), line = false }
-- Pieces are outlined together (so the outline goes round the silhouette,
-- not between pieces); `detail = true` pieces sit on top with a thin line.

local Icons = {}

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local INK = rgb(12, 18, 48)
local WHITE = rgb(255, 255, 255)

local K = {
	gold = rgb(255, 206, 40), goldDark = rgb(236, 150, 20), orange = rgb(255, 140, 40),
	red = rgb(255, 64, 90), green = rgb(70, 225, 110), lime = rgb(170, 245, 90),
	blue = rgb(50, 160, 255), navy = rgb(40, 80, 190), cyan = rgb(60, 225, 255),
	purple = rgb(175, 95, 255), pink = rgb(255, 105, 190), cream = rgb(255, 240, 205),
	tan = rgb(235, 180, 110), grey = rgb(175, 185, 205), dark = rgb(45, 50, 78),
	white = WHITE,
}

local function D(t) t.detail = true return t end

local ICONS = {
	card = {
		{ 50, 52, 64, 82, K.gold, rot = -8, r = 0.16 },
		D({ 50, 44, 42, 38, K.navy, rot = -8, r = 0.2 }),
		D({ 49, 38, 15, 15, K.white, r = 0.5, line = false }),
		D({ 50, 55, 28, 12, K.white, rot = -8, r = 0.5, line = false }),
		D({ 50, 76, 36, 7, K.goldDark, rot = -8, r = 0.5, line = false }),
	},
	gift = {
		{ 50, 64, 66, 48, K.green, r = 0.12 },
		{ 50, 38, 80, 18, K.lime, r = 0.25 },
		{ 38, 20, 24, 18, K.red, rot = 28, r = 0.5 },
		{ 62, 20, 24, 18, K.red, rot = -28, r = 0.5 },
		D({ 50, 62, 14, 52, K.red, line = false }),
		D({ 50, 25, 12, 12, K.red, r = 0.5 }),
	},
	scroll = {
		{ 50, 50, 56, 64, K.cream, r = 0.06 },
		{ 50, 19, 72, 16, K.tan, r = 0.5 },
		{ 50, 81, 72, 16, K.tan, r = 0.5 },
		D({ 50, 40, 36, 6, K.dark, r = 0.5, line = false }),
		D({ 50, 52, 36, 6, K.dark, r = 0.5, line = false }),
		D({ 45, 64, 26, 6, K.dark, r = 0.5, line = false }),
	},
	clipboard = {
		{ 50, 55, 66, 78, K.blue, r = 0.14 },
		{ 50, 16, 32, 16, K.grey, r = 0.35 },
		D({ 50, 58, 48, 58, K.white, r = 0.08 }),
		D({ 50, 44, 30, 6, K.dark, r = 0.5, line = false }),
		D({ 50, 56, 30, 6, K.dark, r = 0.5, line = false }),
		D({ 46, 68, 22, 6, K.dark, r = 0.5, line = false }),
	},
	trophy = {
		{ 25, 34, 22, 26, K.gold, r = 0.5 },
		{ 75, 34, 22, 26, K.gold, r = 0.5 },
		{ 50, 36, 54, 48, K.gold, r = 0.4 },
		{ 50, 66, 14, 18, K.goldDark },
		{ 50, 82, 48, 14, K.goldDark, r = 0.25 },
		D({ 40, 30, 9, 16, K.white, r = 0.5, line = false }),
	},
	palette = {
		{ 50, 52, 84, 72, K.cream, r = 0.5 },
		D({ 30, 42, 16, 16, K.red, r = 0.5 }),
		D({ 50, 30, 16, 16, K.blue, r = 0.5 }),
		D({ 70, 40, 16, 16, K.green, r = 0.5 }),
		D({ 72, 62, 16, 16, K.purple, r = 0.5 }),
		D({ 40, 66, 16, 16, K.tan, r = 0.5 }),
	},
	cart = {
		{ 18, 28, 26, 9, K.grey, rot = 18, r = 0.5 },
		{ 54, 48, 64, 38, K.gold, r = 0.16 },
		{ 36, 82, 17, 17, K.dark, r = 0.5 },
		{ 70, 82, 17, 17, K.dark, r = 0.5 },
		D({ 54, 48, 46, 6, K.goldDark, r = 0.5, line = false }),
	},
	bolt = {
		{ 47, 27, 20, 52, K.gold, rot = 22, r = 0.14 },
		{ 51, 50, 38, 14, K.gold, r = 0.14 },
		{ 55, 73, 20, 52, K.gold, rot = 22, r = 0.14 },
		D({ 51, 17, 6, 20, K.white, rot = 22, r = 0.5, line = false }),
	},
	ball = {
		{ 50, 50, 80, 80, K.white, r = 0.5 },
		D({ 50, 50, 24, 24, K.dark, rot = 45, r = 0.3, line = false }),
		D({ 50, 21, 16, 10, K.dark, r = 0.5, line = false }),
		D({ 24, 42, 10, 16, K.dark, r = 0.5, line = false }),
		D({ 76, 42, 10, 16, K.dark, r = 0.5, line = false }),
		D({ 34, 74, 14, 12, K.dark, r = 0.5, line = false }),
		D({ 66, 74, 14, 12, K.dark, r = 0.5, line = false }),
	},
	target = {
		{ 50, 50, 84, 84, K.red, r = 0.5 },
		D({ 50, 50, 60, 60, K.white, r = 0.5, line = false }),
		D({ 50, 50, 38, 38, K.red, r = 0.5, line = false }),
		D({ 50, 50, 16, 16, K.white, r = 0.5, line = false }),
	},
	swirl = {
		{ 50, 50, 82, 82, K.purple, r = 0.5 },
		D({ 56, 46, 54, 54, K.white, r = 0.5, line = false }),
		D({ 60, 42, 30, 30, K.purple, r = 0.5, line = false }),
		D({ 63, 40, 10, 10, K.white, r = 0.5, line = false }),
	},
	shield = {
		{ 50, 38, 66, 52, K.blue, r = 0.16 },
		{ 50, 58, 48, 48, K.blue, rot = 45, r = 0.16 },
		D({ 50, 52, 14, 56, K.white, r = 0.3, line = false }),
	},
	dumbbell = {
		{ 50, 50, 72, 11, K.grey, r = 0.5 },
		{ 20, 50, 15, 48, K.orange, r = 0.3 },
		{ 33, 50, 11, 34, K.orange, r = 0.3 },
		{ 80, 50, 15, 48, K.orange, r = 0.3 },
		{ 67, 50, 11, 34, K.orange, r = 0.3 },
	},
	star = {
		{ 50, 50, 60, 60, K.gold, r = 0.18 },
		{ 50, 50, 60, 60, K.gold, rot = 45, r = 0.18 },
		D({ 50, 50, 26, 26, K.white, r = 0.5, line = false }),
	},
	crown = {
		{ 22, 42, 20, 20, K.gold, rot = 45, r = 0.15 },
		{ 50, 32, 22, 22, K.gold, rot = 45, r = 0.15 },
		{ 78, 42, 20, 20, K.gold, rot = 45, r = 0.15 },
		{ 50, 66, 72, 30, K.gold, r = 0.15 },
		D({ 50, 66, 14, 14, K.red, r = 0.5 }),
		D({ 28, 66, 9, 9, K.cyan, r = 0.5 }),
		D({ 72, 66, 9, 9, K.cyan, r = 0.5 }),
	},
	robot = {
		{ 50, 20, 7, 18, K.grey },
		{ 50, 11, 13, 13, K.red, r = 0.5 },
		{ 50, 56, 72, 58, K.cyan, r = 0.24 },
		D({ 36, 52, 15, 15, K.dark, r = 0.5, line = false }),
		D({ 64, 52, 15, 15, K.dark, r = 0.5, line = false }),
		D({ 50, 70, 28, 6, K.dark, r = 0.5, line = false }),
	},
	stopwatch = {
		{ 50, 13, 18, 12, K.grey, r = 0.2 },
		{ 50, 56, 78, 78, K.cyan, r = 0.5 },
		D({ 50, 56, 56, 56, K.white, r = 0.5 }),
		D({ 50, 46, 6, 24, K.dark, r = 0.5, line = false }),
		D({ 58, 56, 20, 6, K.dark, r = 0.5, line = false }),
	},
	lock = {
		{ 50, 32, 44, 44, K.grey, r = 0.5 },
		{ 50, 64, 66, 48, K.gold, r = 0.16 },
		D({ 50, 34, 20, 22, K.dark, r = 0.5, line = false }),
		D({ 50, 60, 12, 12, K.dark, r = 0.5, line = false }),
		D({ 50, 70, 6, 14, K.dark, line = false }),
	},
	check = {
		{ 34, 60, 16, 40, K.green, rot = -45, r = 0.5 },
		{ 60, 48, 16, 66, K.green, rot = 38, r = 0.5 },
	},
	boot = {
		{ 40, 42, 34, 46, K.green, r = 0.2 },
		{ 54, 66, 70, 26, K.green, r = 0.3 },
		{ 54, 82, 74, 10, K.white, r = 0.4 },
		D({ 40, 40, 24, 6, K.white, r = 0.5, line = false }),
		D({ 40, 52, 24, 6, K.white, r = 0.5, line = false }),
	},
	cross = {
		{ 50, 50, 20, 80, K.red, rot = 45, r = 0.5 },
		{ 50, 50, 20, 80, K.red, rot = -45, r = 0.5 },
	},
	plus = {
		{ 50, 50, 22, 76, K.white, r = 0.4 },
		{ 50, 50, 76, 22, K.white, r = 0.4 },
	},
	coin = {
		{ 50, 50, 80, 80, K.gold, r = 0.3 },
		D({ 50, 50, 50, 50, K.goldDark, r = 0.25 }),
		D({ 50, 50, 14, 14, K.gold, r = 0.1, line = false }),
	},
	diamond = {
		{ 50, 52, 60, 60, K.cyan, rot = 45, r = 0.12 },
		D({ 42, 42, 12, 26, K.white, rot = 45, r = 0.5, line = false }),
	},
	refresh = {
		{ 50, 50, 80, 80, K.red, r = 0.5 },
		D({ 50, 50, 46, 46, K.white, r = 0.5 }),
		D({ 72, 30, 20, 20, K.white, rot = 45, r = 0.1, line = false }),
	},
	fire = {
		{ 50, 62, 60, 60, K.orange, r = 0.5 },
		{ 50, 40, 38, 38, K.orange, rot = 45, r = 0.4 },
		D({ 50, 66, 30, 30, K.gold, r = 0.5, line = false }),
	},
}

-- which icon each stat uses
Icons.Stat = { PAC = "bolt", SHO = "ball", PAS = "target", DRI = "swirl", DEF = "shield", PHY = "dumbbell" }

local function piece(holder, spec, z, withLine)
	local f = Instance.new("Frame")
	f.Name = "Piece"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(spec[1] / 100, spec[2] / 100)
	f.Size = UDim2.fromScale(spec[3] / 100, spec[4] / 100)
	f.Rotation = spec.rot or 0
	f.BorderSizePixel = 0
	f.BackgroundColor3 = WHITE
	f.ZIndex = z
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(spec.r or 0.08, 0)
	corner.Parent = f
	-- fresh colour: lighter on top
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(spec[5]:Lerp(WHITE, 0.4), spec[5])
	g.Rotation = 90 - (spec.rot or 0)
	g.Parent = f
	if withLine then
		local s = Instance.new("UIStroke")
		s.Name = "Outline"
		s.Color = INK
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s:SetAttribute("Weight", withLine)
		s.Parent = f
	end
	f.Parent = holder
	return f
end

local function outlineWidth(holder, weight)
	return math.max(1, holder.AbsoluteSize.X * 0.055 * weight)
end

--------------------------------------------------------------------------------
-- The "Simulator Icon Pack" (DevJoob, Toolbox): when its images are known,
-- every icon is that picture instead of the drawn one. They come from
--   1. Icons.Images below (ids baked into the game), or
--   2. the pack itself, if it is in the place (insert it from the Toolbox
--      into ReplicatedStorage): its Decals are matched by name.
--------------------------------------------------------------------------------

-- icon -> image id (fill in from the list the game prints in Output)
Icons.Images = {}

-- The icon sheet (assets/Icons_Sheet.png in the repo: 21 icons, 7 x 3, 96
-- px each). Upload it once (Studio > Asset Manager > Import), right-click it
-- > Copy Asset ID, and paste the id in Image. Until then the drawn icons
-- are used.
Icons.Sprite = {
	Image = "rbxassetid://97433681572325",
	Cell = 96,
	Columns = 7,
	Order = { "check", "cross", "coin", "minus", "plus", "undo", "redo",
		"diamond", "gem", "gear", "paw", "refresh", "basket", "swap",
		"gift", "code", "hand", "cursor", "clover", "wheel", "cash" },
	-- the game's icon -> the picture on the sheet
	Use = {
		check = "check", cross = "cross", coin = "coin", plus = "plus", refresh = "refresh",
		cart = "basket", clipboard = "swap", gift = "gift", palette = "wheel", crown = "gem",
		robot = "hand", diamond = "diamond", trophy = "diamond",
	},
}

-- The sheet cell for an icon: its offset on the sheet, or nil.
function Icons.SpriteCell(name)
	local sprite = Icons.Sprite
	-- the server may have found the image behind a Decal id (Main)
	local id = game:GetService("ReplicatedStorage"):GetAttribute("IconSheet") or tostring(sprite.Image or "")
	if id == "" or id == "0" then return nil end
	local pick = sprite.Use[name]
	if not pick then return nil end
	for i, cellName in ipairs(sprite.Order) do
		if cellName == pick then
			local col, row = (i - 1) % sprite.Columns, (i - 1) // sprite.Columns
			if id:match("^%d+$") then id = "rbxassetid://" .. id end
			return id, Vector2.new(col * sprite.Cell, row * sprite.Cell), Vector2.new(sprite.Cell, sprite.Cell)
		end
	end
	return nil
end

-- words to look for in the pack's image names, best first
local KEYWORDS = {
	card = { "card", "id", "profile", "player" }, gift = { "gift", "present" }, scroll = { "scroll", "quest", "paper", "map" },
	clipboard = { "clipboard", "list", "note", "book" }, trophy = { "trophy", "cup" }, palette = { "palette", "paint", "brush", "color" },
	cart = { "cart", "shop", "store" }, bolt = { "lightning", "bolt", "energy", "speed" }, ball = { "ball", "soccer", "football" },
	target = { "target", "bullseye", "aim" }, swirl = { "swirl", "spiral", "portal", "vortex" }, shield = { "shield", "defen" },
	dumbbell = { "dumbbell", "weight", "muscle", "strength", "gym" }, star = { "star" }, crown = { "crown", "vip", "king" },
	robot = { "robot", "auto", "bot" }, stopwatch = { "stopwatch", "timer", "clock", "time", "hourglass" }, lock = { "lock" },
	check = { "check", "tick", "yes" }, fire = { "fire", "flame" },
}

local pack = nil -- name (lower case) -> image id, from the pack in the place
local function packImages()
	if pack then return pack end
	pack = {}
	local root = game:GetService("ReplicatedStorage"):FindFirstChild("Simulator Icon Pack", true)
		or workspace:FindFirstChild("Simulator Icon Pack", true)
	if not root then return pack end
	for _, d in ipairs(root:GetDescendants()) do
		local image = (d:IsA("Decal") and d.Texture) or ((d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image) or nil
		if image and image ~= "" then
			local key = d.Name:lower()
			if key == "decal" or key == "imagelabel" or key == "texture" then key = d.Parent and d.Parent.Name:lower() or key end
			if not pack[key] then pack[key] = image end
		end
	end
	return pack
end

-- The pack's picture for an icon, or nil (then the drawn icon is used).
function Icons.Image(name)
	if Icons.Images[name] then return Icons.Images[name] end
	local images = packImages()
	for _, word in ipairs(KEYWORDS[name] or { name }) do
		if images[word] then return images[word] end
	end
	for _, word in ipairs(KEYWORDS[name] or { name }) do
		for key, image in pairs(images) do
			if key:find(word, 1, true) then return image end
		end
	end
	return nil
end

-- Prints every image in the pack (name = id) so they can be baked into
-- Icons.Images, and which icons it has a picture for.
function Icons.Report()
	local images = packImages()
	local keys = {}
	for key in pairs(images) do table.insert(keys, key) end
	if #keys == 0 then return end
	table.sort(keys)
	local lines = { "[Football] Simulator Icon Pack found (" .. #keys .. " images). Send this list to Claude:" }
	for _, key in ipairs(keys) do table.insert(lines, ("  [%q] = %q,"):format(key, images[key])) end
	local found = {}
	for name in pairs(KEYWORDS) do
		table.insert(found, name .. "=" .. (Icons.Image(name) and "yes" or "NO"))
	end
	table.sort(found)
	table.insert(lines, "  icons: " .. table.concat(found, " "))
	print(table.concat(lines, "\n"))
end

local function draw(holder, name)
	holder:ClearAllChildren()
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = holder
	holder:SetAttribute("Icon", name)
	local sheet, offset, size = Icons.SpriteCell(name)
	if sheet then
		local l = Instance.new("ImageLabel")
		l.Name = "Picture"
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.ScaleType = Enum.ScaleType.Fit
		l.Image = sheet
		l.ImageRectOffset = offset
		l.ImageRectSize = size
		l.ZIndex = holder.ZIndex + 1
		l.Parent = holder
		return function() end
	end
	local image = Icons.Image(name)
	if image then
		local l = Instance.new("ImageLabel")
		l.Name = "Picture"
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.ScaleType = Enum.ScaleType.Fit
		l.Image = image
		l.ZIndex = holder.ZIndex + 1
		l.Parent = holder
		return function() end
	end
	local spec = ICONS[name] or ICONS.star
	local z = holder.ZIndex
	-- 1. the outline round the whole silhouette, 2. the fills over it
	for _, p in ipairs(spec) do
		if not p.detail then piece(holder, p, z + 1, 1) end
	end
	for _, p in ipairs(spec) do
		if not p.detail then piece(holder, p, z + 2, nil) end
	end
	-- 3. the details on top, with a thinner line
	for _, p in ipairs(spec) do
		if p.detail then piece(holder, p, z + 3, p.line ~= false and 0.55 or nil) end
	end
	holder:SetAttribute("Icon", name)
	local function resize()
		for _, s in ipairs(holder:GetDescendants()) do
			if s:IsA("UIStroke") and s.Name == "Outline" then
				s.Thickness = outlineWidth(holder, s:GetAttribute("Weight") or 1)
			end
		end
	end
	resize()
	return resize
end

function Icons.new(parent, name, props)
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(40, 40)
	for k, v in pairs(props or {}) do holder[k] = v end
	holder.Parent = parent
	local resize = draw(holder, name)
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() resize() end)
	return holder
end

function Icons.set(holder, name)
	if holder:GetAttribute("Icon") == name then return end
	draw(holder, name)
end

Icons.Names = ICONS

-- the emoji the game used before -> the drawn icon
local FROM_EMOJI = {
	["\u{1F0CF}"] = "card", ["\u{1F381}"] = "gift", ["\u{1F4DC}"] = "scroll", ["\u{1F4CB}"] = "clipboard",
	["\u{1F3C6}"] = "trophy", ["\u{1F3A8}"] = "palette", ["\u{1F6D2}"] = "cart", ["\u{26A1}"] = "bolt",
	["\u{26BD}"] = "ball", ["\u{1F3AF}"] = "target", ["\u{1F300}"] = "swirl", ["\u{1F6E1}"] = "shield",
	["\u{1F4AA}"] = "dumbbell", ["\u{2B50}"] = "star", ["\u{1F451}"] = "crown", ["\u{1F916}"] = "robot",
	["\u{23F1}"] = "stopwatch", ["\u{1F512}"] = "lock", ["\u{2705}"] = "check", ["\u{1F525}"] = "fire", ["\u{1F504}"] = "refresh", ["\u{1F45F}"] = "boot",
}
function Icons.FromEmoji(emoji)
	return FROM_EMOJI[emoji] or "star"
end

return Icons
