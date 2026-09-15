local handlers, timers, aliases, requests = {}, {}, {}, {}
local serial = 0
local function id() serial=serial+1; return serial end
function cecho() end
function registerAnonymousEventHandler(event, fn) local n=id(); handlers[n]={event=event,fn=fn}; return n end
function killAnonymousEventHandler(n) handlers[n]=nil end
function tempTimer(_, fn) local n=id(); timers[n]=fn; return n end
function killTimer(n) timers[n]=nil end
function tempAlias(pattern, fn) local n=id(); aliases[n]={pattern=pattern,fn=fn}; return n end
function killAlias(n) aliases[n]=nil end
function sendGMCP(value) requests[#requests+1]=value end
function raiseEvent() end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function emit(event, ...)
    local pending={}; for _,h in pairs(handlers) do if h.event==event then pending[#pending+1]=h.fn end end
    for _,fn in ipairs(pending) do fn(event, ...) end
end
local function boot() return assert(loadfile('standalone/init.lua'))('.') end
gmcp={Room={Info={id='stale'}},Char={},Chimera={Room={},Group={},Combat={}}}
local C=boot()
assert(C.ready and not C.runtime:room() and #requests==0)
assert(scripts==nil and ateam==nil and amap==nil and C.updater==nil)
emit('sysConnectionEvent'); emit('sysProtocolEnabled','GMCP')
assert(#requests==1 and requests[1]:find('Chimera.Room.Entities 1',1,true))
emit('sysProtocolEnabled','GMCP'); assert(#requests==1)
gmcp.Room.Info={id='A',name='Pokoj',terrain='las',exits={polnoc='B'}}
emit('gmcp.Room.Info')
local room=C.runtime:room(); assert(room.id=='A' and room.terrain=='las')
room.id='mutated'; assert(C.runtime:room().id=='A')
gmcp.Chimera.Room.Entities={room='A',entities={{id='me',self=1}}}
emit('gmcp.Chimera.Room.Entities')
gmcp.Chimera.Combat.State={room='A',relations={{attacker='enemy',defender='me'}}}
emit('gmcp.Chimera.Combat.State'); assert(C.runtime:combat())
gmcp.Chimera.Room.Entities={room='B',entities={{id='me',self=1}}}
emit('gmcp.Chimera.Room.Entities'); assert(not C.runtime:combat())
gmcp.Room.Info={id='B',exits={}}; emit('gmcp.Room.Info')
assert(C.runtime:entities().room=='B' and not C.runtime:combat())
gmcp.Chimera.Combat.State={room='A',relations={}}
emit('gmcp.Chimera.Combat.State'); assert(not C.runtime:combat())
gmcp.Chimera.Combat.State={room='B',relations={}}
emit('gmcp.Chimera.Combat.State'); assert(C.runtime:combat())
local original_count=count(handlers)
local stale_handler
for _,h in pairs(handlers) do if h.event=='gmcp.Room.Info' then stale_handler=h.fn end end
for _=1,5 do C=boot() end
assert(count(handlers)==original_count and count(aliases)==1 and #requests==6)
assert(C.runtime:room().id=='B')
gmcp.Room.Info={id='old-callback'}; stale_handler()
assert(C.runtime:room().id=='B')
local fired=0
local scope=C.lifecycle:open('test')
local timer=scope:timer(1,function() fired=fired+1 end)
local late=timers[timer]; C.lifecycle:close('test'); late(); assert(fired==0)
scope=C.lifecycle:open('test')
timer=scope:timer(1,function() fired=fired+1 end)
local callback=timers[timer]; timers[timer]=nil; callback()
assert(fired==1 and #scope.resources==0)
scope:event('failure',function() error('expected error') end)
emit('failure'); assert(#C.lifecycle.errors==1)
emit('sysDisconnectionEvent'); assert(not C.runtime:room() and not C.runtime:combat())
C=boot(); assert(not C.runtime:room() and #requests==6)
emit('sysProtocolEnabled','GMCP'); assert(#requests==7 and not C.runtime:room())
emit('sysProtocolDisabled','GMCP'); assert(not C.protocol.active)
-- First actual packet after startup can negotiate without reading old cache.
gmcp.Char.Vitals={hp=100}; emit('gmcp.Char.Vitals')
assert(#requests==8 and C.runtime:vitals().hp==100 and not C.runtime:room())
local old_epoch=C.protocol.epoch
C:stop(); assert(not C.ready and count(handlers)==0 and count(aliases)==0 and count(timers)==0)
assert(C.protocol.epoch>old_epoch)
C=boot(); assert(count(handlers)==original_count and #requests==8)
scripts={}; local ok=pcall(boot); assert(not ok and C.ready); scripts=nil
assert(not C.runtime:can_action('lamp') and not C.runtime:action('lamp'))
C:stop()
-- Failure midway through startup must release resources already registered.
local original_alias=tempAlias
tempAlias=function() error('alias registration failed') end
ok=pcall(boot)
assert(not ok and not C.ready and count(handlers)==0 and count(aliases)==0)
tempAlias=original_alias
C=boot()
-- A failed subscription is retryable and does not report successful setup.
local original_send=sendGMCP
sendGMCP=function() error('send failed') end
emit('sysProtocolEnabled','GMCP')
assert(not C.protocol.subscribed)
sendGMCP=original_send
emit('sysProtocolEnabled','GMCP')
assert(C.protocol.subscribed)
C:stop()
print('PASS standalone startup, GMCP, room isolation, reload, stop and stale callbacks')
