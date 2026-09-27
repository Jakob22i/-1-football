-- The star players round the lobby fountain (Config.Stars): Ronaldo, Messi,
-- Bellingham and Neymar Jr.
--
--   buy     walk up to one and press E: it is a gamepass (free in Studio)
--   wear    once you own it, press E again to wear the look (their kit,
--           hair and beard on your own avatar); again to take it off
--   bonus   owning one gives +10% XP in that player's best stat (StatService)
--
-- What you wear is saved (data.Star) and put back on when you respawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))

local StarService = {}

local Notify
local originals = {} -- player -> their own HumanoidDescription

-- A HumanoidDescription in a star's look. With `base` (a player's own
-- description) only the clothes, hair and beard change; without it the
-- whole body is the star's (the statues).
function StarService.Describe(star, base)
	local desc = base and base:Clone() or Instance.new("HumanoidDescription")
	desc.Shirt = star.Shirt or 0
	desc.Pants = star.Pants or 0
	desc.GraphicTShirt = 0
	desc.HairAccessory = table.concat(star.Hair or {}, ",")
	if star.Face or not base then
		desc.FaceAccessory = table.concat(star.Face or {}, ",")
	end
	-- hats would sit on the hair
	desc.HatAccessory = ""
	if not base and star.Skin then
		for _, k in ipairs({ "HeadColor", "LeftArmColor", "RightArmColor", "TorsoColor", "LeftLegColor", "RightLegColor" }) do
			desc[k] = star.Skin
		end
	end
	return desc
end

local function owns(player, key)
	local star = Config.Stars[key]
	return star and player:GetAttribute("Pass_" .. star.Pass) == true
end

-- The player's own look, kept from before they first wear a star.
local function original(player, humanoid)
	if originals[player] then return originals[player] end
	local ok, desc
	if player.UserId > 0 then
		ok, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(player.UserId) end)
	end
	if not (ok and desc) then
		-- a Studio test player: whatever they have on now
		ok, desc = pcall(function() return humanoid:GetAppliedDescription() end)
	end
	if ok and desc then originals[player] = desc end
	return originals[player]
end

-- Dresses the character in the star's look ("" = the player's own look).
local function dress(player, key)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	local base = original(player, humanoid)
	if not base then return false end
	local star = Config.Stars[key]
	local desc = star and StarService.Describe(star, base) or base
	local ok, err = pcall(function() humanoid:ApplyDescription(desc) end)
	if not ok then warn("[Stars] could not dress " .. player.Name .. ":", err) end
	return ok
end

-- The XP bonus for a stat from the stars a player owns (1 = none).
function StarService.Bonus(player, stat)
	local mult = 1
	for key, star in pairs(Config.Stars) do
		if star.Stat == stat and owns(player, key) then mult *= 1 + (star.Bonus or 0) end
	end
	return mult
end

local function onPrompt(player, key)
	local DataService = require(script.Parent:WaitForChild("DataService"))
	local ShopService = require(script.Parent:WaitForChild("ShopService"))
	local star = Config.Stars[key]
	local data = DataService.Get(player)
	if not (star and data) then return end
	if not owns(player, key) then
		local ok, message = ShopService.BuyPass(player, star.Pass)
		if message then Notify:FireClient(player, message, ok and "gold" or "error") end
		return
	end
	-- owned: wear it, or take it off
	local wearing = data.Star == key
	data.Star = wearing and "" or key
	player:SetAttribute("Star", data.Star)
	DataService.MarkDirty(player)
	if dress(player, data.Star) then
		local name = star.Name:sub(1, 1) .. star.Name:sub(2):lower()
		Notify:FireClient(player, wearing and "Back to your own look." or ("You're wearing " .. name .. "'s look!"), "gold")
	end
end

-- After a respawn (or joining): put the saved look back on.
function StarService.CharacterAdded(player)
	local DataService = require(script.Parent:WaitForChild("DataService"))
	local data = DataService.Get(player)
	if not data then return end
	if data.Star ~= "" and not owns(player, data.Star) then data.Star = "" end
	player:SetAttribute("Star", data.Star)
	if data.Star ~= "" then
		if not player:HasAppearanceLoaded() then
			player.CharacterAppearanceLoaded:Wait()
		end
		dress(player, data.Star)
	end
end

function StarService.Init(remotes, prompts)
	Notify = remotes.Notify
	for key, prompt in pairs(prompts or {}) do
		prompt.Triggered:Connect(function(player) onPrompt(player, key) end)
	end
	Players.PlayerRemoving:Connect(function(player) originals[player] = nil end)
end

return StarService
