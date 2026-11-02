-- Lays out an open swamp stage (Stages.luau, layout = "swamp"): platforms
-- scattered over wide water instead of one trail of stepping stones.
--
-- A route you can always jump winds right across the swamp and back, along
-- a smooth curve it zigzags about, from the start island to the end island:
-- rows of little stumps, rafts, wide stumps, now and then a fallen log to
-- walk along or a little island to rest on. Side paths branch off it. Each
-- starts with a drop off a tall stump that you can jump down but not back
-- up, then crosses a gap too far to jump (Config.Grapple.FarGap) under a
-- hook for the grapple, and comes back to the route further on: whoever
-- takes one gets across with a grapple, an Updraft, or by wading. The first
-- one's far side has the stage's shell; with no side paths, it is on a
-- little stump a short jump off the route. A shortcut is a far gap
-- between two route platforms across a bend, under a hook: a grapple
-- skips the long way round, which is still there. From stage 3 the route
-- itself crosses gaps too far to jump (crossings), under free hooks, and
-- nothing else makes a way round them: you swing, or wade. A fork is a
-- second way between two route platforms, across the inside of a bend:
-- shorter, on little stumps with long jumps between them. The rest of the
-- swamp is strewn with more platforms (scatter), so there's no one clear
-- path: most are a jump from another, making ways off the route that lead
-- nowhere or back onto it a little further on, and some are only a wade.
-- Some rafts are waterlogged and sink a moment after you land (sinking),
-- and some plank rafts are old docks that creak (creaky), as Hazards.luau
-- has them do.
--
-- Platforms are specs as in MapBuilder.luau: { kind, size, x, z, raise },
-- kind "stump", "deck" (planks), "logRaft" (logs tied together), "mound"
-- or "log" (Forest.luau). size is the width a jump is measured to; a log's
-- is its length, and its dir (a Vector2) the way it lies. A raft can have a
-- hazard, "sinking" or "creaky".
-- Everything is laid out from one Random, so a stage comes out the same
-- every time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MAX_JUMP = Config.MaxJump
local GRAPPLE = Config.Grapple
local CLEARANCE = 2 -- the least water between two platforms
local TALL_SIZE = 4.5 -- the stump the shell's path drops off
local SHELL_SIZE = 7 -- the platform across a side path's far gap
local NOOK_SIZE = 4.5 -- the shell's stump just off the route, in a stage without side paths
local SIDE_MARGIN = 8 -- how far in from the swamp's sides the route turns
local LOG_WIDTH = 2.4 -- a fallen log's thickness (Forest.luau's walkLog)
local LANDING_SIZE = { 5.5, 7 } -- the platforms either side of a crossing, before smaller
local FORK_SIZE = { 3.2, 4 } -- a fork's little stumps
local FORK_SKIP = 8 -- how many route platforms a fork skips at least
local TRIES = 40

