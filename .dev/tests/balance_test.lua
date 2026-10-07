local sim = require("tools.balance_sim")
local items = require("data.items")
local locks = require("data.locks")

local function species(key)
	for _, e in ipairs(items) do
		if e.key == key then
			return e
		end
	end
end

test("expected coins grow with rarity", function()
	truthy(sim.expected_coins(50) > sim.expected_coins(1) * 5)
end)

test("a small lock is within reach of a new player, a grand lock is a long-term goal", function()
	local dirt = species("dirt")
	local minutes_small = locks.small.price / sim.coins_per_minute(dirt)
	local minutes_grand = locks.grand.price / sim.coins_per_minute(dirt)
	print(string.format("[balance] small lock: %.0f min, grand lock: %.0f min of punching dirt", minutes_small, minutes_grand))
	truthy(minutes_small < 60, "small lock takes " .. minutes_small .. " minutes")
	truthy(minutes_grand > 600, "grand lock takes only " .. minutes_grand .. " minutes")
end)

test("farming a rare species pays more per harvest but waits longer", function()
	local d, c = species("dirt"), species("crystal")
	truthy(sim.expected_coins(c.rarity) > sim.expected_coins(d.rarity))
	truthy(require("lib.farm").grow_seconds(c.rarity, 1) > require("lib.farm").grow_seconds(d.rarity, 1))
end)
