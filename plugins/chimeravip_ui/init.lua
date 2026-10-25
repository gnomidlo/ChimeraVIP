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
    {"hp","życie","hp"},{"mana","mana","mp"},
    {"fatigue","siły","zm"},{"thirst","pragnienie","blue"},
    {"hunger","głód","mint"},{"encumbrance","obciążenie","peach"},
    {"panic","panika","rose"},{"progress","EXP","lavender"},
}
local BUTTONS = {
    {"⚔","/tryb_ataku","Tryb ataku"},
    {"⬡","/autowsparcie","Autowsparcie"},
    {"➤","/autopogon","Autopogoń"},
    {"♣","/zbieranie","Zbieranie"},
    {"✦","/lampa","Lampa"},
    {"◐","@kolory","Kolorowanie walki"},
    {"⌨","/mbind","MBindy"},
    {"⚙","/cvhud ustawienia","Ustawienia"},
    {"↶","/cvhud oficjalny","Oficjalny HUD"},
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
-- Mudlet's rich-text QLabel can ignore CSS foreground color when echo()
-- inserts formatted text. Set the compass foreground inside the text too.
local function compass_html(label,active)
    local shade=active and "#86E7BC" or "#4A5363"
    local body=active and ("<b>"..label.."</b>") or label
    return "<center><font color='"..shade.."'>"..body.."</font></center>"
end
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
        -- Public keybinding functions are shared with the Geyser click callbacks.
        -- Always read current GMCP when invoked; a timer-rendered list may
        -- still contain commands from a previous room.
        local resolve_exits
        local function slot_number(index,limit)
            local n=tonumber(index)
            if n and n==math.floor(n) and n>=1 and n<=limit then return n end
            return nil
        end

        local function trim(v)
            return tostring(v or ""):gsub("^%s+",""):gsub("%s+$","")
        end
        local function html_escape(v)
            return tostring(v or ""):gsub("&","&amp;"):gsub("<","&lt;")
                :gsub(">","&gt;"):gsub('"',"&quot;")
        end
        local function current_room_id()
            local room=gmcp.room()
            local id=type(room)=="table" and room.id
            if not id then
                local raw=rawget(_G,"gmcp")
                local fallback=type(raw)=="table" and raw.Room and raw.Room.Info
                id=type(fallback)=="table" and fallback.id
            end
            return type(id)=="string" and id~="" and id or nil
        end
        local db={version=2,next_id=1,rooms={},defaults={}}
        local function database_path()
            if type(getMudletHomeDir)~="function" then return nil end
            local home=getMudletHomeDir()
            if type(home)~="string" or home=="" then return nil end
            local dir=home.."/ChimeraVIP-data"
            local vip=rawget(_G,"chimera_vip")
            if vip and vip.util and type(vip.util.ensure_dir)=="function" then
                vip.util.ensure_dir(dir)
            elseif type(createDirectory)=="function" then
                createDirectory(dir)
            elseif type(lfs)=="table" and type(lfs.mkdir)=="function" then
                lfs.mkdir(dir)
            end
            return dir.."/room_actions.lua"
        end
        local actions_path=database_path()
        local function load_actions()
            if not actions_path or type(table.load)~="function" then return end
            local loaded={}
            local ok=pcall(table.load,actions_path,loaded)
            if ok and type(loaded.rooms)=="table" then
                db.rooms=loaded.rooms
                db.defaults=type(loaded.defaults)=="table" and loaded.defaults or {}
                db.next_id=math.max(1,tonumber(loaded.next_id) or 1)
            end
        end
        local function save_actions()
            if not actions_path or type(table.save)~="function" then
                info("Nie mozna zapisac akcji: brak table.save lub katalogu profilu.")
                return false
            end
            local ok,result=pcall(table.save,actions_path,db)
            if not ok or result==false then
                info("Blad zapisu wlasnych akcji. Sprawdz katalog ChimeraVIP-data.")
                return false
            end
            return true
        end
        load_actions()
        local function room_records(roomid,create)
            if not roomid then return nil end
            local list=db.rooms[roomid]
            if type(list)~="table" then
                if not create then return {} end
                list={}
                db.rooms[roomid]=list
            end
            return list
        end
        local function personal_actions()
            local rid=current_room_id()
            local records=room_records(rid,false) or {}
            local output={}
            for _,entry in ipairs(records) do
                if type(entry)=="table" and type(entry.name)=="string" and
                    type(entry.value)=="string" and
                    (entry.kind=="send" or entry.kind=="alias" or entry.kind=="sequence") then
                    output[#output+1]=entry
                end
            end
            return output
        end
        local function combined_actions()
            local result={}
            local official=locations.room_actions()
            if type(official)=="table" then
                for i,entry in ipairs(official) do
                    if type(entry)=="table" and type(entry.command)=="string" and
                        entry.command~="" then
                        result[#result+1]={source="official",index=i,
                            title=entry.command,command=entry.command,key=entry.key}
                    end
                end
            end
            for _,entry in ipairs(personal_actions()) do
                result[#result+1]={source="vip",entry=entry,
                    title=entry.name,command=entry.value}
            end
            return result
        end
        local function run_personal(entry)
            if entry.kind=="alias" then
                if type(expandAlias)~="function" then return false end
                expandAlias(entry.value,false)
            elseif entry.kind=="sequence" then
                for i,command in ipairs(entry.steps or {}) do
                    local step=command
                    if i==1 then
                        ctx:send(command,true)
                    else
                        ctx:timer((i-1)*0.15,function()
                            if not S.destroyed then ctx:send(step,true) end
                        end)
                    end
                end
            else
                ctx:send(entry.value,true)
            end
            return true
        end
        -- An explicit default wins; with exactly one custom action, use it
        -- automatically. Avoid ever guessing among multiple candidates.
        local function map_default()
            local rid=current_room_id()
            if not rid then return nil end
            local entries=personal_actions()
            local stored=db.defaults[rid]
            if stored then
                for _,entry in ipairs(entries) do
                    if tonumber(entry.id)==tonumber(stored) then return entry end
                end
                return nil
            end
            if #entries==1 then return entries[1] end
            return nil
        end
        local function map_default_name()
            local entry=map_default()
            return entry and entry.name or nil
        end
        local function map_run()
            local entry=map_default()
            if not entry then return false end
            return run_personal(entry)
        end
        local schedule
        local function delete_action(roomid,id)
            if current_room_id()~=roomid then return false end
            local records=room_records(roomid,false)
            for i,entry in ipairs(records) do
                if tonumber(entry.id)==tonumber(id) then
                    table.remove(records,i)
                    if db.defaults[roomid]==entry.id then db.defaults[roomid]=nil end
                    if #records==0 then db.rooms[roomid]=nil end
                    save_actions()
                    info("Usunieto akcje: "..entry.name)
                    if schedule then schedule() end
                    return true
                end
            end
            return false
        end
        local function current_special_exits()
            if not resolve_exits then return {} end
            local exits=resolve_exits()
            local normal={gora=true,dol=true}
            for _,entry in ipairs(EXITS) do normal[entry[1]]=true end
            local result={}
            for command in pairs(exits) do
                if not normal[command] then result[#result+1]=command end
            end
            table.sort(result)
            return result
        end
        local function special_exit(index)
            local slot=slot_number(index,3)
            if not slot then return false end
            local command=current_special_exits()[slot]
            if not command then return false end
            ctx:send(command,true)
            return true
        end
        local function room_action(index)
            local slot=slot_number(index,12)
            if not slot then return false end
            local action=combined_actions()[slot]
            if not action then return false end
            if action.source=="official" then
                locations.run_action(action.index)
                return true
            end
            return run_personal(action.entry)
        end
        local vip=rawget(_G,"chimera_vip")
        if type(vip)~="table" then
            vip={}
            _G.chimera_vip=vip
        end
        if type(vip.ui)~="table" then vip.ui={} end
        local public_ui=vip.ui
        local old_special,old_action=public_ui.special_exit,public_ui.room_action
        local old_delete=public_ui.delete_action
        local map_actions=type(vip.map_action)=="table" and vip.map_action or nil
        local old_map_run=map_actions and map_actions._runner
        local old_map_status=map_actions and map_actions._status
        if map_actions then
            map_actions._runner=map_run
            map_actions._status=map_default_name
        end
        public_ui.special_exit=special_exit
        public_ui.room_action=room_action
        public_ui.delete_action=delete_action
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
            -- A henchman/pacholek uses the same two-character leading slot
            -- as the leader star. Preserve alignment without suffix clutter.
            local prefix=p.henchman and "♟ " or (p.leader and "★ " or "  ")
            print_segment(prefix,p.henchman and "yellow" or tint,click,
                ally and "Zaslon" or "Atak")
            print_segment("["..mark.."] ",tint,click,
                ally and "Zaslon" or "Atak")
            local blocks=hp and math.floor(math.max(0,math.min(100,hp))/12.5) or 0
            local hp_text=hp and string.format("%s%s %3d%% ",
                string.rep("█",blocks),string.rep("░",8-blocks),math.floor(hp))
                or "────────  --  "
            print_segment(hp_text,hp and (hp<30 and "rose" or hp<60 and "yellow" or "mint") or "muted",
                ally and not self_row and id and ("wycofaj sie za "..id) or nil,
                "Wycofaj sie za")
            print_segment(self_row and "JA" or clean(p.name),tint,click)
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
                        tostring(p.henchman),tostring(p.leader),
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
                    row:echo(string.rep("&nbsp;",7)..html_escape(short))
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
            background:move(rail_x,65)
            background:resize(rail_w,7)
            background:setStyleSheet("QLabel {background-color:#343C4D;border:0;border-radius:2px;}")
            background:show()
            if capped>0 then
                base:move(rail_x,65)
                base:resize(math.max(1,math.floor(rail_w*capped/100)),4)
                base:setStyleSheet("QLabel {background-color:#AC97D4;border:0;border-radius:2px;}")
                base:show()
            else base:hide() end
            if overflow>0 then
                local tier=math.floor((overflow-1)/100)
                local part=((overflow-1)%100+1)/100
                local shades={"#DFB779","#E6B56E","#EDB05C","#F3BC51"}
                over_bg:move(rail_x,70)
                over_bg:resize(rail_w,2)
                over_bg:setStyleSheet("QLabel {background-color:#343C4D;border:0;}")
                over_bg:show()
                extra:move(rail_x,70)
                extra:resize(math.max(1,math.floor(rail_w*part)),2)
                extra:setStyleSheet("QLabel {background-color:"..shades[math.min(tier+1,#shades)]
                    ..";border:0;}")
                extra:show()
            else
                over_bg:hide()
                extra:hide()
            end
            place(title,7,62,33,11,"EXP","lavender")
            title:setStyleSheet("QLabel {background:transparent;border:0;color:#C7B9E8;"
                .."font-family:'DejaVu Sans Mono';font-size:7pt;}")
            local display=not p and "--" or (p>100 and
                ("100% +"..math.floor(p-100+0.5).."%") or math.floor(p+0.5).."%")
            place(number,width-97,62,87,11,display,"lavender")
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
            return {
                nav_x=nav_x,nav=nav,stats_x=stats_x,stats=stats,
                needs_x=needs_x,needs=needs,controls_x=controls_x,
                controls=controls,top_y=4,top_h=53,
            }
        end
        local function draw_footer(view)
            if not S.built then return end
            local width=tonumber((getMainWindowSize())) or 1200
            -- Client window widths below 640 cannot fit four panels
            -- with readable labels; the supported laptop range is 760+.
            width=math.max(640,width)
            local g=geometry(width)
            local exits=resolve_exits()
            local vitals=current_vitals()
            local bg=S.widgets.hud_background
            bg:move(0,0)
            bg:resize(width,HEIGHT)
            bg:setStyleSheet("QLabel {background-color:#1B2030;border:0;"
                .."border-top:2px solid #535E77;}")
            bg:show()
            panel(S.widgets.section_exits,g.nav_x,g.top_y,g.nav,g.top_h)
            panel(S.widgets.section_stats,g.stats_x,g.top_y,g.stats,g.top_h)
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
                draw_primary(i,g.stats_x+pad+(i-1)*cell,g.top_y+6,
                    cell-6,41,vitals[GAUGES[i][1]],view)
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
        schedule=function()
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

        local function usage()
            info("Akcje bieżącej lokacji:")
            cecho("<light_grey>  /cvakcja dodaj Nazwa - komenda<reset>\n")
            cecho("<light_grey>  /cvakcja alias Nazwa - alias (np. naps lub /wlm)<reset>\n")
            cecho("<light_grey>  /cvakcja sekwencja Nazwa - komenda1, komenda2, ...<reset>\n")
            cecho("<light_grey>  /cvakcja usun Nazwa<reset>\n")
            cecho("<light_grey>  /cvakcja domyslna Nazwa | brak<reset>\n")
            local selected=map_default()
            if selected then
                cecho("<199,185,232>  [⌖ Mapa]<reset> "..html_escape(selected.name).."\n")
            end
            local rid=current_room_id()
            if not rid then
                info("Brak ID lokacji w GMCP — nie moge dodawac akcji.")
                return
            end
            local records=room_records(rid,false)
            if #records==0 then
                info("Brak wlasnych akcji w tej lokacji.")
                return
            end
            for i,entry in ipairs(records) do
                local kind=entry.kind=="send" and "komenda" or
                    (entry.kind=="alias" and "alias" or "sekwencja")
                local chosen=selected and entry.id==selected.id
                cecho(string.format("<lavender> %d.<reset> %s <dim_grey>(%s)<reset>%s",
                    i,html_escape(entry.name),kind,
                    chosen and " <199,185,232>[⌖]<reset>" or ""))
                if type(echoLink)=="function" then
                    local script="chimera_vip.ui.delete_action("..
                        string.format("%q",rid)..","..tostring(entry.id)..")"
                    echoLink(" [usun]",script,"Usun: "..entry.name,true)
                else
                    cecho(" [usun: /cvakcja usun "..entry.name.."]")
                end
                cecho("\n")
            end
        end
        ctx:command{"cvakcja",args="[dodaj|alias|sekwencja|usun|domyslna] ...",
            help="Wlasne akcje przypisane do aktualnej lokacji",fn=function(arg)
                local input=trim(arg)
                if input=="" or input=="pomoc" or input=="lista" then
                    usage()
                    return
                end
                local op,rest=input:match("^(%S+)%s+(.+)$")
                if input=="domyslna" then
                    local selected=map_default()
                    if selected then
                        cecho("\n<199,185,232>[⌖ Mapa]<reset> Domyslna: "..html_escape(selected.name).."\n")
                    else
                        info("Brak domyslnej akcji mapowej w tym pokoju.")
                    end
                    return
                end
                if not op then usage(); return end
                if op=="domyslna" then
                    local rid=current_room_id()
                    if not rid then info("Brak ID lokacji GMCP."); return end
                    local name=trim(rest)
                    if name:lower()=="brak" then
                        db.defaults[rid]=nil
                        save_actions()
                        info("Usunieto domyslna akcje mapowa.")
                        if schedule then schedule() end
                        return
                    end
                    for _,entry in ipairs(personal_actions()) do
                        if entry.name:lower()==name:lower() then
                            db.defaults[rid]=entry.id
                            if save_actions() then
                                cecho("\n<199,185,232>[⌖ Mapa]<reset> Domyslna: "..
                                    html_escape(entry.name).."\n")
                            end
                            if schedule then schedule() end
                            return
                        end
                    end
                    info("Nie znaleziono takiej wlasnej akcji w pokoju.")
                    return
                end
                if op=="usun" then
                    local rid=current_room_id()
                    if not rid then info("Brak ID lokacji GMCP."); return end
                    local records=room_records(rid,false)
                    for _,entry in ipairs(records) do
                        if entry.name:lower()==trim(rest):lower() then
                            delete_action(rid,entry.id)
                            return
                        end
                    end
                    info("Nie znaleziono takiej wlasnej akcji w pokoju.")
                    return
                end
                if op~="dodaj" and op~="alias" and op~="sekwencja" then
                    usage()
                    return
                end
                local name,value=rest:match("^(.-)%s+%-%s+(.+)$")
                name,value=trim(name),trim(value)
                if name=="" or value=="" then
                    info("Skladnia: /cvakcja "..op.." Nazwa - tresc")
                    return
                end
                local rid=current_room_id()
                if not rid then info("Brak ID lokacji GMCP."); return end
                local steps=nil
                if op=="sekwencja" then
                    steps={}
                    for part in (value..","):gmatch("(.-),") do
                        part=trim(part)
                        if part=="" then
                            info("Sekwencja nie moze zawierac pustych krokow.")
                            return
                        end
                        steps[#steps+1]=part
                    end
                end
                local records=room_records(rid,true)
                local entry=nil
                for _,item in ipairs(records) do
                    if item.name:lower()==name:lower() then entry=item; break end
                end
                if entry==nil then
                    entry={id=db.next_id}
                    db.next_id=db.next_id+1
                    records[#records+1]=entry
                end
                entry.name=name
                entry.kind=op=="dodaj" and "send" or (op=="sekwencja" and "sequence" or op)
                entry.value=value
                entry.steps=steps
                if save_actions() then
                    info("Zapisano akcje '"..name.."' dla obecnej lokacji.")
                end
                if schedule then schedule() end
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
            S.destroyed=true
            if public_ui.delete_action==delete_action then
                public_ui.delete_action=old_delete
            end
            if map_actions and map_actions._runner==map_run then
                map_actions._runner=old_map_run
            end
            if map_actions and map_actions._status==map_default_name then
                map_actions._status=old_map_status
            end
            if public_ui.special_exit==special_exit then
                public_ui.special_exit=old_special
            end
            if public_ui.room_action==room_action then
                public_ui.room_action=old_action
            end
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
