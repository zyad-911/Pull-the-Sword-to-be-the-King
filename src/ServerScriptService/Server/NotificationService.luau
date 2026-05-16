--!nonstrict
-- Server -> client toast helper. Replaces the deprecated player:SendNotification
-- API the old admin script used.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Log = require(Shared.Util.Log)

local log = Log.new("Notification")

local NotificationService = {}

function NotificationService.send(player: Player, title: string, text: string)
	Net.event("SendNotification"):FireClient(player, { Title = title, Text = text })
end

function NotificationService.start()
	log:info("started")
end

return NotificationService
