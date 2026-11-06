-- The funnels on the Creator Hub (Analytics > Funnels), to see where players
-- stop. Roblox only takes these from the server of a published game, so
-- nothing is sent from Studio. A step logged twice counts once.
--
--   Onboarding  a player's first time through, from joining to escaping
--   Run         each run, from the cave's mouth to the way out
--   Shop        each visit to the shop: opened, asked to buy, bought. A
--               prompt from anywhere else (the death screen) counts too.
--
-- Practice runs aren't counted: Progress.luau and Parties.luau leave them out.

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Stages)

local SHOP_GAP = 1 -- seconds between a player's shop visits

local RUN_STEPS = { "Left the cave" }
for index in Stages do
	table.insert(RUN_STEPS, ("Stage %d cleared"):format(index))
end
table.insert(RUN_STEPS, "Escaped")

local ONBOARDING_STEPS = { "Joined", "Set off", "In the cave" }
table.move(RUN_STEPS, 1, #RUN_STEPS, #ONBOARDING_STEPS + 1, ONBOARDING_STEPS)

local SHOP_STEPS = { "Opened", "Asked to buy", "Bought" }

local Analytics = {}

local runs = {} -- [player] = the id of their run
local shops = {} -- [player] = the id of their shop visit
local lastOpened = {} -- [player] = os.clock() they last opened the shop

local function log(method, ...)
	if RunService:IsStudio() then
		return
	end
	local ok, problem = pcall(method, AnalyticsService, ...)
	if not ok then
		warn("[Analytics]", problem)
	end
end

local function shopStep(player, step)
	shops[player] = shops[player] or HttpService:GenerateGUID(false)
	log(AnalyticsService.LogFunnelStepEvent, player, "Shop", shops[player], step, SHOP_STEPS[step])
end

local function promptClosed(player, purchased)
	shopStep(player, 2)
	if purchased then
		shopStep(player, 3)
	end
end

-- A player got to a step of ONBOARDING_STEPS, by its name. "Left the cave"
-- starts a new run.
function Analytics.reached(player, name)
	log(AnalyticsService.LogOnboardingFunnelStepEvent, player, table.find(ONBOARDING_STEPS, name), name)
	if name == RUN_STEPS[1] then
		runs[player] = HttpService:GenerateGUID(false)
	end
	local step = table.find(RUN_STEPS, name)
	if step and runs[player] then
		log(AnalyticsService.LogFunnelStepEvent, player, "Run", runs[player], step, name)
	end
end

function Analytics.init()
	Remotes.ShopOpened.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if lastOpened[player] and now - lastOpened[player] < SHOP_GAP then
			return
		end
		lastOpened[player] = now
		shops[player] = nil
		shopStep(player, 1)
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _, purchased)
		promptClosed(player, purchased)
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _, purchased)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			promptClosed(player, purchased)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		runs[player] = nil
		shops[player] = nil
		lastOpened[player] = nil
	end)
end

return Analytics
