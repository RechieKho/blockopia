-- Planting, growing, splicing and harvesting shrubs.
local farm = require("lib.farm")
local splice = require("lib.splice")
local store = require("game.store")
local accounts = require("game.accounts")
local locks = require("game.locks")
local notify = require("game.notify")
local ids = require("game.ids")
local inventory = require("game.inventory")
local drops = require("lib.drops")
local balance = require("data.balance")
local splices = require("data.splices")

local M = {}

local shrubs = store.collection("shrubs", 64)
local recipes = splice.build(splices)

local function total_for(rarity)
	return farm.grow_seconds(rarity, balance.grow_scale)
end

-- Stage the shrub is really at right now (the block in the world may lag behind the sweep).
local function actual_stage(rec)
	return farm.stage(store.now() - rec.planted_at, rec.total, balance.stage_growing_at)
end

local function drop_at(x, y, z, item, count)
	vb.world.spawn_item_drop({ x = x + 0.5, y = y + 0.5, z = z + 0.5 }, item, count)
end

function M.get(x, y, z)
	return shrubs:get(x, y, z)
end

-- True when the player may plant here, with the soil block at (x, y, z) and the seed's species.
function M.plant(player, acc, x, y, z, seed_meta)
	local soil = vb.world.get_block(x, y, z)
	local soil_meta = ids.meta(soil)
	if soil == 0 or (soil_meta and (soil_meta.kind == "shrub" or soil_meta.kind == "seed" or soil_meta.hazard)) then
		return false
	end
	if vb.world.get_block(x, y + 1, z) ~= 0 then
		notify.throttled(player, "There is no room to plant here.")
		return false
	end
	if not locks.can_build(acc, x, z) then
		notify.throttled(player, "This land is locked.")
		return false
	end
	local sp = ids.species[seed_meta.species]
	if not inventory.take(player, sp.seed, 1) then
		return false
	end
	vb.world.set_block(x, y + 1, z, sp.stages[0])
	shrubs:set(x, y + 1, z, {
		species = sp.key, planted_at = store.now(), total = total_for(sp.rarity),
		planter = acc.subject, spliced = false, stage = 0,
	})
	notify.say(player, string.format("Planted %s. Ripe in %s.", sp.label, farm.format_duration(total_for(sp.rarity))))
	return true
end

-- Use `seed_meta` on the shrub at (x, y, z). Returns true when the seed was used up.
function M.splice(player, acc, x, y, z, seed_meta)
	local rec = shrubs:get(x, y, z)
	if not rec then
		return false
	end
	if not locks.can_build(acc, x, z) then
		notify.throttled(player, "This land is locked.")
		return false
	end
	if actual_stage(rec) >= 2 then
		notify.throttled(player, "The shrub is already ripe; seeds can only be spliced into growing shrubs.")
		return false
	end
	if rec.spliced then
		notify.throttled(player, "This shrub was already spliced.")
		return false
	end
	local child_key = splice.lookup(recipes, rec.species, seed_meta.species)
	if not child_key then
		notify.throttled(player, "These seeds can't be spliced.")
		return false
	end
	local seed_id = ids.species[seed_meta.species].seed
	if not inventory.take(player, seed_id, 1) then
		return false
	end
	local child = ids.species[child_key]
	local parents = { rec.species, seed_meta.species }
	rec.species, rec.spliced, rec.parents = child_key, true, parents
	rec.planted_at, rec.total, rec.stage = store.now(), total_for(child.rarity), 0
	shrubs:touch(x, z)
	vb.world.set_block(x, y, z, child.stages[0])
	acc.recipes[splice.pair_key(parents[1], parents[2])] = child_key
	local new = accounts.discover(acc, child_key)
	notify.say(player, string.format("Splice! The shrub is now a %s shrub%s.", child.label,
		new and " - a new species for your almanac" or ""))
	return true
end

-- Wrench on a shrub.
function M.inspect(player, x, y, z)
	local rec = shrubs:get(x, y, z)
	if not rec then
		return
	end
	local sp = ids.species[rec.species]
	local elapsed = store.now() - rec.planted_at
	local stage = actual_stage(rec)
	local text
	if stage >= 2 then
		text = string.format("%s shrub: ripe! Punch it to harvest.", sp.label)
	else
		text = string.format("%s shrub (rarity %d): %s left.", sp.label, sp.rarity,
			farm.format_duration(farm.time_left(elapsed, rec.total)))
	end
	if rec.parents then
		text = text .. string.format(" Spliced from %s + %s.", ids.species[rec.parents[1]].label,
			ids.species[rec.parents[2]].label)
	end
	notify.say(player, text)
end

-- on_break for a shrub stage block: a ripe shrub is harvested, an unripe one is just destroyed.
function M.on_broken(meta, ctx)
	local p = ctx.pos
	local rec = shrubs:get(p.x, p.y, p.z)
	if not rec then
		return
	end
	shrubs:remove(p.x, p.y, p.z)
	local acc = accounts.of(ctx.player)
	if actual_stage(rec) < 2 then
		if acc then
			notify.throttled(ctx.player, "The shrub wasn't ripe, so it was destroyed.")
		end
		return
	end
	local sp = ids.species[rec.species]
	local count = farm.yield(sp.rarity, balance, math.random)
	drop_at(p.x, p.y, p.z, sp.block, count)
	if math.random() < sp.seed_chance then
		drop_at(p.x, p.y, p.z, sp.seed, 1)
	end
	if acc then
		if math.random() < balance.coin_chance then
			local coins = math.max(1, math.floor(drops.coin_amount(sp.rarity, balance, math.random) * balance.harvest_coin_factor))
			accounts.add_coins(acc, coins, "break")
		end
		accounts.discover(acc, sp.key)
		acc.stats.harvests = (acc.stats.harvests or 0) + 1
		require("game.hud").push(ctx.player)
	end
end

-- A block was broken: a shrub standing on it is destroyed too.
function M.on_support_broken(x, y, z)
	local rec = shrubs:get(x, y + 1, z)
	if rec then
		shrubs:remove(x, y + 1, z)
		local id = vb.world.get_block(x, y + 1, z)
		local meta = ids.meta(id)
		if meta and meta.kind == "shrub" then
			vb.world.set_block(x, y + 1, z, 0)
		end
	end
end

local function refresh(x, y, z, rec)
	local stage = actual_stage(rec)
	if stage == rec.stage then
		return
	end
	local sp = ids.species[rec.species]
	local current = ids.meta(vb.world.get_block(x, y, z))
	if not (current and current.kind == "shrub") then
		-- Air here usually means the chunk is not loaded, not that the shrub is gone: keep the
		-- record and try again on the next sweep. (Every real removal goes through on_broken.)
		return
	end
	vb.world.set_block(x, y, z, sp.stages[stage])
	rec.stage = stage
	shrubs:touch(x, z)
end

-- Re-stages shrubs near online players. Chunks far from everyone are not touched.
function M.sweep()
	local seen = 0
	for _, player in accounts.each_online() do
		local p = player:get_pos()
		shrubs:each_near(p.x, p.z, balance.shrub_sweep_radius, function(x, y, z, rec)
			seen = seen + 1
			refresh(x, y, z, rec)
		end)
	end
	return seen
end

function M.count()
	return shrubs:count()
end

return M
