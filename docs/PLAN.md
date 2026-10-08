# Blockopia: implementation plan

Blockopia is a Growtopia-style game built as a Voxel Browser content pack. Players punch blocks to
get blocks, seeds and coins. They plant seeds to grow shrubs, splice seeds into rarer species, claim
land with locks, sell in shops and trade, and sign in with Keycloak.

This document splits the work into phases. Each phase ships something you can play, keeps
`vb pack check` clean, and leaves later phases free to change.

---

## Implementation status

All phases below are implemented in this repository. What is verified and what is not is spelled
out in `docs/ENGINE_NOTES.md`: the pack lints clean with the real engine and the real server loads
and ticks it, but nothing has been played with a real client or Keycloak.

| Phase | Where |
| --- | --- |
| 0 Engine check | `docs/ENGINE_NOTES.md` |
| 1 Foundations | `data/items.lua`, `lib/registry.lua`, `blocks/00_items.lua`, `game/store.lua`, `game/accounts.lua`, `game/inventory.lua`, `ui/hud.lua` |
| 2 Keycloak | `auth.lua`, `ops/keycloak/`, `game/session.lua`, `game/accounts.lua` |
| 3 Breaking, drops, coins | `lib/drops.lua`, `game/breaking.lua`, `game/actions.lua`, `worldgen.lua`, `biomes/meadow.lua` |
| 4 Farming | `lib/farm.lua`, `game/farm.lua` |
| 5 Splicing | `lib/splice.lua`, `data/splices.lua`, `game/almanac.lua`, `ui/almanac.lua` |
| 6 Named worlds | `lib/worldname.lua`, `game/worlds.lua`, `ui/warp.lua` |
| 7 Locks | `lib/locks.lua`, `game/locks.lua`, `game/placing.lua`, `ui/lock.lua` |
| 8 Economy | `game/shop.lua`, `game/vending.lua`, `game/trade.lua`, `lib/market.lua`, `lib/trade.lua`, `game/ledger.lua` |
| 9 Hardening | `game/moderation.lua`, `game/ui_events.lua` (validation, rate limit), `.dev/tools/balance_sim.lua`, `.github/workflows/ci.yml` |

### Where the build differs from the plan below

- **Wrench on a player** is `!trade <name>` / `!trade accept`: the engine can only target blocks.
- **Fist** does not exist: an empty hand punches. The wrench is a normal inventory item.
- **Backpack upgrades** are not sold: the engine inventory has a fixed size.
- **Main Door / starter platform** are not built. `!setspawn` lets the owner of the lock covering a
  world's centre move its arrival point. Terrain is the same flat meadow everywhere.
- **Bedrock floor:** blocks at or below `floor_y` (1) cannot be broken or built on. A `bp:bedrock`
  block is registered but the generator does not place it.
- **Dropped items and coins:** drops use the engine's item drops (no custom entity). Coins go
  straight to the account balance.
- **Inventory:** the engine's, with a per-account snapshot because the engine does not save it.
- **Seeds can be planted only on the top face** of a block; shrubs are broken with
  `player:break_block` because the engine's punch ignores non-solid blocks.
- **Moderation:** bans apply at the next join (the engine has no kick); `!removelock` clears a lock
  without returning the item.
- **Balance:** `coin_chance` is 0.12 and the punch cooldown 0.4 s, so a small lock takes about six
  minutes of punching dirt and a grand lock about 37 hours. Terrain is endless, so mining is not
  capped; treat the numbers as a first pass.

---

## 0. Ground rules for every phase

- **Two VMs (AGENTS.md rule 1).** Game logic and all state live in the server VM. `ui/` only
  draws things and sends `ui.send_event(kind, value)`. The server validates every event: reach
  distance, rate limits, item ownership and coin balance. Never trust the client.
- **Keep logic separate from the engine.** Pure rules go in `lib/` modules that never touch `vb`:
  drop rolls, growth times, splice lookup, lock overlap tests, world-name hashing, inventory maths.
  Thin adapters in `game/` connect those modules to `vb.*` events. The pure modules can then be
  unit-tested with plain `lua5.4`, outside the engine.
- **Block ids are append-only.** All items are generated from one data table (`data/items.lua`) in
  a fixed order. You only ever add new entries at the end; you never reorder or delete them. A
  check in `lib/registry.lua` fails at load time if an existing id has moved.
