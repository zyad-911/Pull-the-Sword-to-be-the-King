--!strict
-- Product / gamepass IDs and monetisation tuning.

local MonetizationConfig = {}

-- Developer Products.
-- NOTE: the two former autoclicker products were rebranded as "Stop Falling"
-- charges. The product IDs are unchanged (so existing purchases / the live
-- store still resolve) -- only what they grant changed:
--   StopFalling5s  (was AutoClicker10s) -> a 5-second decay freeze
--   StopFalling10s (was AutoClicker20s) -> a 10-second decay freeze
MonetizationConfig.Products = {
	StopFalling5s = 3291348387,
	StopFalling10s = 3291348858,
	Revive1x = 3292639633,
	Revive2x = 3292640135,
	Revive3x = 3292641664,
}

-- Gamepasses
MonetizationConfig.Gamepasses = {
	X2Click = 1231166728,
	-- Set the VIP gamepass ID here or VIP minute-boost stays disabled.
	VIP = 0,
}

-- (The Stop-Falling consumables -- durations, buttons, keybinds -- are defined
-- in GameConfig.StopFalling.)

-- Minutes leaderstat accrual.
MonetizationConfig.MinutesPerInterval = 1
MonetizationConfig.MinutesIntervalSeconds = 60
MonetizationConfig.VipBoostEnabled = true
MonetizationConfig.VipMinutesMultiplier = 2
MonetizationConfig.VipWhitelist = { "ImFenice", "FeniceDevss" }

return MonetizationConfig
