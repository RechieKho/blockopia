-- Blockopia HUD: crosshair, hotbar, coins, world, chat, break progress.
--
-- Coins and the current world arrive as hidden chat lines from the server ("@@bp|coins=..|world=..|
-- owner=.."), because the engine has no server -> HUD data channel. This file parses the newest
-- such line and never shows it.
local MARKER = "@@bp|"

local function parse(log)
	for i = #log, 1, -1 do
		local line = log[i]
		local at = line:find(MARKER, 1, true)
		if at then
			local data = {}
			for key, value in line:sub(at + #MARKER):gmatch("([%w_]+)=([^|]*)") do
				data[key] = value
			end
			return data
		end
	end
	return {}
end

local function hotbar(widgets, screen, k)
	local inv = client.inventory()
	local n = math.min(#inv, 9)
	if n == 0 then
		return
	end
	local selected = client.selected_slot()
	local slot, gap = math.floor(56 * k), math.floor(6 * k)
	local total = n * (slot + gap) - gap
	local x0 = math.floor((screen.width - total) / 2)
	local y0 = screen.height - slot - math.floor(18 * k)
	widgets[#widgets + 1] = { id = "hotbar_bg", type = "rect", x = x0 - 6, y = y0 - 6, w = total + 12, h = slot + 12,
		color = { 18, 18, 24, 190 }, border = { 100, 100, 120, 230 } }
	for i = 1, n do
		local s = inv[i]
		local x = x0 + (i - 1) * (slot + gap)
		widgets[#widgets + 1] = { id = "slot_" .. i, type = "rect", x = x, y = y0, w = slot, h = slot,
			color = { 40, 40, 48, 220 }, border = (i == selected) and { 255, 220, 80, 255 } or { 90, 90, 100, 230 } }
		if s.item ~= 0 and s.count > 0 then
			widgets[#widgets + 1] = { id = "icon_" .. i, type = "icon", x = x + 4, y = y0 + 4, w = slot - 8, h = slot - 8, item = s.item }
			widgets[#widgets + 1] = { id = "count_" .. i, type = "text", x = x + slot - 5, y = y0 + slot - math.floor(18 * k),
				align = "right", font_size = math.floor(15 * k), text = tostring(s.count), color = { 255, 255, 255, 255 } }
		end
	end
	local held = inv[selected]
	if held and held.item ~= 0 and held.name then
		widgets[#widgets + 1] = { id = "held_name", type = "text", x = math.floor(screen.width / 2), y = y0 - math.floor(34 * k),
			align = "center", font_size = math.floor(18 * k), text = (held.name:gsub("^bp:", ""):gsub("_", " ")), color = { 255, 255, 255, 230 } }
	end
end

local function chat(widgets, screen, k)
	local log = client.chat_log()
	local lines = {}
	for _, line in ipairs(log) do
		if not line:find(MARKER, 1, true) then
			lines[#lines + 1] = line
		end
	end
	local show = math.min(#lines, 8)
	local line_h = math.floor(20 * k)
	local y = screen.height - math.floor(24 * k) - (client.chat_open() and (line_h + 8) or 0) - show * line_h
	for i = 1, show do
		widgets[#widgets + 1] = { id = "chat_" .. i, type = "text", x = 12, y = y, font_size = math.floor(16 * k),
			text = lines[#lines - show + i], color = bp_ui.text }
		y = y + line_h
	end
end

-- Tells the server when the chat box opens or closes. The client still reports the E keybind while
-- the player types into the chat box, and only this VM can see that the box is open.
local function report_chat(state)
	local open = client.chat_open() and true or false
	if state.chat_open ~= open then
		state.chat_open = open
		ui.send_event("hud_chat", { open = open })
	end
end

ui.define_hud(function(state)
	report_chat(state)
	local widgets = {}
	local screen = client.screen_size()
	local k = bp_ui.scale()

	local cx, cy = math.floor(screen.width / 2), math.floor(screen.height / 2)
	widgets[#widgets + 1] = { id = "cross_h", type = "rect", x = cx - 8, y = cy - 1, w = 16, h = 2, color = { 255, 255, 255, 200 } }
	widgets[#widgets + 1] = { id = "cross_v", type = "rect", x = cx - 1, y = cy - 8, w = 2, h = 16, color = { 255, 255, 255, 200 } }

	local data = parse(client.chat_log())
	state.data = next(data) and data or state.data or {}
	local d = state.data

	widgets[#widgets + 1] = { id = "coins", type = "text", x = screen.width - 14, y = 12, align = "right",
		font_size = math.floor(22 * k), text = (d.coins or "0") .. " coins", color = bp_ui.coin }
	if d.world and d.world ~= "" then
		local owner = (d.owner and d.owner ~= "") and ("  (owner: " .. d.owner .. ")") or ""
		widgets[#widgets + 1] = { id = "world", type = "text", x = screen.width - 14, y = 12 + math.floor(28 * k), align = "right",
			font_size = math.floor(16 * k), text = d.world .. owner, color = bp_ui.muted }
	end
	widgets[#widgets + 1] = { id = "menu_hint", type = "text", x = screen.width - 14, y = 12 + math.floor(52 * k), align = "right",
		font_size = math.floor(14 * k), text = "E: menu   Enter: chat (!help)", color = bp_ui.muted }

	local health = client.health()
	if health then
		local w = math.floor(220 * k)
		local frac = math.max(0, math.min(1, health.current / health.max))
		widgets[#widgets + 1] = { id = "hp_bg", type = "rect", x = 12, y = 12, w = w, h = math.floor(14 * k), color = { 30, 30, 34, 200 }, border = { 90, 90, 100, 230 } }
		widgets[#widgets + 1] = { id = "hp_fill", type = "rect", x = 13, y = 13, w = math.max(0, (w - 2) * frac), h = math.floor(14 * k) - 2, color = { 210, 60, 60, 255 } }
	end

	local progress = client.break_progress()
	if progress then
		local w = math.floor(140 * k)
		widgets[#widgets + 1] = { id = "break_bg", type = "rect", x = cx - w / 2, y = cy + math.floor(30 * k), w = w, h = math.floor(10 * k),
			color = { 30, 30, 34, 200 }, border = { 90, 90, 100, 230 } }
		widgets[#widgets + 1] = { id = "break_fill", type = "rect", x = cx - w / 2, y = cy + math.floor(30 * k), w = w * progress, h = math.floor(10 * k),
			color = { 235, 235, 235, 255 } }
	end

	hotbar(widgets, screen, k)
	chat(widgets, screen, k)
	return { widgets = widgets }
end)
