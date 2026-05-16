--!nonstrict
-- Day/night clock + day/night music (was ForestMusic.server.lua). The tree-sway
-- ServerScripts documented in docs/Map.md live on map instances and are out of
-- scope for this code rewrite.

local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)

local log = Log.new("Ambiance")

local DAY_LENGTH_SECONDS = 15 * 60
local FULL_DAY = 24

local AmbianceService = {}

function AmbianceService.start()
	local dayMusic = SoundService:WaitForChild("DayMusic")
	local nightMusic = SoundService:WaitForChild("NightMusic")
	local increment = FULL_DAY / DAY_LENGTH_SECONDS

	task.spawn(function()
		while true do
			task.wait(1)
			Lighting.ClockTime = (Lighting.ClockTime + increment) % 24

			local t = Lighting.ClockTime
			local isDay = t >= 6 and t < 18
			if isDay then
				if not dayMusic.IsPlaying then
					nightMusic:Stop()
					dayMusic:Play()
				end
			else
				if not nightMusic.IsPlaying then
					dayMusic:Stop()
					nightMusic:Play()
				end
			end
		end
	end)

	log:info("started")
end

return AmbianceService
