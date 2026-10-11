-- The coin store: the main place coins leave the economy.
local accounts = require("game.accounts")
local notify = require("game.notify")
local ids = require("game.ids")
local inventory = require("game.inventory")
local ledger = require("game.ledger")
local ui_events = require("game.ui_events")
local tiers = require("data.locks")
local catalog = require("data.store")

local M = {}

local by_id = {}
for _, e in ipairs(catalog) do
	by_id[e.id] = e
end

local function price_of(e)
	if e.kind == "lock" then
		return tiers[e.tier].price
	end
	return e.price
end

local function name_of(e)
	if e.kind == "lock" then
		return tiers[e.tier].name .. string.format(" (%dx%d area)", tiers[e.tier].size, tiers[e.tier].size)
	end
	return e.name
end

function M.open(player)
	local acc = accounts.of(player)
	local list = {}
	for _, e in ipairs(catalog) do
		list[#list + 1] = { id = e.id, name = name_of(e), price = price_of(e) }
	end
	ui_events.set_context(player, { screen = "bp:store" })
	require("game.ui_events").open(player, "bp:store", { coins = acc.coins, items = list })
end

-- A random seed of a species with rarity <= max_rarity.
local function random_seed(max_rarity)
	local pool = {}
	for _, key in ipairs(ids.species_order) do
		local sp = ids.species[key]
		if sp.rarity <= max_rarity then
			pool[#pool + 1] = sp
		end
	end
	return pool[math.random(1, #pool)]
end

function M.on_ui_event(player, ctx, kind, value)
	if kind ~= "shop_buy" or type(value) ~= "table" or type(value.id) ~= "string" then
		return
	end
	local acc = accounts.of(player)
	local e = by_id[value.id]
	if not e or not acc then
		return
	end
	local price = price_of(e)
	if not accounts.spend_coins(acc, price, "burn", "store: " .. e.id) then
		notify.say(player, string.format("You need %d coins for that.", price))
		return
	end
	if e.kind == "lock" then
		inventory.give(player, ids.id("bp:lock_" .. e.tier), 1)
	elseif e.kind == "item" then
		inventory.give(player, ids.id(e.item), e.count)
	elseif e.kind == "seedpack" then
		local got = {}
		for _ = 1, e.count do
			local sp = random_seed(e.max_rarity)
			inventory.give(player, sp.seed, 1)
			accounts.discover(acc, sp.key)
			got[sp.label] = (got[sp.label] or 0) + 1
		end
		local parts = {}
		for label, n in pairs(got) do
			parts[#parts + 1] = n .. " " .. label
		end
		table.sort(parts)
		notify.say(player, "Your seed pack had: " .. table.concat(parts, ", "))
	end
	ledger.log("store", { from = acc.subject, coins = price, note = e.id })
	notify.say(player, "Bought " .. name_of(e) .. " for " .. price .. " coins.")
	require("game.hud").push(player)
	M.open(player)
end

return M
