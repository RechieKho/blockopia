-- Expands data/items.lua into the ordered list of blocks to register, and validates the data.
-- Pure: no vb.* calls, so tests can run it with plain Lua.
local M = {}

M.PREFIX = "bp:"

local function texture_for(name)
	return "textures/" .. name:gsub("^" .. M.PREFIX, "") .. ".png"
end

function M.name(key)
	return M.PREFIX .. key
end

function M.seed_name(key)
	return M.PREFIX .. key .. "_seed"
end

function M.stage_name(key, stage)
	return M.PREFIX .. key .. "_s" .. stage
end

-- Returns an ordered array of { name, def, meta }.
--   def  : table for vb.register_block (engine fields only)
--   meta : what the pack knows about the block (kind, species key, stage, ...)
function M.expand(items, locks)
	local out = {}
	local function add(name, def, meta)
		def.name = name
		def.texture = def.texture or texture_for(name)
		-- dropped items stay on the ground for 10 minutes (engine default is 2)
		def.item_lifetime_seconds = def.item_lifetime_seconds or 600
		meta.name = name
		out[#out + 1] = { name = name, def = def, meta = meta }
	end

	for _, e in ipairs(items) do
		if e.kind == "special" then
			local def = {}
			for k, v in pairs(e.def or {}) do
				def[k] = v
			end
			add(M.name(e.key), def, {
				kind = e.tool and "tool" or "special", key = e.key, label = e.name,
				unbreakable = e.unbreakable or false, hazard = e.hazard or false, color = e.color,
			})
		elseif e.kind == "species" then
			add(M.name(e.key), { max_damage = e.punches, solid = true, opaque = true }, {
				kind = "block", key = e.key, label = e.name, rarity = e.rarity,
				seed_chance = e.seed_chance, punches = e.punches, color = e.color,
			})
			add(M.seed_name(e.key), { solid = false, opaque = false }, {
				kind = "seed", key = e.key, label = e.name .. " Seed", species = e.key,
				rarity = e.rarity, color = e.color,
			})
			for stage = 0, 2 do
				add(M.stage_name(e.key, stage), { solid = false, opaque = false, max_damage = 0 }, {
					kind = "shrub", key = e.key, label = e.name .. " Shrub", species = e.key,
					stage = stage, rarity = e.rarity, color = e.color,
				})
			end
		elseif e.kind == "lock" then
			local tier = locks[e.tier]
			add(M.name("lock_" .. e.tier), { max_damage = 4, solid = true, opaque = true }, {
				kind = "lock", key = "lock_" .. e.tier, label = tier.name, tier = e.tier,
				color = tier.color,
			})
		elseif e.kind == "vending" then
			add(M.name(e.key), { max_damage = 4, solid = true, opaque = true }, {
				kind = "vending", key = e.key, label = e.name, color = e.color,
			})
		end
	end
	return out
end

-- Returns an array of error strings (empty = valid). `file_exists` is optional.
function M.validate(items, locks, file_exists)
	local errors = {}
	local function err(fmt, ...)
		errors[#errors + 1] = string.format(fmt, ...)
	end
	local seen_keys = {}
	for i, e in ipairs(items) do
		local key = e.key or (e.tier and ("lock_" .. e.tier))
		if not key then
			err("entry %d has no key", i)
		elseif seen_keys[key] then
			err("duplicate key '%s'", key)
		else
			seen_keys[key] = true
		end
		if e.kind == "species" then
			if type(e.rarity) ~= "number" or e.rarity < 1 or e.rarity > 200 or e.rarity ~= math.floor(e.rarity) then
				err("'%s': rarity must be an integer in 1..200", tostring(key))
			end
			if type(e.seed_chance) ~= "number" or e.seed_chance < 0 or e.seed_chance > 1 then
				err("'%s': seed_chance must be a number in 0..1", tostring(key))
			end
			if type(e.punches) ~= "number" or e.punches < 1 or e.punches > 65534 then
				err("'%s': punches must be in 1..65534", tostring(key))
			end
		elseif e.kind == "lock" then
			if not locks[e.tier] then
				err("lock entry names unknown tier '%s'", tostring(e.tier))
			end
		elseif e.kind ~= "special" and e.kind ~= "vending" then
			err("entry '%s' has unknown kind '%s'", tostring(key), tostring(e.kind))
		end
	end
	if file_exists then
		for _, b in ipairs(M.expand(items, locks)) do
			if not file_exists(b.def.texture) then
				err("missing texture %s", b.def.texture)
			end
		end
	end
	return errors
end

-- Block ids are append-only: `saved` is the list of names stored from the previous run. The new
-- list must start with exactly those names. Returns nil, or an error string.
function M.check_order(saved, current_names)
	if type(saved) ~= "table" then
		return nil
	end
	for i, name in ipairs(saved) do
		if current_names[i] ~= name then
			return string.format("block #%d was '%s' but is now '%s'; saved worlds store block ids, "
				.. "so only append new entries to data/items.lua", i, tostring(name), tostring(current_names[i]))
		end
	end
	return nil
end

return M
