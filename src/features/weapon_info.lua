-- ChimeraVIP / Equipment appraisal
-- Parser nowego formatu "oceniasz starannie". Nie gaguje odpowiedzi MUD-a:
-- zbiera twarde dane i dopisuje male podsumowanie na koncu oceny.

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
W.capture_timeout = 4

local colors = U.palette
local trim = U.trim
local normalize = U.normalize

local CONDITION_LEVELS = {
    -- "w znakomitym stanie" jest wspolne dla skal 5- i 7-stopniowej;
    -- maksimum ustalamy dopiero, gdy linia KP/broni okresli rodzaj sprzetu.
    ["w znakomitym stanie"] = {maximum=true},

    -- Pozostaly sprzet, w tym tarcze: skala 1-5.
    ["lekko podniszczony"] = {current=4, maximum=5},
    ["lekko podniszczona"] = {current=4, maximum=5},
    ["lekko podniszczone"] = {current=4, maximum=5},
    ["w kiepskim stanie"] = {current=3, maximum=5},
    ["w oplakanym stanie"] = {current=2, maximum=5},
    ["gotowy sie rozpasc w kazdej chwili"] = {current=1, maximum=5},
    ["gotowa sie rozpasc w kazdej chwili"] = {current=1, maximum=5},
    ["gotowe sie rozpasc w kazdej chwili"] = {current=1, maximum=5},

    -- Bron: skala 1-7.
    ["w dobrym stanie"] = {current=6, maximum=7},
    ["liczne walki wyryly swoje pietno"] = {current=5, maximum=7},
    ["w zlym stanie"] = {current=4, maximum=7},
    ["w bardzo zlym stanie"] = {current=3, maximum=7},
    ["wymaga natychmiastowej konserwacji"] = {current=2, maximum=7},
    ["wymagaja natychmiastowej konserwacji"] = {current=2, maximum=7},
    ["moze peknac w kazdej chwili"] = {current=1, maximum=7},
}

local DURATION_RANGES = {
    ["bardzo dlugo"] = ">48h",
    ["dlugo"] = "24-48h",
    ["troche"] = "6-24h",
    ["krotko"] = "1-6h",
    ["bardzo krotko"] = "<1h",
}

local function parse_money(text)
    local raw = normalize(text)
    local value = {mt=0, z=0, s=0, m=0}
    value.mt = tonumber(raw:match("(%d+)%s+mithryl")) or 0
    value.z = tonumber(raw:match("(%d+)%s+zlot")) or 0
    value.s = tonumber(raw:match("(%d+)%s+srebr")) or 0
    value.m = tonumber(raw:match("(%d+)%s+miedz")) or 0
    if value.mt == 0 and value.z == 0 and value.s == 0 and value.m == 0 then
        value.m = tonumber(raw:match("(%d+)%s+miedziak")) or 0
    end
    return value
end

