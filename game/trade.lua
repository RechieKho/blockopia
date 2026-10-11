-- Player-to-player trades. Both sides add items and coins, both accept, then both confirm; any
-- change resets the accepts. The swap itself happens in one server callback.
local T = require("lib.trade")
local util = require("lib.util")
local accounts = require("game.accounts")
local notify = require("game.notify")
local ids = require("game.ids")
local ledger = require("game.ledger")
local inventory = require("game.inventory")
local ui_events = require("game.ui_events")
local store = require("game.store")
local balance = require("data.balance")

local M = {}

local trades = {} -- player name -> trade (both parties point to the same table)
local requests = {} -- target name -> { from = name, time = t }

local function other_player(t, name)
	return accounts.online(T.other(t, name))
end

local function entries(player, t, name)
	-- everything this player carries, with how much of it they have offered
	local list = {}
	local totals = inventory.totals(player)
	local offered = t.offers[name].items
	local keys = {}
	for item in pairs(totals) do
		keys[#keys + 1] = item
	end
	table.sort(keys)
	for _, item in ipairs(keys) do
		list[#list + 1] = { item = item, name = ids.label(item), have = totals[item], offered = offered[item] or 0 }
	end
	return list
end

local function describe(t, who)
	local out = {}
	for _, e in ipairs(T.item_list(t, who)) do
		out[#out + 1] = { name = ids.label(e.item), count = e.count }
	end
	return out
end

function M.refresh(t)
	for _, name in ipairs(t.parties) do
		local player = accounts.online(name)
		local acc = accounts.of_name(name)
		if player and acc then
			local other = T.other(t, name)
			ui_events.set_context(player, { screen = "bp:trade" })
			require("game.ui_events").open(player, "bp:trade", {
				partner = other, coins = acc.coins,
				mine = describe(t, name), theirs = describe(t, other),
				my_coins = t.offers[name].coins, their_coins = t.offers[other].coins,
				my_accepted = t.accepted[name], their_accepted = t.accepted[other],
				my_confirmed = t.confirmed[name], their_confirmed = t.confirmed[other],
				inventory = entries(player, t, name),
			})
		end
	end
end

function M.request(player, target_name)
	local name = player:get_name()
	local target = accounts.online(target_name)
	if not target or target_name == name then
		notify.say(player, "There is nobody called '" .. tostring(target_name) .. "' here to trade with.")
		return
	end
	if trades[name] or trades[target_name] then
		notify.say(player, "One of you is already trading.")
		return
	end
	requests[target_name] = { from = name, time = store.now() }
	notify.say(player, "Trade request sent to " .. target_name .. ".")
	notify.say(target, name .. " wants to trade. Type !trade accept to start.")
end

function M.accept_request(player)
	local name = player:get_name()
	local req = requests[name]
	requests[name] = nil
	if not req or store.now() - req.time > 60 then
		notify.say(player, "You have no pending trade request.")
		return
	end
	local from = accounts.online(req.from)
	if not from or trades[name] or trades[req.from] then
		notify.say(player, "That trade is no longer possible.")
		return
	end
	local t = T.new(req.from, name)
	t.started = store.now()
	trades[req.from], trades[name] = t, t
	M.refresh(t)
end

function M.cancel(player, why)
	local name = player:get_name()
	local t = trades[name]
	requests[name] = nil
	if not t then
		return
	end
	for _, n in ipairs(t.parties) do
		trades[n] = nil
		local p = accounts.online(n)
		if p then
			ui_events.clear(p)
			if n ~= name then
				notify.notice(p, "Trade cancelled", name .. " " .. (why or "cancelled the trade") .. ".")
			else
				notify.say(p, "Trade cancelled.")
			end
		end
	end
end

-- The swap. Verifies everything first, moves everything, and undoes the first half if the second fails.
local function execute(t)
	local a_name, b_name = t.parties[1], t.parties[2]
	local pa, pb = accounts.online(a_name), accounts.online(b_name)
	local aa, ab = accounts.of_name(a_name), accounts.of_name(b_name)
	if not (pa and pb and aa and ab) then
		return false, "a player left"
	end
	local oa, ob = t.offers[a_name], t.offers[b_name]
	if oa.coins > aa.coins or ob.coins > ab.coins then
		return false, "someone does not have the coins they offered"
	end
	local ta, tb = inventory.totals(pa), inventory.totals(pb)
	for item, n in pairs(oa.items) do
		if (ta[item] or 0) < n then
			return false, "someone no longer has the items they offered"
		end
	end
	for item, n in pairs(ob.items) do
		if (tb[item] or 0) < n then
			return false, "someone no longer has the items they offered"
		end
	end
	-- take from both
	local taken_a, taken_b = {}, {}
	local function rollback()
		for _, e in ipairs(taken_a) do
			inventory.give(pa, e[1], e[2])
		end
		for _, e in ipairs(taken_b) do
			inventory.give(pb, e[1], e[2])
		end
	end
	for item, n in pairs(oa.items) do
		if not inventory.take(pa, item, n) then
			rollback()
			return false, "could not take the offered items"
		end
		taken_a[#taken_a + 1] = { item, n }
	end
	for item, n in pairs(ob.items) do
		if not inventory.take(pb, item, n) then
			rollback()
			return false, "could not take the offered items"
		end
		taken_b[#taken_b + 1] = { item, n }
	end
	for _, e in ipairs(taken_a) do
		inventory.give(pb, e[1], e[2])
	end
	for _, e in ipairs(taken_b) do
		inventory.give(pa, e[1], e[2])
	end
	aa.coins, ab.coins = aa.coins - oa.coins + ob.coins, ab.coins - ob.coins + oa.coins
	local function named(list)
		local out = {}
		for _, e in ipairs(list) do
			out[#out + 1] = { ids.name(e[1]), e[2] }
		end
		return out
	end
	ledger.log("trade", { from = aa.subject, to = ab.subject, coins = oa.coins, items = named(taken_a) })
	ledger.log("trade", { from = ab.subject, to = aa.subject, coins = ob.coins, items = named(taken_b) })
	accounts.save(aa)
	accounts.save(ab)
	return true
end

function M.on_ui_event(player, ctx, kind, value)
	local name = player:get_name()
	local t = trades[name]
	if not t then
		return
	end
	if kind == "trade_item" then
		if type(value) ~= "table" or not util.is_int_in(value.item, 1, 65535) or not util.is_int_in(value.delta, -200, 200) then
			return
		end
		local have = inventory.count(player, value.item)
		local current = t.offers[name].items[value.item] or 0
		local count = util.clamp(current + value.delta, 0, have)
		T.set_item(t, name, value.item, count)
	elseif kind == "trade_coins" then
		if type(value) ~= "table" or not util.is_int_in(value.delta, -100000, 100000) then
			return
		end
		local acc = accounts.of_name(name)
		T.set_coins(t, name, util.clamp(t.offers[name].coins + value.delta, 0, acc.coins))
	elseif kind == "trade_accept" then
		T.accept(t, name)
	elseif kind == "trade_confirm" then
		T.confirm(t, name)
		if T.ready(t) then
			local ok, why = execute(t)
			local partner = T.other(t, name)
			for _, n in ipairs({ name, partner }) do
				local p = accounts.online(n)
				if p then
					notify.notice(p, ok and "Trade complete" or "Trade failed", ok and "Everything was exchanged." or why)
					require("game.hud").push(p)
				end
				trades[n] = nil
			end
			return
		end
	elseif kind == "trade_cancel" then
		M.cancel(player)
		return
	else
		return
	end
	M.refresh(t)
end

function M.on_leave(player)
	M.cancel(player, "left the game")
	requests[player:get_name()] = nil
end

return M
