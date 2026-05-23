--!nonstrict
-- ============================================================================
-- ShopController -- wires the Main/Shop UI to MarketplaceService prompts,
-- with a smooth slide-down open / slide-up close animation.
-- ============================================================================
--
-- The Shop frame's CLOSED position is {0.5, 0},{-0.5, 0} (centred horizontally,
-- pushed off the TOP of the screen) -- this is the value the user already set
-- in Studio. Open just tweens it down to centre ({0.5, 0},{0.5, 0}); close
-- tweens it back up. AnchorPoint must be 0.5,0.5 on the Shop frame.
--
-- Buy buttons -> MarketplaceService, using the IDs in MonetizationConfig:
--   5sTimeFreeze, 10sTimeFreeze   -> StopFalling 5s/10s dev products
--   X2Click                       -> X2 Click gamepass
--   +1Revive, +2Revives, +3Revives -> Revive dev products
--
-- All UI lookups are tolerant -- if you rename or remove a button, only that
-- button stops working; the rest of the shop is fine.
-- ============================================================================

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Mon = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))

local player = Players.LocalPlayer

local ShopController = {}

local UI_WAIT_TIMEOUT = 2

local OPEN_POSITION = UDim2.new(0.5, 0, 0.5, 0)    -- centred on screen
local CLOSED_POSITION = UDim2.new(0.5, 0, -0.5, 0) -- pushed off the top edge
local OPEN_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function findDeep(parent: Instance?, name: string): Instance?
	return parent and parent:FindFirstChild(name, true) or nil
end

function ShopController.start()
	local playerGui = player:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main", UI_WAIT_TIMEOUT)
	if not main then return end

	local shop = main:WaitForChild("Shop", UI_WAIT_TIMEOUT)
	if not shop then return end

	-- Open / close triggers (both deep-searched so you can move them around).
	local mainBtn = findDeep(main, "MainBtn")    -- under Buttons/ShopBtn/
	local closeBtn = findDeep(shop, "CloseBtn")

	-- Snap to closed at start so we never see a single frame of the open state.
	shop.Position = CLOSED_POSITION

	local isOpen = false
	local activeTween: Tween? = nil
	local function setOpen(open: boolean)
		if open == isOpen then return end
		isOpen = open
		if activeTween then activeTween:Cancel() end
		activeTween = TweenService:Create(shop, open and OPEN_TWEEN or CLOSE_TWEEN, {
			Position = open and OPEN_POSITION or CLOSED_POSITION,
		})
		activeTween:Play()
	end

	if mainBtn and mainBtn:IsA("GuiButton") then
		mainBtn.MouseButton1Click:Connect(function()
			setOpen(true)
		end)
	end
	if closeBtn and closeBtn:IsA("GuiButton") then
		closeBtn.MouseButton1Click:Connect(function()
			setOpen(false)
		end)
	end

	-- Auto-close when the player enters pulling mode so the shop isn't left
	-- floating behind the SwordUI when they leave the pull later.
	local swordUI = playerGui:WaitForChild("SwordUI", UI_WAIT_TIMEOUT)
	if swordUI then
		swordUI:GetPropertyChangedSignal("Enabled"):Connect(function()
			if swordUI.Enabled and isOpen then
				setOpen(false)
			end
		end)
	end

	-- ====================================================================
	-- Buy-button wiring -- each button prompts the right purchase.
	-- ====================================================================

	local function promptProduct(productId: number?)
		if not productId or productId <= 0 then return end
		MarketplaceService:PromptProductPurchase(player, productId)
	end
	local function promptGamepass(gamepassId: number?)
		if not gamepassId or gamepassId <= 0 then return end
		MarketplaceService:PromptGamePassPurchase(player, gamepassId)
	end
	local function wire(button: Instance?, onClick: () -> ())
		if button and button:IsA("GuiButton") then
			button.MouseButton1Click:Connect(onClick)
		end
	end

	wire(findDeep(shop, "5sTimeFreeze"),  function() promptProduct(Mon.Products.StopFalling5s) end)
	wire(findDeep(shop, "10sTimeFreeze"), function() promptProduct(Mon.Products.StopFalling10s) end)
	wire(findDeep(shop, "X2Click"),       function() promptGamepass(Mon.Gamepasses.X2Click) end)
	wire(findDeep(shop, "+1Revive"),      function() promptProduct(Mon.Products.Revive1x) end)
	wire(findDeep(shop, "+2Revives"),     function() promptProduct(Mon.Products.Revive2x) end)
	wire(findDeep(shop, "+3Revives"),     function() promptProduct(Mon.Products.Revive3x) end)
	wire(findDeep(shop, "VIP"),           function() promptGamepass(Mon.Gamepasses.VIP) end)
end

return ShopController
