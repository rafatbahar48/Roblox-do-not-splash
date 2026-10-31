-- Only one menu window (shop, bag, stats, settings) is open at a time:
-- opening one closes the others.

local Windows = {}

local closers = {}

-- Adds a window by the function that closes it. Returns a function to call
-- as it opens, which closes the rest.
function Windows.add(close)
	table.insert(closers, close)
	return function()
		for _, other in closers do
			if other ~= close then
				other()
			end
		end
	end
end

return Windows