local function colored_money(value, P)
    if type(value) ~= "table" then return P.text_muted .. "-" end
    local parts = {}
    if (value.mt or 0) > 0 then parts[#parts + 1] = P.lavender .. tostring(value.mt) .. "mt" end
    if (value.z or 0) > 0 then parts[#parts + 1] = P.yellow .. tostring(value.z) .. "z" end
    if (value.s or 0) > 0 then parts[#parts + 1] = P.text .. tostring(value.s) .. "s" end
    if (value.m or 0) > 0 or #parts == 0 then parts[#parts + 1] = P.peach .. tostring(value.m or 0) .. "m" end
    return table.concat(parts, P.text_muted .. " ")
end

local function format_weight(grams)
    grams = tonumber(grams)
    if not grams then return "-" end
    if grams >= 1000 then
        local kg = grams / 1000
        if kg == math.floor(kg) then return tostring(math.floor(kg)) .. " kg" end
        return string.format("%.1f kg", kg)
    end
    return tostring(math.floor(grams)) .. " g"
end

local function condition_level(text)
    local key = normalize(text)
    return CONDITION_LEVELS[key]
end

local function condition_color(current, maximum, P)
    if not current or not maximum then return P.text end
    if current == maximum then return P.lavender end
    if maximum == 7 and current == 6 then return P.mint end
    if current >= 4 then return P.yellow end
    if current == 3 then return P.peach end
    if current <= 2 then return P.rose end
    return P.text
end

local function duration_range(text)
    local key = normalize(text)
    return DURATION_RANGES[key] or trim(text)
end

local function armor_damage_line(rows, key, label, color, P)
    local parts = {}
    for _, row in ipairs(rows or {}) do
        parts[#parts + 1] = P.text_muted .. row.location .. ": " .. P.text .. tostring(row[key])
    end
    return "\n    " .. color .. string.format("%-10s", label .. ":") .. table.concat(parts, P.text_muted .. " | ")
end

function W:touch_capture()
    if self.capture_timer then pcall(killTimer, self.capture_timer) end
    self.capture_timer = tempTimer(self.capture_timeout, function()
        W.capture = nil
        W.capture_timer = nil
    end)
end

function W:start(item_name)
    self.capture = {item_name=trim(item_name), armor={}, magic=false}
    self:touch_capture()
end

function W:ensure_capture()
    if type(self.capture) ~= "table" then self.capture = {armor={}, magic=false} end
    self:touch_capture()
    return self.capture
end

function W:reset_capture()
    self.capture = nil
    if self.capture_timer then pcall(killTimer, self.capture_timer) end
    self.capture_timer = nil
end

function W:on_condition(description, current, maximum)
    local c = self:ensure_capture()
    c.condition_text = trim(description)
    local mapped = condition_level(description)
    c.condition = tonumber(current) or (mapped and mapped.current)
    c.condition_max = tonumber(maximum) or (mapped and mapped.maximum ~= true and mapped.maximum or nil)
    c.condition_is_maximum = mapped and mapped.maximum == true or false
end

function W:on_physical(item_name, amount, unit, milliliters)
    local c = self:ensure_capture()
    c.item_name = trim(item_name)
    local weight = tonumber(amount)
    if unit == "kilogramow" then weight = weight and weight * 1000 or nil end
    c.grams = weight
    c.milliliters = tonumber(milliliters)
end

function W:on_value(text)
    local c = self:ensure_capture()
    c.value = parse_money(text)
    c.value_raw = trim(text)
end

function W:on_duration(duration)
    self:ensure_capture().duration = trim(duration)
end

function W:on_magic()
    self:ensure_capture().magic = true
end

function W:on_weapon_header(weapon_type, grip)
    local c = self:ensure_capture()
    c.weapon_type = trim(weapon_type)
    c.grip = trim(grip)
end

function W:on_damage(damage)
    self:ensure_capture().damage = trim(damage)
end

function W:on_weapon_scores(balance_text, balance, effectiveness_text, effectiveness)
    local c = self:ensure_capture()
    c.kind = "weapon"
    c.balance_text = trim(balance_text)
    c.balance = tonumber(balance)
    c.effectiveness_text = trim(effectiveness_text)
    c.effectiveness = tonumber(effectiveness)
    self:show_summary()
    self:reset_capture()
end

function W:parse_armor(text)
    local rows = {}
    for chunk in tostring(text or ""):gmatch("[^,]+") do
        local location, pierce, slash, blunt = trim(chunk):match("^(.-)%s+(%d+)/(%d+)/(%d+)$")
        if location then
            rows[#rows + 1] = {location=trim(location), pierce=tonumber(pierce), slash=tonumber(slash), blunt=tonumber(blunt)}
        end
    end
    return rows
end

function W:on_armor(text)
    local c = self:ensure_capture()
    c.kind = "armor"
    c.armor = self:parse_armor(text)
    self:show_summary()
    self:reset_capture()
end

function W:show_summary()
    local c = self.capture
    if type(c) ~= "table" then return end
    local P = colors()
    local title = trim(c.item_name)
    if title == "" then title = "przedmiot" end
    if c.condition_is_maximum and not c.condition_max then
        c.condition_max = c.kind == "weapon" and 7 or 5
        c.condition = c.condition_max
    end

    hecho("\n" .. P.separator .. "-------------------------------------------------------")
    if c.magic then
        hecho("\n" .. P.lavender .. "OCENA - " .. title .. "  |  MAGIA")
    else
        hecho("\n" .. P.lavender .. "OCENA" .. P.text_muted .. " - " .. P.text .. title)
    end

    local details = {}
    if c.condition and c.condition_max then
        details[#details + 1] = P.text_muted .. "stan: " .. condition_color(c.condition, c.condition_max, P)
            .. tostring(c.condition) .. "/" .. tostring(c.condition_max)
    elseif c.condition_text then
        details[#details + 1] = P.text_muted .. "stan: " .. P.text .. c.condition_text
    end
    if c.value then details[#details + 1] = P.text_muted .. "wartosc: " .. colored_money(c.value, P) end
    if #details > 0 then hecho("\n  " .. table.concat(details, P.text_muted .. "  |  ")) end

    local physical = {}
    if c.grams then physical[#physical + 1] = P.text_muted .. "waga: " .. P.text .. format_weight(c.grams) end
    if c.milliliters then physical[#physical + 1] = P.text_muted .. "objetosc: " .. P.text .. tostring(c.milliliters) .. " ml" end
    if c.duration then physical[#physical + 1] = P.text_muted .. "czas: " .. P.text .. duration_range(c.duration) end
    if #physical > 0 then hecho("\n  " .. table.concat(physical, P.text_muted .. "  |  ")) end

    if c.kind == "weapon" then
        local weapon = {}
        if c.weapon_type then weapon[#weapon + 1] = P.text_muted .. "typ: " .. P.text .. c.weapon_type end
        if c.grip then weapon[#weapon + 1] = P.text_muted .. "chwyt: " .. P.text .. c.grip end
        if c.damage then weapon[#weapon + 1] = P.text_muted .. "obrazenia: " .. P.text .. c.damage end
        if #weapon > 0 then hecho("\n  " .. table.concat(weapon, P.text_muted .. "  |  ")) end
        if c.balance and c.effectiveness then
            hecho("\n  " .. P.text_muted .. "WYW: " .. P.blue .. tostring(c.balance)
                .. P.text_muted .. "  |  SKUT: " .. P.mint .. tostring(c.effectiveness)
                .. P.text_muted .. "  |  SUMA: " .. P.lavender .. tostring(c.balance + c.effectiveness))
        end
    elseif c.kind == "armor" then
        if #(c.armor or {}) == 0 then
            hecho("\n  " .. P.text_muted .. "KP: brak rozpoznanych danych")
        else
            hecho("\n  " .. P.text_muted .. "KP:")
            hecho(armor_damage_line(c.armor, "pierce", "KLUTE", P.blue, P))
            hecho(armor_damage_line(c.armor, "slash", "CIETE", P.mint, P))
            hecho(armor_damage_line(c.armor, "blunt", "OBUCHOWE", P.peach, P))
        end
    end

    hecho("\n" .. P.separator .. "-------------------------------------------------------\n")
end

function W:show_help()
    local P = colors()
    hecho("\n\n" .. P.lavender .. "SPRZET - OCENA"
        .. "\n" .. P.text_muted .. "Parser oceny sprzetu nie ukrywa ani nie przebudowuje odpowiedzi MUD-a."
        .. "\n" .. P.text_muted .. "Przedmioty magiczne maja wyrozniony naglowek OCENA - nazwa | MAGIA."
        .. "\n" .. P.text_muted .. "Stan opisowy: skala 1-5 dla tarcz i pozostalego sprzetu, 1-7 dla broni."
        .. "\n" .. P.text_muted .. "Czas sluzenia jest mapowany na przyblizony zakres godzin."
        .. "\n" .. P.text_muted .. "KP jest rozbite na klute, ciete i obuchowe, aby latwo porownac ochrone lokacji."
        .. "\n" .. P.text_muted .. "Dla broni SUMA = WYW + SKUT; nie zakladamy obecnie zadnej maksymalnej skali."
        .. "\n\n" .. P.mint .. "/bron pomoc" .. P.text_muted .. "  ta pomoc\n")
end

function W:install()
    U.clear_triggers(self)
    U.clear_aliases(self)
    self:reset_capture()

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger([[^Oceniasz starannie (.+)\.\s*$]], function() W:start(matches[2]) end)
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger([[^Wyglada na to, ze jest (.+?)\.\s*\[(\d+)/(\d+)\]\s*$]], function() if W.capture then W:on_condition(matches[2], matches[3], matches[4]) end end)
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger([[^Wyglada na to, ze jest (w (?:znakomitym|dobrym|kiepskim|oplakanym|zlym|bardzo zlym) stanie|lekko podniszczon(?:y|a|e)|gotow(?:y|a|e) sie rozpasc w kazdej chwili)\.\s*$]], function() if W.capture then W:on_condition(matches[2]) end end)
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger([[^Wyglada na to, ze liczne walki wyryly na (?:nim|niej) swoje pietno\.\s*$]], function() if W.capture then W:on_condition("liczne walki wyryly swoje pietno") end end)
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger([[^Wyglada na to, ze (wymag(?:a|aja) natychmiastowej konserwacji|moze peknac w kazdej chwili)(?: i moze peknac w kazdej chwili)?\.\s*$]], function() if W.capture then W:on_condition(matches[2]) end end)
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger([[^Oceniasz, ze (.+?) wazy (\d+) (gramow|kilogramow), zas (?:jego|jej|ich) objetosc wynosi (\d+) mililitrow\.\s*$]], function() W:on_physical(matches[2], matches[3], matches[4], matches[5]) end)
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger([[^Wydaje ci sie, ze jest wart(?:a|e)? (.+?)\.\s*$]], function() W:on_value(matches[2]) end)
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger([[^Wyglada na to, ze mogl(?:by|aby|oby) ci jeszcze (.+?) sluzyc\.\s*$]], function() W:on_duration(matches[2]) end)
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger([[^Sadzac po .*zostala zakleta jakas magia\.\s*$]], function() W:on_magic() end)
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger([[^Typ broni:\s*(.+?)\s+Chwyt:\s*(.+?)\s*$]], function() W:on_weapon_header(matches[2], matches[3]) end)
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger([[^Obrazenia:\s*(.+?)\s*$]], function() W:on_damage(matches[2]) end)
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger([[^Wywazenie:\s*(.*?)\s*\[(\d+)\]\s+Skutecznosc:\s*(.*?)\s*\[(\d+)\]\s*$]], function() W:on_weapon_scores(matches[2], matches[3], matches[4], matches[5]) end)
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger([[^Klasa pancerza \(klute/ciete/obuchowe\):\s*(.+?)\.\s*$]], function() W:on_armor(matches[2]) end)

    self.alias_ids[#self.alias_ids + 1] = tempAlias([[^/bron (?:pomoc|help)$]], function() W:show_help() end)
end

if C.help and type(C.help.register) == "function" then
    C.help:register("weapon", {
        title="SPRZET - OCENA",
        description={
            "Podsluchuje nowy format 'oceniasz starannie' bez gagowania oryginalnej odpowiedzi.",
            "Dopisuje zwiezle podsumowanie danych dla broni i pancerza.",
        },
        commands={{"/bron pomoc", "ta pomoc"}},
    })
end

W:install()
return W
