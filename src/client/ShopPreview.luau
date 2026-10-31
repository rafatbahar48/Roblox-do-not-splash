-- The 3D on the shop's cards (ShopUi.luau), each in its own ViewportFrame:
--
--   avatar   a copy of your own avatar wearing a skin or an accessory
--            (shared/SkinLook.luau, shared/AccessoryLook.luau), turning slowly
--   model    one of the shop's 3D models (ReplicatedStorage.ShopModels, made
--            in Meshy from the shop's icons), spinning and bobbing
--
-- Each returns a function that poses it for a moment (seconds since the shop
-- opened), or nil if there is nothing to show.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessoryLook = require(ReplicatedStorage.Shared.AccessoryLook)
local SkinLook = require(ReplicatedStorage.Shared.SkinLook)

local player = Players.LocalPlayer

local FOV = 30
local AVATAR_FRAMING = 1.4 -- how much bigger than the avatar the view is
local AVATAR_LIFT = 0.07 -- how far up from its middle the camera aims, in heights
local HEAD_FRAMING = 0.7 -- for things worn on the head: head and shoulders
local MODEL_FRAMING = 1.5
local TURN_SPEED = 0.9 -- radians a second
local SPIN_SPEED = 1.3
local BOB = 0.06 -- how far a model bobs, in its own sizes
-- Flat things (tokens, a bubble) dwell facing you and flip quickly through
-- edge-on: how much of the turn is eased that way (0 is a steady spin).
local DWELL = 0.45
local ROCK = 0.9 -- radians a tipped-up model rocks either way (its underside never shows)

local ShopPreview = {}

-- Where 3D models for the shop come from, named like their icon art.
local function modelsFolder()
	return ReplicatedStorage:FindFirstChild("ShopModels")
end

function ShopPreview.hasModel(name)
	local folder = modelsFolder()
	return folder ~= nil and folder:FindFirstChild(name) ~= nil
end

-- Puts a model in a viewport, with a camera looking at it from the front.
-- Returns the model's centre and size.
local function stage(viewport, model, framing, lift)
	viewport:ClearAllChildren()
	-- A WorldModel, so joints and welds hold it together as it turns.
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	model:PivotTo(CFrame.new())
	model.Parent = world

	local box, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	local tall = math.max(size.Y, size.X * 0.8)
	local distance = (tall / 2) / math.tan(math.rad(FOV / 2)) * framing
	local aim = Vector3.new(0, tall * lift, 0)
	camera.CFrame = CFrame.lookAt(aim + Vector3.new(0, 0, -distance), aim)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return box.Position, size
end

-- A plain copy of your avatar, standing still, or nil without a character.
local function copyAvatar()
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return nil
	end
	local was = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = was
	if not copy then
		return nil
	end
	local extra = copy:FindFirstChild(AccessoryLook.NAME)
	if extra then
		extra:Destroy()
	end
	for _, item in copy:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("Sound") or item:IsA("ForceField") or item:IsA("BillboardGui") then
			item:Destroy()
		elseif item:IsA("Light") then
			item.Enabled = false
		elseif item:IsA("Motor6D") then
			item.Transform = CFrame.identity -- standing, not mid-stride
		elseif item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = false
			item.CastShadow = false
			item.LocalTransparencyModifier = 0
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.PlatformStand = true
	end
	local root = copy:FindFirstChild("HumanoidRootPart")
	root.Anchored = true
	root.Transparency = 1
	copy.PrimaryPart = root
	SkinLook.restore(copy)
	return copy
end

-- You, wearing a skin (a Catalog item) or an accessory (its id). focus
-- "head" frames your head and shoulders, for things worn there.
function ShopPreview.avatar(viewport, look)
	local model = copyAvatar()
	if not model then
		viewport:ClearAllChildren()
		return nil
	end
	SkinLook.apply(model, look.skin)
	model:PivotTo(CFrame.new())
	if look.accessory then
		AccessoryLook.apply(model, look.accessory)
	end

	local centre, size
	if look.focus == "head" then
		local head = model:FindFirstChild("Head")
		centre, size = stage(viewport, model, AVATAR_FRAMING, 0)
		if head then
			-- Closer in, on the head.
			local camera = viewport.CurrentCamera
			local aim = head.Position + Vector3.new(0, head.Size.Y * 0.2, 0) - centre
			local distance = (size.Y * HEAD_FRAMING / 2) / math.tan(math.rad(FOV / 2))
			camera.CFrame = CFrame.lookAt(aim + Vector3.new(0, 0, -distance), aim)
		end
	else
		centre, size = stage(viewport, model, AVATAR_FRAMING, AVATAR_LIFT)
	end
	local phase = math.random() * math.pi * 2
	return function(t)
		if model.Parent then
			-- Turns on the spot about its middle.
			model:PivotTo(CFrame.Angles(0, t * TURN_SPEED + phase, 0) * CFrame.new(-centre))
		end
	end
end

-- One of the shop's 3D models, spinning and bobbing; nil if it isn't there.
-- tilt (degrees) tips a model that lies flat up toward you; rock keeps one
-- with letters on it facing you, rocking to and fro.
function ShopPreview.model(viewport, name, tilt, rock)
	local folder = modelsFolder()
	local template = folder and folder:FindFirstChild(name)
	if not template then
		viewport:ClearAllChildren()
		return nil
	end
	local model = template:Clone()
	if model:IsA("BasePart") then
		-- A lone MeshPart: put it in a model so it can be posed the same way.
		local holder = Instance.new("Model")
		model.Parent = holder
		model = holder
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CastShadow = false
		end
	end
	local centre, size = stage(viewport, model, MODEL_FRAMING, 0)
	local tip = CFrame.Angles(-math.rad(tilt or 0), 0, 0)
	local tipped = (tilt or 0) ~= 0 or rock == true
	-- Flat facing you: thin front to back.
	local flat = size.Z < 0.4 * math.max(size.X, size.Y)
	local phase = math.random() * math.pi * 2
	return function(t)
		if model.Parent then
			local bob = math.sin(t * 2 + phase) * size.Y * BOB
			local turn = t * SPIN_SPEED + phase
			if tipped then
				turn = math.sin(turn) * ROCK
			elseif flat then
				turn -= DWELL * math.sin(2 * turn)
			end
			model:PivotTo(CFrame.new(0, bob, 0) * CFrame.Angles(0, turn, 0) * tip * CFrame.new(-centre))
		end
	end
end

return ShopPreview
