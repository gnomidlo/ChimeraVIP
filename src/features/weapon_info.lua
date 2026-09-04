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

-- Drabinka zgodna z dawnym parserem, rozszerzona do nowej skali 1-7.
-- Serwer potwierdzil jawnie "w dobrym stanie" jako 6/7.
local CONDITION_LEVELS = {
    ["w znakomitym stanie"] = 7,
    ["w dobrym stanie"] = 6,
    ["w kiepskim stanie"] = 5,
    ["liczne walki wyryly swoje pietno"] = 4,
    ["w zlym stanie"] = 3,
    ["w bardzo zlym stanie"] = 2,
    ["natychmiastowa konserwacja"] = 1,
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
    if CONDITION_LEVELS[key] then return CONDITION_LEVELS[key] end
    if key:find("znakomitym", 1, true) then return 7 end
    if key:find("dobrym", 1, true) then return 6 end
    if key:find("kiepskim", 1, true) then return 5 end
    if key:find("liczne walki", 1, true) then return 4 end
    if key:find("bardzo zlym", 1, true) then return 2 end
    if key:find("zlym", 1, true) then return 3 end
    if key:find("natychmiastowej konserwacji", 1, true) then return 1 end
    return nil
end

local function condition_color(text, P)
    local level = condition_level(text)
    if level == 7 then return P.lavender end
    if level == 6 then return P.mint end
    if level == 5 or level == 4 then return P.yellow end
    if level == 3 then return P.peach end
    if level and level <= 2 then return P.rose end
    return P.text
end

local function duration_range(text)
    local key = normalize(text)
    return DURATION_RANGES[key] or trim(text)
end

function W:touch_capture()
    if self.capture_timer then pcall(killTimer, self.capture_timer) end
    self.capture_timer = tempTimer(self.capture_timeout, function()
        W.capture = nil
        W.capture_timer = nil
    end)
end

function W:start(item_name)
    self.capture = {
        item_name = trim(item_name),
        armor = {},
        magic = false,
    }
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
    c.condition = tonumber(current) or condition_level(description)
    c.condition_max = tonumber(maximum) or (c.condition and 7 or nil)
end

function W:on_physical(item_name, amount, unit, milliliters)
    local c = self:ensure_capture()
    -- Ta linia daje nazwe przedmiotu w mianowniku, w przeciwienstwie do
    -- "Oceniasz starannie ...", ktore zwykle uzywa biernika.
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
    local c = self:ensure_capture()
    c.duration = trim(duration)
end

function W:on_magic()
    local c = self:ensure_capture()
    c.magic = true
end

function W:on_weapon_header(weapon_type, grip)
    local c = self:ensure_capture()
    c.weapon_type = trim(weapon_type)
    c.grip = trim(grip)
end

function W:on_damage(damage)
    local c = self:ensure_capture()
    c.damage = trim(damage)
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
            rows[#rows + 1] = {
                location=trim(location),
                pierce=tonumber(pierce), slash=tonumber(slash), blunt=tonumber(blunt),
            }
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

    hecho("\n" .. P.separator .. "-------------------------------------------------------")
    hecho("\n" .. P.lavender .. "OCENA" .. P.text_muted .. " - " .. P.text .. title)

    local details = {}
    if c.condition and c.condition_max then
        details[#details + 1] = P.text_muted .. "stan: " .. condition_color(c.condition_text, P)
            .. tostring(c.condition) .. "/" .. tostring(c.condition_max)
    elseif c.condition_text then
        details[#details + 1] = P.text_muted .. "stan: " .. condition_color(c.condition_text, P) .. c.condition_text
    end
    if c.value then
        details[#details + 1] = P.text_muted .. "wartosc: " .. colored_money(c.value, P)
    end
    if c.magic then details[#details + 1] = P.lavender .. "MAGIA" end
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
            local parts = {}
            for _, row in ipairs(c.armor) do
                parts[#parts + 1] = P.text_muted .. row.location .. " " .. P.mint
                    .. tostring(row.pierce) .. "/" .. tostring(row.slash) .. "/" .. tostring(row.blunt)
            end
            hecho("\n  " .. P.text_muted .. "KP: " .. table.concat(parts, P.text_muted .. "  |  "))
        end
    end

    hecho("\n" .. P.separator .. "-------------------------------------------------------\n")
end

function W:show_help()
    local P = colors()
    hecho("\n\n" .. P.lavender .. "SPRZET - OCENA"
        .. "\n" .. P.text_muted .. "Parser oceny sprzetu nie ukrywa ani nie przebudowuje odpowiedzi MUD-a."
        .. "\n" .. P.text_muted .. "Po surowej ocenie dopisuje podsumowanie stanu, wartosci, masy, objetosci, czasu, magii oraz parametrow broni lub KP."
        .. "\n" .. P.text_muted .. "Stan opisowy jest mapowany na skale 1-7; czas sluzenia na przyblizony zakres godzin."
        .. "\n" .. P.text_muted .. "Dla broni SUMA = WYW + SKUT; nie zakladamy obecnie zadnej maksymalnej skali."
        .. "\n\n" .. P.mint .. "/bron pomoc" .. P.text_muted .. "  ta pomoc\n")
end

function W:install()
    U.clear_triggers(self)
    U.clear_aliases(self)
    self:reset_capture()

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Oceniasz starannie (.+)\.\s*$]],
        function() W:start(matches[2]) end
    )

    -- Wariant z liczbowym stanem, jesli serwer go zwroci.
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Wyglada na to, ze jest (.+?stanie)\.\s*\[(\d+)/(\d+)\]\s*$]],
        function() W:on_condition(matches[2], matches[3], matches[4]) end
    )

    -- Aktualny wariant silnika: tylko opis stanu.
    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Wyglada na to, ze jest (.+?stanie)\.\s*$]],
        function() if W.capture then W:on_condition(matches[2]) end end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Wyglada na to, ze liczne walki wyryly na (?:nim|niej) swoje pietno\.\s*$]],
        function() if W.capture then W:on_condition("liczne walki wyryly swoje pietno") end end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Wyglada na to, ze wym(?:aga|ga) natychmiastowej konserwacji i moze peknac w kazdej chwili\.\s*$]],
        function() if W.capture then W:on_condition("natychmiastowa konserwacja") end end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Oceniasz, ze (.+?) wazy (\d+) (gramow|kilogramow), zas (?:jego|jej|ich) objetosc wynosi (\d+) mililitrow\.\s*$]],
        function() W:on_physical(matches[2], matches[3], matches[4], matches[5]) end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Wydaje ci sie, ze jest wart(?:a|e)? (.+?)\.\s*$]],
        function() W:on_value(matches[2]) end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Wyglada na to, ze mogl(?:by|aby|oby) ci jeszcze (.+?) sluzyc\.\s*$]],
        function() W:on_duration(matches[2]) end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Sadzac po .*zostala zakleta jakas magia\.\s*$]],
        function() W:on_magic() end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Typ broni:\s*(.+?)\s+Chwyt:\s*(.+?)\s*$]],
        function() W:on_weapon_header(matches[2], matches[3]) end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Obrazenia:\s*(.+?)\s*$]],
        function() W:on_damage(matches[2]) end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Wywazenie:\s*(.*?)\s*\[(\d+)\]\s+Skutecznosc:\s*(.*?)\s*\[(\d+)\]\s*$]],
        function() W:on_weapon_scores(matches[2], matches[3], matches[4], matches[5]) end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Klasa pancerza \(klute/ciete/obuchowe\):\s*(.+?)\.\s*$]],
        function() W:on_armor(matches[2]) end
    )

    self.alias_ids[#self.alias_ids + 1] = tempAlias(
        [[^/bron (?:pomoc|help)$]],
        function() W:show_help() end
    )
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
