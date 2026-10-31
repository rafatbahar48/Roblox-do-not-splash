-- The player's settings (Config.Settings): read from what the server saved
-- (Setting_<id> attributes, server/Progress.luau), changed from the settings
-- window (SettingsUi.luau), and applied here:
--
--   music      the music (the Music sound group, see Music.luau)
--   ambience   the night sounds (the Ambience sound group)
--   effects    splashes, creaks, the creature and the rest (the Effects sound group)
--   shake      camera shake (Fear.luau, DeathScene.luau ask)
--   fov        the camera's field of view (Fear.luau, DeathScene.luau start from it)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local SAVE_DELAY = 0.4 -- seconds a setting must stay put before it is saved

local Settings = {}

local values = {}
local saveTokens = {}
local changed = Instance.new("BindableEvent")
Settings.changed = changed.Event -- (id, value)

for _, setting in Config.Settings do
	values[setting.id] = setting.default
end

local function setGroup(name, on)
	local group = SoundService:FindFirstChild(name)
	if group then
		group.Volume = if on then 1 else 0
	end
end

local function apply(id)
	local value = values[id]
	if id == "music" then
		setGroup("Music", value)
	elseif id == "ambience" then
		setGroup("Ambience", value)
	elseif id == "effects" then
		setGroup("Effects", value)
	elseif id == "fov" then
		workspace.CurrentCamera.FieldOfView = value
	end
end

function Settings.get(id)
	return values[id]
end

-- Changes a setting here straight away, and saves it once it stops changing.
function Settings.set(id, value)
	if values[id] == value then
		return
	end
	values[id] = value
	apply(id)
	changed:Fire(id, value)
	local token = (saveTokens[id] or 0) + 1
	saveTokens[id] = token
	task.delay(SAVE_DELAY, function()
		if saveTokens[id] == token then
			saveTokens[id] = nil
			Remotes.SaveSetting:FireServer(id, value)
		end
	end)
end

function Settings.start()
	for _, setting in Config.Settings do
		local attribute = "Setting_" .. setting.id
		local function fromServer()
			local value = player:GetAttribute(attribute)
			-- A save still on its way wins over what the server last said.
			if value ~= nil and value ~= values[setting.id] and not saveTokens[setting.id] then
				values[setting.id] = value
				apply(setting.id)
				changed:Fire(setting.id, value)
			end
		end
		player:GetAttributeChangedSignal(attribute):Connect(fromServer)
		fromServer()
	end

	task.spawn(function()
		-- The sound groups come from the server (server/Effects.luau).
		for _, name in { "Music", "Ambience", "Effects" } do
			SoundService:WaitForChild(name, 30)
		end
		for _, setting in Config.Settings do
			apply(setting.id)
		end
	end)
end

return Settings
