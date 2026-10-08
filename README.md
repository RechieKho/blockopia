# Blockopia

A Growtopia-style game for [Voxel Browser](https://github.com/VoxelBrowser/voxel_browser), written
as a content pack in Lua.

- **Punch blocks** (discrete punches, no hold-to-break) to get the block, sometimes its **seed**,
  and **coins**. Each block sets its own seed chance; rarer blocks pay more coins.
- **Plant seeds** to grow shrubs that drop their block when ripe. The rarer the species, the longer
  it takes: `grow_scale * (R^3 + 30 R)` seconds.
- **Splice** a second seed onto a growing shrub to make a rarer species (`data/splices.lua`).
- **Worlds are names.** `!warp NAME` hashes the name to one 1024 x 1024 cell of a single big map, so
  the same name always leads to the same place.
- **Locks** claim land: small, big and huge locks are resizable squares centred on the lock; the
  **Grand Lock** claims exactly 1024 x 1024 around itself and cannot be resized. There is no world
  lock.
- **Shops:** a coin store, vending machines (only inside land you have locked) and player trades.
- **Accounts** are Keycloak accounts, signed in by the engine before you join.

## Play

```sh
# with Keycloak running (see "Sign-in"):
vb pack dev                             # host with restart-on-save and open the client

# without Keycloak (local singleplayer, nobody is verified):
.dev/tools/play_local.sh
```

Needs Voxel Browser **0.1.3** or newer (`pack.toml` enforces it). Older released builds shipped
without asset sync, so joining clients never received `ui/` or `textures/`; check that
`vb --version` lists `+asset-sync`. See `docs/ENGINE_NOTES.md`.

`play_local.sh` copies the pack without `auth.lua` to `.dev/local/` and starts singleplayer on the
copy (run it again after editing). Accounts are then keyed `dev:<player name>`.

In game: **E** opens the menu, **left click** punches, **right click** places a block / plants a seed
/ splices a seed onto a growing shrub / uses the wrench. **Chat commands** (`!help`):

| Command | What it does |
| --- | --- |
| `!warp <world>` | travel to a world (any name; new names create a world) |
| `!world` | which world you are in and who owns it |
| `!store`, `!almanac`, `!menu` | open the screens |
| `!trade <name>` / `!trade accept` | trade with another player |
| `!setspawn` | set the arrival point of a world you own |
| `!ledger`, `!mute`, `!ban`, `!unban`, `!removelock` | moderators only |

Use the **wrench** (right click) on a shrub to see its growth, on a lock to manage access, on a
vending machine to buy or manage it.

## Sign-in (Keycloak)

The pack ships an `auth.lua`, so the engine makes sign-in **mandatory**: it opens the player's
browser on the Keycloak login page and verifies the token before sending any world data. Passwords
and tokens never reach the pack.

```sh
cd ops/keycloak
cp .env.example .env        # set the two passwords
docker compose up -d        # Keycloak on http://localhost:8080, realm "blockopia" imported
```

Then register a user at `http://localhost:8080/realms/blockopia/account`. Moderators and admins are
Keycloak **groups** named `moderators` and `admins` (add a user to a group in the admin console).
For another host set `[auth] issuer` / `client_id` in `server.toml` (see `server.toml.example`).

Developing without Keycloak: use `.dev/tools/play_local.sh` (singleplayer on a copy of the pack
without `auth.lua`). Accounts are then keyed `dev:<player name>`.

## Layout

| Path | Runs in | Purpose |
| --- | --- | --- |
| `auth.lua` | engine | Keycloak settings |
| `blocks/00_items.lua` | server | registers every block from `data/items.lua` |
| `biomes/`, `worldgen.lua` | server | flat meadow world with lava pockets |
| `init.lua` | server | wires engine events to `game/*` |
| `game/*.lua` | server | rules that need the engine: accounts, farming, locks, worlds, vending, trade, ... |
| `lib/*.lua` | server | pure rules with no `vb.*`: drops, growth, splicing, world names, lock regions, ray march, trade state |
| `data/*.lua` | server | everything tunable: items, splice recipes, lock tiers, store, `balance.lua` |
| `ui/*.lua` | client UI VM | HUD and screens (cannot touch `vb`) |
| `ops/keycloak/` | - | Keycloak + Postgres compose file and realm export |
| `.dev/` | - | tests and tools (`tools/play_local.sh`); dot-directories are not loaded as pack code |
| `docs/` | - | `PLAN.md` (design), `ENGINE_NOTES.md` (engine gaps and workarounds) |

### Adding content

- **A new block/species:** append an entry to the **end** of `data/items.lua` (block ids follow
  registration order and saved worlds store ids; the pack refuses to start if an entry moved), add
  its recipe to `data/splices.lua` if it can be spliced, run `python3 .dev/tools/gen_textures.py`
  (or draw real textures into `textures/`), then the checks below.
- **Tuning:** `data/balance.lua`; run `lua .dev/tools/balance_sim.lua` to see coins per minute and
  how long the store items take to afford.

## Checks

```sh
vb pack check --json --strict           # engine lint: must be clean
python3 .dev/tests/run.py               # unit + mock-engine integration + UI render tests
lua5.4 .dev/tests/run.lua               # the same, without Python (CI)
```

The mock engine (`.dev/tests/mock_engine.lua`) imitates the engine rules the pack relies on; it is
not the engine. See `docs/ENGINE_NOTES.md` for what has and has not been verified against the real
one.
