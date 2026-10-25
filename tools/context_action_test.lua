-- ChimeraVIP 0.177: legacy trigger compatibility and context/map bind separation.
local triggers,timers,clock={}, {},1000
local seq=0
local echoed,commands,aliases={},{},{}
local function id() seq=seq+1;return seq end
function cecho(text) echoed[#echoed+1]=text end
function getEpoch() return clock end
function tempTimer(time,callback) local n=id();timers[n]={delay=time,callback=callback};return n end
function killTimer(n) timers[n]=nil end
function send(value,show) commands[#commands+1]={value=value,show=show} end
function expandAlias(value,show) aliases[#aliases+1]={value=value,show=show} end
local function fire(n)
    local item=timers[n]
    timers[n]=nil
    if item then item.callback() end
end
gmcp={Room={Info={id="room-a"}}}
chimera_vip={util={replace_handler=function(owner,name,event,callback)
    triggers[event]=callback
    return name
end}}
local script=dofile("src/features/context_action.lua")
local A=chimera_vip.context_action
local M=chimera_vip.map_action
assert(script.context==A and script.map==M)
assert(type(A.run)=="function" and type(A.set)=="function")
assert(type(A.set_send)=="function" and type(A.set_alias)=="function")
assert(type(A.clear)=="function" and type(A.status)=="function")
assert(A.default_ttl==30)
assert(A:run()==false)
assert(A:set_send("uderz we wrota")==true)
assert(A.current.room_id=="room-a")
assert(echoed[#echoed]:find("⚡ Kontekst",1,true),"Missing pastel contextual icon")
local initial=A.timer_id
assert(initial~=nil and timers[initial].delay==30)
assert(A:run()==true and commands[1].value=="uderz we wrota" and commands[1].show==false)
assert(A:set_alias("naps",false,5)==true)
assert(timers[initial]==nil,"Old timer must be cancelled")
local newer=A.timer_id
fire(initial)
assert(A.current.label=="naps","Old timer invalidated newer action")
assert(A:run()==true and aliases[1].value=="naps")
fire(newer)
assert(A.current==nil,"Action did not expire after TTL")
assert(A:set_alias("/wlm",false,0)==true)
assert(A.timer_id==nil)
assert(A:run()==true and aliases[2].value=="/wlm")
assert(A:set_send("",false)==false)
assert(A:set(function() error("simulated callback failure") end,"bad",0)==true)
assert(A:run()==false,"Errors must be contained")
assert(A:set(function() commands[#commands+1]={value="ok"} end,"manual",0)==true)
assert(A:status().label=="manual")
gmcp.Room.Info.id="room-b"
assert(A:run()==false and A.current==nil,"Room change must clear situational bind")
gmcp.Room.Info.id="room-a"
assert(A:set_send("rozbij brame",true)==true)
gmcp.Room.Info.id="room-c"
triggers["gmcp.Room.Info"]()
assert(A.current==nil,"Room event must remove stale situational bind")
assert(M:run()==false,"Missing map provider must be a safe no-op")
local hit=0
M._runner=function() hit=hit+1;return true end
M._status=function() return "Otworz wrota" end
assert(M:run()==true and hit==1)
assert(M:status()=="Otworz wrota")
assert(echoed[#echoed]:find("⌖ Mapa",1,true),"Missing lavender map icon")
M._runner=function() return false end
assert(M:run()==false)
M._runner=function() error("simulated map failure") end
assert(M:run()==false)
print("PASS 0.177: trigger context API, TTL, room invalidation, separate map API, pastel feedback")
