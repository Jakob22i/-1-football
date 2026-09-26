-- The menus: big buttons on the left (My Card, Daily, Quests, Positions,
-- Season, Style, Shop) with badges, one window at a time in the middle of
-- the screen, and chips at the top left for the 2x XP boost, the training
-- streak and your XP multiplier.
--
-- Everything the windows show comes from the player's attributes (the
-- server sets them); every button asks the server through ctx.Request.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))
local FKit = require(ReplicatedStorage:WaitForChild("FKit"))
local Icons = require(ReplicatedStorage:WaitForChild("Icons"))
local CardView = require(ReplicatedStorage:WaitForChild("CardView"))
local CardUI = require(script.Parent:WaitForChild("CardUI"))

local MenusUI = {}

local new = FKit.new
local C = FKit.Color
local P = FKit.Palette
local player = Players.LocalPlayer

local ctx
local gui          -- the menus' own ScreenGui (over the HUD, under the upgrade moment)
local dim, holder, panel, titleLabel, titleIcon, page
local current      -- the open window
local refresher    -- updates the open window
local buttons = {} -- name -> { Button, Badge, BadgeLabel }
local WINDOWS = {}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function attr(name, default)
	local value = player:GetAttribute(name)
	if value == nil then return default end
	return value
end

local function decode(name)
	local value = {}
	pcall(function() value = HttpService:JSONDecode(player:GetAttribute(name) or "{}") end)
	return value
end

local function tween(obj, time, goal)
	local t = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- Smaller on phones (see FKit.autoScale).
function MenusUI.Fit(obj, w, h)
	return FKit.autoScale(obj, w, h)
end

-- Asks the server; says what happened.
local function ask(action, ...)
	local ok, text, extra = ctx.Request(action, ...)
	if type(text) == "string" and text ~= "" then ctx.Toast(text, ok and "good" or "error") end
	if not ok and not text then ctx.Sound("Error") end
	return ok, text, extra
end

local function clear(frame)
	for _, child in ipairs(frame:GetChildren()) do child:Destroy() end
end

local function box(parent, props, colors, radius)
	local f = new("Frame", { BackgroundColor3 = C.White, Parent = parent })
	for k, v in pairs(props or {}) do f[k] = v end
	FKit.corner(f, radius or 14)
	FKit.gradient(f, colors or { Color3.fromRGB(56, 86, 176), Color3.fromRGB(30, 48, 116) }, 90)
	FKit.stroke(f, 3, C.Ink, true)
	return f
end

-- A list that scrolls when it is too long (and never sideways).
local function scroller(parent, padding)
	local s = new("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.White,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	})
	new("UIListLayout", { Padding = UDim.new(0, padding or 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = s })
	new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6), Parent = s })
	return s
end

local function heading(parent, text, order)
	return FKit.text(parent, text, 22, C.Gold, {
		Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order,
	})
end

local function bodyText(parent, text, size, color, props)
	local l = FKit.text(parent, text, size or 18, color or C.White, props)
	l.TextWrapped = true
	l.TextStroke.Thickness = math.max(1.5, (size or 18) / 9)
	return l
end

local function greyOut(button, off)
	FKit.recolor(button, off and P.grey or button:GetAttribute("Palette") and P[button:GetAttribute("Palette")] or P.green)
	button.AutoButtonColor = false
	button.Active = not off
end

local function candy(parent, text, palette, props)
	local b, label = FKit.button(parent, text, P[palette] or P.green, props)
	b:SetAttribute("Palette", palette)
	return b, label
end

-- An icon at the left of a button's text (a coin before a price, a check
-- before OWNED).
local function withIcon(button, label, icon, size)
	size = size or 34
	Icons.new(button, icon, {
		Name = "LabelIcon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, -1),
		Size = UDim2.fromOffset(size, size), ZIndex = button.ZIndex + 2,
	})
	label.Position = UDim2.fromOffset(size + 12, 1)
	label.Size = UDim2.new(1, -(size + 18), 1, -4)
end

local function multiplier()
	local mult = 1 + Config.Season.BonusPer * attr("Season", 0)
	if attr("Pass_DoubleXP", false) then mult *= 2 end
	if attr("Boost", 0) > ctx.Now() then mult *= Config.Boost.Multiplier end
	mult *= Config.StreakMultiplier(attr("StreakDays", 0))
	return mult
end

local function multText(m)
	local text = string.format("%.2f", m):gsub("0+$", ""):gsub("%.$", "")
	return "x" .. text
end

--------------------------------------------------------------------------------
-- My Card: the big card, every stat's XP and your OVR in each position
--------------------------------------------------------------------------------

WINDOWS.Card = {
	Title = "MY CARD", Icon = "\u{1F0CF}", Colors = { Color3.fromRGB(255, 220, 90), Color3.fromRGB(230, 140, 10) },
	Watch = "*",
}

