-- One entry per flooded room, in order. Add an entry to add a stage.
--
-- length    room length in studs (start landing + pool + end landing)
-- gap       {min, max} gap between tiles, edge to edge
-- tileSize  {min, max} tile width
-- shift     how far each tile can sit sideways from the one before
-- mix       how often each tile kind appears (relative weights):
--             normal   solid column
--             creaky   solid, but makes noise when you land on it
--             sinking  thin slab that goes under shortly after you step on it
--             raft     floating slab that drifts side to side
--             pillar   narrow column, sometimes taller than the rest
-- sinkDelay seconds before a sinking tile goes under
-- lurkers   how many things live in this room's water
-- flicker   whether the lights cut out now and then

return {
	{
		name = "The Shallow End",
		length = 90,
		gap = { 3, 4 },
		tileSize = { 7, 9 },
		shift = 4,
		mix = { normal = 1 },
		lurkers = 1,
	},
	{
		name = "Creaking Floor",
		length = 100,
		gap = { 3.5, 5 },
		tileSize = { 6, 8 },
		shift = 6,
		mix = { normal = 3, creaky = 2 },
		lurkers = 1,
	},
	{
		name = "Soft Tiles",
		length = 110,
		gap = { 4, 5 },
		tileSize = { 6, 7 },
		shift = 6,
		mix = { normal = 2, creaky = 1, sinking = 2 },
		sinkDelay = 1.2,
		lurkers = 1,
	},
	{
		name = "Drift",
		length = 115,
		gap = { 4, 5.5 },
		tileSize = { 5, 7 },
		shift = 7,
		mix = { normal = 2, raft = 2, sinking = 1 },
		sinkDelay = 1,
		lurkers = 1,
	},
	{
		name = "Columns",
		length = 120,
		gap = { 4.5, 6 },
		tileSize = { 3, 4 },
		shift = 7,
		mix = { normal = 1, pillar = 3, creaky = 1 },
		lurkers = 2,
	},
	{
		name = "Lights Out",
		length = 125,
		gap = { 4.5, 6 },
		tileSize = { 4, 6 },
		shift = 8,
		mix = { normal = 2, creaky = 2, sinking = 2, raft = 1 },
		sinkDelay = 0.9,
		lurkers = 2,
		flicker = true,
	},
	{
		name = "Deep End",
		length = 140,
		gap = { 5, 6.5 },
		tileSize = { 3, 5 },
		shift = 8,
		mix = { pillar = 2, sinking = 2, raft = 2, creaky = 1 },
		sinkDelay = 0.7,
		lurkers = 3,
		flicker = true,
	},
}
