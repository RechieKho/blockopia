-- Flat terrain with lava pockets deep in the rock. The ground is the same height everywhere so
-- every world (every 1024 x 1024 cell) looks alike and a warp can land above a known surface.
local balance = require("data.balance")

vb.worldgen.set_pipeline({
	height = vb.noise.constant(0),
	base_height = balance.world_ground_y,
	amplitude = 0,
	sea_level = 0,
	soil_depth = 4,
	cell_size = 256,
	veins = {
		{ block = "bp:lava", target_rock = "bp:rock", height_min = 2, height_max = 24, vein_size = 14, spawn_rate = 0.5 },
	},
})
