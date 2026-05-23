--!nonstrict
-- Client entry point. Replaces the legacy wait(5) timing hacks with explicit
-- WaitForChild inside each controller, started in dependency order.

local controllers = {
	require(script.MusicController),
	require(script.CameraController),
	require(script.PlayerVisibilityController),
	require(script.SwordInteractionController),
	require(script.PullingController),
	require(script.UiFxController), -- cosmetic ember VFX; safe to remove
	require(script.ShopController), -- shop panel + buy-button wiring
	require(script.GuideController), -- onboarding beam + welcome banner
}

for _, controller in controllers do
	local ok, err = pcall(controller.start)
	if not ok then
		warn(`[Client] a controller failed to start: {tostring(err)}`)
	end
end
