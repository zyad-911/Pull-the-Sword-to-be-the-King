--!nonstrict
-- Proximity prompt + click-to-enter, and the world restore when the server
-- says the pull is over. (Was StartHandler.client.lua.) Resolves UI by
-- PlayerGui path instead of relying on script.Parent.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local MusicController = require(script.Parent.MusicController)

local player = Players.LocalPlayer

-- Platform-aware billboard prompt. Touch devices see "Tap to Start" instead
-- of "Click to Start" -- entering still requires hitting the sword's
-- ClickDetector, but mobile players speak "tap", not "click". The "not
-- MouseEnabled" guard treats hybrid Surface-style devices as PC.
local isTouchDevice = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local START_PROMPT = isTouchDevice and "Tap to Start" or "Click to Start"

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

	textLabel.Text = START_PROMPT

	-- ====================================================================
	-- Proximity Highlight setup.
	-- ====================================================================
	-- Roblox has a SILENT-FAILURE quirk: when multiple Highlights share the
	-- same Adornee, only the FIRST is visible (others are silently dropped).
	-- PullingController also creates FreezeHighlight + WarningHighlight on
	-- the sword Model, so just trusting the workspace-template Highlight
	-- isn't enough -- either a stale leftover or one of the freeze siblings
	-- could be claiming the render slot.
	--
	-- Belt-and-braces fix:
	--   1) Destroy ALL Highlight instances under the sword (handles
	--      duplicates / renamed leftovers, not just the "Highlight" name).
	--   2) Recreate from Instance.new so every property is known-good.
	--   3) Adornee = sword (Model) so the WHOLE sword glows, not just one
	--      part -- matches what players expect when approaching.
	--   4) Re-force the critical properties every RenderStepped frame as a
	--      safety net in case anything ever clobbers them.
	for _, child in sword:GetChildren() do
		if child:IsA("Highlight") then
			child:Destroy()
		end
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "Highlight"
	highlight.Adornee = sword
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.35 -- more opaque than before so the glow really pops
	highlight.OutlineTransparency = 0
	highlight.Enabled = false -- the RenderStepped loop turns it on near the sword
	highlight.Parent = sword

	-- Cache the visible-state target colors so the per-frame safety net
	-- doesn't allocate Color3 / number objects on every tick.
	local HIGHLIGHT_FILL = Color3.fromRGB(255, 255, 255)
	local HIGHLIGHT_OUTLINE = Color3.fromRGB(255, 255, 255)
	local HIGHLIGHT_FILL_T = 0.35
	local HIGHLIGHT_OUTLINE_T = 0

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
		-- Safety net: re-force the visible properties every frame. If
		-- ANYTHING (a stray script, a Roblox quirk, a saved-template
		-- value bleeding in) ever overrides them, this puts them back
		-- before the next render. The cost is two scalar writes + two
		-- Color3 assignments per frame -- microscopic next to the
		-- RenderStepped loop itself.
		if near then
			highlight.Adornee = sword
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.FillColor = HIGHLIGHT_FILL
			highlight.OutlineColor = HIGHLIGHT_OUTLINE
			highlight.FillTransparency = HIGHLIGHT_FILL_T
			highlight.OutlineTransparency = HIGHLIGHT_OUTLINE_T
		end
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
