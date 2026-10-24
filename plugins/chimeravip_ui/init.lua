-- ChimeraVIP 5: pastel footer and independent, dockable Kondycje.
-- Public GMCP/team/locations API only; the official UI is never monkeypatched.
local WINDOW, HEIGHT = "chimeravip_kondycje", 76
local P = {
    bg="#181C26", soft="#232938", edge="#353C4C", text="#D8DCE6",
    hp="#AC6A78", mp="#5D82A6", zm="#A08C64", neutral="#BDC4CE",
    muted="#AEB6C5", mint="#A8DCC2", blue="#AFCBF4",
    lavender="#C7B9E8", peach="#F2C4A0", rose="#F0A8B8", yellow="#EFD8A6",
}
local EXITS = {
    {"polnocny-zachod","NW"},{"polnoc","N"},{"polnocny-wschod","NE"},
    {"zachod","W"},{"","·"},{"wschod","E"},
    {"poludniowy-zachod","SW"},{"poludnie","S"},{"poludniowy-wschod","SE"},
}
local GAUGES = {
    {"hp","HP","hp"},{"mana","MP","mp"},
    {"fatigue","ZM","zm"},{"thirst","PR","blue"},
    {"hunger","GL","mint"},{"encumbrance","OBC","peach"},
    {"panic","PAN","rose"},{"progress","EXP","lavender"},
}
local BUTTONS = {
    {"TRYB","/tryb_ataku"},{"WSP","/autowsparcie"},
    {"POG","/autopogon"},{"ZBIER","/zbieranie"},
    {"LAMPA","/lampa"},{"KOL","@kolory"},{"MB","/mbind"},
    {"OPCJE","/cvhud ustawienia"},{"OFIC","/cvhud oficjalny"},
}
local function clean(value)
    return tostring(value == nil and "?" or value):gsub("[<>\r]", "")
end
local function alpha(i)
    local out={}
    repeat
        table.insert(out,1,string.char(65+(i-1)%26))
        i=math.floor((i-1)/26)
    until i==0
    return table.concat(out)
end
local function color(name) return P[name] or P.text end
local function style(name)
    return "QLabel { background-color:"..P.soft..";color:"..color(name)
        ..";border:1px solid "..P.edge..";border-radius:4px;"
        .."font-family:'Bitstream Vera Sans Mono';font-size:7pt; }"
        .." QLabel:hover {border-color:"..P.lavender..";}"
end
local function alias(command)
    if type(expandAlias)=="function" then expandAlias(command,false) end
end
local function info(message)
    if type(cecho)=="function" then
        cecho("\n<aquamarine>[ChimeraVIP HUD]<reset> "..message.."\n")
    end
end

