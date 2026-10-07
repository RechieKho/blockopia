-- Registers every block, seed, shrub stage, lock and machine from data/items.lua.
-- This is the only file in blocks/, so it loads first; every other module reads ids through
-- game/ids.lua. Block ids follow registration order and saved worlds store ids, so
-- data/items.lua is append-only: this file refuses to load if an existing entry has moved.
local registry = require("lib.registry")
local splice = require("lib.splice")
local ids = require("game.ids")
local items = require("data.items")
local locks = require("data.locks")
local splices = require("data.splices")

local errors = registry.validate(items, locks)

local species = {}
for _, e in ipairs(items) do
	if e.kind == "species" then
		species[e.key] = e
	end
end
for _, msg in ipairs(splice.validate(splices, species)) do
	errors[#errors + 1] = msg
end
if #errors > 0 then
	error("blockopia data is invalid:\n  " .. table.concat(errors, "\n  "))
end

local list = registry.expand(items, locks)
local names = {}
for i, b in ipairs(list) do
	names[i] = b.name
end
local order_error = registry.check_order(vb.storage.block_order, names)
if order_error then
	error(order_error)
end
vb.storage.block_order = names

for _, b in ipairs(list) do
	local def, meta = b.def, b.meta
	-- The callbacks look their module up when they run, so load order does not matter.
	def.on_break = function(ctx)
		require("game.breaking").on_break(meta, ctx)
	end
	def.on_place = function(ctx)
		require("game.placing").on_place(meta, ctx)
	end
	local id = vb.register_block(def)
	ids.register(b.name, id, meta)
end
