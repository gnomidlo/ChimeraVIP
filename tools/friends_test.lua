local aliases,triggers,handlers,timers,sent={},{},{},{},{}
local serial=0
local function add(t,v) serial=serial+1; t[serial]=v; return serial end
function tempAlias(p,f) return add(aliases,{p,f}) end
function tempRegexTrigger(p,f) return add(triggers,{p,f}) end
function registerAnonymousEventHandler(e,f) return add(handlers,{e,f}) end
function tempTimer(_,f) return add(timers,f) end
function killAlias(id) aliases[id]=nil end
function killTrigger(id) triggers[id]=nil end
function killTimer(id) timers[id]=nil end
function killAnonymousEventHandler(id) handlers[id]=nil end
function hecho() end
function hechoLink() end
function send(s) sent[#sent+1]=s end
function deselect() end
function resetFormat() end
local selected,painted={},{}
function selectString(s,n) selected[#selected+1]={s,n}; return 0 end
function setFgColor(r,g,b) painted[#painted+1]={r,g,b} end
local disk,fail_save
chimera_vip={settings={data={},save=function(self)
    if fail_save then return false end
    disk=chimera_vip.util.deep_copy(self.data); return true
end}}
dofile('src/core/util.lua')
local F=dofile('src/features/friends.lua')
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local sample={"Trul odmienia sie nastepujaco:","  Mianownik: Trul,",
    " Dopelniacz: Trula,","   Celownik: Trulowi,","    Biernik: Trula,",
    "  Narzednik: Trulem,","Miejscownik: Trulu."}
local function feed() for _,s in ipairs(sample) do F:parse(s) end end
feed(); assert(not F.data.entries.trul) -- unsolicited output
assert(not F:add('Trul;zabij'))
assert(F:add('trul')); assert(sent[#sent]=='odmien trul')
assert(not F:add('Inny')); assert(#sent==1)
for i=1,6 do F:parse(sample[i]) end
assert(not F.data.entries.trul)
F:parse(sample[7]); assert(F.data.entries.trul and not F.pending)
assert(count(timers)==0 and #F.forms==5) -- duplicate Biernik only once
assert(disk.friends.entries.trul.forms[6]=='Trulu')
local spans=F:spans('Trulowy Trul, Trula! Trula. xTrul Trul2 Trul_ Trul-foo Trulą trul')
assert(#spans==3)
F:highlight('Trulowy Trul, Trula! Trula.')
assert(#painted==3 and selected[1][2]==2)
-- Shared forms from distinct friends are deliberately ambiguous.
local shared=chimera_vip.util.deep_copy(F.data)
shared.entries.ania={forms={"Ania","Trula","Ani","Anie","Ania","Ani"}}
assert(F:commit(shared)); assert(#F:spans('Trula')==0)
assert(F:remove('Ania')); assert(#F:spans('Trula')==1)
F:add('Inny')
for _,h in pairs(handlers) do if h[1]=='sysDisconnectionEvent' then h[2]() end end
assert(not F.pending and count(timers)==0)
assert(F:color('#123456')); assert(disk.friends.color=='#123456')
assert(not F:color('red;foo'))
F:add('Trul'); F:parse(sample[1]); F:parse(sample[2]); F:parse('ktos mowi: Trul')
assert(not F.pending and F.data.entries.trul)
F:add('Inny'); feed(); assert(not F.pending and not F.data.entries.inny)
F:add('Inny'); timers[F.timer](); assert(not F.pending)
timers={}
F:add('Trul'); F:parse(sample[1]); F:parse(sample[3]); assert(not F.pending)
fail_save=true
assert(not F:remove('Trul') and F.data.entries.trul)
assert(not F:color('#ffffff') and F.data.color=='#123456')
fail_save=false
F:add('Inny')
F=dofile('src/features/friends.lua')
assert(count(aliases)==3 and count(triggers)==1 and count(handlers)==2 and count(timers)==0)
assert(F.data.color=='#123456' and F.data.entries.trul)
-- Cold start from persisted settings, not the old module object.
F:cleanup(); chimera_vip.friends=nil; chimera_vip.settings.data=disk
F=dofile('src/features/friends.lua')
assert(F.data.color=='#123456' and #F.forms==5)
assert(F:remove('TRUL') and not disk.friends.entries.trul and #F.forms==0)
-- Bad persisted shapes must not crash a profile's startup.
F:cleanup(); chimera_vip.friends=nil
chimera_vip.settings.data.friends={entries={broken={forms={42,2,3,4,5,6}}}}
F=dofile('src/features/friends.lua'); assert(#F.forms==0)
for _,h in pairs(handlers) do
    if h[1]=='sysUninstallPackage' then h[2]('sysUninstallPackage','ChimeraVIP'); break end
end
assert(count(aliases)==0 and count(triggers)==0 and count(handlers)==0)
print('PASS friends parsing, persistence, colors, boundaries and lifecycle')
