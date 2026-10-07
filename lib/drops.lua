-- Reward rolls for breaking a block. Pure: the caller supplies `rand` (math.random-like).
local util = require("lib.util")

local M = {}

-- Chance that breaking the block also drops the block itself.
function M.block_chance(rarity, b)
	return util.clamp(b.block_base - b.block_slope * rarity, b.block_min, b.block_max)
end

-- Coins for one coin roll; the rarer the block, the more coins.
function M.coin_amount(rarity, b, rand)
	local base = math.floor(rarity / b.coin_div)
	local extra = rand(0, math.ceil(rarity / b.coin_spread))
	return math.max(1, base + extra)
end

-- info = { rarity, seed_chance }. Returns { block = bool, seed = bool, coins = integer }.
function M.roll(info, b, rand)
	local result = { block = false, seed = false, coins = 0 }
	result.block = rand() < M.block_chance(info.rarity, b)
	result.seed = (info.seed_chance or 0) > 0 and rand() < info.seed_chance
	if rand() < b.coin_chance then
		result.coins = M.coin_amount(info.rarity, b, rand)
	end
	return result
end

return M
