-- bp:menu -- opened with E.
ui.define("bp:menu", function(state)
	local widgets, x, y, k = bp_ui.window("Blockopia", 380, 330)
	bp_ui.close_button(widgets, x, y, math.floor(380 * k), k)
	bp_ui.label(widgets, "who", x + math.floor(16 * k), y + math.floor(50 * k), k, (state.name or "") .. "  -  " .. (state.coins or 0) .. " coins", bp_ui.coin)
	bp_ui.label(widgets, "where", x + math.floor(16 * k), y + math.floor(76 * k), k, state.world or "", bp_ui.muted, 14)
	local labels = { { "warp", "Warp to a world" }, { "store", "Coin store" }, { "almanac", "Almanac" } }
	for i, entry in ipairs(labels) do
		bp_ui.button(widgets, "open_" .. entry[1], x + math.floor(16 * k), y + math.floor((110 + (i - 1) * 54) * k), 348, 44, k, entry[2], function()
			ui.send_event("menu_open", { screen = entry[1] })
		end)
	end
	return { widgets = widgets }
end)
