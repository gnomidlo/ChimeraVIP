-- ChimeraVIP / Report Actions
-- Drobne klikalne podkomendy dopinane do raportow przez eventy.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
C.report_actions = C.report_actions or {}
chimera_overlay.report_actions = C.report_actions
local R = C.report_actions

R.handlers = R.handlers or {}

U.replace_handler(R, "stats", "chimeraVipStatsUpdated", function()
    U.action_links({
        {"HISTORIA 10", "/cechy historia 10", "Ostatnie 10 zmian cech"},
    })
end)

return R
