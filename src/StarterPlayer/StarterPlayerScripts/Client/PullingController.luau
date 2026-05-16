--!nonstrict
-- The reaction minigame UI. Renders rounds and sword visuals, but progress is
-- now reported to the server (PullHit) which alone decides the win. The client
-- never declares victory, never fires a badge event and never reports its own
-- time -- it just waits for the server's SuccessPulling.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)

local player = Players.LocalPlayer

local PullingController = {}

local BUTTON_TO_KEY = {
	Q1 = "Q", E2 = "E", R3 = "R", F4 = "F",
	Z5 = "Z", X6 = "X", C7 = "C", V8 = "V",
}

function PullingController.start()
	local playerGui = player:WaitForChild("PlayerGui")
	local swordUI = playerGui:WaitForChild("SwordUI")

	-- UI references (same paths as the published place) -------------------
	local exitButton = swordUI:WaitForChild("Exit")
	local startButton = swordUI:WaitForChild("StartButton")
	local keyBox = swordUI:WaitForChild("KeyBox")
	local keyPrompt = keyBox:WaitForChild("KeyPrompt")
	local clickSFX = keyPrompt:WaitForChild("Click")
	local failedSFX = keyPrompt:WaitForChild("Failed")
	local challengeCompleteSFX = swordUI:WaitForChild("ChallengeCompleteSFX")
	local progressBar = swordUI:WaitForChild("ProgressBar")
	local fillBar = progressBar:WaitForChild("FillBar")
	local usesButtons = swordUI:WaitForChild("Uses"):WaitForChild("Buttons")
	local useAuto10 = usesButtons:WaitForChild("UseAutoClickerButton10s")
	local useAuto20 = usesButtons:WaitForChild("UseAutoClickerButton20s")
	local useReviveButton = usesButtons:WaitForChild("1ReviveUse")
	local reviveCountLabel = swordUI:WaitForChild("Revives"):WaitForChild("Numper")
	local mobileButtons = swordUI:WaitForChild("MobileButtons")

	-- Sword visuals ------------------------------------------------------
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
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local swordOffset = 0

	local function weldParts(folder: Instance)
		for _, part in folder:GetChildren() do
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

	local function moveSword(delta: number)
		swordOffset += delta
		local goalCFrame = CFrame.new(savedCamLockPosition + Vector3.new(0, swordOffset, 0))
			* (savedCamLockCFrame - savedCamLockCFrame.Position)
		TweenService:Create(camLock, tweenInfo, { CFrame = goalCFrame }):Play()
	end

	local function resetSword()
		swordOffset = 0
		TweenService:Create(camLock, tweenInfo, { CFrame = savedCamLockCFrame }):Play()
	end

	local function shakeSword()
		local original = camLock.CFrame
		for _ = 1, 5 do
			camLock.CFrame = original * CFrame.new(math.random(-1, 1) * 0.1, 0, math.random(-1, 1) * 0.1)
			task.wait(0.03)
		end
		camLock.CFrame = original
	end

	local function enableParticles(thing: Instance, duration: number?)
		for _, v in thing:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = true
			end
		end
		if duration then
			task.delay(duration, function()
				for _, v in thing:GetDescendants() do
					if v:IsA("ParticleEmitter") then
						v.Enabled = false
					end
				end
			end)
		end
	end

	-- State --------------------------------------------------------------
	local hasX2 = false
	pcall(function()
		hasX2 = Net.func("CheckX2Click"):InvokeServer()
	end)
	local progressPerHit = hasX2 and GameConfig.ProgressPerHitX2 or GameConfig.ProgressPerHit
	local totalProgress = GameConfig.TotalProgress
	local timeToReact = GameConfig.TimeToReactSeconds

	local playing = false
	local canPress = false
	local currentKey: string? = nil
	local progress = 0
	local currentRoundId = 0
	local reviveUsed = false
	local autoClickerActive = false
	local autoClickerEndTime = 0
	local autoclickerCounts = { [10] = 0, [20] = 0 }

	local startRound, failGame, resetMinigame

	local function setProgressBar()
		fillBar.Size = UDim2.new(progress / totalProgress, 0, 1, 0)
	end

	local function awaitServerWin()
		-- Local bar is full; stop input and wait for the server to confirm.
		playing = false
		canPress = false
	end

	local function registerHit()
		canPress = false
		progress += progressPerHit
		setProgressBar()
		clickSFX:Play()
		moveSword(0.1)
		task.spawn(shakeSword)
		enableParticles(swordVFX, 0.1)
		Net.event("PullHit"):FireServer()
		if progress >= totalProgress then
			awaitServerWin()
		else
			startRound()
		end
	end

	function startRound()
		if not playing then
			return
		end
		currentRoundId += 1
		local thisRound = currentRoundId

		currentKey = GameConfig.Keys[math.random(1, #GameConfig.Keys)]
		keyPrompt.Text = currentKey
		canPress = true

		local randX = (math.random() - 0.5) * 0.8
		local randY = (math.random() - 0.5) * 0.8
		keyPrompt.Position = UDim2.new(0.5 + randX, 0, 0.5 + randY, 0)

		task.delay(timeToReact, function()
			if playing and canPress and currentRoundId == thisRound then
				failGame()
			end
		end)
	end

	function failGame()
		if reviveUsed then
			return
		end

		local revivesLeft = player:FindFirstChild("RevivesLeft")
		if revivesLeft and revivesLeft.Value > 0 then
			keyPrompt.Text = "Revive?"
			useReviveButton.Visible = true
			canPress = false
			task.wait(3)
			if reviveUsed then
				Net.event("UseRevive"):FireServer()
				keyPrompt.Text = ""
				useReviveButton.Visible = false
				canPress = true
				reviveUsed = false
				startRound()
				return
			end
		end

		playing = false
		keyPrompt.Text = "WRONG!"
		useAuto10.Visible = false
		useAuto20.Visible = false
		useReviveButton.Visible = false
		failedSFX:Play()
		Net.event("PullFail"):FireServer()
		task.wait(1)
		resetMinigame()
	end

	function resetMinigame()
		keyPrompt.Text = ""
		keyPrompt.Visible = false
		startButton.Visible = true
		exitButton.Visible = true
		useAuto10.Visible = false
		useAuto20.Visible = false
		useReviveButton.Visible = false
		progress = 0
		setProgressBar()
		resetSword()
		autoClickerActive = false
		reviveUsed = false
		-- Server ends the session and restores camera/visibility/world.
		Net.event("LeavePulling"):FireServer()
	end

	local function completeGameUX()
		playing = false
		canPress = false
		keyPrompt.Text = "KING!"
		challengeCompleteSFX:Play()
		task.wait(1)
		resetMinigame()
	end

	local function handleKeyPress(key: string)
		if not canPress or not playing then
			return
		end
		if key == currentKey then
			registerHit()
		elseif not autoClickerActive then
			failGame()
		end
	end

	-- Input --------------------------------------------------------------
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not canPress or not playing then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		handleKeyPress(input.KeyCode.Name)
	end)

	for buttonName, key in BUTTON_TO_KEY do
		local button = mobileButtons:FindFirstChild(buttonName)
		if button then
			button.MouseButton1Click:Connect(function()
				handleKeyPress(key)
			end)
		end
	end
	mobileButtons.Visible = UserInputService.TouchEnabled

	-- Buttons ------------------------------------------------------------
	exitButton.MouseButton1Click:Connect(function()
		Net.event("LeavePulling"):FireServer()
	end)

	startButton.MouseButton1Click:Connect(function()
		Net.event("StartGameButton"):FireServer()
		startButton.Visible = false
		exitButton.Visible = false
		if autoclickerCounts[10] > 0 then
			useAuto10.Visible = true
		end
		if autoclickerCounts[20] > 0 then
			useAuto20.Visible = true
		end
	end)

	useReviveButton.MouseButton1Click:Connect(function()
		local revivesLeft = player:FindFirstChild("RevivesLeft")
		if revivesLeft and revivesLeft.Value > 0 and not reviveUsed then
			reviveUsed = true
		end
	end)

	local reviveVal = player:WaitForChild("RevivesLeft")
	reviveCountLabel.Text = reviveVal.Value
	reviveVal.Changed:Connect(function()
		reviveCountLabel.Text = reviveVal.Value
	end)

	-- Server-driven flow -------------------------------------------------
	Net.event("StartGame").OnClientEvent:Connect(function()
		keyPrompt.Visible = true
		playing = true
		startRound()
	end)

	Net.event("SuccessPulling").OnClientEvent:Connect(completeGameUX)

	-- Autoclicker --------------------------------------------------------
	local function refreshAutoButtons()
		if autoclickerCounts[10] > 0 then
			useAuto10.Visible = true
		end
		if autoclickerCounts[20] > 0 then
			useAuto20.Visible = true
		end
	end

	Net.event("UpdateAutoClickers").OnClientEvent:Connect(function(counts)
		counts = counts or {}
		autoclickerCounts[10] = counts[10] or counts["10"] or 0
		autoclickerCounts[20] = counts[20] or counts["20"] or 0
	end)

	swordUI:GetPropertyChangedSignal("Enabled"):Connect(function()
		if swordUI.Enabled then
			-- Fresh entry: reset inner widgets and ask for inventory.
			startButton.Visible = true
			exitButton.Visible = true
			keyPrompt.Visible = false
			useAuto10.Visible = false
			useAuto20.Visible = false
			useReviveButton.Visible = false
			progress = 0
			setProgressBar()
			Net.event("RequestAutoClickers"):FireServer()
		else
			autoClickerActive = false
		end
	end)

	local function startAutoClicker(duration: number)
		autoClickerActive = true
		Net.event("UseAutoClicker"):FireServer(duration)
		useAuto10.Visible = false
		useAuto20.Visible = false
	end

	useAuto10.MouseButton1Click:Connect(function()
		if autoclickerCounts[10] > 0 and not autoClickerActive then
			startAutoClicker(10)
		end
	end)
	useAuto20.MouseButton1Click:Connect(function()
		if autoclickerCounts[20] > 0 and not autoClickerActive then
			startAutoClicker(20)
		end
	end)

	Net.event("AutoClickerActivated").OnClientEvent:Connect(function(duration)
		autoClickerEndTime = tick() + duration
		task.spawn(function()
			while autoClickerActive and tick() < autoClickerEndTime and swordUI.Enabled and playing do
				if canPress then
					canPress = false
					progress += progressPerHit
					setProgressBar()
					moveSword(0.1)
					task.spawn(shakeSword)
					clickSFX:Play()
					enableParticles(swordVFX, 0.1)
					Net.event("PullHit"):FireServer()
					if progress >= totalProgress then
						awaitServerWin()
						autoClickerActive = false
						break
					else
						startRound()
					end
				end
				task.wait(GameConfig.AutoClickerIntervalSeconds)
			end
			autoClickerActive = false
			refreshAutoButtons()
		end)
	end)
end

return PullingController
