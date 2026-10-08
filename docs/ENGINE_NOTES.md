# Engine notes

What Blockopia needs from the Voxel Browser engine, what was verified, and where the pack works
around a gap. Required engine: **0.1.5** (`pack.toml`). Last checked against `1c77229` (`v0.1.5`),
built locally with networking, asset sync and the engine's e2e automation harness.

## Verified against the real engine

- `vb pack check --json --strict` is clean: the whole pack loads (86 blocks), the Lua sandbox lint
  passes, and no `vb.*` call appears in `ui/` or the reverse.
- The real server starts with the pack, runs 400 ticks without script
  errors, and persists `vb.storage.block_order`.
- End to end on 0.1.5 (`.dev/tools/e2e_join.py`: a real server and real headless clients over UDP):
  a cold-cache client joins after the pack has written `vb.db`, receives `ui/` and textures and no
  `db/` files; the HUD shows coins; `!world` answers in chat; `!menu`, `!store` and `!almanac` open;
  breaking grass and dirt drops the block and its seed, which are picked up by walking onto them;
  `!warp` teleports with `set_pos` to a new world in another cell, whose chunks load and whose
  ground is generated terrain; a second cold-cache client joins later. A windowed client under Xvfb
  draws the textured ground, HUD, hotbar and chat after the warp.
- API shapes the pack calls were read from the engine source: `player:punch/break_block/place_block`,
  `give/take/get_inventory/get_held_item`, `player_death` decisions (`heal`, `pos`, `message`),
  `ui_event(player, ui_name, widget_id, kind, value)` with `kind` = the string passed to
  `ui.send_event`, `on_break/on_place` callbacks receiving `{ pos, player }`, `block_break` /
  `block_place` vetoes, `region_enter`, punch healing through `vb.combat.set_params`.

## NOT verified yet

The e2e run uses a copy of the pack without `auth.lua`. Still untested in a real session:

1. Joining with Keycloak (`auth.lua`), including `login.claims.groups`.
2. Punching, splicing and harvesting shrubs (walk-through blocks) in a real session; they render correctly.
3. HUD layout at larger window sizes (only checked at 720 x 360).
4. The hidden-chat-line HUD channel (below) under heavy chat.

## Fixed in engine 0.1.3 to 0.1.5

- **Asset sync in release builds.** 0.1.2 release builds were compiled without
  `VB_WITH_COMPRESSION`, so the server skipped asset sync without a word and joining clients got
  no `ui/*.lua` or textures: `ui.open: 'bp:menu' was never defined via ui.define`, no HUD (so no
  chat or hotbar) and white blocks. 0.1.3 builds with it, `--version` lists `+asset-sync`, and the
  server warns at startup when asset sync is off.
- **Client asset cache.** Files with identical bytes under different paths no longer fail a cold
  join, and the reconnect fast path no longer empties the client's files.
- **`Player:set_pos(x, y, z)`** exists; `!warp` uses it (the old death-and-respawn workaround is
  gone). Also new: `Player:get_spawn_pos()`.
- **0.1.4: runtime state kept out of the asset manifest.** 0.1.3 served `db/` (`vb.db`) and
  `storage.json` as pack assets: every client could download the server's database, and after the
  pack's first `vb.db` write (the game clock, every 10 s) the manifest was stale, so later
  cold-cache joins failed with "asset transfer failed (hash mismatch or size cap)". 0.1.4 excludes
  `db/`, `storage.json` and the world directory, and re-hashes files before serving them.
- **0.1.5: what the pack asked for.** A world per hosted pack, and saves that record their blocks
  (a mismatched pack is refused instead of loading another pack's terrain untextured); alpha
  cutout for clear texels; `ui.close{ capture_mouse = true }` (every Close/OK button and the warp
  loading screen use it, through `bp_ui.back_to_game`); `ui.close()` from a screen's own render
  (the loading screen closes itself again, the HUD command line is gone); `player_leave` handles
  that keep the player's name (the pack's "find who left" fallback is gone). Shrubs keep their
  opaque bush textures: they read well and avoid depending on the cutout.

## Gaps and workarounds

| Gap | Effect | Workaround in the pack | Engine change that would remove it |
| --- | --- | --- | --- |
| No server -> HUD data channel | coins/world could not be shown | `game/hud.lua` sends a hidden private chat line (`@@bp\|coins=..\|world=..`) every 3 s and on change; `ui/hud.lua` parses and hides it; chat lines starting with the marker are vetoed so players cannot forge it | `Player:set_hud_state(table)` readable from `ui.define_hud` |
| No wall-clock time (`os` removed) | shrubs only grow while the server runs | `game/store.lua` keeps a game clock advanced by `tick`, saved every 10 s | `vb.time()` (Unix seconds) |
| `vb.db` cannot list keys | records need indexes | `game/store.lua` collections (bucketed by 64x64 columns) and `idx:*` keys | `vb.db.keys(prefix)` |
| Inventories are not saved | items vanish on leave | `game/accounts.lua` snapshots the inventory per account (on leave, every 30 s) and restores it on the first input | engine-side per-account inventory persistence |
| No "joined" event with a `Player` handle | cannot set up a player at join | the first `player_input` after `player_join` marks the player ready | `player_join_completed(player)` event |
| No kick | bans only apply at the next join | `player_join` veto on banned `login.subject` | `Player:kick(reason)` (`Player:remove()` is a logged no-op) |
| `vb.world.raycast` and `Player:punch` only hit **solid** blocks | shrubs (walk-through) could not be punched, wrenched or spliced | `lib/ray.lua` marches the ray in Lua; shrubs are broken with `player:break_block`, everything else with `player:punch` | a `raycast` option to include non-solid blocks |
| `vb pack check` lints every `.lua` under the pack | tests/tools using `io`/`os` raise errors | tests and tools live in `.dev/`; dot-directories are skipped | an ignore list in `pack.toml` |
| Rendering uses float coordinates far from the origin | blocks jittered near ±131 000 (the first map) | the map is 64 x 64 worlds of 256 blocks, so everything stays within ±8192 | camera-relative rendering |
| Custom keybinds (E, Esc) are sent while the chat box or a text field is open | typing "e" opens the menu | every screen opens through `ui_events.open`, so the server ignores E while one of our screens is open (until its `close` event); `ui/hud.lua` reports `client.chat_open()` changes as a `hud_chat` event, so E is also ignored while the chat box is open (still needed on 0.1.5) | gate `kCustomKeybinds` in `sample_input_cmd` on the chat box / focused text field |
| Block placement needs a solid neighbour | cannot place in mid-air | by design (Growtopia-like building) | - |

## Notes on engine behaviour the pack depends on

- Punching: `max_damage` is the number of punches. The engine heals punched blocks itself
  (`heal_after_seconds`, `heal_interval_seconds`); `block_health_tick` and `block_break_tick` only
  apply to the hold-to-break path, which the pack does not use. A veto in `block_break` leaves the
  block cracked and unbroken.
- Block edits check reach to the block centre and require a loaded chunk. `place_block` also requires
  a solid neighbour; planting uses `vb.world.set_block`, which skips that check and the hooks, so the
  pack checks protection itself first.
- `vb.world.set_block` does not run the relight cascade (engine known gap), so shrub growth steps
  may leave stale lighting until something else touches the chunk.
- `vb.db` and `vb.storage` return JSON numbers as floats; `game/store.lua` turns whole numbers back
  into integers on read.
- `ui.send_event` payloads and everything else from a client are untrusted: every handler re-checks
  ownership, balances and value types, and events are rate limited per player.