- **Registration happens at top level.** `blocks/` and `entities/` read the data tables and
  register everything at load time. Nothing is registered inside an event handler.
- **Every loop:** edit → `vb pack check --json` (exit 0) → `vb pack dev`.

### Proposed layout

```
pack.toml
init.lua                  -- wires game/* modules to vb.on(...) events; loaded last
blocks/00_items.lua       -- registers every block/seed/shrub/lock from data/items.lua
auth.lua                  -- Keycloak sign-in settings read by the engine
biomes/blockopia.lua      -- Growtopia-style layers (bedrock / lava / rock / dirt)
data/items.lua            -- the item table: id order, rarity, punches, texture, kind
data/splices.lua          -- splice recipes {a, b} -> child
data/balance.lua          -- every tunable number in one place
data/locks.lua            -- lock tiers
data/store.lua            -- what the coin store sells
lib/*.lua                 -- pure logic, no vb (unit-tested)
game/*.lua                -- engine adapters: accounts, punch, farm, locks, ...
ui/*.lua                  -- HUD, warp, lock, vending, trade, store screens
textures/                 -- block, seed and shrub art
tests/*.lua               -- plain Lua tests for lib/*
ops/keycloak/             -- docker-compose + realm export for the auth server
```

`require("data.items")` loads `data/items.lua`. Only root `*.lua` files load automatically, so
files in subfolders run only when something `require`s them.

---

## Phase 0: Engine capabilities (checked)

Checked against the engine source (`VoxelBrowser/voxel_browser`, commit `3cc9104`): its Lua
reference (`docs/lua-reference/`) and auth guide (`docs/auth.md`). Run `vb pack types` to copy
the same stubs into `.vb/lua/`.

| Need                      | Engine has                                                                                       | Plan                                                                                     |
| ------------------------- | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| Break hooks               | `block_break_begin`, `block_break` (vetoable), `block_break_tick`, `block_health_tick`, per-block `on_break` | Use them. Lock protection vetoes `block_break` / `block_place`.                           |
| Punches and healing       | `max_damage` per block; `vb.combat.set_params{heal_after_seconds, heal_interval_seconds, punch_cooldown_seconds}` | Use the engine's punches and healing. No own damage table.                                |
| Drops                     | `vb.world.spawn_item_drop(pos, item, count)`; `pickup_radius`, `item_lifetime_seconds` per block | Use engine drops. Still to check in a quick test: whether the engine's own drop can be turned off. |
| Place hook                | `block_place` (vetoable), `Player:place_block`, `Player:get_held_item`                          | Use them.                                                                                |
| Inventory                 | Engine inventory: `get_inventory`, `give`, `take` (all-or-nothing), `max_stack`; `client.inventory()` in the UI | Use the engine inventory. No custom inventory.                                            |
| Persistence               | `vb.storage` (one JSON file) and `vb.db.get/set/delete` (written at once, **no key listing**)    | `vb.db` for per-account and per-object data; keep explicit index keys for listing.       |
| Wall-clock time           | **None.** Only `tick(dt)`, `vb.after`, `vb.every`                                                | Count game time from `tick` and save it. Shrubs do not grow while the server is off. Optional engine request: `vb.time()`. |
| Outbound HTTP             | **None**                                                                                         | Not needed: the engine does Keycloak sign-in itself (Phase 2).                           |
| Sign-in                   | **Built in.** `auth.lua` with `provider = "keycloak"`; `Player:get_login()` gives `{subject, name, claims}` | **Option A chosen.** See Phase 2.                                                       |
| Teleport                  | `Player:set_pos(x, y, z)` (engine 0.1.3+). A death can also return a respawn `pos`.              | Resolved: added in engine 0.1.3.                                                         |
| Kick / ban                | Vetoing `player_join` keeps an account out. The engine itself kicks a second session of the same account. | Bans keyed on `login.subject`.                                                           |
| Per-block state           | None                                                                                             | State table in `vb.db` keyed by position, plus one block id per growth stage.            |
| Entities                  | `vb.register_entity`, `vb.world.spawn`                                                           | Only for extras; drops use the engine's item drops.                                      |
| UI                        | `ui.define`, `ui.define_hud`, `ui.send_event`, `client.*`                                        | Screens as planned; chat commands as backup.                                             |
| Limits                    | 20M instructions, 250 ms and 64 MB per callback                                                  | Split big sweeps over several ticks.                                                     |

