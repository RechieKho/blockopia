local farm = require("lib.farm")
local items = require("data.items")
local b = require("data.balance")

test("growth time strictly increases with rarity", function()
	local last = -1
	for r = 1, 200 do
		local t = farm.grow_seconds(r, b.grow_scale)
		truthy(t > last, "rarity " .. r)
		last = t
	end
end)

test("every shipped species: rarer grows longer", function()
	local list = {}
	for _, e in ipairs(items) do
		if e.kind == "species" then
			list[#list + 1] = e
		end
	end
	table.sort(list, function(x, y)
		return x.rarity < y.rarity
	end)
	for i = 2, #list do
		if list[i].rarity > list[i - 1].rarity then
			truthy(farm.grow_seconds(list[i].rarity, 1) > farm.grow_seconds(list[i - 1].rarity, 1))
		end
	end
end)

test("grow_scale stretches every time by the same factor", function()
	eq(farm.grow_seconds(7, 2), 2 * farm.grow_seconds(7, 1))
end)

test("stages", function()
	eq(farm.stage(0, 90, 1 / 3), 0)
	eq(farm.stage(29, 90, 1 / 3), 0)
	eq(farm.stage(31, 90, 1 / 3), 1)
	eq(farm.stage(90, 90, 1 / 3), 2)
	eq(farm.stage(1e9, 90, 1 / 3), 2)
end)

test("yield stays in range and shrinks for rare species", function()
	for _ = 1, 500 do
		local y = farm.yield(1, b, math.random)
		truthy(y >= 1 and y <= 5)
		local z = farm.yield(200, b, math.random)
		eq(z, 1, "rarity 200: top = max(1, 5 - 5) = 1")
	end
end)

test("duration text", function()
	eq(farm.format_duration(30), "30s")
	eq(farm.format_duration(125), "2m 5s")
	eq(farm.format_duration(7300), "2h 1m")
end)
