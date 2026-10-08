-- Join / ready / leave handling. The engine has no "joined" event with a Player handle: the
-- pre-join event only has the name, so a player becomes "ready" on their first input.
local accounts = require("game.accounts")
local inventory = require("game.inventory")
local notify = require("game.notify")

local M = {}

local pending = {} -- player name -> true until their first input

function M.on_join(name, login)
	if vb.auth.required() and not login then
		return false
	end
	if not accounts.on_join(name, login) then
		return false
	end
	pending[name] = true
end

-- Called for every input. Returns the account, or nil when the player has no account.
function M.touch(player)
	local name = player:get_name()
	local acc = accounts.of_name(name)
	if not acc then
		return nil
	end
	accounts.set_online(player)
	if pending[name] then
		pending[name] = nil
		acc.ready = true
		inventory.restore(player, acc)
		accounts.save(acc)
		notify.say(player, "Welcome to Blockopia, " .. name .. "! Press E for the menu, or type !help.")
		require("game.hud").push(player)
	end
	return acc
end

-- Everything that has to happen when a player leaves.
local function leave(player)
	require("game.trade").on_leave(player)
	require("game.ui_events").clear(player)
	require("game.actions").forget(player)
	require("game.worlds").forget(player)
	pending[player:get_name()] = nil
	notify.forget(player)
	accounts.on_leave(player)
end

-- `player`, but get_name() answers `name`. Every other method goes to the real handle, which keeps
-- its inventory until the leave event is over.
local function named(player, name)
	return setmetatable({}, {
		__index = function(_, key)
			if key == "get_name" then
				return function()
					return name
				end
			end
			local value = player[key]
			if type(value) == "function" then
				return function(_, ...)
					return value(player, ...)
				end
			end
			return value
		end,
	})
end

-- player_leave handler. The engine fires it after dropping the connection, so get_name() on the
-- handle returns "" (engine 0.1.4). Then the leaving player is found as the online player whose
-- entity is gone, and cleaned up under the name we stored for them.
function M.on_leave_event(player)
	local name = player:get_name()
	if name ~= "" then
		leave(player)
		return
	end
	for gone_name, handle in pairs(accounts.gone()) do
		leave(named(handle, gone_name))
	end
end

return M
