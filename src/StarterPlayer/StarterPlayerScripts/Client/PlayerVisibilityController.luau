--!nonstrict
-- Hides/shows other players while someone is pulling (server tells us who).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local PlayerVisibilityController = {}

local function setVisible(targetPlayer: Player, visible: boolean)
	local char = targetPlayer.Character
	if not char then
		return
	end
	for _, part in char:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = visible and 0 or 1
		end
	end
end

function PlayerVisibilityController.start()
	Net.event("HidePlayersFor").OnClientEvent:Connect(function(namesToHide)
		namesToHide = namesToHide or {}
		if #namesToHide == 0 then
			for _, p in Players:GetPlayers() do
				setVisible(p, true)
			end
			return
		end
		local hidden = {}
		for _, name in namesToHide do
			hidden[name] = true
		end
		for _, p in Players:GetPlayers() do
			setVisible(p, not hidden[p.Name])
		end
	end)
end

return PlayerVisibilityController
