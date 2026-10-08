-- The engine has no server -> HUD data channel, so the server sends a private chat line that the
-- HUD (ui/hud.lua) recognises, parses and hides. Lines look like:
--   @@bp|coins=120|world=START|owner=alice
-- The server resends it every few seconds, because the client keeps only the latest chat lines.
local accounts = require("game.accounts")
local worlds = require("game.worlds")
local store = require("game.store")

local M = {}

M.MARKER = "@@bp|"

local function clean(s)
	return (tostring(s):gsub("[|=\n\r]", "_"))
end

function M.line(acc, world, owner)
	return string.format("%scoins=%d|world=%s|owner=%s", M.MARKER, acc.coins, clean(world or ""), clean(owner or ""))
end

function M.push(player)
	local acc = accounts.of(player)
	if not acc then
		return
	end
	local p = player:get_pos()
	local world, owner = "", ""
	local idx = worlds.cell_at(p.x, p.z)
	if idx then
		world = worlds.name_at(p.x, p.z) or "unnamed"
		owner = worlds.owner_name(idx) or ""
	end
	player:send_message(M.line(acc, world, owner))
end

function M.push_all()
	for _, player in accounts.each_online() do
		M.push(player)
	end
end

-- Sends the HUD a one-shot command (ui/hud.lua runs each id once), e.g. "close_loading".
local sent = 0
function M.command(player, cmd)
	sent = sent + 1
	player:send_message(string.format("%scmd=%s|id=%d_%d", M.MARKER, clean(cmd), math.floor(store.now() * 1000), sent))
end

-- Chat lines from players must never be mistaken for server data.
function M.is_forged(text)
	return text:sub(1, #M.MARKER) == M.MARKER
end

return M
