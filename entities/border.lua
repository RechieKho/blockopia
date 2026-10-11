-- bp:border -- a post that marks the edge of a lock's area for a few seconds (game/borders.lua).
-- One kind; each lock tier spawns it with its own texture (textures/border_<tier>.png). Entities
-- neither block movement nor take punches, so the posts never get in the way.
vb.register_entity({
	name = "bp:border",
	width = 0.8,
	height = 3.0,
	visual = {
		variant = "tall", -- 128 x 256 frames
		texture = "textures/border_small.png",
		facings = 4, -- looks the same from every side: 3 identical rows (mirror)
		clips = { { clip = "idle", frames = 1, fps = 1 } },
	},
})
