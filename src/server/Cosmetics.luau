-- Puts skins and accessories on characters: skins recolour body regions and
-- hide shirts and pants (shared/SkinLook.luau); accessories are small builds
-- welded to the avatar's attachment points (shared/AccessoryLook.luau). A
-- premium skin adds its outfit (shared/OutfitLook.luau), only while its Game
-- Pass is owned, and marks the character with its move (SkinMove), which
-- every client plays (client/SkinMoves.luau). Under an outfit, the shop's
-- head accessories stay off.
--
-- All can be changed mid-life.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessoryLook = require(ReplicatedStorage.Shared.AccessoryLook)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local OutfitLook = require(ReplicatedStorage.Shared.OutfitLook)
local Perks = require(ReplicatedStorage.Shared.Perks)
local SkinLook = require(ReplicatedStorage.Shared.SkinLook)

local APPEARANCE_WAIT = 6 -- seconds to wait for the avatar to finish loading

local Cosmetics = {}

local function waitForAppearance(player)
	if player:HasAppearanceLoaded() then
		return
	end
	local loaded = false
	local connection = player.CharacterAppearanceLoaded:Connect(function()
		loaded = true
	end)
	local deadline = os.clock() + APPEARANCE_WAIT
	while not loaded and os.clock() < deadline do
		task.wait(0.1)
	end
	connection:Disconnect()
end

-- Dresses a character in what the player has equipped. Waits for the avatar
-- to load first, so its own clothes and colours don't land on top.
function Cosmetics.apply(player, character, equipped)
	if not character then
		return
	end
	waitForAppearance(player)
	if player.Character ~= character or not character.Parent then
		return
	end
	local skin = equipped.skin and Catalog.byId[equipped.skin]
	if skin and skin.premium and not Perks.owns(player, skin.premium) then
		skin = nil -- still equipped, for when the pass shows up (Purchases.luau)
	end
	SkinLook.apply(character, skin)
	OutfitLook.apply(character, skin)
	character:SetAttribute("SkinMove", skin and skin.move)
	local accessory = equipped.accessory and Catalog.byId[equipped.accessory]
	local covered = skin and skin.premium and accessory and accessory.focus == "head"
	AccessoryLook.apply(character, if covered then nil else equipped.accessory)
end

return Cosmetics
