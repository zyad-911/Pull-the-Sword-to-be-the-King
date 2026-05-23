--!strict
-- ============================================================================
-- Game configuration -- ALL tunable gameplay numbers live in this file.
-- ============================================================================
--
-- The minigame: hold a "PULL" by clicking the 3D sword fast enough to outpace
-- a constant downward drain. Stop clicking even briefly and the drain speeds
-- up. Drain the bar to 0% = fail. Fill it to 100% = king.
--
-- ──────────────────────────────────────────────────────────────────────────
-- HOW TO MAKE IT HARDER OR EASIER  (the two knobs that matter most)
-- ──────────────────────────────────────────────────────────────────────────
--   Want HARDER?   ↑ DecayPerSecondActive   or   ↓ ProgressPerHit
--   Want EASIER?   ↓ DecayPerSecondActive   or   ↑ ProgressPerHit
--
-- The break-even click rate (clicks/sec needed JUST to stop sinking) is:
--      DecayPerSecondActive / ProgressPerHit
-- With the current INSANELY HARD values: 11.0 / 1.2 ≈ 9.2 clicks/sec.
-- You'll need to sustain ~11+ clicks/sec to actually win in a reasonable time.
--
-- Time to win from 0% at a sustained click rate `r` (clicks/sec):
--      100 / (r * ProgressPerHit - DecayPerSecondActive)
-- ──────────────────────────────────────────────────────────────────────────

local GameConfig = {}

-- ============================================================================
-- DIFFICULTY -- the click-spam mechanic
-- ============================================================================

-- "Progress units" each stud of blade is worth. Multiplied by the blade's
-- ACTUAL length (read from the mesh at runtime, see Util/BladeMetrics) to
-- produce TotalProgress -- so resizing the blade in Studio auto-scales the
-- whole pull, with NO config change needed. Tune ProgressPerStud to retune
-- the per-stud difficulty curve.
--   default: 100/30 -> a 30-stud blade gives TotalProgress = 100 (original tuning)
GameConfig.ProgressPerStud = 100 / 30

-- Percent added per accepted click.          Lower = harder, higher = easier.
-- This is THE difficulty knob -- lower it to make the pull harder without
-- touching the decay (the sword doesn't sink faster, you just need to click
-- faster). 1.2 -> break-even ~9.2 c/s. Try 1.1 for ~10 c/s, 1.0 for ~11 c/s.
GameConfig.ProgressPerHit = 1.2
-- Same, for X2 Click gamepass owners (should be exactly 2x for "X2" to mean X2).
GameConfig.ProgressPerHitX2 = 2.4

-- Constant downward drain while the player IS clicking (within
-- IdleThresholdSeconds of their last click). Player must out-click this.
-- Higher = harder. Lower = easier.
GameConfig.DecayPerSecondActive = 11.0

-- Faster drain that kicks in once the player goes idle. Sword fully sinks in
-- (TotalProgress / DecayPerSecondIdle) seconds of inactivity from 100%.
-- Higher = punishes stopping more harshly.
GameConfig.DecayPerSecondIdle = 26.0

-- Time without a click before the idle drain rate kicks in.
-- Lower = stricter pacing (less margin for finger fumble).
GameConfig.IdleThresholdSeconds = 0.12

-- How long the player must go WITHOUT a click before the on-screen prompt
-- switches from "CLICK!" to a louder "CLICK FASTER!" warning. UI cue only --
-- deliberately longer than IdleThresholdSeconds so the prompt doesn't strobe
-- during normal fast clicking; it only fires on a real pause.
GameConfig.IdleWarningSeconds = 0.35

-- ============================================================================
-- STOP FALLING -- the paid consumables (was: autoclickers)
-- ============================================================================
-- Activating a "Stop Falling" charge FREEZES the sword's decay for `seconds`.
-- The player still has to CLICK during the freeze to gain ground -- the freeze
-- just removes the drain, so every click is pure progress. It's a strong
-- assist, not an auto-win: a player who activates one and doesn't click gains
-- nothing.
--
-- Each entry:
--   seconds    - how long the decay freeze lasts (also the inventory key in
--                profile.autoClickers and the argument the client sends).
--   buttonName - the SwordUI button (under Uses.Buttons) that activates it.
--   keybind    - PC keyboard shortcut (the button still works too).
--
-- Roughly, with no decay during the freeze and ~10 clicks/sec manual:
--   5s freeze  -> ~70% of the bar    10s freeze -> a full pull.
GameConfig.StopFalling = {
	{ seconds = 5, buttonName = "5sStop", keybind = Enum.KeyCode.Q },
	{ seconds = 10, buttonName = "10sStop", keybind = Enum.KeyCode.E },
}

-- PC keyboard shortcut to use a revive (only fires while the revive is offered).
GameConfig.KeybindRevive = Enum.KeyCode.R

-- ============================================================================
-- CAMERA -- follow, wind sway, per-click kick, and pull-back framing
-- ============================================================================

