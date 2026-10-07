-- Every tunable number in one place. Pure data: no vb.* calls, so tests can load it.
return {
	-- Punching (vb.combat)
	punch_cooldown_seconds = 0.4,
	heal_after_seconds = 6.0,
	heal_interval_seconds = 1.0,
	reach = 6.0,

	-- Rewards when a block breaks. R is the block's rarity.
	-- block: clamp(block_base - block_slope * R, block_min, block_max)
	block_base = 0.25,
	block_slope = 0.001,
	block_min = 0.05,
	block_max = 0.25,
	-- coins: with probability coin_chance, floor(R / coin_div) + random(0, ceil(R / coin_spread)), at least 1
	coin_chance = 0.12,
	coin_div = 5,
	coin_spread = 10,
	-- A harvested shrub pays coins at this fraction of the normal rate.
	harvest_coin_factor = 0.5,

	-- Farming. grow_seconds(R) = grow_scale * (R^3 + 30 * R): rarer species take longer.
	grow_scale = 1.0,
	-- Fractions of the total growth time at which the shrub changes stage.
	stage_growing_at = 1 / 3,
	shrub_sweep_seconds = 5.0,
	-- Shrubs are only re-staged while a player is within this many blocks.
	shrub_sweep_radius = 96,
	-- Harvest yield: random(1, max(1, harvest_base - floor(R / harvest_div)))
	harvest_base = 5,
	harvest_div = 40,

	-- Persistence
	game_clock_save_seconds = 10.0,
	inventory_save_seconds = 30.0,

	-- Worlds: a G x G grid of 1024 x 1024 cells centred on the origin.
	world_cell_size = 1024,
	world_grid = 256,
	world_name_max = 24,
	world_ground_y = 64,
	-- Players warp in at this height and fall onto the ground.
	world_spawn_y = 100,
	hub_name = "START",
	-- Blocks at or below this height cannot be broken (stands in for a bedrock floor).
	floor_y = 1,

	-- Accounts
	start_coins = 100,
	start_items = { { "bp:wrench", 1 }, { "bp:dirt", 8 }, { "bp:dirt_seed", 3 } },
	-- UI event rate limit per player (events per second, burst).
	ui_rate = 12,
	ui_burst = 24,

	-- Trading / vending
	trade_confirm_seconds = 30,
	max_item_stack = 200,
	max_vending_price = 1000000,
	ledger_keep = 2000,

	lava_damage = 8,
}
