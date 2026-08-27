chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util

C.integrations = C.integrations or {}
C.integrations.chimera = C.integrations.chimera or {}
local I = C.integrations.chimera

I.handlers = I.handlers or {}
I.gags_disabled = I.gags_disabled or false
I.gags_warning_shown = I.gags_warning_shown or false

I.gags_candidates = {
    "chimera/skrypty/ui/gags",
    "gags",
}

local function exists_script(name)
    if type(getScript) ~= "function" then return nil end
    local ok, result = pcall(getScript, name)
    if not ok then return nil end
    return result ~= -1
end

function I:set_official_gags_enabled(enabled)
    local fn = enabled and _G.enableScript or _G.disableScript
    if type(fn) ~= "function" then return false end

    local changed = false
    for _, name in ipairs(self.gags_candidates) do
        local exists = exists_script(name)
        if exists == true then
            local ok, result = pcall(fn, name)
            if ok and result ~= false then changed = true end
        end
    end

    -- Część wersji Mudleta nie rozwiązuje pełnej ścieżki grupy przez getScript().
    -- Fallback na nazwę folderu zachowuje zgodność z dotychczasową integracją.
    if not changed then
        local ok, result = pcall(fn, "gags")
        if ok and result ~= false then changed = true end
    end

    if changed then
        self.gags_disabled = not enabled
        self.gags_warning_shown = false
    elseif C.ready and not self.gags_warning_shown then
        self.gags_warning_shown = true
        cecho("\n<yellow>[ChimeraVIP]<reset> Nie udalo sie potwierdzic "
            .. (enabled and "wlaczenia" or "wylaczenia")
            .. " oficjalnego folderu gags.\n")
    end

    return changed
end

function I:disable_official_gags()
    return self:set_official_gags_enabled(false)
end

function I:enable_official_gags()
    return self:set_official_gags_enabled(true)
end

function I:combat_colors_enabled()
    if C.settings and type(C.settings.is_module_enabled) == "function" then
        return C.settings:is_module_enabled("combat_colors", true)
    end
    return true
end

function I:sync_gags()
    if self:combat_colors_enabled() then
        return self:disable_official_gags()
    end
    return self:enable_official_gags()
end

local function schedule_sync(delay)
    tempTimer(delay or 0, function() I:sync_gags() end)
end

if U and U.replace_handler then
    U.replace_handler(I, "vip_ready", "chimeraVipReady", function() schedule_sync(0) end)
    U.replace_handler(I, "scripts_loaded", "scriptsLoaded", function() schedule_sync(0.05) end)
    U.replace_handler(I, "sys_load", "sysLoadEvent", function() schedule_sync(0.15) end)
    U.replace_handler(I, "module_changed", "chimeraVipModuleChanged", function(_, id)
        if tostring(id) == "combat_colors" then schedule_sync(0) end
    end)
end

if scripts_loaded == true or C.ready then schedule_sync(0) end

return I
