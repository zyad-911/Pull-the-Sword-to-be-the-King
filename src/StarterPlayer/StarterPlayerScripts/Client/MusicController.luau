--!nonstrict
-- Owns ambient vs. sword music and the mute toggle in the Main UI. Other
-- controllers just call MusicController.setPulling(true/false).

local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local MUSIC_VOLUME = 0.5
local SWORD_VOLUME = 0.25

local MusicController = {}

local muted = false
local pulling = false
local music: Sound?
local swordMusic: Sound?

local function apply()
	if not music or not swordMusic then
		return
	end
	music.Volume = muted and 0 or MUSIC_VOLUME
	swordMusic.Volume = muted and 0 or SWORD_VOLUME

	if pulling then
		if music.IsPlaying then
			music:Stop()
		end
		if not swordMusic.IsPlaying then
			swordMusic:Play()
		end
	else
		if swordMusic.IsPlaying then
			swordMusic:Stop()
		end
		if not music.IsPlaying then
			music:Play()
		end
	end
end

function MusicController.setPulling(value: boolean)
	pulling = value
	apply()
end

function MusicController.start()
	music = SoundService:WaitForChild("Music")
	swordMusic = SoundService:WaitForChild("SwordMusic")

	local playerGui = player:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main")
	local running = main:WaitForChild("MusicRunning")
	local mutedBtn = main:WaitForChild("MusicMuted")

	running.MouseButton1Click:Connect(function()
		muted = true
		running.Visible = false
		mutedBtn.Visible = true
		apply()
	end)
	mutedBtn.MouseButton1Click:Connect(function()
		muted = false
		mutedBtn.Visible = false
		running.Visible = true
		apply()
	end)

	apply()
end

return MusicController