**Still to test in a quick prototype:** whether the engine's own drop on break can be turned
off, and the largest safe coordinate (for the world-name grid in Phase 6).

---

## Phase 1: Foundations: data model, persistence, accounts

**Goal:** an item registry, saved player state, and coins on the HUD.

1. **Item registry** (`data/items.lua`, `lib/registry.lua`, `blocks/00_items.lua`)
   - Item fields: `key`, `name`, `kind` (`block | seed | shrub | lock | tool | vending | ...`),
     `rarity` (1-200), `punches` (maps to `max_damage`), `texture`,
     `seed_chance` (0-1, chance the block drops its seed when broken; `0` for bedrock, locks and
     machines), `breakable`.
   - Each breakable block of rarity R automatically gets a seed item and shrub growth-stage
     blocks (for example `sapling`, `growing`, `ripe`). The order is defined by the data table, so
     it stays stable.
   - Validation at load time: keys are unique, rarity is in range, textures exist, ids have not
     moved.
2. **Persistence** (`game/store.lua`)
   - Wraps `vb.db`. Key prefixes: `account:<subject>`, `world:<name>`, `lock:<id>`,
     `shrub:<x>,<y>,<z>`, `vending:<x>,<y>,<z>`, plus `meta` (with `schema_version`, migrated on
     load).
   - `vb.db` cannot list keys, so each kind keeps an index key (for example `locks:index`, a list
     of lock ids) that is updated together with the object.
   - Saved game time (`meta.game_seconds`) is advanced from the `tick` event and saved every
     few seconds. Everything time-based (growth) uses it.
3. **Accounts** (`game/accounts.lua`)
   - `Account { subject, display_name, coins, stats, groups }`, keyed by the Keycloak `subject`
     from `player:get_login()`, never by the player name.
   - `accounts.of(player)` is the only way gameplay code finds an account.
   - Development: without `auth.lua` (`.dev/tools/play_local.sh`) `get_login()` returns `nil`;
     the accounts module then uses `dev:<player name>` as the key.
4. **Inventory and HUD** (`ui/hud.lua`)
   - Items use the engine inventory (`give`, `take`, `get_inventory`, `max_stack = 200`).
   - Coins are an account balance, not an inventory item, so they never fill a slot. The HUD
     shows them; the server sends the balance when it changes.

**Exit:** a test block can be broken and placed, coins show on the HUD, and the balance survives
a server restart. `tests/` cover registry validation.

---

## Phase 2: Accounts with Keycloak (engine sign-in, option A)

**Goal:** every player is signed in with a Keycloak account before they join. Keycloak handles
registration, passwords, email checks and 2FA; neither the pack nor the server sees a password,
and tokens never reach Lua.

**How it works:** a pack with an `auth.lua` at its root makes sign-in mandatory. When a player
connects, the game opens their system browser on the Keycloak login page. After they sign in,
the server checks the ID token before sending any world data. The pack then reads
`player:get_login()`. Rejoining later opens no browser, because the client keeps a refresh
token. Every 15 minutes the engine asks the client to prove the sign-in again, so a disabled or
signed-out account is removed within about 17 minutes.

### `auth.lua`
```lua
return {
	provider     = "keycloak",
	display_name = "Blockopia",
	issuer       = "https://<keycloak-host>/realms/blockopia",
	client_id    = "blockopia-game",
	scopes       = { "openid", "profile" },
	name_claim   = "preferred_username",
	claims       = { "groups" },
}
```
Staging and production use the same pack: `server.toml` `[auth] issuer = ...` and
`client_id = ...` override the values above.

### Keycloak setup (`ops/keycloak/`)
- `docker-compose.yml`: Keycloak + Postgres, with `realm-blockopia.json` imported on start so the
  setup can be reproduced. The server needs outbound HTTPS to Keycloak.
- Realm `blockopia`, self-registration on, `preferred_username` as the in-game name.
- Client `blockopia-game`: OpenID Connect, **client authentication off** (public, no secret in
  the pack), **standard flow on**, everything else off, redirect URI `http://127.0.0.1/*`, PKCE
  method **S256**.
- Groups `moderators` and `admins`, with a *Group Membership* mapper (claim `groups`, added to
  the ID token, full group path off). Moderator and admin powers come from
  `login.claims.groups or {}`; Keycloak leaves the claim out for a user in no group.

