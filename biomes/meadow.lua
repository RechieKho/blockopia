-- bp:meadow -- the only biome: flat grass over dirt over rock, like a Growtopia world.
-- Biomes take effect once worldgen.lua calls vb.worldgen.set_pipeline.
vb.register_biome({
	name = "bp:meadow",
	surface = "bp:grass",
	filler = "bp:dirt",
	stone = "bp:rock",
})