function WINDOWS.Card.Build(page)
	local card = CardView.new(page, { Size = UDim2.fromOffset(222, 311), Viewport = true, ZIndex = 2 })
	CardUI.Track(card)
	card:Set(CardUI.Data())
	CardUI.ShowAvatar(card)

	local mult = FKit.text(page, "", 20, C.Gold, {
		Position = UDim2.fromOffset(0, 318), Size = UDim2.fromOffset(222, 24), RichText = true,
	})

	local right = new("Frame", { Position = UDim2.fromOffset(240, 0), Size = UDim2.new(1, -240, 1, 0), BackgroundTransparency = 1, Parent = page })
	local rows = {}
	for i, stat in ipairs(Config.StatOrder) do
		local def = Config.Stats[stat]
		local row = new("Frame", { Position = UDim2.fromOffset(0, (i - 1) * 46), Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Parent = right })
		local icon = box(row, { Size = UDim2.fromOffset(40, 40) }, { def.Color:Lerp(C.White, 0.35), def.Color }, 20)
		Icons.new(icon, Icons.Stat[stat], { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = icon.ZIndex })
		local name = FKit.text(row, "", 20, C.White, {
			Position = UDim2.fromOffset(48, -3), Size = UDim2.new(1, -48, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
		})
		local bar = FKit.bar(row, { Position = UDim2.fromOffset(48, 20), Size = UDim2.new(1, -50, 0, 22) }, { def.Color:Lerp(C.White, 0.3), def.Color })
		bar.Label.TextSize = 14
		rows[stat] = { Name = name, Bar = bar }
	end

	-- OVR in every position
	local posTitle = FKit.text(right, "OVR IN EACH POSITION", 18, C.Gold, {
		Position = UDim2.fromOffset(0, 280), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left,
	})
	posTitle.Name = "PositionsTitle"
	local chipsRow = new("Frame", { Position = UDim2.fromOffset(0, 306), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = right })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chipsRow })
	local chips = {}
	for i, pos in ipairs(Config.PositionOrder) do
		local chip = box(chipsRow, { Size = UDim2.new(1 / 6, -5, 1, 0), LayoutOrder = i }, nil, 10)
		chips[pos] = { Frame = chip, Label = FKit.fit(chip, "", 18, C.White, { Size = UDim2.new(1, -6, 1, -4), Position = UDim2.fromOffset(3, 2), RichText = true }) }
	end

	-- the next card tier
	local nextTitle = FKit.text(right, "", 18, C.Gold, {
		Position = UDim2.fromOffset(0, 352), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left,
	})
	local nextBar = FKit.bar(right, { Position = UDim2.fromOffset(0, 376), Size = UDim2.new(1, -2, 0, 26) }, { C.Gold, C.GoldDark })
	nextBar.Label.TextSize = 15

	return function()
		card:Set(CardUI.Data())
		local m = multiplier()
		mult.Text = m > 1.001 and ("XP " .. multText(m)) or ""
		local stats = ctx.Stats()
		for _, stat in ipairs(Config.StatOrder) do
			local level = stats[stat]
			local xp = attr("XP_" .. stat, 0)
			local need = attr("Need_" .. stat, Config.XPToNext(level))
			local r = rows[stat]
			r.Name.Text = ("<b>%s %d</b>  <font color=\"#B4C8FF\">%s</font>"):format(stat, level, Config.Stats[stat].Drill)
			if level >= Config.MaxLevel or need <= 0 then
				r.Bar.Set(1, "MAX 99", true)
			else
				r.Bar.Set(xp / need, ("%s / %s XP"):format(Config.Short(xp), Config.Short(need)), true)
			end
		end
		local ovr = attr("OVR", Config.StartLevel)
		local tier = Config.TierFor(ovr)
		local nextTier = Config.TierOrder[Config.TierIndex(tier) + 1]
		if nextTier then
			local from, to = Config.Tiers[tier].Min, Config.Tiers[nextTier].Min
			nextTitle.Text = ("NEXT: %s CARD AT %d OVR"):format(Config.Tiers[nextTier].Label, to)
			nextBar.Set((ovr - from) / (to - from), ("OVR %d / %d"):format(ovr, to), true)
		else
			nextTitle.Text = "99 LEGEND! Start a New Season for more XP."
			nextBar.Set(1, "MAX", true)
		end
		local position = attr("Position", Config.StartPosition)
		for _, pos in ipairs(Config.PositionOrder) do
			local chip = chips[pos]
			local posOVR = Config.OVR(stats, pos)
			chip.Label.Text = ("%s <b>%d</b>"):format(pos, posOVR)
			chip.Frame.UIGradient.Color = FKit.sequence(pos == position and { C.Green, C.GreenDark } or { Color3.fromRGB(56, 86, 176), Color3.fromRGB(30, 48, 116) })
		end
	end, function()
		CardUI.Untrack(card)
	end
end

--------------------------------------------------------------------------------
-- Daily reward: 7 days, the 7th is big
--------------------------------------------------------------------------------

WINDOWS.Daily = {
	Title = "DAILY REWARD", Icon = "\u{1F381}", Colors = { Color3.fromRGB(120, 255, 140), Color3.fromRGB(20, 170, 70) },
	Watch = { NextDaily = true, DailyStreak = true, DailyLast = true },
}

local function dailyState()
	local now = ctx.Now()
	local last = attr("DailyLast", 0)
	local streak = attr("DailyStreak", 0)
	local ready = now - last >= Config.Daily.Cooldown
	if ready and now - last > Config.Daily.Reset then streak = 0 end
	local days = #Config.Daily.Days
	local claimed = streak % days
	if not ready and streak > 0 and claimed == 0 then claimed = days end
	return ready, claimed, last + Config.Daily.Cooldown - now
end

local DAILY_ICON = { Boost = "\u{26A1}", XPAll = "\u{2B50}", Cosmetic = "\u{1F3A8}", Big = "\u{1F3C6}" }

function WINDOWS.Daily.Build(page)
	local ready, claimed = dailyState()
	bodyText(page, "Come back every day! Day 7 is the MEGA reward. Miss two days and you start again at Day 1.", 18, C.White, {
		Size = UDim2.new(1, 0, 0, 46), TextYAlignment = Enum.TextYAlignment.Top,
	})
	local row = new("Frame", { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 176), BackgroundTransparency = 1, Parent = page })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	for day, entry in ipairs(Config.Daily.Days) do
		local done = day <= claimed
		local today = ready and day == claimed + 1
		local big = entry.Kind == "Big"
		local colors = big and { Color3.fromRGB(255, 236, 120), Color3.fromRGB(230, 130, 0) }
			or done and { Color3.fromRGB(80, 200, 100), Color3.fromRGB(20, 120, 50) }
			or today and { Color3.fromRGB(120, 210, 255), Color3.fromRGB(30, 120, 230) }
			or nil
		local tile = box(row, { Size = UDim2.new(1 / 7, -6, 1, today and 0 or -14), LayoutOrder = day }, colors, 14)
		if today then
			local s = tile:FindFirstChildOfClass("UIStroke")
			s.Color = C.White
			s.Thickness = 4
		end
		FKit.fit(tile, "DAY " .. day, 18, C.White, { Size = UDim2.new(1, -6, 0, 22), Position = UDim2.fromOffset(3, 4) })
		Icons.new(tile, Icons.FromEmoji(DAILY_ICON[entry.Kind] or "\u{2B50}"), {
			AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0.5, 0, 0, 28), ZIndex = tile.ZIndex,
		})
		FKit.fit(tile, entry.Name, 17, C.White, { Size = UDim2.new(1, -6, 0, 36), Position = UDim2.fromOffset(3, 76) }).TextWrapped = true
		FKit.fit(tile, entry.Line, 13, Color3.fromRGB(225, 235, 255), { Size = UDim2.new(1, -6, 0, 34), Position = UDim2.fromOffset(3, 112) }).TextWrapped = true
		if done then
			Icons.new(tile, "check", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(40, 40), ZIndex = tile.ZIndex + 4 })
		end
	end

	local claim, claimLabel = candy(page, "CLAIM!", "green", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(260, 70),
	})
	local status = FKit.text(page, "", 20, C.White, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -84), Size = UDim2.fromOffset(500, 26),
	})
	local busy = false
	claim.Activated:Connect(function()
		if busy then return end
		if not dailyState() then ctx.Sound("Error"); return end
		busy = true
		ctx.Sound("Click")
		local ok, text = ctx.Request("ClaimDaily")
		if ok then
			ctx.Toast(text or "Claimed!", "gold")
			ctx.Sound("Buy")
		elseif text then
			ctx.Toast(text, "error")
		end
		busy = false
	end)

	return function()
		local isReady, done, wait = dailyState()
		if isReady then
			claimLabel.Text = "CLAIM DAY " .. (done + 1) .. "!"
			greyOut(claim, false)
			status.Text = ""
		else
			claimLabel.Text = "COME BACK SOON"
			greyOut(claim, true)
			status.Text = "\u{23F0} Next reward in " .. Config.Clock(wait)
		end
	end
