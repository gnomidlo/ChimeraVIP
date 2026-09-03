-- ChimeraVIP / Weapon Info
-- Estetyczna karta oceny broni: walka, stan, trwalosc, masa, objetosc i wartosc.

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

local DURABILITY_RANGES = {
    ["bardzo dlugo"] = ">48h",
    ["dlugo"] = "24-48h",
    ["troche"] = "6-24h",
    ["krotko"] = "1-6h",
    ["bardzo krotko"] = "<1h",
}

local normalize = U.normalize
local colors = U.palette
local gag_current_line = U.gag_line

local function make_index(levels)
    local out = {}
    for i, value in ipairs(levels) do out[normalize(value)] = i end
    return out
end

W.balance_index = make_index(BALANCE_LEVELS)
W.effectiveness_index = make_index(EFFECTIVENESS_LEVELS)

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

local function score_color(score, P)
    if score <= 8 then return P.rose end
    if score <= 13 then return P.peach end
    if score <= 18 then return P.yellow end
    if score <= 23 then return P.mint end
    return P.lavender
end

local function format_weight(grams)
    grams = tonumber(grams)
    if not grams then return "-" end
    if grams >= 1000 then return string.format("%.2f kg", grams / 1000) end
    return tostring(math.floor(grams)) .. " g"
end

local function split_value(copper)
    local amount = math.max(0, math.floor(tonumber(copper) or 0))
    local value = {}
    value.mt = math.floor(amount / 24000)
    amount = amount % 24000
    value.z = math.floor(amount / 240)
    amount = amount % 240
    value.s = math.floor(amount / 12)
    value.m = amount % 12
    return value
end

local function colored_value(copper, P)
    local value = split_value(copper)
    local parts = {}
    if value.mt > 0 then parts[#parts + 1] = P.lavender .. tostring(value.mt) .. "mt" end
    if value.z > 0 then parts[#parts + 1] = P.yellow .. tostring(value.z) .. "z" end
    if value.s > 0 then parts[#parts + 1] = P.text .. tostring(value.s) .. "s" end
    if value.m > 0 or #parts == 0 then parts[#parts + 1] = P.peach .. tostring(value.m) .. "m" end
    return table.concat(parts, P.text_muted .. " ")
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

function W:on_physical(item_name, grams, milliliters)
    local c = self:ensure_capture(false)
    c.item_name = normalize(item_name)
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
    local weapon = tostring(c.weapon_type or "bron")
    local grip = grip_short(c.grip)
    local damage = tostring(c.damage or "-")
    local title = tostring(c.item_name or (weapon .. " " .. grip)):upper()

    hecho("\n\n" .. P.lavender .. title .. "\n")
    hecho(P.separator .. "-------------------------------------------------------\n\n")

    hecho(P.text_muted .. "rodzaj: " .. P.text .. weapon .. " " .. grip
        .. P.text_muted .. "  |  obrazenia: " .. P.text .. damage .. "\n")

    local quality = c.quality and (quality_color(c.quality, P) .. tostring(c.quality) .. "/6") or (P.text_muted .. "-")
    local duration = c.duration and (P.lavender .. short_duration(c.duration)) or (P.text_muted .. "-")
    hecho(P.text_muted .. "jakosc: " .. quality
        .. P.text_muted .. "  |  czas: " .. duration .. "\n")

    hecho(P.text_muted .. "waga: " .. P.text .. format_weight(c.grams)
        .. P.text_muted .. "  |  objetosc: " .. P.text .. tostring(c.milliliters and math.floor(c.milliliters) or "-") .. " ml"
        .. P.text_muted .. "  |  wartosc: " .. (c.copper and colored_value(c.copper, P) or (P.text_muted .. "-")) .. "\n")

    hecho(P.text_muted .. "wywazenie: " .. P.blue .. tostring(balance) .. "/14"
        .. P.text_muted .. "  |  skutecznosc: " .. P.mint .. tostring(effectiveness) .. "/14"
        .. P.text_muted .. "  |  " .. score_color(total, P) .. "LACZNA OCENA " .. tostring(total) .. "/28\n")
end

function W:on_scores(balance_text, effectiveness_text)
    if not self.capture or not self.capture.damage then return end
    local balance = self.balance_index[normalize(balance_text)]
    local effectiveness = self.effectiveness_index[normalize(effectiveness_text)]
    if not balance or not effectiveness then self:reset_capture(); return end
    gag_current_line()
    self:show_card(balance, effectiveness)
    self:reset_capture()
end

function W:show_help()
    local P = colors()
    hecho("\n\n" .. P.lavender .. "BRON — POMOC"
        .. "\n" .. P.text_muted .. "Zamienia pelna ocene broni na czytelna karte przedmiotu."
        .. "\n" .. P.text_muted .. "LACZNA OCENA to suma wywazenia i skutecznosci (maks. 28)."
        .. "\n" .. P.text_muted .. "Kolor oceny zmienia sie wraz z wynikiem; wartosc ma osobne kolory nominałów."
        .. "\n\n" .. P.mint .. "/bron pomoc" .. P.text_muted .. "  ta pomoc\n")
end

function W:install()
    U.clear_triggers(self)
    U.clear_aliases(self)
    if self.capture_timer then pcall(killTimer, self.capture_timer) end
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
        [[^Oceniasz, ze (.+?) wazy (\d+) gramow, zas (?:jego|jej) objetosc wynosi (\d+) mililitrow\.\s*$]],
        function() W:on_physical(matches[2], matches[3], matches[4]) end
    )
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Wydaje ci sie, ze jest wart(?:a|e)? (\d+) miedziak(?:i|ow)?\.\s*$]],
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
            "Sklada pelna ocene broni w estetyczna karte: rodzaj, obrazenia, jakosc, czas, mase, objetosc, wartosc i parametry bojowe.",
            "LACZNA OCENA jest suma WYW i SKUT; jej kolor zalezy od wyniku 2-28.",
        },
        commands={{"/bron pomoc", "ta pomoc"}},
    })
end

W:install()
return W
