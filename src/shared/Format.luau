-- Small text helpers shared by the server and the client.

local Format = {}

-- A run time in seconds as minutes, seconds and tenths: 263.47 -> "4:23.4".
function Format.time(seconds)
	local tenths = math.floor(math.max(0, seconds) * 10)
	local minutes = math.floor(tenths / 600)
	return ("%d:%04.1f"):format(minutes, (tenths - minutes * 600) / 10)
end

return Format
