--!nonstrict
-- ============================================================================
-- Click-spam minigame UI controller.
-- ============================================================================
--
-- The player clicks (or taps) the 3D sword to push progress up; a continuous
-- decay constantly drags it back down. Reaching 0% after the grace window =
-- fail; reaching 100% = win. The server runs the same math authoritatively
-- and is the only thing allowed to declare king/fail.
--
-- ──────────────────────────────────────────────────────────────────────────
-- TWO-CLICK ENTRY
-- ──────────────────────────────────────────────────────────────────────────
--   * 1st sword click  -> SwordInteractionController.enter() opens the UI and
--                         locks the camera. The game is NOT running yet --
--                         no decay, no scoring. (That click is consumed by
--                         the sword's ClickDetector; InputBegan sees the UI
--                         still disabled and ignores it.)
--   * 2nd sword click  -> startGameFromClick(): the session opens, the decay
--                         starts, and that very click is the first pull.
--   * 3rd+ sword click -> normal pulls.
--
-- ──────────────────────────────────────────────────────────────────────────
-- STOP FALLING
-- ──────────────────────────────────────────────────────────────────────────
--   The paid consumables ("5sStop" / "10sStop" buttons, or the keybinds)
--   FREEZE the decay for 5 or 10 seconds. The player still has to click the
--   sword during the freeze -- it just removes the drain so every click is
--   pure gain. Defined in GameConfig.StopFalling.
--
-- Every tunable lives in GameConfig.luau. Don't put magic numbers in here.
--
-- UI tolerance: every UI part is optional. Delete the Start button, the
-- keyboard-letters row, the 5sStop/10sStop buttons or the SFX and the minigame
-- still works -- the safe* helpers no-op on nil. ONLY required: SwordUI.
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local BladeMetrics = require(Shared.Util.BladeMetrics)

local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local PullingController = {}

local UI_WAIT_TIMEOUT = 2

-- Platform-aware prompt text. Touch devices see "TAP!" / "TAP FASTER!" since
-- we relaxed the input handler to accept any tap on the screen during a pull
-- (the sword shrinks to a tiny target on phones once the camera pulls back).
-- PC users see "CLICK!" / "CLICK FASTER!" -- a mouse cursor is precise enough
-- to keep hitting the sword, and the input handler still requires a sword
-- raycast there. The "not MouseEnabled" guard treats hybrid Surface-style
-- devices (touch + mouse) as PC.
local isTouchDevice = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local PROMPT_CLICK = isTouchDevice and "TAP!" or "CLICK!"
local PROMPT_FASTER = isTouchDevice and "TAP FASTER!" or "CLICK FASTER!"

-- =====================================================================
-- Small lookup helpers.
-- =====================================================================

local function findChild(parent: Instance, name: string): Instance?
	return parent and parent:FindFirstChild(name) or nil
end

local function findDeep(parent: Instance, name: string): Instance?
	return parent and parent:FindFirstChild(name, true) or nil
end

local function safePlay(sound: Sound?)
	if sound then
		sound:Play()
	end
end

local function safeText(label: TextLabel?, text: string)
	if label then
		label.Text = text
	end
end

local function safeVisible(inst: GuiObject?, visible: boolean)
	if inst then
		inst.Visible = visible
	end
end

local function stopSoundsUnder(roots)
	for _, root in roots do
		if not root then continue end
		for _, snd in root:GetDescendants() do
			if snd:IsA("Sound") and snd.IsPlaying then
				snd:Stop()
			end
		end
	end
end