### Pack side (`auth.lua`, `game/accounts.lua`)
- `player_join(name, login)`: refuse banned `login.subject`s; create the account on first join.
- `login_changed`: refresh the stored display name and groups.
- Names are not unique ids: two accounts wanting `alex` become `alex` and `alex#2`. Access
  lists, trades and bans store the `subject` and only show the name.
- The engine already stops a second session of the same account.

**Exit:** you can register in Keycloak, sign in from the game, and your coins and land follow
your Keycloak account across reconnects. A Keycloak user in `moderators` gets moderator commands.

---

## Phase 3: Breaking, drops and coins

**Goal:** the core loop. You punch a block a set number of times, it breaks, and you get a
reward.

- **Punching:** the engine's `max_damage` gives each block its number of punches. Damage heals
  through `vb.combat.set_params{heal_after_seconds = 6}`, and `punch_cooldown_seconds` limits
  punch rate. The engine already checks reach.
- **Rewards** (`lib/drops.lua`, all tunable in `data/balance.lua`, with R as the rarity). Each
  roll is independent:
  - **Seed:** `p_seed = item.seed_chance`, set for each block in `data/items.lua`. Designers
    choose it per block, so a common block can still be stingy with seeds or a rare one generous.
    The registry check requires every breakable block to set it and keeps it within [0, 1].
  - **Block:** `p_block = clamp(0.25 - 0.001 * R, 0.05, 0.25)`.
  - **Coins:** with `p_coin = 0.6`, you get `floor(R / 5) + random(0, ceil(R / 10))`, at least
    1. The rarer the block, the more coins.
  - Blocks with `seed_chance = 0` (bedrock, locks, machines) never drop seeds.
- **Dropped items:** `vb.world.spawn_item_drop` spawns the block and seed drops, which anyone
  nearby picks up. Each block sets `pickup_radius` and `item_lifetime_seconds` (about 10 minutes).
- **Coins** go straight onto the breaker's balance, with a "+N coins" message.
- **Placing:** placing a block uses up one from the selected stack. The server refuses if you do
  not have the item, if the target is out of reach, or (from Phase 6) if a lock protects the
  spot.
- **Terrain** (`biomes/blockopia.lua`): bedrock floor, then a lava band, then rock, then dirt on
  top, like a Growtopia world. Every block can be broken except bedrock.

**Exit:** a fresh account can punch dirt and rock, collect seeds and coins, and build. The drop
statistics over 100k simulated breaks match `balance.lua` (test in `tests/drops_test.lua`).

---

## Phase 4: Farming (planting, growth, harvest)

- **Plant:** use a seed on the top face of a solid block with air above it. This places a shrub
  block at stage 0 and saves `shrubs[pos] = {species, planted_at, planter, spliced=false}`.
