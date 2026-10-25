-- ChimeraVIP 0.177: independent situational (\) and room (Alt+\) bind engines.
-- The original user-trigger API is intentionally preserved.
chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local A = C.context_action or {}
C.context_action = A
local M = C.map_action or {}
C.map_action = M

A.current = A.current or nil
A.timer_id = A.timer_id or nil
A.generation = A.generation or 0
A.default_ttl = A.default_ttl or 30

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function output(kind, message, warning)
    if type(cecho)~="function" then return end
    -- Quiet HUD palette: warm peach for an ephemeral reaction,
    -- soft lavender for the permanent room binding.
    local heading=kind=="map" and "<199,185,232>[⌖ Mapa]" or
        "<242,196,160>[⚡ Kontekst]"
    local text=warning and "<240,168,184>" or "<216,220,230>"
    cecho("\n"..heading.."<reset> "..text..tostring(message).."<reset>\n")
end

local function room_id()
    local raw=rawget(_G,"gmcp")
    local info=type(raw)=="table" and raw.Room and raw.Room.Info
    local id=type(info)=="table" and info.id or nil
    if not id and C.runtime and type(C.runtime.room_info)=="function" then
        local ok,room=pcall(C.runtime.room_info,C.runtime)
        if ok and type(room)=="table" then id=room.id end
    end
    return type(id)=="string" and id~="" and id or nil
end

function A:clear(silent)
    self.generation=(self.generation or 0)+1
    if self.timer_id then
        if type(killTimer)=="function" then pcall(killTimer,self.timer_id) end
        self.timer_id=nil
    end
    local had=self.current~=nil
    self.current=nil
    if had and not silent then output("context","Wyczyszczona.") end
    return had
end

function A:set(callback,label,ttl)
    if type(callback)~="function" then
        output("context","Oczekiwano funkcji do wykonania.",true)
        return false
    end
    if ttl==nil then ttl=self.default_ttl else ttl=tonumber(ttl) end
    if not ttl or ttl<0 then
        output("context","Czas akcji musi byc liczba >= 0.",true)
        return false
    end
    self:clear(true)
    local generation=self.generation
    local name=trim(label)
    if name=="" then name="akcja kontekstowa" end
    self.current={
        callback=callback,
        label=name,
        room_id=room_id(),  -- contextual trigger must not leak into the next room
        created_at=type(getEpoch)=="function" and getEpoch() or os.time(),
    }
    if ttl>0 then
        if type(tempTimer)=="function" then
            self.timer_id=tempTimer(ttl,function()
                if A.generation~=generation then return end
                A.timer_id=nil
                A.current=nil
                A.generation=A.generation+1
            end)
        end
    end
    output("context","Podpieto: "..name..
        (ttl>0 and (" (na "..tostring(ttl).." s).") or " (bez limitu czasu)."))
    return true
end

function A:set_send(command,show,ttl)
    command=trim(command)
    if command=="" then
        output("context","Komenda nie moze byc pusta.",true)
        return false
    end
    return self:set(function()
        send(command,show==true)
    end,command,ttl)
end

function A:set_alias(command,show,ttl)
    command=trim(command)
    if command=="" then
        output("context","Alias nie moze byc pusty.",true)
        return false
    end
    return self:set(function()
        expandAlias(command,show==true)
    end,command,ttl)
end

function A:run()
    local entry=self.current
    if not entry then
        output("context","Brak aktywnej akcji.",true)
        return false
    end
    local now=room_id()
    if entry.room_id and now and entry.room_id~=now then
        self:clear(true)
        output("context","Akcja wygasla po zmianie lokacji.",true)
        return false
    end
    local ok,err=pcall(entry.callback)
    if not ok then
        output("context","Blad wykonania '"..entry.label.."': "..tostring(err),true)
        return false
    end
    return true
end

function A:status()
    if not self.current then
        output("context","Brak aktywnej akcji.",true)
        return nil
    end
    output("context","Aktywna: "..self.current.label..".")
    return self.current
end

function M:run()
    local runner=self._runner
    if type(runner)~="function" then
        output("map","Akcje mapowe sa niedostepne. Sprawdz /cvip v5.",true)
        return false
    end
    local ok,result=pcall(runner)
    if not ok then
        output("map","Blad wykonania akcji: "..tostring(result),true)
        return false
    end
    if result~=true then
        output("map","Brak domyslnej akcji w tym pokoju.",true)
        return false
    end
    return true
end

function M:status()
    if type(self._status)~="function" then
        output("map","Brak dostepnych akcji mapowych.",true)
        return nil
    end
    local ok,value=pcall(self._status)
    if not ok or type(value)~="string" then
        output("map","Brak domyslnej akcji w tym pokoju.",true)
        return nil
    end
    output("map","Domyslna: "..value..".")
    return value
end

-- Register once per reload via the project's supported handler replacement.
-- Room events may arrive before/after GMCP, so run() independently checks.
if C.util and type(C.util.replace_handler)=="function" then
    C.util.replace_handler(A,"room_change","gmcp.Room.Info",function()
        local entry=A.current
        local now=room_id()
        if entry and entry.room_id and now and entry.room_id~=now then
            A:clear(true)
        end
    end)
end
return {context=A,map=M}
