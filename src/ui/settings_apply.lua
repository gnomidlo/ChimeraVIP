chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util

C.settings_apply = C.settings_apply or {}
local A = C.settings_apply
A.handlers = A.handlers or {}

function A:get_size()
    local S = C.settings
    local size = S and tonumber(S:get("ui.states_font_size", 10)) or 10
    return math.max(8, math.min(14, math.floor(size + 0.5)))
end

function A:apply()
    local size = self:get_size()

    if scripts and scripts.ui then
        scripts.ui.states_font_size = size
    end

    -- To są istniejące okna oficjalnej Chimery: stany drużyny/innych postaci
    -- oraz przeciwników. Footer ChimeraVIP nie jest tutaj dotykany.
    pcall(setFontSize, "states_window", size)
    pcall(setFontSize, "enemy_states_window", size)

    raiseEvent("chimeraVipStatesFontApplied", size)
end

if U and U.replace_handler then
    U.replace_handler(A, "settings_changed", "chimeraVipSettingsChanged", function(_, key)
        if tostring(key or "") == "ui.states_font_size" then tempTimer(0, function() A:apply() end) end
    end)
    U.replace_handler(A, "theme_ready", "chimeraThemeReady", function()
        tempTimer(0, function() A:apply() end)
    end)
    U.replace_handler(A, "ui_ready", "uiReady", function()
        tempTimer(0.05, function() A:apply() end)
    end)
end

tempTimer(0, function() A:apply() end)

return A
