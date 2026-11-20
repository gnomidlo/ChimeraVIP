-- Off-game regression tests for ChimeraVIP Magia.
local printed,sent,timers={},{},{}
local next_id=0
function hecho(s) printed[#printed+1]=tostring(s or "") end
function getMudletHomeDir() return "/tmp" end
function tempTimer(sec,fn,repeat_flag)
    next_id=next_id+1
    timers[next_id]={seconds=sec,callback=fn,repeating=repeat_flag}
    return next_id
end
function killTimer(id) timers[id]=nil end
function tempRegexTrigger() return 1 end
function killTrigger() end
function tempAlias() return 1 end
function killAlias() end
local events={}
function registerAnonymousEventHandler(name,callback)
    events[name]=callback
    return 1
end
function killAnonymousEventHandler() end
function send(s) sent[#sent+1]=s end
local background_calls={}
function setBackgroundColor(name,r,g,b,a)
    background_calls[#background_calls+1]={name=name,r=r,g=g,b=b,a=a}
end

chimera_vip={root_dir="/tmp/cvip-magia-test"}
dofile("src/core/util.lua")
local U=chimera_vip.util
U.file_exists=function() return false end
U.ensure_dir=function() return false end
chimera_vip.magia={}
local M=chimera_vip.magia
M.show_window=function() return true end
M.render=function() end
chimera_vip.xp_tracker={get_present_retainers=function()
    return {{id="npc-1",name="Zathrica"},{id="npc-2",name="Uzzarnia"}}
end}
gmcp={Char={Name={name="Veesa"}}}
dofile("src/features/magia.lua")

assert(M.parse_duration("25 godzin")==25*3600)
assert(M.parse_duration("1 godzine")==3600)
assert(M.parse_duration("2 godziny")==7200)
assert(M.parse_duration("1 dzien i 3 godziny")==27*3600)
assert(M.parse_duration("15 minut")==900)
assert(M.parse_duration("bez terminu")==nil)
assert(M.format(25*3600)=="~25h")

assert(M:scan())
assert(sent[1]=="efekty","start from own effects")
local function parse_lines(lines)
    for _,s in ipairs(lines) do M:on_line(s) end
end
parse_lines({
    "Kamienie Milowe:",
    "Magiczne przedmioty, ktore masz na sobie:",
    "  kamienny olbrzymi miecz",
    "   Dzialanie: nie potrafisz rozpoznac mocy.",
    "   Rozsypie sie w pyl za okolo 25 godzin.",
    "  zakorkowana szklana buteleczka",
    "   Dzialanie: nie potrafisz rozpoznac mocy.",
    "   Rozsypie sie w pyl za okolo 1 godzine.",
    "Kradziez zycia:",
})
assert(#M.data.owners["@"].items==2)
assert(sent[2]=="parozkaz npc-1 efekty","first retainer by GMCP ID")
parse_lines({
    "Magiczne przedmioty, ktore ma na sobie:",
    "  dlugi zaostrzony kord",
    "   Dzialanie: nie potrafisz rozpoznac mocy.",
    "   Rozsypie sie w pyl za okolo 2 godziny.",
    "  matowy pierscien",
    "   Dzialanie: dlugi opis pierscienia z Neverwinter.",
    "   Rozsypie sie w pyl za okolo 14 godzin.",
    "  matowy pierscien",
    "   Dzialanie: ten sam opis, lecz drugi przedmiot.",
    "   Rozsypie sie w pyl za okolo 16 godzin.",
    "Kradziez zycia:",
})
assert(#M.data.owners["npc-1"].items==3,"do not collapse duplicate rings")
assert(M.data.owners["npc-1"].items[2].expiry~=M.data.owners["npc-1"].items[3].expiry)
assert(sent[3]=="parozkaz npc-2 efekty")
parse_lines({
    "Magiczne przedmioty, ktore ma na sobie:",
    "  okragla poswiecona tarcza",
    "   Rozsypie sie w pyl za okolo 35 godzin.",
    "Kradziez zycia:",
})
assert(#M.data.owners["npc-2"].items==1)
assert(M.queue==nil and M.current==nil)
assert(#M:rows()==6)
-- Partial response does not erase complete snapshot.
M.current={id="npc-2",name="Uzzarnia",self=false}
parse_lines({
    "Magiczne przedmioty, ktore ma na sobie:",
    "  okragla poswiecona tarcza",
    "  matowy pierscien",
    "   Rozsypie sie w pyl za okolo 15 godzin.",
    "Kradziez zycia:",
})
assert(#M.data.owners["npc-2"].items==1,"incomplete data must not replace prior results")
assert(M:shortest("@")~=nil)
-- New compact view must include JA despite several urgent retainer items.
M.data.mode="compact"
local display
-- Test manual self 'efekty' header that is indented by the client.
M:on_line("   Magiczne przedmioty, ktore masz na sobie:")
M:on_line("  kamienny olbrzymi miecz")
M:on_line("   Rozsypie sie w pyl za okolo 25 godzin.")
M:on_line("Kradziez zycia:")
assert(#M.data.owners["@"].items==1,"own manual effects should update JA")
-- Regression from a real three-character response: "lada chwila" is not
-- numeric, but MUST be stored, shown as critical and count as a valid item.
-- Two otherwise identical rings with different times remain separate.
local previous_output=#printed
assert(M:scan())
parse_lines({
    "Kamienie Milowe:",
    "Magiczne przedmioty, ktore masz na sobie:",
    "  runiczna rycerska zbroja plytowa",
    "    Dzialanie: nie potrafisz rozpoznac mocy.",
    "    Rozsypie sie w pyl za okolo 7 godzin.",
    "  runiczna dziobata przylbica",
    "    Dzialanie: nie potrafisz rozpoznac mocy.",
    "    Rozsypie sie w pyl lada chwila.",
    "  kamienny olbrzymi miecz",
    "    Dzialanie: nie potrafisz rozpoznac mocy.",
    "    Rozsypie sie w pyl za okolo 24 godziny.",
    "  zakorkowana szklana buteleczka",
    "    Dzialanie: nie potrafisz rozpoznac mocy.",
    "    Rozsypie sie w pyl lada chwila.",
    "Kradziez zycia:",
})
assert(#M.data.owners["@"].items==4,"all 4 own items including two imminent")
assert(M.data.owners["@"].items[2].imminent)
assert(M.data.owners["@"].items[4].imminent)
assert(M:format_item(M.data.owners["@"].items[2])=="lada chwila")
assert(M:remaining(M.data.owners["@"].items[2])==0)
assert(sent[#sent]=="parozkaz npc-1 efekty")
parse_lines({
    "Specjalizacje:",
    "Magiczne przedmioty, ktore ma na sobie:",
    "  dlugi zaostrzony kord",
    "    Dzialanie: nie potrafisz rozpoznac mocy.",
    "    Rozsypie sie w pyl za okolo 1 godzine.",
    "  blekitny kunsztowny sejmitar",
    "    Dzialanie: nie potrafisz rozpoznac mocy.",
    "    Rozsypie sie w pyl lada chwila.",
    "  matowy pierscien",
    "    Dzialanie: Wiedza jaka posiadasz odkrywa czesc tajemnic tego pierscienia.",
    "    Rozsypie sie w pyl za okolo 13 godzin.",
    "  matowy pierscien",
    "    Dzialanie: Wiedza jaka posiadasz odkrywa czesc tajemnic tego pierscienia.",
    "    Rozsypie sie w pyl za okolo 15 godzin.",
    "Kradziez zycia:",
})
assert(#M.data.owners["npc-1"].items==4)
assert(sent[#sent]=="parozkaz npc-2 efekty")
parse_lines({
    "Magiczne przedmioty, ktore ma na sobie:",
    "  runiczna dziobata przylbica",
    "    Dzialanie: nie potrafisz rozpoznac mocy.",
    "    Rozsypie sie w pyl za okolo 12 godzin.",
    "  runiczna rycerska zbroja plytowa",
    "    Rozsypie sie w pyl za okolo 12 godzin.",
    "  okragla poswiecona tarcza",
    "    Rozsypie sie w pyl za okolo 34 godziny.",
    "  blekitny kunsztowny sejmitar",
    "    Rozsypie sie w pyl za okolo 25 godzin.",
    "  matowy pierscien",
    "    Dzialanie: Wiedza jaka posiadasz odkrywa czesc tajemnic tego pierscienia. Stworzyl go mlody elf.",
    "    Rozsypie sie w pyl za okolo 14 godzin.",
    "  matowy pierscien",
    "    Dzialanie: Wiedza jaka posiadasz odkrywa czesc tajemnic tego pierscienia. Stworzyl go mlody elf.",
    "    Rozsypie sie w pyl za okolo 29 godzin.",
    "Kradziez zycia:",
})
assert(#M.data.owners["npc-2"].items==6,"all six with duplicate rings")
assert(#M:rows()==14,"4+4+6 should be retained after complete scan")
assert(M.queue==nil and M.current==nil)
for i=previous_output+1,#printed do
    assert(not printed[i]:find("Niepelna odpowiedz",1,true),
        "complete results with imminent items must not be treated as incomplete")
end
local report=table.concat(printed)
assert(report:find("JA: 4 szt.",1,true))
assert(report:find("Zathrica: 4 szt.",1,true))
assert(report:find("Uzzarnia: 6 szt.",1,true))
M:alarms_tick()
local one_warning=table.concat(printed)
assert(one_warning:find("lada chwila",1,true),"imminent alarm should name urgency")

-- UI smoke test: native UserWindow owns nested Geyser labels and ScrollBox.
local function widget()
    local item={visible=false}
    function item:show() self.visible=true end
    function item:hide() self.visible=false end
    function item:raise() self.z_raise=(self.z_raise or 0)+1 end
    function item:lower() self.z_lower=(self.z_lower or 0)+1 end
    function item:setColor(bg) self.native_bg=bg end
    function item:move(x,y) self.x=x;self.y=y end
    function item:resize(w,h) self.width=w;self.height=h end
    function item:delete() self.deleted=true end
    function item:setStyleSheet(v) self.css=v end
    function item:setClickCallback(fn) self.click=fn end
    function item:echo(v) self.text=v end
    function item:setToolTip(v) self.tip=v end
    return item
end
Geyser={
    UserWindow={new=function(_,props)
        local o=widget();o.native=true;o.props=props;return o
    end},
    Label={new=function(_,props,parent)
        assert(parent,"label must be inside UserWindow or ScrollBox")
        local o=widget()
        o.props=props
        return o
    end},
    ScrollBox={new=function(_,props,parent)
        assert(parent and parent.native,"scrollbox must be inside UserWindow")
        return widget()
    end},
}
assert(loadfile("src/features/magia_window.lua"))
dofile("src/features/magia_window.lua")
assert(M:show_window() and M.win.native)
assert(M.win.props.autoDock==false and M.win.props.restoreLayout==true)
assert(M.win.visible and M.data.mode=="compact")
display=M:display_rows()
local found_self=false
for _,row in ipairs(display) do
    if row.kind=="item" and row.row.id=="@" then found_self=true end
end
assert(found_self,"compact window must include own magic even with urgent retainer items")
assert(M.header.text:find("MAGIA",1,true))
assert(M.name_labels[1].text:find("<div",1,true),"item name has its own label")
assert(M.time_labels[1].props.x=="-107px","time column pinned to right")
assert(M.time_labels[1].props.width=="90px","compact time width must fit lada chwila")
assert(M.name_labels[1].props.width=="-120px","name takes freed time-column space")
assert(M.window_bg==nil,"full UserWindow overlay must not cover all rows")
assert(M.win.native_bg=="#101216","native window has a themed background")
assert(M.body_bg and M.body_bg.css:find("#171A21",1,true),
    "unused scroll-area space should be colored")
assert(not M.body_bg.visible,"filler hidden when 4 item rows fill compact viewport")
assert(M.row_labels[1].visible and M.name_labels[1].visible
    and M.time_labels[1].visible,"labels must actually be shown, not just echoed")
assert((M.name_labels[1].z_raise or 0)>0 and (M.time_labels[1].z_raise or 0)>0,
    "text labels explicitly raised above row background")
assert(M.row_labels[1].props.width=="-16px",
    "Geyser uses negative pixel width to anchor to right edge")
assert(M.footer and M.footer.visible and M.footer.text:find("przedm.",1,true),
    "bottom area must show scan status and item count")
assert(#background_calls>=1 and background_calls[1].name=="ChimeraVIP_Magia",
    "set the native UserWindow background, never the main console")
assert(M.header.css:find("border%-left"),"thin accent stripe")
assert(M.body and #M.row_labels==4,"compact view should list 4 urgent items")
M:set_mode("full")
assert(M.data.mode=="full" and #M.row_labels>=17)
assert(M:display_rows()[1].title=="TWOJA POSTAC")
local original=M.win
M._window_design=4 -- upgrade in a running Mudlet keeps native dock
assert(M:show_window() and M.win==original and M._window_design==5)
-- Resize must re-truncate the name FROM THE END while the rightmost
-- lifetime label retains its full value, even in narrow windows.
assert(M.name_char_limit(235)<M.name_char_limit(630))
local resizing=events["sysUserWindowResizeEvent"]
assert(type(resizing)=="function")
M:set_mode("compact")
local time_before=M.time_labels[1].text
resizing("sysUserWindowResizeEvent",250,235,"ChimeraVIP_Magia")
local callback=timers[M._resize_timer].callback
callback()
assert(M._window_width==235 and M._window_height==250)
assert(M.time_labels[1].text==time_before,"time label must not be truncated")
assert(M.name_labels[1].text:find("runiczn",1,true)
    or M.name_labels[1].text:find("zakork",1,true),
    "keep beginning of item name on shrink")
resizing("sysUserWindowResizeEvent",250,630,"ChimeraVIP_Magia")
timers[M._resize_timer].callback()
assert(M._window_width==630 and M.time_labels[1].text==time_before)
-- When the user makes the UserWindow taller, the filler begins BELOW rows:
-- it must never be a fullscreen overlay across the actual item texts.
resizing("sysUserWindowResizeEvent",550,630,"ChimeraVIP_Magia")
timers[M._resize_timer].callback()
assert(M.body_bg.visible)
assert(M.body_bg.y=="192px","filler must start after 4 compact rows")
assert(M.body_bg.height=="287px","filler covers only the remaining viewport")
assert((M.body_bg.z_lower or 0)>0,"filler should be below row widgets")
assert(M.name_labels[1].visible and M.time_labels[1].visible)
resizing("sysUserWindowResizeEvent",250,630,"ChimeraVIP_Magia")
timers[M._resize_timer].callback()
assert(not M.body_bg.visible,"no unnecessary filler once rows fill viewport")

-- Compact mode prioritizes global urgency: do not reserve an item row for
-- JA when all four soonest-to-expire objects belong to other people.
local saved={}
for _,item in ipairs(M.data.owners["@"].items) do
    saved[#saved+1]={item=item,expiry=item.expiry,imminent=item.imminent}
    item.imminent=false
    item.expiry=os.time()+40*3600
end
local compact=M:display_rows()
assert(#compact==4)
local last=-math.huge
for i,entry in ipairs(compact) do
    assert(entry.kind=="item")
    assert(entry.row.id~="@","do not reserve a slot for non-urgent JA")
    assert(entry.row.seconds>=last,"compact view is globally ascending by expiry")
    last=entry.row.seconds
end
assert(compact[1].row.item.imminent,"imminent should be shown first")
assert(compact[1].row.id=="npc-1")
for _,v in ipairs(saved) do
    v.item.expiry=v.expiry
    v.item.imminent=v.imminent
end
M:hide_window()
assert(not M.win.visible)
-- Server-confirmed disintegration (capitalized nominative) must immediately
-- remove a UNIQUE tracked item, save/update widgets, and leave others intact.
local before_death=#M:rows()
assert(before_death==14)
M:on_line("Zakorkowana szklana buteleczka rozpada sie w pyl!")
assert(#M.data.owners["@"].items==3,"unique shattered object removed from self")
assert(#M:rows()==before_death-1)
for _,item in ipairs(M.data.owners["@"].items) do
    assert(U.normalize(item.name)~="zakorkowana szklana buteleczka")
end
M:on_line("Zakorkowana szklana buteleczka rozpada sie w pyl!")
assert(#M:rows()==before_death-1,"duplicate disappearance must not delete other items")
assert(table.concat(printed):find("Rozpad potwierdzony:",1,true))

-- The same ring can exist on several retainers, and the text lacks an ID.
-- Refuse to attribute such an event to the wrong teammate.
local before_one=#M.data.owners["npc-1"].items
local before_two=#M.data.owners["npc-2"].items
M:on_line("Matowy pierscien rozpada sie w pyl!")
assert(#M.data.owners["npc-1"].items==before_one)
assert(#M.data.owners["npc-2"].items==before_two)
assert(table.concat(printed):find("nazwa wystepuje u kilku",1,true))

-- Two copies carried by just one member: decrement one copy, preferring the
-- shortest estimate, without deleting its second ring.
local other_owner=M.data.owners["npc-2"].items
M.data.owners["npc-2"].items={
    other_owner[1],other_owner[2],other_owner[3],other_owner[4]
}
M:on_line("Matowy pierscien rozpada sie w pyl!")
assert(#M.data.owners["npc-1"].items==before_one-1)
local remaining_ring
for _,item in ipairs(M.data.owners["npc-1"].items) do
    if item.name=="matowy pierscien" then remaining_ring=item end
end
assert(remaining_ring and remaining_ring.seconds==15*3600,
    "heuristic must remove the earliest-expiring duplicate")

-- The parser must not restore an item from a stale effects snapshot that
-- was being captured when the server confirmed its disintegration.
M.capture={
    owner={id="@",name="Veesa"},
    names=1,items={{name="kamienny olbrzymi miecz",expiry=os.time()+24*3600}},
}
M:on_line("Kamienny olbrzymi miecz rozpada sie w pyl!")
assert(M.capture.invalidated,"destroyed during capture must invalidate snapshot")
M:finish_capture()
for _,item in ipairs(M.data.owners["@"].items) do
    assert(U.normalize(item.name)~="kamienny olbrzymi miecz",
        "stale snapshot cannot re-add destroyed object")
end

-- Reproduce live case of 10 detected items, including long owner names.
-- The scanned database works; both UI modes must render visible content.
local stamp=os.time()
M.data.owners={
    ["@"]={name="Xochitl",last_scan=stamp,items={
        {name="kosciana zakrwawiona wlocznia",expiry=stamp+43*3600}}},
    ["npc-1"]={name="Zathrika",last_scan=stamp,items={
        {name="matowy pierscien",expiry=stamp+10*3600},
        {name="matowy pierscien",expiry=stamp+24*3600},
        {name="blyszczacy runiczny scimitar",expiry=stamp+29*3600},
        {name="lsniacy runiczny scimitar",expiry=stamp+29*3600}}},
    ["npc-2"]={name="Uzzarna",last_scan=stamp,items={
        {name="matowy pierscien",expiry=stamp+3*3600},
        {name="azurowy koscistobialy amulet",expiry=stamp+15*3600},
        {name="runiczna dziobata przylbica",expiry=stamp+22*3600},
        {name="okragla poswiecona tarcza",expiry=stamp+29*3600},
        {name="runiczna rycerska zbroja plytowa",expiry=stamp+29*3600}}},
}
M.data.mode="compact"
assert(#M:rows()==10)
assert(M:show_window())
assert(#M:display_rows()==4 and M:display_rows()[1].row.owner=="Uzzarna")
assert(M.name_labels[1].visible and M.time_labels[1].visible)
assert(M.name_labels[1].text:find("matowy pierscien",1,true))
assert(M.time_labels[1].text:find("~3h",1,true))
M:set_mode("full")
assert(#M:display_rows()==13,"3 owners + 10 magic items")
for i,row in ipairs(M:display_rows()) do
    assert(M.row_labels[i].visible,"full row must be visible: "..i)
    if row.kind=="item" then
        assert(M.name_labels[i].visible and M.time_labels[i].visible,
            "full item contents must be above background: "..i)
    end
end
assert(M.footer.visible and M.footer.text:find("10 przedm.",1,true))

print("Magia tests: PASS")
