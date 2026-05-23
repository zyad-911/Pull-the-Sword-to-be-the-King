--!nonstrict
-- ============================================================================
-- BladeMetrics -- single source of truth for the sword's blade length.
-- ============================================================================
--
-- Reads the in-world `Workspace.SwordRock["King's Sword"].Blade` BasePart and
-- exposes its actual length to gameplay code, so RESIZING THE BLADE MESH IN
-- STUDIO auto-syncs the game with zero config tweaks:
--
--   * PullingService    uses getTotalProgress() to set the win threshold.
--   * PullingController uses getBladeLength() for the sword's rise distance.
--   * CameraController  uses getBladeLength() for the pulled-back framing.
--   * UiFxController    uses getTotalProgress() to normalise ProgressSync.
--
-- The blade's "length" is taken as MAX(Size.X, Size.Y, Size.Z), which auto-
-- handles whichever axis the mesh is built along.
--
-- The result is cached on the first successful read (per Lua VM = once per
-- server, once per client). Call BladeMetrics.refresh() if the blade gets
-- replaced or resized live (rare; mostly useful in Studio playtests).
-- ============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local BladeMetrics = {}

-- Used only if the Blade BasePart genuinely cannot be found (e.g. running a
-- test rig with no sword). Matches the original hand-set 30-stud value.
local FALLBACK_LENGTH = 30

local cachedLength: number? = nil

local function readFromWorkspace(): number?
	local rock = workspace:WaitForChild("SwordRock", 5)
	if not rock then return nil end
	local sword = rock:WaitForChild("King's Sword", 5)
	if not sword then return nil end
	local blade = sword:WaitForChild("Blade", 5)
	if not blade or not blade:IsA("BasePart") then return nil end
	local s = blade.Size
	return math.max(s.X, s.Y, s.Z)
end

-- Length of the blade in studs. Cached on first call.
function BladeMetrics.getBladeLength(): number
	if cachedLength == nil then
		cachedLength = readFromWorkspace() or FALLBACK_LENGTH
	end
	return cachedLength
end

-- The bar's full value. Derived: a longer blade = proportionally more clicks
-- needed = a longer pull. Tuned via GameConfig.ProgressPerStud.
function BladeMetrics.getTotalProgress(): number
	return BladeMetrics.getBladeLength() * GameConfig.ProgressPerStud
end

-- Force a re-read of the blade length (e.g. you replaced the blade mesh in a
-- live Studio playtest). Normal play never needs this.
function BladeMetrics.refresh()
	cachedLength = nil
end

return BladeMetrics
