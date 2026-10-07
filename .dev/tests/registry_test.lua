local registry = require("lib.registry")
local items = require("data.items")
local locks = require("data.locks")

local function exists(path)
	local f = io.open(path, "rb")
	if f then
		f:close()
		return true
	end
	return false
end

test("shipped item data is valid and every texture exists", function()
	local errors = registry.validate(items, locks, exists)
	eq(#errors, 0, table.concat(errors, "; "))
end)

test("each species expands to block, seed and three shrub stages in order", function()
	local list = registry.expand(items, locks)
	local names = {}
	for i, b in ipairs(list) do
		names[b.name] = i
	end
	local d = names["bp:dirt"]
	eq(list[d + 1].name, "bp:dirt_seed")
	eq(list[d + 2].name, "bp:dirt_s0")
	eq(list[d + 4].name, "bp:dirt_s2")
	eq(list[d].meta.kind, "block")
	eq(list[d + 1].meta.kind, "seed")
	eq(list[d + 3].meta.stage, 1)
end)

test("names are unique", function()
	local seen = {}
	for _, b in ipairs(registry.expand(items, locks)) do
		falsy(seen[b.name], "duplicate " .. b.name)
		seen[b.name] = true
	end
end)

test("validation catches bad data", function()
	local bad = { { kind = "species", key = "x", name = "X", rarity = 0, punches = 1, seed_chance = 2 } }
	eq(#registry.validate(bad, locks), 2)
	local dup = { { kind = "special", key = "a", name = "A" }, { kind = "special", key = "a", name = "A" } }
	eq(#registry.validate(dup, locks), 1)
end)

test("order check allows appending and refuses reordering", function()
	local current = { "a", "b", "c", "d" }
	eq(registry.check_order({ "a", "b" }, current), nil)
	eq(registry.check_order(nil, current), nil)
	truthy(registry.check_order({ "b", "a" }, current))
	truthy(registry.check_order({ "a", "b", "c", "d", "e" }, current))
end)
