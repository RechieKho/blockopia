-- Small helpers shared by the pure modules. No vb.* here.
local M = {}

function M.clamp(v, lo, hi)
	if v < lo then
		return lo
	end
	if v > hi then
		return hi
	end
	return v
end

function M.copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

function M.deep_copy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = M.deep_copy(v)
	end
	return out
end

function M.sorted_keys(t)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

function M.contains(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

function M.remove_value(list, value)
	for i = #list, 1, -1 do
		if list[i] == value then
			table.remove(list, i)
		end
	end
end

function M.split(s, sep)
	local out = {}
	for part in string.gmatch(s, "([^" .. sep .. "]+)") do
		out[#out + 1] = part
	end
	return out
end

function M.trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Integers that came back from JSON are floats (3.0); this makes them integers again.
function M.int(v)
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return nil
	end
	return math.floor(v)
end

-- True for a JSON/UI-supplied number that is a whole number in [lo, hi].
function M.is_int_in(v, lo, hi)
	return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

function M.pos_key(x, y, z)
	return string.format("%d,%d,%d", x, y, z)
end

function M.parse_pos_key(key)
	local x, y, z = key:match("^(-?%d+),(-?%d+),(-?%d+)$")
	return tonumber(x), tonumber(y), tonumber(z)
end

return M
