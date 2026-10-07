#!/usr/bin/env python3
"""Runs .dev/tests/run.lua with the `lupa` package (pip install lupa) for machines without a lua binary."""
import os
import sys

try:
    import lupa.lua54 as lupa  # the engine runs Lua 5.4
except ImportError:
    import lupa

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(root)
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
def listdir(path):
    try:
        return lua.table_from(sorted(os.listdir(path)))
    except OSError:
        return lua.table_from([])


lua.globals().__listdir = listdir
lua.execute("os.exit = function(code) error('exit:' .. tostring(code), 0) end")
try:
    lua.execute(open(".dev/tests/run.lua").read())
except lupa.LuaError as e:
    if str(e).startswith("exit:"):
        sys.exit(int(str(e)[5:].split()[0]))
    raise
