-- One entry per stretch of the drowned forest, in order. Add an entry to add
-- a stage.
--
-- length    stretch length in studs (start island + water + end island)
-- startLanding  (optional) how long its start island is; stage 1's holds the
--           cave (Config.Cave) as well as the usual landing
-- gap       {min, max} gap between stepping stones, edge to edge
-- tileSize  {min, max} stepping stone width
-- shift     how far each one can sit sideways from the one before
-- mix       how often each kind appears (relative weights):
--             normal   a mossy stump, or a grassy mound if it is wide
--             creaky   old boards on posts: solid, but they creak when you land
--             sinking  a mat of floating moss that goes under shortly after you step on it
--             raft     a little wooden raft that drifts side to side
--             pillar   a narrow broken trunk, sometimes taller than the rest
-- sinkDelay seconds before a moss mat (or a swamp's sinking raft) goes under
-- flicker   whether the lanterns cut out now and then
--
-- A stage with layout = "swamp" is an open swamp instead of one trail
-- (server/Swamp.luau): low platforms over wide water with a natural muddy
-- shoreline, a route you can always jump winding right across it and back
-- along a smooth curve, and side paths off it. It uses tileSize as above,
-- and gap as the range each jump on the route falls in, measured to a
-- raft's nearest side: raise it stage by stage, keeping the top under
-- Config.MaxJump (7), the furthest anyone can jump. It also has:
-- halfWidth how far either side of the middle its platforms go
-- turns     how many times the route runs along one side and crosses to
--           the other
-- bend      how long each run along a side is, as a share of the room
--           each turn has (0.32 if left out): less makes tighter bends,
--           which a grapple shortcut can cut across
-- wobble    how far each jump can veer off the route's smooth curve, in
--           degrees (30 if left out), so it zigzags
-- styles    how often each kind of run makes up the route (relative
--           weights): stumps (a row of little stumps close together), wide
--           (wide stumps, tileSize), rafts (plank and log rafts, roped
--           together), logs (a fallen log to walk along), mounds (a little
--           island to rest on, with a lantern)
-- platformHeight  how far its platforms stand above the water
-- branches  how many side paths; each starts with a drop off a tall stump
--           you can't climb back up, then crosses a gap too far to jump,
--           under a hook for the grapple (Config.Grapple). The first one's
--           far side has the shell
-- shortcuts how many optional grapple shortcuts: a hook across a bend,
--           over a gap too far to jump, that skips the long way round
-- crossings where the route itself crosses gaps too far to jump, in order:
--           each is how many in a row. Each has a hook over its far side
--           that swings you across for free (server/Shop.luau), and
--           nothing else makes a way round it but wading
-- farGap    {min, max} how wide those gaps are, edge to edge
--           (Config.Grapple.FarGap if left out); keep it under 14, so the
--           hook stays in the grapple's reach (Config.Grapple.Range)
-- forks     how many second ways across the inside of a bend, from one
--           route platform to one well along: shorter, but on little
--           stumps a long jump apart
-- scatter   more platforms strewn all over the swamp, per 1000 square studs
--           (kinds from styles), so there's no one clear path: most are a
--           jump from another, making ways off the route that lead nowhere
--           or back onto it, and some are only a wade
-- skip      how many route platforms a way across the scattered ones can
--           skip at most (3 if left out), so none jumps across a bend
-- sinking   the share of rafts that are waterlogged (low in the water and
--           tipped): one goes under sinkDelay seconds after you land on it
-- creaky    the share of the other plank rafts that are pieces of old dock
--           (broken posts at their corners), which creak when you land on
--           them: a noise (Config.Noise.CreakyTile)
-- smaller   how much smaller the little stumps, the rafts and a crossing's
--           landings are, as a share (0 if left out)
-- lanterns  a lantern beside every so many route platforms (4 if left out)
-- trees     the share of the spots among the platforms that have a dead
--           tree (0.35 if left out)
-- treeScale how much taller the trees are (1 if left out)
-- gloom     0 to 1: denser fog and darker light while you're in it
--           (client/Mood.luau); any stage can have it
--
-- Each stage is harder than the one before: longer gaps, smaller platforms
-- and more far gaps in a row, fewer lanterns and platforms to rest on.
--
-- One creature stalks the whole forest (server/Lurkers.luau).

return {
	{
		-- The first steps: a big swamp strewn with stumps, rafts and logs,
		-- the way through winding across it and back, jumps from easy to
		-- quite far, and no grapple needed.
		name = "The First Steps",
		layout = "swamp",
		length = 230, -- 168 of swamp, and the cave before it
		startLanding = 50,
		halfWidth = 50,
		platformHeight = 0.8,
		gap = { 3, 5 },
		tileSize = { 6.5, 8.5 },
		turns = 2,
		styles = { wide = 3, rafts = 3, stumps = 2, mounds = 1, logs = 1 },
		scatter = 5,
		skip = 6,
	},
	{
		-- Deeper waters: wider swings, longer gaps, more little stumps and
		-- logs, denser fog, and one grapple shortcut you don't need.
		name = "Deeper Waters",
		layout = "swamp",
		length = 230,
		halfWidth = 48,
		platformHeight = 0.8,
		gap = { 3.5, 5.8 },
		tileSize = { 5.5, 8 },
		turns = 3,
		bend = 0.18,
		wobble = 40,
		styles = { rafts = 4, wide = 2, stumps = 3, logs = 3, mounds = 2 },
		scatter = 5,
		skip = 6,
		shortcuts = 1,
		gloom = 0.3,
	},
	{
		-- The fallen grove: stumps among fallen logs, jumps short and long,
		-- and the first gap too far to jump, under a hook.
		name = "The Fallen Grove",
		layout = "swamp",
		length = 240,
		halfWidth = 50,
		platformHeight = 0.8,
		gap = { 4, 6.1 },
		tileSize = { 5.5, 7.5 },
		turns = 3,
		bend = 0.24,
		wobble = 40,
		styles = { logs = 3, stumps = 2, wide = 3, rafts = 2, mounds = 1 },
		scatter = 4.5,
		skip = 6,
		crossings = { 1 },
		farGap = { 10, 11 },
		shortcuts = 1,
		trees = 0.4,
		gloom = 0.35,
	},
	{
		-- The web of stumps: a wider swamp of little stumps, a harder way
		-- across a bend beside the long way round, and two far gaps.
		name = "The Web of Stumps",
		layout = "swamp",
		length = 250,
		halfWidth = 58,
		platformHeight = 0.8,
		gap = { 4.3, 6.3 },
		tileSize = { 4.5, 7 },
		turns = 3,
		bend = 0.22,
		wobble = 45,
		styles = { stumps = 4, wide = 3, rafts = 2, logs = 1, mounds = 1 },
		scatter = 5,
		skip = 6,
		crossings = { 1, 1 },
		farGap = { 10, 11.5 },
		forks = 1,
		smaller = 0.05,
		lanterns = 5,
		gloom = 0.35,
	},
	{
		-- The sunken path: old rafts and broken logs, some of them
		-- waterlogged and sinking under you, longer jumps, fewer lanterns.
		name = "The Sunken Path",
		layout = "swamp",
		length = 250,
		halfWidth = 52,
		platformHeight = 0.8,
		gap = { 4.2, 6.3 },
		tileSize = { 4.5, 6.5 },
		turns = 3,
		bend = 0.2,
		wobble = 45,
		styles = { rafts = 5, logs = 3, stumps = 2, wide = 1, mounds = 1 },
		scatter = 4.5,
		skip = 6,
		crossings = { 1, 1 },
		farGap = { 10, 12 },
		shortcuts = 1,
		sinking = 0.3,
		sinkDelay = 1.6,
		smaller = 0.08,
		lanterns = 6,
		gloom = 0.4,
	},
	{
		-- Twisted roots: narrow platforms twisting round huge dead trees, a
		-- harder way across, and two far gaps in a row.
		name = "Twisted Roots",
		layout = "swamp",
		length = 260,
		halfWidth = 52,
		platformHeight = 0.8,
		gap = { 5, 6.7 },
		tileSize = { 4, 6 },
		turns = 4,
		bend = 0.18,
		wobble = 50,
		styles = { stumps = 3, logs = 2, rafts = 3, wide = 1, mounds = 1 },
		scatter = 4.5,
		skip = 6,
		crossings = { 2, 1 },
		farGap = { 10.5, 12 },
		forks = 1,
		sinking = 0.25,
		sinkDelay = 1.5,
		smaller = 0.08,
		lanterns = 6,
		trees = 0.45,
		treeScale = 1.4,
		gloom = 0.4,
	},
	{
		-- The broken mire: old docks that creak, smaller landings, wide
		-- open water and four far gaps.
		name = "The Broken Mire",
		layout = "swamp",
		length = 260,
		halfWidth = 56,
		platformHeight = 0.8,
		gap = { 4.95, 6.75 },
		tileSize = { 3.6, 5.2 },
		turns = 4,
		bend = 0.2,
		wobble = 50,
		styles = { rafts = 5, stumps = 3, logs = 1, wide = 1, mounds = 1 },
		scatter = 3.5,
		skip = 6,
		crossings = { 2, 1, 1 },
		farGap = { 10.5, 12.5 },
		shortcuts = 1,
		sinking = 0.25,
		sinkDelay = 1.4,
		creaky = 0.5,
		smaller = 0.14,
		lanterns = 7,
		gloom = 0.4,
	},
	{
		-- Silence's edge: long open water, far gaps two at a time, narrow
		-- rafts, hardly a lantern, and nowhere much to rest.
		name = "Silence's Edge",
		layout = "swamp",
		length = 270,
		halfWidth = 56,
		platformHeight = 0.8,
		gap = { 5.3, 6.9 },
		tileSize = { 3.6, 5.4 },
		turns = 4,
		bend = 0.18,
		wobble = 50,
		styles = { rafts = 5, stumps = 3, logs = 2, wide = 1 },
		scatter = 3,
		skip = 6,
		crossings = { 2, 2 },
		farGap = { 11, 12.5 },
		sinking = 0.3,
		sinkDelay = 1.3,
		creaky = 0.5,
		smaller = 0.15,
		lanterns = 9,
		trees = 0.5,
		gloom = 0.45,
	},
	{
		-- The hollow basin: a great pond the route curves right round, two
		-- harder ways across it, little stumps and long swings.
		name = "The Hollow Basin",
		layout = "swamp",
		length = 280,
		halfWidth = 60,
		platformHeight = 0.8,
		gap = { 5.7, 6.95 },
		tileSize = { 3.3, 4.8 },
		turns = 4,
		bend = 0.22,
		wobble = 55,
		styles = { stumps = 3, logs = 2, rafts = 4, wide = 1, mounds = 1 },
		scatter = 3.5,
		skip = 6,
		crossings = { 2, 1, 2 },
		farGap = { 11, 13 },
		forks = 2,
		sinking = 0.3,
		sinkDelay = 1.3,
		creaky = 0.5,
		smaller = 0.19,
		lanterns = 9,
		trees = 0.45,
		treeScale = 1.25,
		gloom = 0.45,
	},
	{
		-- The last crossing: the biggest swamp of all, the longest jumps on
		-- the smallest stumps, three far gaps in a row, and a great doorway
		-- at the end.
		name = "The Last Crossing",
		layout = "swamp",
		length = 300,
		halfWidth = 62,
		platformHeight = 0.8,
		gap = { 5.9, 7 },
		tileSize = { 3.2, 4.8 },
		turns = 5,
		bend = 0.16,
		wobble = 55,
		styles = { stumps = 3, rafts = 4, logs = 2, wide = 2 },
		scatter = 3,
		skip = 6,
		crossings = { 1, 3, 2 },
		farGap = { 11.5, 13 },
		forks = 1,
		shortcuts = 1,
		sinking = 0.35,
		sinkDelay = 1.2,
		creaky = 0.5,
		smaller = 0.2,
		lanterns = 10,
		trees = 0.45,
		treeScale = 1.4,
		gloom = 0.45,
	},
}
