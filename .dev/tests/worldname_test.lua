local wn = require("lib.worldname")
local G = 256

test("names are normalised", function()
	eq(wn.normalize("my world!", 24), "MYWORLD")
	eq(wn.normalize("abc123", 24), "ABC123")
	eq(wn.normalize("", 24), nil)
	eq(wn.normalize("!!!", 24), nil)
	eq(wn.normalize(string.rep("a", 25), 24), nil)
	eq(wn.normalize("shit", 24), nil)
end)

test("fnv1a matches the reference values", function()
	eq(wn.fnv1a(""), 2166136261)
	eq(wn.fnv1a("a"), 0xE40C292C)
	eq(wn.fnv1a("foobar"), 0xBF9CF968)
end)

test("a name always gets the same cell", function()
	local a, b = {}, {}
	local ia = wn.assign("FOO", a, {}, G, "START")
	local ib = wn.assign("FOO", b, {}, G, "START")
	eq(ia, ib)
end)

test("assigning again returns the saved cell", function()
	local by_name, by_cell = {}, {}
	local i1, new1 = wn.assign("FOO", by_name, by_cell, G, "START")
	local i2, new2 = wn.assign("FOO", by_name, by_cell, G, "START")
	eq(i1, i2)
	truthy(new1)
	falsy(new2)
end)

test("START is the hub at the origin, and nobody else gets that cell", function()
	local by_name, by_cell = {}, {}
	local hub = wn.assign("START", by_name, by_cell, G, "START")
	eq(hub, wn.hub_index(G))
	local gx, gz = wn.coords_of(hub, G)
	eq(gx, 0)
	eq(gz, 0)
	for i = 1, 3000 do
		local idx = wn.assign("W" .. i, by_name, by_cell, G, "START")
		truthy(idx ~= hub)
	end
end)

test("collisions take the next free cell deterministically", function()
	-- G = 2 has only 4 cells: the hub plus three others, so names must collide.
	local by_name, by_cell = {}, {}
	local seen = {}
	for _, n in ipairs({ "A", "B", "C" }) do
		local idx = wn.assign(n, by_name, by_cell, 2, "START")
		truthy(idx, "free cell expected")
		falsy(seen[idx], "cell reused")
		seen[idx] = true
	end
	eq(wn.assign("D", by_name, by_cell, 2, "START"), nil, "grid full")
end)

test("cell geometry", function()
	local idx = wn.index_of(0, 0, G)
	local cx, cz = wn.center_of(idx, 1024, G)
	eq(cx, 512)
	eq(cz, 512)
	eq(wn.cell_at(512, 512, 1024, G), idx)
	eq(wn.cell_at(-1, -1, 1024, G), wn.index_of(-1, -1, G))
	eq(wn.cell_at(1024 * 200, 0, 1024, G), nil, "outside the grid")
	local gx, gz = wn.coords_of(wn.index_of(-128, 127, G), G)
	eq(gx, -128)
	eq(gz, 127)
end)

test("the map stays small enough for steady float rendering", function()
	local balance = require("data.balance")
	-- float32 still resolves ~1/1000 of a block at 8192; jitter was visible near 131072
	truthy(balance.world_grid * balance.world_cell_size // 2 <= 8192)
	eq(require("data.locks").grand.size, balance.world_cell_size, "a grand lock claims one world")
end)
