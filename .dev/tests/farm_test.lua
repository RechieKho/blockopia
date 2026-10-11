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

test("shrub timer labels: whole units left, every label is drawn", function()
	eq(farm.label(0), "Ripe!")
	eq(farm.label(-3), "Ripe!")
	eq(farm.label(0.2), "1s")
	eq(farm.label(59), "59s")
	eq(farm.label(59.5), "1m")
	eq(farm.label(119), "1m")
	eq(farm.label(120), "2m")
	eq(farm.label(3599), "59m")
	eq(farm.label(3600), "1h")
	eq(farm.label(7199), "1h")
	eq(farm.label(10 ^ 9), farm.LABEL_MAX_HOURS .. "h")
	local seen = {}
	for _, text in ipairs(farm.label_texts()) do
		seen[text] = true
	end
	for left = 0, 200000, 7 do
		truthy(seen[farm.label(left)], "label for " .. left .. "s is drawn")
	end
	local slowest = 0
	for _, e in ipairs(items) do
		if e.kind == "species" then
			slowest = math.max(slowest, farm.grow_seconds(e.rarity, b.grow_scale))
		end
	end
	truthy(slowest < farm.LABEL_MAX_HOURS * 3600, "the slowest species fits the labels")
end)
