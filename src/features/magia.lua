-- ChimeraVIP 0.194 / Magia: czasy rozpadu z komendy "efekty".
-- Brak gagowania, brak wnioskowania o zniszczeniu na podstawie zegara.
chimera_vip=chimera_vip or {}
local C,U=chimera_vip,chimera_vip.util
C.magia=C.magia or {}
chimera_overlay=chimera_overlay or C
chimera_overlay.magia=C.magia
local M=C.magia
M.trigger_ids=M.trigger_ids or {}
M.alias_ids=M.alias_ids or {}
M.handlers=M.handlers or {}
M.data=M.data or {owners={},mode="compact",alarms=true}
M.path=(C.root_dir or getMudletHomeDir().."/ChimeraVIP").."/user/magia.lua"

local function now() return os.time() end
local function p() return U.palette() end
local function note(message,color)
    hecho("\n"..(color or p().lavender).."[Magia] "..p().text..tostring(message).."\n")
end

function M.parse_duration(text)
    local seconds,found=0,false
    for number,unit in U.normalize(text):gmatch("(%d+)%s+(%a+)") do
        local multiplier
        if unit:find("^godzin") then multiplier=3600
        elseif unit=="dzien" or unit=="dni" then multiplier=86400
        elseif unit:find("^minut") then multiplier=60
        elseif unit:find("^sekund") then multiplier=1 end
        if multiplier then seconds=seconds+tonumber(number)*multiplier;found=true end
    end
    return found and seconds or nil
end
function M.format(seconds)
    if not seconds then return "?" end
    if seconds<=0 then return "czas uplynal?" end
    local minutes=math.ceil(seconds/60)
    if minutes>=4320 then return "~"..math.floor(minutes/1440).."d "..math.floor(minutes%1440/60).."h" end
    if minutes>=60 then
        local hrs=math.floor(minutes/60)
        return "~"..hrs.."h"..(minutes%60>0 and " "..(minutes%60).."m" or "")
    end
    return "~"..minutes.."m"
end
-- "Lada chwila" nie jest terminem liczbowym. Wyroznijmy go osobno:
-- bez wymyslania godziny rozpadu i bez liczenia wstecz od zera.
function M:remaining(item)
    if item.imminent then return 0 end
    return (tonumber(item.expiry) or 0)-now()
end
function M:format_item(item)
    if item.imminent then return "lada chwila" end
    return self.format(self:remaining(item))
end
function M:color(seconds)
    if seconds<=3600 then return p().rose end
    if seconds<=10800 then return p().peach end
    if seconds<=43200 then return p().yellow end
    return p().mint
end
function M:self_name()
    local value=gmcp and gmcp.Char and gmcp.Char.Name
    return U.trim(type(value)=="table" and (value.name or value.fullname) or "JA")
end
function M:retainers()
    local xp=C.xp_tracker
    if not xp or type(xp.get_present_retainers)~="function" then return {} end
    local ok,list=pcall(xp.get_present_retainers,xp)
    return ok and type(list)=="table" and list or {}
end
function M:present()
    local found={["@"]=true}
    for _,r in ipairs(self:retainers()) do found[tostring(r.id)]=true end
    return found
end
function M:load_data()
    local result={}
    if U.file_exists(self.path) and type(table.load)=="function" then
        local ok=pcall(table.load,self.path,result)
        if ok and type(result.owners)=="table" then self.data=result end
    end
    self.data.owners=type(self.data.owners)=="table" and self.data.owners or {}
    self.data.mode=self.data.mode=="full" and "full" or "compact"
    if self.data.alarms==nil then self.data.alarms=true end
end
function M:save()
    if type(table.save)~="function" then return end
    local folder=self.path:match("^(.*)/[^/]+$")
    if folder and U.ensure_dir(folder) then pcall(table.save,self.path,self.data) end
end
-- Kopie jednakowo nazwanych rzeczy dopasowujemy ostroznie do poprzedniego
-- odczytu; nie zakladamy, ze indeks na liscie to stabilny ID przedmiotu.
function M:commit(owner,items)
    local id=tostring(owner.id)
    local old=self.data.owners[id]
    local used={}
    for _,entry in ipairs(items) do
        local best,diff
        for i,prev in ipairs(old and old.items or {}) do
            local delta=math.abs((entry.expiry or 0)-(prev.expiry or 0))
            if not used[i] and U.normalize(prev.name)==U.normalize(entry.name)
                and (prev.imminent==true)==(entry.imminent==true)
                and (not diff or delta<diff) then best,diff=i,delta end
        end
        entry.warned={}
        if best and diff<=7200 then
            entry.warned=(old.items[best].warned or {})
            used[best]=true
        end
    end
    self.data.owners[id]={name=owner.name,items=items,last_scan=now()}
    self:save()
    self:render()
