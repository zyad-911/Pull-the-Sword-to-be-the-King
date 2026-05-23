--!strict
-- Shared Luau types.

-- Stop-Falling charge inventory, keyed by the freeze duration in seconds (5/10).
-- (Field is still named `autoClickers` for storage continuity -- see Profile.)
export type StopChargeInventory = { [number]: number }

export type Profile = {
	minutes: number,
	revives: number,
	-- Stop-Falling charges. Keyed by freeze seconds (5 / 10). The field keeps
	-- the legacy `autoClickers` name so the saved DataStore shape is unchanged.
	autoClickers: StopChargeInventory,
	hasX2Click: boolean,
	-- Inventory schema version. 2 = Stop-Falling slots (5/10). 1 (or absent) =
	-- legacy autoclicker slots (10/20); DataService migrates it once on load.
	invVersion: number,
}

export type Notification = {
	Title: string,
	Text: string,
}

return {}
