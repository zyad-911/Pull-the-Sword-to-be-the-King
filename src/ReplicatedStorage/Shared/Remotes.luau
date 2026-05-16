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
	PullHit = { name = "PullHit", kind = "Event", container = "RemoteEvents", doc = "c->s: one successful key press (server validates pace)" },
	PullFail = { name = "PullFail", kind = "Event", container = "RemoteEvents", doc = "c->s: missed/timed-out and not reviving (ends session)" },
	SuccessPulling = { name = "SuccessPulling", kind = "Event", container = "RemoteEvents", doc = "s->c: server declares the player KING (authoritative)" },
	LockCamera = { name = "LockCamera", kind = "Event", container = "RemoteEvents", doc = "s->c: lock camera to the sword" },
	ResetCamera = { name = "ResetCamera", kind = "Event", container = "RemoteEvents", doc = "s->c: restore the player camera" },
	HidePlayersFor = { name = "HidePlayersFor", kind = "Event", container = "RemoteEvents", doc = "s->c: player names to hide ({} = show all)" },

	-- Monetised helpers -----------------------------------------------------
	RequestAutoClickers = { name = "RequestAutoClickers", kind = "Event", container = "RemoteEvents", doc = "c->s: ask for current autoclicker inventory" },
	UpdateAutoClickers = { name = "UpdateAutoClickers", kind = "Event", container = "RemoteEvents", doc = "s->c: pushes autoclicker inventory" },
	UseAutoClicker = { name = "UseAutoClicker", kind = "Event", container = "RemoteEvents", doc = "c->s: request to consume an autoclicker" },
	AutoClickerActivated = { name = "AutoClickerActivated", kind = "Event", container = "RemoteEvents", doc = "s->c: autoclicker granted for N seconds" },
	UseRevive = { name = "UseRevive", kind = "Event", container = "RemoteEvents", doc = "c->s: consume a revive and continue the session" },
	CheckX2Click = { name = "CheckX2Click", kind = "Function", container = "RemoteEvents", doc = "c->s invoke: returns whether player owns the X2 Click gamepass" },

	-- Misc ------------------------------------------------------------------
	SendNotification = { name = "SendNotification", kind = "Event", container = "Root", doc = "s->c: { Title, Text } toast" },
} :: { [string]: RemoteDef })

return Remotes
