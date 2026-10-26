-- Source-audited Chimera 5.0.1 compatibility report; no live Mudlet dependency.
local handlers={}
function getMudletHomeDir() return "/fake/profile" end
function raiseEvent() end
function tempTimer(_,cb) cb() end
chimera_vip={
    util={replace_handler=function(_,key,event,cb) handlers[event]=cb end},
    runtime={is_chimera5=function() return true end,
        bridge=function() return {api=5} end},
    load_errors={},
}
dofile("src/core/bootstrap.lua")
local C=chimera_vip
assert(C.version=="0.181" and C.tested_upstream=="5.0.1",
    "Fallback release version and source-audited upstream drifted")
chimera={app={version="5.0.1"}}
assert(C:get_upstream_version()=="5.0.1",
    "Stable Chimera 5.0.1 runtime version was not detected")
chimera.app.version="dev"
assert(C:get_upstream_version():find("API",1,true),
    "Development build must not be reported as a numbered stable release")
chimera=nil
C.runtime.bridge=function() return nil end
assert(C:get_upstream_version():find("bez mostu",1,true),
    "Bridge-less Chimera 5 must be diagnosable, not misidentified")
C.runtime.is_chimera5=function() return false end
scripts={version={installed=function() return "4.9.9" end}}
assert(C:get_upstream_version()=="4.9.9",
    "Legacy version fallback must remain diagnostic during transition")
scripts=nil
chimera_pkg={version="5.0.1"}
assert(C:get_upstream_version()=="5.0.1")
chimera_pkg=nil
assert(C:get_upstream_version()=="?")
print("PASS 0.181 Chimera 5.0.1 version reporting and safe fallbacks")
