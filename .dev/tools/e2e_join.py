"""End-to-end check of Blockopia on a real engine: a dedicated server and headless clients over
UDP, driven by the engine's own e2e harness (tests/e2e/vbtest in the voxel_browser repo).

Needs an engine checkout and a build of it with automation (never ship that build):
    cmake -S <engine> -B <engine>/build-e2e -DVB_WITH_LUA=ON -DVB_WITH_NET=ON \
          -DVB_WITH_REPLICATION=ON -DVB_WITH_COMPRESSION=ON -DVB_WITH_AUTOMATION=ON
    cmake --build <engine>/build-e2e
    python3 -m pip install -r <engine>/tests/e2e/requirements.txt

usage: python3 .dev/tools/e2e_join.py <engine repo> <build dir> <blockopia dir> <work dir>

The server runs a copy of the pack without auth.lua under <work dir>, which is wiped first.
"""
import math
import pathlib
import shutil
import sys
import time

engine, build, blockopia, work = (pathlib.Path(a).resolve() for a in sys.argv[1:5])
sys.path.insert(0, str(engine / "tests" / "e2e"))
from vbtest import expect  # noqa: E402
from vbtest.stack import ClientFactory, start_server  # noqa: E402

shutil.rmtree(work, ignore_errors=True)
pack = work / "content" / "base"  # start_server serves <work>/content/base
shutil.copytree(blockopia, pack, ignore=shutil.ignore_patterns(
    ".git", ".dev", "auth.lua", "storage.json", "db", "world"))
art = work / "artifacts"
procs = []


def step(msg):
    print("--", msg, flush=True)


def ground_below(client):
    expect(client).to_be_on_ground()
    x, y, z = (int(math.floor(v + 0.01)) for v in client.feet)
    return x, y - 1, z


def punch_until_air(client, server, pos, tries=8):
    client.look_at((pos[0] + 0.5, pos[1] + 0.5, pos[2] + 0.5))
    for _ in range(tries):
        client.mouse_press("left")
        time.sleep(0.6)  # pack punch cooldown is 0.4 s
        if server.block_at(pos) == "base:air":
            return True
    return False


try:
    step("start server")
    server = start_server(build / "voxel_browser_server", engine, art, work, procs)
    step("wait 12 s so the pack writes vb.db (game clock every 10 s) after the manifest was built")
    time.sleep(12)
    db_files = [p for p in (pack / "db").rglob("*") if p.is_file()]
    print("   db files on disk:", len(db_files))
    assert db_files, "the pack wrote no vb.db files"

    clients = ClientFactory(build / "voxel_browser", server, art, work, procs)
    step("cold-cache client joins")
    (alice,) = clients(1, names=["Alice"])
    print("   joined")

    blobs = [p.read_bytes() for p in alice.cache_dir.rglob("*") if p.is_file()]
    for rel in ("ui/menu.lua", "ui/hud.lua", "ui/store.lua", "textures/grass.png", "textures/dirt.png"):
        assert (pack / rel).read_bytes() in blobs, rel + " did not reach the client"
    leaked = [p for p in db_files if p.read_bytes() in blobs]
    print("   ui/ + textures in client cache; db files in client cache:", len(leaked))
    assert not leaked

    step("HUD + chat: !world")
    expect(alice).to_have_hud_widget("coins")
    alice.chat("!world")
    expect(alice).to_have_chat(regex="World ")

    step("!menu opens bp:menu")
    alice.chat("!menu")
    expect(alice).to_have_ui_open("bp:menu")
    alice.ui("close").click()
    expect(alice).not_.to_have_ui_open("bp:menu")

    step("!store and !almanac open")
    alice.chat("!store")
    expect(alice).to_have_ui_open("bp:store")
    alice.ui("close").click()
    alice.chat("!almanac")
    expect(alice).to_have_ui_open("bp:almanac")
    alice.ui("close").click()

    step("break grass then dirt (drop rolls forced to succeed)")
    server.run_lua("math.random = function(a, b) if a then return a end return 0 end")
    x, y, z = ground_below(alice)
    target = (x + 2, y, z)
    print("   surface block:", server.block_at(target))
    assert punch_until_air(alice, server, target), "surface block did not break"
    expect(alice).not_.to_have_inventory("bp:grass", 1, timeout=1)  # 2 blocks away: out of pickup range
    alice.walk_to((target[0] + 0.5, None, target[2] + 0.5), tolerance=0.15)  # walk onto the drop
    expect(alice).to_have_inventory("bp:grass", 1, timeout=10)
    expect(alice).to_have_inventory("bp:grass_seed", 1, timeout=10)
    below = (target[0], target[1] - 1, target[2])  # the dirt under the hole
    print("   block below:", server.block_at(below))
    assert punch_until_air(alice, server, below), "dirt did not break"
    alice.walk_to((below[0] + 0.5, None, below[2] + 0.5), tolerance=0.15)  # into the hole, onto the drop
    expect(alice).to_have_inventory("bp:dirt", 9, timeout=10)  # 8 starting dirt + 1 drop
    expect(alice).to_have_inventory("bp:dirt_seed", 4, timeout=10)  # 3 starting seeds + 1
    print("   drops picked up")

    step("!warp TESTWORLD")
    before = alice.feet
    alice.chat("!warp TESTWORLD")
    expect(alice).to_have_chat(regex="Warping to TESTWORLD")
    time.sleep(1)
    after = alice.feet
    print("   moved from", [round(v) for v in before], "to", [round(v) for v in after])
    assert abs(after[0] - before[0]) + abs(after[2] - before[2]) > 1000
    expect(alice).to_have_loaded_chunks(8, timeout=30)
    expect(alice).to_be_on_ground(timeout=30)
    gx, gy, gz = ground_below(alice)
    print("   ground block at destination:", server.block_at((gx, gy, gz)))
    alice.chat("!world")
    expect(alice).to_have_chat(regex="World TESTWORLD")

    step("second cold-cache client joins after more vb.db writes")
    time.sleep(11)
    (bob,) = clients(1, names=["Bob"])
    expect(bob).to_have_hud_widget("coins")
    print("ALL OK")
finally:
    for p in reversed(procs):
        try:
            p.close()
        except Exception:
            pass
