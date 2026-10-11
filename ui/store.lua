-- bp:store -- the coin store, in two columns.
ui.define("bp:store", function(state)
	local items = state.items or {}
	local col_w, rows = 500, math.ceil(#items / 2)
	local widgets, x, y, k = bp_ui.window("Coin store", col_w * 2 + 20, 120 + rows * 44)
	bp_ui.close_button(widgets, x, y, math.floor((col_w * 2 + 20) * k), k)
	bp_ui.label(widgets, "coins", x + math.floor(16 * k), y + math.floor(46 * k), k, "You have " .. (state.coins or 0) .. " coins", bp_ui.coin)
	for i, item in ipairs(items) do
		local col, r = (i - 1) // rows, (i - 1) % rows
		local left = x + math.floor((16 + col * col_w) * k)
		local row = y + math.floor((80 + r * 44) * k)
		bp_ui.label(widgets, "name_" .. i, left, row + math.floor(8 * k), k, item.name, bp_ui.text)
		local can = (state.coins or 0) >= item.price
		bp_ui.button(widgets, "buy_" .. i, left + math.floor(350 * k), row, 124, 34, k, item.price .. " coins", function()
			if can then
				ui.send_event("shop_buy", { id = item.id })
			end
		end)
	end
	return { widgets = widgets }
end)
