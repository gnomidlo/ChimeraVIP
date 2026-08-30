-- ChimeraVIP / Weapon Info
-- Zwarta karta oceny broni: walka, stan, trwalosc, masa, objetosc i wartosc.

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
W.capture_timer = W.capture_timer or nil

local BALANCE_LEVELS = {
    "wyjatkowo zle", "bardzo zle", "zle", "bardzo kiepsko", "kiepsko",
    "przyzwoicie", "srednio", "niezle", "dosc dobrze", "dobrze",
    "bardzo dobrze", "doskonale", "perfekcyjnie", "genialnie",
}

local EFFECTIVENESS_LEVELS = {
    "kompletnie nieskuteczne", "strasznie nieskuteczne", "bardzo nieskuteczne",
    "raczej nieskuteczne", "malo skuteczne", "niezbyt skuteczne",
    "raczej skuteczne", "dosyc skuteczne", "calkiem skuteczne",
    "bardzo skuteczne", "niezwykle skuteczne", "wyjatkowo skuteczne",
    "zabojczo skuteczne", "fantastycznie skuteczne",
}

local QUALITY_LEVELS = {
    ["w znakomitym stanie"] = 6,
    ["w dobrym stanie"] = 5,
    ["liczne walki wyryly swoje pietno"] = 4,
    ["w zlym stanie"] = 3,
    ["w bardzo zlym stanie"] = 2,
    ["natychmiastowa konserwacja"] = 1,
}

