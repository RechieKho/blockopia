-- Lock regions on the server: records, the spatial index, protection checks and the lock screen.
local L = require("lib.locks")
local store = require("game.store")
local accounts = require("game.accounts")
local notify = require("game.notify")
local ids = require("game.ids")
local ledger = require("game.ledger")
local util = require("lib.util")
local tiers = require("data.locks")

local M = {}

local index = L.new_index()
local loaded = false

local function lock_key(id)
	return "lock:" .. id
end

local function ensure()
	if loaded then
		return
	end
	loaded = true
	for _, id in ipairs(store.get("idx:locks") or {}) do
		local rec = store.get(lock_key(util.int(id)))
		if rec then
			rec.id, rec.x, rec.y, rec.z, rec.size = util.int(rec.id), util.int(rec.x), util.int(rec.y),
				util.int(rec.z), util.int(rec.size)
			rec.admins, rec.builders, rec.names = rec.admins or {}, rec.builders or {}, rec.names or {}
			index:add(rec)
		end
	end
end

local function save(rec)
	local copy = {}
	for k, v in pairs(rec) do
		if k ~= "box" then
			copy[k] = v
		end
	end
	store.set(lock_key(rec.id), copy)
end

local function save_index()
	local list = {}
	for id in pairs(index.by_id) do
		list[#list + 1] = id
	end
	table.sort(list)
	store.set("idx:locks", list)
end

function M.index()
	ensure()
	return index
end

function M.get(id)
	ensure()
	return index.by_id[id]
end

-- May this player break/place/plant/harvest at the column (x, z)?
function M.can_build(acc, x, z)
	ensure()
	return index:can_build(acc.subject, x, z)
end

-- The lock whose block sits exactly at (x, y, z), if any.
function M.at_block(x, y, z)
	ensure()
	for _, lock in ipairs(index:at(x, z)) do
		if lock.x == x and lock.y == y and lock.z == z then
			return lock
		end
	end
	return nil
end

-- Locks covering a column, innermost first.
function M.covering(x, z)
	ensure()
	return index:at(x, z)
end

-- Checks before a lock block is placed. Returns true, or false and a reason.
function M.can_place(acc, tier_key, x, y, z)
	ensure()
	local tier = tiers[tier_key]
	local box = L.box_of(x, z, tier.size)
	if not index:can_build(acc.subject, x, z) then
		return false, "you cannot build here"
	end
	return index:can_place(acc.subject, x, z, box)
end

-- Called after the lock block was placed.
function M.create(tier_key, player, pos)
	ensure()
	local acc = accounts.of(player)
	local tier = tiers[tier_key]
	local seq = util.int(store.get("lock:next") or 0) + 1
	store.set("lock:next", seq)
	local rec = {
		id = seq, tier = tier_key, owner = acc.subject, owner_name = acc.name,
		x = pos.x, y = pos.y, z = pos.z, size = tier.size,
		admins = {}, builders = {}, names = {}, public = false, created = store.now(),
	}
	index:add(rec)
	save(rec)
	save_index()
	ledger.log("admin", { to = acc.subject, note = string.format("placed %s #%d at %d,%d,%d", tier.name, seq, pos.x, pos.y, pos.z) })
	notify.say(player, string.format("%s #%d now protects a %dx%d area around it (marked for a moment). Use the wrench on it to manage access.",
		tier.name, seq, rec.size, rec.size))
	require("game.borders").show(rec)
	return rec
end

-- May this player break the lock block? Returns true, or false and a reason.
function M.can_remove(acc, lock)
	if lock.owner ~= acc.subject then
		return false, "only the owner can remove this lock"
	end
	if #index:foreign_inside(lock) > 0 then
		return false, "other players have locks inside this area; they must remove them first"
	end
	return true
end

-- The lock block is already gone. Forget the region and hand the item back to its owner.
function M.remove(lock, player)
	require("game.borders").hide(lock.id)
	index:remove(lock.id)
	store.delete(lock_key(lock.id))
	save_index()
	local item = ids.id("bp:lock_" .. lock.tier)
	if player then
		player:give({ item = item, count = 1 })
	end
	ledger.log("admin", { from = lock.owner, note = string.format("removed lock #%d", lock.id) })
end

-- The player's own lock count, for the almanac and moderation.
function M.owned_by(subject)
	ensure()
	local n = 0
	for _, lock in pairs(index.by_id) do
		if lock.owner == subject then
			n = n + 1
		end
	end
	return n
end

-- Moderators: forget a lock record (and clear its block) without the owner.
function M.force_remove(id)
	ensure()
	local lock = index.by_id[id]
	if not lock then
		return false
	end
	vb.world.set_block(lock.x, lock.y, lock.z, 0)
	M.remove(lock, nil)
	return true
end

-- Who owns the land at a world's centre (shown as the world's owner).
function M.owner_name_at(x, z)
	ensure()
	local cover = index:at(x, z)
	if #cover == 0 then
		return nil
	end
	return cover[#cover].owner_name
end

-- ---- lock screen -------------------------------------------------------------------------

local function names_of(lock, list)
	local out = {}
	for _, subject in ipairs(list) do
		out[#out + 1] = lock.names[subject] or accounts.display_name_of(subject)
	end
	return out
end

function M.open_screen(player, lock)
	local acc = accounts.of(player)
	local tier = tiers[lock.tier]
	local can_edit = lock.owner == acc.subject
	local is_admin = L.is_owner_or_admin(lock, acc.subject)
	require("game.borders").show(lock)
	require("game.ui_events").set_context(player, { screen = "bp:lock", lock_id = lock.id })
	require("game.ui_events").open(player, "bp:lock", {
		id = lock.id, tier = tier.name, owner = lock.owner_name, size = lock.size,
		max_size = tier.size, adjustable = tier.adjustable, public = lock.public,
		admins = names_of(lock, lock.admins), builders = names_of(lock, lock.builders),
		can_edit = can_edit, is_admin = is_admin, x = lock.x, z = lock.z,
		x1 = lock.box.x1, z1 = lock.box.z1, x2 = lock.box.x2, z2 = lock.box.z2,
	})
end

local function add_member(lock, role, subject, name)
	local list = role == "admin" and lock.admins or lock.builders
	if not util.contains(list, subject) then
		list[#list + 1] = subject
	end
	lock.names[subject] = name
end

local function remove_member(lock, role, subject)
	local list = role == "admin" and lock.admins or lock.builders
	util.remove_value(list, subject)
end

-- Handles the lock screen's events. `ctx` is the server-side context saved when it opened.
function M.on_ui_event(player, ctx, kind, value)
	ensure()
	local lock = index.by_id[ctx.lock_id]
	local acc = accounts.of(player)
	if not lock or not acc or lock.owner ~= acc.subject then
		return
	end
	local tier = tiers[lock.tier]
	if kind == "lock_size" then
		if not tier.adjustable or type(value) ~= "table" or not util.is_int_in(value.delta, -1000, 1000) then
			return
		end
		local size = util.clamp(lock.size + value.delta, 1, tier.size)
		if size ~= lock.size then
			local box = L.box_of(lock.x, lock.z, size)
			local ok, why = index:can_place(acc.subject, lock.x, lock.z, box, lock.id)
			if not ok then
				notify.say(player, "Cannot resize: " .. why)
			else
				index:remove(lock.id)
				lock.size = size
				index:add(lock)
				save(lock)
				require("game.borders").show(lock)
			end
		end
	elseif kind == "lock_public" then
		if type(value) ~= "table" or type(value.value) ~= "boolean" then
			return
		end
		lock.public = value.value
		save(lock)
	elseif kind == "lock_add" then
		if type(value) ~= "table" or type(value.name) ~= "string" or (value.role ~= "admin" and value.role ~= "builder") then
			return
		end
		local name = util.trim(value.name)
		local subject = accounts.subject_of_name(name)
		if not subject then
			notify.say(player, "No player called '" .. name .. "' has joined yet.")
		elseif subject == lock.owner then
			notify.say(player, "You already own this lock.")
		else
			add_member(lock, value.role, subject, accounts.display_name_of(subject))
			save(lock)
		end
	elseif kind == "lock_remove" then
		if type(value) ~= "table" or type(value.index) ~= "number" or (value.role ~= "admin" and value.role ~= "builder") then
			return
		end
		local list = value.role == "admin" and lock.admins or lock.builders
		local subject = list[math.floor(value.index)]
		if subject then
			remove_member(lock, value.role, subject)
			save(lock)
		end
	else
		return
	end
	M.open_screen(player, lock)
end

return M
