-- ChimeraVIP / Ekwipunek
-- Lekko formatuje standardowe linie ekwipunku bez zmiany ich tresci.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
C.equipment_view = C.equipment_view or {}
chimera_overlay.equipment_view = C.equipment_view
local E = C.equipment_view

E.trigger_ids = E.trigger_ids or {}
if U and U.clear_triggers then U.clear_triggers(E) else
    for _, id in ipairs(E.trigger_ids) do pcall(killTrigger, id) end
    E.trigger_ids = {}
end

local function replace_prefix(prefix, label, color_key)
    local found = selectString(prefix, 1)
    if found == nil or found < 0 then return end
    local P = U and U.palette and U.palette() or {}
    local label_tag = U and U.decho_tag and U.decho_tag(P[color_key]) or ""
    local body_tag = U and U.decho_tag and U.decho_tag(P.text) or ""
    dreplace(label_tag .. label .. ":" .. body_tag .. " ")
end

E.trigger_ids[#E.trigger_ids + 1] = tempRegexTrigger(
    [[^Trzymasz .+]],
    function() replace_prefix("Trzymasz ", "RECE", "lavender") end
)

E.trigger_ids[#E.trigger_ids + 1] = tempRegexTrigger(
    [[^Masz na sobie .+]],
    function() replace_prefix("Masz na sobie ", "EKWIPUNEK", "mint") end
)

E.trigger_ids[#E.trigger_ids + 1] = tempRegexTrigger(
    [[^Masz przy sobie .+]],
    function() replace_prefix("Masz przy sobie ", "PRZY SOBIE", "blue") end
)

E.trigger_ids[#E.trigger_ids + 1] = tempRegexTrigger(
    [[^Nie masz nic przy sobie\.$]],
    function()
        local P = U and U.palette and U.palette() or {}
        selectCurrentLine()
        dreplace((U.decho_tag(P.blue) or "") .. "PRZY SOBIE:" .. (U.decho_tag(P.text_muted) or "") .. " brak")
    end
)

return E
