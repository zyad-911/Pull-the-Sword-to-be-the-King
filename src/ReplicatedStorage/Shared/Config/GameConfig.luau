--!strict
-- All minigame tuning lives here so balance changes never require touching logic.

local GameConfig = {}

GameConfig.Keys = { "Q", "E", "R", "F", "Z", "X", "C", "V" }

GameConfig.TimeToReactSeconds = 1
GameConfig.TotalProgress = 100

-- Progress added per validated successful hit.
GameConfig.ProgressPerHit = 0.2
-- X2 Click gamepass: each hit counts double. NOTE: the legacy code had this
-- inverted (it made X2 owners *slower*); this restores the intended 2x.
GameConfig.ProgressPerHitX2 = 0.4

-- Anti-exploit: hits arriving faster than this are ignored by the server.
-- 0.04s = 25 hits/sec, far above any human; blocks scripted instant-wins
-- without affecting legitimate players.
GameConfig.MinHitIntervalSeconds = 0.04

-- Safety floor: a completion reported faster than this (server clock) is rejected.
GameConfig.MinPullDurationSeconds = 3

-- Server-side approach check: the player must be within this many studs of the
-- sword to start a pull. Generous to absorb latency / animation offsets.
GameConfig.MaxApproachDistance = 25

-- Client interaction range for the highlight / billboard prompt.
GameConfig.InteractionDistance = 15

-- Autoclicker cadence the client uses (kept for parity with the legacy UX).
GameConfig.AutoClickerIntervalSeconds = 0.25

return GameConfig
