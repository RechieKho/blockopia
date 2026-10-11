-- Clothing. Right click while holding a clothing item puts it on (replacing whatever was in that
-- slot) or takes it off again. Worn items stay in the inventory; one that leaves it (sold, traded,
-- dropped) comes off. The outfit is saved with the account and drawn on the player's sprite as
-- paper-doll layers (lib/outfit.lua, player:set_visual_override); players see their own outfit
-- in third person (F5).
local accounts = require("game.accounts")
local inventory = require("game.inventory")
local notify = require("game.notify")
local ids = require("game.ids")
local outfit_lib = require("lib.outfit")

local M = {}

local applied = {} -- player name -> outfit signature last sent to the engine

-- slot -> clothing meta for the account's outfit (unknown keys are dropped).
local function metas(acc)
	local out = {}
	for slot, key in pairs(acc.outfit or {}) do
		local id = ids.by_name["bp:" .. tostring(key)]
		local meta = id and ids.meta(id)
		if meta and meta.kind == "clothing" and meta.slot == slot then
			out[slot] = meta
		end
	end
	return out
end

-- Takes off what the player no longer owns, then sends the outfit to the engine if it changed
-- (always when `force`: a player's appearance only lasts for their session).
function M.apply(player, acc, force)
	acc.outfit = acc.outfit or {}
	for slot, meta in pairs(metas(acc)) do
		if inventory.count(player, ids.id(meta.name)) < 1 then
			acc.outfit[slot] = nil
			notify.say(player, "You took off your " .. meta.label .. ".")
		end
	end
	local worn = metas(acc)
	for slot in pairs(acc.outfit) do
		if not worn[slot] then
			acc.outfit[slot] = nil
		end
	end
	local sig = outfit_lib.signature(worn)
	local name = player:get_name()
	if not force and applied[name] == sig then
		return
	end
	applied[name] = sig
	local layers = outfit_lib.layers(worn)
	player:set_visual_override(#layers > 0 and { layers = layers } or nil)
end

-- Right click with clothing in hand.
function M.toggle(player, acc, meta)
	acc.outfit = acc.outfit or {}
	if acc.outfit[meta.slot] == meta.key then
		acc.outfit[meta.slot] = nil
		notify.say(player, "You took off your " .. meta.label .. ".")
	else
		acc.outfit[meta.slot] = meta.key
		notify.say(player, "You put on your " .. meta.label .. ". Press F5 to see yourself.")
	end
	M.apply(player, acc)
	accounts.save(acc)
end

function M.worn(acc)
	local out = {}
	for slot, meta in pairs(metas(acc)) do
		out[slot] = meta.key
	end
	return out
end

-- Every few seconds: catches clothing that left a player's inventory.
function M.check_all()
	for _, player in accounts.each_online() do
		local acc = accounts.of(player)
		if acc and acc.ready then
			M.apply(player, acc)
		end
	end
end

function M.forget(player)
	applied[player:get_name()] = nil
end

return M
