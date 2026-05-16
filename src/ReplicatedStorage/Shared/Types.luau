--!strict
-- Shared Luau types.

export type AutoClickerInventory = { [number]: number }

export type Profile = {
	minutes: number,
	revives: number,
	autoClickers: AutoClickerInventory,
	hasX2Click: boolean,
}

export type Notification = {
	Title: string,
	Text: string,
}

return {}
