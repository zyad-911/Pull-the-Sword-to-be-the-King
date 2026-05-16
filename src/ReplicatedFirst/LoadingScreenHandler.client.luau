--!nonstrict
-- Modernised loading screen. The LoadingScreen ScreenGui asset still lives in
-- the published place; this looks for it under ReplicatedFirst first (the
-- recommended modular home) and falls back to a child of this script so it
-- keeps working during migration.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local template = ReplicatedFirst:FindFirstChild("LoadingScreen") or script:FindFirstChild("LoadingScreen")
if not template then
	warn("[LoadingScreen] no LoadingScreen ScreenGui found; skipping")
	return
end

local loadingScreen = template:Clone()
loadingScreen.Parent = playerGui

local frame = loadingScreen:WaitForChild("Frame")
local loadingText = frame:WaitForChild("TextLabel")
local bar = frame:WaitForChild("LoadingBar"):WaitForChild("Bar")

local assets = game:GetChildren()
local total = #assets

for index, asset in assets do
	loadingText.Text = `Loading {asset.Name}...`
	pcall(function()
		ContentProvider:PreloadAsync({ asset })
	end)
	bar.Size = UDim2.new(index / total, 0, 1, 0)
end

loadingText.Text = "LOADING COMPLETE!"
bar.Size = UDim2.new(1, 0, 1, 0)

task.wait(2)
loadingScreen:Destroy()
