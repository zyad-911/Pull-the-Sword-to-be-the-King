--!strict
-- Single source of truth for every networking endpoint.
-- The server creates these instances; the client waits for them. Names and
-- locations are kept identical to the original published place so any
-- instance still living in the live game keeps binding correctly.

export type RemoteKind = "Event" | "Function"
export type RemoteContainer = "RemoteEvents" | "Root"

export type RemoteDef = {
	name: string,
	kind: RemoteKind,
	container: RemoteContainer,
	doc: string,
}

local Remotes = {}

-- ReplicatedStorage.<FOLDER_NAME> holds every remote except the few defined
-- with container = "Root" (which sit directly under ReplicatedStorage).
Remotes.FOLDER_NAME = "RemoteEvents"

Remotes.List = ({
	-- Pull session lifecycle ------------------------------------------------
	StartPulling = { name = "StartPulling", kind = "Event", container = "RemoteEvents", doc = "c->s: request to begin a pull (approach lock)" },
	LeavePulling = { name = "LeavePulling", kind = "Event", container = "RemoteEvents", doc = "c->s: exit pull / s->c: confirm exit" },
	StartGameButton = { name = "StartGameButton", kind = "Event", container = "RemoteEvents", doc = "c->s: player pressed Start" },
	StartGame = { name = "StartGame", kind = "Event", container = "RemoteEvents", doc = "s->c: server authorised the minigame to begin" },
	PullHit = { name = "PullHit", kind = "Event", container = "RemoteEvents", doc = "c->s: one sword click (server validates pace, credits ProgressPerHit / X2)" },
	PullFail = { name = "PullFail", kind = "Event", container = "RemoteEvents", doc = "c->s: player abandoned and is not reviving (ends session)" },
	FailPulling = { name = "FailPulling", kind = "Event", container = "RemoteEvents", doc = "s->c: server-authoritative failure (sword fully decayed)" },
	SuccessPulling = { name = "SuccessPulling", kind = "Event", container = "RemoteEvents", doc = "s->c: server declares the player KING (authoritative)" },
	ProgressSync = { name = "ProgressSync", kind = "Event", container = "RemoteEvents", doc = "s->c: throttled push of the authoritative progress (~20Hz) so the bar can't drift from the server" },
	LockCamera = { name = "LockCamera", kind = "Event", container = "RemoteEvents", doc = "s->c: lock camera to the sword" },
	ResetCamera = { name = "ResetCamera", kind = "Event", container = "RemoteEvents", doc = "s->c: restore the player camera" },
	HidePlayersFor = { name = "HidePlayersFor", kind = "Event", container = "RemoteEvents", doc = "s->c: player names to hide ({} = show all)" },

	-- Monetised helpers -----------------------------------------------------
	-- NOTE: these four keep their legacy "AutoClicker" names (the products were
	-- rebranded from autoclickers to "Stop Falling" charges) so live remote
	-- instances keep binding. They now carry Stop-Falling data.
	RequestAutoClickers = { name = "RequestAutoClickers", kind = "Event", container = "RemoteEvents", doc = "c->s: ask for current Stop-Falling charge inventory" },
	UpdateAutoClickers = { name = "UpdateAutoClickers", kind = "Event", container = "RemoteEvents", doc = "s->c: pushes Stop-Falling charge inventory" },
	UseAutoClicker = { name = "UseAutoClicker", kind = "Event", container = "RemoteEvents", doc = "c->s: request to consume a Stop-Falling charge (arg = seconds)" },
	AutoClickerActivated = { name = "AutoClickerActivated", kind = "Event", container = "RemoteEvents", doc = "s->c: decay frozen for N seconds" },
	UseRevive = { name = "UseRevive", kind = "Event", container = "RemoteEvents", doc = "c->s: consume a revive and continue the session" },
	CheckX2Click = { name = "CheckX2Click", kind = "Function", container = "RemoteEvents", doc = "c->s invoke: returns whether player owns the X2 Click gamepass" },

	-- Misc ------------------------------------------------------------------
	SendNotification = { name = "SendNotification", kind = "Event", container = "Root", doc = "s->c: { Title, Text } toast" },
} :: { [string]: RemoteDef })

return Remotes
