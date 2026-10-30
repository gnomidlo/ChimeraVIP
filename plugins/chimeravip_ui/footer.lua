-- ChimeraVIP 5: footer module.
return function(ctx,S,T,gmcp,actions,generation)
local WINDOW,HEIGHT,P,EXITS,GAUGES,BUTTONS=T.WINDOW,T.HEIGHT,T.P,T.EXITS,T.GAUGES,T.BUTTONS
local clean,alpha,color,compass_html,style,alias,info=T.clean,T.alpha,T.color,T.compass_html,T.style,T.alias,T.info
local special_exit,room_action=actions.special_exit,actions.room_action
local current_special_exits,combined_actions=actions.current_special_exits,actions.combined_actions
local map_default_name=actions.map_default_name
local html_escape=T.html_escape
local resolve_exits
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
    if ctx.settings.rozmiar=="m" then text=T.upper(text) end
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
    for _,name in ipairs({"hud_background","section_exits","section_stats","section_needs","section_controls","exp_track","exp_over_track"}) do
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
    for i=1,3 do widget("value"..i) end
    for i=1,3 do widget("points"..i) end
    for i=4,7 do widget("need_value"..i) end
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
        widget("special"..i,function() special_exit(slot) end)
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
        floating_widget("action"..i,function() room_action(slot) end)
    end
    for i=1,12 do
        local slot=i
        floating_widget("badge"..i,function() room_action(slot) end)
    end
    S.floating:hide()
    S.footer_signature=nil
    S.built=true
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
-- Three large inset bars and four equal compact need rows.
-- Life is threshold-colored, mana always blue, and available
-- strength = 100 - fatigue (no guessed absolute quantity).
local function primary_tint(i,pct)
    if i==1 then return condition_color(pct) end
    if i==2 then return "#639EDB" end
    return "#D8B671"
end
local function draw_primary(i,x,y,width,height,reading,view)
    local raw=tonumber(reading)
    local pct=raw
    if i==3 and raw then pct=math.max(0,math.min(100,100-raw)) end
    local track=S.widgets["track"..i]
    local fill=S.widgets["fill"..i]
    local title=S.widgets["gauge"..i]
    local value=S.widgets["value"..i]
    panel(track,x,y,width,height)
    track:setStyleSheet("QLabel {background-color:#181E2B;"
        .."border:1px solid #424D64;border-radius:4px;}")
    local name=GAUGES[i][2]
    local label=pct and (math.floor(pct+0.5).."%") or "--"
    -- Only display actual x/y when the official model exposes it.
    local now,max=exact(GAUGES[i][1],view)
    local points=S.widgets["points"..i]
    local large=ctx.settings.rozmiar=="m" or ctx.settings.rozmiar=="xl"
    if large then
        local xl=ctx.settings.rozmiar=="xl"
        local rail_y=xl and y or y+height/2
        local rail_h=xl and height or height/2
        local amount=pct and math.floor(width*math.max(0,math.min(1,pct/100))) or 0
        if amount>0 then
            fill:move(math.floor(x),math.floor(rail_y))
            fill:resize(amount,math.floor(rail_h))
            -- Dark fills keep pale overlay text readable at every percentage.
            local tint=primary_tint(i,pct)
            if xl then
                local health=pct and pct<40 and "#773E49" or pct and pct<70 and "#77633D" or "#345F50"
                tint=({health,"#345779","#6C5C35"})[i]
            end
            fill:setStyleSheet("QLabel {background-color:"..tint..";border:0;border-radius:3px;}")
            fill:show()
        else fill:hide() end
        local font=xl and 16 or 11
        local title_h=xl and 26 or 18
        local value_y=xl and y+27 or y+1
        local value_h=xl and 26 or 18
        local point_y=xl and y+55 or y+19
        local point_h=xl and 22 or 13
        local point_font=xl and 12 or 8
        local title_width=xl and width-12 or width*0.45-6
        place(title,x+6,y+(xl and 0 or 1),title_width,title_h,T.upper(name),"text")
        place(value,x+(xl and 6 or width*0.45),value_y,
            xl and width-12 or width*0.55-6,value_h,label,"text")
        place(points,x+6,point_y,width-12,point_h,
            i~=3 and now and max and string.format("%d / %d",now,max) or "PKT: —","text")
        for _,w in ipairs({title,value,points}) do
            w:setStyleSheet("QLabel {background:transparent;border:0;color:#F1F3F8;"
                .."font-family:'DejaVu Sans Mono';font-size:"..(w==points and point_font or font).."pt;}")
        end
        return
    end
    points:hide()
    if i~=3 and now and max and width>=166 then
        label=string.format("%d/%d %s",now,max,label)
    end
    local title_w=width<122 and 40 or 55
    place(title,x+5,y+4,title_w,16,name,"text")
    title:setStyleSheet("QLabel {background:transparent;color:#C2CCDC;"
        .."border:0;font-family:'DejaVu Sans';font-size:7pt;}")
    place(value,x+title_w,y+4,width-title_w-7,16,label,"text")
    value:setStyleSheet("QLabel {background:transparent;color:#E4E9F2;"
        .."border:0;font-family:'DejaVu Sans Mono';font-size:7pt;}")
    local rail_x=x+6
    local rail_y=y+height-13
    local rail_w=math.max(1,width-12)
    local rail_h=7
    -- Inset rail and full-height, resource-specific fill.
    -- These two labels sit above the panel but below text widgets.
    local amount=pct and math.floor(rail_w*math.max(0,math.min(1,pct/100))) or 0
    if amount>0 then
        fill:move(math.floor(rail_x),math.floor(rail_y))
        fill:resize(amount,rail_h)
        fill:setStyleSheet("QLabel {background-color:"..primary_tint(i,pct)
            ..";border:0;border-radius:2px;}")
        fill:show()
    else fill:hide() end
