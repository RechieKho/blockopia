-- Floating timers above shrubs near players: how long until each one is ripe ("Ripe!" when it is).
-- A label is a bp:shrub_timer billboard showing a pre-drawn texture; it is respawned when its text
-- changes and removed once no player is near. game/farm.lua decides which labels should exist.
local farm = require("lib.farm")

local M = {}

local shown = {} -- "x,y,z" -> { entity = e, text = "5m" }

function M.key(x, y, z)
	return x .. "," .. y .. "," .. z
end

local function drop(key)
	local l = shown[key]
	if l then
		pcall(l.entity.remove, l.entity, "shrub_timer")
		shown[key] = nil
	end
end

-- `want` maps M.key(x, y, z) -> { x =, y =, z =, text = } for every label that should be up.
function M.sync(want)
	for key, l in pairs(shown) do
		local w = want[key]
		if not w or w.text ~= l.text then
			drop(key)
		end
	end
	for key, w in pairs(want) do
		if not shown[key] then
			local pos = { x = w.x + 0.5, y = w.y + 1.05, z = w.z + 0.5 }
			local ok, e = pcall(vb.world.spawn, "bp:shrub_timer", pos, { visual_override = { texture = farm.label_texture(w.text) } })
			if ok and e then
				shown[key] = { entity = e, text = w.text }
			end
		end
	end
end

-- The shrub at (x, y, z) is gone.
function M.remove(x, y, z)
	drop(M.key(x, y, z))
end

function M.text_at(x, y, z)
	local l = shown[M.key(x, y, z)]
	return l and l.text
end

return M
