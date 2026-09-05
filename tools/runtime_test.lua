-- Deterministic Mudlet doubles; no network, UI or game connection.
local timers,handlers={},{}
local serial,clock,cursor=0,10000,1
local function id() serial=serial+1; return serial end
function tempTimer(delay,callback,repeating) local n=id(); timers[n]={callback=callback,repeating=repeating}; return n end
function killTimer(n) timers[n]=nil end
function registerAnonymousEventHandler(event,callback) local n=id(); handlers[n]={event=event,callback=callback}; return n end
function killAnonymousEventHandler(n) handlers[n]=nil end
function tempRegexTrigger() return id() end
function tempAlias() return id() end
function killTrigger() end
function killAlias() end
function raiseEvent() end
function cecho() end
function hecho() end
function getEpochMs() return clock end
function getLineNumber() return cursor end
function getMudletHomeDir() return '/tmp' end
function setLabelToolTip() end
function setLabelCursor() end
local function fire(n) local t=timers[n]; if t then if not t.repeating then timers[n]=nil end; t.callback() end end
local function emit(event) local copy={}; for n,h in pairs(handlers) do copy[n]=h end; for _,h in pairs(copy) do if h.event==event then h.callback() end end end
local function flush(D) local pending={}; for _,p in ipairs(D.pending_hits) do pending[#pending+1]=p.timer end; for _,n in ipairs(pending) do fire(n) end end
chimera_vip={}
dofile('src/core/util.lua'); dofile('src/integrations/runtime.lua')
for _=1,3 do dofile('src/ui/footer_controls.lua') end
local count=0; for _,t in pairs(timers) do if t.repeating then count=count+1 end end
assert(count==1,'reload leaked repeating timers')
local CTRL=chimera_vip.footer_controls
local renders=0; local state='one'
CTRL.buttons.test={name='fake',setStyleSheet=function() renders=renders+1 end,echo=function() renders=renders+1 end}
local def={key='test',label='T',title='Test',state=function() return {label=state,text=state} end}
CTRL:update_button(def); CTRL:update_button(def); assert(renders==2,'unchanged button redrawn')
state='two'; CTRL:update_button(def); assert(renders==4,'changed button not redrawn')
print('PASS reload lifecycle and render cache')
dofile('src/features/defense_tracker.lua'); local D=chimera_vip.defense_tracker
D:new_session(); cursor=10; D:add_event('block','tarcza','zaslona')
cursor=11; clock=clock+50; D:on_incoming_hit('wysokie','oddzielny cios'); flush(D)
assert(D.session.block==1 and D:known_hits()==1,'separate hit after defense lost')
D:new_session(); cursor=20; D:on_incoming_hit('niskie','identical text')
cursor=21; D:on_incoming_hit('niskie','identical text'); D:add_event('parry','mlot','parowanie')
flush(D); assert(D.session.parry==1 and D:known_hits()==1,'defense cancelled another line')
D:new_session(); cursor=30; D:add_event('dodge',nil,'unik'); D:on_incoming_hit('wysokie','unik'); flush(D)
assert(D.session.dodge==1 and D:known_hits()==0,'defense before ANSI counted as hit')
D:new_session(); cursor=40; D:on_incoming_hit('wysokie','partial'); D:on_incoming_hit('wysokie','partial')
D:observe_line('pelna linia prawdziwego trafienia'); flush(D)
assert(D:known_hits()==1 and D.session.events[1].raw=='pelna linia prawdziwego trafienia','duplicate/incomplete hit')
D:new_session(); cursor=41; D:on_incoming_hit('wysokie','partial'); D:new_session(); flush(D)
assert(D:known_hits()==0 and #D.pending_hits==0,'reset left pending hit')
cursor=50; D:on_incoming_hit('wysokie','partial'); dofile('src/features/defense_tracker.lua')
assert(#D.pending_hits==0,'reload left pending hit')
print('PASS defense bursts, trigger order, duplicate, full text, reset and reload')
local sent={}
function send(command) sent[#sent+1]=command end
local function situation()
    gmcp={Room={Info={id='room-a',exits={polnoc='room-b',brama=0}}},Chimera={
        Group={State={leader='leader',members={{id='me',self=true},{id='leader'}}}},
        Combat={State={relations={{attacker='leader',defender='enemy'}},self_active=0}}}}
end
situation(); dofile('src/features/auto_support.lua'); local AS=chimera_vip.auto_support
local function attempt(change,expected)
    situation(); sent={}; AS:update_group(); AS:send_support_pair(); local timer=AS.cache.confirm_timer
    if change then change() end
    fire(timer); assert(#sent==expected,'unexpected support count: '..#sent)
end
attempt(nil,2)
attempt(function() gmcp.Chimera.Combat.State.relations={} end,1)
attempt(function() gmcp.Chimera.Combat.State.relations[2]={attacker='me',defender='enemy'} end,1)
attempt(function() gmcp.Chimera.Combat.State.relations[1].defender='other' end,1)
attempt(function() gmcp.Chimera.Group.State.members={} end,1)
attempt(function() gmcp.Room.Info.id='room-b'; emit('gmcp.Room.Info') end,1)
attempt(function() emit('sysDisconnectionEvent') end,1)
attempt(function() dofile('src/features/auto_support.lua') end,1)
situation(); sent={}; AS:update_group()
function send(command) sent[#sent+1]=command; emit('sysDisconnectionEvent') end
AS:send_support_pair(); assert(AS.cache.confirm_timer==nil and #sent==1,'synchronous response not cancelled')
assert(not chimera_vip.runtime:action('lamp'))
local clicked=false; scripts_ui_info_lamp_click=function() clicked=true end
assert(chimera_vip.runtime:action('lamp') and clicked)
local room=chimera_vip.runtime:room(); assert(#room.exits==2 and room.exits_targets.brama==0)
scripts=nil; amap=nil; ateam=nil; assert(chimera_vip.runtime:capabilities()[1][2]==false)
dofile('src/core/bootstrap.lua'); assert(chimera_vip:is_ready(), 'core still requires upstream UI')
print('PASS support cancellation, immediate response and native Room.Info')
local real_dofile=dofile; chimera_vip={root_dir='.'}
dofile=function(path) if path:match('features/stats.lua$') then error('fixture failure') end end
local ok,err=pcall(real_dofile,'src/init.lua'); dofile=real_dofile
assert(not ok and tostring(err):find('Nie zaladowano') and #chimera_vip.load_errors==1)
print('PASS aggregate module load failure')