- **Growth time depends on rarity: the rarer the species, the longer it grows.**
  `grow_seconds(R) = balance.grow_scale * (R^3 + 30*R)` (Growtopia's curve). It rises steeply
  with R, so a common block such as Dirt (R=1) is ready in about 30 s, while a spliced rare
  species takes hours. `tests/farm_test.lua` checks that `grow_seconds` strictly increases with
  rarity, and `grow_scale` only stretches or shrinks the whole curve. The current stage is worked
  out from `now - planted_at`, where both use the saved game time from Phase 1, so no per-shrub
  timer runs. Shrubs do not grow while the server is off. A sweep every
  `balance.shrub_sweep_s` updates the stage block only for shrubs near online players.
- **Harvest:** punching a ripe shrub breaks it and drops
  `random(1, max(1, 5 - floor(R / 40)))` blocks of its species, plus a seed roll with the species' `seed_chance`
  and coins at half the block rate. Punching an unripe shrub destroys it and drops nothing; the
  UI warns you with a "not ripe" tooltip on the first punch.
- **Inspect:** using the Wrench on a shrub shows the species, its parents if spliced, and the
  time left.

**Exit:** the full plant → wait → harvest loop works and survives server restarts (because it
uses the saved game time).

---

## Phase 5: Splicing

- **Mechanic (Growtopia style):** use seed B on an **unripe** shrub of species A that has not
  been spliced. If `splices[{A, B}]` exists (the order of A and B does not matter), the shrub
  turns into a sapling of the child species, its timer starts again, seed B is used up, and the
  shrub is marked `spliced`. Otherwise the server answers "These seeds can't be spliced" and
  nothing is used up.
- **Recipes** (`data/splices.lua`): stored as data, and checked at load time. Both parents and
  the child must exist, each pair can appear only once, and the child's rarity must be greater
  than `max(rarity A, rarity B)`. Suggested default: `child.rarity >= rA + rB`, as in Growtopia,
  so rarer species take longer to grow and pay more.
- **Almanac** (`ui/almanac.lua`): saves which species each account has found, and shows known
  recipes and the "???" slots still undiscovered.
- **Starter content (example only, to be balanced):**

  | Parents        | Child          | Rarity |
  | -------------- | -------------- | ------ |
  | Dirt + Rock    | Gravel         | 4      |
  | Dirt + Gravel  | Grass          | 7      |
  | Rock + Lava    | Basalt         | 12     |
  | Gravel + Lava  | Glass          | 18     |
  | Grass + Glass  | Greenhouse Pane| 30     |
  | Basalt + Glass | Obsidian Tile  | 35     |

  Content then grows in tiers, with each tier needing the previous one.

**Exit:** each recipe can be done in play; the almanac fills in; the recipe check fails
`vb pack check` when a recipe is invalid.

---

## Phase 6: Named worlds as coordinates

The game runs on one continuous world, split into a grid of **1024 × 1024 cells**. Each cell is
one "world".

- **Name rules:** names are turned into uppercase `A-Z0-9`, 1-24 characters, with a blocklist.
- **Name → cell** (`lib/worldname.lua`): the FNV-1a 32-bit hash of the name picks a cell in a
  `G × G` grid centred on the origin, with G limited by the engine's safe coordinate range from
  Phase 0 (for example G = 256, so ±131k blocks). The world centre is
  `(gx * 1024 + 512, gz * 1024 + 512)`.
- **Collisions:** the first name to reach a cell claims it in a saved `worlds/` registry.
  Another name with the same hash takes the next free cell along a fixed probe sequence, so a
  name always gives the same coordinate once registered. Cell (0,0) is reserved for the hub,
  `START`.
- **Warping uses `Player:set_pos`,** added in engine 0.1.3. `game/worlds.lua` keeps a fallback for
  older engines (death with cause `warp` and a respawn position).
- **Warping:** the `!warp NAME` command and the `ui/warp.lua` screen (recent worlds, owner, lock
  status). Arrival point: the owner's **Main Door** if they set one, otherwise the highest solid
  block at the centre (found with `vb.world.raycast`), plus brief spawn protection.
- **First visit:** terrain comes from the biome; a starter platform and a Main Door are placed
  at the centre. Cells are generated only when someone visits them, since the engine creates
  chunks on demand.
- **Optional:** a thin border marker at cell edges, so players can see where one world ends.

**Exit:** `!warp FOO` always lands you at the same spot; two players warping to the same name
meet; name collisions are handled deterministically (test in `tests/worldname_test.lua`).

---

## Phase 7: Ownership with locks

There is no "world lock". Instead there are lock tiers. Every lock's area is centred on the lock
block itself. The largest one, the **Grand Lock**, always covers a fixed 1024 × 1024 area.

| Lock        | Area (X × Z, all heights)                                                       | Adjustable              | Coin price |
| ----------- | ------------------------------------------------------------------------------- | ----------------------- | ---------- |
| Small Lock  | up to 10 × 10, centred on the lock                                              | yes (smaller square)    | 50         |
| Big Lock    | up to 48 × 48, centred on the lock                                              | yes                     | 200        |
| Huge Lock   | up to 200 × 200, centred on the lock                                            | yes                     | 500        |
| Grand Lock  | **exactly 1024 × 1024, centred on the lock**                                    | **no**                  | ~20,000    |

All values live in `data/locks.lua` and are tunable.

- **Regions:** axis-aligned boxes in X and Z covering every height. A spatial index uses
  1024-sized buckets (each lock touches at most 4 buckets), so the protection check is a
  constant-time bucket lookup followed by a box test. A lock's area does not follow world-cell
  borders: a Grand Lock usually spans parts of up to four named-world cells.
- **Placement rules:**
  - A new region may not overlap any region owned by someone else.
  - A Grand Lock needs its full 1024 × 1024 area to be free of foreign locks. Before placing,
    the client shows the outline and any lock that would block it.
  - Inside your own Grand Lock you may place smaller locks to give out sub-areas. The innermost
    lock decides access, but the Grand Lock owner keeps admin rights.
  - Inside someone else's lock, only its owner and its admins may place locks.
- **Access:**
  - Each lock has an owner, an `admins` list and a `builders` list (account ids, chosen by
    display name), a "public build" toggle, and an optional "no drops for visitors" toggle.
  - Guarded actions: breaking, placing, planting, splicing, harvesting, wrenching machines, and
    picking up drops (optional).
- **Lock UI** (`ui/lock.lua`): opened by using the Wrench on a lock. Edit lists, toggles and the
  size (except for the Grand Lock); shows the region outline.
- **Removing a lock:** only the owner can break their lock, and only once no foreign sub-locks
  are left inside it. The lock item goes back to the owner.
- Whoever owns the lock covering a world's centre is shown as that world's owner on the warp
  screen and can set its Main Door.

**Exit:** non-members cannot change a locked area; overlap and nesting rules are enforced
(`tests/locks_test.lua`); locks survive restarts.

---

## Phase 8: Economy: store, shops and trading

Locks are what make shops possible: only a player who owns land can run a shop on it.

- **Coin store** (`ui/store.lua`, `data/store.lua`): buy locks, backpack upgrades, and "seed
  packs" (random low-rarity seeds). This is the main way coins leave the game.
- **Vending machine** (a placeable block):
  - Can only be placed inside a region where you are owner or admin.
  - The owner stocks one item type and sets a price as *N coins per item* or *1 coin per N
    items*. Buyers use the Wrench, choose a quantity, and confirm.
  - A purchase is one atomic server transaction: check stock and the buyer's coins → move the
    items → move the coins into the machine's till → save. The owner collects the till.
  - Breaking a machine needs it to be empty, or it returns its stock and till to the owner.
- **Display box:** shows an item in a locked area, a shop-window prop with no transaction.
- **Player trade** (`ui/trade.lua`):
  - Started by wrenching a player.
  - Both players add items and coins, both press **Accept**, then both must **Confirm** within
    a short window.
  - Any change resets both accepts. The swap is atomic on the server and saved straight away.
- **Safeguards:** total coins in the game are tracked as a metric. Every coin and item transfer
  goes through `game/ledger.lua`, which writes an append-only audit log for moderators.

**Exit:** a player can buy a lock, claim land, set up a vending machine, and sell to another
player. Trades cannot duplicate items, even when a player disconnects mid-trade (tested).

---

## Phase 9: Hardening, balance and operations

- **Anti-cheat:** server-side reach, punch rate and placement rate checks. Trust nothing from
  `ui.send_event`, and validate every field's type.
- **Moderation:** `bp-moderator` / `bp-admin` commands (mute, kick, ban by Keycloak `sub`, view
  the ledger, remove abandoned locks).
- **Balance:**
  - A simulation script in `tests/` that models coins earned per hour against store prices.
  - Tune `grow_scale`, the drop formulas and lock prices.
  - A content pass covering about 50 species in tiers.
- **Performance:**
  - Profile callbacks against the per-callback instruction budget.
  - Batch the shrub sweeps and save flushes.
  - Limit the number of drop entities per chunk.
- **Operations:**
  - Back up `storage.json`/`db/` and the Keycloak Postgres database.
  - Pin `engine_version_req` to the tested engine version.
  - CI runs `vb pack check --json --strict` and the plain-Lua tests on every push.
- **Docs:** update `README.md` with how to play and how to run the server and Keycloak.

---

## Order of work and dependencies

```
P0 (done) ─► P1 foundations ──► P3 punch/drops ──► P4 farming ──► P5 splicing
                 │                    │
                 ├──► P2 Keycloak     └──► P6 worlds ──► P7 locks ──► P8 economy ──► P9
                 │    (in parallel; development runs without auth.lua)
                 └──► engine: Player:set_pos (done in 0.1.3)
```

P2 is small now that the engine signs players in, and can run alongside P3-P6. It must be
finished before any public server and before P8, because real currency needs real identities.

## Decisions to confirm

1. **Growth speed:** growth time rises with rarity using the Growtopia curve; playtesting decides
   the overall `grow_scale` multiplier.
2. **Growth while the server is off:** the engine has no clock, so shrubs pause while the server
   is down. Adding `vb.time()` to the engine would let them keep growing.
