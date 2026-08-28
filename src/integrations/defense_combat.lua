-- ChimeraVIP / Defense Tracker <-> Combat Colors
-- Rozdziela telemetrie trafien od wizualnego warunku wyswietlania prefiksu.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local I = C.defense_combat_integration or {}
C.defense_combat_integration = I
chimera_overlay.defense_combat_integration = I

function I:install()
    local D = C.combat_colors
    if not D then return false end

    -- Callback triggerow ANSI wywoluje chimera_damage:show_prefix(key).
    -- Event dla Defense Trackera musi poleciec ZANIM sprawdzimy, czy linia
    -- spelnia kosmetyczne wymagania prefiksu (np. minimum 50 znakow).
    function D:show_prefix(key)
        local definition = self.definitions and self.definitions[key]
        if not definition then return end

        local raw_line = tostring(line or "")
        if tostring(key):match("^otrzymane_") then
            raiseEvent("chimeraVipIncomingHit", key, raw_line)
        end

        -- Od tego miejsca logika dotyczy juz tylko prezentacji [0/3]-[3/3].
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

    D.showPrefix = D.show_prefix
    return true
end

I:install()

return I
