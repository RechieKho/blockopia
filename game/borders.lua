-- Shows the area a lock protects: posts in the lock tier's colour around its square, standing on
-- the ground, for balance.lock_border_seconds. Shown when a lock is placed, wrenched or resized.
-- While a player holds a lock, a preview ring follows where it would go (red where it cannot).
local balance = require("data.balance")
local L = require("lib.locks")
local tiers = require("data.locks")

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

-- Where the posts of `box` stand: on the ground of the column just inside each outline point, or
-- at `y` when there is no ground nearby (if `keep_all`; otherwise that post is left out).
local function post_spots(box, y, keep_all)
	local spots = {}
	for _, p in ipairs(M.outline(box, balance.lock_border_posts)) do
		local gx = p.x > box.x2 and box.x2 or p.x
		local gz = p.z > box.z2 and box.z2 or p.z
		local gy = ground(gx, gz, y) or (keep_all and y or nil)
		if gy then
			spots[#spots + 1] = { x = p.x, y = gy, z = p.z }
		end
	end
	return spots
end

local function spawn_at(spots, texture)
	local entities = {}
	for _, s in ipairs(spots) do
		local ok, e = pcall(vb.world.spawn, "bp:border", s, { visual_override = { texture = texture } })
		if ok and e then
			entities[#entities + 1] = e
		end
	end
	return entities
end

local function spawn_posts(box, y, texture)
	return spawn_at(post_spots(box, y, false), texture)
end

local function remove_all(entities)
	for _, e in ipairs(entities) do
		pcall(e.remove, e, "border")
	end
end

function M.is_shown(lock_id)
	return shown[lock_id] ~= nil
end

function M.hide(lock_id)
	local s = shown[lock_id]
	if not s then
		return
	end
	shown[lock_id] = nil
	remove_all(s.entities)
end

function M.show(lock)
	M.hide(lock.id)
	local entities = spawn_posts(lock.box, lock.y, "textures/border_" .. lock.tier .. ".png")
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

local previews = {} -- player name -> { at = "x,y,z", look = "tier,blocked", entities = {...} }

-- Shows the preview ring of a `tier_key` lock placed at (x, y, z); `blocked` turns it red. When only
-- the spot changes, the existing posts are moved instead of respawned.
function M.preview(player, tier_key, x, y, z, blocked)
	local name = player:get_name()
	local at, look = x .. "," .. y .. "," .. z, tier_key .. "," .. tostring(blocked)
	local p = previews[name]
	if p and p.at == at and p.look == look then
		return
	end
	local spots = post_spots(L.box_of(x, z, tiers[tier_key].size), y, true)
	if p and p.look == look and #p.entities == #spots then
		for i, e in ipairs(p.entities) do
			pcall(e.set_pos, e, spots[i].x, spots[i].y, spots[i].z)
		end
		p.at = at
		return
	end
	M.clear_preview(player)
	local texture = blocked and "textures/border_blocked.png" or ("textures/border_" .. tier_key .. ".png")
	previews[name] = { at = at, look = look, entities = spawn_at(spots, texture) }
end

function M.clear_preview(player)
	local name = player:get_name()
	local p = previews[name]
	if p then
		previews[name] = nil
		remove_all(p.entities)
	end
end

function M.preview_posts(player)
	local p = previews[player:get_name()]
	return p and p.entities or {}
end

return M
