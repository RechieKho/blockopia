-- Blockopia entry point (server pack VM). Loaded last, after blocks/*.lua and worldgen.lua.
-- Everything here only wires engine events to the modules in game/; the rules live in lib/.
local balance = require("data.balance")
local store = require("game.store")
local session = require("game.session")
local accounts = require("game.accounts")
local actions = require("game.actions")
local breaking = require("game.breaking")
local placing = require("game.placing")
local commands = require("game.commands")
local ui_events = require("game.ui_events")
local farm = require("game.farm")
local worlds = require("game.worlds")
local inventory = require("game.inventory")
local hud = require("game.hud")
local notify = require("game.notify")

-- Registration must happen at load time.
vb.register_keybind("base:inventory") -- E: the menu (the client binds this name to the E key)
vb.combat.set_params({
	punch_cooldown_seconds = balance.punch_cooldown_seconds,
	-- a block that has not been punched for a while loses one punch per interval (engine behaviour)
	heal_after_seconds = balance.heal_after_seconds,
	heal_interval_seconds = balance.heal_interval_seconds,
	player_damage = 0, -- no player-versus-player damage
})
vb.action.set_params({ reach = balance.reach })

-- Who may join, and who is ready.
vb.on("player_join", session.on_join)
vb.on("player_leave", function(player)
	require("game.trade").on_leave(player)
	ui_events.clear(player)
	actions.forget(player)
	session.on_leave(player)
end)

-- Punching, placing, planting, menus.
vb.on("player_input", actions.on_input)

-- Protection and rewards.
vb.on("block_break", breaking.on_break_event)
vb.on("block_place", placing.on_place_event)

-- Chat commands, screens, deaths.
vb.on("chat", commands.on_chat)
vb.on("ui_event", ui_events.on_ui_event)
ui_events.route("lock", function(player, ctx, kind, value)
	if ctx.screen == "bp:lock" then
		require("game.locks").on_ui_event(player, ctx, kind, value)
	end
end)
ui_events.route("vend", function(player, ctx, kind, value)
	require("game.vending").on_ui_event(player, ctx, kind, value)
end)
ui_events.route("trade", function(player, ctx, kind, value)
	require("game.trade").on_ui_event(player, ctx, kind, value)
end)
ui_events.route("shop", function(player, ctx, kind, value)
	require("game.shop").on_ui_event(player, ctx, kind, value)
end)
ui_events.route("menu", function(player, ctx, kind, value)
	require("game.menu").on_ui_event(player, ctx, kind, value)
end)

vb.on("player_death", function(player)
	local decision = worlds.on_death(player)
	if not decision then
		notify.say(player, "* you died")
	end
	return decision
end)

-- Lava hurts.
vb.on("region_enter", function(player, pos, block_name)
	if block_name == "bp:lava" then
		player:damage(balance.lava_damage, "lava")
	end
end)

-- Clock, shrub growth, saving.
vb.on("tick", function(dt)
	store.advance(dt)
end)
vb.every(balance.shrub_sweep_seconds, function()
	farm.sweep()
end)
vb.every(balance.inventory_save_seconds, function()
	inventory.save_all()
end)
vb.every(3.0, function()
	hud.push_all()
end)

print(string.format("[blockopia] loaded %d item types", #require("game.ids").species_order))
