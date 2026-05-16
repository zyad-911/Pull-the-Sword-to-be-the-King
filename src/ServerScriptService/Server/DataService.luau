--!nonstrict
-- Owns every player's persistent profile (minutes + paid inventory) and keeps
-- the legacy mirror Value objects (RevivesLeft / HasX2Click) in sync so the
-- existing UI keeps working. Fixes the original money-losing bug where
-- Robux-purchased autoclickers/revives lived only in memory.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)
local DataStoreWrapper = require(script.Parent.DataStoreWrapper)

local log = Log.new("DataService")

-- Keep the legacy store/key shape so existing live player minutes are NOT lost.
local MinutesStore = DataStoreService:GetDataStore("MinutesStats")
-- New store for items that were previously never persisted.
local InventoryStore = DataStoreService:GetDataStore("PlayerInventory_v1")

local DataService = {}

local profiles: { [Player]: any } = {}

local function defaultProfile()
	return {
		minutes = 0,
		revives = 0,
		autoClickers = {}, -- [10] = n, [20] = n
		hasX2Click = false,
	}
end

local function ensureMirrors(player: Player, profile)
	local revives = player:FindFirstChild("RevivesLeft")
	if not revives then
		revives = Instance.new("IntValue")
		revives.Name = "RevivesLeft"
		revives.Parent = player
	end
	revives.Value = profile.revives

	local x2 = player:FindFirstChild("HasX2Click")
	if not x2 then
		x2 = Instance.new("BoolValue")
		x2.Name = "HasX2Click"
		x2.Parent = player
	end
	x2.Value = profile.hasX2Click
end

function DataService.load(player: Player)
	local profile = defaultProfile()

	local okM, minutesData = DataStoreWrapper.get(MinutesStore, tostring(player.UserId))
	if okM and type(minutesData) == "table" and type(minutesData.Minutes) == "number" then
		profile.minutes = minutesData.Minutes
	end

	local okI, inv = DataStoreWrapper.get(InventoryStore, tostring(player.UserId))
	if okI and type(inv) == "table" then
		profile.revives = tonumber(inv.revives) or 0
		profile.hasX2Click = inv.hasX2Click == true
		if type(inv.autoClickers) == "table" then
			for k, v in inv.autoClickers do
				local nk = tonumber(k)
				if nk then
					profile.autoClickers[nk] = tonumber(v) or 0
				end
			end
		end
	end

	profiles[player] = profile
	ensureMirrors(player, profile)
	log:info(`loaded profile for {player.Name}`)
end

function DataService.get(player: Player)
	return profiles[player]
end

function DataService.update(player: Player, mutate: (any) -> ())
	local profile = profiles[player]
	if not profile then
		return
	end
	mutate(profile)
	ensureMirrors(player, profile)
end

function DataService.save(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	DataStoreWrapper.update(MinutesStore, tostring(player.UserId), function()
		return { Minutes = profile.minutes }
	end)
	DataStoreWrapper.update(InventoryStore, tostring(player.UserId), function()
		return {
			revives = profile.revives,
			autoClickers = profile.autoClickers,
			hasX2Click = profile.hasX2Click,
		}
	end)
end

function DataService.start()
	Players.PlayerAdded:Connect(DataService.load)
	for _, p in Players:GetPlayers() do
		task.spawn(DataService.load, p)
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.save(player)
		profiles[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(DataService.save, player)
		end
		task.wait(3)
	end)

	log:info("started")
end

return DataService
