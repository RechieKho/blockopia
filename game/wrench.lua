-- What the wrench does on the block you point at.
local accounts = require("game.accounts")
local locks = require("game.locks")
local notify = require("game.notify")
local ids = require("game.ids")
local farm = require("game.farm")
local vending = require("game.vending")
local worlds = require("game.worlds")

local M = {}

function M.use(player, hit)
	local id = vb.world.get_block(hit.x, hit.y, hit.z)
	local meta = ids.meta(id)
	if not meta then
		return
	end
	if meta.kind == "shrub" then
		farm.inspect(player, hit.x, hit.y, hit.z)
	elseif meta.kind == "lock" then
		local lock = locks.at_block(hit.x, hit.y, hit.z)
		if lock then
			locks.open_screen(player, lock)
		end
	elseif meta.kind == "vending" then
		vending.open(player, { x = hit.x, y = hit.y, z = hit.z })
	elseif meta.kind == "block" then
		local cover = locks.covering(hit.x, hit.z)
		local text = string.format("%s (rarity %d).", meta.label, meta.rarity)
		if #cover > 0 then
			text = text .. " Land locked by " .. cover[#cover].owner_name .. "."
		end
		notify.say(player, text)
	else
		notify.say(player, meta.label .. ".")
	end
end

return M
