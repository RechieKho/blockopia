-- bp:trade -- both sides add items and coins, accept, then confirm.
ui.define("bp:trade", function(state)
	local inv = state.inventory or {}
	local widgets, x, y, k = bp_ui.window("Trade with " .. (state.partner or "?"), 780, 190 + math.max(#inv, 4) * 30)
	bp_ui.close_button(widgets, x, y, math.floor(780 * k), k)
	local left, mid = x + math.floor(16 * k), x + math.floor(400 * k)
	local top = y + math.floor(50 * k)

	bp_ui.label(widgets, "my_title", left, top, k, "You offer", bp_ui.title, 16)
	local line = top + math.floor(24 * k)
	for i, e in ipairs(state.mine or {}) do
		bp_ui.label(widgets, "my_" .. i, left, line, k, e.count .. " x " .. e.name, bp_ui.good, 15)
		line = line + math.floor(20 * k)
	end
	bp_ui.label(widgets, "my_coins", left, line, k, (state.my_coins or 0) .. " coins", bp_ui.coin, 15)

	bp_ui.label(widgets, "their_title", mid, top, k, (state.partner or "?") .. " offers", bp_ui.title, 16)
	line = top + math.floor(24 * k)
	for i, e in ipairs(state.theirs or {}) do
		bp_ui.label(widgets, "their_" .. i, mid, line, k, e.count .. " x " .. e.name, bp_ui.good, 15)
		line = line + math.floor(20 * k)
	end
	bp_ui.label(widgets, "their_coins", mid, line, k, (state.their_coins or 0) .. " coins", bp_ui.coin, 15)

	local row = y + math.floor(190 * k)
	bp_ui.label(widgets, "inv_title", left, row - math.floor(22 * k), k, "Your items (click to add / remove)", bp_ui.muted, 14)
	for i, e in ipairs(inv) do
		local ry = row + (i - 1) * math.floor(30 * k)
		bp_ui.label(widgets, "inv_" .. i, left, ry + math.floor(6 * k), k, string.format("%s  (%d, offering %d)", e.name, e.have, e.offered), bp_ui.text, 14)
		bp_ui.button(widgets, "add1_" .. i, left + math.floor(300 * k), ry, 40, 26, k, "+1", function()
			ui.send_event("trade_item", { item = e.item, delta = 1 })
		end)
		bp_ui.button(widgets, "add10_" .. i, left + math.floor(346 * k), ry, 46, 26, k, "+10", function()
			ui.send_event("trade_item", { item = e.item, delta = 10 })
		end)
		bp_ui.button(widgets, "rm_" .. i, left + math.floor(398 * k), ry, 40, 26, k, "-1", function()
			ui.send_event("trade_item", { item = e.item, delta = -1 })
		end)
	end

	local bx = x + math.floor(480 * k)
	bp_ui.label(widgets, "coins_title", bx, row - math.floor(22 * k), k, "Coins (you have " .. (state.coins or 0) .. ")", bp_ui.muted, 14)
	for i, step in ipairs({ -100, -10, 10, 100 }) do
		bp_ui.button(widgets, "coin_" .. i, bx + math.floor((i - 1) * 66 * k), row, 60, 28, k, (step > 0 and "+" or "") .. step, function()
			ui.send_event("trade_coins", { delta = step })
		end)
	end
	local status = state.my_confirmed and "Waiting for the other player..." or (state.my_accepted and "Accepted" or "Not accepted")
	bp_ui.label(widgets, "status", bx, row + math.floor(44 * k), k, status, bp_ui.muted, 14)
	if state.their_accepted then
		bp_ui.label(widgets, "their_status", bx, row + math.floor(64 * k), k, (state.partner or "") .. " accepted", bp_ui.good, 14)
	end
	bp_ui.button(widgets, "accept", bx, row + math.floor(90 * k), 140, 34, k, "Accept", function()
		ui.send_event("trade_accept", {})
	end)
	if state.my_accepted and state.their_accepted then
		bp_ui.button(widgets, "confirm", bx + math.floor(150 * k), row + math.floor(90 * k), 140, 34, k, "Confirm trade", function()
			ui.send_event("trade_confirm", {})
		end)
	end
	bp_ui.button(widgets, "cancel", bx, row + math.floor(134 * k), 140, 34, k, "Cancel trade", function()
		ui.send_event("trade_cancel", {})
		ui.close()
	end)
	return { widgets = widgets }
end)
