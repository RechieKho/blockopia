-- bp:shrub_timer -- the floating "time left" label above a shrub (game/shrub_labels.lua).
-- Every label text is its own texture (textures/timer/<text>.png), picked at spawn with a
-- visual_override.
vb.register_entity({
	name = "bp:shrub_timer",
	width = 1.0,
	height = 0.5,
	visual = {
		variant = "flat", -- 256 x 128 frames
		texture = "textures/timer/ripe.png",
		facings = 4, -- the same from every side: 3 identical rows (mirror)
		clips = { { clip = "idle", frames = 1, fps = 1 } },
	},
})
