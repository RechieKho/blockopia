-- Block breaking: protection checks (vetoes), block healing, and rewards.
local drops = require("lib.drops")
local store = require("game.store")
local accounts = require("game.accounts")
local locks = require("game.locks")
local notify = require("game.notify")
local ids = require("game.ids")
local farm = require("game.farm")
local balance = require("data.balance")

local M = {}

-- Why this player may not break the block at pos, or nil when they may.
local function refusal(player, pos)
	local acc = accounts.of(player)
	if not acc or not acc.ready then
		return "Sign-in is not finished yet."
	end
	if pos.y <= balance.floor_y then
		return "The ground cannot be broken here."
	end
	local id = vb.world.get_block(pos.x, pos.y, pos.z)
	local meta = ids.meta(id)
	if meta and meta.unbreakable then
		return "That block cannot be broken."
	end
	if not locks.can_build(acc, pos.x, pos.z) then
		return "This land is locked."
	end
	if meta and meta.kind == "lock" then
		local lock = locks.at_block(pos.x, pos.y, pos.z)
		if lock then
			local ok, why = locks.can_remove(acc, lock)
			if not ok then
				return why
			end
		end
	elseif meta and meta.kind == "vending" then
		local ok, why = require("game.vending").can_remove(acc, pos)
		if not ok then
			return why
		end
	end
	return nil
end

-- block_break event (vetoable).
function M.on_break_event(player, pos)
	local why = refusal(player, pos)
	if why then
		notify.throttled(player, why)
		return false
	end
end

-- Punch damage healing is the engine's own (vb.combat.set_params in init.lua). The engine checks
-- this veto when the last punch lands, so a protected block shows cracks but never breaks.

local function drop_at(pos, item, count)
	vb.world.spawn_item_drop({ x = pos.x + 0.5, y = pos.y + 0.5, z = pos.z + 0.5 }, item, count)
end

-- Per-block on_break callback. `meta` is what the pack knows about the broken block.
function M.on_break(meta, ctx)
	local pos, player = ctx.pos, ctx.player
	local acc = accounts.of(player)
	farm.on_support_broken(pos.x, pos.y, pos.z)

	if meta.kind == "block" then
		local sp = ids.species[meta.key]
		local roll = drops.roll({ rarity = meta.rarity, seed_chance = meta.seed_chance }, balance, math.random)
		if roll.block then
			drop_at(pos, sp.block, 1)
		end
		if roll.seed then
			drop_at(pos, sp.seed, 1)
		end
		if acc then
			if roll.coins > 0 then
				accounts.add_coins(acc, roll.coins, "break")
			end
			if roll.block or roll.seed then
				accounts.discover(acc, meta.key)
			end
			acc.stats.broken = (acc.stats.broken or 0) + 1
			require("game.hud").push(player)
		end
	elseif meta.kind == "shrub" then
		farm.on_broken(meta, ctx)
	elseif meta.kind == "lock" then
		local lock = locks.at_block(pos.x, pos.y, pos.z)
		if lock then
			locks.remove(lock, player)
		end
	elseif meta.kind == "vending" then
		require("game.vending").on_broken(pos, player)
	end
end

return M