end
local function draw_need(i,x,y,width,height,reading)
    local raw=tonumber(reading)
    local background=S.widgets["track"..i]
    local bar=S.widgets["fill"..i]
    local label=S.widgets["gauge"..i]
    local value=S.widgets["need_value"..i]
    panel(background,x,y,width,height)
    background:setStyleSheet("QLabel {background-color:#1C2331;"
        .."border:1px solid #3B465C;border-radius:2px;}")
    local text=GAUGES[i][2]
    local label_w=math.min(83,math.floor(width*0.53))
    place(label,x+4,y,math.max(1,label_w),height,text,"text")
    label:setStyleSheet("QLabel {background:transparent;color:#BFC9D7;"
        .."border:0;font-family:'DejaVu Sans';font-size:6pt;}")
    local value_w=27
    place(value,x+width-value_w-4,y,value_w,height,
        raw and (math.floor(raw+0.5).."%") or "--","text")
    value:setStyleSheet("QLabel {background:transparent;color:#E3E8F0;"
        .."border:0;font-family:'DejaVu Sans Mono';font-size:6pt;}")
    local rail_x=x+label_w+7
    local rail_w=math.max(1,width-label_w-value_w-15)
    if raw and raw>0 then
        local len=math.floor(rail_w*math.max(0,math.min(1,raw/100)))
        if len>0 then
            bar:move(math.floor(rail_x),math.floor(y+height-5))
            bar:resize(len,3)
            bar:setStyleSheet("QLabel {background-color:"..color(GAUGES[i][3])
                ..";border:0;border-radius:2px;}")
            bar:show()
        else bar:hide() end
    else bar:hide() end
