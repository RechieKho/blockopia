-- bp:meadow -- the common biome: grass over dirt over rock.
-- Biomes take effect once worldgen.lua calls vb.worldgen.set_pipeline.
vb.register_biome({
	name = "bp:meadow",
	surface = "bp:grass",
	filler = "bp:dirt",
	stone = "bp:rock",
	probability = 3.0,
})
