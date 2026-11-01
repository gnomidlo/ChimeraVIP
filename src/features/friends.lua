-- Profile-local friends; one line trigger, no upstream character database.
local C=chimera_vip
local U=C.util
C.friends=C.friends or {}
local F=C.friends
local cases={"Mianownik","Dopelniacz","Celownik","Biernik","Narzednik","Miejscownik"}
local function note(text) hecho("\n#C7B9E8[ZIOM] #D8DCE6"..text.."\n") end
local function name_ok(s)
    return type(s)=="string" and #s>0 and #s<=80
        and s:match("^[A-Za-z\128-\255][A-Za-z\128-\255'%-]*$")~=nil
end
local function color_ok(s) return type(s)=="string" and s:match("^#%x%x%x%x%x%x$")~=nil end
local function word(c) return c~="" and c:match("[%w_\128-\255'%-]")~=nil end

function F:cancel()
    self.pending=nil
    if self.timer then killTimer(self.timer); self.timer=nil end
end

function F:cleanup()
    self:cancel()
    U.clear_aliases(self)
    U.clear_triggers(self)
    for _,id in pairs(self.handlers or {}) do pcall(killAnonymousEventHandler,id) end
    self.handlers={}
end
F:cleanup()

-- Settings already provides profile-local storage and update backups.
local saved=C.settings.data.friends
F.data={color="#A8DCC2",entries={}}
if type(saved)=="table" then
    if color_ok(saved.color) then F.data.color=saved.color end
    for key,entry in pairs(type(saved.entries)=="table" and saved.entries or {}) do
        if name_ok(key) and type(entry)=="table" and type(entry.forms)=="table" then
            local valid=#entry.forms==6 and name_ok(entry.forms[1]) and entry.forms[1]:lower()==key
            for i=1,6 do valid=valid and name_ok(entry.forms[i]) end
            if valid then F.data.entries[key]={forms=U.deep_copy(entry.forms)} end
        end
    end
end

function F:rebuild()
    local owners={}
    for key,entry in pairs(self.data.entries) do
        for _,form in ipairs(entry.forms) do
            if owners[form]==nil then owners[form]=key
            elseif owners[form]~=key then owners[form]=false end
        end
    end
    self.forms={}
    for form,owner in pairs(owners) do
        -- Ambiguous shared inflections are not highlighted.
        if owner then self.forms[#self.forms+1]=form end
    end
    table.sort(self.forms)
end

function F:commit(data)
    local old=C.settings.data.friends
    C.settings.data.friends=data
    local ok,result=pcall(C.settings.save,C.settings)
    if not ok or result==false then
        C.settings.data.friends=old
        note("Nie udalo sie zapisac bazy. Zmiana nie zostala zastosowana.")
        return false
    end
    self.data=data
    self:rebuild()
    return true
end

function F:add(name)
    if not name_ok(name) then note("Uzycie: /ziom IMIE"); return false end
    if self.pending then note("Czekam na odmiane. Sprobuj ponownie za chwile."); return false end
    self.pending={name=name,forms={},started=false}
    self.timer=tempTimer(10,function()
        F.timer=nil; F.pending=nil
        note("Brak pelnej odmiany w ciagu 10 sekund; nic nie zapisano.")
    end)
    send("odmien "..name,false)
    return true
end

function F:parse(text)
    local p=self.pending
    if not p then return end
    local header=text:match("^%s*(.-) odmienia sie nastepujaco:%s*$")
    if header then
        if header:lower()~=p.name:lower() or p.started then self:cancel(); return end
        p.started=true
        return
    end
    if not p.started then return end
    local label,value,ending=text:match("^%s*([A-Za-z]+):%s*(.-)([,.])%s*$")
    local index=#p.forms+1
    if label~=cases[index] or not name_ok(value)
        or ending~=(index==6 and "." or ",")
        or (index==1 and value:lower()~=p.name:lower()) then
        self:cancel()
        return
    end
    p.forms[index]=value
    if index==6 then
        local data=U.deep_copy(self.data)
        data.entries[p.forms[1]:lower()]={forms=p.forms}
        self:cancel()
        if self:commit(data) then note("Zapisano przyjaciela: "..p.forms[1]..".") end
    end
end

function F:remove(name)
    if not name_ok(name) then return false end
    local key=name:lower()
    if self.pending and self.pending.name:lower()==key then self:cancel() end
    if not self.data.entries[key] then note("Brak przyjaciela o tym imieniu."); return false end
    local data=U.deep_copy(self.data)
    data.entries[key]=nil
    if self:commit(data) then note("Usunieto: "..name.."."); return true end
    return false
end

-- Exact, case-sensitive whole names. Count all substring occurrences so that
-- Mudlet's selectString ordinal remains correct even after a rejected prefix.
function F:spans(text)
    local result={}
    for _,form in ipairs(self.forms) do
        local offset,n=1,0
        while true do
            local first,last=text:find(form,offset,true)
            if not first then break end
            n=n+1
            if not word(text:sub(first-1,first-1)) and not word(text:sub(last+1,last+1)) then
                result[#result+1]={form=form,n=n}
            end
            offset=last+1
        end
    end
    return result
end

function F:highlight(text)
    local spans=self:spans(text)
    if #spans==0 then return end
    local r,g,b=U.hex_to_rgb(self.data.color)
    for _,span in ipairs(spans) do
        if selectString(span.form,span.n)>-1 then setFgColor(r,g,b) end
    end
    deselect(); resetFormat()
end

function F:color(value)
    if value and value~="" then
        if not color_ok(value) then note("Kolor: #RRGGBB."); return false end
        local data=U.deep_copy(self.data); data.color=value:upper()
        return self:commit(data)
    end
    -- Same clickable swatch/hex interaction as official Chimera /kolory,
    -- with VIP pastels and no dependency on upstream's private picker module.
    note("Kolor przyjaciol (obecny "..self.data.color.."). Wlasny: /ziomkolor #RRGGBB")
    for _,hex in ipairs({"#A8DCC2","#C7B9E8","#AFCBF4","#F0A8B8","#EFD8A6","#F2C4A0"}) do
        hechoLink(hex.." ["..hex.."] ",string.format("chimera_vip.friends:color(%q)",hex),"Wybierz kolor",true)
    end
    hecho("\n")
end

function F:list()
    note("/ziom IMIE dodaje, /ziom- IMIE usuwa, /ziomkolor wybiera kolor.")
    local keys={}; for key in pairs(self.data.entries) do keys[#keys+1]=key end
    table.sort(keys)
    for _,key in ipairs(keys) do note(table.concat(self.data.entries[key].forms,", ")) end
end

F:rebuild()
F.trigger_ids={tempRegexTrigger("^.*$",function()
    local text=line or matches[1] or ""
    F:highlight(text)
    F:parse(text)
end)}
F.alias_ids={
    tempAlias("^/ziom(?:\\s+(\\S+))?\\s*$",function()
        local name=matches[2]; if not name or name=="" then F:list() else F:add(name) end
    end),
    tempAlias("^/ziom-\\s+(\\S+)\\s*$",function() F:remove(matches[2]) end),
    tempAlias("^/ziomkolor(?:\\s+(\\S+))?\\s*$",function() F:color(matches[2]) end),
}
U.replace_handler(F,"disconnect","sysDisconnectionEvent",function() F:cancel() end)
U.replace_handler(F,"uninstall","sysUninstallPackage",function(_,name)
    if tostring(name):lower()=="chimeravip" then F:cleanup() end
end)
return F