end
local function float_actions(width)
    local items=ctx.settings.akcje and combined_actions() or {}
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
        local badge=S.floating_widgets["badge"..i]
        local entry=items[i]
        if i<=count and entry then
            local description=tostring(entry.title)
            local short=#description>36 and description:sub(1,33).."..." or description
            local y=top+18+(i-1)*20
            row:move(left+6,y)
            row:resize(panel_w-12,20)
            row:echo(string.rep("&nbsp;",7)..html_escape(ctx.settings.rozmiar=="m" and T.upper(short) or short))
            row:setStyleSheet("QLabel {background-color:rgba(37,44,59,55);"
                .."color:#D4DAE5;border:0;border-bottom:1px solid rgba(160,175,195,25);"
                .."font-family:'Bitstream Vera Sans Mono';font-size:7pt;}"
                .."QLabel:hover {background-color:rgba(77,90,115,155);color:#F2F2F5;}")
            if type(row.setToolTip)=="function" then
                row:setToolTip((entry.source=="vip" and "Wlasna: " or "Chimera: ")
                    ..description)
            end
            row:show()
            badge:move(left+11,y+2)
            badge:resize(21,16)
            badge:echo("<center><font color='#D9C5FF'><b>"..i.."</b></font></center>")
            badge:setStyleSheet("QLabel {background-color:#373449;"
                .."border:1px solid #71658C;border-radius:4px;}"
                .."QLabel:hover {background-color:#554967;border-color:#B5A0D5;}")
            badge:show()
        else
            row:hide()
            badge:hide()
        end
    end
    S.action_count=count
