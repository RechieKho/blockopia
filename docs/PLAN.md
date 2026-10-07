# Blockopia: implementation plan

Blockopia is a Growtopia-style game built as a Voxel Browser content pack. Players punch blocks to
get blocks, seeds and coins. They plant seeds to grow shrubs, splice seeds into rarer species, claim
land with locks, sell in shops and trade, and sign in with Keycloak.

This document splits the work into phases. Each phase ships something you can play, keeps
`vb pack check` clean, and leaves later phases free to change.

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
entities/drop.lua         -- floating dropped-item entity
biomes/blockopia.lua      -- Growtopia-style layers (bedrock / lava / rock / dirt)
data/items.lua            -- the item table: id order, rarity, punches, texture, kind
data/splices.lua          -- splice recipes {a, b} -> child
data/balance.lua          -- every tunable number in one place
data/locks.lua            -- lock tiers
data/store.lua            -- what the coin store sells
lib/*.lua                 -- pure logic, no vb (unit-tested)
game/*.lua                -- engine adapters: accounts, auth, inventory, punch, farm, locks, ...
ui/*.lua                  -- HUD, inventory, sign-in, warp, lock, vending, trade, store screens
textures/                 -- block, seed and shrub art
tests/*.lua               -- plain Lua tests for lib/*
ops/keycloak/             -- docker-compose + realm export for the auth server
```

`require("data.items")` loads `data/items.lua`. Only root `*.lua` files load automatically, so
files in subfolders run only when something `require`s them.

---

## Phase 0: Engine capability spike (gate)

There are no `vb` CLI or `.vb/lua` stubs in this repo yet. Before writing any gameplay, run
`vb pack types` and use the stubs and `vb docs` to fill in this table. Each question has a
fallback if the answer is no.

| Need                                     | Question to verify                                                       | Fallback if missing                                                   |
| ---------------------------------------- | ------------------------------------------------------------------------ | --------------------------------------------------------------------- |
| Punch / break hooks                      | Is there a cancellable `block_break` / `block_damage` event that gives the player and position? | Required. Ask for an engine feature.                                    |
| Custom drops                             | Can I turn off default drops and spawn my own?                            | Put drops straight into the inventory.                                |
| Place hook                               | Is there a cancellable `block_place` event that says which item was placed? | Placement from a custom UI hotbar plus `vb.world.raycast`.             |
| Engine inventory                         | Does the engine have an inventory or hotbar I can control?                | Own inventory (Phase 1) with a HUD hotbar.                            |
| Persistence                              | Is there a storage/db API? (`.gitignore` lists `storage.json` and `db/`.)  | Required.                                                             |
| Wall-clock time                          | `os` is removed. Is there a server Unix-time function?                    | Count game ticks and save an offset (growth pauses while the server is down). |
| Timers                                   | Repeating timers or a tick event?                                         | Required.                                                             |
| Outbound HTTP (server VM)                | Is there an HTTP client, and can I allowlist hosts?                       | See the Phase 2 fallback. This is the biggest risk.                   |
| `player_join(name, login)`               | What is `login`? Does the engine already have pluggable or OIDC auth?     | Device flow in Phase 2.                                               |
| Teleport, freeze, kick                   | `player:set_pos`, a movement lock, `player:kick`?                         | Freeze by teleporting guests back each tick.                          |
| World bounds / float precision           | Largest safe coordinate?                                                  | Shrink the world-name grid (Phase 5).                                 |
| Per-block state                          | Is there block metadata?                                                  | Store a state table keyed by position, plus one block id per growth stage. |
| Entities                                 | Custom entity with a texture, a pickup radius and despawn?               | Put drops straight into the inventory.                                |
| UI                                       | Text input, lists, buttons, QR or image widgets?                          | Chat commands (`!warp NAME`, ...).                                    |

**Deliverables:** `docs/ENGINE_NOTES.md` with the filled-in table, plus a throwaway branch with a
proof of concept for each yes/no. **Exit criteria:** every "Required" row says yes, and the
Keycloak path is chosen (A, B or C in Phase 2).

---

## Phase 1: Foundations: data model, persistence, accounts interface, inventory

**Goal:** a typed item registry, saved player state, and an inventory with a HUD. No real auth
yet: an `AccountProvider` interface with a **dev provider** (account id = player name) so later
phases can be built and tested before Keycloak is ready.

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
   - Wraps the engine storage. Namespaces: `accounts/<id>`, `worlds/`, `locks/`, `shrubs/`,
     `vending/`, `meta` (with `schema_version`, migrated on load).
   - In-memory cache, marked dirty on change, flushed on a timer and when a player leaves or the
     server shuts down.
3. **Accounts** (`game/accounts.lua`)
   - `Account { id, display_name, coins, inventory, backpack_slots, stats, roles }`.
   - `session[player] -> account_id`. Gameplay code asks `accounts.of(player)` and never sees the
     player name, so swapping in Keycloak later changes only the provider.
4. **Inventory** (`lib/inventory.lua`, `game/inventory.lua`, `ui/hud.lua`, `ui/inventory.lua`)
   - Slots with stacks of up to 200. Starts with 16 slots; upgrades are bought with coins (a coin
     sink).
   - The Fist and the Wrench are always present and cannot be dropped.
   - The server pushes inventory diffs to the client UI. The client sends `select_slot`,
     `drop_item`, `trash_item`.

**Exit:** items show up in the inventory, survive a server restart, and the HUD shows coins and
the hotbar. `tests/` cover inventory maths and registry validation.

---

## Phase 2: Accounts with Keycloak

**Goal:** every gameplay action needs a signed-in Keycloak account. Keycloak handles
registration, passwords, email checks and 2FA; the pack never sees a password.

### Keycloak setup (`ops/keycloak/`)
- `docker-compose.yml`: Keycloak + Postgres. `realm-blockopia.json` is imported on start so the
  setup can be reproduced.
- Realm `blockopia`; user self-registration on; `preferred_username` unique and used as the
  in-game display name.
- Client `blockopia-game`: **public** client, with **OAuth 2.0 Device Authorization Grant** on
  and the standard and implicit flows off. A public client needs no secret, so nothing secret
  ships in the pack.
- Realm roles `bp-moderator` and `bp-admin` map to in-game permissions (kick, mute, inspecting
  or removing locks).

### Integration path (picked in Phase 0)
- **A. Engine-native OIDC (preferred, if `login` in `player_join` supports it):** the engine
  checks the Keycloak token when the player connects and gives the pack a verified `sub`. The
  pack only maps `sub` to an account.
- **B. Device flow from the server VM (needs outbound HTTP):**
  1. A player joins as a **guest**. Guests are frozen at the hub spawn, cannot punch or place,
     and the sign-in screen opens (`player:open_ui("signin", ctx)`).
  2. The server POSTs `.../protocol/openid-connect/auth/device` and gets `user_code` and
     `verification_uri_complete`. The UI shows the code and URL (and a QR code if the UI can draw
     images).
  3. A server timer polls the token endpoint at the `interval` Keycloak returns, handling
     `authorization_pending`, `slow_down` and `expired_token`.
  4. On success the server calls `userinfo` with the access token, which gives `sub`,
     `preferred_username` and roles. That call checks the token, so the server never needs to
     verify a JWT signature in Lua.
  5. The server binds the session to an account, creating it on first sign-in. Tokens are thrown
     away; nothing is stored on disk.
- **C. Neither is available:** an engine change is needed, either a server-only, allowlisted
  `vb.http` or native OIDC. A sidecar service alone is not enough, because the sandbox has no
  `io` or socket to talk to it. Raise this with the engine first. It blocks Phase 2 but not
  Phases 3-8, which keep running on the dev provider.

### Rules
- One live session per account: signing in again kicks the older session.
- The dev provider stays available only behind a `pack.toml`/server config flag that is off by
  default.
- Rate-limit sign-in attempts for each connection.

**Exit:** you can register in Keycloak, sign in from the game, and your inventory follows your
Keycloak account across player names and reconnects. A guest cannot change the world.

---

## Phase 3: Breaking, drops and coins

**Goal:** the core loop. You punch a block a set number of times, it breaks, and you get a
reward.

- **Punching:** the engine's `max_damage` gives each block its number of punches. Damage heals if
  you stop punching for `balance.heal_seconds` (about 6 s). Use the engine's healing if it has
  it; otherwise keep a `damage[pos] = {hits, last_hit}` table. The server limits punch rate and
  reach for each player.
- **Rewards** (`lib/drops.lua`, all tunable in `data/balance.lua`, with R as the rarity). Each
  roll is independent:
  - **Seed:** `p_seed = item.seed_chance`, set for each block in `data/items.lua`. Designers
    choose it per block, so a common block can still be stingy with seeds or a rare one generous.
    The registry check requires every breakable block to set it and keeps it within [0, 1].
  - **Block:** `p_block = clamp(0.25 - 0.001 * R, 0.05, 0.25)`.
  - **Coins:** with `p_coin = 0.6`, you get `floor(R / 5) + random(0, ceil(R / 10))`, at least
    1. The rarer the block, the more coins.
  - Blocks with `seed_chance = 0` (bedrock, locks, machines) never drop seeds.
- **Dropped items** (`entities/drop.lua`): a small spinning item, picked up by anyone within
  about 1.5 blocks, merged with matching nearby drops, and removed after 10 minutes. Coins drop
  as a coin entity. If the engine has no custom entities, rewards go straight into the
  inventory.
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
  out from `now - planted_at`, so no per-shrub timer runs. A sweep every
  `balance.shrub_sweep_s` updates the stage block only for shrubs near online players.
- **Harvest:** punching a ripe shrub breaks it and drops
  `random(1, max(1, 5 - floor(R / 40)))` blocks of its species, plus a seed roll with the species' `seed_chance`
  and coins at half the block rate. Punching an unripe shrub destroys it and drops nothing; the
  UI warns you with a "not ripe" tooltip on the first punch.
- **Inspect:** using the Wrench on a shrub shows the species, its parents if spliced, and the
  time left.

**Exit:** the full plant → wait → harvest loop works and survives server restarts (because it
uses saved wall-clock timestamps).

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
P0 spike ──► P1 foundations ──► P3 punch/drops ──► P4 farming ──► P5 splicing
                 │                    │
                 ├──► P2 Keycloak     └──► P6 worlds ──► P7 locks ──► P8 economy ──► P9
                 │    (in parallel; uses the dev provider until it lands)
```

P2 can run alongside P3-P6 because all gameplay goes through the `AccountProvider` interface.
P2 must be finished before any public server and before P8, because real currency needs real
identities.

## Decisions to confirm

1. **Growth speed:** growth time rises with rarity using the Growtopia curve; playtesting decides
   the overall `grow_scale` multiplier.
2. **Keycloak path (A/B/C):** decided by the Phase 0 findings on the engine's auth and HTTP
   support.
