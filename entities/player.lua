-- bp:player -- how every player is drawn. Players are never spawned by the pack; `represents =
-- "player"` makes the engine use this kind's visual for them. Clothing is drawn on top as
-- paper-doll layers with the same frame (game/wardrobe.lua, lib/outfit.lua), so every sheet in
-- textures/player/ has this exact layout (.dev/tools/gen_player.py).
vb.register_entity({
	name = "bp:player",
	represents = "player",
	width = 0.8,
	height = 1.8,
	visual = {
		variant = "tall", -- 128 x 256 frames
		texture = "textures/player/body.png",
		facings = 4, -- rows: 0 front, 1 side (facing right; mirrored for the left), 2 back
		clips = {
			{ clip = "idle", frames = 2, fps = 2 },
			{ clip = "walk", frames = 4, fps = 8 },
			{ clip = "run", frames = 4, fps = 12 },
			{ clip = "jump", frames = 1, fps = 1 },
			{ clip = "fall", frames = 1, fps = 1 },
		},
	},
})