end

--------------------------------------------------------------------------------
-- Quests: they never run out, a bigger goal follows each one
--------------------------------------------------------------------------------

WINDOWS.Quests = {
	Title = "QUESTS", Icon = "\u{1F4DC}", Colors = { Color3.fromRGB(255, 190, 110), Color3.fromRGB(230, 100, 20) },
	Watch = { Quests = true },
}

function WINDOWS.Quests.Build(page)
	local list = scroller(page, 8)
	local quests = decode("Quests")
	table.sort(quests, function(a, b)
		local ra, rb = a.Ready and 0 or a.Done and 2 or 1, b.Ready and 0 or b.Done and 2 or 1
		if ra ~= rb then return ra < rb end
		return a.Order < b.Order
	end)
	if #quests == 0 then bodyText(list, "Loading quests...", 20) end
	for i, q in ipairs(quests) do
		local statDef = Config.Stats[q.Stat]
		local color = statDef and statDef.Color or C.Gold
		local row = box(list, { Size = UDim2.new(1, 0, 0, 76), LayoutOrder = i },
			q.Ready and { Color3.fromRGB(90, 200, 110), Color3.fromRGB(26, 120, 56) } or nil, 14)
		local icon = box(row, { Position = UDim2.fromOffset(10, 12), Size = UDim2.fromOffset(52, 52) }, { color:Lerp(C.White, 0.35), color }, 26)
		Icons.new(icon, statDef and Icons.Stat[q.Stat] or "star", { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = icon.ZIndex })
		FKit.fit(row, q.Text, 20, C.White, {
			Position = UDim2.fromOffset(72, 6), Size = UDim2.new(1, -250, 0, 26), TextXAlignment = Enum.TextXAlignment.Left,
		})
		local reward = q.Stat == "ALL" and "Reward: XP for every stat" or ("Reward: big %s XP"):format(q.Stat)
		FKit.text(row, ("Step %d/%d  \u{2022}  %s"):format(math.min(q.Step, q.Steps), q.Steps, reward), 14, Color3.fromRGB(200, 220, 255), {
			Position = UDim2.fromOffset(72, 30), Size = UDim2.new(1, -250, 0, 16), TextXAlignment = Enum.TextXAlignment.Left,
		})
		local bar = FKit.bar(row, { Position = UDim2.fromOffset(72, 48), Size = UDim2.new(1, -250, 0, 20) }, { color:Lerp(C.White, 0.3), color })
		bar.Label.TextSize = 14
		if q.Done then
			bar.Set(1, "ALL DONE!", true)
		elseif q.Lower then
			local best = q.Value > 0 and ("best %.2fs"):format(q.Value) or "no time yet"
			bar.Set(q.Ready and 1 or (q.Value > 0 and math.clamp(q.Goal / q.Value, 0, 1) or 0), best .. " / goal " .. q.Goal .. "s", true)
		else
			bar.Set(q.Value / math.max(1, q.Goal), ("%s / %s"):format(Config.Short(q.Value), Config.Short(q.Goal)), true)
		end
		local button = candy(row, q.Done and "DONE" or q.Ready and "CLAIM!" or "TRAIN", q.Ready and "gold" or "grey", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 56),
		})
		if q.Ready then
			button.Activated:Connect(function()
				ctx.Sound("Click")
				local ok, text = ctx.Request("ClaimQuest", q.Id)
				if ok then ctx.Sound("Buy") end
				if text then ctx.Toast(text, ok and "gold" or "error") end
			end)
		else
			button.Active = false
		end
	end
end

--------------------------------------------------------------------------------
-- Positions: the same stats give a different OVR in each position
--------------------------------------------------------------------------------

WINDOWS.Positions = {
	Title = "POSITIONS", Icon = "\u{1F4CB}", Colors = { Color3.fromRGB(140, 220, 255), Color3.fromRGB(30, 120, 230) },
	Watch = { Position = true, PositionsUnlocked = true, OVR = true, PAC = true, SHO = true, PAS = true, DRI = true, DEF = true, PHY = true },
}

function WINDOWS.Positions.Build(page)
	local unlocked = attr("PositionsUnlocked", false)
	local position = attr("Position", Config.StartPosition)
	local stats = ctx.Stats()
	local ovr = attr("OVR", Config.StartLevel)
	local top
	if unlocked then
		top = bodyText(page, "Pick where you play. Your OVR is worked out from the stats that matter most there.", 18, C.White, {
			Size = UDim2.new(1, 0, 0, 44), TextYAlignment = Enum.TextYAlignment.Top,
		})
	else
		top = bodyText(page, ("\u{1F512} The Position Board opens at %d OVR. You are %d."):format(Config.PositionsUnlockOVR, ovr), 20, C.Gold, {
			Size = UDim2.new(1, 0, 0, 26),
		})
		local bar = FKit.bar(page, { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 18) })
		bar.Label.TextSize = 13
		bar.Set((ovr - Config.StartLevel) / (Config.PositionsUnlockOVR - Config.StartLevel), "", true)
	end
	top.Name = "Top"
	local grid = new("Frame", { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54), BackgroundTransparency = 1, Parent = page })
	new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -8, 0.5, -8), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for i, pos in ipairs(Config.PositionOrder) do
		local def = Config.Positions[pos]
		local here = pos == position
		local open = unlocked or pos == Config.StartPosition
		local tile = box(grid, { LayoutOrder = i }, here and { Color3.fromRGB(110, 230, 120), Color3.fromRGB(20, 140, 60) } or nil, 14)
		FKit.fit(tile, pos, 34, C.White, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.45, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Left })
		FKit.fit(tile, tostring(Config.OVR(stats, pos)), 34, C.Gold, {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 4), Size = UDim2.new(0.45, 0, 0, 38), TextXAlignment = Enum.TextXAlignment.Right,
		})
		FKit.fit(tile, def.Name, 16, C.White, { Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -20, 0, 18), TextXAlignment = Enum.TextXAlignment.Left })
		-- the two stats that count the most
		local order = {}
		for stat, w in pairs(def.Weights) do table.insert(order, { stat, w }) end
		table.sort(order, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end; return a[1] < b[1] end)
		FKit.fit(tile, ("%s %d%%  %s %d%%"):format(order[1][1], order[1][2] * 100 + 0.5, order[2][1], order[2][2] * 100 + 0.5), 14, Color3.fromRGB(210, 225, 255), {
			Position = UDim2.fromOffset(10, 60), Size = UDim2.new(1, -20, 0, 16), TextXAlignment = Enum.TextXAlignment.Left,
		})
		local text = here and "PLAYING" or open and "PLAY HERE" or ("\u{1F512} " .. Config.PositionsUnlockOVR)
		local b = candy(tile, text, here and "gold" or open and "blue" or "grey", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -20, 0, 44),
		})
		if open and not here then
			b.Activated:Connect(function()
				ctx.Sound("Click")
				ask("SetPosition", pos)
			end)
		else
			b.Active = false
		end
	end
