--!nonstrict
-- Proximity prompt + click-to-enter, and the world restore when the server
-- says the pull is over. (Was StartHandler.client.lua.) Resolves UI by
-- PlayerGui path instead of relying on script.Parent.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local MusicController = require(script.Parent.MusicController)

local player = Players.LocalPlayer

local SwordInteractionController = {}
local inPullingMode = false

function SwordInteractionController.isInPullingMode(): boolean
	return inPullingMode
end

function SwordInteractionController.start()
	local playerGui = player:WaitForChild("PlayerGui")
	local swordUI = playerGui:WaitForChild("SwordUI")
	local mainUI = playerGui:WaitForChild("Main")

	local rock = workspace:WaitForChild("SwordRock")
	local sword = rock:WaitForChild("King's Sword")
	local handle = sword:WaitForChild("Handle")
	local camLock = handle:WaitForChild("CamLock")
	local clickDetector = sword:WaitForChild("ClickDetector")
	local highlight = sword:WaitForChild("Highlight")
	local billboard = rock:WaitForChild("BillboardGui")
	local textLabel = billboard:WaitForChild("TextLabel")

	textLabel.Text = "Click to Start"

	RunService.RenderStepped:Connect(function()
		if inPullingMode then
			highlight.Enabled = false
			billboard.Enabled = false
			return
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local near = (root.Position - camLock.Position).Magnitude <= GameConfig.InteractionDistance
		highlight.Enabled = near
		billboard.Enabled = near
	end)

	local function enter()
		if inPullingMode then
			return
		end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		if (root.Position - camLock.Position).Magnitude > GameConfig.InteractionDistance then
			return
		end

		inPullingMode = true
		Net.event("StartPulling"):FireServer()
		swordUI.Enabled = true
		mainUI.Enabled = false
		root.Anchored = true
		MusicController.setPulling(true)
		billboard.Enabled = false
		highlight.Enabled = false
	end

	clickDetector.MouseClick:Connect(function(clicked)
		if clicked == player then
			enter()
		end
	end)

	Net.event("LeavePulling").OnClientEvent:Connect(function()
		inPullingMode = false
		swordUI.Enabled = false
		mainUI.Enabled = true
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = false
		end
		MusicController.setPulling(false)
		billboard.Enabled = true
	end)
end

return SwordInteractionController
