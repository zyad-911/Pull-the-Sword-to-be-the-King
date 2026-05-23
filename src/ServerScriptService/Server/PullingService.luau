--!nonstrict
-- Authoritative click-spam minigame. The client renders the sword and forwards
-- raw click events; the SERVER decides progress, runs the decay tick, and is
-- the only thing allowed to declare a win or a fail. This closes the legacy
-- exploits where a client could fire SuccessPulling / BadgeEvent / a fake
-- PullingTime and instantly become king.
--
-- TWO-CLICK ENTRY:
--   * 1st sword click  -> StartPulling  -> lock camera + hide players. NO
--                         session yet, so the decay clock is NOT running.
--   * 2nd sword click  -> StartGameButton -> openSession: the session opens,
--                         the decay starts, and that click counts as a pull.
--
-- STOP FALLING:
--   A paid "Stop Falling" charge freezes the decay tick for N seconds
--   (MonetizationService.isDecayFrozen). The player still clicks the sword to
--   gain ground -- the freeze just removes the drain, it doesn't auto-win.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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

-- How often the server pushes its authoritative progress to the client so the
-- UI bar can't visibly drift from the server. 0.05s = 20 Hz, low bandwidth.
local PROGRESS_SYNC_INTERVAL = 0.05

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

local function isWithinApproach(player: Player): boolean
	local char = player.Character
	local anchor = getSwordAnchor()
	if not char or not anchor then
		return true -- best-effort: don't block if char/sword aren't loaded
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return true
	end
	return (hrp.Position - anchor.Position).Magnitude <= GameConfig.MaxApproachDistance
end

-- Rejects whatever client-side optimistic state the player applied when they
-- "entered" the minigame. Used by every server-side rejection path.
local function rejectEntry(player: Player)
	Net.event("HidePlayersFor"):FireClient(player, {})
	Net.event("LeavePulling"):FireClient(player)
	Net.event("ResetCamera"):FireClient(player)
end

-- 1st sword click. Enter pulling mode: lock the camera and hide the other
-- players. Deliberately does NOT open a session -- the decay clock only starts
-- when the player clicks the sword a second time (openSession below).
local function onStartPulling(player: Player)
	if not isWithinApproach(player) then
		rejectEntry(player)
		return
	end
	local names = {}
	for _, p in Players:GetPlayers() do
		table.insert(names, p.Name)
	end
	Net.event("HidePlayersFor"):FireClient(player, names)
	Net.event("LockCamera"):FireClient(player)
end

-- 2nd sword click (or the legacy Start button). Opens the session: the decay
-- starts now, and the triggering click is the player's first pull. Idempotent
-- -- a double-fire just no-ops on the already-live session.
local function openSession(player: Player)
	if sessions[player] then
		return -- already live; idempotent
	end
	if not isWithinApproach(player) then
		rejectEntry(player)
		return
	end

	local x2 = MonetizationService.ownsX2Click(player)
	local now = os.clock()
	sessions[player] = {
		startClock = now,
		progress = 0,
		perHit = x2 and GameConfig.ProgressPerHitX2 or GameConfig.ProgressPerHit,
		lastHit = 0,
		lastTick = now,
		-- Delay the first ProgressSync a touch so the player's first PullHit
		-- has time to land before we start broadcasting -- otherwise an early
		-- "progress = 0" sync could fight the client's optimistic first click.
		lastSync = now,
		finished = false,
		failedAt = nil,
	}
	-- NOTE: the camera was already locked by onStartPulling (the 1st click).
	-- We deliberately DON'T re-fire LockCamera here -- a re-lock would make the
	-- camera recapture its rest height after the sword has begun rising.
	Net.event("StartGame"):FireClient(player)
	log:info(`{player.Name} started a pull (x2={tostring(x2)})`)
end

local function completeGame(player: Player, session)
	if session.finished then
		return
	end
	session.finished = true
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

