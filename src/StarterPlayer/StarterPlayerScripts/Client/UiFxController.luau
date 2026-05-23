--!nonstrict
-- ============================================================================
-- UiFxController -- code-only "ember" VFX for the pull minigame.
-- ============================================================================
-- No image assets needed: each ember is a small circular Frame (a soft halo
-- with a brighter core) that rises from the bottom of the screen, sways, and
-- fades -- giving the SwordUI a warm, fiery ambiance while the player pulls.
-- The ember spawn rate swells as the progress bar fills, so the sword visibly
-- "blazes" harder the closer it is to coming free.
--
-- Purely cosmetic and fully self-contained:
--   * Lives in its own Frame layer (EmberVFX) created under SwordUI.
--   * Every frame is Active=false, so embers NEVER eat a sword click.
--   * Driven only by SwordUI.Enabled (on/off) and the ProgressSync remote
--     (intensity) -- no coupling to the gameplay controllers.
-- Delete this controller (and unregister it in init.client) to remove the FX.
-- ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local BladeMetrics = require(Shared.Util.BladeMetrics)

local player = Players.LocalPlayer

local UiFxController = {}

-- Tuning (cosmetic only -- safe to tweak freely).
local POOL_SIZE = 26          -- max embers alive at once
local SPAWN_BASE = 9          -- embers/sec at 0% progress
local SPAWN_EXTRA = 16        -- additional embers/sec at 100% progress
local RISE_MIN, RISE_MAX = 0.10, 0.22  -- rise speed, screen-heights per second
local LIFE_MIN, LIFE_MAX = 1.6, 3.0    -- ember lifetime, seconds
local SIZE_MIN, SIZE_MAX = 6, 18       -- ember diameter, pixels
local SWAY = 0.045            -- horizontal sway amplitude (scale)
local WARM = {                -- ember colours (deep ember -> bright flame)
	Color3.fromRGB(255, 205, 80),
	Color3.fromRGB(255, 155, 45),
	Color3.fromRGB(255, 110, 30),
	Color3.fromRGB(255, 80, 35),
}

