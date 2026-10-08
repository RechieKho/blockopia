-- bp:notice -- a small message box (trade finished, warping, ...).
ui.define("bp:notice", function(state)
	local widgets, x, y, k = bp_ui.window(state.title or "Blockopia", 420, 160)
	bp_ui.label(widgets, "text", x + math.floor(16 * k), y + math.floor(60 * k), k, state.text or "", bp_ui.text)
	bp_ui.button(widgets, "ok", x + math.floor(16 * k), y + math.floor(110 * k), 100, 32, k, "OK", bp_ui.back_to_game)
	return { widgets = widgets }
end)
