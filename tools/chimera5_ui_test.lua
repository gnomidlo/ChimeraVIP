-- ChimeraVIP UI regression tests — Lua 5.1 compatible, no Mudlet.
local handlers,commands,timers,aliases={},{},{},{}
local widgets,fonts,printed={}, {}, {}
local windows,fg,border={},nil,0
local main_width=1200
local function element(name)
    local w={name=name,hidden=false}
    widgets[name]=w
    function w:setStyleSheet(css) self.css=css end
    function w:setClickCallback(fn) self.click=fn end
    function w:move(x,y) self.x,self.y=x,y end
    function w:resize(x,y) self.width,self.height=x,y end
    function w:echo(value) self.text=value end
    function w:hide() self.hidden=true end
    function w:show() self.hidden=false end
    function w:delete() self.deleted=true end
    return w
end
Geyser={
    Container={new=function(_,a) return element(a.name) end},
    Label={new=function(_,a,parent) assert(parent);return element(a.name) end},
}
function getMainWindowSize() return main_width,800 end
function setBorderBottom(value) border=value end
function openUserWindow(name) windows[name]="visible" end
function windowType(name) return windows[name] and "userwindow" or nil end
function showWindow(name) windows[name]="visible" end
function hideWindow(name) windows[name]="hidden" end
function setUserWindowTitle() end
function setFontSize(name,n) fonts[name]=n end
function clearWindow() printed={} end
function saveWindowLayout() end
function cecho() end
function setFgColor(name,r,g,b) fg=string.format("%d,%d,%d",r,g,b) end
function echo(name,value) printed[#printed+1]={text=value,color=fg} end
function echoLink(name,value) printed[#printed+1]={text=value,color=fg} end
function expandAlias(value) aliases[#aliases+1]=value end
local room={id="one",exits={polnoc="two",zachod="three",["wejdz do piwnicy"]="four"}}
local vitals={hp=82,mana=67,fatigue=45,thirst=12,hunger=4,encumbrance=38,panic=0,progress=71}
local gmcp_api={
    room=function() return room end,
    vitals=function() return vitals end,
    group=function() return {members={{id="me",self=1,mana=80,maxmana=120}}} end,
}
local view={
    self={id="me",name="JA",hp=82,hp_now=123,hp_max=150,attackers={}},
    members={{id="a",name="Lisstana",hp=74,attackers={}}},
    enemies={{id="enemy",name="Ork",hp=28,attackers={}}},
    others={{id="npc",name="Neutral",hp=100,attackers={}}}
}
local team={view=function() return view end}
local actions={
    {key="Ctrl+Shift+1",command="przejrzyj kufer"},
    {key="Ctrl+Shift+2",command="otworz schowek"}
}
local executed={}
local locations={
    room_actions=function() return actions end,
    run_action=function(i) executed[#executed+1]=i end,
}
local ctx={state={},settings={mode="vip",kondycje=true,czcionka=7,akcje=true}}
function ctx:use(name)
    return ({gmcp=gmcp_api,team=team,locations=locations})[name]
end
function ctx:on(name,fn) handlers[name]=fn end
function ctx:timer(seconds,fn,repeating) if not repeating then timers[#timers+1]=fn end end
function ctx:command(spec) commands[spec[1]]=spec.fn end
function ctx:cleanup(fn) self.cleanup=fn end
function ctx:set(key,value)
    self.settings[key]=value
    handlers["chimera.config.changed"]("chimeravip_ui",key,value)
    return true
end
function ctx:send(value) executed[#executed+1]=value end
local spec=dofile("plugins/chimeravip_ui/init.lua")
assert(spec.name=="chimeravip_ui" and spec.settings.czcionka.default==7)
local api=spec.setup(ctx)
local function flush()
    local n=0
    while #timers>0 and n<40 do
        local fn=table.remove(timers,1)
        fn()
        n=n+1
    end
end
flush()
local function w(name) return assert(widgets["chimeravip2_1_"..name],name) end
assert(api.active() and border==76,"VIP footer must remain exactly 76px")
assert(fonts.chimeravip_kondycje==7,"Kondycje default 7pt")
assert(w("gauge1").text:find("HP: 123/150 82%%"),"HP x/y percentage missing")
assert(w("gauge2").text:find("MP: 80/120 67%%"),"MP x/y percentage missing")
assert(w("gauge3").text:find("ZM: 45%%"),"fatigue percentage fallback missing")
assert(w("exp_percent").text:find("71%%"),"EXP missing from bottom strip")
assert(w("exp_track").y==58,"EXP rail must stay inside stats panel")
assert(w("exp_over_track").hidden,"No overflow bar at 71 percent")
for i,label in ipairs({"PR 12%","GL 4%","OBC 38%","PAN 0%"}) do
    assert(w("gauge"..(i+3)).text:find(label,1,true),label)
end
assert(w("fill1").height==3,"HP fill must be a subtle bottom line")
assert(w("fill1").css:find("#69C9A1",1,true),"HP at 82 percent should be green")
assert(w("fill2").css:find("#D7B56B",1,true),"MP at 67 percent should be amber")
assert(w("section_stats").css:find("#232938",1,true),"slate section panel missing")
assert(w("exit_up").text:find("GORA",1,true) and w("exit_down").text:find("DOL",1,true),"vertical compass labels missing")
assert(w("fill1").css:find("#69C9A1",1,true),"82% HP should be green")
assert(w("fill2").css:find("#D7B56B",1,true),"67% mana should be amber")
assert(w("fill3").css:find("#D7B56B",1,true),"45% fatigue should be amber")
assert(w("section_exits").css:find("#232938",1,true),"footer background missing")

assert(not w("exit2").css:find("background%-color"),"compass should not resemble buttons")
assert(w("special1").text:find("wejdz",1,true),"nonstandard exits missing")
assert(not w("action_bg").hidden,"context actions should be visible")
assert(w("action1").text:find("Ctrl+Shift+1",1,true),"real key label missing")
assert(w("action2").text:find("Ctrl+Shift+2",1,true),"second action missing")
assert(w("action_bg").css:find("rgba",1,true),"popup must be translucent")
w("action2").click()
assert(#executed==1 and executed[1]==2,"click must invoke official run_action")
local npc_color=nil
for _,line in ipairs(printed) do
    if line.text=="Neutral" then npc_color=line.color end
end
assert(npc_color=="189,196,206","neutral NPC should not be red")
assert(not table.concat((function() local out={} for _,v in ipairs(printed) do out[#out+1]=v.text end return out end)(),""):find("◆",1,true),"section headings should have no diamond")
assert(aliases[1]=="/pasek pasek nie" and aliases[2]=="/ustaw kondycje okno nie")
ctx:set("czcionka",8)
assert(fonts.chimeravip_kondycje==8,"font change not applied")
actions={}
handlers["chimera.room.changed"]({id="two"})
flush()
assert(w("action_bg").hidden or widgets["chimeravip2_floating_1"].hidden,
    "empty locations must hide floating popup")
w("action1").click()
assert(#executed==1,"stale click ran an action after room change")
actions={{key="Alt+F1",command="zbadaj sciane"}}
handlers["chimera.locations.actions"]()
flush()
assert(w("action1").text:find("Alt+F1",1,true),"changed official binding not updated")
ctx:set("akcje",false)
flush()
assert(w("action_bg").hidden or widgets["chimeravip2_floating_1"].hidden,
    "disabled context actions remain visible")
vitals.progress=137
handlers["chimera.room.changed"]()
flush()
assert(w("exp_percent").text:find("+37%%"),"overcap event progress not reflected")
assert(not w("exp_extra").hidden,"overflow strip missing")
assert(not w("exp_over_track").hidden,"overflow background missing")
assert(w("exp_extra").y==65 and w("exp_base").y==58,"EXP base and overflow rails overlap")
local function touches(a,b)
    return a.x < b.x+b.width and b.x < a.x+a.width
        and a.y < b.y+b.height and b.y < a.y+a.height
end
local function verify_geometry()
    for name,item in pairs(widgets) do
        if name:match("^chimeravip2_1_") and
            not name:match("^chimeravip2_1_action") and
            item.hidden==false and item.x~=nil then
            assert(item.x>=0 and item.y>=0 and item.width>0 and item.height>0
                and item.x+item.width<=main_width
                and item.y+item.height<=76,
                string.format("Widget outside HUD at width %d: %s (%s,%s) %sx%s",
                    main_width,name,tostring(item.x),tostring(item.y),
                    tostring(item.width),tostring(item.height)))
        end
    end
    local rail=w("exp_track")
    local stats=w("section_stats")
    assert(rail.x>=stats.x and rail.x+rail.width<=stats.x+stats.width,
        "EXP rail escaped central section")
    assert(not touches(rail,w("exp_percent")) and not touches(rail,w("exp_label")),
        "EXP rail overlaps text")
    for i=1,9 do
        assert(not touches(w("exit"..i),w("exit_up")),
            "GORA overlaps compass")
        assert(not touches(w("exit"..i),w("exit_down")),
            "DOL overlaps compass")
    end
    for i=1,3 do
        local special=w("special"..i)
        if not special.hidden then
            assert(not touches(special,w("exit_up"))
                and not touches(special,w("exit_down")),
                "vertical exits overlap special exits")
        end
    end
end
for _,width in ipairs({760,1024,1200,1440}) do
    main_width=width
    handlers["sysWindowResizeEvent"]()
    flush()
    assert(api.active(),"resize deactivated footer")
    verify_geometry()
end
commands.cvhud("oficjalny")
assert(not api.active() and border==0 and not chimera_vip_ui_targets)
commands.cvhud("vip")
flush()
assert(api.active())
ctx.cleanup()
assert(not api.active() and not chimera_vip_ui_targets)
assert(widgets["chimeravip2_floating_1"].hidden,"cleanup did not hide popup")
print("PASS 0.172: footer bounds at 760/1024/1200/1440, compass, EXP, switchback")
