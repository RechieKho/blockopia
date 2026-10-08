-- The main menu (E) and the warp screen.
local accounts = require("game.accounts")
local worlds = require("game.worlds")
local ui_events = require("game.ui_events")
local notify = require("game.notify")

local M = {}

function M.open_menu(player)
	local acc = accounts.of(player)
	ui_events.set_context(player, { screen = "bp:menu" })
	require("game.ui_events").open(player, "bp:menu", { coins = acc.coins, name = acc.name, world = worlds.info(player) })
end

function M.open_warp(player)
	local acc = accounts.of(player)
	ui_events.set_context(player, { screen = "bp:warp" })
	require("game.ui_events").open(player, "bp:warp", { recent = worlds.list_recent(acc), here = worlds.info(player) })
end

-- Events from the menu and warp screens.
function M.on_ui_event(player, ctx, kind, value)
	if kind == "menu_open" and type(value) == "table" then
		local target = value.screen
		if target == "store" then
			require("game.shop").open(player)
		elseif target == "almanac" then
			require("game.almanac").open(player)
		elseif target == "warp" then
			M.open_warp(player)
		end
	elseif kind == "menu_warp" and type(value) == "table" and type(value.name) == "string" then
		if #value.name > 64 then
			return
		end
		if worlds.warp(player, value.name) then
			notify.notice(player, "Warping", "Hold on...")
		end
	end
end

return M
