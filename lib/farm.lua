-- Growth rules. Pure.
local M = {}

-- Seconds a species takes to grow. Strictly increasing in rarity (Growtopia's curve).
function M.grow_seconds(rarity, scale)
	return scale * (rarity ^ 3 + 30 * rarity)
end

-- 0 = sprout, 1 = growing, 2 = ripe.
function M.stage(elapsed, total, growing_at)
	if elapsed >= total then
		return 2
	end
	if elapsed >= total * growing_at then
		return 1
	end
	return 0
end

function M.time_left(elapsed, total)
	return math.max(0, total - elapsed)
end

-- Number of blocks a ripe shrub drops.
function M.yield(rarity, b, rand)
	local top = math.max(1, b.harvest_base - math.floor(rarity / b.harvest_div))
	return rand(1, top)
end

function M.format_duration(seconds)
	seconds = math.ceil(seconds)
	if seconds < 60 then
		return string.format("%ds", seconds)
	end
	if seconds < 3600 then
		return string.format("%dm %ds", seconds // 60, seconds % 60)
	end
	return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
end

-- Timer labels above shrubs (game/shrub_labels.lua). The engine cannot draw text in the world, so
-- every label is a pre-drawn texture: label_texts() is the full list, and
-- .dev/tools/gen_textures.py draws the same list into textures/timer/.
M.LABEL_MAX_HOURS = 99

-- Text above a shrub with `left` seconds to go: "Ripe!", then "1s".."59s", "1m".."59m", "1h"..
-- Whole units left, so "2m" means at least two minutes.
function M.label(left)
	local s = math.ceil(left)
	if s <= 0 then
		return "Ripe!"
	end
	if s < 60 then
		return s .. "s"
	end
	if s < 3600 then
		return (s // 60) .. "m"
	end
	return math.min(s // 3600, M.LABEL_MAX_HOURS) .. "h"
end

function M.label_texts()
	local list = { "Ripe!" }
	for n = 1, 59 do
		list[#list + 1] = n .. "s"
	end
	for n = 1, 59 do
		list[#list + 1] = n .. "m"
	end
	for n = 1, M.LABEL_MAX_HOURS do
		list[#list + 1] = n .. "h"
	end
	return list
end

function M.label_texture(text)
	return "textures/timer/" .. (text == "Ripe!" and "ripe" or text) .. ".png"
end

return M