return {
    name="chimeravip_ui",
    title="Pastelowy HUD ChimeraVIP",
    section="vip_hud",
    description="Alternatywny HUD i okno Kondycje z powrotem do oficjalnego",
    deps={"gmcp","team","locations","status_bar","room_window","lamp"},
    settings={
        mode={type="enum",values={"vip","oficjalny"},default="vip",label="Interfejs",order=1},
        kondycje={type="boolean",default=true,label="VIP Kondycje",order=2},
        czcionka={type="number",default=7,min=6,max=12,label="Czcionka Kondycji (pt)",order=3},
        akcje={type="boolean",default=true,label="Plywajace akcje lokacji",order=4},
    },
    setup=function(ctx)
        local gmcp,team,locations=ctx:use("gmcp"),ctx:use("team"),ctx:use("locations")
        ctx.state.vip_generation=(ctx.state.vip_generation or 0)+1
        local generation=ctx.state.vip_generation
        local S={active=false,built=false,opened=false,pending=false,widgets={},
            marks={members={},enemies={}},signature=nil,root=nil,cached_vitals=nil,
            floating=nil,floating_widgets={},specials={},action_count=0,exp_progress=nil}
        local function available()
            return type(Geyser)=="table" and type(Geyser.Container)=="table"
                and type(Geyser.Label)=="table" and type(getMainWindowSize)=="function"
                and type(setBorderBottom)=="function" and type(openUserWindow)=="function"
                and type(clearWindow)=="function" and type(echo)=="function"
                and type(setFgColor)=="function"
        end
        local function action(command)
            if command=="@kolory" then
                local vip=rawget(_G,"chimera_vip")
                if vip and vip.settings and vip.settings.toggle_module then
                    vip.settings:toggle_module("combat_colors")
                end
            else alias(command) end
        end
        local function widget(id,onClick)
            local w=Geyser.Label:new({name="chimeravip2_"..generation.."_"..id,
                x=0,y=0,width=20,height=20},S.root)
            w:setStyleSheet(style("text"))
            if onClick then w:setClickCallback(onClick) end
            S.widgets[id]=w
            return w
        end
        local function place(w,x,y,width,height,text,tint)
            w:move(math.floor(x),math.floor(y))
            w:resize(math.max(1,math.floor(width)),math.max(1,math.floor(height)))
            w:setStyleSheet(style(tint))
            w:echo("<center>"..clean(text):gsub("\n","").."</center>")
            w:show()
        end
        local function build()
            if S.built then return end
            S.root=Geyser.Container:new({name="chimeravip2_footer_"..generation,
                x=0,y=-HEIGHT,width="100%",height=HEIGHT})
            -- Backdrops must be created first (Qt/Geyser stacking order).
            for _,name in ipairs({"section_exits","section_stats","section_controls","exp_track","exp_over_track"}) do
                widget(name)
            end
            for i,exit in ipairs(EXITS) do
                local command=exit[1]
                widget("exit"..i,command~="" and function() ctx:send(command,true) end or nil)
            end
            -- Fill widgets are created before the labels so color is behind text.
            for i=1,#GAUGES do widget("track"..i) end
            for i=1,#GAUGES do widget("fill"..i) end
            for i=1,#GAUGES do widget("gauge"..i) end
            for i,button in ipairs(BUTTONS) do
                local command=button[2]
                widget("control"..i,function() action(command) end)
            end
            -- Special exits are plain text; actions move to a floating list.
            for _,name in ipairs({"exp_base","exp_extra","exp_label","exp_percent","exit_up","exit_down"}) do
                widget(name)
            end
            for i=1,3 do
                local slot=i
                widget("special"..i,function()
                    if S.specials[slot] then ctx:send(S.specials[slot],true) end
                end)
            end
            -- Separate sibling avoids clipping in the 76px footer.
            S.floating=Geyser.Container:new({name="chimeravip2_floating_"..generation,
                x=0,y=-HEIGHT-280,width="100%",height=280})
            local function floating_widget(id,callback)
                local w=Geyser.Label:new({name="chimeravip2_"..generation.."_"..id,
                    x=0,y=0,width=20,height=18},S.floating)
                if callback then w:setClickCallback(callback) end
                S.floating_widgets[id]=w
            end
            floating_widget("action_bg")
            floating_widget("action_title")
            for i=1,12 do
                local slot=i
                floating_widget("action"..i,function()
                    local all=locations.room_actions() or {}
                    local entry=all[slot]
                    if entry and type(entry.command)=="string" and entry.command~="" then
                        locations.run_action(slot) -- exactly the official key's API
                    end
                end)
            end
            S.floating:hide()
            S.built=true
        end
        local function open_window()
            if not ctx.settings.kondycje then return end
            if not S.opened then
                if type(windowType)=="function" and windowType(WINDOW)=="userwindow" then
                    if type(showWindow)=="function" then showWindow(WINDOW) end
                else openUserWindow(WINDOW,true,true,"right") end
                if type(setUserWindowTitle)=="function" then
                    setUserWindowTitle(WINDOW,"Kondycje — ChimeraVIP")
                end
                if type(setFontSize)=="function" then setFontSize(WINDOW,ctx.settings.czcionka or 7) end
                S.opened=true
            elseif type(showWindow)=="function" then showWindow(WINDOW) end
            -- Existing docked windows retain old Mudlet font size on reload.
            if type(setFontSize)=="function" then setFontSize(WINDOW,ctx.settings.czcionka or 7) end
        end
        local function official(on)
            -- Documented official public commands, never private module fields.
            alias("/pasek pasek "..(on and "tak" or "nie"))
            alias("/ustaw kondycje okno "..(on and "tak" or "nie"))
        end
        local function restore()
            if S.root then S.root:hide() end
            if S.floating then S.floating:hide() end
            if S.opened and type(hideWindow)=="function" then hideWindow(WINDOW) end
            if type(setBorderBottom)=="function" then setBorderBottom(0) end
            if S.active then official(true) end
            S.active=false
            if rawget(_G,"chimera_vip_ui_targets")==S.marks then
                _G.chimera_vip_ui_targets=nil
            end
        end
        local function index_view(view)
            local m={members={},enemies={},by_id={}}
            local own=view.self or {}
            if own.id then m.by_id[tostring(own.id)]="@" end
            -- Dense VIP letters even when upstream marks have holes.
            for i,member in ipairs(view.members or {}) do
                local letter=alpha(i)
                m.members[letter]=tostring(member.id)
                m.by_id[tostring(member.id)]=letter
            end
            local n=0
            for _,list in ipairs({view.enemies or {},view.others or {}}) do
                for _,person in ipairs(list) do
                    n=n+1
                    m.enemies[tostring(n)]=tostring(person.id)
                    m.by_id[tostring(person.id)]=tostring(n)
                end
            end
            S.marks=m
            _G.chimera_vip_ui_targets=m
            return m
        end
        local function set_window_color(tint)
            local hex=color(tint)
            -- setFgColor works in both user windows and main console.
            -- No cecho markup: Mudlet printed literal <#RRGGBB> in this window.
            local r=tonumber(hex:sub(2,3),16) or 216
            local g=tonumber(hex:sub(4,5),16) or 220
            local b=tonumber(hex:sub(6,7),16) or 230
            setFgColor(WINDOW,r,g,b)
        end
        local function print_segment(text,tint,command,hint)
            set_window_color(tint)
            if command and type(echoLink)=="function" then
                echoLink(WINDOW,clean(text),
                    "send("..string.format("%q",command)..", false)",
                    hint or command,true)
            else
                echo(WINDOW,clean(text))
            end
        end
        local function row(mark,p,ally,self_row,map,fighting,hostile)
            local id=p.id and tostring(p.id) or nil
            local hp=tonumber(p.hp)
            local tint=p.stunned and "lavender" or (self_row and "lavender" or (ally and "mint" or (hostile and "rose" or "neutral")))
            if ally and p.here==false then tint="muted" end
            local attack=id and ("zabij "..id) or nil
            local cover=ally and not self_row and id and ("zaslon "..id) or nil
            local click=ally and cover or attack
            print_segment((p.leader and "★ " or "  ").."["..mark.."] ",tint,click,
                ally and "Zaslon" or "Atak")
            local blocks=hp and math.floor(math.max(0,math.min(100,hp))/12.5) or 0
            local hp_text=hp and string.format("%s%s %3d%% ",
                string.rep("█",blocks),string.rep("░",8-blocks),math.floor(hp))
                or "────────  --  "
            print_segment(hp_text,hp and (hp<30 and "rose" or hp<60 and "yellow" or "mint") or "muted",
                ally and not self_row and id and ("wycofaj sie za "..id) or nil,
                "Wycofaj sie za")
            print_segment(self_row and "JA" or clean(p.name),tint,click)
            if p.henchman then print_segment(" [P]","yellow") end
            if p.stunned then print_segment(" [OGL]","lavender") end
            if fighting and ally and not p.attacking
                and (not p.attackers or #p.attackers==0) then
                print_segment(" [X]","yellow")
            end
            if p.attacking then
                print_segment(" ->["..(map.by_id[tostring(p.attacking)] or "?").."]","peach")
            end
            if type(p.attackers)=="table" and #p.attackers>0 then
                local names={}
                for _,attacker in ipairs(p.attackers) do
                    names[#names+1]=map.by_id[tostring(attacker)] or "?"
                end
                print_segment(" <-["..table.concat(names,",").."]","rose")
            end
            if ally and p.stamina then
                print_segment(" Z:"..math.floor(100-math.min(100,tonumber(p.stamina) or 0)).."%","muted")
            end
            echo(WINDOW,"\n")
        end
        local function draw_window(view)
            if not S.opened or not ctx.settings.kondycje then return end
            local map=index_view(view)
            local signatures={}
            for _,list in ipairs({{view.self or {}},view.members or {},view.enemies or {},view.others or {}}) do
                for _,p in ipairs(list) do
                    signatures[#signatures+1]=table.concat({
                        tostring(p.id),tostring(p.hp),tostring(p.attacking),
                        tostring(p.here),tostring(p.stunned),tostring(p.name),
                        table.concat(p.attackers or {},","),
                    },":")
                end
            end
            local signature=table.concat(signatures,"|")
            if S.signature==signature then return end
            S.signature=signature
            clearWindow(WINDOW)
            print_segment("  DRUZYNA\n","lavender")
            local me=view.self or {}
            local fighting=me.attacking or (me.attackers and #me.attackers>0) or false
            for _,p in ipairs(view.members or {}) do
                if p.attacking or (p.attackers and #p.attackers>0) then fighting=true end
            end
            row("@",me,true,true,map,fighting,false)
            for i,p in ipairs(view.members or {}) do row(alpha(i),p,true,false,map,fighting,false) end
            for _,part in ipairs({{view.enemies or {},"WROGOWIE",true},
                                   {view.others or {},"POZOSTALI",false}}) do
                if #part[1]>0 then
                    print_segment("\n  "..part[2].."\n","lavender")
                    for _,p in ipairs(part[1]) do
                        row(map.by_id[tostring(p.id)] or "?",p,false,false,map,fighting,part[3])
                    end
                end
            end
        end
        -- Use the official GMCP cache, the latest event payload, and only
        -- then raw Mudlet GMCP. A plugin reload need not replay Char.Vitals.
        local function current_vitals()
            local values=gmcp.vitals()
            if type(values)=="table" and next(values) then
                S.cached_vitals=values
                return values
            end
            if type(S.cached_vitals)=="table" then return S.cached_vitals end
            local raw=rawget(_G,"gmcp")
            local incoming=type(raw)=="table" and raw.Char and raw.Char.Vitals
            if type(incoming)=="table" and next(incoming) then
                S.cached_vitals=incoming
                return incoming
            end
            -- The official status bar uses precisely these GMCP key names.
            local api=ctx:use("status_bar")
            if api and type(api.model)=="function" then
                local model=api.model()
                local out={}
                for _,reading in ipairs(model and model.gauges or {}) do
                    out[reading.key]=reading.value
                end
                if next(out) then return out end
            end
            return {}
        end
        -- Char.Vitals is percentage data. Exact values must be sourced
        -- separately from team / group snapshots, never guessed.
        local function exact(key,view)
            if key=="hp" and view and view.self then
                local me=view.self
                local now,max=tonumber(me.hp_now),tonumber(me.hp_max)
                if now and max and max>0 then return now,max end
            end
            local group=gmcp.group()
            local my_id=view and view.self and view.self.id
            if type(group)=="table" then
                for _,member in ipairs(group.members or {}) do
                    if member.self==true or tonumber(member.self)==1
                        or (my_id and tostring(member.id)==tostring(my_id)) then
                        local field,maxfield=nil,nil
                        if key=="hp" then field,maxfield="hp","maxhp"
                        elseif key=="mana" then field,maxfield="mana","maxmana" end
                        if field then
                            local now,max=tonumber(member[field]),tonumber(member[maxfield])
                            if now and max and max>0 then return now,max end
                        end
                    end
                end
            end
            return nil,nil
        end
        local function main_label(i,reading,view)
            local def=GAUGES[i]
            local pct=tonumber(reading)
            if not pct then return def[2]..": --" end
            local now,max=exact(def[1],view)
            if now and max then
                return string.format("%s: %d/%d %d%%",def[2],now,max,math.floor(pct+0.5))
            end
            return def[2]..": "..math.floor(pct+0.5).."%"
        end
        -- Thresholds apply to all three primary percentages:
        -- 70-100: green; 40-69: amber; 0-39: red.
        local function condition_color(pct)
            if pct==nil then return "#6B778B" end
            if pct>=70 then return "#69C9A1" end
            if pct>=40 then return "#D7B56B" end
            return "#CB7580"
        end
        local function panel(w,x,y,width,height)
            w:move(math.floor(x),math.floor(y))
            w:resize(math.max(1,math.floor(width)),math.max(1,math.floor(height)))
            w:setStyleSheet("QLabel {background-color:#232938;"
                .."border:1px solid #41485C;border-radius:4px;}")
            w:show()
        end
        local function draw_bar(i,x,y,width,height,reading,view)
            local pct=tonumber(reading)
            local track=S.widgets["track"..i]
            local fill=S.widgets["fill"..i]
            local text=S.widgets["gauge"..i]
            place(track,x,y,width,height,"","muted")
            track:setStyleSheet("QLabel {background-color:#202633;"
                .."border:1px solid #343B4B;border-radius:3px;}")
            local amount=pct and math.floor((width-2)*math.max(0,math.min(1,pct/100))) or 0
            if amount>0 then
                fill:move(math.floor(x+1),math.floor(y+height-4))
                fill:resize(amount,3)
                fill:setStyleSheet("QLabel {background-color:"..(i<=3 and condition_color(pct) or color(GAUGES[i][3]))
                    ..";border:0;border-radius:2px;}")
                fill:show()
            else fill:hide() end
            place(text,x,y,width,height,main_label(i,reading,view),"text")
            -- Thin colored line and neutral text: no pale text on pale fill.
            text:setStyleSheet("QLabel {background:transparent;color:#DCE1EA;"
                .."border:0;font-family:'Bitstream Vera Sans Mono';font-size:7pt;}")
        end
        local function draw_chip(i,x,y,width,v)
            -- Keep the four original separate PR/GL/OBC/PAN capsules.
            S.widgets["track"..i]:hide()
            S.widgets["fill"..i]:hide()
            local number=tonumber(v)
            local label=GAUGES[i][2].." "..(number and math.floor(number+0.5).."%" or "--")
            local w=S.widgets["gauge"..i]
            place(w,x,y,width,17,label,"text")
            w:setStyleSheet("QLabel {background-color:#202633;color:#DCE1EA;"
                .."border:1px solid #343B4B;border-radius:3px;"
                .."font-family:'Bitstream Vera Sans Mono';font-size:7pt;}")
        end
        local function float_actions(width)
            local items=ctx.settings.akcje and locations.room_actions() or {}
            if type(items)~="table" then items={} end
            local count=math.min(#items,12)
            if count==0 then
                S.floating:hide()
                S.action_count=0
                return
            end
            local panel_w=math.min(265,math.max(185,math.floor(width*0.23)))
            local left=math.max(0,width-panel_w-9)
            local height=23+count*20
            local top=280-height
            S.floating:show()
            local bg=S.floating_widgets.action_bg
            bg:move(left,top)
            bg:resize(panel_w,height)
            bg:setStyleSheet("QLabel {background-color:rgba(29,35,48,198);"
                .."border:1px solid rgba(140,154,177,85);border-radius:6px;}")
            bg:show()
            local title=S.floating_widgets.action_title
            title:move(left+9,top+3)
            title:resize(panel_w-18,15)
            title:echo("AKCJE LOKACJI")
            title:setStyleSheet("QLabel {background:transparent;color:#8995A9;"
                .."border:0;font-family:'Bitstream Vera Sans Mono';font-size:7pt;}")
            title:show()
            for i=1,12 do
                local row=S.floating_widgets["action"..i]
                if i<=count and items[i] and items[i].command then
                    local key=tostring(items[i].key or ("Akcja "..i))
                    local cmd=tostring(items[i].command)
                    if #cmd>36 then cmd=cmd:sub(1,33).."..." end
                    row:move(left+6,top+18+(i-1)*20)
                    row:resize(panel_w-12,20)
                    row:echo("  <font color='#C7B9E8'>"..clean(key)
                        .."</font>  "..clean(cmd))
                    row:setStyleSheet("QLabel {background-color:rgba(37,44,59,55);"
                        .."color:#D4DAE5;border:0;border-bottom:1px solid rgba(160,175,195,25);"
                        .."font-family:'Bitstream Vera Sans Mono';font-size:7pt;}"
                        .."QLabel:hover {background-color:rgba(77,90,115,155);color:#F2F2F5;}")
                    row:show()
                else row:hide() end
            end
            S.action_count=count
        end
        -- Experience belongs INSIDE the central stats panel. It may have
        -- two tracks: base 0-100% and an independent overflow cycle.
        -- Never paint a bar across the entire footer or below HEIGHT.
        local function draw_experience(x,space,vitals)
            local track=S.widgets.exp_track
            local overflow_track=S.widgets.exp_over_track
            local base=S.widgets.exp_base
            local extra=S.widgets.exp_extra
            local label=S.widgets.exp_label
            local number=S.widgets.exp_percent
            local rail_x=x+53
            local rail_w=math.max(26,math.floor(space-134))
            local raw=tonumber(vitals.progress) or S.exp_progress
            -- Official GMCP usually caps at 100. Only show extra cycles
            -- when the server supplies an uncapped progress value.
            local full=raw and math.max(0,raw) or nil
            local initial=full and math.min(100,full) or nil
            local over=full and math.max(0,full-100) or nil
            track:move(math.floor(rail_x),58)
            track:resize(rail_w,4)
            track:setStyleSheet("QLabel {background-color:#34384B;border:0;border-radius:2px;}")
            track:show()
            if initial then
                local amount=math.floor(rail_w*initial/100)
                if amount>0 then
                    base:move(math.floor(rail_x),58)
                    base:resize(amount,4)
                    base:setStyleSheet("QLabel {background-color:#A892CF;border:0;border-radius:2px;}")
                    base:show()
                else base:hide() end
            else base:hide() end
            if over and over>0 then
                overflow_track:move(math.floor(rail_x),65)
                overflow_track:resize(rail_w,3)
                overflow_track:setStyleSheet("QLabel {background-color:#34384B;border:0;border-radius:2px;}")
                overflow_track:show()
                local tier=math.floor((over-1)/100)
                local fraction=((over-1)%100+1)/100
                local shades={"#D4C08A","#DEB46F","#E6AA4E","#EBA837","#F2BF4A"}
                local amount=math.floor(rail_w*fraction)
                if amount>0 then
                    extra:move(math.floor(rail_x),65)
                    extra:resize(amount,3)
                    extra:setStyleSheet("QLabel {background-color:"..shades[math.min(tier+1,#shades)]
                        ..";border:0;border-radius:2px;}")
                    extra:show()
                else extra:hide() end
            else
                overflow_track:hide()
                extra:hide()
            end
            place(label,x+7,55,42,15,"EXP","lavender")
            label:setStyleSheet("QLabel {background:transparent;border:0;color:#C7B9E8;"
                .."font-family:'Bitstream Vera Sans Mono';font-size:7pt;}")
            local display=not full and "--" or
                (full>100 and ("100% +"..math.floor(full-100+0.5).."%")
                    or (math.floor(full+0.5).."%"))
            place(number,x+space-77,55,71,15,display,"lavender")
            number:setStyleSheet("QLabel {background:transparent;border:0;color:#D5C3E5;"
                .."font-family:'Bitstream Vera Sans Mono';font-size:7pt;}")
        end
        local function draw_footer(view)
            if not S.built then return end
            local width=tonumber((getMainWindowSize())) or 1000
            width=math.max(450,width)
            local room=gmcp.room() or {}
            local exits=type(room.exits)=="table" and room.exits or {}
            local vitals=current_vitals()
            local normal={}
            for _,e in ipairs(EXITS) do normal[e[1]]=true end
            local controls=math.min(180,math.max(151,math.floor(width*0.17)))
            local x=168
            local rx=width-controls-8
            local space=math.max(170,rx-x-8)
            -- Slate background panels: continuous, discreet, distinct zones.
            panel(S.widgets.section_exits,2,2,x-7,HEIGHT-4)
            panel(S.widgets.section_stats,x-1,2,space+5,HEIGHT-4)
            panel(S.widgets.section_controls,rx-3,2,controls+7,HEIGHT-4)
            -- The compass is only a text hint, never a button.
            for i,e in ipairs(EXITS) do
                local active=e[1]=="" or exits[e[1]]~=nil
                local w=S.widgets["exit"..i]
                place(w,8+(i-1)%3*18,13+math.floor((i-1)/3)*17,
                    17,14,e[2],active and "mint" or "muted")
                w:setStyleSheet("QLabel {background:transparent;border:0;color:"
                    ..(active and "#A8DCC2" or "#556070")
                    ..";font-family:'Bitstream Vera Sans Mono';font-size:7pt;}")
            end
            local specials={}
            for cmd in pairs(exits) do
                if type(cmd)=="string" and cmd~="gora" and cmd~="dol" and not normal[cmd] then specials[#specials+1]=cmd end
            end
            table.sort(specials)
            S.specials=specials
            for i=1,3 do
                local w=S.widgets["special"..i]
                local cmd=specials[i]
                if cmd then
                    local short=#cmd>16 and cmd:sub(1,13).."..." or cmd
                    place(w,65,33+(i-1)*14,94,12,short,"peach")
                    w:setStyleSheet("QLabel {background:transparent;border:0;color:#D5B98F;"
                        .."font-family:'Bitstream Vera Sans Mono';font-size:7pt;}")
                else w:hide() end
            end
            for i=1,3 do
                local cell=space/3
                draw_bar(i,x+(i-1)*cell,6,cell-5,22,vitals[GAUGES[i][1]],view)
            end
            for offset=1,4 do
                local i=offset+3
                local cell=space/4
                draw_chip(i,x+(offset-1)*cell,32,cell-5,vitals[GAUGES[i][1]])
            end
            -- Include up/down alongside the eight compass directions.
            for _,pair in ipairs({{"exit_up","gora",0},{"exit_down","dol",1}}) do
                local w=S.widgets[pair[1]]
                place(w,65,5+pair[3]*14,94,12,
                    pair[3]==0 and "GORA" or "DOL",
                    exits[pair[2]]~=nil and "mint" or "muted")
                w:setStyleSheet("QLabel {background:transparent;border:0;color:"
                    ..(exits[pair[2]] and "#A8DCC2" or "#667083")
                    ..";font-family:'Bitstream Vera Sans Mono';font-size:6pt;}")
            end
            S.widgets.track8:hide()
            S.widgets.fill8:hide()
            S.widgets.gauge8:hide()
            draw_experience(x,space,vitals)
            -- Only official status_bar.model() determines upstream states.
            local official_model=nil
            local sb=ctx:use("status_bar")
            if sb and type(sb.model)=="function" then
                local ok,model=pcall(sb.model)
                if ok and type(model)=="table" then official_model=model end
            end
            local states={}
            if official_model then
                for _,v in ipairs(official_model.toggles or {}) do
                    if v.command=="/autowsparcie" then states[2]=v.on
                    elseif v.command=="/autopogon" then states[3]=v.on end
                end
                if official_model.collect then states[4]=official_model.collect.on end
            end
            local lamp=ctx:use("lamp")
            if lamp and type(lamp.state)=="function" then
                local ok,v=pcall(lamp.state)
                if ok and type(v)=="table" then states[5]=v.lit end
            end
            local cell=controls/3
            for i,btn in ipairs(BUTTONS) do
                local title=btn[1]
                local state=states[i]
                if i==1 and official_model and official_model.mode then
                    title=(official_model.mode=="Atak" and "TRYB A" or "TRYB R")
                elseif state~=nil then
                    title=title.." "..(state and "ON" or "OFF")
                end
                local control=S.widgets["control"..i]
                place(control,rx+(i-1)%3*cell,
                    7+math.floor((i-1)/3)*21,cell-4,16,title,"text")
                local fg=state==true and "#A8DCC2" or state==false and "#8590A2" or "#D8DCE6"
                local bg=state==true and "#26463F" or "#232938"
                control:setStyleSheet("QLabel {background-color:"..bg
                    ..";color:"..fg..";border:1px solid "
                    ..(state==true and "#4F977E" or "#41485C")
                    ..";border-radius:4px;font-family:'Bitstream Vera Sans Mono';font-size:7pt;}")

            end
            float_actions(width)
        end
        local function render()
            S.pending=false
            if not S.active then return end
            local ok,err=pcall(function()
                local v=team.view() or {self={},members={},enemies={},others={}}
                draw_footer(v)
                draw_window(v)
            end)
            if not ok then
                info("Blad rysowania: "..clean(err)..". Wracam do oficjalnego.")
                restore()
            end
        end
        local function schedule()
            if not S.active or S.pending then return end
            S.pending=true
            ctx:timer(0.10,render)
        end
        local function activate()
            if not available() then
                info("Brak Geyser lub API okien. Pozostawiam oficjalny HUD.")
                return false
            end
            local ok,err=pcall(function() build(); open_window() end)
            if not ok then
                info("Nie udalo sie utworzyc HUD: "..clean(err))
                return false
            end
            S.active=true
            S.root:show()
            official(false)
            setBorderBottom(HEIGHT)
            S.signature=nil
            render()
            return S.active
        end
        local function switch(mode)
            if mode=="vip" then return activate() end
            restore()
            official(true)
            return true
        end
        ctx:command{"cvhud",args="[vip|oficjalny|status|ustawienia]",
            help="Przelacz HUD ChimeraVIP",fn=function(arg)
                local mode=tostring(arg or "status"):lower():gsub("^%s+",""):gsub("%s+$","")
                if mode=="vip" or mode=="oficjalny" then
                    ctx:set("mode",mode) -- config event invokes switch()
                elseif mode=="ustawienia" then
                    alias("/ustawienia vip_hud")
                else
                    info("Interfejs: "..(S.active and "VIP" or "oficjalny")
                        .." | /cvhud vip | /cvhud oficjalny")
                end
            end}
        ctx:on("chimera.team.changed",function()
            S.signature=nil
            schedule()
        end)
        ctx:on("chimera.progress",function(data)
            -- Some servers provide only capped percent; this is conditional.
            if type(data)=="table" and tonumber(data.percent) then
                S.exp_progress=tonumber(data.percent)
            end
            schedule()
        end)
        ctx:on("chimera.room.changed",schedule)
        ctx:on("chimera.locations.actions",schedule)
        ctx:on("chimera.char.vitals",function(vitals)
            if type(vitals)=="table" then S.cached_vitals=vitals end
            schedule()
        end)
        ctx:on("gmcp.Char.Vitals",function()
            local raw=rawget(_G,"gmcp")
            local values=type(raw)=="table" and raw.Char and raw.Char.Vitals
            if type(values)=="table" then S.cached_vitals=values end
            schedule()
        end)
        ctx:on("sysWindowResizeEvent",schedule)
        ctx:on("chimera.config.changed",function(module_name,key,value)
            if module_name=="chimeravip_ui" then
                if key=="mode" then switch(value)
                elseif key=="czcionka" then
                    if S.opened and type(setFontSize)=="function" then
                        setFontSize(WINDOW,tonumber(value) or 7)
                    end
                elseif key=="kondycje" then
                    if value then open_window()
                    elseif S.opened and type(hideWindow)=="function" then
                        hideWindow(WINDOW)
                    end
                    S.signature=nil
                    schedule()
                else schedule() end
            end
        end)
        ctx:on("sysExitEvent",function()
            if S.opened and type(saveWindowLayout)=="function" then saveWindowLayout() end
        end)
        ctx:timer(1.5,schedule,true)
        ctx:cleanup(function()
            restore()
            if S.root and type(S.root.delete)=="function" then
                pcall(function() S.root:delete() end)
            end
            if S.floating and type(S.floating.delete)=="function" then
                pcall(function() S.floating:delete() end)
            end
        end)
        ctx:timer(0.5,function()
            if ctx.settings.mode=="vip" then activate()
            else official(true) end
        end)
        return {
            active=function() return S.active end,
            targets=function() return S.marks end,
        }
    end,
}
