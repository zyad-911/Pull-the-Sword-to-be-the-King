--!nonstrict
-- ============================================================================
-- LoadingScreenHandler -- simple custom loading screen.
-- ============================================================================
--
-- One TextLabel (the AssetText already positioned at the bottom of the screen
-- in Studio) animates between "Loading", "Loading.", "Loading..", "Loading..."
-- while assets preload in the background. No asset names, no progress bar,
-- no "Complete!" stinger -- the whole screen just disappears the moment
-- preload finishes.
--
-- The template lives in ReplicatedFirst.LoadingScreen and is cloned in here.
-- We trust the Studio layout (position / font / colour / size are NOT touched
-- here -- whatever you set on the AssetText label in Studio is what shows up).
-- ============================================================================

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
-- Make sure the loading screen draws on top of everything else (Main, SwordUI,
-- the welcome banner, etc.) so nothing peeks through before it disappears.
loadingScreen.DisplayOrder = 1000
loadingScreen.Parent = playerGui

-- Resolve the label we'll animate. Prefer the AssetText label (your bottom-of-
-- screen Studio label); fall back to ANY TextLabel inside the screen so this
-- never silently does nothing if the template is renamed later. Any extra
-- TextLabels are hidden so the screen stays clean.
--
-- (Aside on the previous bug: `:FindFirstAncestor("LoadingFrame")` walks UP
-- the tree from the ScreenGui -- which only has PlayerGui / Player / Players
-- as ancestors -- so it always returned nil, and the chained :FindFirstChild
-- crashed the script before any label could be found. We use a descendant
-- walk here instead, which works no matter how the template is nested.)
local loadingText: TextLabel? = nil
local fallback: TextLabel? = nil
for _, descendant in loadingScreen:GetDescendants() do
	if descendant:IsA("TextLabel") then
		if descendant.Name == "AssetText" and loadingText == nil then
			loadingText = descendant
		elseif fallback == nil then
			fallback = descendant
		else
			descendant.Visible = false
		end
	end
end
if loadingText == nil then
	loadingText = fallback
elseif fallback ~= nil then
	-- We found the preferred AssetText, so hide the other TextLabel(s) too.
	fallback.Visible = false
end

if loadingText then
	loadingText.Text = "Loading"
else
	warn("[LoadingScreen] no TextLabel found inside the LoadingScreen template")
end

local isLoading = true

-- Animated dots: cycles 0 -> 1 -> 2 -> 3 -> 0 ... every 0.4s while loading.
-- This is the ONLY writer for loadingText.Text so it can't get clobbered.
task.spawn(function()
	local dots = 0
	while isLoading do
		if loadingText then
			loadingText.Text = "Loading" .. string.rep(".", dots)
		end
		dots += 1
		if dots > 3 then
			dots = 0
		end
		task.wait(0.4)
	end
end)

-- Preload every asset already in the DataModel. Wrapped in pcall so a single
-- bad asset (missing texture id, etc.) can't abort the whole loading flow.
-- We deliberately do NOT write the asset name to the label here -- it would
-- race the dots animation above and make the bottom text strobe nonsense.
local assets = game:GetDescendants()
for _, asset in assets do
	pcall(function()
		ContentProvider:PreloadAsync({ asset })
	end)
end

-- Done. Kill the animation loop and the screen in one go -- no "Complete!"
-- stinger, the game just appears.
isLoading = false
loadingScreen:Destroy()
