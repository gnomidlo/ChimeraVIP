chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util

C.settings_apply = C.settings_apply or {}
local A = C.settings_apply
A.handlers = A.handlers or {}

function A:get_sizes()
    local S = C.settings
    local main = S and tonumber(S:get("ui.condition_font_size", 10)) or 10
    main = math.max(8, math.min(14, math.floor(main + 0.5)))

    -- Mniejsze elementy footera rosną razem z głównym tekstem, ale wolniej,
    -- aby SYTOSC/WODA/OBC/UPI/EXP nadal mieściły się w kompaktowym panelu.
    local small = math.max(6, main - 4)
    local exp = small

    return main, small, exp
end

function A:sync_values()
    local HUD = C.quiet_footer
    if not HUD then return false end

    local main, small, exp = self:get_sizes()
    HUD.main_font = main
    HUD.small_font = small
    HUD.exp_font = exp

    return true, main, small, exp
end

function A:apply(rebuild)
    local HUD = C.quiet_footer
    if not HUD then return end

    local ok, main, small, exp = self:sync_values()
    if not ok then return end

    -- Geyser.Label dostaje fontSize w chwili tworzenia. Dlatego zmiana
    -- ustawienia musi przebudować Quiet Footer, a nie tylko dopisać CSS do
    -- już istniejących QLabeli.
    if rebuild and type(HUD.schedule_rebuild) == "function" then
        HUD:schedule_rebuild()
    end

    raiseEvent("chimeraVipConditionFontApplied", main, small, exp)
end

if U and U.replace_handler then
    U.replace_handler(A, "settings_changed", "chimeraVipSettingsChanged", function(_, key)
        if tostring(key or "") == "ui.condition_font_size" then
            A:apply(true)
        end
    end)
end

-- Przy starcie ustawiamy wartości PRZED najbliższą budową footera. Jeżeli
-- footer został już zbudowany podczas hot-reloadu, schedule_rebuild odtworzy
-- go raz z właściwymi fontSize.
tempTimer(0, function() A:apply(true) end)

return A
