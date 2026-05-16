--!strict
-- Product / gamepass IDs and monetisation tuning.

local MonetizationConfig = {}

-- Developer Products
MonetizationConfig.Products = {
	AutoClicker10s = 3291348387,
	AutoClicker20s = 3291348858,
	Revive1x = 3292639633,
	Revive2x = 3292640135,
	Revive3x = 3292641664,
}

-- Gamepasses
MonetizationConfig.Gamepasses = {
	X2Click = 1231166728,
	-- TODO: the VIP gamepass id was stored as a Value object inside the old
	-- Minutes script (data baked into the .rbxl, not readable from source).
	-- Set it here or VIP minute-boost stays disabled.
	VIP = 0,
}

-- Autoclicker SKUs available, in seconds.
MonetizationConfig.AutoClickerDurations = { 10, 20 }

-- Minutes leaderstat accrual.
MonetizationConfig.MinutesPerInterval = 1
MonetizationConfig.MinutesIntervalSeconds = 60
MonetizationConfig.VipBoostEnabled = true
MonetizationConfig.VipMinutesMultiplier = 2
MonetizationConfig.VipWhitelist = { "ImFenice", "FeniceDevss" }

return MonetizationConfig
