-- ChimeraVIP 5: conditions module.
return function(ctx,S,T,team)
local WINDOW,HEIGHT,P,EXITS,GAUGES,BUTTONS=T.WINDOW,T.HEIGHT,T.P,T.EXITS,T.GAUGES,T.BUTTONS
local clean,alpha,color,compass_html,style,alias,info=T.clean,T.alpha,T.color,T.compass_html,T.style,T.alias,T.info
local function index_view(view)
    local m={members={},enemies={},by_id={}}
    local own=view.self or {}
    if own.id then
        m.by_id[tostring(own.id)]="@"
        m.members["@"]=tostring(own.id)
    end
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
    if ctx.settings.rozmiar=="m" then text=T.upper(text) end
    if command and type(echoLink)=="function" then
        echoLink(WINDOW,clean(text),
            "send("..string.format("%q",command)..", false)",
            hint or command,true)
    else
        echo(WINDOW,clean(text))
    end
end
-- Former tactical_states_view behavior: keep recognizable name tails.
-- Count Unicode codepoints, not bytes: ♟ and █ take a single column.
local function chars_of(value)
    local result={}
    for char in tostring(value or ""):gmatch("[\1-\127\194-\244][\128-\191]*") do
        result[#result+1]=char
    end
    return result
end
local function visual_width(value) return #chars_of(value) end
local function window_columns()
    if type(getColumnCount)=="function" then
        local ok,columns=pcall(getColumnCount,WINDOW)
        columns=ok and tonumber(columns) or nil
        if columns and columns>0 then return math.floor(columns) end
    end
    return 72 -- Original Kondycje fallback when the window is unavailable.
end
local function fit_tail_words(value,width)
    local name=tostring(value or "")
    width=math.max(1,math.floor(tonumber(width) or 1))
    if visual_width(name)<=width then return name end
    if width==1 then return "…" end
    local words={}
    for word in name:gmatch("%S+") do words[#words+1]=word end
    local kept,used={},2 -- ellipsis and a space
    for i=#words,1,-1 do
        local extra=visual_width(words[i])+(#kept>0 and 1 or 0)
        if used+extra>width then break end
        table.insert(kept,1,words[i])
        used=used+extra
    end
    if #kept>0 then return "… "..table.concat(kept," ") end
    -- A single long word: preserve the Unicode tail without cutting bytes.
    local chars=chars_of(name)
    local tail={}
    for i=math.max(1,#chars-width+2),#chars do
        tail[#tail+1]=chars[i]
    end
    return "…"..table.concat(tail)
end
local function attacker_relation(p,map)
    local marks,seen={},{}
    local incoming=type(p.attackers)=="table" and p.attackers or {}
    for _,attacker in ipairs(incoming) do
        local mark=map.by_id[tostring(attacker)]
        if mark and not seen[mark] then
            marks[#marks+1]=mark
            seen[mark]=true
        end
    end
    table.sort(marks,function(a,b)
        if a=="@" then return true end
        if b=="@" then return false end
        local an,bn=tonumber(a),tonumber(b)
        if an and bn then return an<bn end
        if an then return false end
        if bn then return true end
        return a<b
    end)
    return #marks>0 and (" - ["..table.concat(marks,", ").."]") or ""
end
local function row(mark,p,ally,self_row,map,fighting,hostile,columns)
    local id=p.id and tostring(p.id) or nil
    local hp=tonumber(p.hp)
    -- Stun highlights ONLY the name, without recoloring the HP/mark.
    local tint=self_row and "lavender" or
        (ally and "mint" or (hostile and "rose" or "neutral"))
    if ally and p.here==false then tint="muted" end
    local attack=id and ("zabij "..id) or nil
    local cover=ally and not self_row and id and ("zaslon "..id) or nil
    local click=ally and cover or attack
    local prefix=p.henchman and "♟ " or (p.leader and "★ " or "  ")
    print_segment(prefix,p.henchman and "yellow" or tint,click,
        ally and "Zaslon" or "Atak")
    print_segment("["..mark.."] ",tint,click,
        ally and "Zaslon" or "Atak")
    local blocks=hp and math.floor(math.max(0,math.min(100,hp))/12.5) or 0
    local hp_text=hp and string.format("%s%s %3d%% ",
        string.rep("█",blocks),string.rep("░",8-blocks),math.floor(hp))
        or "────────  --  "
    local stacked=(ctx.settings.rozmiar=="m" or ctx.settings.rozmiar=="xl") and (columns or 72)<40
    local function health_line()
        print_segment(hp_text,hp and (hp<30 and "rose" or hp<60 and "yellow" or "mint") or "muted",
            ally and not self_row and id and ("wycofaj sie za "..id) or nil,
            "Wycofaj sie za")
    end
    if not stacked then health_line() end
    local idle=fighting and ally and not p.attacking
        and (not p.attackers or #p.attackers==0)
    -- Incoming relations only, as in the old Kondycje renderer:
    -- team members show who attacks them; enemies show their attackers.
    local relation=idle and " [X]" or attacker_relation(p,map)
    local fixed=visual_width(prefix.."["..mark.."] "..(stacked and "" or hp_text))
    local name=fit_tail_words(self_row and "JA" or clean(p.name),
        math.max(1,(columns or 72)-fixed-visual_width(relation)-1))
    if p.stunned and type(setBgColor)=="function"
        and type(resetFormat)=="function" then
        setBgColor(WINDOW,48,54,69) -- #303645
        print_segment(name,tint,click)
        resetFormat(WINDOW)
    else
        print_segment(name,tint,click)
    end
    if idle then
        print_segment(" [X]","yellow")
    elseif relation~="" then
        print_segment(relation,ally and "rose" or (hostile and "lavender" or "muted"))
    end
    echo(WINDOW,"\n")
    if stacked then
        health_line()
        echo(WINDOW,"\n")
    end
end
local function draw_window(view)
    if not S.opened or not ctx.settings.kondycje then return end
    local map=index_view(view)
    local columns=window_columns()
    local signatures={"columns="..columns,"size="..tostring(ctx.settings.rozmiar),
        "font="..tostring(ctx.settings.czcionka)}
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
    row("@",me,true,true,map,fighting,false,columns)
    for i,p in ipairs(view.members or {}) do row(alpha(i),p,true,false,map,fighting,false,columns) end
    for _,part in ipairs({{view.enemies or {},"WROGOWIE",true},
                           {view.others or {},"POZOSTALI",false}}) do
        if #part[1]>0 then
            print_segment("\n  "..part[2].."\n","lavender")
            for _,p in ipairs(part[1]) do
                row(map.by_id[tostring(p.id)] or "?",p,false,false,map,fighting,part[3],columns)
            end
        end
    end
end

-- Resolve only against the same fresh, official team.view() used to draw
-- Kondycje. Never trust the last rendered/global mark cache during GMCP churn.
local function resolve_target(kind,mark)
    if type(team)~="table" or type(team.view)~="function" then return nil end
    local ok,view=pcall(team.view)
    if not ok or type(view)~="table" then return nil end
    local map=index_view(view)
    -- When a keybind races the scheduled redraw, update visible marks first.
    -- This keeps the ID sent by the alias consistent with the letters shown.
    if S.active and S.opened and ctx.settings.kondycje then
        local drawn=pcall(draw_window,view)
        if not drawn then return nil end
    end
    mark=tostring(mark or "")
    if kind=="member" then return map.members[mark:upper()] end
    if kind=="enemy" then return map.enemies[mark] end
    return nil
end

return {draw=draw_window,resolve_target=resolve_target}
end
