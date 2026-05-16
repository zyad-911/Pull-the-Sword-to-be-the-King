--!strict
-- Typed access to every remote. The server lazily creates instances (and the
-- RemoteEvents folder) from the Remotes manifest; the client waits for them.
-- This removes every ad-hoc Instance.new / WaitForChild chain from gameplay code.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(script.Parent.Remotes)

local IS_SERVER = RunService:IsServer()
local WAIT_TIMEOUT = 30

local Net = {}

local cache: { [string]: Instance } = {}

local function classNameFor(kind: string): string
	return if kind == "Function" then "RemoteFunction" else "RemoteEvent"
end

local function getContainer(container: string): Instance
	if container == "Root" then
		return ReplicatedStorage
	end

	local existing = ReplicatedStorage:FindFirstChild(Remotes.FOLDER_NAME)
	if existing then
		return existing
	end
	if IS_SERVER then
		local folder = Instance.new("Folder")
		folder.Name = Remotes.FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(Remotes.FOLDER_NAME, WAIT_TIMEOUT) :: Instance
end

local function resolve(def: Remotes.RemoteDef): Instance
	local cached = cache[def.name]
	if cached then
		return cached
	end

	local container = getContainer(def.container)
	local inst = container:FindFirstChild(def.name)
	if not inst then
		if IS_SERVER then
			inst = Instance.new(classNameFor(def.kind))
			inst.Name = def.name
			inst.Parent = container
		else
			inst = container:WaitForChild(def.name, WAIT_TIMEOUT)
		end
	end
	assert(inst, `Net: remote "{def.name}" could not be resolved`)
	cache[def.name] = inst
	return inst
end

-- Server-only: pre-create every remote so clients never race a missing instance.
function Net.init()
	assert(IS_SERVER, "Net.init() is server-only")
	for _, def in Remotes.List do
		resolve(def)
	end
end

function Net.event(key: string): RemoteEvent
	local def = Remotes.List[key]
	assert(def, `Net: unknown remote "{key}"`)
	assert(def.kind == "Event", `Net: "{key}" is a RemoteFunction, use Net.func`)
	return resolve(def) :: RemoteEvent
end

function Net.func(key: string): RemoteFunction
	local def = Remotes.List[key]
	assert(def, `Net: unknown remote "{key}"`)
	assert(def.kind == "Function", `Net: "{key}" is a RemoteEvent, use Net.event`)
	return resolve(def) :: RemoteFunction
end

return Net
