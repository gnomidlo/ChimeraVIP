-- ChimeraVIP 0.173: Geyser HUD layout and behaviour regression, Lua 5.1.
local handlers,commands,timers,aliases={},{},{},{}
local widgets,fonts,printed={},{},{}
local windows,fg,border={},nil,0
local bg=nil
local paint_calls=0
local main_width=1200
local kondycje_columns=72
local saved_files,links,log={},{},{}
function getMudletHomeDir() return "/fake/profile" end
function createDirectory() return true end
local function deep_copy(value)
    if type(value)~="table" then return value end
    local out={}
    for k,v in pairs(value) do out[k]=deep_copy(v) end
    return out
end
function table.save(path,value) saved_files[path]=deep_copy(value);return true end
function table.load(path,out)
    local input=assert(saved_files[path],"File not found")
    for k,v in pairs(input) do out[k]=deep_copy(v) end
    return true
end
local function element(name)
    local w={name=name,hidden=false}
    widgets[name]=w
    function w:setStyleSheet(css) paint_calls=paint_calls+1; self.css=css end
    function w:setClickCallback(fn) self.click=fn end
    function w:setToolTip(tip) self.tooltip=tip end
    function w:move(x,y) paint_calls=paint_calls+1; self.x,self.y=x,y end
    function w:resize(width,height) paint_calls=paint_calls+1; self.width,self.height=width,height end
    function w:echo(text) paint_calls=paint_calls+1; self.text=text end
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
function getColumnCount(name) assert(name=="chimeravip_kondycje"); return kondycje_columns end
function setBorderBottom(n) border=n end
function openUserWindow(n) windows[n]="visible" end
function windowType(n) return windows[n] and "userwindow" or nil end
function showWindow(n) windows[n]="visible" end
function hideWindow(n) windows[n]="hidden" end
function setUserWindowTitle() end
function setFontSize(n,size) fonts[n]=size end
function saveWindowLayout() end
function clearWindow() printed={} end
function cecho(v) log[#log+1]=v end
function setFgColor(n,r,g,b) fg=string.format("%d,%d,%d",r,g,b) end
function setBgColor(n,r,g,b) bg=string.format("%d,%d,%d",r,g,b) end
function resetFormat(n) bg=nil;fg=nil end
function echo(n,t) printed[#printed+1]={text=t,color=fg,bg=bg} end
function echoLink(label,command,hint)
    links[#links+1]={label=label,command=command,hint=hint}
    printed[#printed+1]={text=command,color=fg,bg=bg}
end
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
dofile("src/features/context_action.lua")
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
            not name:match("^chimeravip2_1_badge") and
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
-- A no-op room notification (and the status fallback poll) must not
-- repaint Geyser when the official model/GMCP are unchanged.
local idle_paints=paint_calls
handlers["chimera.room.changed"]()
flush()
assert(paint_calls==idle_paints,"Unchanged HUD unnecessarily repainted Geyser")
-- The same cache must not hide real changes in official toggle state.
support=false
handlers["chimera.room.changed"]()
flush()
assert(paint_calls>idle_paints and w("control2").tooltip:find("wyłączone",1,true),
    "Status change was hidden by the footer render cache")
support=true
handlers["chimera.room.changed"]()
flush()
-- One authoritative fresh team.view() mapping for the drawing and aliases.
assert(chimera_vip.ui.resolve_target("member","A")=="ally")
assert(chimera_vip.ui.resolve_target("member","@")=="me")
assert(chimera_vip.ui.resolve_target("enemy","1")=="enemy")
assert(chimera_vip.ui.resolve_target("enemy","2")=="neutral")
local previous_ally=view.members[1]
view.members[1]={id="new-ally",name="Zmieniona",hp=91,attackers={}}
assert(chimera_vip.ui.resolve_target("member","A")=="new-ally",
    "Resolver used a stale rendered mark after a team update")
assert(chimera_vip_ui_targets.members.A=="new-ally")
view.members[1]=previous_ally
assert(chimera_vip.ui.resolve_target("member","A")=="ally")
-- Kondycje: small chess pawn icon BEFORE the letter, no [P]/Z:x% suffix.
-- Changing only henchman must invalidate the cached window signature.
view.self.leader=true
view.members[1].henchman=true
view.members[1].stamina=100  -- old code would print unwanted Z:0%
local before_links=#links
handlers["sysWindowResizeEvent"]()
flush()
local observed={}
for i=before_links+1,#links do
    local item=links[i]
    if item.label=="chimeravip_kondycje" then
        observed[#observed+1]=item.command
    end
end
local actual=table.concat(observed)
assert(actual:find("♟ [A] ",1,true),
    "Pawn icon must occupy leading slot before [A]")
assert(actual:find("★ [@] ",1,true),
    "Team leader star should retain its original leading slot")
assert(not actual:find("[P]",1,true),
    "Old pawn [P] label should be removed")
assert(not actual:find("Z:",1,true),
    "Stamina Z: percentage should be removed from Kondycje")
-- Second pass with same name/hp but no henchman verifies signature refresh.
view.members[1].henchman=false
before_links=#links
handlers["sysWindowResizeEvent"]()
flush()
local later={}
for i=before_links+1,#links do
    if links[i].label=="chimeravip_kondycje" then
        later[#later+1]=links[i].command
    end
end
assert(table.concat(later):find("  [A] ",1,true),
    "Removing henchman flag must restore neutral alignment")
view.members[1].henchman=true
handlers["sysWindowResizeEvent"]()
flush()
-- Restore incoming combat relationships ONCE: who attacks a party
-- member, and which party members are attacking each enemy.
view.self.attacking="enemy"
view.self.attackers={"enemy"}
view.members[1].attacking="enemy" -- outgoing alone must not add a suffix
view.enemies[1].attackers={"ally","me","ally"} -- unsorted and duplicated
view.enemies[1].stunned=true
handlers["sysWindowResizeEvent"]()
flush()
local segments=printed
local enemy_name,enemy_mark,enemy_hp=nil,nil,nil
local visible={}
for _,segment in ipairs(segments) do
    visible[#visible+1]=segment.text
    if segment.text=="Ork" then enemy_name=segment end
    if segment.text=="[1] " then enemy_mark=segment end
    if segment.text:find("28%",1,true) then enemy_hp=segment end
end
local contents=table.concat(visible)
assert(contents:find("JA - [1]",1,true),
    "Party row must show the attacking enemy exactly once")
assert(contents:find("Ork - [@, A]",1,true),
    "Enemy row must show sorted unique attacking party marks")
assert(not contents:find("Lisstana - [1]",1,true),
    "Outgoing attack from an ally must not duplicate the enemy relation")
assert(not contents:find(" ->[",1,true) and not contents:find(" <-[",1,true),
    "Old two-sided arrows must not reappear")
assert(not contents:find("[OGL]",1,true),
    "Stun must be conveyed solely through styling, never [OGL]")
assert(enemy_name and enemy_name.bg=="48,54,69",
    "Only a stunned name must use #303645 background")
assert(enemy_name.color=="240,168,184",
    "Stun must not replace hostile enemy text color with lavender")
assert(enemy_mark and enemy_mark.bg==nil and
    enemy_mark.color=="240,168,184",
    "Enemy marker must retain the normal hostile color and background")
assert(enemy_hp and enemy_hp.bg==nil,
    "Stun must never color an enemy's HP bar")
assert(bg==nil,"Stun background formatting must not leak to relation suffix")

-- Real window column count controls tail-preserving name truncation.
local long_name="Przesadnie bardzo mocno rozgadany opancerzony goblin"
view.enemies[1].name=long_name
kondycje_columns=42
handlers["sysWindowResizeEvent"]()
flush()
local name_tail,combat_suffix=nil,nil
for _,segment in ipairs(printed) do
    if segment.bg=="48,54,69" then name_tail=segment.text end
    if segment.text==" - [@, A]" then combat_suffix=segment end
end
assert(name_tail and name_tail:sub(1,3)=="…" and
    name_tail:find("goblin",1,true),
    "Narrow window should truncate the NAME from the left, preserving its tail")
assert(not name_tail:find("Przesadnie",1,true),
    "Narrow window should remove first name words")
assert(combat_suffix and combat_suffix.bg==nil,
    "The relation must stay visible and outside the stun background")
local visual=function(value)
    local n=0
    for _ in tostring(value):gmatch("[\1-\127\194-\244][\128-\191]*") do n=n+1 end
    return n
end
local enemy_line="  [1] ".."██░░░░░░  28% "..name_tail.." - [@, A]"
assert(visual(enemy_line)<=kondycje_columns,
    "Full rendered enemy row must fit the narrow Kondycje window")
-- A wider pane should restore full names even without new GMCP updates.
kondycje_columns=100
handlers["sysWindowResizeEvent"]()
flush()
local wide={}
for _,segment in ipairs(printed) do wide[#wide+1]=segment.text end
assert(table.concat(wide):find(long_name.." - [@, A]",1,true),
    "Resizing larger must restore the full name (column count in signature)")
-- A single long UTF-8 word must not be chopped into invalid bytes.
view.enemies[1].name="Arcydługowłosyprzebiegłygoblin"
-- Enough columns for the six-letter suffix; more narrow panes
-- necessarily preserve only the last few characters.
kondycje_columns=39
handlers["sysWindowResizeEvent"]()
flush()
local unicode_tail=nil
for _,segment in ipairs(printed) do
    if segment.bg=="48,54,69" then unicode_tail=segment.text end
end
assert(unicode_tail and unicode_tail:sub(1,3)=="…" and
    unicode_tail:find("goblin",1,true),
    "Long Unicode word must retain a usable UTF-8 suffix")
view.self.attacking=nil
view.self.attackers={}
view.members[1].attacking=nil
view.enemies[1].attackers={}
view.enemies[1].stunned=false
view.enemies[1].name="Ork"
kondycje_columns=72
handlers["sysWindowResizeEvent"]()
flush()
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
assert(w("badge1").text:find(">1</b>",1,true),"Action badge must show #1")
assert(w("badge1").css:find("#71658C",1,true),"Lavender badge style missing")
assert(w("action1").text:find("przejrzyj kufer",1,true),
    "Action list should show command, not fixed Ctrl+Shift key")
assert(type(chimera_vip.ui)=="table")
assert(type(chimera_vip.ui.special_exit)=="function")
assert(type(chimera_vip.ui.room_action)=="function")
assert(type(chimera_vip.map_action.run)=="function")
assert(type(chimera_vip.context_action.run)=="function")
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
w("badge1").click()
assert(#called==5 and called[5]==1,"Clicking numbered badge did not run action")
-- When room changes BEFORE the next render, stale visible exit actions
-- must never be sent by the user-supplied keybind.
room={id="next",exits={polnoc="somewhere",gora="up"}}
assert(chimera_vip.ui.special_exit(1)==false)
w("special1").click()
assert(#called==5,"Old room's special exit was sent from stale widget")
-- 0.181: presets change presentation in place, never reconstruct the HUD.
local theme=dofile("plugins/chimeravip_ui/theme.lua")
assert(theme.upper("żółć ąęśźń") == "ŻÓŁĆ ĄĘŚŹŃ")
local original_root=widgets.chimeravip2_footer_1
local original_special=chimera_vip.ui.special_exit
for _,size in ipairs({"m","xl","s","xl","m"}) do
    assert(chimera_vip.ui.set_size(size))
    flush()
    assert(fonts.chimeravip_kondycje==theme.profiles[size].font)
    assert(api.active() and border==theme.profiles[size].height)
    assert(widgets.chimeravip2_footer_1==original_root and chimera_vip.ui.special_exit==original_special)
    for _,width in ipairs({640,760,900,1200,1440}) do
        main_width=width
        handlers.sysWindowResizeEvent(); flush()
        assert(api.active(),"Preset failed on resize: "..size)
        if size~="s" then
            local panels={"section_exits","section_stats","section_needs","section_controls"}
            for i=1,#panels do
                for j=i+1,#panels do assert(not overlap(w(panels[i]),w(panels[j])),"Preset panels overlap") end
            end
            for i=1,3 do
                local track,fill=w("track"..i),w("fill"..i)
                assert(track.height==theme.profiles[size].bar)
                assert(fill.height==(size=="xl" and track.height or track.height/2))
                assert(fill.y==(size=="xl" and track.y or track.y+track.height/2))
                assert(fill.width<=track.width)
                local text={w("gauge"..i),w("value"..i),w("points"..i)}
                for a=1,3 do
                    local item=text[a]
                    assert(item.x>=track.x and item.x+item.width<=track.x+track.width)
                    assert(item.y>=track.y and item.y+item.height<=track.y+track.height)
                    for b=a+1,3 do assert(not overlap(item,text[b]),"Preset text overlaps") end
                end
            end
            assert(w("gauge1").text:find("ŻYCIE",1,true))
            assert(w("points1").text:find("969 / 969",1,true))
            assert(w("points3").text:find("PKT: —",1,true),"No invented energy points")
            assert(w("exp_track").y==border-11)
            assert(original_root.y==-border and original_root.height==border)
            assert(widgets.chimeravip2_floating_1.y==-border-280)
        end
    end
end
-- Uppercase is presentation-only; links retain the original game IDs.
view.members[1].name="Żółta Lisstana"
kondycje_columns=28
handlers["chimera.team.changed"](); flush()
local uppercase=false
for _,entry in ipairs(links) do
    if entry.command:find("ŻÓŁTA LISSTANA",1,true) then
        uppercase=true
        assert(entry.hint:find("ally",1,true),"Uppercase changed the command target")
    end
end
assert(uppercase,"M did not uppercase the Polish display name")
assert(not chimera_vip.ui.set_size("invalid"))
chimera_vip.ui.set_size("s"); flush()
main_width=1200; kondycje_columns=72
handlers.sysWindowResizeEvent(); flush(); geometry()
assert(w("points1").hidden and fonts.chimeravip_kondycje==7,"S did not restore legacy presentation")
location_actions={}
assert(chimera_vip.ui.room_action(1)==false)
w("action1").click()
assert(#called==5,"Stale context action must be inert")
room={id="one",exits={polnoc="north",zachod="west",gora=false,
    ["wejdz do piwnicy"]="inside"}}
location_actions={{key="Ctrl+Shift+1",command="przejrzyj kufer"}}
-- Room-scoped persistent actions: add command, alias, and timed sequence.
commands.cvakcja("dodaj Otworz skrzynie - otworz ciemna skrzynie")
assert(#saved_files["/fake/profile/ChimeraVIP-data/room_actions.lua"].rooms.one==1,
    "Room action was not persisted")
handlers["chimera.room.changed"]()
flush()
assert(w("action2").text:find("Otworz skrzynie",1,true),
    "Custom room action should appear after the official action")
assert(w("badge2").text:find(">2</b>",1,true),"Second badge missing")
assert(chimera_vip.ui.room_action(2)==true)
assert(called[#called]=="otworz ciemna skrzynie","Custom action must send command")
w("action2").click()
assert(called[#called]=="otworz ciemna skrzynie",
    "Click should match Alt+2 custom action")
-- With one custom action, the map bind chooses it automatically.
assert(chimera_vip.map_action:run()==true and
    called[#called]=="otworz ciemna skrzynie",
    "Map bind must use the only local action")
commands.cvakcja("alias Szybka akcja - naps")
commands.cvakcja("alias Magia - /wlm")
handlers["chimera.room.changed"]()
flush()
assert(chimera_vip.ui.room_action(3)==true and aliases[#aliases]=="naps",
    "Alias without a slash was not expanded")
assert(chimera_vip.ui.room_action(4)==true and aliases[#aliases]=="/wlm",
    "Alias with a slash was not expanded")
assert(chimera_vip.map_action:run()==false,
    "Map action must not guess among multiple local actions")
commands.cvakcja("domyslna Magia")
assert(chimera_vip.map_action:status()=="Magia")
assert(chimera_vip.map_action:run()==true and aliases[#aliases]=="/wlm",
    "Explicit map default alias should execute")
commands.cvakcja("sekwencja Wielki test - wez klucz, otworz drzwi, wejdz")
local before=#called
assert(chimera_vip.ui.room_action(5)==true,"Sequence should be runnable")
assert(#called==before+1 and called[#called]=="wez klucz",
    "Sequence first step should execute instantly")
flush()
assert(called[#called-1]=="otworz drzwi" and called[#called]=="wejdz",
    "Sequence must send separate ordered commands")
commands.cvakcja("dodaj Otworz skrzynie - obejrzyj skrzynie")
assert(#saved_files["/fake/profile/ChimeraVIP-data/room_actions.lua"].rooms.one==4,
    "Adding same name should update existing action, not duplicate")
assert(chimera_vip.ui.room_action(2)==true and
    called[#called]=="obejrzyj skrzynie","Updated action was not applied")
local link_count=#links
commands.cvakcja("")
assert(#links==link_count+4,"Help must present clickable deletion for four actions")
assert(links[link_count+1].label:find("usun",1,true) and
    links[link_count+1].command:find("chimera_vip.ui.delete_action",1,true),
    "Help should have a clickable deletion link")
local remove_click=assert(loadstring(links[link_count+1].command))
remove_click()
assert(#saved_files["/fake/profile/ChimeraVIP-data/room_actions.lua"].rooms.one==3,
    "Click-to-delete must remove selected action")
assert(chimera_vip.ui.room_action(2)==true and aliases[#aliases]=="naps",
    "After deletion, next custom action must occupy slot 2")
-- Old links must be inert if the player moves to a different room.
commands.cvakcja("")
local expired=assert(loadstring(links[#links].command))
room={id="somewhere-else",exits={polnoc="there"}}
local last=#called
expired()
assert(#saved_files["/fake/profile/ChimeraVIP-data/room_actions.lua"].rooms.one==3,
    "Old delete link must not modify another room")
assert(chimera_vip.ui.room_action(2)==false,
    "Saved actions must be scoped to their GMCP room id")
assert(chimera_vip.ui.room_action(1)==true,"Official actions still work")
room={id="one",exits={polnoc="north",zachod="west",gora=false,
    ["wejdz do piwnicy"]="inside"}}
-- New room must not contain other room's saved data.
commands.cvakcja("dodaj Pusty test - cos")
room={id="somewhere-else",exits={polnoc="there"}}
assert(chimera_vip.map_action:run()==false,
    "Map action must not execute previous room's default")
assert(chimera_vip.ui.room_action(2)==false,
    "An entry added to the previous room leaked into this room")
room={id="one",exits={polnoc="north",zachod="west",gora=false,
    ["wejdz do piwnicy"]="inside"}}
commands.cvakcja("usun Pusty test")
assert(chimera_vip.map_action:run()==true and aliases[#aliases]=="/wlm",
    "Map action must preserve default on unrelated deletion")
assert(saved_files["/fake/profile/ChimeraVIP-data/room_actions.lua"].rooms.one[3].name=="Wielki test",
    "Name-based deletion did not work")
-- Invalid sequence must leave the list intact.
local n=#saved_files["/fake/profile/ChimeraVIP-data/room_actions.lua"].rooms.one
commands.cvakcja("domyslna brak")
assert(chimera_vip.map_action:run()==false,"Unset map default must not guess")
commands.cvakcja("domyslna Magia")
assert(chimera_vip.map_action:run()==true and aliases[#aliases]=="/wlm",
    "Map default should be configurable again")
commands.cvakcja("sekwencja Bledna - 1, , 3")
assert(#saved_files["/fake/profile/ChimeraVIP-data/room_actions.lua"].rooms.one==n,
    "Blank sequence step should be rejected")
-- Test persistence after plugin reload, retaining action data in memory.
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
room={id="empty",exits={polnoc="north"}}
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
assert(chimera_vip.map_action._runner==nil and chimera_vip.map_action._status==nil,
    "Map action callback must be detached on cleanup")
assert(chimera_vip.ui.special_exit==nil and chimera_vip.ui.room_action==nil
    and chimera_vip.ui.delete_action==nil and chimera_vip.ui.resolve_target==nil,
    "Public APIs must be removed on plugin cleanup")
room={id="one",exits={polnoc="north"}}
ctx.state={}
ctx.settings.mode="oficjalny"
local second=plugin.setup(ctx)
assert(type(chimera_vip.ui.room_action)=="function",
    "Public action API not restored on reload")
assert(chimera_vip.ui.room_action(1)==true and aliases[#aliases]=="naps",
    "Saved local action did not survive a plugin reload")
assert(chimera_vip.map_action:run()==true and aliases[#aliases]=="/wlm",
    "Persisted map default should survive plugin reload")
ctx.cleanup()
print("PASS 0.176: local persistence, numbered clickable Geyser actions, command/alias/sequence, stale safety")
