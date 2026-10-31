-- The cave at the start of stage 1 (server/CaveBuilder.luau), on this
-- screen: water dripping and wind through its mouth while you are in it,
-- its torches flickering, and what happens when your party arrives (the
-- CaveArrival attribute, server/Progress.luau). A few seconds of quiet, then
-- something out past the mouth steps on a stick, growls two seconds later,
-- and a note says this is the last chance to stock up, with a button to the
-- shop. Practice runs skip the scare: nothing is out there.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Candy = require(ReplicatedStorage.Shared.Candy)
local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)
local ShopUi = require(script.Parent.ShopUi)
local Sounds = require(script.Parent.Sounds)
local Windows = require(script.Parent.Windows)

local player = Players.LocalPlayer

local CAVE = Config.Cave
local TILE_TOP = Config.Room.SurfaceY + Config.Room.TileHeight
local DRIPS_VOLUME = 0.6
local WIND_VOLUME = { 0.15, 0.5 } -- at the back, and at the mouth
local FRESH = 10 -- seconds an arrival is still news, for a screen that loads late
local NOTE_DELAY = 1.2 -- seconds after the growl starts
local WIDTH, HEIGHT = 560, 380
local TOP, SIDE = Candy.WINDOW_TOP, Candy.WINDOW_SIDE
local NOTE_TEXT = "This is your last chance to grab some supplies before you face the unknown."
local NOTE_HINT = "Better to have a second chance than to start over."

local Cave = {}

local note
local openNote -- closes the other menu windows

local function root()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

local function inCave()
	local part = root()
	return part ~= nil and Zones.at(part.Position) == "cave"
end

-- Plays a Config.Sounds sound once out in the world at position, for this
-- player: full volume out to near studs, fading beyond.
local function playAt(name, position, volume, near)
	local id = Config.Sounds[name]
	if not id or id == "" then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain
	attachment.WorldPosition = position
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = near
	sound.RollOffMaxDistance = 300
	sound.SoundGroup = SoundService:FindFirstChild("Effects")
	sound.Parent = attachment
	sound:Play()
	Debris:AddItem(attachment, 12)
end

local function buildNote()
	local gui = Candy.create("ScreenGui", {
		Name = "Cave",
		ResetOnSpawn = false,
		DisplayOrder = 7,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local window, _, closeButton = Candy.window(gui, { name = "LastChance", size = UDim2.fromOffset(WIDTH, HEIGHT), title = "LAST CHANCE" })
	note = window
	note.Visible = false
	Candy.fit(note, Vector2.new(WIDTH + 10, HEIGHT + 10), 24)
	local function close()
		note.Visible = false
	end
	openNote = Windows.add(close)
	closeButton.Activated:Connect(close)

	-- A Self-Revive: the second chance.
	Candy.art("robux_self_revive", { Position = UDim2.fromOffset(SIDE, TOP - 4), Size = UDim2.fromOffset(124, 124), ZIndex = 3, Parent = note })
	Candy.text({
		Position = UDim2.fromOffset(SIDE + 140, TOP - 8),
		Size = UDim2.new(1, -2 * SIDE - 140, 0, 96),
		TextSize = 26,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = NOTE_TEXT,
		Parent = note,
	})
	Candy.text({
		Position = UDim2.fromOffset(SIDE + 140, TOP + 94),
		Size = UDim2.new(1, -2 * SIDE - 140, 0, 54),
		Font = Enum.Font.GothamMedium,
		TextSize = 19,
		TextWrapped = true,
		TextColor3 = Candy.MUTED,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = NOTE_HINT,
		Parent = note,
	})

	local ready = Candy.button(note, {
		size = UDim2.fromOffset(170, 62),
		position = UDim2.new(0, SIDE, 1, -Candy.WINDOW_BOTTOM - 66),
		text = "I'm ready",
	})
	ready.Activated:Connect(close)
	local shop = Candy.button(note, {
		size = UDim2.new(1, -2 * SIDE - 182, 0, 62),
		position = UDim2.new(0, SIDE + 182, 1, -Candy.WINDOW_BOTTOM - 66),
		text = "Open shop",
		color = Candy.LEMON,
	})
	shop.Activated:Connect(function()
		close()
		ShopUi.open("shop")
	end)
end

local function showNote()
	openNote()
	note.Position = UDim2.fromScale(0.5, 0.58)
	note.Visible = true
	TweenService:Create(note, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
end

-- Eases a looped sound toward a volume, playing it only while it can be heard.
local function fade(sound, target, dt)
	if not sound then
		return
	end
	sound.Volume += (target - sound.Volume) * math.min(1, dt * 1.5)
	if sound.Volume > 0.01 and not sound.IsPlaying then
		sound:Play()
	elseif sound.Volume <= 0.01 and sound.IsPlaying then
		sound:Stop()
	end
end

function Cave.start()
	buildNote()

	local drips = Sounds.loop("CaveDrips", 0, "Ambience")
	local wind = Sounds.loop("CaveWind", 0, "Ambience")
	local flames = {} -- { light, base brightness, seed }
	task.spawn(function()
		local folder = workspace:WaitForChild("Map"):WaitForChild("Stage01"):WaitForChild("Cave")
		local function add(part)
			local light = part.Name == "Flame" and part:FindFirstChildOfClass("PointLight")
			if light then
				table.insert(flames, { light = light, base = light.Brightness, seed = math.random() * 100 })
			end
		end
		folder.ChildAdded:Connect(function(part)
			-- Its light may still be on its way.
			task.defer(add, part)
		end)
		for _, part in folder:GetChildren() do
			add(part)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local part = root()
		local here = part ~= nil and Zones.at(part.Position) == "cave"
		local depth = if part then math.clamp(part.Position.Z / CAVE.Length, 0, 1) else 0
		fade(drips, if here then DRIPS_VOLUME else 0, dt)
		fade(wind, if here then WIND_VOLUME[1] + (WIND_VOLUME[2] - WIND_VOLUME[1]) * depth else 0, dt)
		if here then
			local now = os.clock()
			for _, flame in flames do
				flame.light.Brightness = flame.base * (0.9 + 0.35 * math.noise(now * 5, flame.seed))
			end
		end
	end)

	-- Each arrival starts it over; one still under way stops.
	local arrival = 0
	local function arrive()
		arrival += 1
		local mine = arrival
		local function still()
			return mine == arrival and inCave()
		end
		task.wait(CAVE.ArrivalDelay)
		if not still() then
			return
		end
		local side = if math.random() < 0.5 then -1 else 1
		local mouth = Vector3.new(0, TILE_TOP + 1, CAVE.Length)
		playAt("StickSnap", mouth + Vector3.new(side * math.random(4, 12), 0, 12), 1.4, 25)
		task.wait(CAVE.GrowlDelay)
		if not still() then
			return
		end
		playAt("CaveGrowl", mouth + Vector3.new(-side * math.random(6, 18), 1, 34), 2, 50)
		task.wait(NOTE_DELAY)
		if still() then
			showNote()
		end
	end
	local function onArrival()
		local at = player:GetAttribute("CaveArrival")
		if type(at) == "number" and workspace:GetServerTimeNow() - at < FRESH and player:GetAttribute("Practice") ~= true then
			task.spawn(arrive)
		end
	end
	player:GetAttributeChangedSignal("CaveArrival"):Connect(onArrival)
	onArrival()
end

return Cave
