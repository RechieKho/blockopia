-- Named worlds: every world name hashes to one 1024 x 1024 cell of the single big map.
local wn = require("lib.worldname")
local store = require("game.store")
local accounts = require("game.accounts")
local notify = require("game.notify")
local locks = require("game.locks")
local balance = require("data.balance")

local M = {}

local G, CELL = balance.world_grid, balance.world_cell_size

local by_name, by_cell, loaded = {}, {}, false

local function ensure()
	if loaded then
		return
	end
	loaded = true
	local saved = store.get("worlds:registry") or {}
	for name, idx in pairs(saved) do
		idx = math.floor(idx)
		by_name[name] = idx
		by_cell[idx] = name
	end
	if not by_name[balance.hub_name] then
		wn.assign(balance.hub_name, by_name, by_cell, G, balance.hub_name)
		store.set("worlds:registry", by_name)
	end
end

function M.cell_at(x, z)
	return wn.cell_at(x, z, CELL, G)
end

-- Name of the world at (x, z), or nil for a cell nobody has named.
function M.name_at(x, z)
	ensure()
	local idx = M.cell_at(x, z)
	return idx and by_cell[idx] or nil
end

function M.center(idx)
	return wn.center_of(idx, CELL, G)
end

-- Where players arrive in a world: the owner's chosen spawn, else above the world centre.
function M.spawn_of(idx)
	local custom = store.get("worlds:spawn:" .. idx)
	if custom then
		return custom.x, custom.y, custom.z
	end
	local cx, cz = M.center(idx)
	return cx + 0.5, balance.world_spawn_y, cz + 0.5
end

function M.owner_name(idx)
	local cx, cz = M.center(idx)
	return locks.owner_name_at(cx, cz)
end

function M.teleport(player, x, y, z)
	player:set_pos(x, y, z)
end

-- player_death handler. Returns a DeathDecision table or nil.
function M.on_death(player)
	local health = player:get_health()
	local full = health and health.max or 20
	-- Respawn in the world where the player died.
	local p = player:get_pos()
	local idx = M.cell_at(p.x, p.z)
	if idx then
		ensure()
		local x, y, z = M.spawn_of(idx)
		return { heal = full, pos = { x = x, y = y, z = z } }
	end
	return nil
end

-- Warp to a world by name. Returns true on success.
function M.warp(player, raw_name)
	ensure()
	local name, why = wn.normalize(raw_name, balance.world_name_max)
	if not name then
		notify.say(player, "Cannot warp: " .. why)
		return false
	end
	local idx, is_new = wn.assign(name, by_name, by_cell, G, balance.hub_name)
	if not idx then
		notify.say(player, "Every world slot is taken.")
		return false
	end
	if is_new then
		store.set("worlds:registry", by_name)
	end
	local acc = accounts.of(player)
	if acc then
		local recent = acc.recent_worlds or {}
		for i = #recent, 1, -1 do
			if recent[i] == name then
				table.remove(recent, i)
			end
		end
		table.insert(recent, 1, name)
		while #recent > 8 do
			table.remove(recent)
		end
		acc.recent_worlds = recent
	end
	local x, y, z = M.spawn_of(idx)
	M.teleport(player, x, y, z)
	notify.say(player, "Warping to " .. name .. (is_new and " (a brand new world!)" or "") .. "...")
	return true
end

-- The owner of the land at the world's centre may move its arrival point to where they stand.
function M.set_spawn(player)
	ensure()
	local acc = accounts.of(player)
	local p = player:get_pos()
	local idx = M.cell_at(p.x, p.z)
	if not idx or not by_cell[idx] then
		notify.say(player, "You are not in a named world.")
		return
	end
	local cx, cz = M.center(idx)
	local cover = locks.covering(cx, cz)
	local owner = cover[#cover]
	if not owner or owner.owner ~= acc.subject then
		notify.say(player, "Only the owner of the lock covering the world's centre can set its spawn.")
		return
	end
	store.set("worlds:spawn:" .. idx, { x = p.x, y = p.y + 1, z = p.z })
	notify.say(player, "Spawn point of " .. by_cell[idx] .. " moved here.")
end

function M.info(player)
	ensure()
	local p = player:get_pos()
	local idx = M.cell_at(p.x, p.z)
	if not idx then
		return "You are outside the mapped area."
	end
	local name = by_cell[idx] or "(unnamed wilderness)"
	local owner = M.owner_name(idx)
	return string.format("World %s%s", name, owner and (" - owned by " .. owner) or " - unclaimed")
end

function M.list_recent(acc)
	return acc.recent_worlds or {}
end

return M
