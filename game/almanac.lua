-- The almanac: species the player has found, and the splice recipes they have discovered.
local accounts = require("game.accounts")
local farm = require("lib.farm")
local ids = require("game.ids")
local ui_events = require("game.ui_events")
local balance = require("data.balance")

local M = {}

function M.open(player)
	local acc = accounts.of(player)
	local species = {}
	for _, key in ipairs(ids.species_order) do
		local sp = ids.species[key]
		if acc.found[key] then
			species[#species + 1] = {
				name = sp.label, rarity = sp.rarity, grow = farm.format_duration(farm.grow_seconds(sp.rarity, balance.grow_scale)),
				seed_chance = math.floor(sp.seed_chance * 100 + 0.5), found = true,
			}
		else
			species[#species + 1] = { name = "???", rarity = sp.rarity, found = false }
		end
	end
	local recipes = {}
	for pair, child in pairs(acc.recipes) do
		local a, b = pair:match("^(.-)%+(.+)$")
		if a and ids.species[a] and ids.species[b] and ids.species[child] then
			recipes[#recipes + 1] = string.format("%s + %s = %s", ids.species[a].label, ids.species[b].label, ids.species[child].label)
		end
	end
	table.sort(recipes)
	ui_events.set_context(player, { screen = "bp:almanac" })
	require("game.ui_events").open(player, "bp:almanac", { species = species, recipes = recipes })
end

return M
