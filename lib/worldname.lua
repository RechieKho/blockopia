-- World names -> cells of a G x G grid of square cells centred on the origin. Pure.
local M = {}

local BLOCKLIST = { "FUCK", "SHIT", "NAZI", "RAPE", "CUNT", "NIGGER", "FAGGOT" }

-- Returns the normalised name, or nil and a reason.
function M.normalize(name, max_len)
	if type(name) ~= "string" then
		return nil, "world names are text"
	end
	local up = name:upper():gsub("[^A-Z0-9]", "")
	if #up == 0 then
		return nil, "a world name needs letters or digits"
	end
	if #up > max_len then
		return nil, "world names are at most " .. max_len .. " characters"
	end
	for _, bad in ipairs(BLOCKLIST) do
		if up:find(bad, 1, true) then
			return nil, "that name is not allowed"
		end
	end
	return up
end

-- 32-bit FNV-1a.
function M.fnv1a(s)
	local h = 2166136261
	for i = 1, #s do
		h = h ~ s:byte(i)
		h = (h * 16777619) & 0xFFFFFFFF
	end
	return h
end

-- Cell index <-> grid coordinates. Index i in [0, G*G); gx, gz in [-G/2, G/2).
function M.index_of(gx, gz, G)
	return (gx + G // 2) + (gz + G // 2) * G
end

function M.coords_of(index, G)
	return (index % G) - G // 2, (index // G) - G // 2
end

function M.hub_index(G)
	return M.index_of(0, 0, G)
end

-- The cell containing block coordinates (x, z).
function M.cell_at(x, z, cell_size, G)
	local gx = math.floor(x / cell_size)
	local gz = math.floor(z / cell_size)
	if gx < -G // 2 or gx >= G // 2 or gz < -G // 2 or gz >= G // 2 then
		return nil
	end
	return M.index_of(gx, gz, G)
end

function M.center_of(index, cell_size, G)
	local gx, gz = M.coords_of(index, G)
	return gx * cell_size + cell_size // 2, gz * cell_size + cell_size // 2
end

-- Probe step: odd, so it is coprime with G*G whenever G is a power of two.
local STEP = 40503

-- Finds the cell for `name` (already normalised).
--   by_name : map name -> cell index   (saved registry)
--   by_cell : map cell index -> name
-- Returns index, is_new. Mutates both maps when the name is new. Returns nil when the grid is full.
function M.assign(name, by_name, by_cell, G, hub_name)
	local existing = by_name[name]
	if existing then
		return existing, false
	end
	local n = G * G
	local hub = M.hub_index(G)
	if name == hub_name then
		by_name[name], by_cell[hub] = hub, name
		return hub, true
	end
	local h = M.fnv1a(name) % n
	for k = 0, n - 1 do
		local idx = (h + k * STEP) % n
		if idx ~= hub and not by_cell[idx] then
			by_name[name], by_cell[idx] = idx, name
			return idx, true
		end
	end
	return nil
end

return M
