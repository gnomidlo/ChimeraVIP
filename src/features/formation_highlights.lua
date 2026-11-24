-- Optional, profile-local formation highlighting.
local C,U=chimera_vip,chimera_vip.util
C.formation=C.formation or {}
local F=C.formation
U.clear_aliases(F); U.clear_triggers(F)
local keys={"druzyna_sukces","druzyna_porazka","inni_sukces","inni_porazka"}
local labels={"Druzyna - powodzenie","Druzyna - niepowodzenie","Pozostali - powodzenie","Pozostali - niepowodzenie"}
local defaults={druzyna_sukces="#8895A3",druzyna_porazka="#A38B91",inni_sukces="#81766D",inni_porazka="#686868"}
local function note(s) hecho("\n#C7B9E8[Szyk] #D8DCE6"..s.."\n") end
local function valid(s) return type(s)=="string" and s:match("^#%x%x%x%x%x%x$")~=nil end
function F:color(key)
    local v=C.settings:get("formation_colors."..key)
    return valid(v) and v or defaults[key]
end
function F:own(name,g)
    if not name then return true end
    g=g or {}
    local char=g.Char or {}
    local own=(char.Info or {}).name or (char.Name or {}).name
    name=name:lower()
    if type(own)=="string" and own:lower()==name then return true end
    local members=(((g.Chimera or {}).Group or {}).State or {}).members
    for _,m in pairs(type(members)=="table" and members or {}) do
        if type(m)=="table" and type(m.name)=="string" and m.name:lower()==name then return true end
    end
    return false
