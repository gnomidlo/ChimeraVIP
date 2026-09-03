-- ChimeraVIP / Ekwipunek
-- Lekko formatuje standardowe linie ekwipunku bez zmiany ich tresci.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
C.equipment_view = C.equipment_view or {}
chimera_overlay.equipment_view = C.equipment_view
local E = C.equipment_view

E.trigger_ids = E.trigger_ids or {}

for _, id in ipairs(E.trigger_ids) do
    pcall(killTrigger, id)
end
E.trigger_ids = {}

local BODY = "216,220,230"
local MUTED = "174,182,197"

local function replace_prefix(prefix, label, rgb)
    local found = selectString(prefix, 1)
    if found == nil or found < 0 then return end
    dreplace("<" .. rgb .. ">" .. label .. ":<" .. BODY .. "> ")
end

E.trigger_ids[#E.trigger_ids + 1] = tempRegexTrigger(
    [[^Trzymasz .+]],
    function()
        replace_prefix("Trzymasz ", "RECE", "199,185,232")
    end
)

E.trigger_ids[#E.trigger_ids + 1] = tempRegexTrigger(
    [[^Masz na sobie .+]],
    function()
        replace_prefix("Masz na sobie ", "EKWIPUNEK", "168,220,194")
    end
)

E.trigger_ids[#E.trigger_ids + 1] = tempRegexTrigger(
    [[^Masz przy sobie .+]],
    function()
        replace_prefix("Masz przy sobie ", "PRZY SOBIE", "175,203,244")
    end
)

E.trigger_ids[#E.trigger_ids + 1] = tempRegexTrigger(
    [[^Nie masz nic przy sobie\.$]],
    function()
        selectCurrentLine()
        dreplace("<175,203,244>PRZY SOBIE:<" .. MUTED .. "> brak")
    end
)

return E