function PullingController.start()
	local playerGui = player:WaitForChild("PlayerGui")
	local swordUI = playerGui:WaitForChild("SwordUI", UI_WAIT_TIMEOUT)
	if not swordUI then
		warn("[Pulling] SwordUI missing; controller disabled")
		return
	end

	-- =====================================================================
	-- UI resolution -- everything optional; safe helpers tolerate nil.
	-- =====================================================================

	local exitButton = findChild(swordUI, "Exit")
	local startButton = findChild(swordUI, "StartButton")
	local keyBox = findChild(swordUI, "KeyBox")
	local keyPrompt = (keyBox and findChild(keyBox, "KeyPrompt")) or nil
	local progressBar = findChild(swordUI, "ProgressBar")
	local fillBar = progressBar and findChild(progressBar, "FillBar") or nil
	local mobileButtons = findChild(swordUI, "MobileButtons")

	local usesContainer = findChild(swordUI, "Uses")
	local usesButtons = usesContainer and findChild(usesContainer, "Buttons") or nil
	local useReviveButton = usesButtons and findChild(usesButtons, "1ReviveUse") or nil

	local revivesGroup = findChild(swordUI, "Revives")
	local reviveCountLabel = revivesGroup and findChild(revivesGroup, "Numper") or nil

	local clickSFX = findDeep(swordUI, "Click")
	local failedSFX = findDeep(swordUI, "Failed")
	local challengeCompleteSFX = findDeep(swordUI, "ChallengeCompleteSFX")

	-- Sword-freeze + warning sounds. Names are matched against several variants
	-- so you can call them "Freeze"/"Freeze Sound" interchangeably and it works.
	-- If a sound is missing, the playback helper silently no-ops.
	local function findSoundByAnyName(...)
		for _, name in {...} do
			local s = swordUI:FindFirstChild(name, true)
			if s and s:IsA("Sound") then return s end
		end
		return nil
	end
	local freezeSFX      = findDeep(swordUI, "Freeze")
	local timerSFX       = findDeep(swordUI, "TimerSFX")
	local freezeBreakSFX = findDeep(swordUI, "FreezeBreak")
	local slipWarningSFX = findDeep(swordUI, "SlipWarning")
	if timerSFX then
		timerSFX.Looped = true -- defensive: ensure the tic-toc actually loops
	end

	-- ParticleEmitter templates that get cloned onto the Blade during a freeze.
	local freezeVfxFolder = nil
	do
		local effects = ReplicatedStorage:FindFirstChild("Effects")
		freezeVfxFolder = effects and effects:FindFirstChild("FreezeVFX") or nil
	end

	if mobileButtons then
		mobileButtons.Visible = false
	end

	-- Stop-Falling consumables, resolved from GameConfig.StopFalling. Each entry
	-- pairs a freeze duration with its SwordUI button and PC keybind.
	local stopProducts = {}    -- array of { seconds, button, keybind }
	local stopCharges = {}     -- [seconds] = owned count
	for _, def in GameConfig.StopFalling do
		stopProducts[#stopProducts + 1] = {
			seconds = def.seconds,
			button = usesButtons and findChild(usesButtons, def.buttonName) or nil,
			keybind = def.keybind,
		}
		stopCharges[def.seconds] = 0
	end

	local function showOwnedStopButtons()
		for _, sp in stopProducts do
			safeVisible(sp.button, (stopCharges[sp.seconds] or 0) > 0)
		end
	end

	local function hideStopButtons()
		for _, sp in stopProducts do
			safeVisible(sp.button, false)
		end
	end

	-- Stops the "Stop Falling" timer SFX (under the stop buttons / Uses group,
	-- plus any looping Sound anywhere under SwordUI) so it can't bleed past the
	-- freeze or the round.
	local function stopFreezeSounds()
		local roots = { usesContainer }
		for _, sp in stopProducts do
			roots[#roots + 1] = sp.button
		end
		stopSoundsUnder(roots)
		for _, snd in swordUI:GetDescendants() do
			if snd:IsA("Sound") and snd.Looped and snd.IsPlaying then
				snd:Stop()
			end
		end
	end

	-- =====================================================================
	-- Sword visuals (welding + raycast filter)
	-- =====================================================================

	local rock = workspace:WaitForChild("SwordRock")
	local sword = rock:WaitForChild("King's Sword")
	local handleFolder = sword:WaitForChild("Handle")
	local neonFolder = sword:WaitForChild("Neon")
	local blade = sword:WaitForChild("Blade")
	local camLock = handleFolder:WaitForChild("CamLock")

	local effects = ReplicatedStorage:WaitForChild("Effects")
	local swordVFX = effects:WaitForChild("RockEffect"):Clone()
	swordVFX.Parent = rock

	sword.PrimaryPart = camLock
	local savedCamLockCFrame = camLock.CFrame
	local savedCamLockPosition = camLock.Position

	-- Walk the WHOLE descendant tree, not just direct children. Some gems in
	-- the Neon folder are nested inside sub-folders / sub-Models -- if we
	-- only welded direct children, those nested gems wouldn't be attached to
	-- camLock, so they'd stay floating in place when the sword rose during
	-- a pull. (Same applies to the Handle folder for symmetry / safety.)
	local function weldParts(folder: Instance)
		for _, part in folder:GetDescendants() do
			if part:IsA("BasePart") and part ~= camLock then
				part.CanCollide = false
				part.Anchored = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = camLock
				weld.Part1 = part
				weld.Parent = camLock
			end
		end
	end
	weldParts(handleFolder)
	weldParts(neonFolder)
	if blade:IsA("BasePart") then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = camLock
		weld.Part1 = blade
		weld.Parent = camLock
		blade.Anchored = false
		blade.CanCollide = false
	end
	camLock.Anchored = true
	camLock.CanCollide = false

	-- A glow Highlight that fades IN during a Stop-Falling freeze (on top of
	-- the part-colour tint) so the sword reads as visibly enchanted/frozen.
	-- DepthMode = Occluded so the rock properly hides the buried portion of
	-- the sword (otherwise the highlight draws through the rock and you can
	-- see the blade inside it). Enabled stays false when not freezing so the
	-- highlight is truly OFF, not "transparent and still doing something".
	local freezeHighlight = Instance.new("Highlight")
	freezeHighlight.Name = "FreezeHighlight"
	freezeHighlight.FillColor = Color3.fromRGB(150, 220, 255)
	freezeHighlight.OutlineColor = Color3.fromRGB(220, 245, 255)
	freezeHighlight.FillTransparency = 1
	freezeHighlight.OutlineTransparency = 1
	freezeHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	freezeHighlight.Adornee = sword
	freezeHighlight.Enabled = false
	freezeHighlight.Parent = sword

	-- A red Highlight that pulses like a HEARTBEAT while the player is in the
	-- "CLICK FASTER!" idle-warning band. Pairs with the SlipWarning sound so
	-- the danger is heard AND seen. Same Occluded depth so it can't render
	-- through the rock either.
	local warningHighlight = Instance.new("Highlight")
	warningHighlight.Name = "WarningHighlight"
	warningHighlight.FillColor = Color3.fromRGB(255, 60, 60)
	warningHighlight.OutlineColor = Color3.fromRGB(255, 130, 130)
	warningHighlight.FillTransparency = 1
	warningHighlight.OutlineTransparency = 1
	warningHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	warningHighlight.Adornee = sword
	warningHighlight.Enabled = false
	warningHighlight.Parent = sword

	local clickRayParams = RaycastParams.new()
	clickRayParams.FilterType = Enum.RaycastFilterType.Include
	clickRayParams.FilterDescendantsInstances = { sword }

	-- Token-counted particle pulse so rapid clicks don't flicker the emitters.
	local particleToken = 0
	local function pulseParticles(thing: Instance, duration: number?)
		particleToken += 1
		local myToken = particleToken
		for _, v in thing:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = true
			end
		end
		if duration then
			task.delay(duration, function()
				if particleToken ~= myToken then
					return
				end
				for _, v in thing:GetDescendants() do
					if v:IsA("ParticleEmitter") then
						v.Enabled = false
					end
				end
			end)
		end
	end

	-- =====================================================================
	-- State
	-- =====================================================================

	local hasX2 = false
	pcall(function()
		hasX2 = Net.func("CheckX2Click"):InvokeServer()
	end)
	local progressPerHit = hasX2 and GameConfig.ProgressPerHitX2 or GameConfig.ProgressPerHit
	-- BOTH derive from the blade's actual mesh size (Util/BladeMetrics) -- so
	-- resizing the Blade in Studio auto-syncs the bar AND the rise distance.
	local totalProgress = BladeMetrics.getTotalProgress()
	local maxRise = BladeMetrics.getBladeLength()
	local idleThreshold = GameConfig.IdleThresholdSeconds
	local decayActive = GameConfig.DecayPerSecondActive
	local decayIdle = GameConfig.DecayPerSecondIdle

	local playing = false
	local sessionFinished = false
	local progress = 0
	local lastHitClock = 0
	local sessionStartClock = 0
	local renderedOffset = 0
	local swordClickKick = 0
	local reviveUsed = false
	local awaitingReviveChoice = false
	local hasClicked = false         -- has the player landed any click this round?
	local showingIdleWarning = false -- is the prompt showing the idle warning?
	local freezeEndsAt = 0           -- tick() at which the decay freeze ends
	local wasFrozen = false          -- freeze state last Heartbeat (edge detect)
	local shownFreezeSecond = nil    -- last countdown number written to the prompt
	local decayShudder = 0           -- current sword slip-tremble amplitude
	local barTrendUp = false         -- bar-colour hysteresis: progress trending up?
	local smoothedVelocity = 0       -- EMA of progress %/s, drives the bar colour
	local prevColorProgress = 0      -- progress last frame (for the velocity calc)
	local barColor = GameConfig.BarFallingColor -- current (lerped) FillBar colour
	local activeFreezeVfx = nil      -- list of cloned ParticleEmitters on the Blade
	local originalSwordColors = {}   -- [Part] = pre-freeze Color3 to restore
	local activeColorTweens = {}     -- [Part] = active colour Tween (for cancel)
	local activeHighlightTween: Tween? = nil -- active Highlight transparency tween

	-- Forward declarations.
	local resetMinigame
	local failLocally
	local registerClick
	local startGameFromClick
	local tryUseRevive   -- shared by the revive button + keybind
	local tryUseStop     -- shared by the stop buttons + keybinds

	-- =====================================================================
	-- Visual / state helpers
	-- =====================================================================

	local function setProgressBar()
		if fillBar then
			fillBar.Size = UDim2.new(progress / totalProgress, 0, 1, 0)
		end
	end

	local function sword_addClickPop()
		swordClickKick = math.min(0.6, swordClickKick + 0.25)
	end

	local function isFrozen(): boolean
		return tick() < freezeEndsAt
	end

	-- Tween helpers for the freeze look. Smooth fades feel much more like a
	-- "magical transformation" than an instant snap.
	local FREEZE_FADE_IN = 0.4
	local FREEZE_FADE_OUT = 0.3
	local FADE_IN_INFO = TweenInfo.new(FREEZE_FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local FADE_OUT_INFO = TweenInfo.new(FREEZE_FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local function tweenPartColor(part: BasePart, color: Color3, info: TweenInfo): Tween
		if activeColorTweens[part] then
			activeColorTweens[part]:Cancel()
		end
		local tween = TweenService:Create(part, info, { Color = color })
		activeColorTweens[part] = tween
		tween:Play()
		return tween
	end

	local function tweenHighlight(fillT: number, outlineT: number, info: TweenInfo)
		if activeHighlightTween then
			activeHighlightTween:Cancel()
		end
		-- Enable to allow the fade-in. Once the fade-out completes (target both
		-- transparencies = 1) we disable it again so it's truly off, not just
		-- "on but invisible" -- belts and braces alongside DepthMode=Occluded.
		freezeHighlight.Enabled = true
		local tween = TweenService:Create(freezeHighlight, info, {
			FillTransparency = fillT,
			OutlineTransparency = outlineT,
		})
		activeHighlightTween = tween
		tween:Play()
		if fillT >= 1 and outlineT >= 1 then
			local connection
			connection = tween.Completed:Connect(function()
				if activeHighlightTween == tween then
					freezeHighlight.Enabled = false
				end
				if connection then connection:Disconnect() end
			end)
		end
	end

	-- Applies the full freeze look to the sword: clones every ParticleEmitter
	-- from ReplicatedStorage.Effects.FreezeVFX onto the Blade, smoothly fades
	-- the Handle / Neon / Blade colours toward icy blue (saving each original
	-- so we can restore them), fades in the freeze Highlight glow, plays the
	-- freeze stinger, and starts the looping tic-toc timer SFX. All side-
	-- effects are LOCAL -- other players see the sword unchanged.
	local function applyFreezeVisuals()
		-- Clone the freeze particles onto the blade.
		if freezeVfxFolder then
			activeFreezeVfx = {}
			for _, original in freezeVfxFolder:GetChildren() do
				if original:IsA("ParticleEmitter") then
					local clone = original:Clone()
					clone.Enabled = true
					clone.Parent = blade
					activeFreezeVfx[#activeFreezeVfx + 1] = clone
				end
			end
		end
		-- Tween sword parts toward ice. Save originals (only if not already
		-- saved -- a re-freeze during the previous fade-out keeps the TRUE
		-- original, not the icy in-flight value).
		local function tintPart(part: Instance)
			if not part:IsA("BasePart") then return end
			if originalSwordColors[part] == nil then
				originalSwordColors[part] = part.Color
			end
			tweenPartColor(part, GameConfig.SwordFreezeColor, FADE_IN_INFO)
		end
		for _, child in handleFolder:GetChildren() do tintPart(child) end
		for _, child in neonFolder:GetChildren() do tintPart(child) end
		tintPart(blade)
		-- Highlight glow on top of the colour tint.
		tweenHighlight(0.55, 0.15, FADE_IN_INFO)
		-- Stingers.
		safePlay(freezeSFX)
		if timerSFX then
			timerSFX:Play() -- loops until clearFreezeVisuals
		end
	end

	-- Reverses everything applyFreezeVisuals did: stops the particles emitting
	-- (letting already-spawned ones fade out naturally), tweens every saved
	-- colour BACK to its original, fades the Highlight out, stops the looping
	-- tic-toc, plays the "ice cracks" stinger, and snaps a small camera kick.
	local function clearFreezeVisuals()
		if activeFreezeVfx then
			local clones = activeFreezeVfx
			activeFreezeVfx = nil
			for _, c in clones do
				c.Enabled = false
			end
			-- Destroy after the longest plausible Lifetime so particles fade
			-- naturally instead of popping out.
			task.delay(2, function()
				for _, c in clones do
					if c.Parent then
						c:Destroy()
					end
				end
			end)
		end
		for part, originalColor in originalSwordColors do
			if part and part.Parent then
				local t = tweenPartColor(part, originalColor, FADE_OUT_INFO)
				-- Drop the saved original once the tween-back fully completes
				-- (so a fresh freeze re-captures the current part colour).
				local connection
				connection = t.Completed:Connect(function()
					if activeColorTweens[part] == t then
						activeColorTweens[part] = nil
						originalSwordColors[part] = nil
					end
					if connection then connection:Disconnect() end
				end)
			else
				originalSwordColors[part] = nil
				activeColorTweens[part] = nil
			end
		end
		-- Fade the highlight back out.
		tweenHighlight(1, 1, FADE_OUT_INFO)
		if timerSFX then
			timerSFX:Stop()
		end
		safePlay(freezeBreakSFX)
		-- A small camera kick communicates "the ice cracks!"
		CameraController.kickShake(0.4)
	end

	-- Ends any active decay freeze and cuts its timer SFX. Called on every
	-- session-end path so a freeze can't bleed into the next round.
	local function clearFreeze()
		if wasFrozen then
			clearFreezeVisuals() -- restore sword colours + destroy VFX + stop SFX
		end
		freezeEndsAt = 0
		wasFrozen = false
		shownFreezeSecond = nil
		stopFreezeSounds()
	end

	-- =====================================================================
	-- Core gameplay
	-- =====================================================================

	function registerClick()
		if not playing or sessionFinished or awaitingReviveChoice then
			return
		end
		local now = os.clock()
		-- Mirror the server's rate cap exactly so the local bar tracks server.
		if now - lastHitClock < GameConfig.MinHitIntervalSeconds then
			return
		end
		lastHitClock = now

		progress = math.min(totalProgress, progress + progressPerHit)
		Net.event("PullHit"):FireServer()
		safePlay(clickSFX)
		sword_addClickPop()
		CameraController.kickShake() -- per-click camera punch
		pulseParticles(swordVFX, 0.1)

		hasClicked = true
		setProgressBar()
		-- We deliberately do NOT stop at 100% locally. The SERVER is
		-- authoritative for the win, and it runs a few hits behind the client
		-- (network latency). If the client stopped feeding hits the instant
		-- its own bar hit 100%, the server could land just short of 100% and
		-- never complete -- the player would "win" on screen then get failed.
		-- Staying in `playing` keeps hits flowing until the server confirms
		-- with SuccessPulling. The bar itself is already clamped by math.min.
	end

	local function rayHitsSword(screenX: number, screenY: number): boolean
		local ray = camera:ViewportPointToRay(screenX, screenY)
		local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, clickRayParams)
		return result ~= nil
	end

	-- Moves the client into the "playing" state (state C). Used both by the
	-- 2nd-sword-click path and by the legacy Start-button / server StartGame.
	local function enterPlayingState()
		progress = 0
		renderedOffset = 0
		swordClickKick = 0
		sessionStartClock = os.clock()
		lastHitClock = 0  -- 0 so the very first click isn't rate-rejected
		playing = true
		sessionFinished = false
		awaitingReviveChoice = false
		reviveUsed = false
		hasClicked = false
		showingIdleWarning = false
		freezeEndsAt = 0
		wasFrozen = false
		shownFreezeSecond = nil
		decayShudder = 0
		barTrendUp = false
		smoothedVelocity = 0
		prevColorProgress = 0
		barColor = GameConfig.BarFallingColor
		setProgressBar()
		safeVisible(keyPrompt, true)
		safeText(keyPrompt, PROMPT_CLICK)
		if keyPrompt then
			keyPrompt.Position = UDim2.new(0, 0, 0, 0)
		end
		safeVisible(startButton, false)
		safeVisible(exitButton, false)
		showOwnedStopButtons()
	end

	-- The 2nd sword click. Opens the session on the server and counts the
	-- triggering click as the first pull.
	function startGameFromClick()
		if playing or sessionFinished then
			return -- already started
		end
		enterPlayingState()
		Net.event("StartGameButton"):FireServer() -- server opens the session
		registerClick()                           -- this click is the 1st pull
	end

	function failLocally()
		if sessionFinished then
			return
		end
		sessionFinished = true
		playing = false
		clearFreeze()
		progress = 0
		setProgressBar()

		-- Offer a revive whenever the player HAS one (not gated on the button
		-- existing) -- on PC the revive keybind works even with no button.
		local revivesLeft = player:FindFirstChild("RevivesLeft")
		if revivesLeft and revivesLeft.Value > 0 and not reviveUsed then
			awaitingReviveChoice = true
			safeText(keyPrompt, "Press R to Revive or Press the Revive Button.")
			safeVisible(useReviveButton, true)
			task.delay(3, function()
				if not awaitingReviveChoice then
					return
				end
				awaitingReviveChoice = false
				if reviveUsed then
					return
				end
				safeText(keyPrompt, "TOO SLOW!")
				safeVisible(useReviveButton, false)
				safePlay(failedSFX)
				Net.event("PullFail"):FireServer()
				task.wait(1)
				resetMinigame()
			end)
			return
		end

		safeText(keyPrompt, "TOO SLOW!")
		safeVisible(useReviveButton, false)
		safePlay(failedSFX)
		Net.event("PullFail"):FireServer()
		task.delay(1, resetMinigame)
	end

	function resetMinigame()
		playing = false
		sessionFinished = false
		awaitingReviveChoice = false
		reviveUsed = false
		clearFreeze()
		progress = 0
		renderedOffset = 0
		swordClickKick = 0
		setProgressBar()
		camLock.CFrame = savedCamLockCFrame

		safeText(keyPrompt, "")
		safeVisible(keyPrompt, false)
		safeVisible(startButton, true)
		safeVisible(exitButton, true)
		hideStopButtons()
		safeVisible(useReviveButton, false)
		Net.event("LeavePulling"):FireServer()
	end

	local function completeGameUX()
		playing = false
		sessionFinished = true
		showingIdleWarning = false
		clearFreeze()
		progress = totalProgress
		setProgressBar()
		safeText(keyPrompt, "You're the NEW KING!")
		safePlay(challengeCompleteSFX)
		-- Big celebratory particle burst + a hold on the fully-pulled sword
		-- (camera is at its widest here) so the win doesn't cut away instantly.
		pulseParticles(swordVFX, GameConfig.WinCelebrationSeconds)
		task.wait(GameConfig.WinCelebrationSeconds)
		resetMinigame()
	end

	local function handleServerFail()
		if sessionFinished then
			return
		end
		failLocally()
	end

	-- =====================================================================
	-- Input (mouse + touch raycast onto the sword)
	-- =====================================================================

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		-- Only react while the pull UI is open and we're not in a finished /
		-- revive-choice state. If the UI just opened (1st click entering),
		-- this same click's InputBegan already fired BEFORE the ClickDetector
		-- enabled the UI, so it harmlessly fails this guard.
		if not swordUI.Enabled or sessionFinished or awaitingReviveChoice then
			return
		end
		local isTouch = input.UserInputType == Enum.UserInputType.Touch
		local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
		if not isTouch and not isMouse then
			return
		end
		-- MOBILE: skip the precise sword-raycast. The camera pulls back as
		-- progress climbs (and on tall blades that's a LOT of distance), so
		-- on a phone screen the sword shrinks to a tiny target that's
		-- basically impossible to spam-tap. The player is already in pulling
		-- mode (they tapped the sword once intentionally to enter), so any
		-- subsequent tap anywhere on screen clearly means "I'm pulling" --
		-- there's nothing else they could be trying to do, and any UI button
		-- taps are caught by the gameProcessed guard above. Mouse users on
		-- PC keep the pixel-perfect aim requirement (single-pixel cursor
		-- makes the small sword still hittable, and it preserves the "skill"
		-- feel for the desktop crowd).
		if not isTouch then
			local pos = input.Position
			if not rayHitsSword(pos.X, pos.Y) then
				return
			end
		end
		if playing then
			registerClick()
		else
			startGameFromClick() -- 2nd click: opens the session + 1st pull
		end
	end)

	-- Keyboard shortcuts (PC). A separate handler so it ISN'T gated by the
	-- sword-click guards above -- the revive key in particular must work while
	-- awaitingReviveChoice is true. tryUseRevive / tryUseStop do their own
	-- state checks. Mobile has no keyboard, so this simply never fires there.
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return -- e.g. the player is typing in chat
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if not swordUI.Enabled then
			return -- only while the pull UI is open
		end
		local key = input.KeyCode
		if key == GameConfig.KeybindRevive then
			tryUseRevive()
			return
		end
		for _, sp in stopProducts do
			if key == sp.keybind then
				tryUseStop(sp.seconds)
				return
			end
		end
	end)

	-- =====================================================================
	-- UI buttons (all optional)
	-- =====================================================================

	if exitButton then
		exitButton.MouseButton1Click:Connect(function()
			Net.event("LeavePulling"):FireServer()
		end)
	end

	-- Legacy Start button -- still works if the user kept it. Server-side
	-- StartGameButton is idempotent so this is harmless alongside the
	-- click-the-sword-to-start flow.
	if startButton then
		startButton.MouseButton1Click:Connect(function()
			Net.event("StartGameButton"):FireServer()
		end)
	end

	-- Use a revive. Shared by the revive button AND the revive keybind. Only
	-- valid while the "Revive?" prompt is up (awaitingReviveChoice) -- pressing
	-- the key any other time does nothing.
	function tryUseRevive()
		if not awaitingReviveChoice or reviveUsed then
			return
		end
		local revivesLeft = player:FindFirstChild("RevivesLeft")
		if not revivesLeft or revivesLeft.Value <= 0 then
			return
		end
		reviveUsed = true
		awaitingReviveChoice = false
		Net.event("UseRevive"):FireServer()
		progress = totalProgress * GameConfig.ReviveProgressFraction
		-- Match the server's onUseRevive: it stamps lastHit = now so the decay
		-- starts in the ACTIVE band, not the punishing idle band.
		lastHitClock = os.clock()
		sessionStartClock = os.clock()
		showingIdleWarning = false
		freezeEndsAt = 0
		wasFrozen = false
		shownFreezeSecond = nil
		setProgressBar()
		safeText(keyPrompt, PROMPT_CLICK)
		safeVisible(useReviveButton, false)
		sessionFinished = false
		playing = true
	end

	if useReviveButton then
		useReviveButton.MouseButton1Click:Connect(tryUseRevive)
	end

	-- Use a "Stop Falling" charge. Shared by the stop buttons AND the keybinds.
	-- The server is the gatekeeper: it rejects a 2nd activation while a freeze
	-- is already running, so a double-tap can't consume two charges.
	function tryUseStop(seconds: number)
		if not playing or sessionFinished or awaitingReviveChoice then
			return
		end
		if isFrozen() then
			return -- a freeze is already active
		end
		if (stopCharges[seconds] or 0) <= 0 then
			return -- player doesn't own a charge of this duration
		end
		Net.event("UseAutoClicker"):FireServer(seconds)
	end

	for _, sp in stopProducts do
		if sp.button then
			local seconds = sp.seconds
			sp.button.MouseButton1Click:Connect(function()
				tryUseStop(seconds)
			end)
		end
	end

	local reviveVal = player:WaitForChild("RevivesLeft", UI_WAIT_TIMEOUT)
	if reviveVal and reviveCountLabel then
		reviveCountLabel.Text = reviveVal.Value
		reviveVal.Changed:Connect(function()
			reviveCountLabel.Text = reviveVal.Value
		end)
	end

	-- =====================================================================
	-- Server-driven flow
	-- =====================================================================

	-- Server confirmed the session opened. If the client already started
	-- optimistically (2nd-click path), this is a no-op. The legacy Start
	-- button path relies on this to actually enter the playing state.
	Net.event("StartGame").OnClientEvent:Connect(function()
		if not playing and not sessionFinished then
			enterPlayingState()
		end
	end)

	Net.event("SuccessPulling").OnClientEvent:Connect(completeGameUX)
	Net.event("FailPulling").OnClientEvent:Connect(handleServerFail)

	-- Authoritative progress sync, ~20Hz. We only SNAP on a large drift
	-- (>5% of the bar). Small drifts are left to the local model so an early
	-- server tick can't yank back the optimistic first click.
	Net.event("ProgressSync").OnClientEvent:Connect(function(serverProgress)
		if not playing or sessionFinished then
			return
		end
		serverProgress = tonumber(serverProgress)
		if not serverProgress then
			return
		end
		serverProgress = math.clamp(serverProgress, 0, totalProgress)
		if math.abs(serverProgress - progress) > totalProgress * 0.05 then
			progress = serverProgress
			setProgressBar()
		end
	end)

	-- =====================================================================
	-- Stop-Falling charges
	-- =====================================================================

	Net.event("UpdateAutoClickers").OnClientEvent:Connect(function(counts)
		counts = counts or {}
		for _, sp in stopProducts do
			-- DataStore round-trips can stringify numeric keys -- check both.
			stopCharges[sp.seconds] = counts[sp.seconds] or counts[tostring(sp.seconds)] or 0
		end
		-- Refresh button visibility if we're mid-round and not currently frozen.
		if playing and not sessionFinished and not isFrozen() then
			showOwnedStopButtons()
		end
	end)

	-- Server confirmed a Stop-Falling charge -- freeze the decay for N seconds.
	Net.event("AutoClickerActivated").OnClientEvent:Connect(function(seconds)
		seconds = tonumber(seconds) or 0
		if seconds <= 0 then
			return
		end
		freezeEndsAt = tick() + seconds
		hideStopButtons() -- can't stack a second freeze
	end)

	swordUI:GetPropertyChangedSignal("Enabled"):Connect(function()
		if swordUI.Enabled then
			-- Entered pulling mode (state B). NOT playing yet -- the player
			-- has to click the sword to actually start the round.
			playing = false
			sessionFinished = false
			awaitingReviveChoice = false
			reviveUsed = false
			clearFreeze()
			progress = 0
			renderedOffset = 0
			swordClickKick = 0
			setProgressBar()
			camLock.CFrame = savedCamLockCFrame
			safeVisible(startButton, true)
			safeVisible(exitButton, true)
			hideStopButtons()
			safeVisible(useReviveButton, false)
			safeVisible(keyPrompt, true)
			safeText(keyPrompt, "SPAM CLICKING ON THE SWORD TO PULL IT OUT!")
			Net.event("RequestAutoClickers"):FireServer()
		else
			-- UI closed for any reason -- full reset.
			playing = false
			sessionFinished = false
			awaitingReviveChoice = false
			reviveUsed = false
			clearFreeze()
			progress = 0
			renderedOffset = 0
			swordClickKick = 0
			setProgressBar()
			camLock.CFrame = savedCamLockCFrame
			-- Slip-warning cleanup: silence the alarm + drop the red highlight
			-- so neither bleeds past the round.
			showingIdleWarning = false
			if slipWarningSFX then slipWarningSFX:Stop() end
			warningHighlight.Enabled = false
		end
	end)

	-- =====================================================================
	-- Heartbeat: local decay mirror + smooth sword rendering.
	-- Gated on session state so the sword stays still when nobody is pulling
	-- (including state B -- entered but not yet started).
	-- =====================================================================
	RunService.Heartbeat:Connect(function(dt)
		if not playing and not sessionFinished then
			return
		end

		-- Once the round is finished (win/fail), the warning band no longer
		-- applies -- silence the alarm + drop the red pulse before the round
		-- resets so they don't bleed into the win/fail UX.
		if sessionFinished and showingIdleWarning then
			showingIdleWarning = false
			if slipWarningSFX then slipWarningSFX:Stop() end
			warningHighlight.Enabled = false
		end

		if playing and not sessionFinished and not awaitingReviveChoice then
			local now = os.clock()
			local frozen = isFrozen()

			-- Freeze edge detection.
			if frozen ~= wasFrozen then
				wasFrozen = frozen
				if frozen then
					-- Freeze just started: ice the sword + play the stinger.
					-- ALSO kill any in-flight slip warning -- the sword can't
					-- be slipping while the decay is frozen, so leaving the
					-- warning siren or red pulse on would be a glitch.
					applyFreezeVisuals()
					showingIdleWarning = false
					if slipWarningSFX then slipWarningSFX:Stop() end
					warningHighlight.Enabled = false
				else
					-- Freeze just ended: restore the sword + cut its SFX +
					-- play the "ice cracks" sound + restore the prompt + re-show
					-- whatever stop charges the player still owns.
					clearFreezeVisuals()
					shownFreezeSecond = nil
					showingIdleWarning = false
					stopFreezeSounds()
					safeText(keyPrompt, PROMPT_CLICK)
					showOwnedStopButtons()
				end
			end

			if frozen then
				-- Decay is frozen. Just run the on-screen countdown (updated
				-- only when the whole-second value changes, so no strobing).
				local secsLeft = math.max(1, math.ceil(freezeEndsAt - tick()))
				if secsLeft ~= shownFreezeSecond then
					shownFreezeSecond = secsLeft
					safeText(keyPrompt, `FROZEN {secsLeft}s`)
				end
			else
				-- Normal decay -- faster once the player goes idle.
				local idle = (now - lastHitClock) > idleThreshold
				local rate = idle and decayIdle or decayActive
				progress = math.max(0, progress - rate * dt)
				setProgressBar()

				-- Readability cue: once the player has started, a real pause
				-- flips the prompt to a louder warning. Only updated on a
				-- state change so the text doesn't strobe.
				local warnIdle = hasClicked and (now - lastHitClock) > GameConfig.IdleWarningSeconds
				if warnIdle ~= showingIdleWarning then
					showingIdleWarning = warnIdle
					safeText(keyPrompt, warnIdle and PROMPT_FASTER or PROMPT_CLICK)
					if warnIdle then
						-- Sound the alarm. (If the user set it to Looped, it
						-- keeps going for the whole warning; if not, it plays
						-- once. Either way we stop it the moment they catch up.)
						safePlay(slipWarningSFX)
					else
						-- Player caught up -- mute the warning immediately so
						-- the alarm doesn't keep playing past the danger.
						if slipWarningSFX then slipWarningSFX:Stop() end
					end
				end

				-- Heartbeat-pulse red warning highlight while in the warning
				-- band. Smoothly oscillates between dim and bright so it reads
				-- as "danger pulse" instead of a solid red overlay.
				if showingIdleWarning then
					if not warningHighlight.Enabled then
						warningHighlight.Enabled = true
					end
					local pulse = (math.sin(now * 8) + 1) * 0.5 -- 0..1 at ~1.27 Hz
					warningHighlight.FillTransparency = 0.92 - pulse * 0.30 -- 0.62 .. 0.92
					warningHighlight.OutlineTransparency = 0.65 - pulse * 0.55 -- 0.10 .. 0.65
				elseif warningHighlight.Enabled then
					warningHighlight.Enabled = false
				end

				if progress <= 0 and (now - sessionStartClock) >= GameConfig.FailGraceSeconds then
					failLocally()
				end
			end
		end

		local targetOffset = (progress / totalProgress) * maxRise
		local smooth = math.clamp(dt * 12, 0, 1)
		renderedOffset += (targetOffset - renderedOffset) * smooth
		swordClickKick = math.max(0, swordClickKick - dt * 4)

		-- Slip shudder: while the player is idle-draining (stopped clicking,
		-- not frozen) the sword trembles a little so it visibly "struggles".
		local slipping = playing and not sessionFinished and not awaitingReviveChoice
			and hasClicked and not isFrozen()
			and (os.clock() - lastHitClock) > idleThreshold
		local shudderTarget = slipping and GameConfig.SwordSlipShudderStuds or 0
		decayShudder += (shudderTarget - decayShudder) * math.clamp(dt * 8, 0, 1)

		local now = os.clock()
		local shudderX = math.noise(now * 20, 3.3) * decayShudder
		local shudderZ = math.noise(9.1, now * 20) * decayShudder
		local yOffset = renderedOffset + swordClickKick
		local rest = savedCamLockCFrame - savedCamLockCFrame.Position
		camLock.CFrame = CFrame.new(savedCamLockPosition + Vector3.new(shudderX, yOffset, shudderZ)) * rest

		-- Progress-bar colour feedback: the FillBar tints green while progress
		-- is net-rising and red while it's net-falling. Coloured by a SMOOTHED
		-- velocity (EMA) so the click-up / decay-down wobble doesn't strobe it,
		-- with a deadzone + hysteresis around break-even.
		if fillBar then
			local vel = math.clamp((progress - prevColorProgress) / math.max(dt, 1 / 240), -150, 150)
			prevColorProgress = progress
			smoothedVelocity += (vel - smoothedVelocity) * math.clamp(dt * 3, 0, 1)
			if smoothedVelocity > 1 then
				barTrendUp = true
			elseif smoothedVelocity < -1 then
				barTrendUp = false
			end
			local targetCol = barTrendUp and GameConfig.BarRisingColor or GameConfig.BarFallingColor
			barColor = barColor:Lerp(targetCol, math.clamp(dt * 8, 0, 1))
			fillBar.BackgroundColor3 = barColor
		end
	end)
end

return PullingController
