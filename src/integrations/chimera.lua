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

local function exists_script(name)
    if type(getScript) ~= "function" then return nil end
    local ok, result = pcall(getScript, name)
    if not ok then return nil end
    return result ~= -1
end

function I:disable_official_gags()
    if type(disableScript) ~= "function" then return false end

    -- Mudlet's public script API works on element names rather than a tree path.
    -- We first try the path supplied by the official package layout, then the
    -- actual folder name used in the script tree.
    local candidates = {
        "chimera/skrypty/ui/gags",
        "gags",
    }

    local found = false
    for _, name in ipairs(candidates) do
        local exists = exists_script(name)
        if exists == true then
            local ok = pcall(disableScript, name)
            if ok then found = true end
        end
    end

    -- Some Mudlet versions do not resolve grouped paths through getScript().
    -- Calling disableScript("gags") is harmless if no such element exists.
    if not found then
        local ok, result = pcall(disableScript, "gags")
        if ok and result ~= false then found = true end
    end

    self.gags_disabled = found

    if not found and not self.gags_warning_shown then
        self.gags_warning_shown = true
        cecho("\n<yellow>[ChimeraVIP]<reset> Nie udalo sie potwierdzic wylaczenia oficjalnego folderu gags.\n")
    end

    return found
end

local function schedule_disable(delay)
    tempTimer(delay or 0, function()
        I:disable_official_gags()
    end)
end

if U and U.replace_handler then
    U.replace_handler(I, "vip_ready", "chimeraVipReady", function() schedule_disable(0) end)
    U.replace_handler(I, "scripts_loaded", "scriptsLoaded", function() schedule_disable(0.05) end)
    U.replace_handler(I, "sys_load", "sysLoadEvent", function() schedule_disable(0.15) end)
end

if scripts_loaded == true or C.ready then schedule_disable(0) end

return I
