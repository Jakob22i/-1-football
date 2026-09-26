-- Makes the real Roblox characters the drills use (see PlayerFigure) and
-- keeps them in ReplicatedStorage.FigureRigs, where every client can copy
-- them:
--
--   Kits/Attacker_1 ...        default avatars in each kit's colours
--   Avatars/Avatar_<userId>    every player in the server
--   Friends_<userId>/...       each player's Roblox friends
--
-- Making a character asks Roblox for the avatar, so it all happens in the
-- background; the drills use whatever is ready.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))
local PlayerFigure = require(ReplicatedStorage:WaitForChild("PlayerFigure"))

local RigService = {}

local root, kitsFolder, avatarsFolder
local ready = false
local readyEvent = Instance.new("BindableEvent")

local function folder(parent, name)
	local f = parent:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function fromDescription(desc, name)
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn("[Figures] could not make " .. name .. ":", rig)
		return nil
	end
	rig.Name = name
	rig.Archivable = true
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("BaseScript") then d:Destroy() end
	end
	return rig
end

-- A default Roblox avatar in a kit: shirt-coloured torso, shorts-coloured
-- legs, and one of the skin tones.
local function kitRig(kitName, index)
	local kit = PlayerFigure.Kits[kitName]
	local skins = PlayerFigure.Skins
	local skin = skins[(index * 2 - 1) % #skins + 1]
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = kit.Shirt
	desc.LeftLegColor = kit.Shorts
	desc.RightLegColor = kit.Shorts
	return fromDescription(desc, kitName .. "_" .. index)
end

local function avatarRig(userId)
	local ok, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)
	if not ok or not desc then return nil end
	return fromDescription(desc, "Avatar_" .. userId)
end

local function friendIds(userId)
	local ids = {}
	local max = Config.Figures.FriendsPerPlayer
	local ok, pages = pcall(function() return Players:GetFriendsAsync(userId) end)
	if not ok or not pages then return ids end
	while #ids < max do
		for _, friend in ipairs(pages:GetCurrentPage()) do
			if #ids >= max then break end
			table.insert(ids, friend.Id)
		end
		if pages.IsFinished or #ids >= max then break end
		if not pcall(function() pages:AdvanceToNextPageAsync() end) then break end
	end
	return ids
end

local function onPlayer(player)
	-- a Studio test player (UserId 0 or below) has no avatar or friends
	if player.UserId <= 0 then return end
	task.spawn(function()
		if not avatarsFolder:FindFirstChild("Avatar_" .. player.UserId) then
			local rig = avatarRig(player.UserId)
			if rig then rig.Parent = avatarsFolder end
		end
		local friends = folder(root, "Friends_" .. player.UserId)
		for _, id in ipairs(friendIds(player.UserId)) do
			if not player.Parent then break end
			if not friends:FindFirstChild("Avatar_" .. id) then
				local rig = avatarRig(id)
				if rig then rig.Parent = friends end
			end
		end
	end)
end

function RigService.Init()
	root = folder(ReplicatedStorage, "FigureRigs")
	kitsFolder = folder(root, "Kits")
	avatarsFolder = folder(root, "Avatars")
	task.spawn(function()
		for _, kitName in ipairs({ "Dummy", "Attacker", "Keeper", "Teammate" }) do
			for i = 1, Config.Figures.KitRigs[kitName] or 0 do
				local rig = kitRig(kitName, i)
				if rig then rig.Parent = kitsFolder end
			end
		end
		ready = true
		readyEvent:Fire()
	end)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end
	Players.PlayerRemoving:Connect(function(player)
		local friends = root:FindFirstChild("Friends_" .. player.UserId)
		if friends then friends:Destroy() end
		local avatar = avatarsFolder:FindFirstChild("Avatar_" .. player.UserId)
		if avatar then avatar:Destroy() end
	end)
end

-- Waits (up to `timeout` seconds) until the kit characters are made.
function RigService.WaitReady(timeout)
	if ready then return true end
	local done = false
	local conn = readyEvent.Event:Connect(function() done = true end)
	local start = os.clock()
	while not done and not ready and os.clock() - start < (timeout or 30) do
		task.wait(0.2)
	end
	conn:Disconnect()
	return ready
end

return RigService
