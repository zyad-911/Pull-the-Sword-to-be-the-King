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
	local billboard = rock:WaitForChild("BillboardGui")
	local textLabel = billboard:WaitForChild("TextLabel")

	textLabel.Text = "Click to Start"

	-- DESTROY the workspace Highlight and rebuild from scratch. The previous
	-- approach (find + override properties) wasn't enough -- something about
	-- the Studio-saved instance was poisoning it (probably an unset Adornee,
	-- FillTransparency = 1, or a leftover property the override missed).
	-- Recreating it in code means EVERY property is known-good, and we
	-- avoid the silent-failure trap that Highlights are prone to. The
	-- BillboardGui has no such pitfall because it just draws its children
	-- regardless -- which is why the billboard "works" and the highlight
	-- didn't.
	--
	-- Adornee = handle (a BasePart), NOT sword (the Model). Adorning to a
	-- specific BasePart is the most reliable form in Roblox and dodges any
	-- subtle Model-level rendering quirks. Visually it still glows over the
	-- whole handle, which is what the player actually sees sticking out of
	-- the rock.
	local oldHighlight = sword:FindFirstChild("Highlight")
	if oldHighlight then
		oldHighlight:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "Highlight"
	highlight.Adornee = handle
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.Enabled = false -- the RenderStepped loop turns it on near the sword
	highlight.Parent = sword

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
