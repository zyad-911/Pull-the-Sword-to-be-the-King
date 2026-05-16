--!nonstrict
-- Fastest-pull leaderboard. The original handler was placed *after* an infinite
-- loop in the legacy script and therefore never ran at all -- this restores it,
-- driven by the server-validated pull duration.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)

local log = Log.new("Leaderboard")
local FastestPullStore = DataStoreService:GetOrderedDataStore("FastestPullTimes")

local LeaderboardService = {}

-- Called by PullingService with the server-measured duration (seconds).
-- OrderedDataStore requires integers, so we store milliseconds.
function LeaderboardService.submitPull(player: Player, seconds: number)
	if type(seconds) ~= "number" or seconds <= 0 then
		return
	end
	local key = tostring(player.UserId)
	local ms = math.floor(seconds * 1000)

	task.spawn(function()
		local ok, best = pcall(function()
			return FastestPullStore:GetAsync(key)
		end)
		if not ok then
			log:warn(`failed reading fastest pull for {player.Name}`)
			return
		end
		if not best or ms < best then
			local okSet = pcall(function()
				FastestPullStore:SetAsync(key, ms)
			end)
			if okSet then
				log:info(`{player.Name} new fastest pull: {string.format("%.3f", seconds)}s`)
			else
				log:warn(`failed saving fastest pull for {player.Name}`)
			end
		end
	end)
end

function LeaderboardService.start()
	log:info("started")
end

return LeaderboardService
