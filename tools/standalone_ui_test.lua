local handlers,timers,aliases,labels,sent={},{},{},{},{}
local serial,border,width,height,draws=0,18,1280,800,0
local function id() serial=serial+1; return serial end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
function cecho() end
function sendGMCP() end
function send(command) sent[#sent+1]=command end
function registerAnonymousEventHandler(event,fn) local n=id(); handlers[n]={event=event,fn=fn}; return n end
function killAnonymousEventHandler(n) handlers[n]=nil end
function tempTimer(_,fn) local n=id(); timers[n]=fn; return n end
function killTimer(n) timers[n]=nil end
function tempAlias(_,fn) local n=id(); aliases[n]=fn; return n end
function killAlias(n) aliases[n]=nil end
function raiseEvent(event,...)
    local pending={}
    for _,h in pairs(handlers) do if h.event==event then pending[#pending+1]=h.fn end end
    for _,fn in ipairs(pending) do fn(event,...) end
end
local function flush()
    local pending=timers; timers={}
    for _,fn in pairs(pending) do fn() end
end
function createLabel(name,x,y,w,h)
    assert(not labels[name], 'label leaked across reload: '..name)
    labels[name]={x=x,y=y,w=w,h=h}; return true
end
function deleteLabel(name) assert(labels[name]); labels[name]=nil; return true end
function moveWindow(name,x,y) labels[name].x=x; labels[name].y=y end
function resizeWindow(name,w,h) labels[name].w=w; labels[name].h=h end
function setLabelStyleSheet(name,style) labels[name].style=style end
function setLabelClickCallback(name,fn) labels[name].click=fn end
function echo(name,value) labels[name].text=value; draws=draws+1 end
function getMainWindowSize() return width,height end
function getBorderBottom() return border end
function setBorderBottom(value) border=value end
local function label(key) return labels['chimera_vip2.footer.'..key] end
local function boot() return assert(loadfile('standalone/init.lua'))('.') end
gmcp={Room={Info={id='stale',exits={polnoc='stale'}}},Char={Vitals={hp=99}}}
local C=boot()
assert(C.ui.active and count(labels)==23 and border==100)
assert(scripts==nil and ateam==nil and amap==nil)
assert(label('hp').text:find('—',1,true) and label('exit2').text=='')
-- Native buttons delegate to the active standalone feature services.
local features=C.features
C.combat_colors={enabled=true}; C.auto_support={enabled=true}
C.settings={set_module_enabled=function(_,name,value)
    assert(name=='combat_colors'); C.combat_colors.enabled=value
    raiseEvent('chimeraVipCombatColorsStateChanged')
end}
C.features={active=true,set_support=function(_,value)
    C.auto_support.enabled=value; raiseEvent('chimeraAutoSupportChanged')
end}
raiseEvent('chimeraVipV2FeaturesReady'); flush()
assert(label('colors').text=='KOL ON' and label('support').text=='AS ON')
label('colors').click(); label('support').click(); flush()
assert(label('colors').text=='KOL OFF' and label('support').text=='AS OFF')
C.features=features
gmcp.Room.Info={id='A',name='<b>Las & pole</b>',exits={polnoc='B',['wejdz do jaskini']='C',['n;quit']='bad'}}
gmcp.Char.Vitals={hp=73,moves=0,mana=math.huge,hunger=10}
raiseEvent('gmcp.Room.Info'); raiseEvent('gmcp.Char.Vitals')
assert(count(timers)==1, 'updates must share one render')
flush()
assert(label('room').text=='&lt;b&gt;Las &amp; pole&lt;/b&gt;')
assert(label('hp').text:find('73%%') and label('moves').text:find('0%%'))
assert(label('mana').text:find('—',1,true) and label('thirst').text:find('—',1,true))
label('exit2').click(); assert(sent[1]=='polnoc')
label('exit11').click(); assert(sent[2]=='wejdz do jaskini')
local cached_draws=draws
for _=1,100 do raiseEvent('gmcp.Char.Vitals') end
assert(count(timers)==1); flush(); assert(draws==cached_draws)
-- A click queued for the old room is refused before the deferred redraw.
local stale=label('exit2').click
gmcp.Room.Info={id='B',exits={polnoc='D'}}; raiseEvent('gmcp.Room.Info')
stale(); assert(#sent==2); flush()
-- A changed exit in the same room also invalidates its old callback.
stale=label('exit2').click
gmcp.Room.Info.exits.polnoc='E'; raiseEvent('gmcp.Room.Info')
stale(); assert(#sent==2); flush()
stale=label('exit2').click
raiseEvent('sysDisconnectionEvent')
assert(label('hp').text:find('—',1,true) and label('exit2').text=='')
stale(); assert(#sent==2)
-- Resize uses existing widgets and stays within the available width.
width,height=360,500; raiseEvent('sysWindowResizeEvent'); flush()
for _,widget in pairs(labels) do assert(widget.x>=0 and widget.x+widget.w<=width) end
assert(label('background').y==400)
local handler_count=count(handlers)
for _=1,10 do C=boot(); assert(count(labels)==23 and count(handlers)==handler_count and border==100) end
stale(); assert(#sent==2)
C:stop()
assert(count(labels)==0 and count(handlers)==0 and count(timers)==0 and count(aliases)==0 and border==18)
-- Another package's later border change is not overwritten on shutdown.
C=boot(); border=140; C:stop(); assert(border==140)
border=18
-- Failed styling after label allocation still releases that label and border.
local style=setLabelStyleSheet
local styled=0
setLabelStyleSheet=function(...)
    styled=styled+1
    if styled==5 then error('style failed') end
    return style(...)
end
assert(not pcall(boot))
assert(count(labels)==0 and count(handlers)==0 and count(timers)==0 and border==18)
setLabelStyleSheet=style
C=boot(); assert(C.ui.active); C:stop()
print('PASS standalone footer: native data, clicks, stale events, resize, reload and cleanup')
