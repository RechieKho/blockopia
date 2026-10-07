-- Block ids and what the pack knows about each block. Filled by blocks/00_items.lua at load time.
local M = {
	by_name = {},
	name_by_id = {},
	meta_by_id = {},
	-- species key -> { key, label, rarity, seed_chance, block, seed, stages = { [0..2] = id } }
	species = {},
	species_order = {},
}

function M.register(name, id, meta)
	M.by_name[name] = id
	M.name_by_id[id] = name
	M.meta_by_id[id] = meta
	if meta.kind == "block" then
		local sp = M.species[meta.key] or { stages = {} }
		sp.key, sp.label, sp.rarity, sp.seed_chance = meta.key, meta.label, meta.rarity, meta.seed_chance
		sp.block, sp.color = id, meta.color
		if not M.species[meta.key] then
			M.species[meta.key] = sp
			M.species_order[#M.species_order + 1] = meta.key
		end
	elseif meta.kind == "seed" then
		local sp = M.species[meta.species] or { stages = {} }
		M.species[meta.species] = sp
		sp.seed = id
	elseif meta.kind == "shrub" then
		local sp = M.species[meta.species] or { stages = {} }
		M.species[meta.species] = sp
		sp.stages[meta.stage] = id
	end
end

-- Id for a registered name, e.g. "bp:dirt". Raises on a typo so mistakes fail loudly.
function M.id(name)
	local id = M.by_name[name]
	if not id then
		error("unknown block name: " .. tostring(name), 2)
	end
	return id
end

function M.meta(id)
	return M.meta_by_id[id]
end

function M.name(id)
	return M.name_by_id[id]
end

-- Display name for an item id.
function M.label(id)
	local m = M.meta_by_id[id]
	if m then
		return m.label
	end
	return M.name_by_id[id] or ("item " .. tostring(id))
end

return M
