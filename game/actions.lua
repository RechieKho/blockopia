-- Turns raw input into game actions: one punch per left click, and for a right click either
-- placing a block, planting/splicing a seed, or using the wrench.
local session = require("game.session")
local ids = require("game.ids")
local farm = require("game.farm")
local wrench = require("game.wrench")
local placing = require("game.placing")
local notify = require("game.notify")
local ray = require("lib.ray")
local store = require("game.store")
local balance = require("data.balance")

local M = {}

local was_down, was_secondary, was_menu = {}, {}, {}
local last_swing = {} -- player name -> game time of the last shrub punch

-- Left click. The engine's punch only sees solid blocks, so a shrub in the line of sight is broken
-- directly (still through the engine's validated break: reach, protection, rewards).
local function punch(player, input)
	local hit = M.pick(player, input)
	local meta = hit and ids.meta(vb.world.get_block(hit.x, hit.y, hit.z))
	if meta and meta.kind == "shrub" then
		local name, now = player:get_name(), store.now()
		if now - (last_swing[name] or -1) >= balance.punch_cooldown_seconds then
			last_swing[name] = now
			player:break_block(hit.x, hit.y, hit.z)
		end
	else
		player:punch(1)
	end
end

-- What the player is looking at: the first non-air block within reach, solid or not. (The
-- engine's raycast skips walk-through blocks, but shrubs must be targetable.)
-- Replaceable, so tests can aim without building geometry.
function M.pick(player, input)
	local pos = player:get_pos()
	local yaw, pitch = math.rad(input.yaw), math.rad(input.pitch)
	local dx = math.sin(yaw) * math.cos(pitch)
	local dy = math.sin(pitch)
	local dz = -math.cos(yaw) * math.cos(pitch)
	local eye = vb.physics.get_params().eye_height
	return ray.cast(vb.world.get_block, pos.x, pos.y + eye, pos.z, dx, dy, dz, vb.action.get_params().reach)
end

local function secondary(player, acc, input)
	local held = player:get_held_item()
	if not held or held.item == 0 then
		return
	end
	local meta = ids.meta(held.item)
	if not meta then
		return
	end
	local hit = M.pick(player, input)
	if not hit then
		return
	end
	if meta.kind == "tool" then
		wrench.use(player, hit)
	elseif meta.kind == "seed" then
		local target = ids.meta(vb.world.get_block(hit.x, hit.y, hit.z))
		if target and target.kind == "shrub" then
			farm.splice(player, acc, hit.x, hit.y, hit.z, meta)
		elseif hit.ny == 1 then
			farm.plant(player, acc, hit.x, hit.y, hit.z, meta)
		end
	elseif placing.placeable(meta) then
		local x, y, z = hit.x + hit.nx, hit.y + hit.ny, hit.z + hit.nz
		if vb.world.get_block(x, y, z) ~= 0 then
			return
		end
		local ok, why = placing.can_place(acc, meta, x, y, z)
		if not ok then
			notify.throttled(player, why or "You cannot place that here.")
			return
		end
		if player:place_block(x, y, z, held.item) then
			player:take({ item = held.item, count = 1 })
		end
	end
end

-- player_input handler. Never changes movement.
function M.on_input(player, input)
	local acc = session.touch(player)
	if not acc or not acc.ready then
		return
	end
	local name = player:get_name()

	local down = input.buttons and input.buttons.primary or false
	if down and not was_down[name] then
		punch(player, input)
	end
	was_down[name] = down

	local sec = input.buttons and input.buttons.secondary or false
	if sec and not was_secondary[name] then
		secondary(player, acc, input)
	end
	was_secondary[name] = sec

	-- E opens the menu, but not while one of our screens or the chat box is open: the client still
	-- reports the key while the player types "e" into a text field or a chat message.
	local menu = input.keybinds and input.keybinds["base:inventory"] or false
	local ui_events = require("game.ui_events")
	if menu and not was_menu[name] and not ui_events.screen_open(player) and not ui_events.chatting(player) then
		require("game.menu").open_menu(player)
	end
	was_menu[name] = menu
end

function M.forget(player)
	local name = player:get_name()
	was_down[name], was_secondary[name], was_menu[name], last_swing[name] = nil, nil, nil, nil
end

return M
