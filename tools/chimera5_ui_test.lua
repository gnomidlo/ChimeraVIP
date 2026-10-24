-- ChimeraVIP 0.173: Geyser HUD layout and behaviour regression, Lua 5.1.
local handlers,commands,timers,aliases={},{},{},{}
local widgets,fonts,printed={},{},{}
local windows,fg,border={},nil,0
local main_width=1200
local function element(name)
    local w={name=name,hidden=false}
    widgets[name]=w
    function w:setStyleSheet(css) self.css=css end
    function w:setClickCallback(fn) self.click=fn end
    function w:setToolTip(tip) self.tooltip=tip end
    function w:move(x,y) self.x,self.y=x,y end
    function w:resize(width,height) self.width,self.height=width,height end
    function w:echo(text) self.text=text end
    function w:hide() self.hidden=true end
    function w:show() self.hidden=false end
    function w:delete() self.deleted=true end
    return w
end
Geyser={
    Container={new=function(_,props) return element(props.name) end},
    Label={new=function(_,props,parent) assert(parent);return element(props.name) end},
}
function getMainWindowSize() return main_width,800 end
function setBorderBottom(n) border=n end
function openUserWindow(n) windows[n]="visible" end
function windowType(n) return windows[n] and "userwindow" or nil end
function showWindow(n) windows[n]="visible" end
function hideWindow(n) windows[n]="hidden" end
function setUserWindowTitle() end
function setFontSize(n,size) fonts[n]=size end
function saveWindowLayout() end
function clearWindow() printed={} end
function cecho() end
function setFgColor(n,r,g,b) fg=string.format("%d,%d,%d",r,g,b) end
function echo(n,t) printed[#printed+1]={text=t,color=fg} end
function echoLink(n,t) printed[#printed+1]={text=t,color=fg} end
function expandAlias(t) aliases[#aliases+1]=t end
local room={id="one",exits={polnoc="north",zachod="west",gora=false,
    ["wejdz do piwnicy"]="inside"}}
local vitals={hp=100,mana=100,fatigue=20,thirst=96,hunger=83,
    encumbrance=38,panic=0,progress=71}
local gmcp_api={
    room=function() return room end,
    vitals=function() return vitals end,
    group=function() return {members={{id="me",self=true,hp=969,maxhp=969,
        mana=120,maxmana=120}}} end,
}
local view={
    self={id="me",name="JA",hp=100,hp_now=969,hp_max=969,attackers={}},
    members={{id="ally",name="Lisstana",hp=74,attackers={}}},
    enemies={{id="enemy",name="Ork",hp=28,attackers={}}},
    others={{id="neutral",name="Veith",hp=100,attackers={}}},
}
local team={view=function() return view end}
local location_actions={{key="Ctrl+Shift+1",command="przejrzyj kufer"}}
local called={}
local locations={
    room_actions=function() return location_actions end,
    run_action=function(i) called[#called+1]=i end,
}
local support=true
local follow=false
local official_model={
    mode="Atak",toggles={
        {command="/autowsparcie",on=support},
        {command="/autopogon",on=follow},
    },
    collect={on=true},
}
local status_bar={model=function() 
    official_model.toggles[1].on=support
    official_model.toggles[2].on=follow
    return official_model
end}
local lamp={state=function() return {lit=true} end}
chimera_vip={settings={is_module_enabled=function(self,name)
    return name=="combat_colors"
end}}
local ctx={state={},settings={mode="vip",kondycje=true,czcionka=7,akcje=true}}
function ctx:use(n)
    return ({gmcp=gmcp_api,team=team,locations=locations,status_bar=status_bar,lamp=lamp})[n]
end
function ctx:on(e,fn) handlers[e]=fn end
function ctx:timer(_,fn,repeating) if not repeating then timers[#timers+1]=fn end end
function ctx:command(spec) commands[spec[1]]=spec.fn end
function ctx:cleanup(fn) self.cleanup=fn end
function ctx:set(k,v)
    self.settings[k]=v
    handlers["chimera.config.changed"]("chimeravip_ui",k,v)
end
function ctx:send(v) called[#called+1]=v end
local plugin=dofile("plugins/chimeravip_ui/init.lua")
assert(plugin.name=="chimeravip_ui" and plugin.settings.czcionka.default==7)
local api=plugin.setup(ctx)
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
local function overlap(a,b)
    return a.x<b.x+b.width and b.x<a.x+a.width
        and a.y<b.y+b.height and b.y<a.y+a.height
end
local function geometry()
    assert(border==76,"HUD must be exactly 76px")
    local footer_panels={"section_exits","section_stats","section_needs","section_controls"}
    for _,name in ipairs(footer_panels) do
        local panel=w(name)
        assert(not panel.hidden and panel.y==4 and panel.height==53,
            "Panel has wrong height: "..name)
    end
    for i=1,#footer_panels do
        for j=i+1,#footer_panels do
            assert(not overlap(w(footer_panels[i]),w(footer_panels[j])),
                "Top-level footer panels overlap")
        end
    end
    local foot=w("hud_background")
    assert(foot.width==main_width and foot.height==76)
    for name,item in pairs(widgets) do
        if name:match("^chimeravip2_1_") and
            not name:match("^chimeravip2_1_action") and
            not item.hidden and item.x then
            assert(item.x>=0 and item.y>=0 and item.width>0 and item.height>0
                and item.x+item.width<=main_width
                and item.y+item.height<=76,
                "Widget outside footer: "..name)
        end
    end
    for i=1,9 do
        assert(not overlap(w("exit"..i),w("exit_up")),
            "Up arrow intersects compass")
        assert(not overlap(w("exit"..i),w("exit_down")),
            "Down arrow intersects compass")
    end
    for i=1,3 do
        local s=w("special"..i)
        if not s.hidden then
            assert(not overlap(s,w("exit_up")) and
                not overlap(s,w("exit_down")),"special exit intersects arrow")
        end
    end
    -- Every need is a separate, equal, non-overlapping row.
    for i=4,7 do
        local row=w("track"..i)
        assert(row.height==11,"Need row is not 11px: "..i)
        assert(row.x>=w("section_needs").x and
            row.x+row.width<=w("section_needs").x+w("section_needs").width)
        if i>4 then assert(not overlap(row,w("track"..(i-1))),
            "Need rows overlap") end
    end
    local rail=w("exp_track")
    assert(rail.y==65 and rail.height==7,"EXP not at the very bottom")
    assert(not overlap(rail,w("exp_label")) and not overlap(rail,w("exp_percent")),
        "EXP bar intersects label or percent")
    assert(rail.x+rail.width<w("exp_percent").x,"EXP value is behind bar")
    assert(w("section_needs").y+w("section_needs").height<=rail.y,
        "PANIKA is covered by EXP")
end
assert(api.active() and fonts.chimeravip_kondycje==7)
geometry()
assert(w("gauge1").text:find("życie",1,true))
assert(w("gauge2").text:find("mana",1,true))
assert(w("gauge3").text:find("siły",1,true))
assert(w("value1").text:find("969/969 100%",1,true))
assert(w("value2").text:find("120/120 100%",1,true))
assert(w("value3").text:find("80%",1,true),
    "Available energy must be 100 - fatigue")
assert(w("fill1").css:find("#69C9A1",1,true),"Full life should be mint green")
assert(w("fill2").css:find("#639EDB",1,true),"Mana MUST stay blue at 100%")
assert(w("fill3").css:find("#D8B671",1,true),"Available energy should be amber")
assert(w("fill1").height==7 and w("fill2").height==7)
for i,name in ipairs({"pragnienie","głód","obciążenie","panika"}) do
    assert(w("gauge"..(i+3)).text:find(name,1,true),name)
end
assert(w("need_value4").text:find("96%",1,true))
assert(w("need_value5").text:find("83%",1,true))
assert(w("need_value6").text:find("38%",1,true))
assert(w("need_value7").text:find("0%",1,true))
assert(w("exit2").css:find("#86E7BC",1,true),
    "Available north should be lit")
assert(w("exit4").css:find("#86E7BC",1,true),
    "Available west should be lit")
assert(w("exit6").css:find("#4A5363",1,true),
    "Unavailable east should be dimmed")
assert(w("exit_up").css:find("#86E7BC",1,true),
    "Existing up exit with false GMCP target must still be lit")
-- Guard against Mudlet QLabel rich text ignoring only CSS foreground:
-- active directions must contain green and bold HTML; disabled ones
-- contain the much dimmer color without bold markup.
assert(w("exit2").text:find("<font color='#86E7BC'><b>N</b></font>",1,true),
    "Active direction must have explicit green bold rich text")
assert(w("exit4").text:find("<font color='#86E7BC'><b>W</b></font>",1,true),
    "West active direction rich text missing")
assert(w("exit6").text:find("<font color='#4A5363'>E</font>",1,true),
    "Disabled direction must be explicitly dim")
assert(w("exit_up").text:find("<font color='#86E7BC'><b>↑</b></font>",1,true),
    "Available up arrow must be green and bold")
assert(w("exit_down").text:find("<font color='#4A5363'>↓</font>",1,true),
    "Unavailable down arrow must be dim without bold")
assert(w("special1").text:find("wejdz",1,true))
assert(w("control1").text:find("⚔",1,true))
assert(w("control1").tooltip:find("Atak",1,true))
assert(w("control2").tooltip:find("włączone",1,true))
assert(w("control3").tooltip:find("wyłączona",1,true)
    or w("control3").tooltip:find("wyłączone",1,true))
assert(w("control5").tooltip:find("włączone",1,true))
assert(w("control6").tooltip:find("włączone",1,true))
assert(not w("action_bg").hidden)
assert(type(chimera_vip.ui)=="table")
assert(type(chimera_vip.ui.special_exit)=="function")
assert(type(chimera_vip.ui.room_action)=="function")
-- Bind in Mudlet's Keys editor: chimera_vip.ui.special_exit(1)
assert(chimera_vip.ui.special_exit(1)==true)
assert(#called==1 and called[1]=="wejdz do piwnicy",
    "Special exit #1 did not dispatch current GMCP exit")
w("special1").click()
assert(#called==2 and called[2]==called[1],
    "Click and custom keybind must dispatch the same special exit")
assert(chimera_vip.ui.special_exit(2)==false and
    chimera_vip.ui.special_exit(0)==false and
    chimera_vip.ui.special_exit(1.5)==false and
    chimera_vip.ui.special_exit("abc")==false and
    chimera_vip.ui.special_exit(nil)==false)
assert(#called==2,"Missing/invalid special exits must send nothing")
-- Context actions can also be bound in Keys editor as Alt+1/2/3.
assert(chimera_vip.ui.room_action(1)==true)
assert(#called==3 and called[3]==1,"Alt+1 context action wrapper failed")
w("action1").click()
assert(#called==4 and called[4]==1,
    "Action mouse click and Alt key should invoke same official API")
assert(chimera_vip.ui.room_action(2)==false and
    chimera_vip.ui.room_action(0)==false and
    chimera_vip.ui.room_action(13)==false and
    chimera_vip.ui.room_action(2.7)==false)
assert(#called==4,"Missing/invalid room actions must be inert")
-- When room changes BEFORE the next render, stale visible exit actions
-- must never be sent by the user-supplied keybind.
room={id="next",exits={polnoc="somewhere",gora="up"}}
assert(chimera_vip.ui.special_exit(1)==false)
w("special1").click()
assert(#called==4,"Old room's special exit was sent from stale widget")
location_actions={}
assert(chimera_vip.ui.room_action(1)==false)
w("action1").click()
assert(#called==4,"Stale context action must be inert")
room={id="one",exits={polnoc="north",zachod="west",gora=false,
    ["wejdz do piwnicy"]="inside"}}
location_actions={{key="Ctrl+Shift+1",command="przejrzyj kufer"}}
local neutral_color=nil
for _,line in ipairs(printed) do
    if line.text=="Veith" then neutral_color=line.color end
end
assert(neutral_color=="189,196,206","POZOSTALI must be neutral")
vitals.progress=137
handlers["chimera.room.changed"]()
flush()
assert(not w("exp_extra").hidden and w("exp_extra").y==70)
assert(w("exp_percent").text:find("+37%",1,true))
geometry()
vitals.fatigue=65
handlers["gmcp.Char.Vitals"]()
flush()
assert(w("value3").text:find("35%",1,true),"Energy inversion not updated")
-- Natural resize, before switching to the official HUD.
for _,width in ipairs({760,900,1024,1200,1440}) do
    main_width=width
    handlers["sysWindowResizeEvent"]()
    flush()
    assert(api.active(),"HUD crashed on resize")
    geometry()
end
location_actions={}
handlers["chimera.room.changed"]()
flush()
assert(w("action_bg").hidden or widgets["chimeravip2_floating_1"].hidden)
commands.cvhud("oficjalny")
assert(not api.active() and border==0)
commands.cvhud("vip")
flush()
assert(api.active())
ctx.cleanup()
assert(not api.active() and widgets["chimeravip2_floating_1"].hidden)
assert(chimera_vip.ui.special_exit==nil and chimera_vip.ui.room_action==nil,
    "Public bind API must be removed on plugin cleanup")
print("PASS 0.173: approved 76px Geyser layout, colors, compass, needs, EXP, icons, mouseovers")
