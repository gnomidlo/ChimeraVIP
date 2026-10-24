-- ChimeraVIP UI smoke/regression test; run: texlua tools/chimera5_ui_test.lua
local handlers,commands,timers,aliases={}, {}, {}, {}
local windows,border={},0
local function mock_widget(name)
    local w={name=name}
    function w:setStyleSheet() end
    function w:setClickCallback() end
    function w:move() end
    function w:resize() end
    function w:echo() end
    function w:hide() end
    function w:show() end
    function w:delete() end
    return w
end
Geyser={
    Container={new=function(_,attrs) return mock_widget(attrs.name) end},
    Label={new=function(_,attrs,parent) assert(parent); return mock_widget(attrs.name) end},
}
function getMainWindowSize() return 1200,800 end
function setBorderBottom(n) border=n end
function openUserWindow(name) windows[name]="userwindow" end
function windowType(name) return windows[name] end
function showWindow(name) windows[name]="userwindow" end
function hideWindow(name) windows[name]="hidden" end
function setUserWindowTitle() end
function setFontSize() end
function saveWindowLayout() end
function clearWindow() end
function cecho() end
function cechoLink() end
function expandAlias(command) aliases[#aliases+1]=command end
local gmcp={
    room=function() return {id="room",exits={polnoc="next"}} end,
    vitals=function() return {hp=90,mana=55,progress=45} end,
}
local view={self={id="me",hp=90,attackers={}},
    members={{id="friend1",name="Friend",hp=78,attackers={}},
             {id="friend2",name="Friend2",hp=80,attackers={}}},
    enemies={{id="enemy",name="Enemy",hp=50,attackers={}}},others={}}
local team={view=function() return view end}
local locations={room_actions=function() return {} end,run_action=function() end}
local ctx={state={},settings={mode="vip",kondycje=true,akcje=true}}
function ctx:use(n) return ({gmcp=gmcp,team=team,locations=locations})[n] end
function ctx:on(event,fn) handlers[event]=fn end
function ctx:timer(_,fn,repeating) if not repeating then timers[#timers+1]=fn end end
function ctx:command(spec) commands[spec[1]]=spec.fn end
function ctx:cleanup(fn) self.clean=fn end
function ctx:set(key,value)
    self.settings[key]=value
    handlers["chimera.config.changed"]("chimeravip_ui",key,value)
    return true
end
function ctx:send() end
local spec=dofile("plugins/chimeravip_ui/init.lua")
assert(spec.name=="chimeravip_ui" and spec.deps[1]=="gmcp")
local api=spec.setup(ctx)
local function flush()
    local count=0
    while #timers>0 and count<25 do
        local fn=table.remove(timers,1)
        fn()
        count=count+1
    end
end
flush()
assert(api.active() and border==120)
assert(aliases[1]=="/pasek pasek nie")
assert(aliases[2]=="/ustaw kondycje okno nie")
assert(chimera_vip_ui_targets.members.A=="friend1")
assert(chimera_vip_ui_targets.members.B=="friend2")
assert(chimera_vip_ui_targets.enemies["1"]=="enemy")
commands.cvhud("oficjalny")
assert(not api.active() and border==0 and not chimera_vip_ui_targets)
commands.cvhud("vip")
flush()
assert(api.active())
ctx.clean()
assert(not api.active() and not chimera_vip_ui_targets)
print("PASS ChimeraVIP UI switch, dense marks, fallback and teardown")