end
-- Return exact byte spans; never search again for a short word inside a name.
function F:parse(s,g)
    local spans={}
    local function add(a,b) if a and b then spans[#spans+1]={a,b} end end
    local function find(p,start) local a,b=s:find(p,start or 1); add(a,b); return a,b end
    local actor,failed
    if s:match("^Jestes gotow[ya] do zmiany w szyku%.$") then
        add(1,#s)
    elseif s:match(" jest gotow[ay] do kolejnej zmiany w szyku%.$") then
        actor=s:match("^(.-) jest gotow[ay]")
        find("jest gotow[ay] do kolejnej zmiany w szyku%.$")
    elseif s:match("^Glosno wypowiadasz rozkaz ") then
        local p=s:match("^(Glosno wypowiadasz rozkaz zasloniecia ciebie)") or s:match("^(Glosno wypowiadasz rozkaz ataku na)") or s:match("^(Glosno wypowiadasz rozkaz zasloniecia)")
        if not p then return end
        add(1,#p)
    else
        local suffix=", lecz nie jest w stanie tego uczynic."
        failed=s:sub(-#suffix)==suffix
        local body=failed and s:sub(1,-#suffix-1) or s
        local a,b
        if failed then
            a,b=body:find(" probuje cie zaslonic ")
            if not a then a,b=body:find(" probuje zaslonic ") end
        else
            a,b=body:find(" zaslania ")
            if not a then a,b=body:find("^Zaslaniasz ") end
        end
        if not a then return end
        local start=a==1 and 1 or a+1
        if a>1 then actor=s:sub(1,a-1):gsub("%s+$","") end
        local x,y=body:find(" przed twoimi ciosami",b)
        if x and y~=#body and body:sub(y+1)~="." then x=nil end
        if not x then x,y=body:find(" przed ciosami ",b) end
        if x and x<b then return end
        if not x or (not failed and body:sub(-1)~=".") then return end
        if body:sub(x,x)~=" " then return end
        add(start,b-1)
        if body:sub(b+1,x-1)=="cie" then add(b+1,x-1) end
        add(x+1,body:sub(y,y)==" " and y-1 or y)
        if failed then add(#body+3,#s) end
    end
    return (self:own(actor,g) and "druzyna_" or "inni_")..(failed and "porazka" or "sukces"),spans
end
function F:highlight(s)
    if not C.settings:is_module_enabled("formation",true) then return end
    local key,spans=self:parse(s,gmcp)
    if not key then return end
    local r,g,b=U.hex_to_rgb(self:color(key))
    for _,v in ipairs(spans) do
        local part=s:sub(v[1],v[2])
        local n,pos=0,1
        while true do
            local a,z=s:find(part,pos,true)
            if not a or a>v[1] then break end
            n=n+1; pos=z+1
            if a==v[1] then
                if selectString(part,n)>-1 then setFgColor(r,g,b); setUnderline(true) end
                break
            end
        end
    end
    deselect(); resetFormat()
end
local palette={"#8895A3","#AFCBF4","#788A9C","#A0ADB8","#718096","#A38B91","#F0A8B8","#9C8580","#81766D","#F2C4A0","#686868","#858585","#A0A0A0","#D8DCE6","#A8DCC2","#C7B9E8","#EFD8A6","#60A5FA","#EF4444","#F97316"}
function F:set_color(key,value)
    if not defaults[key] or not valid(value) then note("Uzycie: /szyk kolor KATEGORIA #RRGGBB"); return end
    if C.settings:set("formation_colors."..key,value:upper()) then self:menu() end
end
function F:picker(key)
    if not defaults[key] then return end
    note("Wybierz kolor lub /szyk kolor "..key.." #RRGGBB")
    for i,hex in ipairs(palette) do
        hechoLink(hex.."■ "..hex.."  ",string.format("chimera_vip.formation:set_color(%q,%q)",key,hex),"Wybierz kolor",true)
        if i%4==0 then hecho("\n") end
    end
    hecho("\n")
    hechoLink("#AFCBF4Wroc","chimera_vip.formation:menu()","Menu szyku",true); hecho("\n")
end
function F:menu()
    note("KOLORY SZYKU")
    for i,key in ipairs(keys) do
        local hex=self:color(key)
        hecho("#D8DCE6  "..labels[i].."  ")
        hechoLink(hex.."■ "..hex,string.format("chimera_vip.formation:picker(%q)",key),"Zmien kolor",true)
        hecho("\n")
    end
    hechoLink("#AFCBF4Podglad","chimera_vip.formation:preview()","Pokaz przyklady",true)
    hecho("  ")
    hechoLink("#AEB6C5Domyslne","chimera_vip.formation:reset()","Przywroc kolory",true)
    hecho("\n")
end
function F:reset()
    if C.settings:set("formation_colors",{}) then self:menu() end
end
function F:preview()
    local g={Chimera={Group={State={members={{name="Uzzarna"}}}}}}
    for _,s in ipairs({
        "Uzzarna zaslania cie przed ciosami trolla.",
        "Uzzarna probuje cie zaslonic przed ciosami trolla, lecz nie jest w stanie tego uczynic.",
        "Warg zaslania trolla przed twoimi ciosami.",
        "Warg probuje zaslonic trolla przed twoimi ciosami, lecz nie jest w stanie tego uczynic."
    }) do
        local key,spans=self:parse(s,g)
        local pos=1
        for _,v in ipairs(spans or {}) do
            hecho("#D8DCE6"..s:sub(pos,v[1]-1))
            setUnderline(true); hecho(self:color(key)..s:sub(v[1],v[2])); resetFormat()
            pos=v[2]+1
        end
        hecho("#D8DCE6"..s:sub(pos).."\n"); resetFormat()
    end
end
C.settings:register_module("formation",{title="Oznaczenia szyku",description="Kolorowanie i podkreslanie manewrow druzyny i pozostalych.",default=true,section="combat",order=20})
F.trigger_ids={tempRegexTrigger([[^(?:Jestes gotow[ya] do zmiany w szyku\.|.+ jest gotow[ay] do kolejnej zmiany w szyku\.|Glosno wypowiadasz rozkaz (?:zasloniecia|ataku na).*$|(?:Zaslaniasz|.+ zaslania|.+ probuje (?:cie )?zaslonic) .+|.+ probuje cie zaslonic przed ciosami .+)$]],function() F:highlight(line or matches[1]) end)}
F.alias_ids={
    tempAlias([[^/szyk(?:\s+kolory)?\s*$]],function() F:menu() end),
    tempAlias([[^/szyk podglad\s*$]],function() F:preview() end),
    tempAlias([[^/szyk kolor (\S+) (#\S+)\s*$]],function() F:set_color(matches[2],matches[3]) end),
    tempAlias([[^/szyk (on|off)\s*$]],function()
        local enabled=matches[2]=="on"
        if C.settings:set_module_enabled("formation",enabled) then note(enabled and "WLACZONE" or "WYLACZONE") end
    end),
    tempAlias([[^/szyk pomoc\s*$]],function() note("/szyk kolory, /szyk podglad, /szyk on, /szyk off") end)
}
return F
