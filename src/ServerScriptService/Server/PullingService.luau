--!nonstrict
-- Authoritative minigame. The client renders the reaction UI, but the SERVER
-- owns the session: it paces hits, decides when the player wins, awards the
-- badge, broadcasts the king message and submits the leaderboard time. This
-- closes the legacy exploits where a client could fire SuccessPulling /
-- BadgeEvent / a fake PullingTime and instantly become king.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeService = game:GetService("BadgeService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Util.Log)

local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MonetizationService = require(script.Parent.MonetizationService)

local log = Log.new("Pulling")
local BADGE_ID = 3516739710742552

local PullingService = {}

local sessions: { [Player]: any } = {}

local function getSwordAnchor(): BasePart?
	local rock = workspace:FindFirstChild("SwordRock")
	local sword = rock and rock:FindFirstChild("King's Sword")
	local handle = sword and sword:FindFirstChild("Handle")
	return handle and handle:FindFirstChild("CamLock")
end

local function endSession(player: Player)
	sessions[player] = nil
end

local function onStartPulling(player: Player)
	-- Server-side proximity check (anti teleport-and-win abuse).
	local char = player.Character
	local anchor = getSwordAnchor()
	if char and anchor then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - anchor.Position).Magnitude > GameConfig.MaxApproachDistance then
			Net.event("ResetCamera"):FireClient(player)
			return
		end
	end

	local names = {}
	for _, p in Players:GetPlayers() do
		table.insert(names, p.Name)
	end
	Net.event("HidePlayersFor"):FireClient(player, names)
	Net.event("LockCamera"):FireClient(player)
end

local function onStartGame(player: Player)
	local x2 = MonetizationService.ownsX2Click(player)
	sessions[player] = {
		startClock = os.clock(),
		progress = 0,
		perHit = x2 and GameConfig.ProgressPerHitX2 or GameConfig.ProgressPerHit,
		lastHit = 0,
	}
	Net.event("LockCamera"):FireClient(player)
	Net.event("StartGame"):FireClient(player)
	log:info(`{player.Name} started a pull (x2={tostring(x2)})`)
end

local function completeGame(player: Player, session)
	endSession(player)

	local duration = os.clock() - session.startClock
	if duration < GameConfig.MinPullDurationSeconds then
		log:warn(`{player.Name} completion rejected: {string.format("%.2f", duration)}s below floor`)
		return
	end

	task.spawn(function()
		local ok, has = pcall(function()
			return BadgeService:UserHasBadgeAsync(player.UserId, BADGE_ID)
		end)
		if ok and not has then
			pcall(function()
				BadgeService:AwardBadge(player.UserId, BADGE_ID)
			end)
		end
	end)

	pcall(function()
		TextChatService:BroadcastSystemMessage(
			`👑 {player.DisplayName} has pulled the King's Sword and become the new KING!`,
			Enum.TextChatColor.Blue
		)
	end)

	LeaderboardService.submitPull(player, duration)
	Net.event("SuccessPulling"):FireClient(player)
	log:info(`{player.Name} is KING ({string.format("%.2f", duration)}s)`)
end

local function onHit(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local now = os.clock()
	if now - session.lastHit < GameConfig.MinHitIntervalSeconds then
		return -- exploit-rate hit: ignore, do not credit progress
	end
	session.lastHit = now
	session.progress += session.perHit
	if session.progress >= GameConfig.TotalProgress then
		completeGame(player, session)
	end
end

local function onFail(player: Player)
	-- Client failed and is NOT reviving -> tear the session down.
	endSession(player)
end

local function onUseRevive(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local profile = DataService.get(player)
	if not profile or profile.revives <= 0 then
		return
	end
	DataService.update(player, function(p)
		p.revives -= 1
	end)
	-- Keep the session (and accumulated progress) alive; reset pacing window.
	session.lastHit = 0
end

local function onLeave(player: Player)
	endSession(player)
	Net.event("HidePlayersFor"):FireClient(player, {})
	Net.event("LeavePulling"):FireClient(player)
	Net.event("ResetCamera"):FireClient(player)
end

function PullingService.start()
	Net.event("StartPulling").OnServerEvent:Connect(onStartPulling)
	Net.event("StartGameButton").OnServerEvent:Connect(onStartGame)
	Net.event("PullHit").OnServerEvent:Connect(onHit)
	Net.event("PullFail").OnServerEvent:Connect(onFail)
	Net.event("UseRevive").OnServerEvent:Connect(onUseRevive)
	Net.event("LeavePulling").OnServerEvent:Connect(onLeave)

	Players.PlayerRemoving:Connect(endSession)
	log:info("started")
end

return PullingService