end

--------------------------------------------------------------------------------
-- Season: at 99, start again from 60 with +25% XP forever
--------------------------------------------------------------------------------

WINDOWS.Season = {
	Title = "NEW SEASON", Icon = "\u{1F504}", Colors = { Color3.fromRGB(230, 170, 255), Color3.fromRGB(130, 50, 230) },
	Watch = { Season = true, OVR = true },
}

function WINDOWS.Season.Build(page)
	local season = attr("Season", 0)
	local ovr = attr("OVR", Config.StartLevel)
	local nextSeason = season + 1
	local color = Config.SeasonColor(nextSeason)

	-- the badge you will get
	local badgeHolder = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(170, 170), BackgroundTransparency = 1, Parent = page })
	local badge = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.72, 0.72),
		Rotation = 45, BackgroundColor3 = C.White, Parent = badgeHolder,
	})
	FKit.corner(badge, 18)
	FKit.gradient(badge, { color:Lerp(C.White, 0.45), color, color:Lerp(C.Ink, 0.35) }, 90)
	FKit.stroke(badge, 5, C.Ink, true)
	FKit.fit(badgeHolder, "S" .. nextSeason, 64, C.White, { Size = UDim2.fromScale(0.8, 0.5), Position = UDim2.fromScale(0.1, 0.25), ZIndex = 3 })
	FKit.text(page, season > 0 and ("You are in SEASON %d"):format(season) or "Your first season", 20, C.Gold, {
		Position = UDim2.fromOffset(0, 186), Size = UDim2.fromOffset(190, 24),
	})
	FKit.text(page, ("XP now: +%d%%"):format(Config.Season.BonusPer * season * 100 + 0.5), 18, C.White, {
		Position = UDim2.fromOffset(0, 212), Size = UDim2.fromOffset(190, 22),
	})

	local right = new("Frame", { Position = UDim2.fromOffset(210, 0), Size = UDim2.new(1, -210, 1, 0), BackgroundTransparency = 1, Parent = page })
	FKit.fit(right, ("REACH %d, THEN START SEASON %d"):format(Config.Season.NeedOVR, nextSeason), 26, C.White, { Size = UDim2.new(1, 0, 0, 32) })
	local lines = {
		("\u{2B06} +%d%% XP in every drill, forever (you get it every season)"):format(Config.Season.BonusPer * 100 + 0.5),
		("\u{1F3F7} An S%d badge on your card and on the leaderboard"):format(nextSeason),
		"\u{1F504} Your stats go back to 60 so you can climb again",
		"\u{2705} You keep: quests, styles, passes and your best times",
	}
	for i, line in ipairs(lines) do
		bodyText(right, line, 17, C.White, {
			Position = UDim2.fromOffset(0, 40 + (i - 1) * 32), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	local bar = FKit.bar(right, { Position = UDim2.fromOffset(0, 180), Size = UDim2.new(1, 0, 0, 30) }, { Color3.fromRGB(230, 170, 255), Color3.fromRGB(130, 50, 230) })
	bar.Set((ovr - Config.StartLevel) / (Config.Season.NeedOVR - Config.StartLevel), ("OVR %d / %d"):format(ovr, Config.Season.NeedOVR), true)
	FKit.text(right, "Seasons and LEGEND can never be bought.", 15, Color3.fromRGB(190, 205, 240), {
		Position = UDim2.fromOffset(0, 214), Size = UDim2.new(1, 0, 0, 18),
	})

	local canStart = ovr >= Config.Season.NeedOVR
	local b, label = candy(right, canStart and ("START SEASON " .. nextSeason) or ("\u{1F512} NEED " .. Config.Season.NeedOVR .. " OVR"), canStart and "purple" or "grey", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(300, 66),
	})
	local sure = false
	b.Activated:Connect(function()
		if not canStart then ctx.Sound("Error"); return end
		ctx.Sound("Click")
		if not sure then
			sure = true
			label.Text = "SURE? TAP AGAIN!"
			FKit.recolor(b, P.red)
			task.delay(4, function()
				if sure and label.Parent then
					sure = false
					label.Text = "START SEASON " .. nextSeason
					FKit.recolor(b, P.purple)
				end
			end)
			return
		end
		sure = false
		local ok = ask("NewSeason")
		if ok then MenusUI.Close() end
	end)
end

--------------------------------------------------------------------------------
-- Style: borders, backgrounds and celebrations for your card
--------------------------------------------------------------------------------

WINDOWS.Style = {
	Title = "CARD STYLE", Icon = "\u{1F3A8}", Colors = { Color3.fromRGB(255, 160, 230), Color3.fromRGB(220, 50, 160) },
	Watch = { Cosmetics = true, Pass_Cosmetics = true },
}

local function sortedCosmetics(kind)
	local list = {}
	for id, item in pairs(Config.Cosmetics) do
		if item.Kind == kind then table.insert(list, id) end
	end
	local function rank(id)
		local item = Config.Cosmetics[id]
		return item.Default and 0 or item.Pack and 2 or 1
	end
	table.sort(list, function(a, b)
		if rank(a) ~= rank(b) then return rank(a) < rank(b) end
		return Config.Cosmetics[a].Name < Config.Cosmetics[b].Name
	end)
	return list
end

-- Where a locked item comes from.
local function source(id)
	for day, entry in ipairs(Config.Daily.Days) do
		if entry.Item == id then return "DAY " .. day end
	end
	return Config.Cosmetics[id].Pack and "PACK" or ""
end

local DEFAULT_LOOK = { Border = "Border_Classic", Background = "Background_Stadium", Celebration = "Celebration_Confetti" }

-- The card as it looks now, with the default look filled in.
local function lookNow()
	local d = CardUI.Data()
	d.Border = d.Border or DEFAULT_LOOK.Border
	d.Background = d.Background or DEFAULT_LOOK.Background
	return d
end

local CELEBRATION_ICON = { Celebration_Confetti = "\u{1F389}", Celebration_Fireworks = "\u{1F386}", Celebration_Lightning = "\u{26A1}", Celebration_Hearts = "\u{1F496}" }

function WINDOWS.Style.Build(page)
	local cosmetics = decode("Cosmetics")
	local owned = cosmetics.Owned or {}
	local preview = CardView.new(page, { Size = UDim2.fromOffset(190, 266), Viewport = true, Position = UDim2.fromOffset(0, 10), ZIndex = 2 })
	CardUI.Track(preview)
	preview:Set(lookNow())
	CardUI.ShowAvatar(preview)
	if not attr("Pass_Cosmetics", false) then
		local b = candy(page, "\u{1F6CD} STYLE PACK", "purple", { Position = UDim2.fromOffset(0, 290), Size = UDim2.fromOffset(190, 50) })
		b.Activated:Connect(function()
			ctx.Sound("Click")
			MenusUI.Open("Shop")
		end)
	end

	local right = new("Frame", { Position = UDim2.fromOffset(206, 0), Size = UDim2.new(1, -206, 1, 0), BackgroundTransparency = 1, Parent = page })
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = right })
	for k, kind in ipairs(Config.CosmeticKinds) do
		heading(right, kind:upper(), k * 2 - 1)
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 86), BackgroundTransparency = 1, LayoutOrder = k * 2, Parent = right })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
		for i, id in ipairs(sortedCosmetics(kind)) do
			local item = Config.Cosmetics[id]
			local has = item.Default or owned[id] == true
			local equipped = (cosmetics[kind] or DEFAULT_LOOK[kind]) == id
			local tile = new("TextButton", {
				Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(78, 86), LayoutOrder = i,
				BackgroundColor3 = C.White, Parent = row,
			})
			FKit.corner(tile, 12)
			FKit.gradient(tile, equipped and { C.Green, C.GreenDark } or { Color3.fromRGB(56, 86, 176), Color3.fromRGB(30, 48, 116) }, 90)
			FKit.stroke(tile, equipped and 4 or 3, equipped and C.White or C.Ink, true)
			FKit.press(tile)
			local swatch = new("Frame", { Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 40), BackgroundColor3 = C.White, Parent = tile })
			FKit.corner(swatch, 8)
			FKit.stroke(swatch, 2, C.Ink, true)
			if kind == "Celebration" then
				swatch.BackgroundColor3 = Color3.fromRGB(20, 30, 80)
				FKit.fit(swatch, CELEBRATION_ICON[id] or "\u{2728}", 28, C.White, { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold })
			else
				local colors = item.Colors or { Color3.fromRGB(196, 120, 60), Color3.fromRGB(92, 48, 18) }
				FKit.gradient(swatch, colors, kind == "Border" and 0 or 90)
			end
			FKit.fit(tile, item.Name, 15, C.White, { Position = UDim2.fromOffset(3, 48), Size = UDim2.new(1, -6, 0, 18) })
			local state = equipped and "ON" or has and "USE" or ("\u{1F512} " .. source(id))
			FKit.fit(tile, state, 13, equipped and C.White or has and C.Gold or Color3.fromRGB(190, 200, 230), { Position = UDim2.fromOffset(3, 66), Size = UDim2.new(1, -6, 0, 16) })
			if not has then
				new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.55, ZIndex = 2, Parent = swatch })
			end
			tile.MouseEnter:Connect(function()
				local look = {}
				look[kind] = id
				if kind ~= "Celebration" then preview:Set(look) end
			end)
			tile.MouseLeave:Connect(function() preview:Set(lookNow()) end)
			tile.Activated:Connect(function()
				if not has then
					ctx.Sound("Error")
					ctx.Toast(item.Pack and "This comes with the Card Style Pack." or "Claim daily rewards to unlock this!", "info")
					return
				end
				if equipped then return end
				ctx.Sound("Click")
				ask("Equip", id)
			end)
		end
	end
	return nil, function()
		CardUI.Untrack(preview)
	end
