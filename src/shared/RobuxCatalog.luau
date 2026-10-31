-- Everything sold for Robux, in the order the shop shows it (client/
-- ShopUi.luau): Developer Products, bought again and again, and Game
-- Passes, owned forever. Their ids are in Config.Products and Config.Passes,
-- by the id here; an id of 0 means it isn't set up, and the game doesn't
-- offer it. Prices are set on the Creator Dashboard.
--
-- art     the UI kit part on its card (UiArtParts.luau), and the name of
--         its 3D model in ReplicatedStorage.ShopModels
-- rarity  the tag and colour of its card (as in Catalog.luau)
-- tilt    degrees its 3D model is tipped up toward you, for models that lie
--         flat (negative tips the other way, for one whose top faces down)
-- rock    true for a model that should only rock to and fro, never show its
--         back (one with letters on it)
-- gives   (products) coins, boosts by id, and self-revives, handed out by
--         server/Progress.luau's grant
--
-- What the passes do is in Config.PassPerks and shared/Perks.luau.
--
-- Bundles are Developer Products too (ids in Config.Products), sold for a
-- while, until endsAt, from their own window (client/ChristmasBundle.luau)
-- and the HUD's event button rather than the Robux tab. gives can include
-- items (catalog ids) that are only had this way; perks are the lines the
-- window shows: a UI kit icon, a name, a line about it and a tag.

local RobuxCatalog = {}

RobuxCatalog.products = {
	{
		id = "CoinsSmall",
		rarity = "Common",
		name = "Handful of Coins",
		blurb = "+200 coins.",
		art = "robux_coins_small",
		gives = { coins = 200 },
	},
	{
		id = "CoinsJar",
		rarity = "Rare",
		name = "Jar of Coins",
		blurb = "+650 coins.",
		art = "robux_coins_jar",
		gives = { coins = 650 },
	},
	{
		id = "CoinsChest",
		rarity = "Epic",
		name = "Chest of Coins",
		blurb = "+1,600 coins.",
		art = "robux_coins_chest",
		gives = { coins = 1600 },
	},
	{
		id = "CoinsHoard",
		rarity = "Legendary",
		name = "Sunken Hoard",
		blurb = "+4,500 coins.",
		art = "robux_coins_hoard",
		gives = { coins = 4500 },
	},
	{
		id = "NightKit",
		rarity = "Epic",
		name = "Night Kit",
		blurb = "+250 coins, 3 Updrafts, 3 Hushes and 2 Self-Revives.",
		art = "robux_kit",
		gives = { coins = 250, boosts = { updraft = 3, hush = 3 }, selfRevives = 2 },
	},
	{
		id = "SelfRevive1",
		rarity = "Rare",
		name = "Self-Revive",
		blurb = "Get back up when it catches you, for free. Kept until you need it.",
		art = "robux_self_revive",
		gives = { selfRevives = 1 },
	},
	{
		id = "SelfRevive3",
		rarity = "Epic",
		name = "3 Self-Revives",
		blurb = "Three times back up when it catches you. Kept until you need them.",
		art = "robux_self_revive",
		gives = { selfRevives = 3 },
	},
	{
		id = "Updraft5",
		rarity = "Rare",
		name = "5 Updrafts",
		blurb = "Five Updrafts for your pocket. Past what you can carry, you get coins.",
		art = "action_updraft",
		gives = { boosts = { updraft = 5 } },
	},
	{
		id = "Hush5",
		rarity = "Rare",
		name = "5 Hushes",
		blurb = "Five Hushes for your pocket. Past what you can carry, you get coins.",
		art = "action_hush",
		gives = { boosts = { hush = 5 } },
	},
}

RobuxCatalog.passes = {
	{
		id = "DoubleCoins",
		rarity = "Legendary",
		name = "2× Coins",
		blurb = "Twice the coins from every stage, shell and escape. Forever.",
		art = "robux_double_coins",
		rock = true,
	},
	{
		id = "DeepPockets",
		rarity = "Legendary",
		name = "Deep Pockets",
		blurb = "5 pebbles a life instead of 3, and carry up to 15 of each boost. Forever.",
		art = "robux_pockets",
	},
}

RobuxCatalog.bundles = {
	{
		id = "ChristmasBundle",
		rarity = "Legendary",
		name = "Christmas Bundle",
		endsAt = DateTime.fromUniversalTime(2027, 1, 1).UnixTimestamp, -- midnight on New Year's Day, UTC
		gives = { coins = 1000, selfRevives = 3, items = { "frostbite", "santa_hat" } },
		perks = {
			{ art = "icon_frostbite", name = "Frostbite Skin", blurb = "Exclusive. Frozen solid, still moving.", tag = "FOREVER" },
			{ art = "icon_santa_hat", name = "Santa Hat", blurb = "Exclusive. Red, fluffy, a bit floppy.", tag = "FOREVER" },
			{ art = "robux_coins_chest", name = "1,000 Coins", blurb = "Spend them on anything in the shop.", tag = "+1,000" },
			{ art = "robux_self_revive", name = "3 Self-Revives", blurb = "Get back up when it catches you.", tag = "×3" },
		},
	},
}

RobuxCatalog.productById = {}
for _, product in RobuxCatalog.products do
	RobuxCatalog.productById[product.id] = product
end
for _, bundle in RobuxCatalog.bundles do
	RobuxCatalog.productById[bundle.id] = bundle
end
RobuxCatalog.passById = {}
for _, pass in RobuxCatalog.passes do
	RobuxCatalog.passById[pass.id] = pass
end

return RobuxCatalog
