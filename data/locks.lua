-- Lock tiers. A lock claims a square of `size` x `size` blocks (all heights) centred on the lock
-- block. `adjustable` locks may be shrunk to any smaller size from the lock screen; the grand
-- lock is always exactly 1024 x 1024.
return {
	small = { name = "Small Lock", size = 10, adjustable = true, price = 50, color = { 120, 190, 120 } },
	big = { name = "Big Lock", size = 48, adjustable = true, price = 200, color = { 90, 150, 220 } },
	huge = { name = "Huge Lock", size = 200, adjustable = true, price = 500, color = { 170, 100, 220 } },
	grand = { name = "Grand Lock", size = 1024, adjustable = false, price = 20000, color = { 240, 190, 40 } },
	-- Order used by the store and the lock screen.
	order = { "small", "big", "huge", "grand" },
}
