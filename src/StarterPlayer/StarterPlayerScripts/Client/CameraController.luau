--!nonstrict
-- Scriptable camera that locks onto the sword while pulling. Same framing math
-- as the legacy code; centralised here instead of being tangled into the
-- minigame script.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CameraController = {}
local renderConn: RBXScriptConnection?

local function getCamLock(): BasePart
	local rock = workspace:WaitForChild("SwordRock")
	local sword = rock:WaitForChild("King's Sword")
	local handle = sword:WaitForChild("Handle")
	return handle:WaitForChild("CamLock")
end

local function lock()
	local camLock = getCamLock()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CameraSubject = nil
	if renderConn then
		renderConn:Disconnect()
	end
	renderConn = RunService.RenderStepped:Connect(function()
		local goalPos = camLock.Position + Vector3.new(0, 5, 10)
		camera.CFrame = CFrame.lookAt(goalPos, camLock.Position)
	end)
end

local function reset()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	camera.CameraType = Enum.CameraType.Custom
	local char = player.Character or player.CharacterAdded:Wait()
	camera.CameraSubject = char:FindFirstChildOfClass("Humanoid")
end

function CameraController.start()
	Net.event("LockCamera").OnClientEvent:Connect(lock)
	Net.event("ResetCamera").OnClientEvent:Connect(reset)
end

return CameraController