end

--------------------------------------------------------------------------------
-- Shop: gamepasses and products (fair: no LEGEND, no seasons)
--------------------------------------------------------------------------------

WINDOWS.Shop = {
	Title = "SHOP", Icon = "\u{1F6D2}", Colors = { Color3.fromRGB(255, 240, 120), Color3.fromRGB(240, 150, 0) },
	Watch = { Pass_DoubleXP = true, Pass_VIP = true, Pass_AutoTrain = true, Pass_Cosmetics = true, Boost = true,
		PAC = true, SHO = true, PAS = true, DRI = true, DEF = true, PHY = true },
}

local PASS_LOOK = {
	DoubleXP = { "\u{26A1}", { Color3.fromRGB(255, 236, 120), Color3.fromRGB(240, 150, 0) } },
	VIP = { "\u{1F451}", { Color3.fromRGB(255, 200, 255), Color3.fromRGB(190, 60, 230) } },
	AutoTrain = { "\u{1F916}", { Color3.fromRGB(150, 240, 255), Color3.fromRGB(20, 140, 230) } },
	Cosmetics = { "\u{1F3A8}", { Color3.fromRGB(255, 170, 200), Color3.fromRGB(230, 50, 120) } },
	SpeedBoots = { "\u{1F45F}", { Color3.fromRGB(170, 255, 170), Color3.fromRGB(30, 170, 80) } },
}

-- the XP packs: icon and colours
local PACK_LOOK = {
	Boost60 = { "stopwatch", { Color3.fromRGB(255, 180, 120), Color3.fromRGB(240, 90, 30) } },
	StatPoint3 = { "plus", { Color3.fromRGB(140, 230, 255), Color3.fromRGB(30, 130, 240) } },
	TrainingPack = { "star", { Color3.fromRGB(200, 255, 140), Color3.fromRGB(60, 180, 60) } },
	MegaPack = { "diamond", { Color3.fromRGB(230, 170, 255), Color3.fromRGB(140, 50, 240) } },
}

local pickedStat -- the stat the +1 Stat Point goes to

