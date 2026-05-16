--!nonstrict
-- leaderstats.Minutes accrual with VIP boost. Minutes persist through
-- DataService; the OrderedDataStore mirror feeds the in-game leaderboard.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mon = require(Shared.Config.MonetizationConfig)
local Log = require(Shared.Util.Log)
local DataService = require(script.Parent.DataService)

local log = Log.new("Leaderstats")
local MinutesOrdered = DataStoreService:GetOrderedDataStore("PlayerMinutes")

local LeaderstatsService = {}

local function waitForProfile(player: Player)
	for _ = 1, 600 do
		local profile = DataService.get(player)
		if profile then
			return profile
		end
		if not player.Parent then
			return nil
		end
		task.wait(0.1)
	end
	return nil
end

local function setup(player: Player)
	local profile = waitForProfile(player)
	if not profile then
		log:warn(`no profile for {player.Name}; skipping leaderstats`)
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local minutes = Instance.new("NumberValue")
	minutes.Name = "Minutes"
	minutes.Value = profile.minutes
	minutes.Parent = leaderstats

	minutes.Changed:Connect(function(value)
		DataService.update(player, function(p)
			p.minutes = value
		end)
	end)

	local increment = Mon.MinutesPerInterval
	if Mon.VipBoostEnabled then
		local hasPass = false
		if Mon.Gamepasses.VIP and Mon.Gamepasses.VIP > 0 then
			pcall(function()
				hasPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, Mon.Gamepasses.VIP)
			end)
		end
		if hasPass or table.find(Mon.VipWhitelist, player.Name) then
			increment = Mon.MinutesPerInterval * Mon.VipMinutesMultiplier
		end
	end

	task.spawn(function()
		while player.Parent do
			task.wait(Mon.MinutesIntervalSeconds)
			if not player.Parent then
				break
			end
			minutes.Value += increment
			pcall(function()
				MinutesOrdered:SetAsync(tostring(player.UserId), math.floor(minutes.Value))
			end)
		end
	end)
end

function LeaderstatsService.start()
	Players.PlayerAdded:Connect(setup)
	for _, p in Players:GetPlayers() do
		task.spawn(setup, p)
	end
	log:info("started")
end

return LeaderstatsService
