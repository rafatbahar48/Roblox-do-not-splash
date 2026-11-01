-- Waist-deep wading. The forest's water is Roblox terrain water
-- (server/MapBuilder.luau), which would have you swim; here you stand on
-- its muddy bottom instead, the water up to your waist, and can climb back
-- out onto a platform. The noise and the creature are server/Noise.luau's.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local Wading = {}

local function onCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
end

function Wading.start()
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return Wading
