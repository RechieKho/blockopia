-- Routes ui_event messages from the client UI VM to the right module.
--
-- Nothing the client sends is trusted: each screen has a server-side context (what it was opened
-- for), handlers re-check ownership and balances, and events are rate limited per player.
local accounts = require("game.accounts")
local store = require("game.store")
local balance = require("data.balance")

local M = {}

local contexts = {} -- player name -> table describing the open screen
local buckets = {} -- player name -> { tokens, time }

function M.set_context(player, ctx)
	contexts[player:get_name()] = ctx
end

function M.get_context(player)
	return contexts[player:get_name()]
end

function M.clear(player)
	contexts[player:get_name()] = nil
	buckets[player:get_name()] = nil
end

local function allow(name)
	local now = store.now()
	local b = buckets[name]
	if not b then
		b = { tokens = balance.ui_burst, time = now }
		buckets[name] = b
	end
	b.tokens = math.min(balance.ui_burst, b.tokens + (now - b.time) * balance.ui_rate)
	b.time = now
	if b.tokens < 1 then
		return false
	end
	b.tokens = b.tokens - 1
	return true
end

local routes = {} -- event kind -> function(player, ctx, kind, value)

function M.route(prefix, fn)
	routes[prefix] = fn
end

function M.on_ui_event(player, ui_name, widget_id, event_kind, value)
	local name = player:get_name()
	if not accounts.of_name(name) then
		return
	end
	if event_kind == "close" then
		local ctx = contexts[name]
		contexts[name] = nil
		if ctx and ctx.screen == "bp:trade" then
			require("game.trade").cancel(player, "closed the trade window")
		end
		return
	end
	if type(event_kind) ~= "string" or not allow(name) then
		return
	end
	local prefix = event_kind:match("^(%a+)_")
	local fn = prefix and routes[prefix]
	if not fn then
		return
	end
	-- Events without a context (the shop, the warp screen) pass an empty one.
	fn(player, contexts[name] or {}, event_kind, value)
end

return M
