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


def inv_count(client, item):
    return sum(s["count"] for s in client.state().get("inventory", []) if s["item"] == item)


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

    step("dig straight down twice (drop rolls forced to succeed)")
    server.run_lua("math.random = function(a, b) if a then return a end return 0 end")
    for _ in range(2):
        below = ground_below(alice)  # the block under Alice's feet: she falls onto its drop
        name = server.block_at(below)
        have, seeds = inv_count(alice, name), inv_count(alice, name + "_seed")
        print("   breaking", name, "at", below)
        assert punch_until_air(alice, server, below), name + " did not break"
        expect(alice).to_have_inventory(name, have + 1, timeout=10)
        expect(alice).to_have_inventory(name + "_seed", seeds + 1, timeout=10)
    print("   drops picked up")

    step("!warp TESTWORLD")
    before = alice.feet
    alice.chat("!warp TESTWORLD")
    expect(alice).to_have_chat(regex="Warping to TESTWORLD")
    time.sleep(1)
    after = alice.feet
    print("   moved from", [round(v) for v in before], "to", [round(v) for v in after])
    cell = 256  # balance.world_cell_size
    assert (math.floor(after[0] / cell), math.floor(after[2] / cell)) != \
        (math.floor(before[0] / cell), math.floor(before[2] / cell)), "still in the same world cell"
    assert max(abs(after[0]), abs(after[2])) <= 8192, "outside the map"
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
