-- Splice recipes: { parent_a, parent_b, child } by species key. Order of the parents does not
-- matter. lib/splice.lua checks at load time that every key exists, every unordered pair appears
-- once, and the child is rarer than both parents (child.rarity >= rarity_a + rarity_b).
return {
	{ "dirt", "rock", "gravel" },
	{ "dirt", "gravel", "grass" },
	{ "rock", "gravel", "sand" },
	{ "dirt", "sand", "clay" },
	{ "grass", "gravel", "wood" },
	{ "sand", "gravel", "glass" },
	{ "rock", "clay", "brick" },
	{ "wood", "gravel", "planks" },
	{ "rock", "planks", "marble" },
	{ "glass", "brick", "obsidian" },
	{ "marble", "obsidian", "gold" },
	{ "gold", "glass", "crystal" },
}
