-- Economy simulation. Prints expected coins per minute for each block and how long the store
-- items take to afford, so prices can be tuned without playing.
--   lua .dev/tools/balance_sim.lua      or      python3 .dev/tests/run.py (runs .dev/tests/balance_test.lua)
package.path = "./?.lua;./.dev/?.lua;" .. package.path
local drops = require("lib.drops")
local farm = require("lib.farm")
local items = require("data.items")
local locks = require("data.locks")
local b = require("data.balance")

local M = {}

-- Expected coins from one broken block of the given rarity (exact, no sampling).
function M.expected_coins(rarity)
	local base = math.floor(rarity / b.coin_div)
	local spread = math.ceil(rarity / b.coin_spread)
	local sum = 0
	for extra = 0, spread do
		sum = sum + math.max(1, base + extra)
	end
	return b.coin_chance * sum / (spread + 1)
end

-- Seconds per broken block when punching at the cooldown rate.
function M.seconds_per_block(punches)
	return punches * b.punch_cooldown_seconds
end

function M.coins_per_minute(species)
	return 60 / M.seconds_per_block(species.punches) * M.expected_coins(species.rarity)
end

-- Coins per minute from tending shrubs of a species (harvest only; ignores replanting effort).
function M.farm_coins_per_hour(species, shrubs)
	local per_harvest = b.harvest_coin_factor * M.expected_coins(species.rarity)
	local cycle = farm.grow_seconds(species.rarity, b.grow_scale)
	return shrubs * per_harvest * 3600 / cycle
end

function M.report()
	local lines = {}
	for _, e in ipairs(items) do
		if e.kind == "species" then
			local cpm = M.coins_per_minute(e)
			lines[#lines + 1] = string.format("%-10s R%-3d punches %d  block %.2f  coins/min %6.1f  grows in %s",
				e.key, e.rarity, e.punches, drops.block_chance(e.rarity, b), cpm,
				farm.format_duration(farm.grow_seconds(e.rarity, b.grow_scale)))
		end
	end
	local dirt = items[4]
	for _, tier in ipairs(locks.order) do
		local t = locks[tier]
		lines[#lines + 1] = string.format("%-11s costs %5d coins = %6.1f minutes of punching dirt", t.name, t.price,
			t.price / M.coins_per_minute(dirt))
	end
	return lines
end

if arg and arg[0] and arg[0]:match("balance_sim%.lua$") then
	for _, line in ipairs(M.report()) do
		print(line)
	end
end

return M
