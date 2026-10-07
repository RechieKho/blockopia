-- Chat commands. All of them start with "!".
local accounts = require("game.accounts")
local notify = require("game.notify")
local worlds = require("game.worlds")
local moderation = require("game.moderation")
local util = require("lib.util")

local M = {}

local HELP = {
	"!warp <world>  - travel to a world (any name you like)",
	"!world         - which world you are in and who owns it",
	"!menu          - open the menu (or press E)",
	"!store         - open the coin store",
	"!almanac       - species and splice recipes you have found",
	"!coins         - show your coins",
	"!trade <name>  - start a trade; the other player types !trade accept",
	"!setspawn      - set the arrival point of a world you own",
}

local MOD_HELP = {
	"Moderator: !ledger [n], !mute <name>, !unmute <name>, !ban <name> [reason], !unban <name>, !removelock <id>",
}

local commands = {}

commands.help = function(player, acc)
	for _, line in ipairs(HELP) do
		notify.say(player, line)
	end
	if accounts.is_mod(acc) then
		for _, line in ipairs(MOD_HELP) do
			notify.say(player, line)
		end
	end
end

commands.warp = function(player, acc, args)
	if args == "" then
		require("game.menu").open_warp(player)
	else
		worlds.warp(player, args)
	end
end

commands.world = function(player)
	notify.say(player, worlds.info(player))
end

commands.menu = function(player)
	require("game.menu").open_menu(player)
end

commands.store = function(player)
	require("game.shop").open(player)
end

commands.almanac = function(player)
	require("game.almanac").open(player)
end

commands.coins = function(player, acc)
	notify.say(player, "You have " .. acc.coins .. " coins.")
end

commands.setspawn = function(player)
	worlds.set_spawn(player)
end

commands.trade = function(player, acc, args)
	local trade = require("game.trade")
	if args == "accept" then
		trade.accept_request(player)
	elseif args == "cancel" then
		trade.cancel(player)
	elseif args ~= "" then
		trade.request(player, args)
	else
		notify.say(player, "Usage: !trade <player name>")
	end
end

local function mod_only(fn)
	return function(player, acc, args)
		if not accounts.is_mod(acc) then
			notify.say(player, "Moderators only.")
			return
		end
		fn(player, acc, args)
	end
end

commands.ledger = mod_only(function(player, acc, args)
	moderation.show_ledger(player, tonumber(args))
end)
commands.mute = mod_only(function(player, acc, args)
	moderation.mute(player, args, true)
end)
commands.unmute = mod_only(function(player, acc, args)
	moderation.mute(player, args, false)
end)
commands.ban = mod_only(function(player, acc, args)
	local name, reason = args:match("^(%S+)%s*(.*)$")
	if name then
		moderation.ban(player, name, reason)
	end
end)
commands.unban = mod_only(function(player, acc, args)
	moderation.unban(player, args)
end)
commands.removelock = mod_only(function(player, acc, args)
	local id = tonumber(args)
	if id then
		moderation.remove_lock(player, math.floor(id))
	end
end)

-- chat event handler. Returns false to hide the line from other players.
function M.on_chat(player, text)
	local acc = accounts.of(player)
	if require("game.hud").is_forged(text) then
		return false
	end
	if not acc then
		return false
	end
	if moderation.is_muted(acc) then
		notify.say(player, "You are muted.")
		return false
	end
	if text:sub(1, 1) ~= "!" then
		return nil
	end
	local name, args = text:match("^!(%a+)%s*(.-)%s*$")
	local fn = name and commands[name:lower()]
	if fn then
		fn(player, acc, util.trim(args))
	else
		notify.say(player, "Unknown command. Try !help.")
	end
	return false
end

return M
