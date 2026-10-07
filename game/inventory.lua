-- Thin helpers over the engine inventory (Player:get_inventory / give / take), plus saving it:
-- the engine does not persist inventories, so each account keeps a snapshot.
local accounts = require("game.accounts")
local ids = require("game.ids")
local util = require("lib.util")
local balance = require("data.balance")

local M = {}

function M.count(player, item)
	local n = 0
	for _, slot in ipairs(player:get_inventory()) do
		if slot.item == item then
			n = n + slot.count
		end
	end
	return n
end

function M.give(player, item, count)
	if count > 0 then
		player:give({ item = item, count = count })
	end
end

-- All-or-nothing. Returns true when `count` was removed.
function M.take(player, item, count)
	if count <= 0 then
		return true
	end
	return player:take({ item = item, count = count })
end

-- Totals per item id: { [item] = count }.
function M.totals(player)
	local t = {}
	for _, slot in ipairs(player:get_inventory()) do
		if slot.item ~= 0 and slot.count > 0 then
			t[slot.item] = (t[slot.item] or 0) + slot.count
		end
	end
	return t
end

function M.clear(player)
	for _, slot in ipairs(player:get_inventory()) do
		if slot.item ~= 0 and slot.count > 0 then
			player:take({ item = slot.item, count = slot.count })
		end
	end
end

-- Puts the account's saved items (or the starter kit for a new account) into the inventory.
function M.restore(player, acc)
	M.clear(player)
	if not acc.starter_given then
		for _, entry in ipairs(balance.start_items) do
			M.give(player, ids.id(entry[1]), entry[2])
		end
		acc.starter_given = true
		accounts.discover(acc, "dirt")
	else
		for _, entry in ipairs(acc.inventory) do
			local item, count = util.int(entry.item), util.int(entry.count)
			if item and count and ids.name(item) then
				M.give(player, item, count)
			end
		end
	end
	-- Nobody should lose their wrench.
	if M.count(player, ids.id("bp:wrench")) == 0 then
		M.give(player, ids.id("bp:wrench"), 1)
	end
end

function M.save_all()
	for _, player in accounts.each_online() do
		local acc = accounts.of(player)
		if acc and acc.ready then
			accounts.snapshot_inventory(player, acc)
			accounts.save(acc)
		end
	end
end

return M
