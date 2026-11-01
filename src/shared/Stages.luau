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
-- sinkDelay seconds before a moss mat goes under
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
-- scatter   more platforms strewn all over the swamp, per 1000 square studs
--           (kinds from styles), so there's no one clear path: most are a
--           jump from another, making ways off the route that lead nowhere
--           or back onto it, and some are only a wade
-- skip      how many route platforms a way across the scattered ones can
--           skip at most (3 if left out), so none jumps across a bend
-- gloom     0 to 1: denser fog and darker light while you're in it
--           (client/Mood.luau); any stage can have it
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
