-- Your card, small and clean in the bottom-right corner, with your avatar in
-- it. It shows the six stats, pops a stat when it goes +1, and opens the big
-- "My Card" window when you tap it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))
local FKit = require(ReplicatedStorage:WaitForChild("FKit"))
local CardView = require(ReplicatedStorage:WaitForChild("CardView"))

local CardUI = {}

local ctx, card, holder
local player = Players.LocalPlayer
local animated = {} -- every card on screen that animates

function CardUI.Track(view)
	animated[view] = true
end

function CardUI.Untrack(view)
	animated[view] = nil
end

-- What the card shows right now, from the player's attributes.
function CardUI.Data()
	local cosmetics = {}
	pcall(function() cosmetics = HttpService:JSONDecode(player:GetAttribute("Cosmetics") or "{}") end)
	return {
		OVR = player:GetAttribute("OVR") or Config.StartLevel,
		Position = player:GetAttribute("Position") or Config.StartPosition,
		Name = player.DisplayName,
		Stats = ctx.Stats(),
		Season = player:GetAttribute("Season") or 0,
		Border = cosmetics.Border,
		Background = cosmetics.Background,
		Tier = nil,
	}
end

-- While the upgrade moment plays, the corner card waits with the old OVR.
local frozen = false
function CardUI.Freeze(on)
	frozen = on
	if not on then CardUI.Refresh() end
end

function CardUI.Refresh()
	if frozen or not card then return end
	card:Set(CardUI.Data())
end

function CardUI.Holder()
	return holder
end

-- Your avatar on a card: your Roblox avatar picture, or (a Studio test
-- player with no picture) a copy of your character.
function CardUI.ShowAvatar(view)
	if view:ShowPlayer(player.UserId) then return end
	local character = player.Character
	if character then view:ShowCharacter(character) end
end

-- A stat went +1: its number pops and "+1 SHO" floats up from the card.
function CardUI.StatUp(data)
	if not card then return end
	CardUI.Refresh()
	local cell = card.StatLabels[data.Stat]
	if cell then
		cell.Value.Text = tostring(data.Level)
		FKit.pop(cell.Cell, 1.8, 0.45)
	end
	local color = Config.Stats[data.Stat] and Config.Stats[data.Stat].Color or FKit.Color.Gold
	FKit.float(holder, ("+%d %s"):format(data.Ups or 1, data.Stat), color, UDim2.new(0.5, 0, 0, -18), 30)
	ctx.Sound("Pop", 1, 1 + math.min(data.Level - 60, 39) / 80)
end

function CardUI.Init(c)
	ctx = c
	holder = FKit.new("Frame", {
		Name = "MyCard",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(150, 210),
		BackgroundTransparency = 1,
		Parent = ctx.Gui,
	})
	card = CardView.new(holder, { Size = UDim2.fromScale(1, 1), Viewport = true })
	CardUI.Track(card)
	local button = FKit.new("TextButton", {
		Name = "OpenCard",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 30,
		Parent = holder,
	})
	FKit.press(button)
	button.Activated:Connect(function()
		ctx.Sound("Click")
		if ctx.OpenMenu then ctx.OpenMenu("Card") end
	end)

	CardUI.ShowAvatar(card)
	local function avatar()
		task.wait(1.2)
		CardUI.ShowAvatar(card)
	end
	player.CharacterAppearanceLoaded:Connect(function() task.spawn(avatar) end)
	if player.Character then task.spawn(avatar) end

	for _, attribute in ipairs({ "OVR", "Position", "Season", "Cosmetics", "PAC", "SHO", "PAS", "DRI", "DEF", "PHY" }) do
		player:GetAttributeChangedSignal(attribute):Connect(CardUI.Refresh)
	end
	CardUI.Refresh()

	local start = os.clock()
	RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		for view in pairs(animated) do
			if view.Frame.Parent then view:Animate(t) else animated[view] = nil end
		end
	end)
	return card
end

return CardUI
