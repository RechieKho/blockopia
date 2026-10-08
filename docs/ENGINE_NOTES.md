# Engine notes

What Blockopia needs from the Voxel Browser engine, what was verified, and where the pack works
around a gap. Engine checked: commit `3cc9104` (`voxel_browser 0.1.2`, protocol 30), read from its
source and docs and built headless locally (`VB_WITH_LUA`, `VB_WITH_WORLDGEN`, no networking).

## Verified against the real engine

- `vb pack check --json --strict` is clean: the whole pack loads (86 blocks), the Lua sandbox lint
  passes, and no `vb.*` call appears in `ui/` or the reverse.
- The real server starts with the pack, runs 400 ticks without script
  errors, and persists `vb.storage.block_order`.
- API shapes the pack calls were read from the engine source: `player:punch/break_block/place_block`,
  `give/take/get_inventory/get_held_item`, `player_death` decisions (`heal`, `pos`, `message`),
  `ui_event(player, ui_name, widget_id, kind, value)` with `kind` = the string passed to
  `ui.send_event`, `on_break/on_place` callbacks receiving `{ pos, player }`, `block_break` /
  `block_place` vetoes, `region_enter`, punch healing through `vb.combat.set_params`.

## NOT verified (no client or network backend was available)

Nothing was played end to end. The mock engine in `.dev/tests/mock_engine.lua` covers the rules
above, but these still need a real session:

1. Joining with Keycloak (`auth.lua`), including `login.claims.groups`.
2. Warping far from the origin (chunk loading at the destination, float precision at ±131 000).
3. Whether non-air-but-non-solid blocks (shrubs) render and can be broken as expected.
4. HUD layout at real window sizes (the UI is only render-checked in a fake VM).
5. The hidden-chat-line HUD channel (below) under heavy chat.

## Released builds have no asset sync (engine bug)

The engine's release workflows (`.github/workflows/build_linux.yml`, `build_windows.yml`,
`build_macos.yml` at `3cc9104` / `v0.1.2`) configure with `-DVB_WITH_LUA=ON -DVB_WITH_NET=ON` but
not `-DVB_WITH_COMPRESSION=ON`, which defaults to `OFF`. Without it `assetsync::build_manifest`
returns `kDisabled`, the server skips asset sync without logging anything, and a joining client
gets no pack files at all. Seen in play:

- `ui/*.lua` never loads, so `player:open_ui` logs `ui.open: 'bp:menu' was never defined via
  ui.define` (same for `bp:store`, `bp:almanac`, ...).
- No HUD: the engine draws chat and the hotbar only through the pack's `ui.define_hud`, so chat
  replies (`!world`, `!help`) and picked-up drops are invisible.
- No textures: every pack block falls back to `WHITE` in `render/texture_atlas.cpp`, so worlds
  look white (the flat ground itself is by design).

Engine fix: add `-DVB_WITH_COMPRESSION=ON` to the three distribution builds (the automation job in
`build_linux.yml` already has it), and log a warning when the manifest is disabled. Until then,
singleplayer (`.dev/tools/play_local.sh`) works because it reads `ui/` and textures from disk.

## Gaps and workarounds

| Gap | Effect | Workaround in the pack | Engine change that would remove it |
| --- | --- | --- | --- |
| `Player` has no `set_pos` | cannot teleport for `!warp` | `game/worlds.lua` uses `set_pos` if it ever exists; otherwise it "kills" the player with cause `warp` and the `player_death` handler respawns them at the target (full heal, no death message, inventory kept) | `Player:set_pos(x, y, z)` |
| No server -> HUD data channel | coins/world could not be shown | `game/hud.lua` sends a hidden private chat line (`@@bp\|coins=..\|world=..`) every 3 s and on change; `ui/hud.lua` parses and hides it; chat lines starting with the marker are vetoed so players cannot forge it | `Player:set_hud_state(table)` readable from `ui.define_hud` |
| No wall-clock time (`os` removed) | shrubs only grow while the server runs | `game/store.lua` keeps a game clock advanced by `tick`, saved every 10 s | `vb.time()` (Unix seconds) |
| `vb.db` cannot list keys | records need indexes | `game/store.lua` collections (bucketed by 64x64 columns) and `idx:*` keys | `vb.db.keys(prefix)` |
| Inventories are not saved | items vanish on leave | `game/accounts.lua` snapshots the inventory per account (on leave, every 30 s) and restores it on the first input | engine-side per-account inventory persistence |
| No "joined" event with a `Player` handle | cannot set up a player at join | the first `player_input` after `player_join` marks the player ready | `player_join_completed(player)` event |
| No kick | bans only apply at the next join | `player_join` veto on banned `login.subject` | `Player:kick(reason)` (`Player:remove()` is a logged no-op) |
| `vb.world.raycast` and `Player:punch` only hit **solid** blocks | shrubs (walk-through) could not be punched, wrenched or spliced | `lib/ray.lua` marches the ray in Lua; shrubs are broken with `player:break_block`, everything else with `player:punch` | a `raycast` option to include non-solid blocks |
| `vb pack check` lints every `.lua` under the pack | tests/tools using `io`/`os` raise errors | tests and tools live in `.dev/`; dot-directories are skipped | an ignore list in `pack.toml` |
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