function WINDOWS.Shop.Build(page)
	local list = scroller(page, 8)
	heading(list, "GAMEPASSES (FOREVER)", 1)
	local passes = new("Frame", { Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1, LayoutOrder = 2, Parent = list })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = passes })
	for i, key in ipairs(Config.PassOrder) do
		local pass = Config.Gamepasses[key]
		local look = PASS_LOOK[key]
		local ownedPass = attr("Pass_" .. key, false)
		local tile = box(passes, { Size = UDim2.new(1 / #Config.PassOrder, -7, 1, 0), LayoutOrder = i }, look[2], 16)
		Icons.new(tile, Icons.FromEmoji(look[1]), { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(44, 44), ZIndex = tile.ZIndex })
		FKit.fit(tile, pass.Name, 19, C.White, { Position = UDim2.fromOffset(6, 50), Size = UDim2.new(1, -12, 0, 24) })
		bodyText(tile, pass.Line, 15, C.White, { Position = UDim2.fromOffset(6, 76), Size = UDim2.new(1, -12, 0, 68), TextYAlignment = Enum.TextYAlignment.Top })
		local b, priceLabel = candy(tile, ownedPass and "OWNED" or tostring(pass.Price), ownedPass and "grey" or "green", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 46),
		})
		withIcon(b, priceLabel, ownedPass and "check" or "coin")
		if not ownedPass then FKit.shine(b, 2 + i * 0.4) end
		if ownedPass then
			b.Active = false
		else
			b.Activated:Connect(function()
				ctx.Sound("Click")
				ask("BuyPass", key)
			end)
		end
	end

	heading(list, "BOOSTS", 3)
	local products = new("Frame", { Size = UDim2.new(1, 0, 0, 170), BackgroundTransparency = 1, LayoutOrder = 4, Parent = list })
	-- 2x XP boost
	local boost = Config.Products.Boost15
	local boostTile = box(products, { Size = UDim2.new(0.34, -4, 1, 0) }, PASS_LOOK.DoubleXP[2], 16)
	Icons.new(boostTile, "stopwatch", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(40, 40), ZIndex = boostTile.ZIndex })
	FKit.fit(boostTile, boost.Name, 20, C.White, { Position = UDim2.fromOffset(6, 44), Size = UDim2.new(1, -12, 0, 24) })
	local boostLeft = FKit.fit(boostTile, boost.Line, 15, C.White, { Position = UDim2.fromOffset(6, 70), Size = UDim2.new(1, -12, 0, 36) })
	boostLeft.TextWrapped = true
	local boostButton, boostPrice = candy(boostTile, tostring(boost.Price), "green", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 46),
	})
	withIcon(boostButton, boostPrice, "coin")
	FKit.shine(boostButton, 2.6)
	boostButton.Activated:Connect(function()
		ctx.Sound("Click")
		ask("BuyProduct", "Boost15")
	end)

	-- +1 stat point: pick the stat first
	local point = Config.Products.StatPoint
	local pointTile = box(products, { Position = UDim2.new(0.34, 4, 0, 0), Size = UDim2.new(0.66, -4, 1, 0) }, { Color3.fromRGB(150, 240, 170), Color3.fromRGB(20, 150, 70) }, 16)
	Icons.new(pointTile, "plus", { Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(28, 28), ZIndex = pointTile.ZIndex })
	FKit.fit(pointTile, point.Name, 20, C.White, { Position = UDim2.fromOffset(40, 6), Size = UDim2.new(1, -50, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
	FKit.fit(pointTile, point.Line, 15, C.White, { Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 18), TextXAlignment = Enum.TextXAlignment.Left })
	local statRow = new("Frame", { Position = UDim2.fromOffset(10, 52), Size = UDim2.new(1, -20, 0, 54), BackgroundTransparency = 1, Parent = pointTile })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = statRow })
	local stats = ctx.Stats()
	local statButtons = {}
	local buy, buyLabel = candy(pointTile, "", "green", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -20, 0, 46),
	})
	withIcon(buy, buyLabel, "coin")
	local function pick(stat)
		pickedStat = stat
		for s, b in pairs(statButtons) do
			local canTake = stats[s] < point.MaxLevel
			b.UIGradient.Color = FKit.sequence(s == stat and { C.White, Color3.fromRGB(255, 230, 120) }
				or canTake and { Config.Stats[s].Color:Lerp(C.White, 0.3), Config.Stats[s].Color } or { C.Grey, Color3.fromRGB(90, 96, 130) })
			b.UIStroke.Color = s == stat and C.Gold or C.Ink
		end
		if stat then
			buyLabel.Text = ("+1 %s  %d"):format(stat, point.Price)
			greyOut(buy, false)
		else
			buyLabel.Text = "PICK A STAT"
			greyOut(buy, true)
		end
	end
	for i, stat in ipairs(Config.StatOrder) do
		local b = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1 / 6, -5, 1, 0), LayoutOrder = i, BackgroundColor3 = C.White, Parent = statRow })
		FKit.corner(b, 10)
		FKit.gradient(b, { C.White, C.Grey }, 90)
		FKit.stroke(b, 3, C.Ink, true)
		FKit.press(b)
		FKit.fit(b, stat, 16, C.White, { Size = UDim2.new(1, -4, 0.5, 0), Position = UDim2.fromOffset(2, 2) })
		FKit.fit(b, tostring(stats[stat]), 20, C.White, { Size = UDim2.new(1, -4, 0.5, -2), Position = UDim2.new(0, 2, 0.5, 0) })
		statButtons[stat] = b
		b.Activated:Connect(function()
			if stats[stat] >= point.MaxLevel then
				ctx.Sound("Error")
				ctx.Toast(("Stat points only work up to %d."):format(point.MaxLevel), "error")
				return
			end
			ctx.Sound("Click")
			pick(stat)
		end)
	end
	if pickedStat and stats[pickedStat] >= point.MaxLevel then pickedStat = nil end
	pick(pickedStat)
	buy.Activated:Connect(function()
		if not pickedStat then ctx.Sound("Error"); return end
		ctx.Sound("Click")
		ask("BuyProduct", "StatPoint", pickedStat)
	end)

	-- XP packs: four tiles with a tag on the best ones
	heading(list, "XP PACKS", 5)
	local packs = new("Frame", { Size = UDim2.new(1, 0, 0, 176), BackgroundTransparency = 1, LayoutOrder = 6, Parent = list })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = packs })
	for i, key in ipairs(Config.PackOrder) do
		local product = Config.Products[key]
		local look = PACK_LOOK[key]
		local tile = box(packs, { Size = UDim2.new(1 / #Config.PackOrder, -6, 1, 0), LayoutOrder = i }, look[2], 16)
		FKit.fallingBlocks(tile, { Max = 3, Every = 1.1, Transparency = 0.6, Corner = 16, ZIndex = tile.ZIndex })
		local icon = Icons.new(tile, look[1], { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(40, 40), ZIndex = tile.ZIndex + 1 })
		FKit.pulse(icon, 0.08, 0.8 + i * 0.1)
		FKit.fit(tile, product.Name, 18, C.White, { Position = UDim2.fromOffset(6, 48), Size = UDim2.new(1, -12, 0, 22), ZIndex = tile.ZIndex + 1 })
		bodyText(tile, product.Line, 13, C.White, { Position = UDim2.fromOffset(6, 72), Size = UDim2.new(1, -12, 0, 48), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = tile.ZIndex + 1 })
		local b, priceLabel = candy(tile, tostring(product.Price), "green", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 40), ZIndex = tile.ZIndex + 2,
		})
		withIcon(b, priceLabel, "coin", 28)
		FKit.shine(b, 1.8 + i * 0.5)
		b.Activated:Connect(function()
			ctx.Sound("Click")
			ask("BuyProduct", key)
		end)
		if product.Tag then
			local tag = FKit.tag(tile, product.Tag, product.Tag == "HOT" and { Color3.fromRGB(255, 150, 90), Color3.fromRGB(230, 40, 40) } or nil, {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -18, 0, 4), ZIndex = tile.ZIndex + 4,
			})
			FKit.wobble(tag, 7, 0.6)
		end
	end

	bodyText(list, "\u{1F6E1} Fair play: LEGEND cards and Seasons can never be bought. You earn them by training!", 16, Color3.fromRGB(200, 220, 255), {
		Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 7,
	})

	return function()
		local left = attr("Boost", 0) - ctx.Now()
		boostLeft.Text = left > 0 and ("\u{26A1} Active: " .. Config.Clock(left) .. " left") or boost.Line
	end
