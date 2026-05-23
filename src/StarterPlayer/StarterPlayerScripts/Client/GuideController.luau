--!nonstrict
-- ============================================================================
-- GuideController -- onboarding for new players.
-- ============================================================================
--
--   1) Glowing BEAM from the player's character to the sword. Hidden when the
--      player is close OR already pulling. Helps them find the sword on a big
--      map and gives newcomers an obvious goal.
--   2) One-time WELCOME banner (Main.Welcome.Label) that fades in, holds, and
--      fades out, telling them what to do.
--
-- Everything is OPTIONAL UI -- if Main.Welcome.Label doesn't exist the welcome
-- step silently skips, and if the sword/character isn't loaded the beam
-- silently waits. Both are pure client-side cosmetic helpers.
--
-- Configure in GameConfig:
--   * GameConfig.WelcomeMessage     - the banner text ("" disables)
--   * GameConfig.GuideBeamTextureId - your beam image (rbxassetid://...)
--   * GameConfig.GuideBeamColor     - solid colour the beam tints toward
-- ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local SwordInteractionController = require(script.Parent.SwordInteractionController)

local player = Players.LocalPlayer

local GuideController = {}

local UI_WAIT_TIMEOUT = 5

-- Welcome banner timings.
local WELCOME_FADE_IN = 0.5
local WELCOME_HOLD = 6
local WELCOME_FADE_OUT = 0.7

-- Hard cap on how long we wait for the LoadingScreen to disappear before
-- giving up and showing the welcome anyway. Belt-and-braces: if something
-- ever breaks the LoadingScreenHandler the player still gets the banner.
local LOADING_WAIT_TIMEOUT = 30

-- =====================================================================
-- Wait for the LoadingScreen to fully disappear.
-- =====================================================================
-- LoadingScreenHandler (ReplicatedFirst) clones a ScreenGui named
-- "LoadingScreen" into PlayerGui and Destroys it when preloading is done.
-- Anything we'd otherwise show during preload (welcome banner, guide beam)
-- is invisible behind the loading screen anyway -- worse, the welcome
-- banner's fade-in would burn through its hold timer WHILE the player is
-- still staring at the loading screen, so by the time the game appears
-- the banner is already half gone. We block on the LoadingScreen leaving
-- PlayerGui first, then continue.
local function waitForLoadingScreenGone()
	local playerGui = player:WaitForChild("PlayerGui")
	local loadingScreen = playerGui:FindFirstChild("LoadingScreen")
	if not loadingScreen then
		-- Either the loading screen already finished, or this place doesn't
		-- have one. Either way, nothing to wait on.
		return
	end

	-- Race-safe wait: AncestryChanged + a timeout poll. AncestryChanged fires
	-- when the ScreenGui is Destroyed (parent becomes nil), so this returns
	-- the moment LoadingScreenHandler kills it.
	local done = false
	local conn
	conn = loadingScreen.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			done = true
			if conn then conn:Disconnect() end
		end
	end)

	local elapsed = 0
	while not done and elapsed < LOADING_WAIT_TIMEOUT do
		task.wait(0.1)
		elapsed += 0.1
		-- Belt-and-braces: if something destroyed the screen without
		-- AncestryChanged firing on our captured reference, the playerGui
		-- check still notices.
		if not playerGui:FindFirstChild("LoadingScreen") then
			done = true
		end
	end
	if conn then conn:Disconnect() end
end

-- Beam visuals (purely cosmetic).
local BEAM_WIDTH_PLAYER = 2     -- width at the player end (wider, the "tail")
local BEAM_WIDTH_SWORD = 1      -- width at the sword end (narrows to a point)
local BEAM_TEXTURE_LENGTH = 4
local BEAM_TEXTURE_SPEED = -1.5   -- negative = scrolls TOWARD the sword
local BEAM_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.15),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 0.15),
})
local BEAM_HIDE_MARGIN = 2 -- hide when within InteractionDistance + this

-- =====================================================================
-- Welcome banner -- shown once per join (per controller.start()).
-- =====================================================================