-- The runs the route is made of (Stages.luau's styles weight them): how
-- many platforms in a run, which kinds, how wide (nil: the stage's
-- tileSize), and their gaps as a share of the stage's. Scattered
-- platforms are picked by the same weights, scatter wide.
-- Little stumps and rafts are smaller in a later stage (Stages.luau's
-- smaller).
local STYLES = {
	stumps = { count = { 3, 5 }, kinds = { stump = 1 }, size = { 3.6, 4.6 }, scatter = { 3.2, 4.6 }, gap = 0.65, shrinks = true }, -- a row of little stumps
	wide = { count = { 2, 4 }, kinds = { stump = 1 }, scatter = { 4.5, 7 }, gap = 1 },
	rafts = { count = { 2, 4 }, kinds = { deck = 1, logRaft = 1 }, size = { 6.5, 8.5 }, scatter = { 4.5, 8 }, gap = 1, shrinks = true },
	logs = { count = { 1, 1 }, kinds = { log = 1 }, size = { 9, 12 }, scatter = { 6, 11 }, gap = 1 }, -- a fallen log to walk along
	mounds = { count = { 1, 1 }, kinds = { mound = 1 }, size = { 9, 11.5 }, scatter = { 7, 10 }, gap = 1 }, -- a little island to rest on
}

local Swamp = {}

-- Distance from point p to the segment a-b, on the ground plane.
function Swamp.distanceToSegment(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local lengthSquared = dx * dx + dz * dz
	local t = if lengthSquared > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / lengthSquared, 0, 1) else 0
	local cx, cz = ax + dx * t - px, az + dz * t - pz
	return math.sqrt(cx * cx + cz * cz)
end

-- How far a platform's edge is from its middle. Rafts are squares a little
-- smaller than their size, turned any which way (Forest.luau), so their
-- sides are nearer than size / 2 and their corners further (outer).
local function radius(p, outer)
	if p.kind == "deck" or p.kind == "logRaft" then
		return p.size * (if outer then 0.57 else 0.4)
	end
	return p.size / 2
end

-- Water between two platforms: the most a jump between them may have to
-- clear, or with outer, the least, for keeping them apart and out of reach.
-- A log is long and thin, not the circle its length makes.
local function between(a, b, outer)
	if a.kind ~= "log" and b.kind ~= "log" then
		local dx, dz = a.x - b.x, a.z - b.z
		return math.sqrt(dx * dx + dz * dz) - radius(a, outer) - radius(b, outer)
	end
	local log, other = a, b
	if a.kind ~= "log" then
		log, other = b, a
	end
	local hx, hz = log.dir.X * log.size / 2, log.dir.Y * log.size / 2
	if other.kind ~= "log" then
		local d = Swamp.distanceToSegment(other.x, other.z, log.x - hx, log.z - hz, log.x + hx, log.z + hz)
		return d - LOG_WIDTH / 2 - radius(other, outer)
	end
	-- Two logs: the closest any point along one comes to the other.
	local ox, oz = other.dir.X * other.size / 2, other.dir.Y * other.size / 2
	local d = math.huge
	for t = -1, 1, 0.25 do
		d = math.min(
			d,
			Swamp.distanceToSegment(other.x + ox * t, other.z + oz * t, log.x - hx, log.z - hz, log.x + hx, log.z + hz),
			Swamp.distanceToSegment(log.x + hx * t, log.z + hz * t, other.x - ox, other.z - oz, other.x + ox, other.z + oz)
		)
	end
	return d - LOG_WIDTH
end

-- The widest a jump between two platforms can be, edge to edge.
local function edgeGap(a, b)
	return between(a, b, false)
end

-- How close two platforms come.
local function apart(a, b)
	return between(a, b, true)
end

local function unit(dx, dz)
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-6 then
		return 0, 1
	end
	return dx / length, dz / length
end

-- raise is above the stage's other platforms for now; attempt() lifts them
-- all to platformHeight at the end.
local function spec(x, z, size, raise, kind)
	return { kind = kind or "stump", size = size, x = x, z = z, raise = raise or 0 }
end

-- A kind of platform from the stage's mix (Stages.luau).
local function pickKind(rng, mix)
	local total = 0
	for _, weight in mix or {} do
		total += weight
	end
	local roll = rng:NextNumber() * total
	for kind, weight in mix or {} do
		roll -= weight
		if roll <= 0 then
			return kind
		end
	end
	return "stump"
end

-- Points about every half stud along a smooth curve (Catmull-Rom) through
-- points (Vector2s across the ground), from the first to the last.
local function sampleCurve(points)
	local samples = {}
	for i = 1, #points - 1 do
		local p0, p1 = points[math.max(1, i - 1)], points[i]
		local p2, p3 = points[i + 1], points[math.min(#points, i + 2)]
		local steps = math.max(1, math.ceil((p2 - p1).Magnitude / 0.5))
		for s = 0, steps - 1 do
			local t = s / steps
			local t2, t3 = t * t, t * t * t
			local point = p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3
			table.insert(samples, point * 0.5)
		end
	end
	table.insert(samples, points[#points])
	return samples
end

-- One try at a layout; nil if it didn't work out.
local function attempt(rng, stage, area)
	local band = stage.halfWidth
	local gaps, sizes = stage.gap, stage.tileSize
	local farGaps = stage.farGap or GRAPPLE.FarGap
	local shrink = 1 - (stage.smaller or 0)
	local poolStart, poolEnd = area.poolStart, area.poolEnd
	local platforms, links, hooks = {}, {}, {}
	local guarded = {} -- platforms nothing else may come within a jump of
	local posts = {} -- where the hooks' posts stand in the water (Vector2s)
	local reach = MAX_JUMP + 1 -- a jump, with some to spare

	local function pickSize()
		return rng:NextNumber(sizes[1], sizes[2])
	end
	local function pickGap()
		return rng:NextNumber(gaps[1], gaps[2])
	end

	-- Inside the swamp and clear of every platform, and of the pending ones,
	-- and of the hooks' posts.
	local function fits(new, pending, clearance)
		if math.abs(new.x) > band - new.size / 2 then
			return false
		end
		if new.z - new.size / 2 < poolStart + 1 or new.z + new.size / 2 > poolEnd - 1 then
			return false
		end
		for _, list in { platforms, pending or {} } do
			for _, other in list do
				if apart(new, other) < (clearance or CLEARANCE) then
					return false
				end
			end
		end
		for _, post in posts do
			if (post - Vector2.new(new.x, new.z)).Magnitude < radius(new, true) + 1.2 then
				return false
			end
		end
		return true
	end
	local function allFit(chain)
		local pending = {}
		for _, new in chain do
			if not fits(new, pending) then
				return false
			end
			table.insert(pending, new)
		end
		return true
	end
	-- More than a jump from everything in lists, except what's in except.
	local function outOfReach(new, lists, except)
		for _, list in lists do
			for _, other in list do
				if other ~= new and not (except and table.find(except, other)) and apart(new, other) <= MAX_JUMP + 1 then
					return false
				end
			end
		end
		return true
	end
	local function commit(chain)
		for _, new in chain do
			table.insert(platforms, new)
		end
	end
	local function link(a, b)
		table.insert(links, { a, b })
	end

	-- The route ---------------------------------------------------------------
	-- A smooth curve that winds right across the swamp and back: out from the
	-- start island, then for each turn a run along one side and a long
	-- crossing to the other, and in to the end island. Platforms go along it
	-- in runs of one style each (STYLES, picked by the stage's styles), each
	-- jump veering off it a little (wobble), so it zigzags.

	local startX = rng:NextNumber(-area.startHalf + 5, area.startHalf - 5)
	local endX = rng:NextNumber(-area.endHalf + 6, area.endHalf - 6)
	local points = { Vector2.new(startX, poolStart - 4), Vector2.new(startX, poolStart + 8) }
	local turns = stage.turns or 2
	local first, last = poolStart + 14, poolEnd - 30
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local spacing = (last - first) / turns
	for k = 1, turns do
		local z = first + spacing * (k - 0.5)
		local run = spacing * (stage.bend or 0.32)
		local x = side * (band - SIDE_MARGIN - rng:NextNumber(0, 6))
		if k > 1 then
			-- A bend partway across, so the crossing meanders.
			table.insert(points, Vector2.new(-side * band * rng:NextNumber(-0.25, 0.25), z - spacing * 0.5 + rng:NextNumber(-0.1, 0.1) * spacing))
		end
		table.insert(points, Vector2.new(x, z - run))
		table.insert(points, Vector2.new(x, z + run))
		side = -side
	end
	table.insert(points, Vector2.new(endX, poolEnd - 22))
	table.insert(points, Vector2.new(endX, poolEnd + 8))
	local curve = sampleCurve(points)

	-- A jump from the end island (x within endHalf, z from poolEnd on)?
	local function reachesEnd(p)
		local dx = math.max(0, math.abs(p.x) - area.endHalf)
		local dz = math.max(0, poolEnd - p.z)
		return math.sqrt(dx * dx + dz * dz) - radius(p) <= gaps[2]
	end
	-- Within a jump, with some to spare, of the start or the end island.
	local function nearStart(p)
		local dx = math.max(0, math.abs(p.x) - area.startHalf)
		return math.sqrt(dx * dx + (p.z - poolStart) ^ 2) - radius(p, true) <= reach
	end
	local function nearEnd(p)
		local dx = math.max(0, math.abs(p.x) - area.endHalf)
		return math.sqrt(dx * dx + (poolEnd - p.z) ^ 2) - radius(p, true) <= reach
	end

	-- The first point on the curve past cursor that is distance from p.
	local cursor = 1
	local function along(p, distance)
		for i = cursor, #curve do
			if (curve[i] - p).Magnitude >= distance then
				return curve[i], i
			end
		end
		return nil
	end

	-- Runs come from a shuffled bag holding each of the stage's styles as
	-- many times as its weight, so each comes up as often as it should.
	local bag = {}
	local function nextStyle()
		if #bag == 0 then
			for name, weight in stage.styles or { wide = 1 } do
				for _ = 1, weight do
					table.insert(bag, name)
				end
			end
			for i = #bag, 2, -1 do
				local j = rng:NextInteger(1, i)
				bag[i], bag[j] = bag[j], bag[i]
			end
		end
		return table.remove(bag)
	end
	local route = {}
	local prev = { x = startX, z = poolStart, size = 0 } -- the start island's edge
	local style, runLeft = nil, 0
	local wobble = math.rad(stage.wobble or 30)

	-- The crossings: spread along the curve, none near either end, each so
	-- many far gaps in a row. crossAt holds the route place of the platform
	-- before each far gap.
	local targets, crossAt = {}, {}
	local crossings = stage.crossings or {}
	for k, count in crossings do
		local share = 0.12 + 0.68 * (k - 0.5) / #crossings + rng:NextNumber(-0.04, 0.04)
		table.insert(targets, { at = math.floor(#curve * share), count = count })
	end
	local farLeft = 0 -- far gaps still to cross at this crossing

	-- Would new be a jump from the start island or from route[1..upTo]?
	-- Nothing past a crossing may be: it would be a way round.
	local function wayRound(new, upTo)
		if not upTo then
			return false
		end
		if nearStart(new) then
			return true
		end
		for a = 1, upTo do
			if apart(new, route[a]) <= reach then
				return true
			end
		end
		return false
	end
	-- Turns the point ahead of from about the curve by up to wobble (times
	-- by), keeping its distance.
	local function veered(from, at, by)
		local veer = rng:NextNumber(-wobble, wobble) * by
		local ahead = at - from
		local c, s = math.cos(veer), math.sin(veer)
		return from + Vector2.new(ahead.X * c - ahead.Y * s, ahead.X * s + ahead.Y * c)
	end

	while #route == 0 or farLeft > 0 or not reachesEnd(route[#route]) do
		if #route > 200 then
			return nil
		end
		if farLeft == 0 and #route > 0 and targets[1] and cursor >= targets[1].at then
			farLeft = table.remove(targets, 1).count
		end
		local placed, placedAt
		-- Measured from where you jump: a log's far end, as it lies the way
		-- you walked onto it, or the middle of anything else.
		local from, fromEdge = Vector2.new(prev.x, prev.z), radius(prev)
		if prev.kind == "log" then
			from, fromEdge = from + prev.dir * (prev.size / 2), LOG_WIDTH / 2
		end
		if farLeft > 0 then
			-- Across a far gap, under a free hook, onto a landing big enough
			-- to come down on safely.
			for _ = 1, 8 do
				local kind = pickKind(rng, { stump = 1, deck = 1, logRaft = 1 })
				local size = rng:NextNumber(LANDING_SIZE[1], LANDING_SIZE[2]) * shrink
				local gap = rng:NextNumber(farGaps[1], farGaps[2])
				local at, i = along(from, fromEdge + gap + radius({ kind = kind, size = size }))
				if not at or at.Y + size / 2 > poolEnd - 1.5 then
					return nil
				end
				at = veered(from, at, 0.3)
				local candidate = spec(math.clamp(at.X, -band + size / 2, band - size / 2), at.Y, size, 0, kind)
				if apart(candidate, prev) >= farGaps[1] - 0.5 and edgeGap(candidate, prev) <= farGaps[2] + 0.5 and fits(candidate) and not wayRound(candidate, #route - 1) then
					placed, placedAt = candidate, i
					break
				end
			end
			if not placed then
				return nil
			end
			placed.hooked = true
			table.insert(crossAt, #route)
			farLeft -= 1
		else
			if runLeft <= 0 then
				style = STYLES[nextStyle()] or STYLES.wide
				runLeft = rng:NextInteger(style.count[1], style.count[2])
			end
			for try = 1, 6 do
				-- After a few misfits, fall back on a plain stump.
				local use = if try > 3 then STYLES.wide else style
				local kind = pickKind(rng, use.kinds)
				local size = if use.size then rng:NextNumber(use.size[1], use.size[2]) * (if use.shrinks then shrink else 1) else pickSize()
				local gap = math.max(1.5, pickGap() * use.gap)
				local at, i = along(from, fromEdge + gap + radius({ kind = kind, size = size }))
				if not at then
					return nil
				end
				if at.Y + size / 2 > poolEnd - 1.5 then
					-- Nearly there: a little stump that fits in front of the island.
					kind, size = "stump", 3.6
					at, i = along(from, fromEdge + gap + size / 2)
				end
				if at then
					-- Veer off the curve, keeping the gap (less after a misfit).
					at = veered(from, at, if try > 3 then 0.3 else 1)
					local candidate = spec(math.clamp(at.X, -band + size / 2, band - size / 2), at.Y, size, 0, kind)
					if kind == "log" then
						-- Lying straight back at where you jump from.
						candidate.dir = (Vector2.new(candidate.x, candidate.z) - from).Unit
					end
					local jump = edgeGap(candidate, prev)
					if jump <= math.min(MAX_JUMP, gaps[2] + 0.3) and apart(candidate, prev) >= CLEARANCE and fits(candidate) and not wayRound(candidate, crossAt[#crossAt]) then
						placed, placedAt = candidate, i
						break
					end
				end
			end
			if not placed then
				return nil
			end
			runLeft -= 1
		end
		cursor = placedAt
		commit({ placed })
		if #route > 0 then
			link(prev, placed)
		end
		table.insert(route, placed)
		prev = placed
	end
	-- Every crossing made before the end.
	if #targets > 0 then
		return nil
	end
	-- Side paths need room along it to branch off and come back.
	if #route < (if (stage.branches or 0) > 0 then 12 else 6) then
		return nil
	end

	-- Which way the route runs at route[i].
	local function heading(i)
		local a, b = route[math.max(1, i - 1)], route[math.min(#route, i + 1)]
		return unit(b.x - a.x, b.z - a.z)
	end

	-- The route platform after route[after] nearest to p.
	local function nearestAhead(p, after)
		local best, bestIndex
		for j = after + 1, #route do
			local d = edgeGap(p, route[j])
			if not best or d < best then
				best, bestIndex = d, j
			end
		end
		return bestIndex
	end

	-- Platforms from a toward b, a jump apart, until b is a jump away. The
	-- farAt'th jump is a far gap instead. Nil if b can't be reached that way.
	local function bridge(a, b, farAt)
		local chain = {}
		local prev = a
		for step = 1, 12 do
			local left = edgeGap(prev, b)
			if left <= gaps[2] and step > (farAt or 0) then
				return chain
			end
			local dx, dz = unit(b.x - prev.x, b.z - prev.z)
			local size, gap = pickSize(), pickGap()
			if step == farAt then
				gap = rng:NextNumber(GRAPPLE.FarGap[1], GRAPPLE.FarGap[2])
			elseif left <= 2 * gaps[2] + sizes[2] then
				-- One more platform finishes it: sized to leave a jump either side.
				size = math.clamp(left - (gaps[1] + gaps[2]), 3, sizes[2])
				gap = (left - size) / 2
				if gap < CLEARANCE then
					return nil
				end
			end
			local distance = gap + radius(prev) + size / 2
			local new = spec(prev.x + dx * distance, prev.z + dz * distance, size)
			table.insert(chain, new)
			prev = new
		end
		return nil
	end

	-- Side paths ---------------------------------------------------------------
	-- Off the route onto a tall stump, a drop you can't climb back, a
	-- platform on, the far gap, a mound (the first one's has the shell), and
	-- back to the route further on.

	local shell
	local function sidePath(withShell)
		for _ = 1, TRIES do
			local i = rng:NextInteger(3, #route - 6)
			local m = route[i]
			local fx, fz = heading(i)
			local outSide = if rng:NextNumber() < 0.5 then -1 else 1
			local ox, oz = unit(-fz * outSide + fx * 0.4, fx * outSide + fz * 0.4)

			local d = radius(m) + 2.6 + TALL_SIZE / 2
			local tall = spec(m.x + ox * d, m.z + oz * d, TALL_SIZE, GRAPPLE.Drop)
			local landSize = rng:NextNumber(5, 6.5)
			d = TALL_SIZE / 2 + GRAPPLE.DropGap + landSize / 2
			local landing = spec(tall.x + ox * d, tall.z + oz * d, landSize)
			local ax, az = unit(ox + fx, oz + fz)
			local edgeSize = pickSize()
			d = landSize / 2 + pickGap() + edgeSize / 2
			local edge = spec(landing.x + ax * d, landing.z + az * d, edgeSize)
			local sx, sz = unit(ax + fx * 1.5, az + fz * 1.5)
			d = edgeSize / 2 + rng:NextNumber(GRAPPLE.FarGap[1], GRAPPLE.FarGap[2]) + SHELL_SIZE / 2
			local mound = spec(edge.x + sx * d, edge.z + sz * d, SHELL_SIZE)

			local j = nearestAhead(mound, i + 3)
			local back = j and bridge(mound, route[j])
			if back then
				local chain = { tall, landing, edge, mound }
				table.move(back, 1, #back, #chain + 1, chain)
				-- Off the drop, nothing is a jump away but the next one.
				local stuck = { landing, edge }
				local isolated = outOfReach(landing, { platforms, chain }, { tall, edge })
					and outOfReach(edge, { platforms, chain }, { landing })
				-- Nor a way round another side path's far gap.
				for _, new in chain do
					isolated = isolated and outOfReach(new, { guarded })
				end
				if isolated and allFit(chain) then
					commit(chain)
					link(m, tall)
					link(tall, landing)
					link(landing, edge)
					link(edge, mound)
					local prev = mound
					for _, new in back do
						link(prev, new)
						prev = new
					end
					link(prev, route[j])
					table.insert(hooks, { from = edge, to = mound })
					table.move(stuck, 1, #stuck, #guarded + 1, guarded)
					table.insert(guarded, mound)
					if withShell then
						shell = mound
					end
					return true
				end
			end
		end
		return false
	end

	for branch = 1, stage.branches or 0 do
		if not sidePath(branch == 1) then
			return nil
		end
	end

	-- Grapple shortcuts: a hook over a route platform a far gap from an
	-- earlier one, across a bend, so a grapple skips the long way round. The
	-- route still goes round, so they're optional. The hook's post stands
	-- past the platform, to whichever side is clear (Forest.grappleHook).
	local function postAt(from, to, side)
		local ax, az = unit(to.x - from.x, to.z - from.z)
		local d = to.size / 2 + 2.2
		return Vector2.new(to.x + ax * d - az * side * 1.6, to.z + az * d + ax * side * 1.6)
	end
	local function postSide(from, to)
		for _, side in { 1, -1 } do
			local post = postAt(from, to, side)
			local px, pz = post.X, post.Y
			local clear = true
			for _, p in platforms do
				if math.sqrt((px - p.x) ^ 2 + (pz - p.z) ^ 2) - radius(p, true) < 1.5 then
					clear = false
				end
			end
			for _, pair in links do
				if Swamp.distanceToSegment(px, pz, pair[1].x, pair[1].z, pair[2].x, pair[2].z) < 2 then
					clear = false
				end
			end
			if clear then
				return side
			end
		end
		return nil
	end
	-- A shortcut goes straight across a far gap from one route platform to a
	-- later one, or, where the bend is wider, a jump onto a little stump out
	-- in the bend and the far gap from there. The longest skip wins.
	local function shortcutFrom(a, b)
		if apart(a, b) >= GRAPPLE.FarGap[1] and edgeGap(a, b) <= GRAPPLE.FarGap[2] + 4 then
			local side = postSide(a, b)
			return side and { from = a, to = b, side = side }, nil
		end
		-- The step: a jump from a, toward b or angled into the bend.
		local d = radius(a) + pickGap() + NOOK_SIZE / 2
		for _, turn in { 0, 0.35, -0.35, 0.7, -0.7 } do
			local ax, az = unit(b.x - a.x, b.z - a.z)
			ax, az = ax * math.cos(turn) - az * math.sin(turn), az * math.cos(turn) + ax * math.sin(turn)
			local step = spec(a.x + ax * d, a.z + az * d, NOOK_SIZE)
			if apart(step, b) >= GRAPPLE.FarGap[1] and edgeGap(step, b) <= GRAPPLE.FarGap[2] + 2 and fits(step) then
				table.insert(platforms, step)
				local side = postSide(step, b)
				table.remove(platforms)
				if side then
					return { from = step, to = b, side = side }, step
				end
			end
		end
		return nil
	end
	-- The crossings' hooks, which are free. Nothing to stand on may come
	-- within a jump of their ends (guarded) but the route either side.
	for _, g in crossAt do
		local from, to = route[g], route[g + 1]
		local side = postSide(from, to) or 1
		table.insert(hooks, { from = from, to = to, side = side, free = true })
		table.insert(posts, postAt(from, to, side))
		table.insert(guarded, from)
		table.insert(guarded, to)
	end

	for _ = 1, stage.shortcuts or 0 do
		local best, bestStep, bestSkip, bestFrom
		for i = 2, #route - 5 do
			for j = i + 4, #route - 1 do
				local taken = false
				for _, hook in hooks do
					taken = taken or hook.to == route[j] or hook.from == route[i]
				end
				if not taken and (not best or j - i > bestSkip) then
					local hook, step = shortcutFrom(route[i], route[j])
					if hook then
						best, bestStep, bestSkip, bestFrom = hook, step, j - i, route[i]
					end
				end
			end
		end
		if best then
			if bestStep then
				commit({ bestStep })
				link(bestFrom, bestStep)
			end
			table.insert(hooks, best)
			table.insert(posts, postAt(best.from, best.to, best.side))
			link(best.from, best.to)
		end
	end

	-- Whether a crossing lies between route places lo and hi (0 is the start
	-- island, #route + 1 the end island): anything joining them would be a
	-- way round it.
	local function spansCrossing(lo, hi)
		for _, g in crossAt do
			if lo <= g and hi > g then
				return true
			end
		end
		return false
	end
	-- The first and last route places within a jump of new.
	local function routeSpan(new)
		local lo, hi = math.huge, -math.huge
		for i, p in route do
			if apart(new, p) <= reach then
				lo, hi = math.min(lo, i), math.max(hi, i)
			end
		end
		if nearStart(new) then
			lo, hi = 0, math.max(hi, 0)
		end
		if nearEnd(new) then
			lo, hi = math.min(lo, #route + 1), #route + 1
		end
		return lo, hi
	end

	-- Forks: a second way from one route platform to one further on, more or
	-- less straight across the inside of a bend, zigzagging over little
	-- stumps a long jump apart. It skips at least FORK_SKIP platforms of the
	-- route, crosses no crossing, and comes within a jump of nothing but the
	-- route round its two ends.
	local forkGaps = { math.max(gaps[1], gaps[2] - 0.8), math.min(MAX_JUMP, gaps[2] + 0.2) }
	local function forkChain(a, b)
		local span = edgeGap(a, b)
		local ax, az = unit(b.x - a.x, b.z - a.z)
		local size = rng:NextNumber(FORK_SIZE[1], FORK_SIZE[2])
		local gap = rng:NextNumber(forkGaps[1], forkGaps[2])
		local count = math.max(1, math.floor((span - gap) / (size + gap) + 0.5))
		gap = (span - count * size) / (count + 1)
		if gap < forkGaps[1] - 0.6 or gap > forkGaps[2] then
			return nil
		end
		local chain = {}
		local d = radius(a) + gap + size / 2
		for k = 1, count do
			local off = (if k % 2 == 0 then 1 else -1) * rng:NextNumber(0.4, 1.4)
			table.insert(chain, spec(a.x + ax * d - az * off, a.z + az * d + ax * off, size * rng:NextNumber(0.92, 1.08)))
			d += size + gap
		end
		local steps = table.clone(chain)
		table.insert(steps, b)
		local last = a
		for _, p in steps do
			if edgeGap(last, p) > math.min(MAX_JUMP, forkGaps[2] + 0.3) or apart(last, p) < CLEARANCE then
				return nil
			end
			last = p
		end
		return chain
	end
	for _ = 1, stage.forks or 0 do
		local made = false
		for _ = 1, TRIES * 2 do
			local i = rng:NextInteger(3, math.max(3, #route - FORK_SKIP - 3))
			local j = math.min(#route - 2, i + FORK_SKIP + rng:NextInteger(0, FORK_SKIP))
			local a, b = route[i], route[j]
			local span = edgeGap(a, b)
			if j - i >= FORK_SKIP and a.kind ~= "log" and b.kind ~= "log" and not a.hooked and not b.hooked and not spansCrossing(i - 2, j + 2) and span > forkGaps[2] * 2 and span < 60 then
				local chain = forkChain(a, b)
				if chain and allFit(chain) then
					-- Round its ends, the route a couple of platforms either way.
					local near = {}
					for k = math.max(1, i - 2), math.min(#route, i + 2) do
						table.insert(near, route[k])
					end
					for k = math.max(1, j - 2), math.min(#route, j + 2) do
						table.insert(near, route[k])
					end
					local alone = true
					for k, p in chain do
						local except = table.clone(near)
						table.insert(except, chain[k - 1] or a)
						table.insert(except, chain[k + 1] or b)
						alone = alone and outOfReach(p, { platforms, guarded }, except) and not nearStart(p) and not nearEnd(p)
						for _, post in posts do
							alone = alone and (post - Vector2.new(p.x, p.z)).Magnitude > p.size / 2 + 1.2
						end
					end
					if alone then
						commit(chain)
						local last = a
						for _, p in chain do
							link(last, p)
							last = p
						end
						link(last, b)
						made = true
						break
					end
				end
			end
		end
		if not made then
			return nil
		end
	end

	-- No side path: the shell sits on a little stump a short jump off the route.
	if not shell then
		for _ = 1, TRIES do
			local i = rng:NextInteger(3, #route - 3)
			local m = route[i]
			local fx, fz = heading(i)
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local d = radius(m) + pickGap() + NOOK_SIZE / 2
			local nook = spec(m.x - fz * side * d, m.z + fx * side * d, NOOK_SIZE)
			if fits(nook) and not spansCrossing(routeSpan(nook)) and outOfReach(nook, { guarded }) then
				commit({ nook })
				link(m, nook)
				shell = nook
				break
			end
		end
	end

	-- The rest of the swamp ----------------------------------------------------
	-- Platforms all over it, most a jump or so off one already there. None may
	-- make a way round more than skip platforms of the route (so no jumping
	-- across a bend) or round a crossing, come within a jump of anything off
	-- the route (side paths, forks, the shell's stump, a shortcut's step), or
	-- sit on a jump.

	local skip = stage.skip or 3
	local routeIndex, offRoute = {}, {}
	for i, p in route do
		routeIndex[p] = i
	end
	for _, p in platforms do
		if not routeIndex[p] then
			table.insert(offRoute, p)
		end
	end
	-- Scattered platforms a jump apart make a group, which knows the first
	-- and last places on the route it touches (the start island is 0, the
	-- end island #route + 1).
	local scattered, groupOf = {}, {}
	local function touches(new)
		local lo, hi = routeSpan(new)
		local groups = {}
		local function mark(i)
			lo, hi = math.min(lo, i), math.max(hi, i)
		end
		for _, p in scattered do
			local group = groupOf[p]
			if not table.find(groups, group) and apart(new, p) <= reach then
				table.insert(groups, group)
				if group.lo <= group.hi then
					mark(group.lo)
					mark(group.hi)
				end
			end
		end
		return lo, hi, groups
	end
	-- On the line of a jump (links), or too near one to leave it clear.
	local function onAJump(new)
		local points, width = { Vector2.new(new.x, new.z) }, radius(new, true)
		if new.kind == "log" then
			width = LOG_WIDTH / 2
			for t = -0.5, 0.5, 0.25 do
				table.insert(points, Vector2.new(new.x + new.dir.X * new.size * t, new.z + new.dir.Y * new.size * t))
			end
		end
		for _, pair in links do
			for _, point in points do
				if Swamp.distanceToSegment(point.X, point.Y, pair[1].x, pair[1].z, pair[2].x, pair[2].z) < width + 1.5 then
					return true
				end
			end
		end
		return false
	end

	local wanted = math.floor((stage.scatter or 0) * 2 * band * (poolEnd - poolStart) / 1000)
	for _ = 1, wanted * 20 do
		if #scattered >= wanted then
			break
		end
		local style = STYLES[pickKind(rng, stage.styles)] or STYLES.wide
		local kind = pickKind(rng, style.kinds)
		local size = rng:NextNumber(style.scatter[1], style.scatter[2]) * (if style.shrinks then shrink else 1)
		local new
		if rng:NextNumber() < 0.7 then
			-- A jump or so off a platform already there, any way round.
			local base = if #scattered > 0 and rng:NextNumber() < 0.5 then scattered[rng:NextInteger(1, #scattered)] else route[rng:NextInteger(1, #route)]
			local bx, bz, from = base.x, base.z, radius(base)
			if base.kind == "log" then
				local t = rng:NextNumber(-0.5, 0.5) * base.size
				bx, bz, from = bx + base.dir.X * t, bz + base.dir.Y * t, LOG_WIDTH / 2
			end
			local angle = rng:NextNumber(0, math.pi * 2)
			local d = from + rng:NextNumber(gaps[1], gaps[2] + 2.5) + (if kind == "log" then LOG_WIDTH / 2 else radius({ kind = kind, size = size }))
			new = spec(bx + math.cos(angle) * d, bz + math.sin(angle) * d, size, 0, kind)
		else
			new = spec(rng:NextNumber(-band, band), rng:NextNumber(poolStart, poolEnd), size, 0, kind)
		end
		if kind == "log" then
			local angle = rng:NextNumber(0, math.pi * 2)
			new.dir = Vector2.new(math.cos(angle), math.sin(angle))
		end
		if fits(new, nil, math.max(CLEARANCE, gaps[1])) and outOfReach(new, { offRoute }) and not onAJump(new) then
			local lo, hi, groups = touches(new)
			if hi - lo <= skip and not spansCrossing(lo, hi) then
				commit({ new })
				table.insert(scattered, new)
				local group = { lo = lo, hi = hi, members = { new } }
				for _, other in groups do
					table.move(other.members, 1, #other.members, #group.members + 1, group.members)
				end
				for _, member in group.members do
					groupOf[member] = group
				end
				-- Keep its nearest jump clear of trees and plants.
				local nearest, best
				for _, list in { route, scattered } do
					for _, p in list do
						local gap = if p ~= new then apart(new, p) else math.huge
						if gap <= MAX_JUMP and (not best or gap < best) then
							nearest, best = p, gap
						end
					end
				end
				if nearest then
					link(new, nearest)
				end
			end
		end
	end

	-- Last, to be sure: no way round a crossing by jumping, however it winds.
	-- Platforms a jump apart (and the islands) make groups, and each far
	-- gap's two ends must be in different ones.
	if #crossAt > 0 then
		local parent = {}
		local function find(p)
			while parent[p] ~= p do
				parent[p] = parent[parent[p]]
				p = parent[p]
			end
			return p
		end
		local function join(a, b)
			parent[find(a)] = find(b)
		end
		local startIsland, endIsland = {}, {}
		parent[startIsland], parent[endIsland] = startIsland, endIsland
		for _, p in platforms do
			parent[p] = p
		end
		for n, p in platforms do
			if nearStart(p) then
				join(p, startIsland)
			end
			if nearEnd(p) then
				join(p, endIsland)
			end
			for m = n + 1, #platforms do
				if apart(p, platforms[m]) <= reach then
					join(p, platforms[m])
				end
			end
		end
		for _, g in crossAt do
			if find(route[g]) == find(route[g + 1]) then
				return nil
			end
		end
	end

	-- Waterlogged rafts that sink a moment after you land, and plank rafts
	-- that are old docks and creak (Hazards.luau): never either side of a
	-- far gap, nor among the first few on the route.
	if stage.sinking or stage.creaky then
		local ends = {}
		for _, hook in hooks do
			ends[hook.from], ends[hook.to] = true, true
		end
		for _, p in platforms do
			if (p.kind == "deck" or p.kind == "logRaft") and not ends[p] and (routeIndex[p] or math.huge) > 3 then
				if rng:NextNumber() < (stage.sinking or 0) then
					p.hazard = "sinking"
				elseif p.kind == "deck" and rng:NextNumber() < (stage.creaky or 0) then
					p.hazard = "creaky"
				end
			end
		end
	end

	for _, p in platforms do
		p.raise += area.raise or 0
	end
	return {
		platforms = platforms,
		links = links, -- pairs a jump (or a grapple) apart: kept clear of trees
		hooks = hooks, -- { from, to, side?, free? } across each far gap; side is where the hook's post goes, free for a crossing
		route = route, -- in order; a platform past a crossing is hooked
		shell = shell, -- the platform the shell sits on
		guarded = guarded, -- the far gaps' ends: nothing to stand on may come within a jump
	}
end

-- The layout of a swamp stage between poolStart and poolEnd, coming off a
-- start island startHalf wide and onto an end island endHalf wide, its
-- platforms raise above the usual height (area).
-- Returns { platforms, links, hooks, route, shell, guarded }.
function Swamp.layout(seed, stage, area)
	for try = 0, 30 do
		local result = attempt(Random.new(seed + try * 101), stage, area)
		if result then
			return result
		end
	end
	error(("Swamp: couldn't lay out %s; give it more room, or fewer branches, forks or crossings"):format(stage.name))
end

return Swamp
