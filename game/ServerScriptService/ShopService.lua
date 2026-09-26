-- Gamepasses and developer products. Fair by design: nothing here gives a
-- LEGEND card or a season; the stat point stops at 84.
--
-- Ids of 0 mean "coming soon" in a live game. In Studio they are free so
-- everything can be tested.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("FootballConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local StatService = require(script.Parent:WaitForChild("StatService"))
local RewardService = require(script.Parent:WaitForChild("RewardService"))

local ShopService = {}

local Notify
local pendingStat = {} -- player -> the stat chosen before buying a stat point

local function setPass(player, key, owned)
	player:SetAttribute("Pass_" .. key, owned == true)
	if owned and key == "Cosmetics" then RewardService.UnlockPack(player) end
	if owned then StatService.Sync(player) end
end

-- Checks every gamepass for a player who just joined.
function ShopService.CheckPasses(player)
	for key, pass in pairs(Config.Gamepasses) do
		local owned = false
		if pass.Id ~= 0 then
			local ok, result = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id) end)
			owned = ok and result == true
		end
		setPass(player, key, owned)
	end
end

local function grant(player, key)
	local data = DataService.Get(player)
	local product = Config.Products[key]
	if not (data and product) then return false end
	if key == "Boost15" then
		data.Boost = math.max(data.Boost, os.time()) + product.Minutes * 60
		Notify:FireClient(player, ("2x XP for %d more minutes!"):format(product.Minutes), "gold")
		StatService.Sync(player)
	elseif key == "StatPoint" then
		local stat = pendingStat[player]
		if not (stat and data.Stats[stat] and data.Stats[stat] < product.MaxLevel) then
			-- the lowest stat that can still take it
			stat = nil
			for _, s in ipairs(Config.StatOrder) do
				if data.Stats[s] < product.MaxLevel and (not stat or data.Stats[s] < data.Stats[stat]) then stat = s end
			end
		end
		if stat then
			StatService.AddLevel(player, stat, 1, product.MaxLevel)
			Notify:FireClient(player, ("+1 %s!"):format(stat), "gold")
		else
			-- nothing below 85: give XP to the lowest stat instead
			local low = Config.StatOrder[1]
			for _, s in ipairs(Config.StatOrder) do if data.Stats[s] < data.Stats[low] then low = s end end
			StatService.AddXP(player, low, Config.XPToNext(data.Stats[low]), 1, true)
			Notify:FireClient(player, ("Your stats are too high for a point: +XP to %s instead!"):format(low), "gold")
		end
	end
	DataService.MarkDirty(player)
	return true
end

function ShopService.BuyPass(player, key)
	local pass = Config.Gamepasses[key]
	if not pass then return false, "Unknown pass." end
	if player:GetAttribute("Pass_" .. key) then return false, "You already own this!" end
	if pass.Id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		return true
	end
	if RunService:IsStudio() then
		setPass(player, key, true)
		return true, "Studio test: " .. pass.Name .. " is yours (free in Studio)."
	end
	return false, pass.Name .. " is coming soon!"
end

function ShopService.BuyProduct(player, key, stat)
	local product = Config.Products[key]
	if not product then return false, "Unknown item." end
	if key == "StatPoint" then
		if type(stat) ~= "string" or not Config.Stats[stat] then return false, "Pick a stat first." end
		local data = DataService.Get(player)
		if data and data.Stats[stat] >= product.MaxLevel then
			return false, ("Stat points only work up to %d."):format(product.MaxLevel)
		end
		pendingStat[player] = stat
	end
	if product.ProductId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.ProductId)
		return true
	end
	if RunService:IsStudio() then
		grant(player, key)
		return true, "Studio test: free."
	end
	return false, product.Name .. " is coming soon!"
end

function ShopService.Init(remotes)
	Notify = remotes.Notify
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		if not bought then return end
		for key, pass in pairs(Config.Gamepasses) do
			if pass.Id == passId then
				setPass(player, key, true)
				local data = DataService.Get(player)
				if data then data.RobuxSpent += pass.Price end
				Notify:FireClient(player, "Thanks! " .. pass.Name .. " is yours!", "gold")
			end
		end
	end)
	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local data = DataService.Get(player)
		if not data then return Enum.ProductPurchaseDecision.NotProcessedYet end
		if data.Receipts[info.PurchaseId] then return Enum.ProductPurchaseDecision.PurchaseGranted end
		for key, product in pairs(Config.Products) do
			if product.ProductId == info.ProductId then
				if not grant(player, key) then return Enum.ProductPurchaseDecision.NotProcessedYet end
				data.Receipts[info.PurchaseId] = os.time()
				data.RobuxSpent += info.CurrencySpent or product.Price
				if not DataService.Save(player) and DataService.CanSave(player) then
					return Enum.ProductPurchaseDecision.NotProcessedYet
				end
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Players.PlayerRemoving:Connect(function(player) pendingStat[player] = nil end)
end

return ShopService
