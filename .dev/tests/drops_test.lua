local drops = require("lib.drops")
local b = require("data.balance")

test("block chance falls with rarity but stays inside its bounds", function()
	truthy(drops.block_chance(1, b) <= b.block_max)
	truthy(drops.block_chance(200, b) >= b.block_min)
	truthy(drops.block_chance(1, b) >= drops.block_chance(100, b))
end)

test("coins grow with rarity", function()
	local lo, hi = 0, 0
	for _ = 1, 2000 do
		lo = lo + drops.coin_amount(1, b, math.random)
		hi = hi + drops.coin_amount(50, b, math.random)
	end
	truthy(hi > lo * 5, "rare blocks should pay far more")
	truthy(drops.coin_amount(1, b, function()
		return 0
	end) >= 1)
end)

test("seed chance comes from the block, not its rarity", function()
	local n, seeds_a, seeds_b = 50000, 0, 0
	for _ = 1, n do
		if drops.roll({ rarity = 1, seed_chance = 0.5 }, b, math.random).seed then
			seeds_a = seeds_a + 1
		end
		if drops.roll({ rarity = 100, seed_chance = 0.5 }, b, math.random).seed then
			seeds_b = seeds_b + 1
		end
	end
	truthy(math.abs(seeds_a / n - 0.5) < 0.02, "rarity 1 seed rate " .. seeds_a / n)
	truthy(math.abs(seeds_b / n - 0.5) < 0.02, "rarity 100 seed rate " .. seeds_b / n)
end)

test("seed_chance 0 never drops a seed", function()
	for _ = 1, 5000 do
		falsy(drops.roll({ rarity = 5, seed_chance = 0 }, b, math.random).seed)
	end
end)

test("simulated rates match the balance table", function()
	local n, blocks, coins = 100000, 0, 0
	for _ = 1, n do
		local r = drops.roll({ rarity = 10, seed_chance = 0.1 }, b, math.random)
		if r.block then
			blocks = blocks + 1
		end
		if r.coins > 0 then
			coins = coins + 1
		end
	end
	truthy(math.abs(blocks / n - drops.block_chance(10, b)) < 0.01)
	truthy(math.abs(coins / n - b.coin_chance) < 0.01)
end)
