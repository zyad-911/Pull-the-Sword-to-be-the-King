All the trees arround the map has this ServerScript:

```--PUT INSIDE A LEAVES MODEL--
--ALSO PUT A SOUND INSIDE THE LEAVES--

local RunService = game:GetService("RunService")
local scriptParent = script.Parent
local pos = scriptParent.Position
local tall = scriptParent.Size.Y / 2
local T = -99999
local rand = (math.random(0, 20)) / 10
script.Parent.Sound:Play()

local function updatePosition()
	local x = pos.x + (math.sin(T + (pos.x / 5)) * math.sin(T / 9)) / 3
	local z = pos.z + (math.sin(T + (pos.z / 6)) * math.sin(T / 12)) / 4

	scriptParent.CFrame = CFrame.new(x, pos.y, z) * CFrame.Angles((z - pos.z) / tall, 0, (x - pos.x) / -tall)

	T = T + 0.12
end

RunService.Heartbeat:Connect(updatePosition)
```
