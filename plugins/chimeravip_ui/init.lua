-- ChimeraVIP 5: pastel footer and independent, dockable Kondycje.
-- Public GMCP/team/locations API only; the official UI is never monkeypatched.
local WINDOW, HEIGHT = "chimeravip_kondycje", 120
local P = {
    bg="#181C26", soft="#232938", edge="#353C4C", text="#D8DCE6",
    muted="#AEB6C5", mint="#A8DCC2", blue="#AFCBF4",
    lavender="#C7B9E8", peach="#F2C4A0", rose="#F0A8B8", yellow="#EFD8A6",
}
local EXITS = {
    {"polnocny-zachod","NW"},{"polnoc","N"},{"polnocny-wschod","NE"},
    {"zachod","W"},{"","·"},{"wschod","E"},
    {"poludniowy-zachod","SW"},{"poludnie","S"},{"poludniowy-wschod","SE"},
}
local GAUGES = {
    {"hp","KOND","rose"},{"mana","MANA","blue"},
    {"fatigue","ZMECZ","yellow"},{"progress","EXP","lavender"},
    {"thirst","PRAGN","blue"},{"hunger","GLOD","mint"},
    {"encumbrance","OBC","peach"},{"panic","PANIKA","rose"},
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
        .."font-family:'DejaVu Sans Mono';font-size:9pt; }"
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
    deps={"gmcp","team","locations","status_bar","room_window"},
    settings={
        mode={type="enum",values={"vip","oficjalny"},default="vip",label="Interfejs",order=1},
        kondycje={type="boolean",default=true,label="VIP Kondycje",order=2},
        akcje={type="boolean",default=true,label="Akcje lokacji",order=3},
    },
    setup=function(ctx)
        local gmcp,team,locations=ctx:use("gmcp"),ctx:use("team"),ctx:use("locations")
        ctx.state.vip_generation=(ctx.state.vip_generation or 0)+1
        local generation=ctx.state.vip_generation
        local S={active=false,built=false,opened=false,pending=false,widgets={},
            marks={members={},enemies={}},signature=nil,root=nil}
        local function available()
            return type(Geyser)=="table" and type(Geyser.Container)=="table"
                and type(Geyser.Label)=="table" and type(getMainWindowSize)=="function"
                and type(setBorderBottom)=="function" and type(openUserWindow)=="function"
                and type(clearWindow)=="function" and type(cechoLink)=="function"
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
            for i,exit in ipairs(EXITS) do
                local command=exit[1]
                widget("exit"..i,command~="" and function() ctx:send(command,true) end or nil)
            end
            for i=1,#GAUGES do widget("gauge"..i) end
            for i,button in ipairs(BUTTONS) do
                local command=button[2]
                widget("control"..i,function() action(command) end)
            end
            for i=1,3 do
                local index=i
                widget("action"..i,function() locations.run_action(index) end)
            end
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
                if type(setFontSize)=="function" then setFontSize(WINDOW,10) end
                S.opened=true
            elseif type(showWindow)=="function" then showWindow(WINDOW) end
        end
        local function official(on)
            -- Documented official public commands, never private module fields.
            alias("/pasek pasek "..(on and "tak" or "nie"))
            alias("/ustaw kondycje okno "..(on and "tak" or "nie"))
        end
        local function restore()
            if S.root then S.root:hide() end
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
        local function print_segment(text,tint,command,hint)
            local formatted="<"..color(tint)..">"..clean(text).."<reset>"
            if command then
                cechoLink(WINDOW,formatted,
                    "send("..string.format("%q",command)..", false)",
                    hint or command,true)
            else cecho(WINDOW,formatted) end
        end
        local function row(mark,p,ally,self_row,map,fighting)
            local id=p.id and tostring(p.id) or nil
            local hp=tonumber(p.hp)
            local tint=p.stunned and "lavender" or (ally and "mint" or "rose")
            if ally and p.here==false then tint="muted" end
            local attack=id and ("zabij "..id) or nil
            local cover=ally and not self_row and id and ("zaslon "..id) or nil
            local click=ally and cover or attack
            print_segment((p.leader and "★ " or "  ").."["..mark.."] ",tint,click,
                ally and "Zaslon" or "Atak")
            local blocks=hp and math.floor(math.max(0,math.min(100,hp))/12.5) or 0
            local hp_text=hp and string.format("[%s%s] %3d%% ",
                string.rep("#",blocks),string.rep(".",8-blocks),math.floor(hp))
                or "[--------]  --  "
            print_segment(hp_text,hp and (hp<30 and "rose" or hp<60 and "yellow" or "mint") or "muted",
                ally and not self_row and id and ("wycofaj sie za "..id) or nil,
                "Wycofaj sie za")
            print_segment(self_row and "JA" or clean(p.name),tint,click)
            if p.henchman then print_segment(" [P]","yellow") end
            if p.stunned then print_segment(" [OGL]","lavender") end
            if fighting and ally and not self_row and not p.attacking
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
            cecho(WINDOW,"\n")
        end
        local function draw_window(view)
            if not S.opened or not ctx.settings.kondycje then return end
            local map=index_view(view)
            local signatures={}
            for _,list in ipairs({{view.self or {}},view.members or {},view.enemies or {},view.others or {}}) do
                for _,p in ipairs(list) do
                    signatures[#signatures+1]=table.concat({
                        tostring(p.id),tostring(p.hp),tostring(p.attacking),
                        tostring(p.here),tostring(p.stunned),
                        table.concat(p.attackers or {},","),
                    },":")
                end
            end
            local signature=table.concat(signatures,"|")
            if S.signature==signature then return end
            S.signature=signature
            clearWindow(WINDOW)
            print_segment("  ◆ DRUZYNA\n","lavender")
            local me=view.self or {}
            local fighting=me.attacking or (me.attackers and #me.attackers>0) or false
            for _,p in ipairs(view.members or {}) do
                if p.attacking or (p.attackers and #p.attackers>0) then fighting=true end
            end
            row("@",me,true,true,map,fighting)
            for i,p in ipairs(view.members or {}) do row(alpha(i),p,true,false,map,fighting) end
            for _,part in ipairs({{view.enemies or {},"WROGOWIE"},
                                   {view.others or {},"POZOSTALI"}}) do
                if #part[1]>0 then
                    print_segment("\n  ◆ "..part[2].."\n","lavender")
                    for _,p in ipairs(part[1]) do
                        row(map.by_id[tostring(p.id)] or "?",p,false,false,map,fighting)
                    end
                end
            end
        end
        local function draw_footer()
            if not S.built then return end
            local width=tonumber((getMainWindowSize())) or 1000
            width=math.max(350,width)
            local room=gmcp.room() or {}
            local exits=type(room.exits)=="table" and room.exits or {}
            local vitals=gmcp.vitals() or {}
            for i,exit in ipairs(EXITS) do
                local col=(i-1)%3
                local line=math.floor((i-1)/3)
                local enabled=exit[1]=="" or exits[exit[1]]~=nil
                place(S.widgets["exit"..i],6+col*58,8+line*32,53,27,exit[2],
                    enabled and "mint" or "muted")
            end
            local x=193
            local space=math.max(100,width-x-8)
            local columns=space>=680 and 4 or 2
            for i,gauge in ipairs(GAUGES) do
                local w=S.widgets["gauge"..i]
                if i<=columns*2 then
                    local value=tonumber(vitals[gauge[1]])
                    local text=gauge[2]..": "..(value and (math.floor(value+0.5).."%") or "--")
                    place(w,x+((i-1)%columns)*space/columns,
                        8+math.floor((i-1)/columns)*26,
                        space/columns-5,22,text,gauge[3])
                else w:hide() end
            end
            local button_width=(space-5)/#BUTTONS
            for i,btn in ipairs(BUTTONS) do
                place(S.widgets["control"..i],x+(i-1)*button_width,62,
                    button_width-4,22,btn[1],"text")
            end
            local actions=ctx.settings.akcje and locations.room_actions() or {}
            for i=1,3 do
                local w=S.widgets["action"..i]
                local a=type(actions)=="table" and actions[i] or nil
                if a then
                    local text=clean(a.key or i).." "..clean(a.command or a.label or "Akcja")
                    if #text>24 then text=text:sub(1,21).."..." end
                    place(w,x+(i-1)*(space-5)/3,91,(space-5)/3-5,22,text,"yellow")
                else w:hide() end
            end
        end
        local function render()
            S.pending=false
            if not S.active then return end
            local ok,err=pcall(function()
                draw_footer()
                draw_window(team.view() or {self={},members={},enemies={},others={}})
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
        ctx:on("chimera.team.changed",schedule)
        ctx:on("chimera.room.changed",schedule)
        ctx:on("chimera.char.vitals",schedule)
        ctx:on("sysWindowResizeEvent",schedule)
        ctx:on("chimera.config.changed",function(module_name,key,value)
            if module_name=="chimeravip_ui" then
                if key=="mode" then switch(value)
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
