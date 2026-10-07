-- bp:store -- the coin store.
ui.define("bp:store", function(state)
	local items = state.items or {}
	local widgets, x, y, k = bp_ui.window("Coin store", 520, 120 + #items * 44)
	bp_ui.close_button(widgets, x, y, math.floor(520 * k), k)
	bp_ui.label(widgets, "coins", x + math.floor(16 * k), y + math.floor(46 * k), k, "You have " .. (state.coins or 0) .. " coins", bp_ui.coin)
	for i, item in ipairs(items) do
		local row = y + math.floor((80 + (i - 1) * 44) * k)
		bp_ui.label(widgets, "name_" .. i, x + math.floor(16 * k), row + math.floor(8 * k), k, item.name, bp_ui.text)
		local can = (state.coins or 0) >= item.price
		bp_ui.button(widgets, "buy_" .. i, x + math.floor(380 * k), row, 124, 34, k, item.price .. " coins", function()
			if can then
				ui.send_event("shop_buy", { id = item.id })
			end
		end)
	end
	return { widgets = widgets }
end)
