-- Shows the area a lock protects: posts in the lock tier's colour around its square, standing on
-- the ground, for balance.lock_border_seconds. Shown when a lock is placed, wrenched or resized.
local balance = require("data.balance")

local M = {}

local shown = {} -- lock id -> { entities = {...}, token = n }
local tokens = 0

-- Height of the ground at column (x, z), searching around `y`; nil if there is none nearby.
local function ground(x, z, y)
	for yy = y + 12, y - 12, -1 do
		if vb.world.get_block(x, yy, z) ~= 0 then
			return yy + 1
		end
	end
	return nil
end

-- Points along the square's outline (block corners), about `max_posts` of them, corners included.
function M.outline(box, max_posts)
	local x1, z1, x2, z2 = box.x1, box.z1, box.x2 + 1, box.z2 + 1
	local side = x2 - x1
	local step = math.max(2, math.ceil(4 * side / max_posts))
	local points = {}
	local function add(x, z)
		points[#points + 1] = { x = x, z = z }
	end
	for i = 0, side - 1, step do
		add(x1 + i, z1)
		add(x2, z1 + i)
		add(x2 - i, z2)
		add(x1, z2 - i)
	end
	return points
end

function M.hide(lock_id)
	local s = shown[lock_id]
	if not s then
		return
	end
	shown[lock_id] = nil
	for _, e in ipairs(s.entities) do
		pcall(e.remove, e, "border")
	end
end

function M.show(lock)
	M.hide(lock.id)
	local texture = "textures/border_" .. lock.tier .. ".png"
	local entities = {}
	for _, p in ipairs(M.outline(lock.box, balance.lock_border_posts)) do
		-- the column just inside the corner decides the height the post stands at
		local gx = p.x > lock.box.x2 and lock.box.x2 or p.x
		local gz = p.z > lock.box.z2 and lock.box.z2 or p.z
		local y = ground(gx, gz, lock.y)
		if y then
			local ok, e = pcall(vb.world.spawn, "bp:border", { x = p.x, y = y, z = p.z },
				{ visual_override = { texture = texture } })
			if ok and e then
				entities[#entities + 1] = e
			end
		end
	end
	tokens = tokens + 1
	local token = tokens
	shown[lock.id] = { entities = entities, token = token }
	vb.after(balance.lock_border_seconds, function()
		local s = shown[lock.id]
		if s and s.token == token then
			M.hide(lock.id)
		end
	end)
	return #entities
end

return M
