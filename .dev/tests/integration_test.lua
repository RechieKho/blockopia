-- Loads the whole pack into the mock engine (tests/mock_engine.lua) and plays it.
local M = require("tests.mock_engine")
local wn = require("lib.worldname")
local balance = require("data.balance")

local function fresh(opts)
	M.load(opts)
	M.flat_ground(63, 40)
end

local function dev(name)
	return M.join(name, nil)
end

local function aim(x, y, z, nx, ny, nz)
	M.aim = { x = x, y = y, z = z, nx = nx or 0, ny = ny or 0, nz = nz or 0 }
end

-- Makes every random roll succeed with the smallest amounts.
local real_random = math.random
local function lucky()
	math.random = function(a)
		if a then
			return a
		end
		return 0
	end
end
local function unlucky()
	math.random = function(a, b)
		if a then
			return b
		end
		return 0.999
	end
end
local function normal()
	math.random = real_random
end

local function account(p)
	return require("game.accounts").of(p)
end

local function has_message(p, needle)
	for _, m in ipairs(p.messages) do
		if m:find(needle, 1, true) then
			return true
		end
	end
	return false
end

test("the pack loads: blocks, worldgen, keybind, id order saved", function()
	fresh()
	eq(M.storage.block_order[1], "bp:bedrock")
	truthy(M.blocks["bp:dirt"] and M.blocks["bp:dirt_seed"] and M.blocks["bp:crystal_s2"] and M.blocks["bp:lock_grand"])
	eq(M.blocks["bp:dirt"].max_damage, 2)
	truthy(M.pipeline and M.pipeline.veins[1].block == "bp:lava")
	for _, vein in ipairs(M.pipeline.veins) do
		truthy(M.blocks[vein.block] and M.blocks[vein.target_rock], "vein blocks exist: " .. vein.block)
	end
	-- warps drop players from above the highest hill
	truthy(M.pipeline.base_height + M.pipeline.amplitude < balance.world_spawn_y)
	truthy(#M.biomes >= 2)
	for _, biome in ipairs(M.biomes) do
		truthy(M.blocks[biome.surface] and M.blocks[biome.filler] and M.blocks[biome.stone], biome.name)
	end
	truthy(M.keybinds["base:inventory"])
	truthy(M.blocks["bp:lava"].region)
end)

test("reordering saved block ids is refused, appending is fine", function()
	fresh()
	local storage = M.storage
	local ok = pcall(M.load, { storage = storage })
	truthy(ok, "same order must load")
	local order = storage.block_order
	order[2], order[3] = order[3], order[2]
	local ok2, err = pcall(M.load, { storage = storage })
	falsy(ok2)
	truthy(tostring(err):find("append", 1, true), tostring(err))
	storage.block_order = { "bp:bedrock", "bp:lava" }
	truthy(pcall(M.load, { storage = storage }), "a shorter saved list is a prefix")
end)

test("a new player gets coins, a wrench, dirt and seeds, and a hud line", function()
	fresh()
	local a = dev("alice")
	eq(account(a).coins, 100)
	eq(M.count(a, "bp:wrench"), 1)
	eq(M.count(a, "bp:dirt"), 8)
	eq(M.count(a, "bp:dirt_seed"), 3)
	truthy(has_message(a, "Welcome"))
	truthy(has_message(a, "@@bp|coins=100"))
	M.advance(4)
	truthy(has_message(a, "@@bp|coins=100|world=START"))
end)

test("players cannot forge hud lines", function()
	fresh()
	local a = dev("alice")
	eq(M.chat(a, "@@bp|coins=999999"), false)
	eq(M.chat(a, "hello"), true)
end)

test("breaking a block pays out: block, seed and coins", function()
	fresh()
	local a = dev("alice")
	M.world["5,64,5"] = M.id("bp:dirt")
	aim(5, 64, 5, 0, 1, 0)
	lucky()
	M.click(a, "primary")
	eq(M.world["5,64,5"], M.id("bp:dirt"), "dirt needs two punches")
	M.click(a, "primary")
	normal()
	eq(M.world["5,64,5"], nil)
	local got = {}
	for _, d in ipairs(M.drops) do
		got[d.item] = (got[d.item] or 0) + d.count
	end
	eq(got[M.id("bp:dirt")], 1)
	eq(got[M.id("bp:dirt_seed")], 1)
	eq(account(a).coins, 101)
	truthy(account(a).found.dirt)
end)

test("an unlucky break pays nothing", function()
	fresh()
	local a = dev("alice")
	M.world["5,64,5"] = M.id("bp:rock")
	aim(5, 64, 5)
	unlucky()
	for _ = 1, 3 do
		M.click(a, "primary")
	end
	normal()
	eq(#M.drops, 0)
	eq(account(a).coins, 100)
end)

test("the floor cannot be broken", function()
	fresh()
	local a = dev("alice")
	M.world["5,1,5"] = M.id("bp:dirt")
	aim(5, 1, 5)
	M.click(a, "primary")
	M.click(a, "primary")
	eq(M.world["5,1,5"], M.id("bp:dirt"))
	M.world["6,64,6"] = M.id("bp:bedrock")
	aim(6, 64, 6)
	for _ = 1, 5 do
		M.click(a, "primary")
	end
	eq(M.world["6,64,6"], M.id("bp:bedrock"))
end)

test("placing a block spends one", function()
	fresh()
	local a = dev("alice")
	M.select(a, "bp:dirt")
	aim(3, 63, 3, 0, 1, 0)
	M.click(a, "secondary")
	eq(M.world["3,64,3"], M.id("bp:dirt"))
	eq(M.count(a, "bp:dirt"), 7)
end)

test("plant, wait, harvest: the whole farming loop", function()
	fresh()
	local a = dev("alice")
	local farm = require("game.farm")
	M.select(a, "bp:dirt_seed")
	aim(5, 63, 5, 0, 1, 0)
	M.click(a, "secondary")
	eq(M.world["5,64,5"], M.id("bp:dirt_s0"))
	eq(M.count(a, "bp:dirt_seed"), 2)
	local rec = farm.get(5, 64, 5)
	truthy(rec and rec.species == "dirt")
	M.advance(6)
	eq(M.world["5,64,5"], M.id("bp:dirt_s0"), "still a sprout after 6s")
	M.advance(10)
	eq(M.world["5,64,5"], M.id("bp:dirt_s1"), "growing after a third of 31s")
	M.advance(40)
	eq(M.world["5,64,5"], M.id("bp:dirt_s2"), "ripe")
	aim(5, 64, 5)
	lucky()
	M.click(a, "primary")
	normal()
	eq(M.world["5,64,5"], nil)
	local dirt = 0
	for _, d in ipairs(M.drops) do
		if d.item == M.id("bp:dirt") then
			dirt = dirt + d.count
		end
	end
	truthy(dirt >= 1)
	eq(farm.get(5, 64, 5), nil, "the record is gone")
end)

test("growth time depends on rarity: rarer is slower", function()
	fresh()
	local a = dev("alice")
	local farm = require("game.farm")
	local ids = require("game.ids")
	a:give({ item = ids.species.crystal.seed, count = 1 })
	M.select(a, "bp:dirt_seed")
	aim(5, 63, 5, 0, 1, 0)
	M.click(a, "secondary")
	M.select(a, "bp:crystal_seed")
	aim(7, 63, 7, 0, 1, 0)
	M.click(a, "secondary")
	local dirt, crystal = farm.get(5, 64, 5), farm.get(7, 64, 7)
	truthy(crystal.total > dirt.total * 1000, "crystal " .. crystal.total .. " vs dirt " .. dirt.total)
end)

test("punching an unripe shrub destroys it for nothing", function()
	fresh()
	local a = dev("alice")
	M.select(a, "bp:dirt_seed")
	aim(5, 63, 5, 0, 1, 0)
	M.click(a, "secondary")
	aim(5, 64, 5)
	lucky()
	M.click(a, "primary")
	normal()
	eq(M.world["5,64,5"], nil)
	eq(#M.drops, 0)
end)

test("splicing makes a rarer species and starts the timer again", function()
	fresh()
	local a = dev("alice")
	local farm = require("game.farm")
	local ids = require("game.ids")
	M.select(a, "bp:dirt_seed")
	aim(5, 63, 5, 0, 1, 0)
	M.click(a, "secondary")
	local before = farm.get(5, 64, 5).total
	-- a seed that does not combine with dirt leaves everything alone
	M.select(a, "bp:dirt_seed")
	aim(5, 64, 5)
	M.click(a, "secondary")
	truthy(has_message(a, "can't be spliced"))
	eq(M.count(a, "bp:dirt_seed"), 2)
	-- rock + dirt = gravel
	a:give({ item = ids.species.rock.seed, count = 1 })
	M.select(a, "bp:rock_seed")
	M.click(a, "secondary")
	eq(M.world["5,64,5"], M.id("bp:gravel_s0"))
	eq(M.count(a, "bp:rock_seed"), 0)
	local rec = farm.get(5, 64, 5)
	eq(rec.species, "gravel")
	truthy(rec.spliced)
	truthy(rec.total > before)
	truthy(account(a).recipes["dirt+rock"] == "gravel")
	truthy(account(a).found.gravel)
	-- a spliced shrub cannot be spliced again
	a:give({ item = ids.species.dirt.seed, count = 1 })
	M.select(a, "bp:dirt_seed")
	M.click(a, "secondary")
	truthy(has_message(a, "already spliced"))
end)

test("seeds cannot be spliced into a ripe shrub", function()
	fresh()
	local a = dev("alice")
	local ids = require("game.ids")
	M.select(a, "bp:dirt_seed")
	aim(5, 63, 5, 0, 1, 0)
	M.click(a, "secondary")
	M.advance(60)
	a:give({ item = ids.species.rock.seed, count = 1 })
	M.select(a, "bp:rock_seed")
	aim(5, 64, 5)
	M.click(a, "secondary")
	truthy(has_message(a, "already ripe"))
	eq(M.count(a, "bp:rock_seed"), 1)
end)

test("breaking the soil destroys the shrub on it", function()
	fresh()
	local a = dev("alice")
	M.world["8,63,8"] = M.id("bp:dirt")
	M.select(a, "bp:dirt_seed")
	aim(8, 63, 8, 0, 1, 0)
	M.click(a, "secondary")
	truthy(M.world["8,64,8"])
	aim(8, 63, 8)
	M.click(a, "primary")
	M.click(a, "primary")
	eq(M.world["8,64,8"], nil)
	eq(require("game.farm").get(8, 64, 8), nil)
end)

test("a small lock protects its square and nothing else", function()
	fresh()
	local a, b = dev("alice"), dev("bob")
	local locks = require("game.locks")
	a:give({ item = M.id("bp:lock_small"), count = 1 })
	M.select(a, "bp:lock_small")
	aim(20, 63, 20, 0, 1, 0)
	M.click(a, "secondary")
	local lock = locks.at_block(20, 64, 20)
	truthy(lock, "lock registered")
	eq(lock.size, 10)
	eq(lock.owner, "dev:alice")
	-- protected block
	M.world["22,64,20"] = M.id("bp:dirt")
	aim(22, 64, 20)
	M.click(b, "primary")
	M.click(b, "primary")
	eq(M.world["22,64,20"], M.id("bp:dirt"), "bob cannot break inside alice's lock")
	M.click(a, "primary")
	M.click(a, "primary")
	eq(M.world["22,64,20"], nil, "alice can")
	-- bob cannot place inside, can outside
	M.select(b, "bp:dirt")
	aim(21, 63, 21, 0, 1, 0)
	M.click(b, "secondary")
	eq(M.world["21,64,21"], nil)
	aim(35, 63, 35, 0, 1, 0)
	M.click(b, "secondary")
	eq(M.world["35,64,35"], M.id("bp:dirt"))
	-- bob cannot break alice's lock
	aim(20, 64, 20)
	for _ = 1, 6 do
		M.click(b, "primary")
	end
	truthy(M.world["20,64,20"])
	truthy(locks.at_block(20, 64, 20))
end)

test("locks cannot overlap other people's locks", function()
	fresh()
	local a, b = dev("alice"), dev("bob")
	a:give({ item = M.id("bp:lock_small"), count = 1 })
	b:give({ item = M.id("bp:lock_small"), count = 1 })
	M.select(a, "bp:lock_small")
	aim(20, 63, 20, 0, 1, 0)
	M.click(a, "secondary")
	M.select(b, "bp:lock_small")
	aim(26, 63, 20, 0, 1, 0)
	M.click(b, "secondary")
	eq(M.world["26,64,20"], nil)
	eq(M.count(b, "bp:lock_small"), 1, "the lock item is kept")
end)

test("a grand lock covers exactly one world's size around the lock", function()
	fresh()
	local a, b = dev("alice"), dev("bob")
	local locks = require("game.locks")
	a:give({ item = M.id("bp:lock_grand"), count = 1 })
	M.select(a, "bp:lock_grand")
	aim(3000, 63, -700, 0, 1, 0)
	M.click(a, "secondary")
	local lock = locks.at_block(3000, 64, -700)
	truthy(lock)
	local size = balance.world_cell_size
	eq(lock.size, size)
	eq(lock.box.x2 - lock.box.x1 + 1, size)
	truthy(not locks.can_build(account(b), 3000 + size // 2 - 1, -700 + size // 2 - 1))
	truthy(locks.can_build(account(b), 3000 + size // 2, -700))
	truthy(locks.can_build(account(b), 3000 - size // 2 - 1, -700))
	truthy(locks.can_build(account(a), 3000 + size // 4, -700))
	-- the grand lock cannot be resized from its screen
	M.select(a, "bp:wrench")
	aim(3000, 64, -700)
	M.click(a, "secondary")
	eq(a.ui.name, "bp:lock")
	eq(a.ui.ctx.adjustable, false)
	M.ui_event(a, "lock_size", { delta = -10 })
	eq(locks.at_block(3000, 64, -700).size, size)
end)

test("the lock screen: resize, admins, public building, and who may edit", function()
	fresh()
	local a, b = dev("alice"), dev("bob")
	local locks = require("game.locks")
	a:give({ item = M.id("bp:lock_big"), count = 1 })
	M.select(a, "bp:lock_big")
	aim(20, 63, 20, 0, 1, 0)
	M.click(a, "secondary")
	M.select(a, "bp:wrench")
	aim(20, 64, 20)
	M.click(a, "secondary")
	eq(a.ui.name, "bp:lock")
	eq(a.ui.ctx.size, 48)
	M.ui_event(a, "lock_size", { delta = -40 })
	eq(locks.at_block(20, 64, 20).size, 8)
	M.ui_event(a, "lock_size", { delta = 100 })
	eq(locks.at_block(20, 64, 20).size, 48, "capped at the tier maximum")
	M.ui_event(a, "lock_add", { role = "admin", name = "bob" })
	eq(#locks.at_block(20, 64, 20).admins, 1)
	truthy(locks.can_build(account(b), 20, 20))
	M.ui_event(a, "lock_remove", { role = "admin", index = 1 })
	truthy(not locks.can_build(account(b), 20, 20))
	M.ui_event(a, "lock_public", { value = true })
	truthy(locks.can_build(account(b), 20, 20))
	-- bob opens the screen but cannot edit
	M.select(b, "bp:wrench")
	aim(20, 64, 20)
	M.click(b, "secondary")
	eq(b.ui.ctx.can_edit, false)
	M.ui_event(b, "lock_public", { value = false })
	eq(locks.at_block(20, 64, 20).public, true)
end)

test("the owner can remove a lock and gets it back; nobody else can", function()
	fresh()
	local a, b = dev("alice"), dev("bob")
	local locks = require("game.locks")
	a:give({ item = M.id("bp:lock_small"), count = 1 })
	M.select(a, "bp:lock_small")
	aim(20, 63, 20, 0, 1, 0)
	M.click(a, "secondary")
	eq(M.count(a, "bp:lock_small"), 0)
	aim(20, 64, 20)
	for _ = 1, 6 do
		M.click(b, "primary")
	end
	truthy(locks.at_block(20, 64, 20))
	for _ = 1, 6 do
		M.click(a, "primary")
	end
	eq(locks.at_block(20, 64, 20), nil)
	eq(M.count(a, "bp:lock_small"), 1)
	truthy(locks.can_build(account(b), 20, 20))
end)

test("a grand lock cannot be removed while someone else has a lock inside", function()
	fresh()
	local a, b = dev("alice"), dev("bob")
	local locks = require("game.locks")
	a:give({ item = M.id("bp:lock_grand"), count = 1 })
	M.select(a, "bp:lock_grand")
	aim(500, 63, 500, 0, 1, 0)
	M.click(a, "secondary")
	-- alice makes bob an admin, then bob puts a small lock inside
	M.select(a, "bp:wrench")
	aim(500, 64, 500)
	M.click(a, "secondary")
	M.ui_event(a, "lock_add", { role = "admin", name = "bob" })
	b:give({ item = M.id("bp:lock_small"), count = 1 })
	M.select(b, "bp:lock_small")
	aim(520, 63, 520, 0, 1, 0)
	M.click(b, "secondary")
	truthy(locks.at_block(520, 64, 520))
	aim(500, 64, 500)
	for _ = 1, 6 do
		M.click(a, "primary")
	end
	truthy(locks.at_block(500, 64, 500), "still there")
	-- alice keeps control of the land inside bob's small lock
	truthy(locks.can_build(account(a), 521, 521))
end)

local function setup_vending()
	local a, b = dev("alice"), dev("bob")
	a:give({ item = M.id("bp:lock_big"), count = 1 })
	M.select(a, "bp:lock_big")
	aim(20, 63, 20, 0, 1, 0)
	M.click(a, "secondary")
	a:give({ item = M.id("bp:vending"), count = 1 })
	M.select(a, "bp:vending")
	aim(22, 63, 22, 0, 1, 0)
	M.click(a, "secondary")
	return a, b
end

test("vending machines only go on land you have locked", function()
	fresh()
	local a = dev("alice")
	a:give({ item = M.id("bp:vending"), count = 1 })
	M.select(a, "bp:vending")
	aim(22, 63, 22, 0, 1, 0)
	M.click(a, "secondary")
	eq(M.world["22,64,22"], nil)
	eq(M.count(a, "bp:vending"), 1)
end)

test("selling through a vending machine", function()
	fresh()
	local a, b = setup_vending()
	local vending = require("game.vending")
	truthy(vending.get(22, 64, 22))
	a:give({ item = M.id("bp:dirt"), count = 20 })
	M.select(a, "bp:dirt")
	M.select(a, "bp:wrench")
	aim(22, 64, 22)
	M.click(a, "secondary")
	eq(a.ui.name, "bp:vending")
	eq(a.ui.ctx.is_owner, true)
	M.select(a, "bp:dirt")
	M.ui_event(a, "vend_qty", { delta = 9 }, "bp:vending")
	M.ui_event(a, "vend_stock", {}, "bp:vending")
	eq(vending.get(22, 64, 22).stock, 10)
	eq(vending.get(22, 64, 22).item, M.id("bp:dirt"))
	M.ui_event(a, "vend_terms", { price = 3, bundle = 2 }, "bp:vending")
	M.ui_event(a, "vend_terms", { price = -5 }, "bp:vending")
	eq(vending.get(22, 64, 22).price, 3)
	eq(vending.get(22, 64, 22).bundle, 2)

	M.select(b, "bp:wrench")
	aim(22, 64, 22)
	M.click(b, "secondary")
	eq(b.ui.ctx.is_owner, false)
	local before = M.count(b, "bp:dirt")
	M.ui_event(b, "vend_buy", {}, "bp:vending")
	eq(M.count(b, "bp:dirt"), before + 2)
	eq(account(b).coins, 97)
	eq(vending.get(22, 64, 22).stock, 8)
	eq(vending.get(22, 64, 22).till, 3)
	-- a stranger cannot use the owner's controls
	M.ui_event(b, "vend_collect", {}, "bp:vending")
	M.ui_event(b, "vend_terms", { price = 1 }, "bp:vending")
	eq(vending.get(22, 64, 22).till, 3)
	eq(vending.get(22, 64, 22).price, 3)
	-- a broke buyer is refused
	account(b).coins = 1
	M.ui_event(b, "vend_buy", {}, "bp:vending")
	eq(vending.get(22, 64, 22).stock, 8)
	-- the owner collects
	M.ui_event(a, "vend_collect", {}, "bp:vending")
	eq(account(a).coins, 103)
	eq(vending.get(22, 64, 22).till, 0)
end)

test("breaking a vending machine returns stock; only the owner may", function()
	fresh()
	local a, b = setup_vending()
	local vending = require("game.vending")
	a:give({ item = M.id("bp:dirt"), count = 5 })
	M.select(a, "bp:wrench")
	aim(22, 64, 22)
	M.click(a, "secondary")
	M.select(a, "bp:dirt")
	M.ui_event(a, "vend_stock", {}, "bp:vending")
	local stocked = vending.get(22, 64, 22).stock
	truthy(stocked > 0)
	for _ = 1, 6 do
		M.click(b, "primary")
	end
	truthy(vending.get(22, 64, 22), "bob cannot break it")
	local dirt = M.count(a, "bp:dirt")
	for _ = 1, 6 do
		M.click(a, "primary")
	end
	eq(vending.get(22, 64, 22), nil)
	eq(M.count(a, "bp:dirt"), dirt + stocked)
	eq(M.count(a, "bp:vending"), 1)
end)

test("a trade moves items and coins both ways, once both confirm", function()
	fresh()
	local a, b = dev("alice"), dev("bob")
	M.chat(a, "!trade bob")
	truthy(has_message(b, "!trade accept"))
	M.chat(b, "!trade accept")
	eq(a.ui.name, "bp:trade")
	eq(b.ui.name, "bp:trade")
	local dirt = M.id("bp:dirt")
	M.ui_event(a, "trade_item", { item = dirt, delta = 5 })
	M.ui_event(a, "trade_item", { item = dirt, delta = 200 })
	eq(a.ui.ctx.mine[1].count, 8, "cannot offer more than you have")
	M.ui_event(a, "trade_item", { item = dirt, delta = -3 })
	M.ui_event(b, "trade_coins", { delta = 30 })
	M.ui_event(b, "trade_coins", { delta = 100000 })
	eq(b.ui.ctx.my_coins, 100, "cannot offer more coins than you have")
	M.ui_event(b, "trade_coins", { delta = -70 })
	-- confirming before both accepted does nothing
	M.ui_event(a, "trade_confirm", {})
	M.ui_event(a, "trade_accept", {})
	M.ui_event(b, "trade_accept", {})
	M.ui_event(a, "trade_confirm", {})
	eq(M.count(a, "bp:dirt"), 8, "nothing moved yet")
	-- changing the offer resets accepts
	M.ui_event(b, "trade_coins", { delta = 5 })
	eq(b.ui.ctx.my_accepted, false)
	M.ui_event(a, "trade_accept", {})
	M.ui_event(b, "trade_accept", {})
	M.ui_event(a, "trade_confirm", {})
	M.ui_event(b, "trade_confirm", {})
	eq(M.count(a, "bp:dirt"), 3)
	eq(M.count(b, "bp:dirt"), 13)
	eq(account(a).coins, 100 + 35)
	eq(account(b).coins, 100 - 35)
	eq(a.ui.name, "bp:notice")
end)

test("leaving cancels a trade without losing anything", function()
	fresh()
	local a, b = dev("alice"), dev("bob")
	M.chat(a, "!trade bob")
	M.chat(b, "!trade accept")
	M.ui_event(a, "trade_item", { item = M.id("bp:dirt"), delta = 4 })
	M.leave(b)
	eq(M.count(a, "bp:dirt"), 8)
	eq(a.ui.name, "bp:notice")
	M.ui_event(a, "trade_confirm", {})
	eq(account(a).coins, 100)
end)

test("the store sells locks and seed packs for coins", function()
	fresh()
	local a = dev("alice")
	M.chat(a, "!store")
	eq(a.ui.name, "bp:store")
	M.ui_event(a, "shop_buy", { id = "lock_small" })
	eq(M.count(a, "bp:lock_small"), 1)
	eq(account(a).coins, 50)
	M.ui_event(a, "shop_buy", { id = "lock_grand" })
	eq(M.count(a, "bp:lock_grand"), 0, "too expensive")
	eq(account(a).coins, 50)
	M.ui_event(a, "shop_buy", { id = "seedpack" })
	eq(account(a).coins, 10)
	M.ui_event(a, "shop_buy", { id = "nonsense" })
	M.ui_event(a, "shop_buy", { id = 5 })
	local ledger = require("game.ledger")
	truthy(ledger.economy().burned >= 90)
end)

test("warping lands in the same cell for the same name", function()
	fresh()
	local a = dev("alice")
	M.chat(a, "!warp my world!")
	local name = wn.normalize("my world!", 24)
	local by_name, by_cell = {}, {}
	wn.assign("START", by_name, by_cell, balance.world_grid, "START")
	local idx = wn.assign(name, by_name, by_cell, balance.world_grid, "START")
	local cx, cz = wn.center_of(idx, balance.world_cell_size, balance.world_grid)
	eq(a.x, cx + 0.5)
	eq(a.z, cz + 0.5)
	eq(a.y, balance.world_spawn_y)
	eq(a.deaths, nil, "teleported, not killed")
	local b = dev("bob")
	M.chat(b, "!warp MYWORLD")
	eq(b.x, a.x)
	eq(b.z, a.z)
	M.chat(a, "!world")
	truthy(has_message(a, "MYWORLD"))
	M.advance(4)
	truthy(has_message(a, "world=MYWORLD"))
end)

test("a bad world name is refused", function()
	fresh()
	local a = dev("alice")
	M.chat(a, "!warp !!!")
	truthy(has_message(a, "Cannot warp"))
	eq(a.x, 0.5)
end)

test("the world owner can move the arrival point", function()
	fresh()
	local a = dev("alice")
	M.chat(a, "!warp farm")
	local idx = wn.assign("FARM", {}, {}, balance.world_grid, "START")
	local cx, cz = wn.center_of(idx, balance.world_cell_size, balance.world_grid)
	a.x, a.y, a.z = cx + 3, 70, cz + 3
	M.chat(a, "!setspawn")
	truthy(has_message(a, "Only the owner"))
	a:give({ item = M.id("bp:lock_big"), count = 1 })
	M.select(a, "bp:lock_big")
	aim(cx, 63, cz, 0, 1, 0)
	M.click(a, "secondary")
	M.chat(a, "!setspawn")
	local b = dev("bob")
	M.chat(b, "!warp farm")
	eq(b.x, cx + 3)
	eq(b.y, 71)
end)

test("lava hurts", function()
	fresh()
	local a = dev("alice")
	M.fire("region_enter", a, { x = 0, y = 5, z = 0 }, "bp:lava")
	eq(a.health, 12)
	M.fire("region_enter", a, { x = 0, y = 5, z = 0 }, "bp:water")
	eq(a.health, 12)
end)

test("everything survives a server restart", function()
	fresh()
	local a, b = dev("alice"), dev("bob")
	M.select(a, "bp:dirt_seed")
	aim(5, 63, 5, 0, 1, 0)
	M.click(a, "secondary")
	a:give({ item = M.id("bp:lock_small"), count = 1 })
	M.select(a, "bp:lock_small")
	aim(20, 63, 20, 0, 1, 0)
	M.click(a, "secondary")
	M.chat(a, "!warp somewhere")
	M.advance(25)
	local coins = account(a).coins
	local dirt = M.count(a, "bp:dirt")
	M.leave(a)
	M.leave(b)
	local world = M.world
	M.load({ db = M.db, storage = M.storage })
	M.world = world
	local a2 = dev("alice")
	local b2 = dev("bob")
	eq(account(a2).coins, coins)
	eq(M.count(a2, "bp:dirt"), dirt)
	eq(M.count(a2, "bp:wrench"), 1)
	truthy(require("game.farm").get(5, 64, 5), "shrub record")
	truthy(require("game.locks").at_block(20, 64, 20), "lock")
	truthy(not require("game.locks").can_build(account(b2), 20, 20))
	truthy(require("game.store").now() >= 20, "game clock")
	-- the sprout keeps growing from where it was
	M.advance(30)
	eq(M.world["5,64,5"], M.id("bp:dirt_s2"))
	eq(account(a2).recent_worlds[1], "SOMEWHERE")
end)

test("with sign-in required: no login, no entry; groups make moderators", function()
	fresh({ auth_required = true })
	eq(dev("nobody"), nil)
	local mod = M.join("Zed", { subject = "kc-1", name = "Zed", provider = "keycloak", claims = { groups = { "/moderators" } } })
	local user = M.join("Yan", { subject = "kc-2", name = "Yan", provider = "keycloak", claims = {} })
	truthy(mod and user)
	truthy(M.db["account:kc-1"], "keyed by subject, not name")
	M.chat(user, "!ledger")
	truthy(has_message(user, "Moderators only"))
	M.chat(mod, "!ledger 3")
	truthy(has_message(mod, "Coins minted"))
	M.chat(mod, "!mute Yan")
	eq(M.chat(user, "hello everyone"), false)
	M.chat(mod, "!unmute Yan")
	eq(M.chat(user, "hello everyone"), true)
	M.chat(mod, "!ban Yan cheating")
	M.leave(user)
	eq(M.join("Yan", { subject = "kc-2", name = "Yan", provider = "keycloak", claims = {} }), nil, "banned")
	-- the same person under another name is still banned, a new name from another account is not
	eq(M.join("Other", { subject = "kc-2", name = "Other", provider = "keycloak", claims = {} }), nil)
	truthy(M.join("Yan2", { subject = "kc-3", name = "Yan2", provider = "keycloak", claims = {} }))
	M.chat(mod, "!unban Yan")
	truthy(M.join("Yan", { subject = "kc-2", name = "Yan", provider = "keycloak", claims = {} }))
end)

test("the same account cannot be online twice under one name", function()
	fresh()
	local a = dev("alice")
	eq(M.join("alice", nil), nil)
	truthy(a)
end)

test("hostile ui events never raise and never change anything", function()
	fresh()
	local a, b = dev("alice"), dev("bob")
	local junk = { nil, true, false, 0, -1, 1e300, 0 / 0, "x", string.rep("x", 10000), {}, { delta = "x" },
		{ delta = 1e300 }, { item = {} }, { role = 5 }, { name = {} }, { id = {} }, { index = -4 }, { value = "yes" }, { bundle = 0 / 0 } }
	local kinds = { "lock_size", "lock_public", "lock_add", "lock_remove", "vend_buy", "vend_stock", "vend_unstock",
		"vend_terms", "vend_collect", "vend_qty", "trade_item", "trade_coins", "trade_accept", "trade_confirm",
		"shop_buy", "menu_open", "menu_warp", "nonsense", "", "close" }
	M.chat(a, "!store")
	M.advance(2)
	for _, kind in ipairs(kinds) do
		for i = 1, 19 do
			M.advance(0.2)
			M.ui_event(a, kind, junk[i])
		end
	end
	eq(account(a).coins, 100)
	eq(M.count(a, "bp:dirt"), 8)
	eq(account(b).coins, 100)
end)

test("ui events are rate limited", function()
	fresh()
	local a = dev("alice")
	account(a).coins = 1000000
	for _ = 1, 200 do
		M.ui_event(a, "shop_buy", { id = "wrench" })
	end
	truthy(M.count(a, "bp:wrench") < 40, "got " .. M.count(a, "bp:wrench"))
end)

test("the menu opens with E", function()
	fresh()
	local a = dev("alice")
	M.input(a, { menu = true })
	eq(a.ui.name, "bp:menu")
end)

test("wrench on a plain block says what it is", function()
	fresh()
	local a = dev("alice")
	M.world["5,64,5"] = M.id("bp:gold")
	M.select(a, "bp:wrench")
	aim(5, 64, 5)
	M.click(a, "secondary")
	truthy(has_message(a, "Gold (rarity 34)"))
end)

test("the economy is logged", function()
	fresh()
	local a = dev("alice")
	local ledger = require("game.ledger")
	local recent = ledger.recent(5)
	eq(recent[1].kind, "mint")
	eq(recent[1].coins, 100)
	truthy(ledger.format(recent[1]):find("100 coins", 1, true))
	eq(ledger.economy().minted, 100)
	truthy(a)
end)

test("E opens the menu, but not while a screen is open (typing 'e' into a text field)", function()
	fresh()
	local a = dev("alice")
	local function press_e()
		M.input(a, { menu = true })
		M.input(a, {})
	end
	press_e()
	eq(a.ui.name, "bp:menu")
	M.ui_event(a, "menu_open", { screen = "warp" })
	eq(a.ui.name, "bp:warp")
	local opened = #a.ui_log
	press_e() -- typing "MYWORLDE" into the warp screen's name field
	eq(#a.ui_log, opened, "E while the warp screen is open must not reopen the menu")
	eq(a.ui.name, "bp:warp")
	M.ui_event(a, "close", nil)
	press_e()
	eq(a.ui.name, "bp:menu", "E works again once the screen is closed")
	eq(#a.ui_log, opened + 1)
end)

test("E does not open the menu while the chat box is open", function()
	fresh()
	local a = dev("alice")
	local function press_e()
		M.input(a, { menu = true })
		M.input(a, {})
	end
	M.ui_event(a, "hud_chat", { open = true }, "")
	press_e() -- typing "hello" into the chat box
	eq(a.ui, nil, "E while chatting must not open the menu")
	M.ui_event(a, "hud_chat", { open = false }, "")
	press_e()
	eq(a.ui.name, "bp:menu")
	-- junk from the client is ignored
	M.ui_event(a, "hud_chat", "yes", "")
	M.ui_event(a, "close", nil)
	press_e()
	eq(#a.ui_log, 2)
end)

test("the warp loading screen closes itself once the player has landed", function()
	fresh()
	local a = dev("alice")
	local function closes()
		local n = 0
		for _, m in ipairs(a.messages) do
			if m:find("cmd=close_loading", 1, true) then
				n = n + 1
			end
		end
		return n
	end
	M.chat(a, "!warp landing")
	eq(a.ui.name, "bp:loading")
	eq(a.ui.ctx.world, "LANDING")
	M.advance(2, 0.25) -- still falling: nothing under the player at the spawn height
	eq(closes(), 0)
	-- lands on the ground at the destination
	local gx, gz = math.floor(a.x), math.floor(a.z)
	M.world[gx .. "," .. 63 .. "," .. gz] = M.id("bp:grass")
	a.y = 64
	M.advance(0.25, 0.25)
	eq(closes(), 0, "needs a steady height first")
	M.advance(1, 0.25)
	eq(closes(), 1, "the HUD is told to close the loading screen")
	M.ui_event(a, "close", nil)
	M.advance(20, 0.5)
	eq(closes(), 1, "only once")
end)

test("the warp loading screen times out, and never closes another screen", function()
	fresh()
	local a = dev("alice")
	local function closes()
		local n = 0
		for _, m in ipairs(a.messages) do
			if m:find("cmd=close_loading", 1, true) then
				n = n + 1
			end
		end
		return n
	end
	M.chat(a, "!warp nowhere")
	eq(a.ui.name, "bp:loading")
	M.advance(16, 0.5) -- never lands
	eq(closes(), 1)
	M.ui_event(a, "close", nil)
	-- the player opens the menu while still loading: the menu stays
	M.chat(a, "!warp elsewhere")
	M.chat(a, "!menu")
	M.advance(16, 0.5)
	eq(a.ui.name, "bp:menu")
	eq(closes(), 1, "no close command while another screen is showing")
end)

test("leaving saves the player even though the engine's leave handle has no name", function()
	fresh()
	local a, b = dev("alice"), dev("bob")
	a:give({ item = M.id("bp:gold"), count = 7 })
	account(a).coins = 345
	M.leave(a) -- get_name() is "" and get_pos() throws, like the real engine
	-- timers keep running: shrub sweep, inventory autosave, HUD, warp arrivals
	M.advance(65, 0.5)
	truthy(not require("game.accounts").online("alice"), "alice is no longer online")
	local a2 = dev("alice")
	eq(M.count(a2, "bp:gold"), 7, "inventory survived the leave and the autosave after it")
	eq(account(a2).coins, 345)
	truthy(M.count(b, "bp:dirt") > 0, "bob is untouched")
end)
