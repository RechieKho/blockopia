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
	-- clothing (game/wardrobe.lua): right click while holding it to put it on or take it off
	{ id = "red_cap", kind = "item", name = "Red Cap", item = "bp:red_cap", count = 1, price = 30 },
	{ id = "blue_cap", kind = "item", name = "Blue Cap", item = "bp:blue_cap", count = 1, price = 30 },
	{ id = "straw_hat", kind = "item", name = "Straw Hat", item = "bp:straw_hat", count = 1, price = 60 },
	{ id = "red_shirt", kind = "item", name = "Red Shirt", item = "bp:red_shirt", count = 1, price = 40 },
	{ id = "green_shirt", kind = "item", name = "Green Shirt", item = "bp:green_shirt", count = 1, price = 40 },
	{ id = "yellow_shirt", kind = "item", name = "Yellow Shirt", item = "bp:yellow_shirt", count = 1, price = 40 },
	{ id = "jeans", kind = "item", name = "Jeans", item = "bp:jeans", count = 1, price = 40 },
	{ id = "brown_trousers", kind = "item", name = "Brown Trousers", item = "bp:brown_trousers", count = 1, price = 40 },
	{ id = "purple_cape", kind = "item", name = "Purple Cape", item = "bp:purple_cape", count = 1, price = 150 },
	{ id = "red_cape", kind = "item", name = "Red Cape", item = "bp:red_cape", count = 1, price = 150 },
}
