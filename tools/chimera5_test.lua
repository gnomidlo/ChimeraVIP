-- Run: lua tools/chimera5_test.lua (no Mudlet)
local calls, handlers, cleanup = {}, {}, nil
function raiseEvent(name, data) calls[#calls + 1] = {name, data} end
local gmcp_api = {
    room=function() return {id="room",exits={polnoc="next"}} end,
    group=function() return {members={}} end,
    combat=function() return {relations={}} end,
    vitals=function() return {hp=50} end,
    entities=function() return {entities={}} end,
}
local team = {
    view=function() return {self={id="my-id"},members={},enemies={}} end,
    resolve=function(mark) return mark=="A" and "ally-id" or nil end,
}
local ctx = {
    use=function(_, name) return name=="gmcp" and gmcp_api or team end,
    on=function(_, name, fn) handlers[name]=fn end,
    timer=function(_, _, fn) fn() end,
    cleanup=function(_, fn) cleanup=fn end,
}
local spec = dofile("plugins/chimera_vip_bridge/init.lua")
assert(spec.name=="chimeravip_bridge" and spec.deps[1]=="gmcp")
local api = spec.setup(ctx)
assert(api.connected() and chimera_vip_bridge.team_resolve("A")=="ally-id")
assert(chimera_vip_bridge.gmcp_room().exits.polnoc=="next")
handlers["chimera.killed"]({exp=111})
assert(calls[#calls][1]=="chimeraVipUpstreamKilled" and calls[#calls][2].exp==111)
handlers["gmcp.Chimera.Group.State"]()
assert(calls[#calls][1]=="chimeraVipUpstreamTeam")
cleanup()
assert(not api.connected() and chimera_vip_bridge==nil)
print("PASS Chimera 5 plugin bridge")
