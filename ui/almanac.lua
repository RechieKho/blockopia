-- bp:almanac -- species found so far and the splice recipes discovered.
ui.define("bp:almanac", function(state)
	local species, recipes = state.species or {}, state.recipes or {}
	local rows = math.max(#species, #recipes)
	local widgets, x, y, k = bp_ui.window("Almanac", 760, 110 + rows * 26)
	bp_ui.close_button(widgets, x, y, math.floor(760 * k), k)
	bp_ui.label(widgets, "h1", x + math.floor(16 * k), y + math.floor(46 * k), k, "Species  (rarity, grow time, seed chance)", bp_ui.title, 15)
	bp_ui.label(widgets, "h2", x + math.floor(430 * k), y + math.floor(46 * k), k, "Splice recipes found", bp_ui.title, 15)
	for i, sp in ipairs(species) do
		local text
		if sp.found then
			text = string.format("%s  (R%d, %s, %d%%)", sp.name, sp.rarity, sp.grow, sp.seed_chance)
		else
			text = string.format("???  (R%d)", sp.rarity)
		end
		bp_ui.label(widgets, "sp_" .. i, x + math.floor(16 * k), y + math.floor((74 + (i - 1) * 26) * k), k, text,
			sp.found and bp_ui.text or bp_ui.muted, 15)
	end
	for i, line in ipairs(recipes) do
		bp_ui.label(widgets, "rc_" .. i, x + math.floor(430 * k), y + math.floor((74 + (i - 1) * 26) * k), k, line, bp_ui.good, 15)
	end
	if #recipes == 0 then
		bp_ui.label(widgets, "rc_none", x + math.floor(430 * k), y + math.floor(74 * k), k, "None yet. Plant a seed, then use a different seed on it.", bp_ui.muted, 14)
	end
	return { widgets = widgets }
end)