end

--------------------------------------------------------------------------------
-- The window
--------------------------------------------------------------------------------

local cleanup

function MenusUI.Close()
	if not current then return end
	current = nil
	refresher = nil
	if cleanup then cleanup() end
	cleanup = nil
	ctx.Sound("Close")
	for _, b in pairs(buttons) do b.Button.Border.Color = C.Ink end
	tween(dim, 0.15, { BackgroundTransparency = 1 })
	local s = FKit.scaleOf(panel)
	tween(s, 0.15, { Scale = 0.85 })
	task.delay(0.15, function()
		if current then return end
		holder.Visible = false
		dim.Visible = false
		clear(page)
	end)
end

local function build(name)
	local def = WINDOWS[name]
	if cleanup then cleanup() end
	cleanup = nil
	clear(page)
	local ok, refresh, done = pcall(def.Build, page)
	if not ok then
		warn("[Football] menu " .. name .. " failed:", refresh)
		refresh, done = nil, nil
	end
	refresher = refresh
	cleanup = done
	if refresher then refresher() end
end

-- Opens a window (toggle: a second tap on its button closes it).
function MenusUI.Open(name, toggle)
	local def = WINDOWS[name]
	if not def then return end
	if current == name then
		if toggle then MenusUI.Close() end
		return
	end
	current = name
	titleLabel.Text = def.Title
	Icons.set(titleIcon, Icons.FromEmoji(def.Icon))
	panel.Header.UIGradient.Color = FKit.sequence(def.Colors)
	for key, b in pairs(buttons) do b.Button.Border.Color = key == name and C.White or C.Ink end
	build(name)
	if not holder.Visible then
		holder.Visible = true
		dim.Visible = true
		dim.BackgroundTransparency = 1
		tween(dim, 0.2, { BackgroundTransparency = 0.45 })
		FKit.pop(panel, 0.7, 0.3)
	end
	ctx.Sound("Open")
end

local function buildWindow()
	dim = new("TextButton", {
		Name = "Dim", Size = UDim2.fromScale(1, 1), Text = "", AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(4, 8, 30), BackgroundTransparency = 1, Visible = false, Parent = gui,
	})
	dim.Activated:Connect(MenusUI.Close)
	holder = new("Frame", {
		Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 14), Size = UDim2.fromOffset(700, 470),
		BackgroundTransparency = 1, Visible = false, ZIndex = 2, Parent = gui,
	})
	MenusUI.Fit(holder, 740, 540)
	panel = FKit.panel(holder, { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, 22)
	FKit.fallingBlocks(panel, { Corner = 22, ZIndex = 2 })
	local header = new("Frame", { Name = "Header", Position = UDim2.fromOffset(10, -22), Size = UDim2.new(0, 330, 0, 58), BackgroundColor3 = C.White, ZIndex = 3, Parent = panel })
	FKit.corner(header, 16)
	FKit.gradient(header, { C.Gold, C.GoldDark }, 90)
	FKit.stroke(header, 4, C.Ink, true)
	titleIcon = Icons.new(header, "star", { Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(46, 46), ZIndex = 4 })
	titleLabel = FKit.fit(header, "", 34, C.White, {
		Position = UDim2.fromOffset(58, 6), Size = UDim2.new(1, -66, 1, -12), ZIndex = 4, TextXAlignment = Enum.TextXAlignment.Left,
	})
	local close = candy(panel, "\u{2715}", "red", {
		Name = "Close", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -14, 0, 8), Size = UDim2.fromOffset(48, 48), ZIndex = 4,
	})
	close.Label.Text = ""
	Icons.new(close, "cross", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(30, 30), ZIndex = close.ZIndex + 2 })
	close.Activated:Connect(MenusUI.Close)
	page = new("Frame", { Name = "Page", Position = UDim2.fromOffset(20, 50), Size = UDim2.new(1, -40, 1, -64), BackgroundTransparency = 1, ZIndex = 3, Parent = panel })
end

--------------------------------------------------------------------------------
-- The buttons on the left and the chips at the top
--------------------------------------------------------------------------------

local MENU = {
	{ "Card", "MY CARD", "\u{1F0CF}", "gold" },
	{ "Daily", "DAILY", "\u{1F381}", "green" },
	{ "Quests", "QUESTS", "\u{1F4DC}", "orange" },
	{ "Positions", "POSITION", "\u{1F4CB}", "blue" },
	{ "Season", "SEASON", "\u{1F504}", "purple" },
	{ "Style", "STYLE", "\u{1F3A8}", "red" },
	{ "Shop", "SHOP", "\u{1F6D2}", "gold" },
}

