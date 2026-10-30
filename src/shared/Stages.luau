-- One entry per stretch of the drowned forest, in order. Add an entry to add
-- a stage.
--
-- length    stretch length in studs (start island + water + end island)
-- gap       {min, max} gap between stepping stones, edge to edge
-- tileSize  {min, max} stepping stone width
-- shift     how far each one can sit sideways from the one before
-- mix       how often each kind appears (relative weights):
--             normal   a mossy stump, or a grassy mound if it is wide
--             creaky   old boards on posts: solid, but they creak when you land
--             sinking  a mat of floating moss that goes under shortly after you step on it
--             raft     a little wooden raft that drifts side to side
--             pillar   a narrow broken trunk, sometimes taller than the rest
-- sinkDelay seconds before a moss mat goes under
-- flicker   whether the lanterns cut out now and then
--
-- One creature stalks the whole forest (server/Lurkers.luau).

return {
	{
		name = "The Shallows",
		length = 90,
		gap = { 3, 4 },
		tileSize = { 7, 9 },
		shift = 4,
		mix = { normal = 1 },
	},
	{
		name = "Old Boards",
		length = 100,
		gap = { 3.5, 5 },
		tileSize = { 6, 8 },
		shift = 6,
		mix = { normal = 3, creaky = 2 },
	},
	{
		name = "Soft Moss",
		length = 110,
		gap = { 4, 5 },
		tileSize = { 6, 7 },
		shift = 6,
		mix = { normal = 2, creaky = 1, sinking = 2 },
		sinkDelay = 1.2,
	},
	{
		name = "Drift",
		length = 115,
		gap = { 4, 5.5 },
		tileSize = { 5, 7 },
		shift = 7,
		mix = { normal = 2, raft = 2, sinking = 1 },
		sinkDelay = 1,
	},
	{
		name = "Broken Trunks",
		length = 120,
		gap = { 4.5, 6 },
		tileSize = { 3, 4 },
		shift = 7,
		mix = { normal = 1, pillar = 3, creaky = 1 },
	},
	{
		name = "Lights Out",
		length = 125,
		gap = { 4.5, 6 },
		tileSize = { 4, 6 },
		shift = 8,
		mix = { normal = 2, creaky = 2, sinking = 2, raft = 1 },
		sinkDelay = 0.9,
		flicker = true,
	},
	{
		name = "Deep Water",
		length = 140,
		gap = { 5, 6.5 },
		tileSize = { 3, 5 },
		shift = 8,
		mix = { pillar = 2, sinking = 2, raft = 2, creaky = 1 },
		sinkDelay = 0.7,
		flicker = true,
	},
}