function UiFxController.start()
	local playerGui = player:WaitForChild("PlayerGui")
	local swordUI = playerGui:WaitForChild("SwordUI", 5)
	if not swordUI then
		return -- no pull UI; nothing to decorate
	end

	-- Full-screen, non-interactive layer that sits BEHIND the gameplay UI.
	local layer = Instance.new("Frame")
	layer.Name = "EmberVFX"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.Active = false
	layer.ZIndex = 0
	layer.Parent = swordUI

	-- Icy-blue overlay shown while a Stop-Falling freeze is active. Sits ABOVE
	-- the gameplay UI so it tints the whole view (the sword + bar + buttons all
	-- read as "frozen"). Active=false so it never eats a click.
	local freezeOverlay = Instance.new("Frame")
	freezeOverlay.Name = "FreezeOverlay"
	freezeOverlay.BackgroundColor3 = Color3.fromRGB(120, 195, 255)
	freezeOverlay.BackgroundTransparency = 1
	freezeOverlay.Size = UDim2.fromScale(1, 1)
	freezeOverlay.Active = false
	freezeOverlay.ZIndex = 50
	freezeOverlay.Parent = swordUI

	-- Bright white impact flash on a win. Decays quickly. Sits above everything
	-- so the king-moment has visual punch.
	local winFlash = Instance.new("Frame")
	winFlash.Name = "WinFlashOverlay"
	winFlash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	winFlash.BackgroundTransparency = 1
	winFlash.Size = UDim2.fromScale(1, 1)
	winFlash.Active = false
	winFlash.ZIndex = 100
	winFlash.Parent = swordUI

	-- Pre-build the ember pool (halo Frame + brighter core Frame, both circles).
	local embers = {}
	for i = 1, POOL_SIZE do
		local halo = Instance.new("Frame")
		halo.Name = "Ember"
		halo.AnchorPoint = Vector2.new(0.5, 0.5)
		halo.BackgroundColor3 = Color3.fromRGB(255, 120, 40)
		halo.BackgroundTransparency = 1
		halo.Active = false
		halo.ZIndex = 0
		halo.Visible = false
		local haloCorner = Instance.new("UICorner")
		haloCorner.CornerRadius = UDim.new(1, 0)
		haloCorner.Parent = halo

		local core = Instance.new("Frame")
		core.Name = "Core"
		core.AnchorPoint = Vector2.new(0.5, 0.5)
		core.Position = UDim2.fromScale(0.5, 0.5)
		core.Size = UDim2.fromScale(0.5, 0.5)
		core.BackgroundColor3 = Color3.fromRGB(255, 235, 175)
		core.Active = false
		core.ZIndex = 0
		local coreCorner = Instance.new("UICorner")
		coreCorner.CornerRadius = UDim.new(1, 0)
		coreCorner.Parent = core
		core.Parent = halo

		halo.Parent = layer
		embers[i] = { halo = halo, core = core, alive = false }
	end

	local active = false      -- is the pull UI open?
	local progressLevel = 0   -- 0..1 from ProgressSync; scales the spawn rate
	local spawnAccum = 0
	local freezeEndsAt = 0    -- tick() at which the current freeze ends
	local freezeAlpha = 0     -- current (smoothed) freeze-overlay alpha 0..1
	local flashAlpha = 0      -- current (decaying) win-flash alpha 0..1

	-- Brings one dormant ember to life at the bottom of the screen.
	local function spawnEmber()
		for _, e in embers do
			if not e.alive then
				local size = SIZE_MIN + math.random() * (SIZE_MAX - SIZE_MIN)
				e.alive = true
				e.age = 0
				e.life = LIFE_MIN + math.random() * (LIFE_MAX - LIFE_MIN)
				e.x = 0.5 + (math.random() - 0.5) * 0.7   -- centre-biased
				e.y = 1.05                                 -- just off the bottom
				e.vy = -(RISE_MIN + math.random() * (RISE_MAX - RISE_MIN))
				e.sway = math.random() * math.pi * 2
				e.halo.BackgroundColor3 = WARM[math.random(#WARM)]
				e.halo.Size = UDim2.fromOffset(size, size)
				e.halo.Visible = true
				return
			end
		end
	end

	swordUI:GetPropertyChangedSignal("Enabled"):Connect(function()
		active = swordUI.Enabled
		if not active then
			progressLevel = 0 -- stop the intensity swell; alive embers finish
			freezeEndsAt = 0  -- clear any stale tint
			flashAlpha = 0
		end
	end)

	-- Progress drives the ember intensity (more fire as the bar fills).
	-- Normalised against the real TotalProgress (which scales with the blade).
	local totalProgress = math.max(BladeMetrics.getTotalProgress(), 1)
	Net.event("ProgressSync").OnClientEvent:Connect(function(p)
		p = tonumber(p)
		if p then
			progressLevel = math.clamp(p / totalProgress, 0, 1)
		end
	end)

	-- Stop-Falling activated -- start the icy blue tint for `seconds`.
	Net.event("AutoClickerActivated").OnClientEvent:Connect(function(seconds)
		seconds = tonumber(seconds) or 0
		if seconds > 0 then
			freezeEndsAt = tick() + seconds
		end
	end)

	-- Round ended -- clear the freeze tint (so winning/losing mid-freeze
	-- doesn't leave a phantom blue overlay).
	Net.event("SuccessPulling").OnClientEvent:Connect(function()
		freezeEndsAt = 0
		flashAlpha = 0.85 -- bright impact flash for the king moment
	end)
	Net.event("FailPulling").OnClientEvent:Connect(function()
		freezeEndsAt = 0
	end)

	RunService.Heartbeat:Connect(function(dt)
		-- Freeze overlay: lerp toward 0.22 alpha while a freeze is active,
		-- toward 0 once it ends. Smooth in/out so the tint doesn't pop.
		local freezeTarget = (tick() < freezeEndsAt) and 0.22 or 0
		freezeAlpha += (freezeTarget - freezeAlpha) * math.clamp(dt * 6, 0, 1)
		freezeOverlay.BackgroundTransparency = 1 - freezeAlpha

		-- Win flash: snap-on (on SuccessPulling), then linearly decay to 0
		-- over ~0.6 seconds. Brief but punchy.
		if flashAlpha > 0 then
			flashAlpha = math.max(0, flashAlpha - dt * 1.5)
			winFlash.BackgroundTransparency = 1 - flashAlpha
		elseif winFlash.BackgroundTransparency ~= 1 then
			winFlash.BackgroundTransparency = 1
		end

		-- Spawn embers while the pull UI is open; rate swells with progress.
		if active then
			local rate = SPAWN_BASE + SPAWN_EXTRA * progressLevel
			spawnAccum += dt * rate
			while spawnAccum >= 1 do
				spawnAccum -= 1
				spawnEmber()
			end
		end

		-- Animate every live ember (they finish their rise even after the UI
		-- closes, then go dormant -- no popping).
		for _, e in embers do
			if e.alive then
				e.age += dt
				if e.age >= e.life then
					e.alive = false
					e.halo.Visible = false
				else
					e.y += e.vy * dt
					local t = e.age / e.life
					local alpha
					if t < 0.15 then
						alpha = t / 0.15        -- fade in
					elseif t > 0.55 then
						alpha = (1 - t) / 0.45  -- fade out
					else
						alpha = 1
					end
					local swayX = math.sin(e.sway + e.age * 3) * SWAY
					e.halo.Position = UDim2.fromScale(e.x + swayX, e.y)
					e.halo.BackgroundTransparency = 1 - alpha * 0.5
					e.core.BackgroundTransparency = 1 - alpha
				end
			end
		end
	end)
end

return UiFxController
