-- ChimeraVIP / Containers
-- Czytelne listy zawartosci pojemnikow z monetami na gorze.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
C.containers = C.containers or {}
chimera_overlay.containers = C.containers
local R = C.containers

R.trigger_ids = R.trigger_ids or {}

R.container_words = {
    "plecak",
    "sakiewk",
    "sakw",
    "torb",
    "kosz",
    "worek",
    "worecz",
    "puzdr",
    "skrzyn",
    "kufr",
}

R.word_amounts = {
    jeden=1, jedna=1, jedno=1,
    dwa=2, dwie=2,
    trzy=3, cztery=4, piec=5,
    szesc=6, siedem=7, osiem=8,
    dziewiec=9, dziesiec=10,
}

local trim = U.trim
local normalize = U.normalize
local colors = U.palette

function R:is_container(name)
    local lowered = normalize(name)
    for _, word in ipairs(self.container_words) do
        if lowered:find(word, 1, true) then return true end
    end
    return false
end

function R:split_items(text)
    local parts = {}
    for part in trim(text):gmatch("[^,]+") do
        parts[#parts + 1] = trim(part)
    end

    if #parts > 0 then
        local last = parts[#parts]
        local before, after = last:match("^(.-)%s+i%s+([^,]+)$")
        if before and after then
            parts[#parts] = trim(before)
            parts[#parts + 1] = trim(after)
        end
    end

    local items = {}
    for _, item in ipairs(parts) do
        if item ~= "" then items[#items + 1] = item end
    end
    return items
end

function R:parse_amount(item)
    item = trim(item)
    local lowered = item:lower()

    local number, name = item:match("^(%d+)%s+(.+)$")
    if number then return tostring(number), name end

    local huge = "ogromny stos "
    if lowered:sub(1, #huge) == huge then
        return "1k+", trim(item:sub(#huge + 1))
    end

    local many = "wiele "
    if lowered:sub(1, #many) == many then
        return "~", trim(item:sub(#many + 1))
    end

    local first, rest = item:match("^(%S+)%s+(.+)$")
    if first and rest then
        local value = self.word_amounts[first:lower()]
        if value then return tostring(value), trim(rest) end
    end

    return "1", item
end

function R:is_money(item)
    local lowered = normalize(item)
    return lowered:find("monet", 1, true) ~= nil
        or lowered:find("miedziak", 1, true) ~= nil
end

function R:money_color(item, P)
    local lowered = normalize(item)
    if lowered:find("mithryl", 1, true) then return P.lavender end
    if lowered:find("zlot", 1, true) then return P.yellow end
    if lowered:find("srebr", 1, true) then return P.text end
    if lowered:find("miedz", 1, true) or lowered:find("miedziak", 1, true) then return P.peach end
    return P.text
end

function R:print_item(item, money)
    local P = colors()
    local amount, name = self:parse_amount(item)
    local amount_color = (amount == "~" or amount == "1k+") and P.yellow or P.mint
    local text_color = money and self:money_color(item, P) or P.text

    hecho("\n" .. amount_color .. string.format("%4s", tostring(amount))
        .. P.text_muted .. "  " .. text_color .. name)
end

function R:print_header(state, name)
    local P = colors()
    hecho("\n\n" .. P.lavender .. normalize(name):upper()
        .. P.text_muted .. "  [" .. normalize(state):upper() .. "]"
        .. "\n" .. P.separator .. "-------------------------------------------------------")
end

function R:show(state, name, contents)
    if not self:is_container(name) then return false end
    U.gag_line()

    local money, other = {}, {}
    for _, item in ipairs(self:split_items(contents)) do
        if self:is_money(item) then money[#money + 1] = item else other[#other + 1] = item end
    end

    local P = colors()
    self:print_header(state, name)

    if #money > 0 then
        hecho("\n\n" .. P.text_muted .. "MONETY")
        for _, item in ipairs(money) do self:print_item(item, true) end
    end

    if #other > 0 then
        if #money > 0 then hecho("\n") end
        hecho("\n" .. P.text_muted .. "PRZEDMIOTY")
        for _, item in ipairs(other) do self:print_item(item, false) end
    end

    hecho("\n")
    return true
end

function R:show_empty(state, name)
    if not self:is_container(name) then return false end
    U.gag_line()
    self:print_header(state, name)
    hecho("\n\n" .. colors().text_muted .. "  pusty\n")
    return true
end

function R:install()
    U.clear_triggers(self)

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^\s*(Otwarty|Zamkniety) (.+?) zawiera (.+)\.\s*$]],
        function() R:show(matches[2], matches[3], matches[4]) end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^\s*(Otwarty|Zamkniety) (.+?) jest pusty\.\s*$]],
        function() R:show_empty(matches[2], matches[3]) end
    )
end

R:install()
return R
