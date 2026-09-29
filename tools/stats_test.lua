chimera_vip = {}
getMudletHomeDir = function() return "/tmp" end
tempRegexTrigger = function() return 1 end
tempAlias = function() return 1 end
killTrigger = function() end
killAlias = function() end
registerAnonymousEventHandler = function() return 1 end
killAnonymousEventHandler = function() end
tempTimer = function() return 1 end
killTimer = function() end
hecho = function() end
raiseEvent = function() end
io.exists = function() return false end

assert(dofile("src/core/util.lua"))
local ST = dofile("src/features/stats.lua")
ST.current = {Sil=90, Zr=120, Wt=150, Int=80, Md=100, Odw=60}
local snapshot = ST:build_snapshot()
assert(snapshot.physical_average == 120)
assert(snapshot.mental_average == 90)
assert(snapshot.total == 600 and snapshot.average == 100)

local plain = {lavender="", mint="", text_muted="", blue=""}
local rendered = ST:average_line(snapshot, plain)
assert(rendered == "  SREDNIA: 100.0 (fizyczne: 120.0 | mentalne: 90.0)")
print("Stats average tests: PASS")