local function buildMenu()
	local menu = new("Frame", {
		Name = "Menu", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 30), Size = UDim2.fromOffset(138, 284),
		BackgroundTransparency = 1, ZIndex = 5, Parent = gui,
	})
	MenusUI.Fit(menu, 900, 600)
	for i, entry in ipairs(MENU) do
		local key, text, icon, palette = entry[1], entry[2], entry[3], entry[4]
		local wide = key == "Shop"
		local col, row = (i - 1) % 2, (i - 1) // 2
		local b, label = candy(menu, text, palette, {
			Name = key,
			Position = UDim2.fromOffset(wide and 0 or col * 72, row * 72),
			Size = UDim2.fromOffset(wide and 138 or 66, wide and 56 or 66),
		})
		if not wide then
			label.Position = UDim2.new(0, 3, 1, -23)
			label.Size = UDim2.new(1, -6, 0, 17)
			label:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 14
			Icons.new(b, Icons.FromEmoji(icon), { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(36, 36), ZIndex = b.ZIndex + 1 })
		else
			Icons.new(b, Icons.FromEmoji(icon), { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, -1), Size = UDim2.fromOffset(40, 40), ZIndex = b.ZIndex + 1 })
			label.Position = UDim2.fromOffset(52, 1)
			label.Size = UDim2.new(1, -58, 1, -4)
			label:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 24
		end
		local badge = new("Frame", {
			Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = C.White, Visible = false, ZIndex = b.ZIndex + 3, Parent = b,
		})
		FKit.corner(badge, UDim.new(0.5, 0))
		FKit.gradient(badge, { Color3.fromRGB(255, 120, 120), Color3.fromRGB(220, 20, 50) }, 90)
		FKit.stroke(badge, 3, C.Ink, true)
		local badgeLabel = FKit.fit(badge, "!", 20, C.White, { Size = UDim2.fromScale(1, 1), ZIndex = badge.ZIndex + 1 })
		buttons[key] = { Button = b, Badge = badge, BadgeLabel = badgeLabel }
		b.Activated:Connect(function()
			ctx.Sound("Click")
			MenusUI.Open(key, true)
		end)
	end
end

local function setBadge(key, text)
	local b = buttons[key]
	if not b then return end
	local show = text ~= nil and text ~= ""
	if show and not b.Badge.Visible then FKit.pop(b.Badge, 0.4, 0.3) end
	b.Badge.Visible = show
	if show then b.BadgeLabel.Text = text end
end

local function updateBadges()
	local ready = dailyState()
	setBadge("Daily", attr("DataReady", false) and ready and "!" or nil)
	local quests = attr("QuestsReady", 0)
	setBadge("Quests", quests > 0 and tostring(quests) or nil)
	setBadge("Season", attr("OVR", 0) >= Config.Season.NeedOVR and "!" or nil)
	local lock = buttons.Positions
	if lock then
		Icons.set(lock.Button.Icon, attr("PositionsUnlocked", false) and "clipboard" or "lock")
	end
end

-- Chips at the top left: 2x boost time, streak, total XP multiplier.
local chips = {}
local function buildChips()
	local row = new("Frame", {
		Name = "Chips", Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(600, 34),
		BackgroundTransparency = 1, Parent = ctx.Gui,
	})
	MenusUI.Fit(row, 900, 500)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	local function chip(name, order, colors)
		local t, l = FKit.tag(row, "", colors, { Name = name, LayoutOrder = order, Size = UDim2.fromOffset(0, 34), Visible = false })
		l.TextSize = 19
		chips[name] = { Frame = t, Label = l }
	end
	chip("Mult", 1, { Color3.fromRGB(130, 255, 140), Color3.fromRGB(20, 160, 60) })
	chip("Boost", 2, { Color3.fromRGB(255, 236, 120), Color3.fromRGB(240, 150, 0) })
	chip("Streak", 3, { Color3.fromRGB(255, 190, 110), Color3.fromRGB(230, 80, 20) })
	chip("Season", 4, { Color3.fromRGB(230, 170, 255), Color3.fromRGB(130, 50, 230) })
end

local function updateChips()
	local now = ctx.Now()
	local m = multiplier()
	chips.Mult.Frame.Visible = m > 1.001
	chips.Mult.Label.Text = "XP " .. multText(m)
	local boost = attr("Boost", 0) - now
	chips.Boost.Frame.Visible = boost > 0
	chips.Boost.Label.Text = "\u{26A1} 2x XP " .. Config.Clock(boost)
	local days = attr("StreakDays", 0)
	local today = math.floor(now / 86400)
	local alive = attr("StreakLastDay", -1) >= today - 1
	chips.Streak.Frame.Visible = alive and days >= 2
	chips.Streak.Label.Text = ("\u{1F525} %d DAYS +%d%%"):format(days, (Config.StreakMultiplier(days) - 1) * 100 + 0.5)
	local season = attr("Season", 0)
	chips.Season.Frame.Visible = season > 0
	chips.Season.Label.Text = ("S%d +%d%%"):format(season, Config.Season.BonusPer * season * 100 + 0.5)
end

--------------------------------------------------------------------------------

function MenusUI.Init(c)
	ctx = c
	ctx.OpenMenu = MenusUI.Open
	ctx.CloseMenu = MenusUI.Close
	ctx.Fit = MenusUI.Fit
	gui = new("ScreenGui", {
		Name = "FootballMenus",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = ctx.Gui.Parent,
	})
	buildWindow()
	buildMenu()
	buildChips()
	local card = CardUI.Holder()
	if card then MenusUI.Fit(card, 900, 580) end

	-- keep the open window up to date (a moment after the last change)
	local queued = false
	player.AttributeChanged:Connect(function(name)
		if not queued then
			queued = true
			task.defer(function()
				queued = false
				updateBadges()
				updateChips()
			end)
		end
		local def = current and WINDOWS[current]
		if not def then return end
		if (def.Watch == "*" or def.Watch[name]) and not def.Pending then
			-- "*" windows update in place, the others are built again
			def.Pending = true
			task.delay(def.Watch == "*" and 0 or 0.15, function()
				def.Pending = false
				if not (current and WINDOWS[current] == def) then return end
				if def.Watch == "*" then
					if refresher then refresher() end
				else
					build(current)
				end
			end)
		end
	end)

	-- clocks: boost timer, daily countdown
	task.spawn(function()
		while gui.Parent do
			updateBadges()
			updateChips()
			if refresher and (current == "Daily" or current == "Shop") then refresher() end
			task.wait(0.5)
		end
	end)
	updateBadges()
	updateChips()
end

return MenusUI
