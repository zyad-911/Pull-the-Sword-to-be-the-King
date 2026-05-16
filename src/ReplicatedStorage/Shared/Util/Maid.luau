--!strict
-- Minimal connection / instance janitor so controllers can tear down cleanly.

export type Task = RBXScriptConnection | Instance | () -> () | { Destroy: (any) -> () }

local Maid = {}
Maid.__index = Maid

export type Maid = typeof(setmetatable({} :: { _tasks: { Task } }, Maid))

function Maid.new(): Maid
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid.give(self: Maid, task: Task): Task
	table.insert(self._tasks, task)
	return task
end

local function cleanupOne(task: Task)
	if typeof(task) == "RBXScriptConnection" then
		(task :: RBXScriptConnection):Disconnect()
	elseif typeof(task) == "function" then
		(task :: () -> ())()
	elseif typeof(task) == "Instance" then
		(task :: Instance):Destroy()
	elseif type(task) == "table" and typeof((task :: any).Destroy) == "function" then
		(task :: any):Destroy()
	end
end

function Maid.clean(self: Maid)
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		cleanupOne(tasks[i])
	end
end

Maid.Destroy = Maid.clean

return Maid
