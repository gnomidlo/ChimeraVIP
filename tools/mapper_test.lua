local handlers,timers,aliases,sent={},{},{},{}
local serial=0
local function id() serial=serial+1; return serial end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
function cecho() end
function sendGMCP() end
function registerAnonymousEventHandler(event,fn) local n=id(); handlers[n]={event=event,fn=fn}; return n end
function killAnonymousEventHandler(n) handlers[n]=nil end
function tempTimer(delay,fn) local n=id(); timers[n]={delay=delay,fn=fn}; return n end
function killTimer(n) timers[n]=nil end
function tempAlias(pattern,fn) local n=id(); aliases[n]={pattern=pattern,fn=fn}; return n end
function killAlias(n) aliases[n]=nil end
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
local A,B,D='aaaaaaaaaaaaaaaa','bbbbbbbbbbbbbbbb','dddddddddddddddd'
local rooms={[11]='A',[22]='B',[33]='D'}
local hashes={[11]=A,[22]='legacy:1,2,3',[33]=D}
local data={[22]=B}
local marker
function getRooms() return rooms end
function getRoomHashByID(n) return hashes[n] end
function getRoomUserData(n,key) assert(key=='chimera_id'); return data[n] end
function centerview(n) marker=n end
function getPath(from,to)
    assert(from==11 and to==33)
    speedWalkPath={22,33}; speedWalkDir={'n','wejdz do jaskini'}; return true
end
-- Any map mutation would fail this test. Old metadata remains in these tables.
function setRoomIDbyHash() error('map must not be rewritten') end
function setRoomUserData() error('map must not be rewritten') end
local hook
function send(command) sent[#sent+1]=command; if hook then hook(command) end end
gmcp={Room={Info={id='stale'}},Char={}}
local function room(key,exits,instance)
    gmcp.Room.Info={id=key,exits=exits or {},instance=instance}
    raiseEvent('gmcp.Room.Info')
end
local function boot() return assert(loadfile('standalone/init.lua'))('.') end
local C=boot(); local M=C.mapper
assert(M.active and not M.current and not marker and count(aliases)==5)
room(A,{polnoc=B}); assert(M.current==11 and marker==11)
assert(M:key({id=A:upper()})==A and M:key({id=A,instance='03'})==A..'#3')
assert(not M:key({id=A,instance=-1}))
assert(M:resolve(B)==22 and hashes[22]=='legacy:1,2,3' and data[22]==B)
assert(not M:set_delay(-1) and not M:set_delay(math.huge) and M:set_delay(0.2))
-- Synchronous GMCP acknowledgement is caught; pacing happens after arrival.
hook=function(cmd)
    assert(count(timers)==1, 'timeout must exist before send')
    if cmd=='polnoc' then room(B,{['wejdz do jaskini']=D}) else room(D,{}) end
end
local ok,run=M:go(33)
assert(ok and #sent==1 and run.waiting==false and M.current==22)
speedWalkPath[2]=99; speedWalkDir[2]='quit' -- snapshot must be independent
tick(0.2)
assert(#sent==2 and sent[2]=='wejdz do jaskini' and run.result=='cel osiagniety')
assert(M.current==33 and not M.walk and count(timers)==0)
-- Refused movement times out without retries, and late callbacks are inert.
hook=nil; room(A,{polnoc=B}); ok,run=M:go(33); assert(ok)
local late; for _,t in pairs(timers) do late=t.fn end
local before=#sent; tick(10)
assert(run.result=='timeout ruchu' and not M.walk)
room(B,{['wejdz do jaskini']=D}); late(); tick(0.2); assert(#sent==before)
-- Unexpected movement stops; it cannot be treated as arrival at the target.
room(A,{polnoc=B}); ok,run=M:go(33); assert(ok)
room(D,{}); assert(run.result=='nieoczekiwana lokacja' and count(timers)==0)
-- Stop cancels deferred movement too.
room(A,{polnoc=B}); ok,run=M:go(33); assert(ok)
room(B,{['wejdz do jaskini']=D}); M:stop('stop'); before=#sent; tick(0.2); assert(#sent==before)
-- A new instance never localizes to the base room by accident.
room(A,{polnoc=B},3); assert(not M.current and not M:go(33))
-- Conflicting imported/native mappings and duplicates block localization.
rooms[44]='duplicate'; hashes[44]=B
M:reindex(); assert(not M:resolve(B))
rooms[44]=nil; hashes[44]=nil; data[11]=D
M:reindex(); assert(not M:resolve(A) and not M:resolve(D))
data[11]=nil; M:reindex()
-- Check all route identities before sending its first command.
data[22]=nil; M:reindex(); room(A,{polnoc=B}); before=#sent
assert(not M:go(33) and #sent==before)
data[22]=B; M:reindex()
-- Current exits must match: stale map paths cannot send blindly.
room(A,{polnoc=D}); assert(not M:go(33) and #sent==before)
-- Disconnect and reload cancel pending movement, preserving session delay.
room(A,{polnoc=B}); ok,run=M:go(33); assert(ok)
raiseEvent('sysDisconnectionEvent'); assert(not M.current and run.result=='rozlaczenie')
room(A,{polnoc=B}); ok,run=M:go(33); assert(ok)
C=boot(); assert(run.result=='zatrzymanie VIP' and not C.mapper.walk and C.mapper.delay==0.2)
assert(count(timers)==0 and count(aliases)==5 and scripts==nil and amap==nil and ateam==nil)
-- Sending failure releases timeout and leaves a retryable service.
M=C.mapper; hook=function() error('send failed') end
assert(not M:go(33) and not M.walk and count(timers)==0)
hook=nil
speedWalkPath={33}; before=#sent
doSpeedWalk(); assert(M.walk and #sent==before+1)
local old_hook=doSpeedWalk
C:stop(); assert(count(aliases)==0 and count(handlers)==0 and count(timers)==0)
assert(doSpeedWalk==nil and mudlet.mapper_script==nil)
before=#sent; old_hook(); assert(#sent==before)
print('PASS native mapper: identity, conflicts, path confirmation, pacing, stop and sessions')
