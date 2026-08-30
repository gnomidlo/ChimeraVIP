-- ChimeraVIP / Weapon Info
-- Skraca opis parametrow broni do jednej linii z wartosciami liczbowymi.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util

C.weapon_info = C.weapon_info or {}
chimera_overlay.weapon_info = C.weapon_info
local W = C.weapon_info

W.trigger_ids = W.trigger_ids or {}
W.alias_ids = W.alias_ids or {}
W.capture = nil

local BALANCE_LEVELS = {
    "wyjatkowo zle",
    "bardzo zle",
    "zle",
    "bardzo kiepsko",
    "kiepsko",
    "przyzwoicie",
    "srednio",
    "niezle",
    "dosc dobrze",
    "dobrze",
    "bardzo dobrze",
    "doskonale",
    "perfekcyjnie",
    "genialnie",
}

local EFFECTIVENESS_LEVELS = {
    "kompletnie nieskuteczne",
    "strasznie nieskuteczne",
    "bardzo nieskuteczne",
    "raczej nieskuteczne",
    "malo skuteczne",
    "niezbyt skuteczne",
    "raczej skuteczne",
    "dosyc skuteczne",
    "calkiem skuteczne",
    "bardzo skuteczne",
    "niezwykle skuteczne",
    "wyjatkowo skuteczne",
    "zabojczo skuteczne",
    "fantastycznie skuteczne",
}

local function normalize(value)
    return tostring(value or ""):lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
end

local function make_index(levels)
    local out = {}
    for i, value in ipairs(levels) do out[normalize(value)] = i end
    return out
end

W.balance_index = make_index(BALANCE_LEVELS)
W.effectiveness_index = make_index(EFFECTIVENESS_LEVELS)

local function colors()
    if C.pastel_ui and C.pastel_ui.colors then return C.pastel_ui.colors end
    return {
        text="#D8DCE6", text_muted="#AEB6C5", mint="#A8DCC2", blue="#AFCBF4",
        lavender="#C7B9E8", peach="#F2C4A0", yellow="#EFD8A6", rose="#F0A8B8",
    }
end

local function gag_current_line()
    if type(deleteLine) == "function" then
        local ok = pcall(deleteLine)
        if ok then return end
    end
    pcall(function()
        selectCurrentLine()
        replace("")
    end)
end

local function grip_short(value)
    local key = normalize(value)
    if key == "jednoreczna" then return "1H" end
    if key == "dwureczna" then return "2H" end
    return tostring(value or ""):upper()
end

function W:reset_capture()
    self.capture = nil
end

function W:on_header(weapon_type, grip)
    self.capture = {
        weapon_type = normalize(weapon_type),
        grip = normalize(grip),
    }
    gag_current_line()
end

function W:on_damage(damage)
    if not self.capture then return end
    self.capture.damage = normalize(damage)
    gag_current_line()
end

function W:on_scores(balance_text, effectiveness_text)
    if not self.capture or not self.capture.damage then return end

    local balance = self.balance_index[normalize(balance_text)]
    local effectiveness = self.effectiveness_index[normalize(effectiveness_text)]
    if not balance or not effectiveness then
        self:reset_capture()
        return
    end

    gag_current_line()

    local P = colors()
    local total = balance + effectiveness
    local weapon = tostring(self.capture.weapon_type or "bron"):upper()
    local grip = grip_short(self.capture.grip)
    local damage = tostring(self.capture.damage or "-")

    hecho("\n" .. P.lavender .. weapon .. " " .. P.text .. grip
        .. P.text_muted .. " | " .. P.text .. damage
        .. P.text_muted .. " | " .. P.blue .. "WYW " .. tostring(balance) .. "/14"
        .. P.text_muted .. " | " .. P.mint .. "SKUT " .. tostring(effectiveness) .. "/14"
        .. P.text_muted .. " | " .. P.peach .. "OCENA " .. tostring(total) .. "/28\n")

    self:reset_capture()
end

function W:show_help()
    local P = colors()
    local rows = {
        {"/bron pomoc", "ta pomoc"},
    }
    local command_width = 0
    for _, row in ipairs(rows) do
        local n = U and U.text_width and U.text_width(row[1]) or #row[1]
        command_width = math.max(command_width, n)
    end
    command_width = command_width + 2

    hecho("\n\n" .. P.lavender .. "BRON — POMOC"
        .. "\n" .. P.text_muted .. "Skraca opis parametrow broni do jednej linii:"
        .. "\n" .. P.text .. "TOPOR 1H | ciete | WYW 4/14 | SKUT 8/14 | OCENA 12/28"
        .. "\n\n")
    for _, row in ipairs(rows) do
        local label = U and U.pad_right and U.pad_right(row[1], command_width)
            or (row[1] .. string.rep(" ", math.max(0, command_width - #row[1])))
        hecho(P.mint .. label .. P.text_muted .. row[2] .. "\n")
    end
end

function W:install()
    for _, id in ipairs(self.trigger_ids or {}) do pcall(killTrigger, id) end
    for _, id in ipairs(self.alias_ids or {}) do pcall(killAlias, id) end
    self.trigger_ids, self.alias_ids = {}, {}
    self.capture = nil

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Typ broni:\s*(.+?)\s+Chwyt:\s*(.+?)\s*$]],
        function() W:on_header(matches[2], matches[3]) end
    )
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Obrazenia:\s*(.+?)\s*$]],
        function() W:on_damage(matches[2]) end
    )
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Wywazenie:\s*(.+?)\s+Skutecznosc:\s*(.+?)\s*$]],
        function() W:on_scores(matches[2], matches[3]) end
    )

    self.alias_ids[#self.alias_ids + 1] = tempAlias(
        [[^/bron (?:pomoc|help)$]],
        function() W:show_help() end
    )
end

if C.help and type(C.help.register) == "function" then
    C.help:register("weapon", {
        title="BRON",
        description={"Skraca opis wywazenia i skutecznosci broni do jednej linii z ocenami liczbowymi."},
        commands={{"/bron pomoc", "ta pomoc"}},
    })
end

W:install()
return W
