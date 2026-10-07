-- bp:vending -- buyers see the offer; the owner also sees stock, terms and the till.
ui.define("bp:vending", function(state)
	local widgets, x, y, k = bp_ui.window("Vending machine", 520, state.is_owner and 470 or 300)
	bp_ui.close_button(widgets, x, y, math.floor(520 * k), k)
	local left = x + math.floor(16 * k)
	bp_ui.label(widgets, "owner", left, y + math.floor(46 * k), k, "Owner: " .. (state.owner or "?"), bp_ui.muted, 14)
	bp_ui.label(widgets, "offer", left, y + math.floor(74 * k), k,
		string.format("Selling: %s   (%d in stock)", state.item or "nothing yet", state.stock or 0), bp_ui.text)
	bp_ui.label(widgets, "terms", left, y + math.floor(100 * k), k,
		string.format("%d coins for every %d", state.price or 0, state.bundle or 1), bp_ui.coin)

	local row = y + math.floor(140 * k)
	bp_ui.label(widgets, "qty", left, row + math.floor(8 * k), k, "Amount: " .. (state.qty or 1), bp_ui.text)
	for i, step in ipairs({ -10, -1, 1, 10 }) do
		bp_ui.button(widgets, "qty_" .. i, left + math.floor((200 + (i - 1) * 62) * k), row, 56, 32, k,
			(step > 0 and "+" or "") .. step, function()
				ui.send_event("vend_qty", { delta = step })
			end)
	end
	row = row + math.floor(46 * k)
	bp_ui.button(widgets, "buy", left, row, 220, 36, k, "Buy " .. (state.qty or 1) .. " bundle(s)", function()
		ui.send_event("vend_buy", {})
	end)
	bp_ui.label(widgets, "coins", left + math.floor(240 * k), row + math.floor(8 * k), k, "You have " .. (state.coins or 0) .. " coins", bp_ui.coin, 14)

	if state.is_owner then
		row = row + math.floor(56 * k)
		bp_ui.label(widgets, "own_title", left, row, k, "Owner controls", bp_ui.title, 16)
		row = row + math.floor(28 * k)
		bp_ui.label(widgets, "held", left, row, k, "Holding: " .. (state.held or "nothing") .. " x" .. (state.held_count or 0), bp_ui.muted, 14)
		row = row + math.floor(24 * k)
		bp_ui.button(widgets, "stock", left, row, 160, 32, k, "Stock held item", function()
			ui.send_event("vend_stock", {})
		end)
		bp_ui.button(widgets, "unstock", left + math.floor(170 * k), row, 160, 32, k, "Take stock back", function()
			ui.send_event("vend_unstock", {})
		end)
		row = row + math.floor(44 * k)
		bp_ui.label(widgets, "price_label", left, row + math.floor(8 * k), k, "Price:", bp_ui.text, 14)
		for i, step in ipairs({ -10, -1, 1, 10 }) do
			bp_ui.button(widgets, "price_" .. i, left + math.floor((60 + (i - 1) * 56) * k), row, 50, 32, k,
				(step > 0 and "+" or "") .. step, function()
					ui.send_event("vend_terms", { price = math.max(1, (state.price or 1) + step) })
				end)
		end
		for i, step in ipairs({ -1, 1, 10 }) do
			bp_ui.button(widgets, "bundle_" .. i, left + math.floor((300 + (i - 1) * 62) * k), row, 56, 32, k,
				"per " .. (step > 0 and "+" or "") .. step, function()
					ui.send_event("vend_terms", { bundle = math.max(1, (state.bundle or 1) + step) })
				end)
		end
		row = row + math.floor(44 * k)
		bp_ui.button(widgets, "collect", left, row, 260, 32, k, "Collect " .. (state.till or 0) .. " coins from till", function()
			ui.send_event("vend_collect", {})
		end)
	end
	return { widgets = widgets }
end)
