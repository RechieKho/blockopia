-- Block placement: protection checks (veto) and what happens after a special block is placed.
local accounts = require("game.accounts")
local locks = require("game.locks")
local notify = require("game.notify")
local ids = require("game.ids")
local balance = require("data.balance")

local M = {}

-- block_place event (vetoable). The engine does not say which block, only where.
function M.on_place_event(player, pos)
	local acc = accounts.of(player)
	if not acc or not acc.ready then
		return false
	end
	if pos.y <= balance.floor_y then
		notify.throttled(player, "You cannot build this low.")
		return false
	end
	if not locks.can_build(acc, pos.x, pos.z) then
		notify.throttled(player, "This land is locked.")
		return false
	end
end

-- Per-block on_place callback (after the block is in the world).
function M.on_place(meta, ctx)
	if meta.kind == "lock" then
		locks.create(meta.tier, ctx.player, ctx.pos)
	elseif meta.kind == "vending" then
		require("game.vending").on_placed(ctx.pos, ctx.player)
	end
end

-- Checks that must pass BEFORE placing `meta` at (x, y, z). Returns true, or false and a reason.
function M.can_place(acc, meta, x, y, z)
	if meta.kind == "lock" then
		return locks.can_place(acc, meta.tier, x, y, z)
	elseif meta.kind == "vending" then
		return require("game.vending").can_place(acc, x, z)
	end
	return true
end

function M.placeable(meta)
	return meta and (meta.kind == "block" or meta.kind == "lock" or meta.kind == "vending")
end

return M
