-- The item table. ORDER MATTERS: block ids follow registration order and saved worlds store
-- ids, so only ever append entries at the END of this list. lib/registry.lua refuses to load
-- when an existing entry has moved (checked against vb.storage.block_order).
--
-- kind = "special"  one fixed block/item (`def` goes to vb.register_block as-is)
-- kind = "species"  a natural block: expands to the block, its seed, and three shrub stages
-- kind = "lock"     a lock tier from data/locks.lua
-- kind = "vending"  the vending machine
return {
	{ kind = "special", key = "bedrock", name = "Bedrock", color = { 40, 40, 46 },
		def = { max_damage = 65535 }, unbreakable = true },
	{ kind = "special", key = "lava", name = "Lava", color = { 230, 90, 20 },
		def = { solid = false, opaque = false, region = true, light = 12 }, hazard = true },
	{ kind = "special", key = "wrench", name = "Wrench", color = { 170, 175, 185 },
		def = { solid = false, opaque = false }, tool = true },

	-- key, display name, rarity, punches to break, chance that breaking drops its seed, colour
	{ kind = "species", key = "dirt", name = "Dirt", rarity = 1, punches = 2, seed_chance = 0.30, color = { 121, 85, 58 } },
	{ kind = "species", key = "rock", name = "Rock", rarity = 2, punches = 3, seed_chance = 0.28, color = { 125, 125, 130 } },
	{ kind = "species", key = "gravel", name = "Gravel", rarity = 3, punches = 2, seed_chance = 0.26, color = { 150, 145, 140 } },
	{ kind = "species", key = "grass", name = "Grass", rarity = 4, punches = 2, seed_chance = 0.25, color = { 82, 160, 62 } },
	{ kind = "species", key = "sand", name = "Sand", rarity = 5, punches = 1, seed_chance = 0.24, color = { 226, 210, 150 } },
	{ kind = "species", key = "clay", name = "Clay", rarity = 6, punches = 2, seed_chance = 0.22, color = { 176, 110, 90 } },
	{ kind = "species", key = "wood", name = "Wood", rarity = 7, punches = 3, seed_chance = 0.20, color = { 140, 100, 52 } },
	{ kind = "species", key = "glass", name = "Glass", rarity = 8, punches = 1, seed_chance = 0.18, color = { 170, 215, 230 } },
	{ kind = "species", key = "brick", name = "Brick", rarity = 8, punches = 4, seed_chance = 0.20, color = { 170, 70, 55 } },
	{ kind = "species", key = "planks", name = "Planks", rarity = 10, punches = 3, seed_chance = 0.16, color = { 196, 152, 90 } },
	{ kind = "species", key = "marble", name = "Marble", rarity = 12, punches = 4, seed_chance = 0.15, color = { 230, 230, 235 } },
	{ kind = "species", key = "obsidian", name = "Obsidian", rarity = 20, punches = 6, seed_chance = 0.10, color = { 40, 22, 60 } },
	{ kind = "species", key = "gold", name = "Gold", rarity = 34, punches = 5, seed_chance = 0.08, color = { 240, 200, 50 } },
	{ kind = "species", key = "crystal", name = "Crystal", rarity = 50, punches = 5, seed_chance = 0.06, color = { 120, 230, 240 } },

	{ kind = "lock", tier = "small" },
	{ kind = "lock", tier = "big" },
	{ kind = "lock", tier = "huge" },
	{ kind = "lock", tier = "grand" },
	{ kind = "vending", key = "vending", name = "Vending Machine", color = { 200, 60, 70 } },
}
