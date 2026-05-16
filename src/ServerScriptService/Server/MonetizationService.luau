--!nonstrict
-- ProcessReceipt + gamepass checks + autoclicker/revive grants. All grants go
-- through DataService so Robux purchases now actually persist (the legacy code
-- stored them in a memory table that was wiped on every rejoin).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Mon = require(Shared.Config.MonetizationConfig)
local Log = require(Shared.Util.Log)
local DataService = require(script.Parent.DataService)

local log = Log.new("Monetization")

local MonetizationService = {}

local x2Cache: { [number]: boolean } = {}

function MonetizationService.ownsX2Click(player: Player): boolean
	local profile = DataService.get(player)
	if profile and profile.hasX2Click then
		return true -- admin-granted override
	end

	local cached = x2Cache[player.UserId]
	if cached ~= nil then
		return cached
	end

	local ok, has = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Mon.Gamepasses.X2Click)
	end)
	local result = ok and has == true
	x2Cache[player.UserId] = result
	return result
end

local function pushInventory(player: Player)
	local profile = DataService.get(player)
	if profile then
		Net.event("UpdateAutoClickers"):FireClient(player, profile.autoClickers)
	end
end

function MonetizationService.grantAutoClicker(player: Player, duration: number, amount: number)
	DataService.update(player, function(p)
		p.autoClickers[duration] = (p.autoClickers[duration] or 0) + amount
	end)
	pushInventory(player)
end

function MonetizationService.grantRevives(player: Player, amount: number)
	DataService.update(player, function(p)
		p.revives += amount
	end)
end

function MonetizationService.grantX2Click(player: Player)
	DataService.update(player, function(p)
		p.hasX2Click = true
	end)
	x2Cache[player.UserId] = true
end

local function onReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not DataService.get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local id = receipt.ProductId
	local P = Mon.Products
	if id == P.AutoClicker10s then
		MonetizationService.grantAutoClicker(player, 10, 1)
	elseif id == P.AutoClicker20s then
		MonetizationService.grantAutoClicker(player, 20, 1)
	elseif id == P.Revive1x then
		MonetizationService.grantRevives(player, 1)
	elseif id == P.Revive2x then
		MonetizationService.grantRevives(player, 2)
	elseif id == P.Revive3x then
		MonetizationService.grantRevives(player, 3)
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Persist immediately so the purchase survives a crash/rejoin.
	DataService.save(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = onReceipt

	Net.event("RequestAutoClickers").OnServerEvent:Connect(pushInventory)

	Net.event("UseAutoClicker").OnServerEvent:Connect(function(player, duration)
		duration = tonumber(duration)
		if not duration then
			return
		end
		local profile = DataService.get(player)
		if not profile or (profile.autoClickers[duration] or 0) <= 0 then
			return
		end
		DataService.update(player, function(p)
			p.autoClickers[duration] -= 1
		end)
		pushInventory(player)
		Net.event("AutoClickerActivated"):FireClient(player, duration)
		log:info(`{player.Name} used a {duration}s autoclicker`)
	end)

	Net.func("CheckX2Click").OnServerInvoke = function(player)
		return MonetizationService.ownsX2Click(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		x2Cache[player.UserId] = nil
	end)

	log:info("started")
end

return MonetizationService
