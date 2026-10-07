-- bp:lock -- opened by using the wrench on a lock. Only the owner can change anything.
ui.define("bp:lock", function(state)
	local admins, builders = state.admins or {}, state.builders or {}
	local rows = math.max(#admins, #builders)
	local widgets, x, y, k = bp_ui.window(state.tier or "Lock", 640, 330 + rows * 30)
	bp_ui.close_button(widgets, x, y, math.floor(640 * k), k)
	local left = x + math.floor(16 * k)
	bp_ui.label(widgets, "owner", left, y + math.floor(46 * k), k, "Owner: " .. (state.owner or "?") .. "   (lock #" .. (state.id or 0) .. ")", bp_ui.text)
	bp_ui.label(widgets, "area", left, y + math.floor(72 * k), k,
		string.format("Protects %d x %d blocks, all heights   (x %d..%d, z %d..%d)", state.size or 0, state.size or 0,
			state.x1 or 0, state.x2 or 0, state.z1 or 0, state.z2 or 0), bp_ui.muted, 14)
	if not state.can_edit then
		bp_ui.label(widgets, "readonly", left, y + math.floor(110 * k), k, "Only the owner can change this lock.", bp_ui.muted)
		return { widgets = widgets }
	end

	local row = y + math.floor(104 * k)
	if state.adjustable then
		bp_ui.label(widgets, "size_label", left, row + math.floor(8 * k), k, "Size: " .. (state.size or 0) .. " (max " .. (state.max_size or 0) .. ")", bp_ui.text)
		for i, step in ipairs({ -10, -1, 1, 10 }) do
			bp_ui.button(widgets, "size_" .. i, left + math.floor((260 + (i - 1) * 62) * k), row, 56, 32, k,
				(step > 0 and "+" or "") .. step, function()
					ui.send_event("lock_size", { delta = step })
				end)
		end
	else
		bp_ui.label(widgets, "size_fixed", left, row + math.floor(8 * k), k, "Size is fixed for this lock.", bp_ui.muted)
	end

	row = row + math.floor(46 * k)
	bp_ui.button(widgets, "public", left, row, 300, 32, k,
		state.public and "Public building: ON (anyone can build)" or "Public building: OFF", function()
			ui.send_event("lock_public", { value = not state.public })
		end)

	row = row + math.floor(48 * k)
	state.add_name = state.add_name or ""
	widgets[#widgets + 1] = { id = "add_name", type = "textbox", x = left, y = row, w = math.floor(220 * k), h = math.floor(32 * k),
		text = state.add_name, on_change = function(value)
			state.add_name = tostring(value)
		end }
	bp_ui.button(widgets, "add_admin", left + math.floor(230 * k), row, 120, 32, k, "Add admin", function()
		ui.send_event("lock_add", { role = "admin", name = state.add_name })
	end)
	bp_ui.button(widgets, "add_builder", left + math.floor(360 * k), row, 130, 32, k, "Add builder", function()
		ui.send_event("lock_add", { role = "builder", name = state.add_name })
	end)

	row = row + math.floor(44 * k)
	bp_ui.label(widgets, "admins_title", left, row, k, "Admins (can place locks and vending machines)", bp_ui.title, 14)
	bp_ui.label(widgets, "builders_title", left + math.floor(320 * k), row, k, "Builders", bp_ui.title, 14)
	for i, name in ipairs(admins) do
		bp_ui.button(widgets, "rm_admin_" .. i, left, row + math.floor((22 + (i - 1) * 30) * k), 200, 26, k, name .. "  [remove]", function()
			ui.send_event("lock_remove", { role = "admin", index = i })
		end)
	end
	for i, name in ipairs(builders) do
		bp_ui.button(widgets, "rm_builder_" .. i, left + math.floor(320 * k), row + math.floor((22 + (i - 1) * 30) * k), 200, 26, k, name .. "  [remove]", function()
			ui.send_event("lock_remove", { role = "builder", index = i })
		end)
	end
	return { widgets = widgets }
end)
