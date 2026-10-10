# Blockopia

A Growtopia-style game for [Voxel Browser](https://github.com/VoxelBrowser/voxel_browser), written
as a content pack in Lua.

- **Punch blocks** (discrete punches, no hold-to-break) to get the block, sometimes its **seed**,
  and **coins**. Each block sets its own seed chance; rarer blocks pay more coins.
- **Plant seeds** to grow shrubs that drop their block when ripe. The rarer the species, the longer
  it takes: `grow_scale * (R^3 + 30 R)` seconds.
- **Splice** a second seed onto a growing shrub to make a rarer species (`data/splices.lua`).
- **Worlds are names.** `!warp NAME` hashes the name to one 256 x 256 cell of a 64 x 64 grid
  (4096 worlds, all within ±8192 blocks of the origin), so the same name always leads to the same
  place. Terrain is rolling hills of grass or sand over dirt and rock.
- **Locks** claim land: small, big and huge locks are resizable squares centred on the lock; the
  **Grand Lock** claims exactly one world's size (256 x 256) around itself and cannot be resized. There is no world
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

Needs Voxel Browser **0.1.5** or newer (`pack.toml` enforces it): earlier releases lack asset sync
in release builds (0.1.2), break cold joins once the pack writes `vb.db` (0.1.3), and lose the
player's name on leave, crash when a screen closes itself and draw see-through textures with holes
(0.1.4). See `docs/ENGINE_NOTES.md`.

Since 0.1.5, `vb pack dev` and `vb host --pack .` keep a world per pack
(`<vb data>/servers/default/worlds/blockopia-<hash>/`), and a server refuses a world saved by
another pack's blocks. A world saved by an older engine is accepted and recorded as it is: if you
see another pack's untextured terrain or old flat ground around spawn, delete that world folder.

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
vending machine to buy or manage it. Placing, wrenching or resizing a lock marks its area with posts
in the lock's colour for 20 seconds. While you hold a lock, a ring of posts previews the area it
would claim where you aim: in its colour if it can go there, red if not, with the other players'
locks in the way shown too.

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

## Deploy (Docker)

`ops/deploy/` runs a public server on one host: the game server (Voxel Browser built from source at
a pinned tag, with this pack), Keycloak and Postgres for sign-in, and Caddy giving Keycloak HTTPS
with a Let's Encrypt certificate (the engine only accepts an `https` issuer).

```sh
cd ops/deploy
cp .env.example .env          # AUTH_DOMAIN, ACME_EMAIL, passwords, port, MOTD
docker compose up -d --build  # the first build compiles the engine (~10-20 minutes)
docker compose logs -f game
```

- **DNS and firewall:** `AUTH_DOMAIN` must resolve to the host; open 80/tcp, 443/tcp and the game
  port (`GAME_PORT`, UDP, default 7777).
- **Players** register at `https://AUTH_DOMAIN/realms/blockopia/account` and connect to
  `HOST:7777`. Moderators/admins: Keycloak groups `moderators` / `admins` (admin console at
  `https://AUTH_DOMAIN/admin`).
- **Data:** the `game-data` volume holds the world and the pack's `vb.db`/`vb.storage`
  (accounts, locks, worlds); the pack itself is refreshed from the image on every start, so
  `git pull && docker compose up -d --build` updates the game without touching the data. Back up
  with `docker run --rm -v blockopia_game-data:/data -v "$PWD":/backup ubuntu tar czf /backup/game-data.tgz /data`.
- **Engine version:** `VB_VERSION` in `.env` (a tag of the engine repository; it must satisfy
  `pack.toml`).
- `BLOCKOPIA_NO_AUTH=1` runs without sign-in (anyone can join as anyone): LAN or testing only.
  Start just the game then: `docker compose up -d --build --no-deps game` (the sign-in settings
  can keep their example values).

## Layout

| Path | Runs in | Purpose |
| --- | --- | --- |
| `auth.lua` | engine | Keycloak settings |
| `blocks/00_items.lua` | server | registers every block from `data/items.lua` |
| `biomes/`, `worldgen.lua` | server | rolling hills (meadow and dunes biomes), lava, gravel and clay pockets |
| `init.lua` | server | wires engine events to `game/*` |
| `game/*.lua` | server | rules that need the engine: accounts, farming, locks, worlds, vending, trade, ... |
| `lib/*.lua` | server | pure rules with no `vb.*`: drops, growth, splicing, world names, lock regions, ray march, trade state |
| `data/*.lua` | server | everything tunable: items, splice recipes, lock tiers, store, `balance.lua` |
| `ui/*.lua` | client UI VM | HUD and screens (cannot touch `vb`) |
| `ops/keycloak/` | - | Keycloak + Postgres compose file and realm export (local development) |
| `ops/deploy/` | - | Docker Compose deployment: game server image, Keycloak, Postgres, Caddy (HTTPS) |
| `.dev/` | - | tests and tools (`tools/play_local.sh`, `tools/e2e_join.py`); dot-directories are not loaded as pack code |
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
