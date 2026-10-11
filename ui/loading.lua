-- bp:loading -- shown while a warp lands. It has no button: once the player stands on the ground at
-- the destination the server opens it again with `done = true`, and it closes itself and hands the
-- mouse back to the game (closing from a render is safe since engine 0.1.5).
ui.define("bp:loading", function(state)
	if state.done then
		bp_ui.back_to_game()
		return { widgets = {} }
	end
	local widgets, x, y, k = bp_ui.window("Warping", 420, 130)
	local dots = string.rep(".", math.floor((client.time() * 2) % 4))
	bp_ui.label(widgets, "text", x + math.floor(16 * k), y + math.floor(60 * k), k,
		"Travelling to " .. (state.world or "a new world") .. dots, bp_ui.text)
	return { widgets = widgets }
end)
