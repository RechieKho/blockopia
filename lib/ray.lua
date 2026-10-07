-- Voxel ray march (Amanatides & Woo). Pure: `get_block(x, y, z)` returns a block id, 0 for air.
--
-- The engine's own raycast (vb.world.raycast, Player:punch) only hits SOLID blocks, but shrubs,
-- lava and other walk-through blocks must be targetable too, so the pack marches the ray itself.
local M = {}

-- Returns { x, y, z, nx, ny, nz } for the first non-air voxel within `max` blocks, or nil.
-- (nx, ny, nz) is the face normal pointing back towards the origin.
function M.cast(get_block, ox, oy, oz, dx, dy, dz, max)
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	if len == 0 then
		return nil
	end
	dx, dy, dz = dx / len, dy / len, dz / len

	local x, y, z = math.floor(ox), math.floor(oy), math.floor(oz)
	local step_x, step_y, step_z = dx > 0 and 1 or -1, dy > 0 and 1 or -1, dz > 0 and 1 or -1
	local inf = math.huge
	local t_delta_x = dx ~= 0 and math.abs(1 / dx) or inf
	local t_delta_y = dy ~= 0 and math.abs(1 / dy) or inf
	local t_delta_z = dz ~= 0 and math.abs(1 / dz) or inf
	local function first_boundary(o, v, d, step)
		if d == 0 then
			return inf
		end
		local next_edge = step > 0 and (v + 1) or v
		return (next_edge - o) / d
	end
	local t_max_x = first_boundary(ox, x, dx, step_x)
	local t_max_y = first_boundary(oy, y, dy, step_y)
	local t_max_z = first_boundary(oz, z, dz, step_z)

	local nx, ny, nz = 0, 0, 0
	for _ = 1, 4 * math.ceil(max) + 8 do
		local t
		if t_max_x <= t_max_y and t_max_x <= t_max_z then
			t = t_max_x
			x, t_max_x = x + step_x, t_max_x + t_delta_x
			nx, ny, nz = -step_x, 0, 0
		elseif t_max_y <= t_max_z then
			t = t_max_y
			y, t_max_y = y + step_y, t_max_y + t_delta_y
			nx, ny, nz = 0, -step_y, 0
		else
			t = t_max_z
			z, t_max_z = z + step_z, t_max_z + t_delta_z
			nx, ny, nz = 0, 0, -step_z
		end
		if t > max then
			return nil
		end
		if get_block(x, y, z) ~= 0 then
			return { x = x, y = y, z = z, nx = nx, ny = ny, nz = nz }
		end
	end
	return nil
end

return M
