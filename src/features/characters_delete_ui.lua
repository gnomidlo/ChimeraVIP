-- ChimeraVIP / Characters Delete UI
-- Dodaje przycisk [USUN] do linkow relacji oraz dwuetapowe potwierdzenie usuwania.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local R = C.characters

if not R then return false end

local current = R.print_group_links
if current ~= R._delete_ui_wrapper then
    R._delete_ui_base_print_group_links = current
end

function R:cancel_remove(name_or_form)
    local person = self:find_person(name_or_form)
    local name = person and person.name or tostring(name_or_form or "")
    local P = C.pastel_ui and C.pastel_ui.colors or { text_muted="#AEB6C5" }
    hecho("\n" .. P.text_muted .. "[Postacie] Anulowano usuwanie: " .. name .. ".\n")
end

function R:confirm_remove(name_or_form)
    local person = self:find_person(name_or_form)
    local P = C.pastel_ui and C.pastel_ui.colors or {
        text="#D8DCE6", text_muted="#AEB6C5", mint="#A8DCC2", rose="#F0A8B8", yellow="#EFD8A6"
    }

    if not person then
        hecho("\n" .. P.rose .. "[Postacie] Nie znam postaci: " .. tostring(name_or_form or "") .. ".\n")
        return
    end

    hecho("\n" .. P.yellow .. "[Postacie] Usunac " .. P.text .. person.name .. P.yellow .. "?  ")
    echoLink(
        "[TAK]",
        string.format("chimera_vip.characters:remove(%q)", person.name),
        "Usun postac i wszystkie zapisane odmiany",
        true
    )
    echo(" ")
    echoLink(
        "[NIE]",
        string.format("chimera_vip.characters:cancel_remove(%q)", person.name),
        "Anuluj usuwanie",
        true
    )
    echo("\n")
end

local function wrapped_print_group_links(self, name)
    if type(self._delete_ui_base_print_group_links) == "function" then
        self._delete_ui_base_print_group_links(self, name)
    end
    echo(" ")
    echoLink(
        "[USUN]",
        string.format("chimera_vip.characters:confirm_remove(%q)", name),
        "Usun postac z bazy",
        true
    )
end

R._delete_ui_wrapper = wrapped_print_group_links
R.print_group_links = wrapped_print_group_links

return R
