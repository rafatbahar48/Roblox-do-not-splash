-- Lays out an open swamp stage (Stages.luau, layout = "swamp"): platforms
-- scattered over wide water instead of one trail of stepping stones.
--
-- A route you can always jump winds from side to side across the swamp,
-- from the start island to the end island. Side paths branch off it. Each
-- starts with a drop off a tall stump that you can jump down but not back
-- up, then crosses a gap too far to jump (Config.Grapple.FarGap) under a
-- hook for the grapple, and comes back to the route further on: whoever
-- takes one gets across with a grapple, an Updraft, or by wading. The first
-- one's far side has the stage's shell; with no side paths, it is on a
-- little stump a short jump off the route. The rest of the swamp can be
-- dotted with platforms (scatter), some a jump from the others and some
-- only a wade.
--
-- Platforms are specs as in MapBuilder.luau: { kind, size, x, z, raise },
-- kind "stump" or "deck" (Forest.luau). size is the width a jump is
-- measured to.
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
local TRIES = 40

local Swamp = {}

-- Distance from point p to the segment a-b, on the ground plane.
function Swamp.distanceToSegment(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local lengthSquared = dx * dx + dz * dz
	local t = if lengthSquared > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / lengthSquared, 0, 1) else 0
	local cx, cz = ax + dx * t - px, az + dz * t - pz
	return math.sqrt(cx * cx + cz * cz)
end

-- Water between two platforms, edge to edge.
local function edgeGap(a, b)
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz) - (a.size + b.size) / 2
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

