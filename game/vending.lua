-- Vending machines. A machine can only stand inside land its owner controls (a lock), sells whole
-- bundles of one item for coins, and keeps the takings in a till the owner collects.
local market = require("lib.market")
local util = require("lib.util")
local L = require("lib.locks")
local store = require("game.store")
local accounts = require("game.accounts")
local locks = require("game.locks")
local notify = require("game.notify")
local ids = require("game.ids")
local ledger = require("game.ledger")
local inventory = require("game.inventory")
local balance = require("data.balance")

local M = {}

local machines = store.collection("vending", 64)

-- A machine is only valid inside a lock the player owns or administers.
function M.can_place(acc, x, z)
	for _, lock in ipairs(locks.covering(x, z)) do
		if L.is_owner_or_admin(lock, acc.subject) then
			return true
		end
	end
	return false, "vending machines can only be placed on land you have locked"
end

function M.on_placed(pos, player)
	local acc = accounts.of(player)
	machines:set(pos.x, pos.y, pos.z, {
		owner = acc.subject, owner_name = acc.name, item = 0, stock = 0, bundle = 1, price = 1, till = 0,
	})
	notify.say(player, "Vending machine placed. Use the wrench on it to stock it and set the price.")
end

function M.get(x, y, z)
	return machines:get(x, y, z)
end

-- Owner only; a machine with stock or takings hands them back when it is broken.
function M.can_remove(acc, pos)
	local m = machines:get(pos.x, pos.y, pos.z)
	if m and m.owner ~= acc.subject then
		return false, "only the owner can remove this machine"
	end
	return true
end

function M.on_broken(pos, player)
	local m = machines:get(pos.x, pos.y, pos.z)
	if not m then
		return
	end
	machines:remove(pos.x, pos.y, pos.z)
	local acc = accounts.of(player)
	if m.stock > 0 and m.item ~= 0 then
		inventory.give(player, m.item, m.stock)
	end
	if m.till > 0 and acc then
		accounts.add_coins(acc, m.till, "trade", "vending till returned")
	end
	if acc then
		inventory.give(player, ids.id("bp:vending"), 1)
		require("game.hud").push(player)
	end
end

local function item_label(item)
	if item == 0 then
		return "nothing yet"
	end
	return ids.label(item)
end

function M.open(player, pos)
	local m = machines:get(pos.x, pos.y, pos.z)
	if not m then
		return
	end
	local acc = accounts.of(player)
	local is_owner = m.owner == acc.subject
	local held = player:get_held_item()
	local ctx_store = require("game.ui_events")
	local ctx = ctx_store.get_context(player)
	local draft = (ctx and ctx.screen == "bp:vending" and ctx.pos.x == pos.x and ctx.pos.y == pos.y
		and ctx.pos.z == pos.z) and ctx or { screen = "bp:vending", pos = { x = pos.x, y = pos.y, z = pos.z }, qty = 1 }
	draft.qty = util.clamp(draft.qty or 1, 1, 200)
	ctx_store.set_context(player, draft)
	player:open_ui("bp:vending", {
		owner = m.owner_name, is_owner = is_owner, item = item_label(m.item), item_id = m.item,
		stock = m.stock, bundle = m.bundle, price = m.price, till = m.till, qty = draft.qty,
		coins = acc.coins, held = held and ids.label(held.item) or "nothing",
		held_count = held and held.count or 0,
	})
end

local function with_machine(player, ctx)
	if not ctx or ctx.screen ~= "bp:vending" then
		return nil
	end
	return machines:get(ctx.pos.x, ctx.pos.y, ctx.pos.z), ctx.pos
end

function M.on_ui_event(player, ctx, kind, value)
	local m, pos = with_machine(player, ctx)
	local acc = accounts.of(player)
	if not m or not acc then
		return
	end
	local is_owner = m.owner == acc.subject
	if kind == "vend_qty" then
		if type(value) ~= "table" or not util.is_int_in(value.delta, -200, 200) then
			return
		end
		ctx.qty = util.clamp((ctx.qty or 1) + value.delta, 1, 200)
	elseif kind == "vend_buy" then
		local bundles = ctx.qty or 1
		local items, cost = market.sell(m, bundles, acc.coins)
		if not items then
			notify.say(player, "Cannot buy: " .. cost)
		else
			accounts.spend_coins(acc, cost, "trade", "vending purchase")
			inventory.give(player, m.item, items)
			machines:touch(pos.x, pos.z)
			ledger.log("vend", { from = acc.subject, to = m.owner, coins = cost, items = { { ids.name(m.item), items } } })
			local bought = ids.meta(m.item)
			if bought and (bought.kind == "block" or bought.kind == "seed") then
				accounts.discover(acc, bought.key)
			end
			notify.say(player, string.format("Bought %d x %s for %d coins.", items, item_label(m.item), cost))
		end
	elseif is_owner and kind == "vend_stock" then
		-- deposit `qty` of the held item
		local held = player:get_held_item()
		if not held or held.item == 0 then
			notify.say(player, "Hold the item you want to stock.")
		elseif m.item ~= 0 and m.item ~= held.item and m.stock > 0 then
			notify.say(player, "This machine already sells " .. item_label(m.item) .. ". Empty it first.")
		else
			local meta = ids.meta(held.item)
			if not meta or meta.kind == "special" or meta.kind == "tool" then
				notify.say(player, "That item cannot be sold here.")
			else
				local count = math.min(ctx.qty or 1, held.count)
				if inventory.take(player, held.item, count) then
					m.item = held.item
					m.stock = m.stock + count
					machines:touch(pos.x, pos.z)
					ledger.log("vend", { from = acc.subject, note = "stocked", items = { { ids.name(m.item), count } } })
				end
			end
		end
	elseif is_owner and kind == "vend_unstock" then
		local count = math.min(ctx.qty or 1, m.stock)
		if count > 0 then
			m.stock = m.stock - count
			inventory.give(player, m.item, count)
			machines:touch(pos.x, pos.z)
		end
	elseif is_owner and kind == "vend_terms" then
		if type(value) ~= "table" then
			return
		end
		local bundle = value.bundle ~= nil and value.bundle or m.bundle
		local price = value.price ~= nil and value.price or m.price
		local ok, why = market.validate_terms(bundle, price, balance.max_vending_price)
		if not ok then
			notify.say(player, why)
		else
			m.bundle, m.price = math.floor(bundle), math.floor(price)
			machines:touch(pos.x, pos.z)
		end
	elseif is_owner and kind == "vend_collect" then
		if m.till > 0 then
			local amount = m.till
			m.till = 0
			accounts.add_coins(acc, amount, "trade", "vending takings")
			machines:touch(pos.x, pos.z)
			notify.say(player, "Collected " .. amount .. " coins.")
		end
	else
		return
	end
	require("game.hud").push(player)
	M.open(player, pos)
end

return M
