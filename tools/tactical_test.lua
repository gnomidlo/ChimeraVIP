-- Offline GMCP/alias regression tests; run from the repository root.
local sent, aliases, disabled, handlers, timers = {}, {}, {}, {}, {}
local serial = 0
function send(command) sent[#sent + 1] = command end
function hecho() end
function tempAlias(pattern, callback)
    serial = serial + 1
    aliases[serial] = {pattern=pattern, callback=callback}
    return serial
end
function killAlias(id) aliases[id] = nil end
function disableAlias(name) disabled[name] = true end
function registerAnonymousEventHandler(event, callback)
    serial = serial + 1
    handlers[serial] = {event=event, callback=callback}
    return serial
end
function killAnonymousEventHandler(id) handlers[id] = nil end
function tempTimer(_, callback) timers[#timers + 1] = callback; return #timers end
function killTimer() end
chimera_vip = {}
dofile('src/core/util.lua')
dofile('src/integrations/runtime.lua')
local T = dofile('src/features/tactical_states.lua')
local A = dofile('src/features/tactical_aliases.lua')
local function reset(members)
    gmcp = {Room={Info={id='room1'}}, Chimera={
        Group={State={members=members}},
        Combat={State={relations={}}},
        Room={Entities={entities={{id='ob_self', name='Veesa', self=1, hp=80, maxhp=100}}}},
    }}
    T.team_marks = {}; T.team_next = 1; T:reset_room_marks(nil)
end
local function eq(a,b) assert(a==b, tostring(a)..' ~= '..tostring(b)) end
reset({})
local s = T:build_snapshot()
eq(#s.group,1); eq(#s.others,0); eq(s.group[1].mark,'@'); eq(s.group[1].name,'JA')
gmcp.Chimera.Group = nil
s=T:build_snapshot(); eq(#s.group,1); eq(#s.others,0)
reset({{id='ob_ally',name='Najemnik',here=1}})
gmcp.Chimera.Room.Entities.entities[2]={id='ob_enemy',name='Ork'}
gmcp.Chimera.Combat.State.relations={{attacker='ob_enemy',defender='ob_self'}}
s=T:build_snapshot(); eq(#s.group,2); eq(#s.enemies,1); eq(#s.others,0)
eq(s.group[1].mark,'@'); eq(s.group[2].mark,'A')
assert(A:command('za','a')); eq(sent[#sent],'zaslon ob_ally')
assert(A:command('z','1')); eq(sent[#sent],'zabij ob_enemy')
assert(A:command('rza','a @')); eq(sent[#sent],'parozkaz ob_ally zaslon ob_self')
gmcp.Chimera.Group.State.members[2]={id='ob_other_ally',name='Pomocnik',here=true}
assert(A:command('rza','A b')); eq(sent[#sent],'parozkaz ob_ally zaslon ob_other_ally')
local n=#sent
assert(not A:command('za','@')); assert(not A:command('rza','a a'))
assert(not A:command('rza','@ a')); assert(not A:command('za','1'))
assert(not A:command('z','')); assert(not A:command('z','1 extra'))
assert(not A:command('rza','a')); assert(not A:command('za','Z'))
eq(#sent,n)
-- Departed actors and ended combat must not resolve through old mark tables.
gmcp.Chimera.Group.State.members[1].here=0
assert(not A:command('za','b')); assert(not A:command('rza','b @'))
eq(T:get_group_target('A'),'ob_other_ally')
gmcp.Chimera.Combat.State.relations={}
assert(not A:command('z','1')); eq(#sent,n)
-- A failed refresh must not use the previous snapshot.
local original=T.build_snapshot
T.build_snapshot=function() error('GMCP unavailable') end
assert(not A:command('za','a')); eq(#sent,n)
T.build_snapshot=original
-- Entity self flag also wins when the group member omits its own self flag.
reset({{id='ob_self',name='Veesa'}})
s=T:build_snapshot(); eq(#s.group,1); eq(s.group[1].mark,'@'); eq(s.group[1].name,'JA')
-- Reload must replace aliases and listeners, and re-disable official conflicts.
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local alias_count, handler_count = count(aliases), count(handlers)
eq(alias_count,3)
A=dofile('src/features/tactical_aliases.lua')
eq(count(aliases),alias_count); eq(count(handlers),handler_count)
for _,name in ipairs(A.official_alias_names) do assert(disabled[name]) end
assert(not disabled.team); assert(not disabled.rozkaz_zaslony_id)
disabled={}
for _,h in pairs(handlers) do if h.event=='scriptsLoaded' then h.callback() end end
assert(disabled.zabij_id); assert(disabled.zaslon_team)
-- Manifest and loader must ship and execute the previously orphaned module.
local manifest=dofile('manifest.lua'); local found=false
for _,path in ipairs(manifest.files) do if path=='src/features/tactical_aliases.lua' then found=true end end
assert(found)
local f=assert(io.open('src/init.lua')); local init=f:read('*a'); f:close()
assert(init:find('load("src/features/tactical_aliases.lua")',1,true))
-- Changing teams must never exhaust the alphabet or leave holes.
reset({{id='ob_a',name='Anna'}, {id='ob_b',name='Beata'}, {id='ob_c',name='Celina'}})
s=T:build_snapshot(); eq(T:get_group_target('A'),'ob_a'); eq(T:get_group_target('C'),'ob_c')
gmcp.Chimera.Group.State.members[1].here=0
s=T:build_snapshot(); eq(T:get_group_target('A'),'ob_b'); eq(T:get_group_target('B'),'ob_c')
eq(T:get_group_target('C'),nil); eq(T.team_marks.ob_a,nil)
assert(A:command('za','a')); eq(sent[#sent],'zaslon ob_b')
for i=1,30 do
    gmcp.Chimera.Group.State.members={{id='ob_new'..i,name='Nowy'}}
    s=T:build_snapshot(); eq(s.group[1].mark,'@'); eq(s.group[2].mark,'A')
end
gmcp.Chimera.Group.State.members={}
s=T:build_snapshot(); eq(count(T.team_marks),0)
-- Equal names still have deterministic marks, regardless of packet order.
gmcp.Chimera.Group.State.members={{id='ob_b',name='Najemnik'}, {id='ob_a',name='Najemnik'}}
s=T:build_snapshot(); eq(T:get_group_target('A'),'ob_a')
gmcp.Chimera.Group.State.members={{id='ob_a',name='Najemnik'}, {id='ob_b',name='Najemnik'}}
s=T:build_snapshot(); eq(T:get_group_target('A'),'ob_a'); eq(T:get_group_target('B'),'ob_b')
print('Tactical GMCP and alias regressions: PASS')
