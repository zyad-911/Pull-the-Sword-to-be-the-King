--!strict
-- Single source of truth for admins (was duplicated across two server scripts).

local AdminConfig = {}

AdminConfig.Admins = {
	["ZeZoo_9876"] = true,
}

function AdminConfig.isAdmin(player: Player): boolean
	return AdminConfig.Admins[player.Name] == true
end

return AdminConfig
