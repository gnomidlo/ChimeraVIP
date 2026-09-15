local handlers, timers, sent = {}, {}, {}
local serial = 0
local function id() serial=serial+1; return serial end
function cecho() end
function registerAnonymousEventHandler(event, fn)
    local n=id(); handlers[n]={event=event, fn=fn}; return n
end
function killAnonymousEventHandler(n) handlers[n]=nil end
function tempTimer(delay, fn) local n=id(); timers[n]={delay=delay, fn=fn}; return n end
function killTimer(n) timers[n]=nil end
function raiseEvent(event, ...)
    local pending={}
    for _, h in pairs(handlers) do if h.event==event then pending[#pending+1]=h.fn end end
    for _, fn in ipairs(pending) do fn(event, ...) end
end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function tick(delay)
    local pending={}
    for n,t in pairs(timers) do if t.delay==delay then pending[n]=t.fn end end
    for n,fn in pairs(pending) do timers[n]=nil; fn() end
end
local hook
function send(command)
    sent[#sent+1]=command
    if hook then hook(command) end
end
chimera_vip={protocol={active=true, epoch=1}}
local C=chimera_vip
dofile('standalone/lifecycle.lua')
dofile('standalone/sequences.lua')
C.sequences:setup()
local S=C.sequences
local function step(command)
    return {command=command, event='ack', timeout=5,
        confirm=function(_, value) return value==command end}
end
local function clean()
    assert(count(S.running)==0 and count(timers)==0 and count(handlers)==1)
end
-- The server can respond inside send; no acknowledgement is lost.
hook=function(command)
    assert(count(timers)==1, 'timeout must precede send')
    raiseEvent('ack', command)
end
local ok, run=S:start('walk', {step('n'), step('e')})
assert(ok and sent[1]=='n' and #sent==1)
tick(0); assert(sent[2]=='e' and #sent==2)
tick(0); assert(run.result=='completed'); clean()
-- Invalid later steps cannot partially execute an earlier command.
local before=#sent
assert(not S:start('invalid', {step('n'), step('e;s')}))
assert(not S:start('invalid', {step('n'), step('e\n')}))
assert(not S:start('invalid', {step('/lua')}))
assert(not S:start('invalid', {[1]=step('n'), [3]=step('s')}))
assert(#sent==before); clean()
-- Wrong acknowledgement, timeout, duplicate start and late callbacks.
hook=nil
ok,run=S:start('bag', {step('otworz torbe'), step('wez monety')})
assert(ok and not S:start('bag', {step('zamknij torbe')}))
local late
for _,h in pairs(handlers) do if h.event=='ack' then late=h.fn end end
raiseEvent('ack', 'inne'); assert(run.index==1)
before=#sent; tick(5); assert(run.result=='timeout'); clean()
late('ack', 'otworz torbe'); tick(0); assert(#sent==before)
-- Cancellation also removes the deferred next step.
hook=function(command) raiseEvent('ack',command) end
ok,run=S:start('cancel', {step('n'), step('e')})
S:cancel('cancel'); before=#sent; tick(0)
assert(run.result=='cancelled' and #sent==before); clean()
-- Session reset cancels all independent operations; reconnect never replays.
hook=nil
ok,run=S:start('session', {step('n'),step('e')}); assert(ok)
assert(S:start('other', {step('s')}))
C.protocol.epoch=2; C.protocol.active=false
raiseEvent('chimeraVipV2SessionReset', 2)
assert(run.result=='session changed'); clean()
assert(not S:start('offline', {step('n')}))
before=#sent; C.protocol.active=true; tick(5); assert(#sent==before)
-- Failures release resources, including failures after a synchronous ACK.
hook=function(command) raiseEvent('ack',command); error('send failed') end
assert(not S:start('error', {step('n'),step('e')})); clean()
hook=nil
local bad=step('n'); bad.confirm=function() error('matcher failed') end
ok,run=S:start('matcher', {bad}); assert(ok)
raiseEvent('ack','n'); assert(run.result=='confirmation failed'); clean()
-- Registration failures on a later step do not leave a stuck operation.
hook=function(command) raiseEvent('ack',command) end
ok,run=S:start('late-registration', {step('n'),step('e')}); assert(ok)
local original=tempTimer
tempTimer=function() error('timer failed') end
tick(0); assert(run.result=='registration failed'); clean()
tempTimer=original
-- A callback may cancel and replace a named operation. The old callback must
-- not close the replacement's event handlers or schedule another old command.
hook=nil
local replacement
bad=step('n')
bad.confirm=function()
    S:cancel('replace')
    local started
    started,replacement=S:start('replace',{step('s')})
    assert(started)
    return true
end
ok,run=S:start('replace',{bad,step('e')}); assert(ok)
raiseEvent('ack','n')
assert(run.result=='cancelled' and S.running.replace==replacement)
assert(replacement.result=='running' and replacement.index==1)
raiseEvent('ack','s'); tick(0)
assert(replacement.result=='completed'); clean()
-- Reload/stop invalidates all callbacks and leaves no runtime resources.
hook=nil
assert(S:start('reload',{step('n')}))
S:stop('reload'); C.lifecycle:stop()
assert(count(handlers)==0 and count(timers)==0)
print('PASS confirmed sequences: ordering, timeout, cancellation, sessions and failures')
