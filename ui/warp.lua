-- bp:warp -- type a world name, or pick a recent one. Every name is a world; new names create one.
ui.define("bp:warp", function(state)
	local widgets, x, y, k = bp_ui.window("Warp to a world", 420, 420)
	bp_ui.close_button(widgets, x, y, math.floor(420 * k), k)
	bp_ui.label(widgets, "here", x + math.floor(16 * k), y + math.floor(46 * k), k, state.here or "", bp_ui.muted, 14)
	state.name = state.name or ""
	widgets[#widgets + 1] = { id = "name", type = "textbox", x = x + math.floor(16 * k), y = y + math.floor(76 * k),
		w = math.floor(280 * k), h = math.floor(34 * k), text = state.name,
		on_change = function(value)
			state.name = tostring(value)
		end }
	bp_ui.button(widgets, "go", x + math.floor(306 * k), y + math.floor(76 * k), 98, 34, k, "Warp", function()
		if state.name ~= "" then
			ui.send_event("menu_warp", { name = state.name })
		end
	end)
	bp_ui.label(widgets, "recent_title", x + math.floor(16 * k), y + math.floor(130 * k), k, "Recent worlds", bp_ui.title, 16)
	for i, name in ipairs(state.recent or {}) do
		bp_ui.button(widgets, "recent_" .. i, x + math.floor(16 * k), y + math.floor((158 + (i - 1) * 30) * k), 388, 26, k, name, function()
			ui.send_event("menu_warp", { name = name })
		end)
	end
	return { widgets = widgets }
end)
