-- The grapple, on the server: checks that a hook a player wants to swing to
-- is one (server/Forest.luau's grappleHook) and in reach, and runs the rope
-- from their hand to its ring while they swing, for everyone to see. The
-- swing itself is the player's own (client/Grapple.luau); spending the boost
-- is Shop.luau's.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local LEEWAY = 6 -- studs past the range allowed, for lag
local ROPE_COLOR = Color3.fromRGB(150, 122, 84)

local Grapple = {}

-- The hook, if target is one this player can reach from where they are.
function Grapple.check(player, target)
	if typeof(target) ~= "Instance" or not target:IsA("BasePart") or not CollectionService:HasTag(target, "GrappleHook") then
		return nil
	end
	if not target:IsDescendantOf(workspace) then
		return nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - target.Position).Magnitude > Config.Grapple.Range + LEEWAY then
		return nil
	end
	return target
end

-- The rope from the player's hand to the hook, for as long as the swing.
function Grapple.rope(player, hook, duration)
	local character = player.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	local grip = hand and hand:FindFirstChild("RightGripAttachment")
	local ring = hook:FindFirstChild("Rope")
	if not grip or not ring then
		return
	end
	local beam = Instance.new("Beam")
	beam.Name = "GrappleRope"
	beam.Attachment0 = grip
	beam.Attachment1 = ring
	beam.Color = ColorSequence.new(ROPE_COLOR)
	beam.Width0 = 0.16
	beam.Width1 = 0.16
	beam.FaceCamera = true
	beam.LightInfluence = 1
	beam.Segments = 2
	beam.Parent = hook
	Debris:AddItem(beam, duration)
end

return Grapple