-- Camera offset (relative to the sword's CamLock) at REST. Close-up of the
-- handle so the player sees what they're about to click.
GameConfig.CameraRestOffset = Vector3.new(0, 5, 10)

-- Look-target offset at REST (look directly at the handle).
GameConfig.CameraRestLookOffset = Vector3.new(0, 0, 0)

-- Pulled-camera framing (when the bar is at 100%) is DERIVED from
-- SwordBladeLength so it auto-adapts whenever you resize the blade -- you only
-- ever tune SwordBladeLength, never the camera. These multipliers shape the
-- derived wide shot:
--   distance back     = SwordBladeLength * CameraPulledBackMul
--   drop below handle = SwordBladeLength * CameraPulledDropMul
-- (The camera always looks at the blade's midpoint.)
GameConfig.CameraPulledBackMul = 0.9
GameConfig.CameraPulledDropMul = 0.35

-- Continuous "wind" sway while the camera is locked to the sword. Slow drift,
-- no shake. Set the amplitudes to 0 to disable the sway entirely.
GameConfig.CameraWindAmpStuds = 0.55         -- camera position drift radius
GameConfig.CameraWindLookAmpStuds = 0.30     -- look-target drift radius
GameConfig.CameraWindFrequencyHz = 0.55      -- sway speed; lower = slower wind

-- Per-click camera punch. Bigger = harder to land the same click target twice
-- in a row (camera jerks, sword leaps on screen, you have to re-aim).
--   0    = no per-click shake
--   0.3  = subtle
--   0.6  = aggressive  ← current
--   1.0  = brutal
GameConfig.CameraClickKickStuds = 0.6

-- Per-click kick used on TOUCH devices (mobile/tablet). Mobile players tap a
-- smaller target on a smaller screen, so the kick is softened so the game is
-- challenging rather than unfair. Set equal to CameraClickKickStuds to disable
-- the mobile easing.
GameConfig.CameraClickKickStudsTouch = 0.3

-- How fast the click kick decays back to baseline. Per-second exp decay.
-- Higher = snappier settle (less lingering shake).
GameConfig.CameraClickKickDecay = 8.0

-- How quickly the camera catches up to the sword each frame. Larger = snappier.
GameConfig.CameraFollowSmoothing = 8

-- ============================================================================
-- VISUALS -- sword motion
-- ============================================================================

-- (Blade length is read from the actual Blade mesh at runtime by
-- Shared.Util.BladeMetrics. Resize the blade in Studio and the game adapts
-- with no config change. Tune ProgressPerStud above to scale difficulty.)

-- Lateral tremble (studs) of the sword while it is idle-draining, so it
-- visibly "struggles"/slips when the player stops clicking. 0 = no shudder.
GameConfig.SwordSlipShudderStuds = 0.25

-- Progress-bar colour feedback. The FillBar tints toward BarRisingColor while
-- the player is gaining ground and toward BarFallingColor while losing it --
-- so the bar itself shows whether you're winning the tug-of-war.
GameConfig.BarRisingColor = Color3.fromRGB(70, 220, 90)
GameConfig.BarFallingColor = Color3.fromRGB(235, 65, 55)

-- Colour the sword's Handle / Neon / Blade parts tint to during a "Stop
-- Falling" freeze. Restored when the freeze ends.
GameConfig.SwordFreezeColor = Color3.fromRGB(140, 215, 255)

-- ============================================================================
-- LIFECYCLE -- session timing
-- ============================================================================

-- Grace window after Start before the decay can fail the player. Without this,
-- the bar would auto-fail before the first click ever registers.
GameConfig.FailGraceSeconds = 1.0

-- After the server declares a fail, the session is kept alive this long so
-- the client's revive click can still resurrect it. Must comfortably exceed
-- the client's 3s revive window + network latency.
GameConfig.FailedSessionGraceSeconds = 5.0

-- On revive, restore the sword to this fraction of TotalProgress.
GameConfig.ReviveProgressFraction = 0.5

-- How long the win screen holds on the fully-pulled sword before the world
-- restores. The camera is at its widest here, framing the whole blade -- give
-- the player a moment to enjoy the victory instead of cutting away instantly.
GameConfig.WinCelebrationSeconds = 2.5

-- ============================================================================
-- ANTI-EXPLOIT -- server-side caps and floors
-- ============================================================================

-- Hit-rate cap: clicks arriving faster than this (on the server) are ignored.
-- 0.06s = ~16 hits/sec, slightly above the fastest sustained human click rate,
-- so legitimate fast players are unaffected but third-party autoclickers
-- running above 16 c/s are throttled to the human ceiling.
GameConfig.MinHitIntervalSeconds = 0.06

-- A completion reported faster than this (server clock) is rejected.
-- 2.0s sits above the worst-case X2 + rate-cap exploit and below a legit X2
-- owner's fastest plausible time. If you tune the math so legit wins are
-- slower, raise this floor accordingly.
GameConfig.MinPullDurationSeconds = 2.0

-- Player must be within this many studs of the sword to open a session
-- (server-side, blocks teleport-and-win).
GameConfig.MaxApproachDistance = 25

-- ============================================================================
-- INTERACTION
-- ============================================================================

-- Client-side range for the highlight / billboard prompt to show on the rock.
GameConfig.InteractionDistance = 15

-- ============================================================================
-- ONBOARDING -- guide beam + welcome message for new players
-- ============================================================================

-- One-time welcome line shown on join. Set to "" to skip. Requires a
-- Main.Welcome.Label TextLabel in the UI; GuideController fades it in, holds
-- it for a few seconds, then fades it out.
GameConfig.WelcomeMessage = "Go and try to Pull the King's Sword!"

-- Roblox texture asset ID for the guide-beam that points the player at the
-- sword. Set to your image, e.g. "rbxassetid://1234567890". Empty string =
-- plain solid-colour beam (still works fine without a texture).
GameConfig.GuideBeamTextureId = "rbxassetid://6558648587"

-- Solid colour the beam tints toward. Multiplied with the texture if you set
-- one above; on its own it's the whole beam colour.
GameConfig.GuideBeamColor = Color3.fromRGB(140, 220, 255)

return GameConfig
