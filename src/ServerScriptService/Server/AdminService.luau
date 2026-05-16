--!nonstrict
-- Ban store + chat admin commands. Consolidates the two legacy admin scripts,
-- removes the duplicated admin list, fixes the success messages that wrongly
-- said "Player not found!", and replaces the removed player:SendNotification API.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdminConfig = require(Shared.Config.AdminConfig)
local Log = require(Shared.Util.Log)
local MonetizationService = require(script.Parent.MonetizationService)
local NotificationService = require(script.Parent.NotificationService)

local log = Log.new("Admin")
local BanStore = DataStoreService:GetDataStore("BannedPlayers")

local AdminService = {}

local function findPlayer(name: string): Player?
	for _, p in Players:GetPlayers() do
		if p.Name:lower() == name:lower() then
			return p
		end
	end
	return nil
end

local function resolveTarget(caller: Player, nameArg: string?): Player?
	if nameArg then
		return findPlayer(nameArg)
	end
	return caller
end

local function onChat(player: Player, msg: string)
	if not AdminConfig.isAdmin(player) then
		return
	end

	local args = {}
	for word in msg:gmatch("%S+") do
		table.insert(args, word)
	end
	if #args == 0 then
		return
	end
	local cmd = args[1]:lower()

	if cmd == "/kick" and args[2] then
		local target = findPlayer(args[2])
		if target then
			local reason = table.concat(args, " ", 3)
			target:Kick(reason ~= "" and reason or "You have been kicked.")
		else
			NotificationService.send(player, "Error", "Player not found!")
		end
	elseif cmd == "/ban" and args[2] then
		local target = findPlayer(args[2])
		if target then
			local ok = pcall(function()
				BanStore:SetAsync(tostring(target.UserId), true)
			end)
			if ok then
				target:Kick("You have been banned.")
				NotificationService.send(player, "Success", `Banned {target.Name}`)
			else
				NotificationService.send(player, "Error", "Ban failed.")
			end
		else
			NotificationService.send(player, "Error", "Player not found!")
		end
	elseif cmd == "/unban" and args[2] then
		local id = tonumber(args[2])
		if not id then
			local found = findPlayer(args[2])
			id = found and found.UserId or nil
		end
		if id then
			local ok = pcall(function()
				BanStore:RemoveAsync(tostring(id))
			end)
			NotificationService.send(player, ok and "Success" or "Error", ok and `Unbanned {args[2]}` or "Unban failed.")
		else
			NotificationService.send(player, "Error", "Player not found!")
		end
	elseif cmd == "/x2" and args[2] and args[2]:lower() == "click" then
		local target = resolveTarget(player, args[3])
		if not target then
			NotificationService.send(player, "Error", "Player not found!")
			return
		end
		MonetizationService.grantX2Click(target)
		NotificationService.send(player, "Success", `Gave X2 Click to {target.Name}`)
	elseif (cmd == "/+1" or cmd == "/+2" or cmd == "/+3") and args[2] and args[2]:lower() == "revive" then
		local amount = tonumber(cmd:sub(2)) or 1
		local target = resolveTarget(player, args[3])
		if not target then
			NotificationService.send(player, "Error", "Player not found!")
			return
		end
		MonetizationService.grantRevives(target, amount)
		NotificationService.send(player, "Success", `Gave {amount} revive(s) to {target.Name}`)
	elseif (cmd == "/10s" or cmd == "/20s") and args[2] and args[2]:lower() == "autoclicker" then
		local duration = tonumber(cmd:match("%d+"))
		local target = resolveTarget(player, args[3])
		if not target then
			NotificationService.send(player, "Error", "Player not found!")
			return
		end
		MonetizationService.grantAutoClicker(target, duration, 1)
		NotificationService.send(player, "Success", `Gave a {duration}s AutoClicker to {target.Name}`)
	end
end

local function onAdded(player: Player)
	local ok, banned = pcall(function()
		return BanStore:GetAsync(tostring(player.UserId))
	end)
	if ok and banned then
		player:Kick("You are banned from this game.")
		return
	end
	player.Chatted:Connect(function(msg)
		onChat(player, msg)
	end)
end

function AdminService.start()
	Players.PlayerAdded:Connect(onAdded)
	for _, p in Players:GetPlayers() do
		task.spawn(onAdded, p)
	end
	log:info("started")
end

return AdminService
