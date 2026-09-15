-- Integrated bootstrap and real feature callbacks; isolated temporary data.
local handlers,timers,aliases,triggers={},{},{},{}
local serial,clock=0,10000
local output,sent={},{}
local function id() serial=serial+1; return serial end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
function cecho(s) output[#output+1]=s end
hecho=cecho; decho=cecho
function echo(s) output[#output+1]=s end
function echoLink() end
function sendGMCP() end
function send(s) sent[#sent+1]=s end
function registerAnonymousEventHandler(event,fn) local n=id(); handlers[n]={event=event,fn=fn}; return n end
function killAnonymousEventHandler(n) handlers[n]=nil end
function tempTimer(delay,fn) local n=id(); timers[n]={delay=delay,fn=fn}; return n end
function killTimer(n) timers[n]=nil end
function tempAlias(pattern,fn) local n=id(); aliases[n]={pattern=pattern,fn=fn}; return n end
function killAlias(n) aliases[n]=nil end
function tempRegexTrigger(pattern,fn) local n=id(); triggers[n]={pattern=pattern,fn=fn}; return n end
function tempAnsiColorTrigger(fg,bg,fn) local n=id(); triggers[n]={ansi=fg,fn=fn}; return n end
function killTrigger(n) triggers[n]=nil end
function disableTrigger() error('Must not touch official triggers') end
function enableTrigger() error('Must not touch official triggers') end
function getEpochMs() return clock end
function getLineNumber() return 1 end
function selectString() return 0 end
function selectCurrentLine() end
function resetFormat() end
function setFgColor() end
function deselect() end
function replace() end
function dreplace() end
function deleteLine() end
function prefix() end
function raiseEvent(event,...)
    local pending={}
    for _,h in pairs(handlers) do if h.event==event then pending[#pending+1]=h.fn end end
    for _,fn in ipairs(pending) do fn(event,...) end
end
local function tick(delay)
    local pending={}
    for n,t in pairs(timers) do if t.delay==delay then pending[n]=t.fn end end
    for n,fn in pairs(pending) do if timers[n] then timers[n]=nil; fn() end end
end
local root=os.tmpname(); os.remove(root)
local function quote(s) return "'"..s:gsub("'","'\\''").."'" end
local function mkdir(path) os.execute('mkdir -p '..quote(path)) end
mkdir(root..'/ChimeraVIP-data')
function getMudletHomeDir() return root end
package.preload.lfs=function() return {mkdir=mkdir} end
local function serialize(v)
    if type(v)=='table' then
        local out={'{'}
        for k,value in pairs(v) do out[#out+1]='['..serialize(k)..']='..serialize(value)..',' end
        return table.concat(out)..'}'
    end
    return type(v)=='string' and string.format('%q',v) or tostring(v)
end
function table.save(path,data)
    local file=assert(io.open(path,'w')); file:write('return '..serialize(data)); file:close()
end
function table.load(path,destination)
    local value=assert(loadfile(path))()
    for k,v in pairs(value) do destination[k]=v end
end
local settings_path=root..'/ChimeraVIP-data/settings.lua'
table.save(settings_path,{modules={combat_colors=true},ui={states_font_size=12},custom='keep'})
local function contents(path) local f=assert(io.open(path)); local s=f:read('*a'); f:close(); return s end
local original=contents(settings_path)
local function boot() return assert(loadfile('standalone/init.lua'))('.') end
gmcp={Room={Info={id='stale'}},Char={},Chimera={Group={},Room={},Combat={}}}
local C=boot()
assert(C.features.active and #C.features.loaded==18 and #C.features.errors==0)
assert(C.settings:get('custom')=='keep' and C.settings:get('ui.states_font_size')==12)
assert(contents(settings_path)==original and C.settings.data_file:find('/ChimeraVIP-v2/',1,true))
assert(scripts==nil and ateam==nil and amap==nil and chimera_damage==nil)
assert(count(triggers)>30 and count(aliases)>10)
-- Persist toggles even on filesystems that refuse rename over an existing file.
local rename=os.rename
os.rename=function(from,to)
    local f=io.open(to)
    if f then f:close(); return nil,'destination exists' end
    return rename(from,to)
end
assert(C.features:set_support(false) and not C.auto_support.enabled)
assert(C.features:set_support(true) and C.auto_support.enabled)
assert(C.settings:set_module_enabled('combat_colors',false) and not C.combat_colors.enabled)
assert(C.settings:set_module_enabled('combat_colors',true) and C.combat_colors.enabled)
os.rename=rename
local function trigger(fragment,values,text)
    for _,t in pairs(triggers) do
        if t.pattern and t.pattern:find(fragment,1,true) then
            matches=values; line=text or values[1]; t.fn(); return t.fn
        end
    end
    error('Missing trigger: '..fragment)
end
-- User's female shield appraisal follows the registered trigger path.
trigger('^Oceniasz starannie',{'','wzmacniana drewniana tarcze'})
trigger('lekko podniszczon',{'','lekko podniszczona'})
assert(C.weapon_info.capture.condition_text=='lekko podniszczona' or C.weapon_info.capture.condition)
trigger('^Klasa pancerza',{'','prawe ramie 15/15/15'})
tick(C.weapon_info.summary_delay)
assert(table.concat(output):find('OCENA',1,true))
-- String callbacks compile in the owned environment (defense + ANSI modules).
trigger('oslonic',{'','czarna tarcza'},'lecz udaje ci sie oslonic czarna tarcza.')
assert(C.defense_tracker.session.block==1)
-- Group/combat handlers run after protocol ingestion, not on stale global GMCP.
gmcp.Room.Info={id='A',exits={}}; raiseEvent('gmcp.Room.Info')
gmcp.Chimera.Group.State={leader='leader',members={{id='me',self=1},{id='leader'}}}
raiseEvent('gmcp.Chimera.Group.State')
gmcp.Chimera.Room.Entities={room='A',entities={{id='me',self=1},{id='leader'}}}
raiseEvent('gmcp.Chimera.Room.Entities')
gmcp.Chimera.Combat.State={room='A',self_active=0,relations={{attacker='leader',defender='enemy'}}}
raiseEvent('gmcp.Chimera.Combat.State')
assert(#sent==1 and sent[1]=='wesprzyj')
local late=timers[C.auto_support.cache.confirm_timer].fn
raiseEvent('sysDisconnectionEvent'); late(); assert(#sent==1 and count(timers)==0)
assert(C.weapon_info.capture==nil and not C.runtime:combat())
-- Neither cancelled callbacks nor old-generation callbacks may affect a reload.
local old_trigger=trigger('^Oceniasz starannie',{'','stary miecz'})
local resources={count(handlers),count(aliases),count(triggers)}
for _=1,3 do
    C=boot()
    assert(count(handlers)==resources[1] and count(aliases)==resources[2] and count(triggers)==resources[3])
end
old_trigger(); assert(C.weapon_info.capture==nil)
assert(contents(settings_path)==original)
C:stop()
assert(count(handlers)==0 and count(aliases)==0 and count(triggers)==0 and count(timers)==0)
-- Corrupt v2 data is not silently replaced by defaults or old v1 data.
local v2path=C.settings.data_file
local f=assert(io.open(v2path,'w')); f:write('not valid lua'); f:close()
assert(not pcall(boot)); assert(contents(v2path)=='not valid lua' and contents(settings_path)==original)
assert(count(handlers)==0 and count(aliases)==0 and count(triggers)==0 and count(timers)==0)
os.execute('rm -rf '..quote(root))
print('PASS 18 VIP modules: bootstrap, data isolation, callbacks, native GMCP, reload and stop')
