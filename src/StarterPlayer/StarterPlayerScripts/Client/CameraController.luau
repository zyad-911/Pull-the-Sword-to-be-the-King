--!nonstrict
-- Scriptable camera that follows the sword while the player is pulling.
--
-- Four layers stack each frame to make the camera feel alive AND reveal the
-- full sword as it emerges from the rock:
--
--   1. Framing    - camera offset + look-target LERP between a close-up of
--                   the handle (REST) and a wide shot of the whole blade
--                   (FULLY PULLED). The pull fraction is derived from how
--                   far the sword's CamLock has risen above its rest height
--                   (no extra plumbing needed -- PullingController already
--                   drives the CamLock displacement). Tune in GameConfig.
--   2. Follow     - the camera lerps toward (sword + framed offset) with
--                   smoothing. Larger CameraFollowSmoothing = snappier.
--   3. Wind sway  - a slow, low-frequency drift driven by Perlin noise; the
--                   "wind-like" continuous motion the player feels.
--   4. Click kick - an impulse added by PullingController each time a click
--                   lands (CameraController.kickShake). Decays exponentially.
--                   The bigger this is, the harder it is to land precise
--                   repeat clicks on the same point of the sword.
--
-- All tunables live in GameConfig.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CameraController = {}

local renderConn: RBXScriptConnection? = nil
local kickOffset = Vector3.new(0, 0, 0)
local locked = false
local restY: number? = nil

-- Pure-touch devices (phones/tablets, no mouse) get a softer per-click kick:
-- a smaller target on a smaller screen makes the full PC kick unfair.
local isTouchDevice = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- Pulled-camera framing, DERIVED from the blade length so resizing the sword
-- (GameConfig.SwordBladeLength) auto-adjusts the wide shot -- nothing else to
-- tune. Camera pulls back ~0.9x the blade, drops ~0.35x below the handle, and
-- looks at the blade's midpoint (half a blade-length below the handle).
local PULLED_OFFSET = Vector3.new(
	0,
	-GameConfig.SwordBladeLength * GameConfig.CameraPulledDropMul,
	GameConfig.SwordBladeLength * GameConfig.CameraPulledBackMul
)
local PULLED_LOOK = Vector3.new(0, -GameConfig.SwordBladeLength * 0.5, 0)

local function getCamLock(): BasePart
	local rock = workspace:WaitForChild("SwordRock")
	local sword = rock:WaitForChild("King's Sword")
	local handle = sword:WaitForChild("Handle")
	return handle:WaitForChild("CamLock")
end

-- Called by PullingController on every accepted click. Adds a random-direction
-- impulse to the camera; the per-frame update decays it back to zero.
-- `intensity` overrides GameConfig.CameraClickKickStuds if provided.
function CameraController.kickShake(intensity: number?)
	if not locked then
		return -- nothing to shake; the camera isn't even in pull mode
	end
	local amount = intensity
		or (isTouchDevice and GameConfig.CameraClickKickStudsTouch)
		or GameConfig.CameraClickKickStuds
	if amount <= 0 then
		return
	end
	-- Pick a random direction on the unit sphere-ish, scaled to `amount`.
	local angle = math.random() * math.pi * 2
	local lateral = math.cos(angle) * amount
	local vertical = (math.random() - 0.5) * amount * 0.6
	local depth = math.sin(angle) * amount
	-- Accumulate so rapid clicks stack briefly instead of overwriting.
	kickOffset += Vector3.new(lateral, vertical, depth)
	-- Cap the total kick so a fast click burst doesn't fling the camera away.
	local cap = amount * 2.0
	if kickOffset.Magnitude > cap then
		kickOffset = kickOffset.Unit * cap
	end
end

local function lock()
	local camLock = getCamLock()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CameraSubject = nil
	-- Only capture the rest height + snap into frame on the FIRST lock of a
	-- session. A redundant LockCamera must NOT recapture restY -- by then the
	-- sword may already have risen and the pull-fraction (used for the
	-- pull-back framing) would be misjudged. reset() clears `locked` so the
	-- next session captures a fresh restY.
	if not locked then
		restY = camLock.Position.Y
		camera.CFrame = CFrame.lookAt(
			camLock.Position + GameConfig.CameraRestOffset,
			camLock.Position + GameConfig.CameraRestLookOffset
		)
		kickOffset = Vector3.new(0, 0, 0)
	end
	locked = true

	if renderConn then
		renderConn:Disconnect()
	end
	renderConn = RunService.RenderStepped:Connect(function(dt)
		-- 1) Framing -- where is the sword in its pull cycle (0..1)?
		--    We derive it from CamLock vertical displacement so the camera
		--    doesn't need to share state with PullingController.
		local risen = math.max(0, camLock.Position.Y - (restY or camLock.Position.Y))
		local maxRise = math.max(GameConfig.SwordBladeLength, 0.001) -- rise distance == blade length
		local pulledFraction = math.clamp(risen / maxRise, 0, 1)

		local cameraOffset = GameConfig.CameraRestOffset:Lerp(PULLED_OFFSET, pulledFraction)
		local lookOffset = GameConfig.CameraRestLookOffset:Lerp(PULLED_LOOK, pulledFraction)
		local goalPos = camLock.Position + cameraOffset
		local goalLook = camLock.Position + lookOffset

		-- 2) Follow
		local smooth = math.clamp(dt * GameConfig.CameraFollowSmoothing, 0, 1)
		local newPos = camera.CFrame.Position:Lerp(goalPos, smooth)

		-- 3) Wind sway (slow Perlin drift)
		local t = os.clock()
		local windFreq = GameConfig.CameraWindFrequencyHz
		local posAmp = GameConfig.CameraWindAmpStuds
		local lookAmp = GameConfig.CameraWindLookAmpStuds
		local windPos = Vector3.new(
			math.noise(t * windFreq, 0.0) * posAmp,
			math.noise(0.0, t * windFreq * 0.7) * posAmp * 0.5,
			math.noise(t * windFreq * 1.1, 7.3) * posAmp
		)
		local windLook = Vector3.new(
			math.noise(t * windFreq * 1.2, 11.1) * lookAmp,
			math.noise(13.7, t * windFreq * 1.2) * lookAmp,
			0
		)

		-- 4) Click kick (impulse, exp decay)
		kickOffset = kickOffset * math.exp(-dt * GameConfig.CameraClickKickDecay)

		camera.CFrame = CFrame.lookAt(
			newPos + windPos + kickOffset,
			goalLook + windLook + kickOffset * 0.5
		)
	end)
end

local function reset()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	locked = false
	kickOffset = Vector3.new(0, 0, 0)
	restY = nil
	camera.CameraType = Enum.CameraType.Custom
	local char = player.Character or player.CharacterAdded:Wait()
	camera.CameraSubject = char:FindFirstChildOfClass("Humanoid")
end

function CameraController.start()
	Net.event("LockCamera").OnClientEvent:Connect(lock)
	Net.event("ResetCamera").OnClientEvent:Connect(reset)
end

return CameraController