local function failGame(player: Player, session)
	if session.finished then
		return
	end
	session.finished = true
	session.failedAt = os.clock()
	-- DON'T endSession yet — keep the session around so the client's revive
	-- (which lands a few hundred ms later) can resurrect it. The tick loop
	-- reaps the session after FailedSessionGraceSeconds.
	Net.event("FailPulling"):FireClient(player)
end

-- One sword click. Rate-capped, then credits the per-hit (X2-aware).
local function onHit(player: Player)
	local session = sessions[player]
	if not session or session.finished then
		return
	end
	local now = os.clock()
	if now - session.lastHit < GameConfig.MinHitIntervalSeconds then
		return -- pacing-rejected hit (anti-autoclicker): don't credit progress
	end
	session.lastHit = now

	session.progress += session.perHit
	if session.progress >= GameConfig.TotalProgress then
		session.progress = GameConfig.TotalProgress
		completeGame(player, session)
	end
end

local function onFail(player: Player)
	-- Client abandoned (exit, disconnect) and is NOT reviving -> tear down.
	local session = sessions[player]
	if session then
		session.finished = true
	end
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
	-- Restore the sword to half-pulled and reset the click pacing windows.
	-- Also resurrects a session that just failed (session.finished == true and
	-- we're inside FailedSessionGraceSeconds): the tick loop's "if finished
	-- then continue" branch starts ticking forward again.
	session.progress = GameConfig.TotalProgress * GameConfig.ReviveProgressFraction
	session.lastHit = os.clock()
	session.lastTick = os.clock()
	session.lastSync = 0
	session.finished = false
	session.failedAt = nil
end

local function onLeave(player: Player)
	endSession(player)
	Net.event("HidePlayersFor"):FireClient(player, {})
	Net.event("LeavePulling"):FireClient(player)
	Net.event("ResetCamera"):FireClient(player)
end

local function tickSessions()
	local now = os.clock()
	for player, session in sessions do
		if session.finished then
			-- Reap failed sessions once the revive grace window has elapsed.
			if session.failedAt and (now - session.failedAt) >= GameConfig.FailedSessionGraceSeconds then
				endSession(player)
			end
			continue
		end
		local dt = now - session.lastTick
		session.lastTick = now

		-- A paid "Stop Falling" charge freezes the decay entirely for its
		-- duration -- and, since the player can't lose ground while frozen,
		-- can't fail either. Otherwise the sword drains (faster once the
		-- player goes idle) and a drain to 0 fails the pull.
		if not MonetizationService.isDecayFrozen(player) then
			local idle = (now - session.lastHit) > GameConfig.IdleThresholdSeconds
			local rate = idle and GameConfig.DecayPerSecondIdle or GameConfig.DecayPerSecondActive
			session.progress -= rate * dt

			if session.progress <= 0 then
				session.progress = 0
				if (now - session.startClock) >= GameConfig.FailGraceSeconds then
					failGame(player, session)
				end
			end
		end

		-- Push the authoritative progress to the client so the UI bar can't
		-- visibly drift. Throttled to PROGRESS_SYNC_INTERVAL (~20Hz).
		if now - session.lastSync >= PROGRESS_SYNC_INTERVAL then
			session.lastSync = now
			Net.event("ProgressSync"):FireClient(player, session.progress)
		end
	end
end

function PullingService.start()
	Net.event("StartPulling").OnServerEvent:Connect(onStartPulling)
	Net.event("StartGameButton").OnServerEvent:Connect(openSession)
	Net.event("PullHit").OnServerEvent:Connect(onHit)
	Net.event("PullFail").OnServerEvent:Connect(onFail)
	Net.event("UseRevive").OnServerEvent:Connect(onUseRevive)
	Net.event("LeavePulling").OnServerEvent:Connect(onLeave)

	Players.PlayerRemoving:Connect(endSession)
	RunService.Heartbeat:Connect(tickSessions)
	log:info("started")
end

return PullingService
