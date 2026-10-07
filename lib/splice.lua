-- Splice recipe lookup and validation. Pure.
local M = {}

function M.pair_key(a, b)
	if a > b then
		a, b = b, a
	end
	return a .. "+" .. b
end

-- recipes: array of { a, b, child }. Returns a map pair_key -> child key.
function M.build(recipes)
	local map = {}
	for _, r in ipairs(recipes) do
		map[M.pair_key(r[1], r[2])] = r[3]
	end
	return map
end

function M.lookup(map, a, b)
	return map[M.pair_key(a, b)]
end

-- species: map key -> { rarity }. Returns an array of error strings.
function M.validate(recipes, species)
	local errors = {}
	local seen = {}
	for i, r in ipairs(recipes) do
		local a, b, c = species[r[1]], species[r[2]], species[r[3]]
		if not a or not b or not c then
			errors[#errors + 1] = string.format("recipe %d uses an unknown species (%s + %s -> %s)",
				i, tostring(r[1]), tostring(r[2]), tostring(r[3]))
		else
			if c.rarity < a.rarity + b.rarity then
				errors[#errors + 1] = string.format("recipe %d: %s must have rarity >= %d (has %d)",
					i, r[3], a.rarity + b.rarity, c.rarity)
			end
			local key = M.pair_key(r[1], r[2])
			if seen[key] then
				errors[#errors + 1] = string.format("recipe %d repeats the pair %s", i, key)
			end
			seen[key] = true
		end
	end
	return errors
end

return M
