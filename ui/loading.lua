-- bp:loading -- shown while a warp lands. It has no button: once the player stands on the ground at
-- the destination the server sends the HUD a "close_loading" command (ui/hud.lua), which closes it.
-- (Closing a screen from its own render function crashes the engine's client.)
ui.define("bp:loading", function(state)
	local widgets, x, y, k = bp_ui.window("Warping", 420, 130)
	local dots = string.rep(".", math.floor((client.time() * 2) % 4))
	bp_ui.label(widgets, "text", x + math.floor(16 * k), y + math.floor(60 * k), k,
		"Travelling to " .. (state.world or "a new world") .. dots, bp_ui.text)
	return { widgets = widgets }
end)
