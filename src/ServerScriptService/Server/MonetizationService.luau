--!nonstrict
-- ProcessReceipt + gamepass checks + Stop-Falling/revive grants. All grants go
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

-- Decay-freeze tracker. Keyed by UserId; the value is the os.clock() timestamp
-- at which the active "Stop Falling" freeze expires. PullingService queries
-- this every tick to decide whether to apply decay to that player's session.
local decayFrozenUntil: { [number]: number } = {}

-- Returns true if the player's sword decay is currently frozen by an active
-- paid "Stop Falling" charge. PullingService skips its decay tick while true.
function MonetizationService.isDecayFrozen(player: Player): boolean
	local expiry = decayFrozenUntil[player.UserId]
	return expiry ~= nil and os.clock() < expiry
end

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

-- Grants `amount` Stop-Falling charges of the given freeze duration (5 or 10).
function MonetizationService.grantStopCharge(player: Player, seconds: number, amount: number)
	DataService.update(player, function(p)
		p.autoClickers[seconds] = (p.autoClickers[seconds] or 0) + amount
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
	if id == P.StopFalling5s then
		MonetizationService.grantStopCharge(player, 5, 1)
	elseif id == P.StopFalling10s then
		MonetizationService.grantStopCharge(player, 10, 1)
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

	Net.event("UseAutoClicker").OnServerEvent:Connect(function(player, seconds)
		seconds = tonumber(seconds)
		if not seconds then
			return
		end
		-- Can't stack a second freeze. The server processes remotes serially,
		-- so this also makes a double-tap consume only ONE charge (the second
		-- UseAutoClicker sees the freeze the first one just started).
		if MonetizationService.isDecayFrozen(player) then
			return
		end
		local profile = DataService.get(player)
		-- The inventory key IS the freeze duration (5 or 10). Owning a charge of
		-- that key is the validation -- a forged `seconds` just won't be owned.
		if not profile or (profile.autoClickers[seconds] or 0) <= 0 then
			return
		end
		DataService.update(player, function(p)
			p.autoClickers[seconds] -= 1
		end)
		pushInventory(player)
		-- Server-authoritative freeze window. PullingService skips its decay
		-- tick while this is active; without it a client could claim a freeze
		-- it never paid for.
		decayFrozenUntil[player.UserId] = os.clock() + seconds
		Net.event("AutoClickerActivated"):FireClient(player, seconds)
		log:info(`{player.Name} used a {seconds}s Stop Falling`)
	end)

	Net.func("CheckX2Click").OnServerInvoke = function(player)
		return MonetizationService.ownsX2Click(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		x2Cache[player.UserId] = nil
		decayFrozenUntil[player.UserId] = nil
	end)

	log:info("started")
end

return MonetizationService
