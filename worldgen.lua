-- Rolling hills over a rock layer, with lava, gravel and clay pockets deep in the rock. Heights stay
-- within world_ground_y +- world_hill_height, so a warp that drops players from world_spawn_y always
-- lands on the ground.
local balance = require("data.balance")

vb.worldgen.set_pipeline({
	-- The fbm node's own frequency sets the feature size: hills about 80 blocks across.
	height = vb.noise.fbm({
		source = vb.noise.value(1),
		octaves = 4,
		lacunarity = 2.0,
		gain = 0.5,
		frequency = 1 / 80,
	}),
	base_height = balance.world_ground_y,
	amplitude = balance.world_hill_height,
	sea_level = 0, -- no water
	soil_depth = 4,
	-- Biome regions (biomes/*.lua) are about this many blocks across.
	cell_size = 192,
	veins = {
		{ block = "bp:lava", target_rock = "bp:rock", height_min = 2, height_max = 24, vein_size = 14, spawn_rate = 0.5 },
		{ block = "bp:gravel", target_rock = "bp:rock", height_min = 8, height_max = 56, vein_size = 10, spawn_rate = 0.8 },
		{ block = "bp:clay", target_rock = "bp:rock", height_min = 20, height_max = 58, vein_size = 8, spawn_rate = 0.6 },
	},
})
