--!strict
-- Thin tagged logging wrapper so server/client output stays greppable.

local Log = {}
Log.__index = Log

export type Logger = typeof(setmetatable({} :: { tag: string }, Log))

function Log.new(tag: string): Logger
	return setmetatable({ tag = tag }, Log)
end

function Log.info(self: Logger, ...: any)
	print(`[{self.tag}]`, ...)
end

function Log.warn(self: Logger, ...: any)
	warn(`[{self.tag}]`, ...)
end

return Log
