local L = require("lib.locks")

local function lock(id, owner, x, z, size, extra)
	local l = { id = id, owner = owner, x = x, y = 64, z = z, size = size, admins = {}, builders = {} }
	for k, v in pairs(extra or {}) do
		l[k] = v
	end
	return l
end

test("boxes are centred on the lock", function()
	local b = L.box_of(100, 200, 10)
	eq(b.x2 - b.x1 + 1, 10)
	eq(b.z2 - b.z1 + 1, 10)
	truthy(L.contains(b, 100, 200))
	local g = L.box_of(0, 0, 1024)
	eq(g.x1, -512)
	eq(g.x2, 511)
	eq(g.x2 - g.x1 + 1, 1024)
end)

test("grand lock covers exactly 1024 x 1024 around the lock, not around a world centre", function()
	local idx = L.new_index()
	idx:add(lock(1, "alice", 700, 300, 1024))
	truthy(#idx:at(700, 300) == 1)
	truthy(#idx:at(700 - 512, 300 - 512) == 1)
	truthy(#idx:at(700 + 511, 300 + 511) == 1)
	truthy(#idx:at(700 + 512, 300) == 0)
	truthy(#idx:at(700 - 513, 300) == 0)
end)

test("lookup works across bucket borders and for negative coordinates", function()
	local idx = L.new_index()
	idx:add(lock(1, "alice", -3, -3, 10))
	truthy(#idx:at(-3, -3) == 1)
	truthy(#idx:at(-8, -8) == 1)
	truthy(#idx:at(1000, 1000) == 0)
	idx:add(lock(2, "bob", 1024, 1024, 48))
	truthy(#idx:at(1010, 1010) == 1)
	truthy(#idx:at(1030, 1030) == 1)
end)

test("innermost lock comes first", function()
	local idx = L.new_index()
	idx:add(lock(1, "alice", 0, 0, 1024))
	idx:add(lock(2, "alice", 5, 5, 10))
	eq(idx:at(5, 5)[1].id, 2)
	eq(idx:at(5, 5)[2].id, 1)
end)

test("access: owner, admin, builder, public, stranger", function()
	local idx = L.new_index()
	idx:add(lock(1, "alice", 0, 0, 10, { admins = { "bob" }, builders = { "carol" } }))
	truthy(idx:can_build("alice", 0, 0))
	truthy(idx:can_build("bob", 0, 0))
	truthy(idx:can_build("carol", 0, 0))
	falsy(idx:can_build("dave", 0, 0))
	truthy(idx:can_build("dave", 100, 100), "unclaimed land is free")
	idx.by_id[1].public = true
	truthy(idx:can_build("dave", 0, 0))
end)

test("a grand lock owner keeps control inside smaller locks they handed out", function()
	local idx = L.new_index()
	idx:add(lock(1, "alice", 0, 0, 1024))
	idx:add(lock(2, "bob", 5, 5, 10))
	truthy(idx:can_build("alice", 5, 5))
	truthy(idx:can_build("bob", 5, 5))
	falsy(idx:can_build("bob", 100, 100), "bob only has the small area")
	falsy(idx:can_build("carol", 5, 5))
end)

test("placement rules", function()
	local idx = L.new_index()
	idx:add(lock(1, "alice", 0, 0, 48))
	local box = L.box_of(20, 0, 10)
	local ok, why = idx:can_place("bob", 20, 0, box)
	falsy(ok)
	truthy(why)
	ok = idx:can_place("alice", 20, 0, box)
	truthy(ok, "owners may overlap their own locks")
	ok = idx:can_place("bob", 500, 500, L.box_of(500, 500, 10))
	truthy(ok, "free land")
	ok = idx:can_place("bob", 0, 0, L.box_of(0, 0, 1024))
	falsy(ok, "a grand lock cannot swallow someone else's lock")
end)

test("a foreign lock inside blocks removal of the outer lock", function()
	local idx = L.new_index()
	local grand = lock(1, "alice", 0, 0, 1024)
	idx:add(grand)
	idx:add(lock(2, "bob", 5, 5, 10))
	idx:add(lock(3, "alice", 50, 50, 10))
	local foreign = idx:foreign_inside(grand)
	eq(#foreign, 1)
	eq(foreign[1].id, 2)
end)

test("removal clears the index", function()
	local idx = L.new_index()
	idx:add(lock(1, "alice", 0, 0, 1024))
	idx:remove(1)
	eq(#idx:at(0, 0), 0)
end)

test("border posts follow a lock's outline, corners included, about 64 per lock", function()
	local borders = require("game.borders")
	for _, size in ipairs({ 1, 10, 48, 200, 256 }) do
		local box = L.box_of(0, 0, size)
		local pts = borders.outline(box, 64)
		truthy(#pts >= 4 and #pts <= 72, size .. ": " .. #pts .. " posts")
		local corners = {}
		for _, p in ipairs(pts) do
			local on_x = p.x == box.x1 or p.x == box.x2 + 1
			local on_z = p.z == box.z1 or p.z == box.z2 + 1
			truthy(on_x or on_z, "on the outline")
			if on_x and on_z then
				corners[p.x .. "," .. p.z] = true
			end
		end
		local n = 0
		for _ in pairs(corners) do
			n = n + 1
		end
		eq(n, 4, size .. ": all four corners")
	end
end)
