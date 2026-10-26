"""Execute deterministic Mudlet simulations with the system Lua library."""
import ctypes
import ctypes.util
from pathlib import Path
import sys
import os

library = os.environ.get("KOZO_LUA_LIBRARY", "lua5.4")
lua = ctypes.CDLL(ctypes.util.find_library(library) or library)
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
modern = hasattr(lua, "luaL_loadfilex")
loadfile = lua.luaL_loadfilex if modern else lua.luaL_loadfile
loadfile.argtypes = [ctypes.c_void_p, ctypes.c_char_p] + ([ctypes.c_char_p] if modern else [])
loadfile.restype = ctypes.c_int
pcall = lua.lua_pcallk if modern else lua.lua_pcall
pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
if modern:
    pcall.argtypes += [ctypes.c_longlong, ctypes.c_void_p]
pcall.restype = ctypes.c_int
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]

state = lua.luaL_newstate()
lua.luaL_openlibs(state)
try:
    filename = str(Path(sys.argv[1] if len(sys.argv) > 1 else "tests/roles.lua").resolve())
    result = loadfile(state, filename.encode(), *([None] if modern else []))
    if result == 0:
        result = pcall(state, 0, 0, 0, *([0, None] if modern else []))
    if result:
        print(lua.lua_tolstring(state, -1, None).decode(), file=sys.stderr)
        sys.exit(1)
finally:
    lua.lua_close(state)
