-- Robux purchases (shared/RobuxCatalog.luau; ids in Config.Products and
-- Config.Passes).
--
-- Developer Products: Roblox calls ProcessReceipt for each purchase, perhaps
-- more than once, until it hears the purchase was granted. Each one is
-- written down by its purchase id, so it is only ever granted once, and
-- Progress.grant hands out what it gives.
--
-- Game Passes: who owns which is checked when they join, and again when
-- they buy one here, and marked as Pass_<id> attributes (shared/Perks.luau
-- says what each one does).

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Perks = require(ReplicatedStorage.Shared.Perks)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RobuxCatalog = require(ReplicatedStorage.Shared.RobuxCatalog)
local Progress = require(script.Parent.Progress)

local Purchases = {}

local history -- purchase ids already granted
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName .. "_Purchases")
	end)
	if ok then
		history = result
	else
		warn("[Purchases] Purchases can't be written down:", result)
	end
end

-- The catalog entry for a Developer Product id, if it is one of ours.
local function productFor(productId)
	for name, id in Config.Products do
		if id ~= 0 and id == productId then
			return RobuxCatalog.productById[name]
		end
	end
	return nil
end

local function grant(player, product)
	if not Progress.grant(player, product.gives) then
		return false
	end
	Remotes.Notify:FireClient(player, "bought", "Bought " .. product.name)
	return true
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not Progress.getProfile(player) then
		-- Not here, or not loaded yet: Roblox asks again later.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = productFor(receipt.ProductId)
	if not product then
		warn("[Purchases] No product in Config.Products has id", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not history then
		-- Studio without access to saving: test purchases are free, so give it.
		if RunService:IsStudio() and grant(player, product) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, recorded = pcall(function()
		return history:UpdateAsync(receipt.PlayerId .. "_" .. receipt.PurchaseId, function(granted)
			if granted then
				return true
			end
			local given, result = pcall(grant, player, product)
			if not given or not result then
				warn("[Purchases] Could not grant", product.id, "to", player.Name, result)
				return nil -- not written down, so Roblox tries again
			end
			return true
		end)
	end)
	if ok and recorded then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Marks a pass as owned. Deep Pockets tops up pebbles at once.
local function markPass(player, name)
	player:SetAttribute("Pass_" .. name, true)
	if name == "DeepPockets" then
		player:SetAttribute("Pebbles", math.max(player:GetAttribute("Pebbles") or 0, Perks.pebblesPerLife(player)))
	end
end

local function checkPasses(player)
	for name, id in Config.Passes do
		if id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			if ok and owns and player.Parent then
				markPass(player, name)
			end
		end
	end
end

function Purchases.init()
	MarketplaceService.ProcessReceipt = processReceipt

	Players.PlayerAdded:Connect(checkPasses)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPasses, player)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for name, id in Config.Passes do
			if id ~= 0 and id == passId then
				markPass(player, name)
				Remotes.Notify:FireClient(player, "bought", "Bought " .. RobuxCatalog.passById[name].name)
			end
		end
	end)
end

return Purchases
