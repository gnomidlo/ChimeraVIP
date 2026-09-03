chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
C.name = "ChimeraVIP"
C.version = C.version or "0.95"
C.tested_upstream = "2.6"
C.handlers = C.handlers or {}
C.ready = false
C.theme_ready = C.theme_ready or false

local U = C.util

function C:get_upstream_version()
    if scripts and scripts.version and type(scripts.version.installed) == "function" then
        local ok, value = pcall(scripts.version.installed)
        if ok and value and value ~= "" then return tostring(value) end
    end
    if scripts and scripts.ver then return tostring(scripts.ver) end
    if chimera_pkg and chimera_pkg.version then return tostring(chimera_pkg.version) end
    return "?"
end

function C:is_ready()
    return type(scripts) == "table"
        and type(scripts.ui) == "table"
        and type(scripts.ui.themes) == "table"
end

function C:signal_ready(reason)
    if not self:is_ready() then return false end
    self.ready = true
    raiseEvent("chimeraVipReady", self.version, self:get_upstream_version(), reason or "unknown")
    return true
end

U.replace_handler(C, "scripts_loaded", "scriptsLoaded", function()
    tempTimer(0, function() C:signal_ready("scriptsLoaded") end)
end)

U.replace_handler(C, "sys_load", "sysLoadEvent", function()
    tempTimer(0.05, function() C:signal_ready("sysLoadEvent") end)
end)

if scripts_loaded == true then
    tempTimer(0, function() C:signal_ready("hotReload") end)
end

return C
