-- Presentation of the game's postac reports. Does not alter character choices.
chimera_vip = chimera_vip or {}
local C, U = chimera_vip, chimera_vip.util
C.character_sheet = C.character_sheet or {}
local V = C.character_sheet
if V.timer then pcall(killTimer, V.timer) end
V.timer, V.section, V.details = nil, nil, false
V.trigger_ids = V.trigger_ids or {}
local headings = {
    POSTAC=true, CECHY=true, PROFESJA=true, SPECJALIZACJE=true,
    ["KAMIENIE MILOWE"]=true, ["UMIEJETNOSCI PROFESJI"]=true,
}
local stats = {Sila="sila", Zrecznosc="zrecznosc", Wytrzymalosc="wytrzymalosc",
    Inteligencja="inteligencja", Madrosc="madrosc", Odwaga="odwaga"}
local sections = {Cechy=true, Profesja=true, Specjalizacje=true,
    ["Kamienie Milowe"]=true, ["Rola:"]=true, ["Wyszkolenie:"]=true,
    ["Bronie:"]=true, ["Cecha profesji:"]=true, ["Wybrane:"]=true,
    ["Dostepne:"]=true, ["Zablokowane:"]=true}

function V:touch()
    if self.timer then pcall(killTimer, self.timer) end
    self.timer = tempTimer(2, function()
        V.section, V.timer, V.details = nil, nil, false
    end)
end

local function link(label, command, hint)
    if type(echoLink) == "function" then
        local callback = command and string.format("send(%q, false)", command) or ""
        echoLink(label, callback, hint or command or "", true)
    else
        hecho(label)
    end
end

function V:render(raw)
    local text, P = U.trim(raw), U.palette()
    if headings[text] or text:match("^SPECJALIZACJE%s+%-%-") then
        self.section, self.details = text, false
        self:touch()
        return function() hecho(P.lavender .. text) end
    end
    if not self.section then return nil end
    if text == "" then return nil end
    if not raw:match("^%s") and not sections[text]
        and text ~= "Szczegoly:" and text ~= "Dostepne kategorie:"
        and not text:match("^Wybrane:") and not text:match("^Aktywne:")
        and not text:match("^Specjalizacje%s") and not text:match("^Kamienie Milowe%s")
        and not text:find(" -- ", 1, true)
        and not stats[text:match("^(%S+)")] then
        self.section = nil
        return nil
    end
    self:touch()

    -- Keep full multiword specialization names; clicking only requests details.
    local name, kind = text:match("^(.-)%s+%[([^%]]+)%]%s*$")
    if name and (kind == "walka" or kind == "pasywna" or kind == "komenda") then
        return function()
            hecho("  " .. P.text)
            link(U.pad_right(name, 32), "specjalizacja " .. name)
            hecho((kind == "walka" and P.peach or P.mint) .. "[" .. kind .. "]")
        end
    end
    local stat, rest = text:match("^(%S+)%s+(.+)$")
    if stats[stat] then
        local description, value = rest:match("^(.-)(%d+)$")
        if value then
            return function()
                hecho("  " .. P.blue)
                link(U.pad_right(stat, 15), self.section == "KAMIENIE MILOWE"
                    and ("postac kamienie " .. stats[stat]) or "postac cechy")
                hecho(P.mint .. string.format("%3d", tonumber(value))
                    .. P.text_muted .. "  " .. U.trim(description))
            end
        end
    end
    local milestone, displayed, earned, total = text:match(
        "^(.-)%s+%(do nastepnego:%s*(%d+)%%,%s*(%d+)/(%d+)%s+exp%)$"
    )
    if milestone and tonumber(total) > 0 then
        local percent = tonumber(earned) / tonumber(total) * 100
        local short = percent > 0 and percent < 0.01 and "<0,01%"
            or (string.format("%.2f%%", percent):gsub("%.", ","))
        return function()
            hecho("  " .. P.text .. U.pad_right(milestone, 48) .. P.mint)
            link(short, nil, U.format_int(earned) .. " / " .. U.format_int(total)
                .. " exp (gra: " .. displayed .. "%)")
        end
    end
    if text == "Szczegoly:" or text == "Dostepne kategorie:" then
        self.details = true
        if self.section == "POSTAC" then
            return function()
                hecho(P.blue)
                for _, item in ipairs({{"CECHY", "cechy"}, {"PROFESJA", "profesja"},
                    {"SPECJALIZACJE", "specjalizacje"}, {"KAMIENIE", "kamienie"}}) do
                    link("[" .. item[1] .. "]", "postac " .. item[2]); hecho("  ")
                end
            end
        end
        return function() hecho(P.blue .. text) end
    end
    if self.details and text:match("^postac%s") and not text:find("<", 1, true) then
        if self.section == "POSTAC" then return function() end end
        return function() hecho("  " .. P.blue); link("[" .. text .. "]", text) end
    end
    if self.details and text == "postac kamienie <cecha>" then
        return function()
            hecho("  " .. P.blue)
            for _, label in ipairs({"Sila", "Zrecznosc", "Wytrzymalosc", "Inteligencja", "Madrosc", "Odwaga"}) do
                link("[" .. label .. "]", "postac kamienie " .. stats[label])
                hecho(" ")
            end
        end
    end
    if sections[text] or text:match("^Specjalizacje%s") or text:match("^Kamienie Milowe%s") then
        return function() hecho(P.blue .. text) end
    end
    if text:match("^Wybrane:") or text:match("^Aktywne:") or text:match("^Wyszkolenie:")
        or text:match("^[IVX]+ %-") then
        return function() hecho("  " .. P.mint .. text) end
    end
    if text:find(" -- ", 1, true) then
        return function() hecho(P.lavender .. text) end
    end
    -- Other indented descriptions retain all source text.
    if raw:match("^%s") then return function() hecho(P.text_muted .. raw) end end
end

U.clear_triggers(V)
V.trigger_ids[1] = tempRegexTrigger([[^.*$]], function()
    local draw = V:render(getCurrentLine())
    if draw then
        selectCurrentLine()
        replace("")
        draw()
    end
end)
return V
