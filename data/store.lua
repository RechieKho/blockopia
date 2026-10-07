-- What the coin store sells. kind = "lock" sells a lock tier at its data/locks.lua price;
-- kind = "item" gives `count` of the named block/item;
-- kind = "seedpack" gives `count` random seeds of species with rarity <= max_rarity.
return {
	{ id = "lock_small", kind = "lock", tier = "small" },
	{ id = "lock_big", kind = "lock", tier = "big" },
	{ id = "lock_huge", kind = "lock", tier = "huge" },
	{ id = "lock_grand", kind = "lock", tier = "grand" },
	{ id = "vending", kind = "item", name = "Vending Machine", item = "bp:vending", count = 1, price = 100 },
	{ id = "seedpack", kind = "seedpack", name = "Seed Pack (5 random seeds)", count = 5, max_rarity = 8, price = 40 },
	{ id = "wrench", kind = "item", name = "Spare Wrench", item = "bp:wrench", count = 1, price = 5 },
}
