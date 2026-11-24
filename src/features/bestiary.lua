-- Profile-local bestiary. Official mapper hashes are the durable location key.
local C,U=chimera_vip,chimera_vip.util
C.bestiary=C.bestiary or {}
local B=C.bestiary
local cases={"Mianownik","Dopelniacz","Celownik","Biernik","Narzednik","Miejscownik"}
local levels={["?"]="Nieoceniony",I="Latwy",II="Przecietny",III="Trudny",IV="Ekstremalnie trudny"}
local palette={["?"]="#A9AFBF",I="#A8DCC2",II="#EFD8A6",III="#F2B08A",IV="#F0A8B8"}
local order={"IV","III","II","I","?"}
local function trim(s) return tostring(s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function plain(s) return tostring(s or ""):gsub("#%x%x%x%x%x%x",""):gsub("[%c]"," ") end
local function out(s,color) hecho((color or "#D8DCE6")..plain(s).."\n") end
local function note(s) hecho("\n#C7B9E8[BOSS] "); out(s) end
local function valid(s)
    return type(s)=="string" and #s>0 and #s<=240 and
        s:match("^[%a%d\128-\255][%w\128-\255' %-]*$")~=nil
end
local function word(c) return c~="" and c:match("[%w_\128-\255'%-]")~=nil end
local function lower(s)
    local polish={["Ą"]="ą",["Ć"]="ć",["Ę"]="ę",["Ł"]="ł",["Ń"]="ń",["Ó"]="ó",["Ś"]="ś",["Ź"]="ź",["Ż"]="ż"}
    for a,b in pairs(polish) do s=s:gsub(a,b) end
    return s:lower()
end
local function link(label,method,key,arg)
    local action="chimera_vip.bestiary:"..method.."("..string.format("%q",key or "")
    if arg~=nil then action=action..","..string.format("%q",arg) end
    hechoLink("#C7B9E8["..label.."]",action..")",label,true)
    hecho("  ")
end
function B:cancel()
    self.pending=nil
    if self.timer then killTimer(self.timer); self.timer=nil end
end
function B:cleanup()
    self:cancel()
    U.clear_aliases(self); U.clear_triggers(self)
    for _,id in pairs(self.handlers or {}) do pcall(killAnonymousEventHandler,id) end
    self.handlers={}
end
B:cleanup()
local saved=C.settings.data.bestiary
B.data={entries={},colors=U.deep_copy(palette),enabled=true}
if type(saved)=="table" then
    B.data.enabled=saved.enabled~=false
    for k,v in pairs(type(saved.colors)=="table" and saved.colors or {}) do
        if levels[k] and type(v)=="string" and v:match("^#%x%x%x%x%x%x$") then B.data.colors[k]=v end
    end
    for k,e in pairs(type(saved.entries)=="table" and saved.entries or {}) do
        if type(e)=="table" and type(e.forms)=="table" and #e.forms==6 and valid(e.forms[1]) and lower(e.forms[1])==k then
            local ok=true
            for i=1,6 do if not valid(e.forms[i]) then ok=false end end
            if ok then
                e=U.deep_copy(e); e.level=levels[e.level] and e.level or "?"
                e.note=type(e.note)=="string" and e.note or ""
                B.data.entries[k]=e
            end
        end
    end
end
function B:rebuild()
    local owners={}
    for k,e in pairs(self.data.entries) do
        for _,f in ipairs(e.forms) do
            f=lower(f)
            if owners[f]==nil then owners[f]=k elseif owners[f]~=k then owners[f]=false end
        end
    end
    self.forms={}
    for f,k in pairs(owners) do if k then self.forms[#self.forms+1]={form=f,key=k} end end
    table.sort(self.forms,function(a,b) if #a.form~=#b.form then return #a.form>#b.form end return a.form<b.form end)
end
function B:commit(data)
    local old=C.settings.data.bestiary
    C.settings.data.bestiary=data
    local ok,result=pcall(C.settings.save,C.settings)
    if not ok or result==false then C.settings.data.bestiary=old; note("Nie udalo sie zapisac bazy."); return false end
    self.data=data; self:rebuild(); return true
end
local function mapped(hash)
    if type(hash)~="string" or type(getRoomIDbyHash)~="function" or type(getRoomHashByID)~="function" then return nil end
    local ok,id=pcall(getRoomIDbyHash,hash)
    if not ok or type(id)~="number" or id<=0 or id~=math.floor(id) then return nil end
    local good,actual=pcall(getRoomHashByID,id)
    if good and actual==hash then return id end
end
local function instance(room) return tonumber(room.instance) or (room.instance and room.instance~="" and room.instance or 0) end
function B:snapshot()
    local r=C.runtime:room()
    if not r or type(r.id)~="string" or r.id=="" then return nil end
    local id=mapped(r.id)
    local area
    if id and type(getRoomArea)=="function" and type(getRoomAreaName)=="function" then
        local ok,a=pcall(function() return getRoomAreaName(getRoomArea(id)) end)
        if ok and type(a)=="string" then area=a end
    end
    return {hash=r.id,instance=instance(r),mapper=id,name=r.name,area=area}
end
function B:add(query,level,n)
    query=trim(query)
    if not valid(query) or (level and not levels[level]) then note("Uzycie: /boss dodaj NAZWA [I-IV] [notatka]"); return false end
    if self.pending or (C.friends and C.friends.pending) then note("Trwa pobieranie odmian."); return false end
    local loc=self:snapshot()
    if not loc then note("Brak aktualnej lokacji GMCP."); return false end
    self.pending={query=query,location=loc,forms={},level=level or "?",note=n or ""}
    self.timer=tempTimer(10,function() B.timer=nil; B.pending=nil; note("Brak pelnej odmiany; nic nie zapisano.") end)
    send("odmien "..query,false); return true
end
function B:parse(text)
    local p=self.pending
    if not p then return end
    local header=text:match("^%s*(.-) odmienia sie nastepujaco:%s*$")
    if header then
        if p.header or not valid(header) then self:cancel(); return end
        -- A short query can be expanded by the server. Require a whole
        -- word/phrase match, not equality with the canonical name.
        local h,q=lower(header),lower(p.query)
        local start=1
        local found=false
        while true do
            local a,b=h:find(q,start,true); if not a then break end
            if not word(h:sub(a-1,a-1)) and not word(h:sub(b+1,b+1)) then found=true; break end
            start=b+1
        end
        if not found then self:cancel(); note("Odmiana nie pasuje do wskazanego celu."); return end
        p.header=header; return
    end
    if not p.header then return end
    local label,value,ending=text:match("^%s*([A-Za-z]+):%s*(.-)([,.])%s*$")
    local i=#p.forms+1
    if label~=cases[i] or not valid(value) or ending~=(i==6 and "." or ",")
        or (i==1 and lower(value)~=lower(p.header)) then self:cancel(); note("Niepelna odmiana; nic nie zapisano."); return end
    p.forms[i]=value
    if i~=6 then return end
    self:cancel()
    local k=lower(p.forms[1])
    if self.data.entries[k] then note("Boss juz zapisany; dane pozostaly bez zmian."); self:card(k); return end
    local now=self:snapshot()
    if not now or now.hash~=p.location.hash or now.instance~=p.location.instance then note("Lokacja zmienila sie; ponow dodawanie."); return end
    local data=U.deep_copy(self.data)
    data.entries[k]={forms=p.forms,location=p.location,level=p.level,note=p.note,created=os.time()}
    if self:commit(data) then note("Zapisano: "..p.forms[1]); self:card(k) end
end
function B:spans(text)
    local result,occupied={},{}
    local normalized=lower(text)
    for _,item in ipairs(self.forms) do
        local offset=1
        while true do
            local a,b=normalized:find(item.form,offset,true)
            if not a then break end
            local free=not word(text:sub(a-1,a-1)) and not word(text:sub(b+1,b+1))
            if free then for i=a,b do if occupied[i] then free=false; break end end end
            if free then
                for i=a,b do occupied[i]=true end
                local literal=text:sub(a,b)
                local n,pos=0,1
                while pos<=a do local x,y=text:find(literal,pos,true); if not x or x>a then break end; n=n+1; pos=y+1 end
                result[#result+1]={form=literal,n=n,key=item.key}
            end
            offset=b+1
        end
    end
    return result
end
function B:highlight(text)
    if not self.data.enabled then return end
    for _,s in ipairs(self:spans(text)) do
        if selectString(s.form,s.n)>-1 then
            local r,g,b=U.hex_to_rgb(self.data.colors[self.data.entries[s.key].level])
            setFgColor(r,g,b)
            if type(setBold)=="function" then setBold(true) end
        end
    end
    deselect(); resetFormat()
end
function B:resolve(q)
    q=lower(trim(q))
    if self.data.entries[q] then return q end
    local found
    for k in pairs(self.data.entries) do
        if q~="" and k:find(q,1,true) then
            if found then note("Wiele pasujacych bossow; wybierz z /boss."); return nil end
            found=k
        end
    end
    if not found then note("Nie znaleziono bossa.") end
    return found
end
function B:list(filter)
    hecho("\n#C7B9E8BESTIARIUSZ\n")
    local keys={}
    for k,e in pairs(self.data.entries) do if not levels[filter] or e.level==filter then keys[#keys+1]=k end end
    table.sort(keys,function(a,b)
        local rank={IV=4,III=3,II=2,I=1,["?"]=0}
        local x,y=rank[self.data.entries[a].level],rank[self.data.entries[b].level]
        if x~=y then return x>y end
        return a<b
    end)
    local last
    for _,k in ipairs(keys) do
        local e=self.data.entries[k]
        if last~=e.level then last=e.level; out("\n"..last.." - "..levels[last],self.data.colors[last]) end
        out("  ◆ "..e.forms[1],self.data.colors[e.level])
        local l=e.location or {}
        out("    "..(l.area or "").." / "..(l.name or l.hash or "Brak lokacji"),"#A9AFBF")
        hecho("    "); link("Idz","travel",k); link("Szczegoly","card",k); hecho("\n")
    end
    if #keys==0 then out("  Brak bossow.") end
    out("\nBossowie: "..#keys)
    for _,l in ipairs(order) do link(l,"list",l) end
    link("Wszystkie","list",""); link("Kolory","colors",""); hecho("\n")
end
function B:card(k)
    local e=self.data.entries[k]; if not e then return end
    local l=e.location or {}
    hecho("\n#C7B9E8BESTIARIUSZ\n")
    out("◆ "..e.forms[1],self.data.colors[e.level])
    out("  "..(l.area or "").." / "..(l.name or l.hash or "Brak lokacji"))
    out("  Mapper: "..tostring(mapped(l.hash) or "brak")..((l.instance and l.instance~=0) and " (instancja)" or ""))
    out("  Trudnosc: "..e.level.." - "..levels[e.level])
    for _,v in ipairs({"I","II","III","IV","?"}) do link((v==e.level and "* " or "")..v,"difficulty",k,v) end
    hecho("\n"); out("  Notatka: "..(e.note~="" and e.note or "Brak"))
    link("Idz","travel",k); link("Mapa","show_map",k); link("Notatka","edit_note",k)
    link("Zmien lokacje","relocate",k); hecho("\n")
    link("Odmiany","inflections",k); link("Usun","confirm_remove",k); link("Lista","list",""); hecho("\n")
end
function B:change(k,field,value)
    if not self.data.entries[k] then return false end
    local data=U.deep_copy(self.data); data.entries[k][field]=value
    if self:commit(data) then self:card(k); return true end
    return false
end
function B:difficulty(k,v) if levels[v] then return self:change(k,"level",v) end end
function B:edit_note(k)
    local e=self.data.entries[k]; if not e then return end
    if type(setCmdLine)=="function" then setCmdLine("/boss notatka "..e.forms[1].." | "..e.note:gsub("[\r\n]"," "))
    else note("Uzyj /boss notatka "..e.forms[1].." | tekst") end
end
function B:relocate(k)
    local l=self:snapshot()
    if not l then note("Brak aktualnej lokacji."); return end
    return self:change(k,"location",l)
end
function B:inflections(k)
    local e=self.data.entries[k]; if not e then return end
    for i,f in ipairs(e.forms) do out(cases[i]..": "..f,self.data.colors[e.level]) end
end
function B:confirm_remove(k)
    if not self.data.entries[k] then return end
    note("Usunac "..self.data.entries[k].forms[1].."?")
    link("Tak","remove",k); link("Anuluj","card",k); hecho("\n")
end
function B:remove(k)
    local data=U.deep_copy(self.data); data.entries[k]=nil
    if self:commit(data) then note("Usunieto bossa."); self:list() end
end
function B:destination(k)
    local e=self.data.entries[k]; if not e then return end
    local l=e.location or {}
    if l.instance and l.instance~=0 then note("Lokacja instancyjna: automatyczna nawigacja zablokowana."); return end
    local id=mapped(l.hash)
    if not id then note("Nie znaleziono zgodnej lokacji na mapie."); return end
    return id
end
function B:travel(k)
    local id=self:destination(k); if not id then return false end
    local here=self:snapshot()
    if not here or not here.mapper or here.instance~=0 then note("Brak stalej pozycji na mapie."); return false end
    local combat=C.runtime:combat()
    -- Conservative: any active relation blocks a new walk.
    if type(combat)~="table" or (combat.primary and combat.primary~="") or next(combat.relations or {}) then
        note("Walka lub brak danych o walce; nie uruchamiam chodzika."); return false
    end
    if type(expandAlias)~="function" then return false end
    expandAlias("/idz "..id,false); return true
end
function B:show_map(k)
    local id=self:destination(k)
    if id and type(centerview)=="function" then centerview(id) end
end
function B:set_color(level,hex)
    if not levels[level] or not hex:match("^#%x%x%x%x%x%x$") then return end
    local data=U.deep_copy(self.data); data.colors[level]=hex:upper()
    if self:commit(data) then self:colors(level) end
end
function B:colors(level)
    hecho("\n#C7B9E8BESTIARIUSZ - KOLORY\n")
    for _,v in ipairs(order) do
        out(v.." "..levels[v],self.data.colors[v]); link("Wybierz","colors",v); hecho("\n")
    end
    if levels[level] then
        for _,hex in ipairs({"#A9AFBF","#A8DCC2","#EFD8A6","#F2B08A","#F0A8B8","#C7B9E8","#AFCBF4","#FF4545","#00FF80"}) do
            hechoLink(hex.." ■ "..hex.." ", "chimera_vip.bestiary:set_color("..string.format("%q,%q",level,hex)..")","Ustaw kolor",true)
        end
        hecho("\n")
    end
    link(self.data.enabled and "Wylacz" or "Wlacz","toggle",""); hecho("\n")
end
function B:toggle()
    local data=U.deep_copy(self.data); data.enabled=not data.enabled
    if self:commit(data) then self:colors("") end
end
function B:help()
    out("/boss [I-IV|?] | /boss NAZWA | /boss dodaj CEL [I-IV] [notatka]")
    out("/boss idz|mapa|lokacja|usun|odmiany NAZWA")
    out("/boss trudnosc NAZWA IV | /boss notatka NAZWA | tekst")
    out("/bosskolor [I-IV #RRGGBB|on|off]")
end
function B:command(s)
    s=trim(s)
    if s=="" or levels[s] then return self:list(s) end
    if s=="pomoc" then return self:help() end
    local cmd,arg=s:match("^(%S+)%s+(.+)$")
    if cmd=="dodaj" then
        -- Optional level is a standalone uppercase token.
        local q,v,n=arg:match("^(.-)%s+(I[IV]*)%s+(.*)$")
        if not q then q,v=arg:match("^(.-)%s+(I[IV]*)$") end
        if q and levels[v] then return self:add(q,v,n) end
        return self:add(arg)
    elseif cmd=="trudnosc" then
        local q,v=arg:match("^(.-)%s+(%S+)$")
        if q and levels[v] then local k=self:resolve(q); if k then return self:difficulty(k,v) end end
        return self:help()
    elseif cmd=="notatka" then
        local q,n=arg:match("^(.-)%s*|%s*(.*)$")
        if q then local k=self:resolve(q); if k then return self:change(k,"note",n) end end
        return self:help()
    end
    local methods={idz="travel",mapa="show_map",lokacja="relocate",usun="confirm_remove",odmiany="inflections"}
    if methods[cmd] then local k=self:resolve(arg); if k then return self[methods[cmd]](self,k) end; return end
    local k=self:resolve(s); if k then self:card(k) end
end
B:rebuild()
B.trigger_ids={tempRegexTrigger("^.*$",function() local t=line or matches[1] or ""; B:highlight(t); B:parse(t) end)}
B.alias_ids={
    tempAlias("^/boss(?:\\s+(.*))?\\s*$",function() B:command(matches[2]) end),
    tempAlias("^/bosskolor(?:\\s+(.*))?\\s*$",function()
        local a=trim(matches[2])
        if a=="on" or a=="off" then if B.data.enabled~=(a=="on") then B:toggle() end; return end
        local l,h=a:match("^(%S+)%s+(#%x%x%x%x%x%x)$")
        if l then B:set_color(l,h) else B:colors(a) end
    end)
}
U.replace_handler(B,"disconnect","sysDisconnectionEvent",function() B:cancel() end)
U.replace_handler(B,"room","gmcp.Room.Info",function()
    if B.pending then
        local r=gmcp and gmcp.Room and gmcp.Room.Info
        local l=B.pending.location
        if r and (r.id~=l.hash or instance(r)~=l.instance) then B:cancel(); note("Zmiana lokacji; przerwano dodawanie.") end
    end
end)
U.replace_handler(B,"uninstall","sysUninstallPackage",function(_,name)
    if tostring(name):lower()=="chimeravip" then B:cleanup() end
end)
return B
