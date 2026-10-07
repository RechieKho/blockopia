local splice = require("lib.splice")
local recipes = require("data.splices")
local items = require("data.items")

local species = {}
for _, e in ipairs(items) do
	if e.kind == "species" then
		species[e.key] = e
	end
end

test("shipped recipes are valid", function()
	local errors = splice.validate(recipes, species)
	eq(#errors, 0, table.concat(errors, "; "))
end)

test("lookup ignores parent order", function()
	local map = splice.build(recipes)
	eq(splice.lookup(map, "dirt", "rock"), "gravel")
	eq(splice.lookup(map, "rock", "dirt"), "gravel")
	eq(splice.lookup(map, "dirt", "dirt"), nil)
end)

test("validation catches bad recipes", function()
	local sp = { a = { rarity = 2 }, b = { rarity = 3 }, c = { rarity = 4 } }
	eq(#splice.validate({ { "a", "b", "c" } }, sp), 1, "child rarer than the sum is required")
	eq(#splice.validate({ { "a", "b", "z" } }, sp), 1, "unknown species")
	sp.c.rarity = 5
	eq(#splice.validate({ { "a", "b", "c" }, { "b", "a", "c" } }, sp), 1, "duplicate pair")
	eq(#splice.validate({ { "a", "b", "c" } }, sp), 0)
end)
