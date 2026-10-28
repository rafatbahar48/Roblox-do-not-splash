-- Everything the shop sells, in the order the shop shows it. Prices are in
-- pearls (see Config.Pearls for how they are earned).
--
-- kind     "skin", "accessory" or "boost"
-- swatch   colour on the shop card
--
-- Skins recolour body regions (head, torso, arms, legs). A region left out
-- keeps the avatar's own colour. Wearing any skin hides shirts and pants.
-- Accessories are built from parts in server/Cosmetics.luau, keyed by id.
-- Boost effects are tuned in Config.Boosts.

local Catalog = {}

local function region(r, g, b, material, transparency)
	return { color = Color3.fromRGB(r, g, b), material = material, transparency = transparency }
end

Catalog.items = {
	-- Skins
	{
		id = "lifeguard",
		kind = "skin",
		name = "Lifeguard",
		price = 150,
		blurb = "Red top, dark trunks. Someone has to keep watch.",
		swatch = Color3.fromRGB(196, 40, 28),
		torso = region(196, 40, 28),
		legs = region(30, 32, 36),
	},
	{
		id = "night_swimmer",
		kind = "skin",
		name = "Night Swimmer",
		price = 200,
		blurb = "A dark wetsuit for swimming after closing time.",
		swatch = Color3.fromRGB(22, 32, 58),
		torso = region(22, 32, 58),
		arms = region(22, 32, 58),
		legs = region(22, 32, 58),
	},
	{
		id = "porcelain",
		kind = "skin",
		name = "Porcelain",
		price = 300,
		blurb = "Cold, white and very still.",
		swatch = Color3.fromRGB(238, 234, 226),
		head = region(238, 234, 226, Enum.Material.Marble),
		torso = region(238, 234, 226, Enum.Material.Marble),
		arms = region(238, 234, 226, Enum.Material.Marble),
		legs = region(238, 234, 226, Enum.Material.Marble),
	},
	{
		id = "drowned",
		kind = "skin",
		name = "Drowned",
		price = 350,
		blurb = "You look like you've been down there a while.",
		swatch = Color3.fromRGB(118, 138, 128),
		head = region(118, 138, 128, Enum.Material.Slate),
		torso = region(96, 114, 106, Enum.Material.Slate),
		arms = region(118, 138, 128, Enum.Material.Slate),
		legs = region(96, 114, 106, Enum.Material.Slate),
	},
	{
		id = "glowtide",
		kind = "skin",
		name = "Glowtide",
		price = 450,
		blurb = "Dark suit, glowing limbs. Easy to find in the dark.",
		swatch = Color3.fromRGB(0, 205, 190),
		torso = region(14, 22, 26),
		arms = region(0, 205, 190, Enum.Material.Neon),
		legs = region(0, 205, 190, Enum.Material.Neon),
	},
	{
		id = "phantom",
		kind = "skin",
		name = "Phantom",
		price = 500,
		blurb = "Half here, half somewhere else.",
		swatch = Color3.fromRGB(196, 226, 236),
		head = region(196, 226, 236, Enum.Material.Glass, 0.35),
		torso = region(196, 226, 236, Enum.Material.Glass, 0.35),
		arms = region(196, 226, 236, Enum.Material.Glass, 0.35),
		legs = region(196, 226, 236, Enum.Material.Glass, 0.35),
	},

	-- Accessories
	{
		id = "swim_cap",
		kind = "accessory",
		name = "Swim Cap",
		price = 100,
		blurb = "Keeps your hair dry. Nothing else.",
		swatch = Color3.fromRGB(246, 196, 52),
	},
	{
		id = "dive_goggles",
		kind = "accessory",
		name = "Dive Goggles",
		price = 140,
		blurb = "Big round lenses. Purely for looks.",
		swatch = Color3.fromRGB(70, 170, 220),
	},
	{
		id = "float_ring",
		kind = "accessory",
		name = "Float Ring",
		price = 180,
		blurb = "Won't keep you up. Looks cheerful, though.",
		swatch = Color3.fromRGB(230, 70, 60),
	},
	{
		id = "dorsal_fin",
		kind = "accessory",
		name = "Dorsal Fin",
		price = 220,
		blurb = "Make it think twice.",
		swatch = Color3.fromRGB(90, 100, 110),
	},
	{
		id = "head_lamp",
		kind = "accessory",
		name = "Head Lamp",
		price = 260,
		blurb = "A small light of your own in the dark rooms.",
		swatch = Color3.fromRGB(255, 226, 150),
	},
	{
		id = "drowned_halo",
		kind = "accessory",
		name = "Drowned Halo",
		price = 320,
		blurb = "A ring of pale lights that follows you around.",
		swatch = Color3.fromRGB(150, 240, 255),
	},

	-- Boosts
	{
		id = "updraft",
		kind = "boost",
		name = "Updraft",
		price = 40,
		blurb = "Fly for 2 seconds. Press Q or tap Fly.",
		swatch = Color3.fromRGB(170, 230, 255),
	},
	{
		id = "hush",
		kind = "boost",
		name = "Hush",
		price = 30,
		blurb = "Make no sound at all for 5 seconds. Press F or tap Hush.",
		swatch = Color3.fromRGB(180, 160, 255),
	},
}

Catalog.byId = {}
for _, item in Catalog.items do
	Catalog.byId[item.id] = item
end

-- Equipment slots and the item kind each one takes.
Catalog.slots = { skin = "skin", accessory = "accessory" }

return Catalog
