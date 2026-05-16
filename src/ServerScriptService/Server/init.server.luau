--!nonstrict
-- Server entry point. Creates every remote up-front, then starts each service
-- in dependency order (data first, everything that reads it after).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Log = require(Shared.Util.Log)

local log = Log.new("Server")

Net.init()

local services = {
	require(script.DataService),
	require(script.NotificationService),
	require(script.LeaderstatsService),
	require(script.LeaderboardService),
	require(script.MonetizationService),
	require(script.PullingService),
	require(script.AdminService),
	require(script.AmbianceService),
}

for _, service in services do
	local ok, err = pcall(service.start)
	if not ok then
		log:warn(`a service failed to start: {tostring(err)}`)
	end
end

log:info("all services started")