-- Zakresy wynikaja z komunikatu gry, nie sa odliczaniem czasu rzeczywistego.
-- Nieznany wariant zachowujemy tekstowo zamiast zgadywac.
local DURABILITY_RANGES = {
    ["bardzo dlugo"] = ">48h",
    ["dlugo"] = "24-48h",
    ["troche"] = "6-24h",
    ["krotko"] = "1-6h",
    ["bardzo krotko"] = "<1h",
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

local function quality_color(level, P)
    if level >= 6 then return P.lavender end
    if level >= 5 then return P.mint end
    if level >= 4 then return P.yellow end
    if level >= 3 then return P.peach end
    return P.rose
end

local function format_weight(grams)
    grams = tonumber(grams)
    if not grams then return "-" end
    if grams >= 1000 then return string.format("%.2f kg", grams / 1000) end
    return tostring(math.floor(grams)) .. " g"
end

local function format_value(copper)
    local amount = math.max(0, math.floor(tonumber(copper) or 0))
    local mithril = math.floor(amount / 24000)
    amount = amount % 24000
    local gold = math.floor(amount / 240)
    amount = amount % 240
    local silver = math.floor(amount / 12)
    local copper_left = amount % 12

    local parts = {}
    if mithril > 0 then parts[#parts + 1] = tostring(mithril) .. "mt" end
    if gold > 0 then parts[#parts + 1] = tostring(gold) .. "z" end
    if silver > 0 then parts[#parts + 1] = tostring(silver) .. "s" end
    if copper_left > 0 or #parts == 0 then parts[#parts + 1] = tostring(copper_left) .. "m" end
    return table.concat(parts, " ")
end

local function short_duration(raw)
    local key = normalize(raw)
    return DURABILITY_RANGES[key] or key
end

function W:touch_capture()
    if self.capture_timer then pcall(killTimer, self.capture_timer) end
    self.capture_timer = tempTimer(2, function()
        W.capture = nil
        W.capture_timer = nil
    end)
end

function W:ensure_capture(reset)
    if reset or type(self.capture) ~= "table" then self.capture = {} end
    self:touch_capture()
    return self.capture
end

function W:reset_capture()
    self.capture = nil
    if self.capture_timer then pcall(killTimer, self.capture_timer) end
    self.capture_timer = nil
end

function W:on_quality_standard(text)
    local key = normalize(text)
    local c = self:ensure_capture(true)
    c.quality = QUALITY_LEVELS[key]
    c.quality_raw = key
    gag_current_line()
end

function W:on_quality_battles()
    local c = self:ensure_capture(true)
    c.quality = QUALITY_LEVELS["liczne walki wyryly swoje pietno"]
    c.quality_raw = "liczne walki wyryly swoje pietno"
    gag_current_line()
end

function W:on_quality_critical()
    local c = self:ensure_capture(true)
    c.quality = QUALITY_LEVELS["natychmiastowa konserwacja"]
    c.quality_raw = "natychmiastowa konserwacja"
    gag_current_line()
end

function W:on_physical(grams, milliliters)
    local c = self:ensure_capture(false)
    c.grams = tonumber(grams)
    c.milliliters = tonumber(milliliters)
    gag_current_line()
end

function W:on_value(copper)
    local c = self:ensure_capture(false)
    c.copper = tonumber(copper)
    gag_current_line()
end

function W:on_duration(duration)
    local c = self:ensure_capture(false)
    c.duration = normalize(duration)
    gag_current_line()
end

function W:on_header(weapon_type, grip)
    local c = self:ensure_capture(false)
    c.weapon_type = normalize(weapon_type)
    c.grip = normalize(grip)
    gag_current_line()
end

function W:on_damage(damage)
    if not self.capture then return end
    self.capture.damage = normalize(damage)
    self:touch_capture()
    gag_current_line()
end

function W:show_card(balance, effectiveness)
    local c = self.capture or {}
    local P = colors()
    local total = balance + effectiveness
    local weapon = tostring(c.weapon_type or "bron"):upper()
    local grip = grip_short(c.grip)
    local damage = tostring(c.damage or "-")

    hecho("\n" .. P.lavender .. weapon .. " " .. P.text .. grip
        .. P.text_muted .. "  |  " .. P.text .. damage .. "\n")

    hecho(P.blue .. "WYW " .. tostring(balance) .. "/14"
        .. P.text_muted .. "  |  " .. P.mint .. "SKUT " .. tostring(effectiveness) .. "/14"
        .. P.text_muted .. "  |  " .. P.peach .. "OCENA " .. tostring(total) .. "/28\n")

    local state_parts = {}
    if c.quality then
        state_parts[#state_parts + 1] = quality_color(c.quality, P) .. "JAK " .. tostring(c.quality) .. "/6"
    end
    if c.duration and c.duration ~= "" then
        state_parts[#state_parts + 1] = P.lavender .. "TRW " .. short_duration(c.duration)
    end
    if #state_parts > 0 then
        hecho("\n" .. table.concat(state_parts, P.text_muted .. "  |  ") .. "\n")
    end

    local physical = {}
    if c.grams then physical[#physical + 1] = P.text .. format_weight(c.grams) end
    if c.milliliters then physical[#physical + 1] = P.text .. tostring(math.floor(c.milliliters)) .. " ml" end
    if c.copper then physical[#physical + 1] = P.yellow .. "WART " .. format_value(c.copper) end
    if #physical > 0 then
        hecho(table.concat(physical, P.text_muted .. "  |  ") .. "\n")
    end
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
    self:show_card(balance, effectiveness)
    self:reset_capture()
end

function W:show_help()
    local P = colors()
    hecho("\n\n" .. P.lavender .. "BRON — POMOC"
        .. "\n" .. P.text_muted .. "Zamienia ocene broni na zwarta karte:"
        .. "\n\n" .. P.lavender .. "TOPOR " .. P.text .. "1H"
        .. P.text_muted .. "  |  " .. P.text .. "ciete"
        .. "\n" .. P.blue .. "WYW 4/14" .. P.text_muted .. "  |  "
        .. P.mint .. "SKUT 8/14" .. P.text_muted .. "  |  " .. P.peach .. "OCENA 12/28"
        .. "\n\n" .. P.yellow .. "JAK 4/6" .. P.text_muted .. "  |  " .. P.lavender .. "TRW 24-48h"
        .. "\n" .. P.text .. "3.10 kg" .. P.text_muted .. "  |  " .. P.text .. "500 ml"
        .. P.text_muted .. "  |  " .. P.yellow .. "WART 1z 6s 8m"
        .. "\n\n" .. P.mint .. "/bron pomoc" .. P.text_muted .. "  ta pomoc\n")
end

function W:install()
    for _, id in ipairs(self.trigger_ids or {}) do pcall(killTrigger, id) end
    for _, id in ipairs(self.alias_ids or {}) do pcall(killAlias, id) end
    if self.capture_timer then pcall(killTimer, self.capture_timer) end
    self.trigger_ids, self.alias_ids = {}, {}
    self.capture, self.capture_timer = nil, nil

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Wyglada na to, ze jest (w znakomitym stanie|w dobrym stanie|w zlym stanie|w bardzo zlym stanie)\.\s*$]],
        function() W:on_quality_standard(matches[2]) end
    )
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Wyglada na to, ze liczne walki wyryly na (?:nim|niej) swoje pietno\.\s*$]],
        function() W:on_quality_battles() end
    )
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Wyglada na to, ze wym(?:aga|ga) natychmiastowej konserwacji i moze peknac w kazdej chwili\.\s*$]],
        function() W:on_quality_critical() end
    )
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Oceniasz, ze .+? wazy (\d+) gramow, zas (?:jego|jej) objetosc wynosi (\d+) mililitrow\.\s*$]],
        function() W:on_physical(matches[2], matches[3]) end
    )
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Wydaje ci sie, ze jest wart(?:a|e)? (\d+) miedziakow\.\s*$]],
        function() W:on_value(matches[2]) end
    )
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Wyglada na to, ze mogl(?:by|aby|oby) ci jeszcze (.+?) sluzyc\.\s*$]],
        function() W:on_duration(matches[2]) end
    )
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
        description={
            "Sklada ocene broni w zwarta karte: parametry bojowe, jakosc, przedzial trwalosci, mase, objetosc i wartosc.",
            "OCENA to suma WYW i SKUT. JAK i TRW opisuja stan konkretnego egzemplarza i nie zmieniaja oceny bojowej.",
        },
        commands={{"/bron pomoc", "ta pomoc"}},
    })
end

W:install()
return W
