-- Turns an outfit (slot -> clothing meta) into the paper-doll `layers` of the player's visual.
-- Pure: no vb.* calls. Sheets share bp:player's layout (entities/player.lua), so the engine draws
-- them with the body's exact frame. Rows: 0 front, 1 side, 2 back.
local M = {}

-- Bottom to top. A cape hangs behind the body when seen from the front or side, and over it from
-- the back, so it is listed twice: below the body on rows 0-1, over everything but the hat on row 2.
M.ORDER = { "back_below", "pants", "shirt", "back_over", "hat" }

local function sheet(meta)
	return "textures/player/" .. meta.sheet .. ".png"
end

local function layer(meta, extra)
	local l = { texture = sheet(meta), tint = meta.tint }
	for k, v in pairs(extra or {}) do
		l[k] = v
	end
	return l
end

-- `outfit` maps slot -> clothing meta (game/ids.lua meta of a kind = "clothing" item).
function M.layers(outfit)
	local out = {}
	for _, part in ipairs(M.ORDER) do
		if part == "back_below" and outfit.back then
			out[#out + 1] = layer(outfit.back, { below = true, rows = { 0, 1 } })
		elseif part == "back_over" and outfit.back then
			out[#out + 1] = layer(outfit.back, { rows = { 2 } })
		elseif outfit[part] then
			out[#out + 1] = layer(outfit[part])
		end
	end
	return out
end

-- A short string that changes whenever the layers would.
function M.signature(outfit)
	local parts = {}
	for _, slot in ipairs({ "hat", "shirt", "pants", "back" }) do
		parts[#parts + 1] = outfit[slot] and outfit[slot].key or "-"
	end
	return table.concat(parts, ",")
end

return M