-- One try at a layout; nil if it didn't work out.
local function attempt(rng, stage, area)
	local band = stage.halfWidth
	local gaps, sizes = stage.gap, stage.tileSize
	local poolStart, poolEnd = area.poolStart, area.poolEnd
	local platforms, links, hooks = {}, {}, {}
	local guarded = {} -- platforms nothing else may come within a jump of

	local function pickSize()
		return rng:NextNumber(sizes[1], sizes[2])
	end
	local function pickGap()
		return rng:NextNumber(gaps[1], gaps[2])
	end

	-- Inside the swamp and clear of every platform, and of the pending ones.
	local function fits(new, pending, clearance)
		if math.abs(new.x) > band - new.size / 2 then
			return false
		end
		if new.z - new.size / 2 < poolStart + 1 or new.z + new.size / 2 > poolEnd - 1 then
			return false
		end
		for _, list in { platforms, pending or {} } do
			for _, other in list do
				if edgeGap(new, other) < (clearance or CLEARANCE) then
					return false
				end
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
				if other ~= new and not (except and table.find(except, other)) and edgeGap(new, other) <= MAX_JUMP + 1 then
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

	-- Where it turns: alternately well out to the left and the right, then in
	-- line with the end island, and into it.
	local points = {}
	local turns = math.max(2, math.floor((poolEnd - poolStart) / 55))
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	for i = 1, turns do
		local z = poolStart + (poolEnd - poolStart) * i / (turns + 1)
		table.insert(points, { x = side * rng:NextNumber(band * 0.6, band - 6), z = z })
		side = -side
	end
	local endX = rng:NextNumber(-area.endHalf + 8, area.endHalf - 8)
	table.insert(points, { x = endX, z = poolEnd - 30 })
	table.insert(points, { x = endX, z = poolEnd + 10 })

	-- A jump from the end island (x within endHalf, z from poolEnd on)?
	local function reachesEnd(p)
		local dx = math.max(0, math.abs(p.x) - area.endHalf)
		local dz = math.max(0, poolEnd - p.z)
		return math.sqrt(dx * dx + dz * dz) - p.size / 2 <= gaps[2]
	end

	local route = {}
	local first = pickSize()
	route[1] = spec(rng:NextNumber(-area.startHalf + 5, area.startHalf - 5), poolStart + pickGap() + first / 2, first, 0, pickKind(rng, stage.mix))
	commit({ route[1] })
	local target = 1
	while not reachesEnd(route[#route]) do
		if #route > 80 then
			return nil
		end
		local prev = route[#route]
		local goal = points[target]
		while target < #points and math.sqrt((goal.x - prev.x) ^ 2 + (goal.z - prev.z) ^ 2) < 9 do
			target += 1
			goal = points[target]
		end
		local dx, dz = unit(goal.x - prev.x, goal.z - prev.z)
		local nextOne
		for try = 0, 6 do
			local size, gap = pickSize(), pickGap()
			-- A little off the straight line; swung forward if it lands too
			-- near another platform.
			local wobble = rng:NextNumber(-0.25, 0.25)
			local fx, fz = unit(dx * math.cos(wobble) - dz * math.sin(wobble), dz * math.cos(wobble) + dx * math.sin(wobble) + try * 0.4)
			local distance = gap + (prev.size + size) / 2
			local x = math.clamp(prev.x + fx * distance, -band + size / 2, band - size / 2)
			local z = prev.z + fz * distance
			if z + size / 2 > poolEnd - 1.5 then
				-- Nearly there: one last platform that fits in front of the island.
				local room = poolEnd - 1.5 - (prev.z + prev.size / 2)
				size = math.clamp(room - 2 * gaps[1], 3, sizes[2])
				gap = (room - size) / 2
				fx, fz = unit((endX - prev.x) * 0.2, 1)
				distance = gap + (prev.size + size) / 2
				x = math.clamp(prev.x + fx * distance, -band + size / 2, band - size / 2)
				z = prev.z + fz * distance
			end
			local candidate = spec(x, z, size, 0, pickKind(rng, stage.mix))
			local jump = edgeGap(candidate, prev)
			if jump <= MAX_JUMP and jump >= CLEARANCE and fits(candidate) then
				nextOne = candidate
				break
			end
		end
		if not nextOne then
			return nil
		end
		commit({ nextOne })
		link(prev, nextOne)
		table.insert(route, nextOne)
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
			local distance = gap + (prev.size + size) / 2
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

			local d = m.size / 2 + 2.6 + TALL_SIZE / 2
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

	-- No side path: the shell sits on a little stump a short jump off the route.
	if not shell then
		for _ = 1, TRIES do
			local i = rng:NextInteger(3, #route - 3)
			local m = route[i]
			local fx, fz = heading(i)
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local d = m.size / 2 + pickGap() + NOOK_SIZE / 2
			local nook = spec(m.x - fz * side * d, m.z + fx * side * d, NOOK_SIZE)
			if fits(nook) then
				commit({ nook })
				link(m, nook)
				shell = nook
				break
			end
		end
	end

	-- The rest of the swamp ----------------------------------------------------

	local wanted = math.floor((stage.scatter or 0) * 2 * band * (poolEnd - poolStart) / 1000)
	local placed = 0
	for _ = 1, wanted * 6 do
		if placed >= wanted then
			break
		end
		local size = rng:NextNumber(3.5, sizes[2])
		local new = spec(rng:NextNumber(-band, band), rng:NextNumber(poolStart, poolEnd), size, 0, pickKind(rng, stage.mix))
		local clear = fits(new, nil, 3) and outOfReach(new, { guarded })
		if clear then
			for _, pair in links do
				if Swamp.distanceToSegment(new.x, new.z, pair[1].x, pair[1].z, pair[2].x, pair[2].z) < size / 2 + 1.5 then
					clear = false
					break
				end
			end
		end
		if clear then
			commit({ new })
			placed += 1
		end
	end

	for _, p in platforms do
		p.raise += area.raise or 0
	end
	return {
		platforms = platforms,
		links = links, -- pairs a jump (or a grapple) apart: kept clear of trees
		hooks = hooks, -- { from, to } across each far gap
		route = route,
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
	error(("Swamp: couldn't lay out %s; give it more room or fewer branches"):format(stage.name))
end

return Swamp