end
function M:clear_timeout()
    if self.response_timer then pcall(killTimer,self.response_timer) end
    self.response_timer=nil
end
function M:timeout(seconds)
    self:clear_timeout()
    self.response_timer=tempTimer(seconds,function()
        M.response_timer=nil
        if M.capture then M:finish_capture()
        elseif M.current then
            note("Brak sekcji magii: "..M.current.name..". Zachowuje poprzednie dane.",p().yellow)
            M.current=nil
            M:next_task()
        end
    end)
end
function M:finish_capture()
    local c=self.capture
    if not c then return end
    self.capture=nil
    self:clear_timeout()
    local valid=c.names==#c.items
    if valid then
        self:commit(c.owner,c.items)
    else
        note("Niepelna odpowiedz "..c.owner.name.." — nie zmieniam zapisanych przedmiotow.",p().yellow)
    end
    if self.current and c.queued then
        self.current=nil
        self:next_task()
    elseif self.current then
        -- Niezalezna odpowiedz 'efekty' gracza nie moze anulowac
        -- oczekujacego rozkazu skierowanego do pacholka.
        self:timeout(8)
    end
end
function M:next_task()
    if self.capture or self.current then return end
    local task=self.queue and table.remove(self.queue,1)
    if not task then
        self.queue=nil
        if self.scan_active then
            self.scan_active=false
            local report={}
            for _,id in ipairs(self.scanned_ids or {}) do
                local row=self.data.owners[id]
                local label=id=="@" and "JA" or (row and row.name or id)
                if not row or (row.last_scan or 0)<(self.scan_started or 0) then
                    report[#report+1]=label..": brak nowego odczytu"
                else
                    report[#report+1]=label..": "..#(row.items or {}).." szt."
                end
            end
            note("Skan zakonczony | "..table.concat(report," | "))
        end
        self:render()
        return
    end
    self.current=task
    send(task.id=="@" and "efekty" or ("parozkaz "..task.id.." efekty"),false)
    self:timeout(12)
end
function M:scan()
    if self.current or self.capture or self.queue then
        note("Skan juz trwa.",p().yellow);return false
    end
    local retainers=self:retainers()
    self.scan_started=now()
    self.scan_active=true
    self.scanned_ids={"@"}
    self.queue={{id="@",name=self:self_name(),self=true}}
    for _,r in ipairs(retainers) do
        self.queue[#self.queue+1]={id=tostring(r.id),name=r.name,self=false}
        self.scanned_ids[#self.scanned_ids+1]=tostring(r.id)
    end
    self:show_window()
    note("Skanuje "..(#retainers+1).." postaci.")
    self:next_task()
    return true
end
function M:on_line(raw)
    local s=tostring(raw or ""):gsub("\r$","")
    -- Wlasne efekty moga przyjsc rowniez bez /magia sprawdz.
    -- Rozpoznawaj naglowek niezaleznie od poprzedzajacych bialych znakow.
    local possessive=s:match("^%s*Magiczne przedmioty, ktore (%a+) na sobie:%s*$")
    if possessive=="masz" or possessive=="ma" then
        if self.capture then self:finish_capture() end
        local owner,queued
        if possessive=="masz" then
            owner={id="@",name=self:self_name(),self=true}
            queued=self.current and self.current.self or false
        elseif self.current and not self.current.self then
            owner=self.current
            queued=true
        end
        if not owner then return end
        self.capture={owner=owner,items={},names=0,queued=queued}
        self:timeout(5)
        return
    end
    local capture=self.capture
    if not capture then return end
    local duration=s:match("^%s*Rozsypie sie w pyl za okolo (.+)%.%s*$")
    local imminent=s:match("^%s*Rozsypie sie w pyl lada chwila%.%s*$")~=nil
    if duration or imminent then
        local seconds=duration and self.parse_duration(duration) or nil
        if capture.pending and (seconds or imminent) then
            capture.pending.imminent=imminent
            capture.pending.seconds=seconds
            capture.pending.expiry=seconds and (now()+seconds) or nil
            capture.pending.observed=now()
            capture.items[#capture.items+1]=capture.pending
            capture.pending=nil
        end
        self:timeout(5)
        return
    end
    -- Na roznych profilach efekt moze miec 1-3 wciecia (takze tab).
    -- Klucze opisu nie sa przedmiotami, a kazdy przedmiot wymaga czasu.
    local indent,name=s:match("^(%s+)(%S.-)%s*$")
    if name and #indent<=3 and not name:match("^Dzialanie:")
        and not name:match("^Rozsypie sie") then
        capture.names=capture.names+1
        capture.pending={name=U.trim(name)}
        self:timeout(5)
        return
    end
    if s:match("^%S") then self:finish_capture() end
end
function M:rows()
    local rows,seen={},self:present()
    for id,owner in pairs(self.data.owners or {}) do
        if seen[id] then
            for _,item in ipairs(owner.items or {}) do
                rows[#rows+1]={id=id,owner=owner.name,item=item,seconds=self:remaining(item)}
            end
        end
    end
    table.sort(rows,function(a,b)
        if a.seconds==b.seconds then
            if a.owner==b.owner then return a.item.name<b.item.name end
            return a.owner<b.owner
        end
        return a.seconds<b.seconds
    end)
    return rows
end
function M:shortest(id)
    local owner=self.data.owners[tostring(id or "@")]
    if not owner or not owner.items or #owner.items==0 then return nil end
    local shortest
    for _,item in ipairs(owner.items) do
        if not shortest or self:remaining(item)<self:remaining(shortest) then
            shortest=item
        end
    end
    return shortest and self:format_item(shortest) or nil
end
function M:alarms_tick()
    if self.data.alarms==false then return end
    local present=self:present()
    local modified=false
    for id,owner in pairs(self.data.owners) do
        if present[id] and now()-(owner.last_scan or 0)<12*3600 then
            for _,item in ipairs(owner.items or {}) do
                local sec=self:remaining(item)
                -- 0 = osobny alarm dla "lada chwila"; nie tworzymy
                -- fikcyjnego licznika do rozpadu.
                local threshold=item.imminent and 0 or
                    (sec>0 and (sec<=1800 and 30 or sec<=3600 and 60
                    or sec<=10800 and 180) or nil)
                if threshold~=nil then
                    item.warned=item.warned or {}
                    if not item.warned[threshold] then
                        item.warned[threshold]=true
                        modified=true
                        note(owner.name..": "..item.name.." — "..self:format_item(item)..
                            " (szacunek).",self:color(sec))
                    end
                end
            end
        end
    end
    if modified then self:save() end
end
function M:report()
    local rows=self:rows()
    hecho("\n"..p().lavender.."MAGIA — WYPOSAZENIE ("..#rows..")")
    if #rows==0 then hecho("\n  "..p().text_muted.."Brak danych. /magia sprawdz\n");return end
    for _,r in ipairs(rows) do
        hecho("\n  "..self:color(r.seconds)..self:format_item(r.item).."  "
            ..p().text_muted..r.owner.."  "..p().text..r.item.name)
    end
    hecho("\n"..p().text_muted.."Czasy przyblizone. /magia sprawdz | /magia okno\n")
end
function M:cleanup()
    U.clear_triggers(self);U.clear_aliases(self)
    for _,id in pairs(self.handlers or {}) do pcall(killAnonymousEventHandler,id) end
    self.handlers={}
    if self.tick then pcall(killTimer,self.tick) end;self.tick=nil
    self:clear_timeout()
    self.capture=nil;self.current=nil;self.queue=nil
    self.scan_active=false
end
M:cleanup()
if not M.loaded then M:load_data();M.loaded=true end
M.trigger_ids[1]=tempRegexTrigger("^.*$",function() M:on_line(line or matches[1] or "") end)
M.alias_ids[1]=tempAlias("^/magia(?:\\s+(.*))?\\s*$",function()
    local arg=U.normalize(matches[2] or "")
    if arg=="sprawdz" then M:scan()
    elseif arg=="okno" then M:show_window()
    elseif arg=="pelny" or arg=="full" then M:set_mode("full")
    elseif arg=="kompakt" then M:set_mode("compact")
    elseif arg=="ukryj" then M:hide_window()
    elseif arg=="alarmy" then
        M.data.alarms=not M.data.alarms
        M:save();note("Alarmy "..(M.data.alarms and "wlaczone" or "wylaczone"))
    else M:report() end
end)
U.replace_handler(M,"disconnect","sysDisconnectionEvent",function()
    M:clear_timeout();M.capture=nil;M.current=nil;M.queue=nil
    M.scan_active=false
end)
U.replace_handler(M,"exit","sysExitEvent",function()
    M:save()
    if M.win and type(saveWindowLayout)=="function" then pcall(saveWindowLayout) end
end)
M.tick=tempTimer(30,function() M:alarms_tick();M:render() end,true)
if C.help and type(C.help.register)=="function" then
    C.help:register("magia",{
        title="MAGIA — WYPOSAZENIE",
        description={"Monitoring przyblizonego czasu magicznych przedmiotow.",
            "Skan kolejno sprawdza efekty postaci i obecnych pacholkow po ID.",
            "Licznik uzywa czasu zegarowego; zachowanie offline nie jest potwierdzone."},
        commands={{"/magia","raport"},{" /magia sprawdz","skan druzyny"},
            {"/magia okno","pokaz okno"},{" /magia pelny","pelne okno"},
            {"/magia kompakt","widok skrocony"},{" /magia alarmy","przelacz alarmy"}},
    })
end
return M
