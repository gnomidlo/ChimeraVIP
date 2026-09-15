-- Developer entry point. Invoke loadfile(...)(absolute_checkout_directory).
-- This is not the stable loader and intentionally loads no updater.
local root = ...
assert(type(root)=="string" and root~="", "Podaj katalog checkoutu ChimeraVIP")
if scripts_loaded==true or scripts~=nil or ateam~=nil or amap~=nil then
    error("Start 2.0 wymaga osobnego profilu bez uruchomionej Chimery")
end
if chimera_vip and chimera_vip.mode~="standalone" then
    error("W tym profilu uruchomiono juz inne ChimeraVIP; uzyj osobnego profilu")
end
chimera_vip = chimera_vip or {}
local C = chimera_vip
C.mode = "standalone"
C.version = "2.0.0-dev.2"
C.root_dir = root
C.ready = false
if C.features and C.features.active then C.features:flush() end
if C.sequences then C.sequences:stop("reload") end
if C.lifecycle then C.lifecycle:stop() end

local ok, err = pcall(function()
    dofile(root .. "/src/core/util.lua")
    dofile(root .. "/standalone/lifecycle.lua")
    dofile(root .. "/standalone/protocol.lua")
    dofile(root .. "/standalone/runtime.lua")
    dofile(root .. "/standalone/sequences.lua")
    dofile(root .. "/standalone/ui.lua")
    dofile(root .. "/standalone/mapper.lua")
    dofile(root .. "/standalone/features.lua")
    function C:stop()
        self.ready = false
        if self.features.active then self.features:flush() end
        self.protocol:reset()
        self.lifecycle:stop()
    end
    function C:status()
        cecho("\n<cyan>[ChimeraVIP " .. self.version .. "]<reset> Rdzen: "
            .. (self.ready and "ON" or "OFF")
            .. " | GMCP: " .. (self.protocol.subscribed and "subskrypcje wyslane" or "oczekiwanie")
            .. " | lokacja: " .. tostring(self.runtime:room_key() or "brak danych")
            .. " | bledy: " .. tostring(#self.lifecycle.errors)
            .. " | stopka: " .. (self.ui.active and "ON" or "brak API: "..tostring(self.ui.unavailable))
            .. " | mapa: " .. tostring(self.mapper.current or self.mapper.reason or "brak lokalizacji")
            .. " | moduly: " .. tostring(#self.features.loaded)
            .. (self.features.unavailable and (" (brak API: "..self.features.unavailable..")") or "")
            .. "\nWersja deweloperska: bez pelnego UI i aktualizatora.\n")
    end
    C.protocol:start()
    C.sequences:setup()
    C.ui:start()
    C.mapper:start()
    C.features:start()
    local scope = C.lifecycle:open("commands")
    scope:alias([[^/cvip2(?:\s+(status|reload|stop))?$]], function()
        local command = matches[2]
        if command=="stop" then C:stop(); C:status()
        elseif command=="reload" then assert(loadfile(root .. "/standalone/init.lua"))(root)
        else C:status() end
    end)
    C.ready = true
end)
if not ok then
    if C.protocol then C.protocol:reset() end
    if C.lifecycle then C.lifecycle:stop() end
    error(err)
end
C:status()
return C