end
-- A single bottom ribbon, outside all four top panels.
-- The main lavender cycle occupies four pixels; optional overcap
-- uses two distinct amber pixels underneath only with real data.
local function draw_experience(width,vitals)
    local background=S.widgets.exp_track
    local over_bg=S.widgets.exp_over_track
    local base=S.widgets.exp_base
    local extra=S.widgets.exp_extra
    local title=S.widgets.exp_label
    local number=S.widgets.exp_percent
    local value=tonumber(vitals.progress) or S.exp_progress
    local p=value and math.max(0,value) or nil
    local capped=p and math.min(100,p) or 0
    local overflow=p and math.max(0,p-100) or 0
    local rail_x=46
    local rail_w=math.max(30,math.floor(width-150))
    background:move(rail_x,HEIGHT-11)
    background:resize(rail_w,7)
    background:setStyleSheet("QLabel {background-color:#343C4D;border:0;border-radius:2px;}")
    background:show()
    if capped>0 then
        base:move(rail_x,HEIGHT-11)
        base:resize(math.max(1,math.floor(rail_w*capped/100)),4)
        base:setStyleSheet("QLabel {background-color:#AC97D4;border:0;border-radius:2px;}")
        base:show()
    else base:hide() end
    if overflow>0 then
        local tier=math.floor((overflow-1)/100)
        local part=((overflow-1)%100+1)/100
        local shades={"#DFB779","#E6B56E","#EDB05C","#F3BC51"}
        over_bg:move(rail_x,HEIGHT-6)
        over_bg:resize(rail_w,2)
        over_bg:setStyleSheet("QLabel {background-color:#343C4D;border:0;}")
        over_bg:show()
        extra:move(rail_x,HEIGHT-6)
        extra:resize(math.max(1,math.floor(rail_w*part)),2)
        extra:setStyleSheet("QLabel {background-color:"..shades[math.min(tier+1,#shades)]
            ..";border:0;}")
        extra:show()
    else
        over_bg:hide()
        extra:hide()
    end
    place(title,7,HEIGHT-14,33,11,"EXP","lavender")
    title:setStyleSheet("QLabel {background:transparent;border:0;color:#C7B9E8;"
        .."font-family:'DejaVu Sans Mono';font-size:7pt;}")
    local display=not p and "--" or (p>100 and
        ("100% +"..math.floor(p-100+0.5).."%") or math.floor(p+0.5).."%")
    place(number,width-97,HEIGHT-14,87,11,display,"lavender")
    number:setStyleSheet("QLabel {background:transparent;border:0;color:#D5C3E7;"
        .."font-family:'DejaVu Sans Mono';font-size:7pt;}")
end
resolve_exits=function()
    local room=gmcp.room()
    local exits=type(room)=="table" and room.exits
    if type(exits)~="table" or next(exits)==nil then
        local raw=rawget(_G,"gmcp")
        local fallback=type(raw)=="table" and raw.Room and raw.Room.Info
        exits=type(fallback)=="table" and fallback.exits or exits
    end
    local found={}
    if type(exits)=="table" then
        for key,value in pairs(exits) do
            -- Normalize keyed Room.Info.exits AND older array forms.
            local command=type(key)=="string" and key or
                (type(value)=="string" and value or
                 (type(value)=="table" and (value.command or value.direction)))
            if type(command)=="string" and command~="" then
                found[command:lower()]=true
            end
        end
    end
    return found
end
local function geometry(width)
    local edge,gap=5,5
    local narrow=width<900
    local nav=narrow and 164 or 193
    local needs=narrow and 174 or 191
    local controls=narrow and 127 or 139
    local stats=math.max(180,width-edge*2-gap*3-nav-needs-controls)
    local nav_x=edge
    local stats_x=nav_x+nav+gap
    local needs_x=stats_x+stats+gap
    local controls_x=needs_x+needs+gap
    if ctx.settings.rozmiar=="m" or ctx.settings.rozmiar=="xl" then
        return {nav_x=edge,nav=nav,stats_x=edge,stats=width-2*edge,
            stats_y=4,stats_h=T.profile(ctx.settings).bar+8,
            needs_x=edge+nav+gap,needs=width-2*edge-2*gap-nav-controls,
            controls_x=width-edge-controls,controls=controls,
            top_y=T.profile(ctx.settings).bar+14,top_h=53}
    end
    return {
        nav_x=nav_x,nav=nav,stats_x=stats_x,stats=stats,
        needs_x=needs_x,needs=needs,controls_x=controls_x,
        controls=controls,top_y=4,top_h=53,
    }
end
-- Build a deterministic frame key before touching Qt widgets. The
-- 1.5s official-status fallback still checks state, but no longer repaints
-- the entire Geyser footer on every tick when nothing visible changed.
local function stable_key(value,depth,seen)
    local kind=type(value)
    if kind~="table" then
        if kind=="function" or kind=="userdata" or kind=="thread" then return "-" end
        return kind..":"..tostring(value)
    end
    if depth==0 or seen[value] then return "*" end
    seen[value]=true
    local keys={}
    for k,v in pairs(value) do
        local t=type(v)
        if t~="function" and t~="userdata" and t~="thread" then
            keys[#keys+1]=k
        end
    end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    local out={}
    for _,key in ipairs(keys) do
        out[#out+1]=tostring(key).."="..stable_key(value[key],depth-1,seen)
    end
    seen[value]=nil
    return "{"..table.concat(out,",").."}"
end
local function frame_signature(width,view,exits,vitals)
    local status=ctx:use("status_bar")
    local model=nil
    if status and type(status.model)=="function" then
        local ok,value=pcall(status.model)
        if ok then model=value end
    end
    local lamp=ctx:use("lamp")
    local lamp_state=nil
    if lamp and type(lamp.state)=="function" then
        local ok,value=pcall(lamp.state)
        if ok then lamp_state=value end
    end
    local vip=rawget(_G,"chimera_vip")
    local combat_colors=nil
    if vip and vip.settings and type(vip.settings.is_module_enabled)=="function" then
        local ok,value=pcall(vip.settings.is_module_enabled,vip.settings,"combat_colors",true)
        if ok then combat_colors=value end
    end
    local snapshot={
        width=width,height=HEIGHT,size=ctx.settings.rozmiar,
        actions_visible=ctx.settings.akcje,
        room=gmcp.room(),group=gmcp.group(),view=view,
        exits=exits,vitals=vitals,progress=S.exp_progress,
        actions=ctx.settings.akcje and combined_actions() or {},
        status=model,lamp=lamp_state,combat_colors=combat_colors,
    }
    return stable_key(snapshot,7,{})
end
local function draw_footer(view)
    if not S.built then return end
    HEIGHT=T.profile(ctx.settings).height
    local width=tonumber((getMainWindowSize())) or 1200
    -- Client window widths below 640 cannot fit four panels
    -- with readable labels; the supported laptop range is 760+.
    width=math.max(640,width)
    local exits=resolve_exits()
    local vitals=current_vitals()
    local signature=frame_signature(width,view,exits,vitals)
    if S.footer_signature==signature then return end
    S.footer_signature=signature
    if S.footer_height~=HEIGHT or S.footer_width~=width then
        S.root:move(0,-HEIGHT)
        S.root:resize("100%",HEIGHT)
        S.floating:move(0,-HEIGHT-280)
        if S.footer_height~=HEIGHT then setBorderBottom(HEIGHT) end
        S.footer_height,S.footer_width=HEIGHT,width
    end
    local g=geometry(width)
    local bg=S.widgets.hud_background
    bg:move(0,0)
    bg:resize(width,HEIGHT)
    bg:setStyleSheet("QLabel {background-color:#1B2030;border:0;"
        .."border-top:2px solid #535E77;}")
    bg:show()
    panel(S.widgets.section_exits,g.nav_x,g.top_y,g.nav,g.top_h)
    panel(S.widgets.section_stats,g.stats_x,g.stats_y or g.top_y,g.stats,g.stats_h or g.top_h)
    panel(S.widgets.section_needs,g.needs_x,g.top_y,g.needs,g.top_h)
    panel(S.widgets.section_controls,g.controls_x,g.top_y,g.controls,g.top_h)
    -- Compass: 3x3 directions, arrows to its right and a narrow
    -- nonstandard-exit column. No overlapping rectangles.
    for i,e in ipairs(EXITS) do
        local exists=e[1]=="" or exits[e[1]]==true
        local w=S.widgets["exit"..i]
        local x=g.nav_x+7+((i-1)%3)*19
        local y=g.top_y+6+math.floor((i-1)/3)*13
        place(w,x,y,18,12,e[2],exists and "mint" or "muted")
        w:setStyleSheet("QLabel {background:transparent;border:0;color:"
            ..(exists and "#86E7BC" or "#4A5363")
            ..";font-family:'DejaVu Sans Mono';font-weight:"
            ..(exists and "bold" or "normal")..";font-size:7pt;}")
        w:echo(compass_html(e[2],exists))
    end
    for _,entry in ipairs({{"exit_up","gora","↑",0},{"exit_down","dol","↓",1}}) do
        local w=S.widgets[entry[1]]
        local lit=exits[entry[2]]==true
        place(w,g.nav_x+67,g.top_y+11+entry[4]*20,
            26,16,entry[3],lit and "mint" or "muted")
        w:setStyleSheet("QLabel {background:transparent;border:0;color:"
            ..(lit and "#86E7BC" or "#4A5363")
            ..";font-family:'DejaVu Sans';font-weight:"
            ..(lit and "bold" or "normal")..";font-size:10pt;}")
        w:echo(compass_html(entry[3],lit))
        if type(w.setToolTip)=="function" then
            w:setToolTip(entry[2]..(lit and " (dostępne)" or " (brak wyjścia)"))
        end
    end
    local specials=current_special_exits()
    S.specials=specials
    local sx=g.nav_x+97
    local sw=math.max(1,g.nav-102)
    local header=S.widgets.special1
    -- The label of a room exit is shortened only visually.
    for i=1,3 do
        local w=S.widgets["special"..i]
        local cmd=specials[i]
        if cmd then
            local short=#cmd>14 and cmd:sub(1,11).."..." or cmd
            place(w,sx,g.top_y+16+(i-1)*12,sw,11,short,"peach")
            w:setStyleSheet("QLabel {background:transparent;border:0;color:#DABF9F;"
                .."font-family:'DejaVu Sans Mono';font-size:6pt;}")
            if type(w.setToolTip)=="function" then w:setToolTip(cmd) end
        else w:hide() end
    end
    -- Three full, tinted resource bars share the central panel.
    local pad=7
    local cell=(g.stats-2*pad)/3
    for i=1,3 do
        draw_primary(i,g.stats_x+pad+(i-1)*cell,(g.stats_y or g.top_y)+6,
            cell-6,T.profile(ctx.settings).bar,vitals[GAUGES[i][1]],view)
    end
    -- Four identically sized, *stacked* need indicators.
    local need_pad=4
    local row_w=g.needs-need_pad*2
    for offset=1,4 do
        local i=offset+3
        draw_need(i,g.needs_x+need_pad,g.top_y+3+(offset-1)*12,
            row_w,11,vitals[GAUGES[i][1]])
    end
    -- The old EXP widget pool (8) is no longer a main gauge.
    S.widgets.track8:hide()
    S.widgets.fill8:hide()
    S.widgets.gauge8:hide()
    draw_experience(width,vitals)
    -- Official state model controls visual feedback.
    local official_model=nil
    local sb=ctx:use("status_bar")
    if sb and type(sb.model)=="function" then
        local ok,value=pcall(sb.model)
        if ok and type(value)=="table" then official_model=value end
    end
    local states={}
    if official_model then
        for _,toggle in ipairs(official_model.toggles or {}) do
            if toggle.command=="/autowsparcie" then states[2]=toggle.on
            elseif toggle.command=="/autopogon" then states[3]=toggle.on end
        end
        if official_model.collect then states[4]=official_model.collect.on end
    end
    local lamp=ctx:use("lamp")
    if lamp and type(lamp.state)=="function" then
        local ok,state=pcall(lamp.state)
        if ok and type(state)=="table" then states[5]=state.lit end
    end
    local vip=rawget(_G,"chimera_vip")
    if vip and vip.settings and type(vip.settings.is_module_enabled)=="function" then
        local ok,result=pcall(vip.settings.is_module_enabled,vip.settings,"combat_colors",true)
        if ok then states[6]=result end
    end
    local controls_pad=4
    local cellw=(g.controls-2*controls_pad)/3
    for i,button in ipairs(BUTTONS) do
        local w=S.widgets["control"..i]
        local state=states[i]
        local symbol=button[1]
        local tooltip=button[3]
        local fg=state==true and "#A4F3CF" or
            state==false and "#798599" or "#C6CEDC"
        local background=state==true and "#2A4A41" or "#293143"
        local border=state==true and "#54957E" or "#465169"
        if i==1 then
            background="#45382E"
            fg="#E9C28D"
            border="#A48256"
            if official_model and official_model.mode then
                symbol=official_model.mode=="Atak" and "⚔" or "⛨"
                tooltip=button[3]..": "..official_model.mode
            end
        elseif state~=nil then
            tooltip=button[3]..": "..(state and "włączone" or "wyłączone")
        elseif i<=6 then
            tooltip=button[3]..": stan nieznany"
        end
        local col=(i-1)%3
        local line=math.floor((i-1)/3)
        place(w,g.controls_x+controls_pad+col*cellw,
            g.top_y+3+line*16,cellw-3,14,symbol,"text")
        w:setStyleSheet("QLabel {background-color:"..background
            ..";color:"..fg..";border:1px solid "..border
            ..";border-radius:3px;font-family:'DejaVu Sans';font-size:10pt;}"
            .."QLabel:hover {background-color:#39415C;border-color:#D0BBEA;}")
        if type(w.setToolTip)=="function" then w:setToolTip(tooltip) end
    end
    float_actions(width)
end

return {available=available, build=build, draw=draw_footer, resolve_exits=resolve_exits}
end
