-- bp_ui -- shared colours and small layout helpers for every Blockopia screen. Runs in the client
-- UI VM (no `vb` here). "_" sorts before letters, so this loads first.
bp_ui = {
	backdrop = { 0, 0, 0, 130 },
	panel_bg = { 24, 24, 32, 245 },
	panel_border = { 110, 110, 130, 255 },
	row_bg = { 38, 38, 48, 230 },
	title = { 255, 225, 120, 255 },
	text = { 225, 225, 230, 255 },
	muted = { 165, 165, 178, 255 },
	good = { 130, 230, 140, 255 },
	bad = { 240, 120, 110, 255 },
	coin = { 255, 215, 70, 255 },
}

-- Scale factor so screens keep their proportions on any window size.
function bp_ui.scale()
	local s = client.screen_size()
	return math.min(math.max(math.min(s.width / 1280, s.height / 720), 1), 3)
end

-- Starts a screen: backdrop, a centred window of w x h (in unscaled units) and a title.
-- Returns the widget list and the window's top-left corner in pixels plus the scale.
function bp_ui.window(title, w, h)
	local screen = client.screen_size()
	local k = bp_ui.scale()
	local pw, ph = math.floor(w * k), math.floor(h * k)
	local x = math.floor((screen.width - pw) / 2)
	local y = math.floor((screen.height - ph) / 2)
	local widgets = {
		{ id = "backdrop", type = "rect", x = 0, y = 0, w = screen.width, h = screen.height, color = bp_ui.backdrop },
		{ id = "window", type = "rect", x = x, y = y, w = pw, h = ph, color = bp_ui.panel_bg, border = bp_ui.panel_border },
		{ id = "title", type = "text", x = x + math.floor(16 * k), y = y + math.floor(12 * k), font_size = math.floor(22 * k),
			text = title, color = bp_ui.title },
	}
	return widgets, x, y, k
end

function bp_ui.label(widgets, id, x, y, k, text, color, size)
	widgets[#widgets + 1] = { id = id, type = "text", x = x, y = y, font_size = math.floor((size or 16) * k),
		text = tostring(text), color = color or bp_ui.text }
end

function bp_ui.button(widgets, id, x, y, w, h, k, text, on_click)
	widgets[#widgets + 1] = { id = id, type = "button", x = x, y = y, w = math.floor(w * k), h = math.floor(h * k),
		text = text, on_click = on_click }
end

function bp_ui.close_button(widgets, x, y, w, k)
	bp_ui.button(widgets, "close", x + w - math.floor(96 * k), y + math.floor(10 * k), 80, 28, k, "Close", function()
		ui.close()
	end)
end
