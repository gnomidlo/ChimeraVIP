-- ChimeraVIP / Defense Tracker <-> Combat Colors
-- Combat Colors zgłasza kandydat na trafienie, a Defense Tracker rozstrzyga
-- je chwilę później po pełnym przetworzeniu tekstowej linii obrony.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local I = C.defense_combat_integration or {}
C.defense_combat_integration = I
chimera_overlay.defense_combat_integration = I

function I:install()
    local CC = C.combat_colors
    if not CC then return false end

    function CC:show_prefix(key)
        local definition = self.definitions and self.definitions[key]
        if not definition then return end

        local raw_line = tostring(line or "")

        -- Callback ANSI może odpalić zanim globalne `line` zawiera pełny tekst.
        -- Nie próbujemy tu rozpoznawać parowania/zasłony. Zgłaszamy kandydat
        -- na trafienie; Defense Tracker zapisuje go z krótkim opóźnieniem i
        -- anuluje, jeśli pełnoliniowy regex rozpozna obronę.
        if tostring(key):match("^otrzymane_") then
            raiseEvent("chimeraVipIncomingHit", key, raw_line)
        end

        if not self:is_eligible_line() then return end

        local prefix_color = self.prefix_colors and self.prefix_colors[definition.color]
        if not prefix_color then return end

        prefix(
            "<" .. self.prefix_colors.muted .. ">["
            .. "<" .. prefix_color .. ">" .. definition.level
            .. "<" .. self.prefix_colors.muted .. ">]"
            .. "<r> ",
            decho
        )
    end

    CC.showPrefix = CC.show_prefix
    return true
end

I:install()

return I
