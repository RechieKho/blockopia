-- Private chat lines with a per-player rate limit, so protected-land spam does not flood chat.
local store = require("game.store")

local M = {}

local last = {} -- player name -> { text, time }

function M.say(player, text)
	player:send_message(text)
end

-- Like say, but the same text is shown at most once per second.
function M.throttled(player, text)
	local name = player:get_name()
	local now = store.now()
	local prev = last[name]
	if prev and prev.text == text and now - prev.time < 1.0 then
		return
	end
	last[name] = { text = text, time = now }
	player:send_message(text)
end

-- Replaces whatever screen is open with a simple message box.
function M.notice(player, title, text)
	require("game.ui_events").set_context(player, { screen = "bp:notice" })
	require("game.ui_events").open(player, "bp:notice", { title = title, text = text })
end

function M.forget(player)
	last[player:get_name()] = nil
end

return M
