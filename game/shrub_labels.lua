-- Floating timers above shrubs near players: how long until each one is ripe ("Ripe!" when it is).
-- A label is a text-only bp:shrub_timer entity; its text is changed in place every second and it
-- is removed once no player is near. game/farm.lua decides which labels should exist.
local M = {}

local RIPE_COLOR = { 120, 235, 110 }
local TIME_COLOR = { 255, 255, 255 }

local shown = {} -- "x,y,z" -> { entity = e, text = "5m 3s" }

function M.key(x, y, z)
	return x .. "," .. y .. "," .. z
end

-- The label for `text`: green when ripe, white while growing.
function M.style(text)
	return { value = text, color = text == "Ripe!" and RIPE_COLOR or TIME_COLOR }
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
	for key in pairs(shown) do
		if not want[key] then
			drop(key)
		end
	end
	for key, w in pairs(want) do
		local l = shown[key]
		if l and l.text ~= w.text then
			if pcall(l.entity.set_text, l.entity, M.style(w.text)) then
				l.text = w.text
			else
				drop(key) -- the entity is gone; spawn a new one below
				l = nil
			end
		end
		if not l then
			local pos = { x = w.x + 0.5, y = w.y + 1.05, z = w.z + 0.5 }
			local ok, e = pcall(vb.world.spawn, "bp:shrub_timer", pos, { text = M.style(w.text) })
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