local function showWelcome()
	local playerGui = player:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main", UI_WAIT_TIMEOUT)
	if not main then return end

	local frame = main:FindFirstChild("Welcome")
	if not frame then return end
	local label = frame:FindFirstChild("Label")
	if not label or not label:IsA("TextLabel") then return end

	local message = GameConfig.WelcomeMessage or ""
	if message == "" then return end
	label.Text = message

	-- Save the user-set transparencies so we can restore them after fade-out
	-- (if you styled the label with a custom transparency in Studio, it's not
	-- clobbered).
	local originalText = label.TextTransparency
	local originalStroke = label.TextStrokeTransparency

	frame.Visible = true
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1

	TweenService:Create(
		label,
		TweenInfo.new(WELCOME_FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			TextTransparency = originalText,
			TextStrokeTransparency = originalStroke,
		}
	):Play()

	task.delay(WELCOME_FADE_IN + WELCOME_HOLD, function()
		local fadeOut = TweenService:Create(
			label,
			TweenInfo.new(WELCOME_FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			frame.Visible = false
			label.TextTransparency = originalText
			label.TextStrokeTransparency = originalStroke
		end)
	end)
end

-- =====================================================================
-- Guide beam -- character <-> sword, auto-hidden when close or pulling.
-- =====================================================================

local function setupBeam()
	local rock = workspace:WaitForChild("SwordRock", 10)
	if not rock then return end
	local sword = rock:WaitForChild("King's Sword", 10)
	if not sword then return end
	local handle = sword:WaitForChild("Handle", 10)
	if not handle then return end
	local camLock = handle:WaitForChild("CamLock", 10)
	if not camLock then return end

	-- Sword-side attachment is persistent (reused every respawn). Anchored
	-- directly to THE ROCK (not the sword/CamLock) and placed at the rock's
	-- BASE in WORLD space, so the beam runs along the floor regardless of
	-- the rock's or CamLock's orientation. SwordRock can be a BasePart
	-- (MeshPart) OR a Model -- we resolve to a usable BasePart either way.
	local rockPart: BasePart? = nil
	if rock:IsA("BasePart") then
		rockPart = rock
	elseif rock:IsA("Model") then
		rockPart = rock.PrimaryPart or rock:FindFirstChildWhichIsA("BasePart")
	end
	if not rockPart then return end -- nothing to anchor to

	local swordAtt = rockPart:FindFirstChild("GuideBeamSwordAtt")
	if not swordAtt then
		swordAtt = Instance.new("Attachment")
		swordAtt.Name = "GuideBeamSwordAtt"
		swordAtt.Parent = rockPart
	end
	-- WorldPosition is absolute, so rock rotation never tilts the attachment
	-- off the ground. Bottom-centre of the rock = ground level.
	swordAtt.WorldPosition = Vector3.new(
		rockPart.Position.X,
		rockPart.Position.Y - rockPart.Size.Y / 2,
		rockPart.Position.Z
	)

	local charAtt: Attachment? = nil
	local beam: Beam? = nil

	local function destroyBeam()
		if beam then beam:Destroy(); beam = nil end
		if charAtt then charAtt:Destroy(); charAtt = nil end
	end

	local function buildBeamFor(char: Model)
		destroyBeam()
		local root = char:WaitForChild("HumanoidRootPart", 5)
		if not root then return end

		charAtt = Instance.new("Attachment")
		charAtt.Name = "GuideBeamCharAtt"
		-- Anchored at the character's FEET (below HRP centre) so the beam runs
		-- along the ground instead of hovering above the player's head.
		charAtt.Position = Vector3.new(0, -(root.Size.Y / 2) - 1, 0)
		charAtt.Parent = root

		beam = Instance.new("Beam")
		beam.Name = "GuideBeam"
		beam.Attachment0 = swordAtt
		beam.Attachment1 = charAtt
		beam.Width0 = BEAM_WIDTH_SWORD
		beam.Width1 = BEAM_WIDTH_PLAYER
		beam.Color = ColorSequence.new(GameConfig.GuideBeamColor)
		beam.Transparency = BEAM_TRANSPARENCY
		beam.LightEmission = 0.5
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.TextureLength = BEAM_TEXTURE_LENGTH
		beam.TextureSpeed = BEAM_TEXTURE_SPEED
		beam.TextureMode = Enum.TextureMode.Wrap
		if GameConfig.GuideBeamTextureId and GameConfig.GuideBeamTextureId ~= "" then
			beam.Texture = GameConfig.GuideBeamTextureId
		end
		beam.Enabled = false -- visibility loop turns it on as needed
		beam.Parent = root
	end

	if player.Character then
		buildBeamFor(player.Character)
	end
	player.CharacterAdded:Connect(buildBeamFor)

	-- Visibility loop -- hide when near the sword OR while in pulling mode.
	local hideRadius = GameConfig.InteractionDistance + BEAM_HIDE_MARGIN
	RunService.RenderStepped:Connect(function()
		-- `beam.Parent` is nil for an already-destroyed instance (e.g. brief
		-- window between character-removed and the next CharacterAdded). Bail
		-- to avoid setting properties on a dead instance.
		if not beam or not beam.Parent then return end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			beam.Enabled = false
			return
		end
		local nearSword = (root.Position - camLock.Position).Magnitude <= hideRadius
		beam.Enabled = not nearSword and not SwordInteractionController.isInPullingMode()
	end)
end

function GuideController.start()
	-- Don't show ANY onboarding UI / world FX until the loading screen is
	-- gone. The welcome banner in particular would burn its hold timer
	-- behind the loading screen and be half-faded by the time the player
	-- actually sees the game.
	task.spawn(function()
		waitForLoadingScreenGone()
		task.spawn(showWelcome)
		task.spawn(setupBeam)
	end)
end

return GuideController
