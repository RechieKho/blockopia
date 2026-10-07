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

return M
