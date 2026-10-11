-- bp:shrub_timer -- the floating "time left" label above a shrub (game/shrub_labels.lua): a
-- text-only entity (no sprite), whose text is changed in place as it counts down.
vb.register_entity({
	name = "bp:shrub_timer",
	width = 0.2,
	height = 0.2,
	visual = false,
	text = { size = 0.28, color = { 255, 255, 255 }, background = { 30, 30, 30, 210 }, max_distance = 24 },
})
