-- ChimeraVIP / Kamienie Milowe
-- Kompaktowe widoki: przeglad, cecha i karta pojedynczego Kamienia.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
C.milestones = C.milestones or {}
chimera_overlay.milestones = C.milestones
local M = C.milestones

M.trigger_ids = M.trigger_ids or {}
M.alias_ids = M.alias_ids or {}
M.capture = nil
M.capture_timer = nil
M.capture_delay = 0.35

local trim = U.trim
local normalize = U.normalize
local colors = U.palette
local gag_line = U.gag_line

local function compact_number(value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    if value < 1000 then return tostring(value) end
    if value < 1000000 then
        local v = value / 1000
        return v >= 100 and string.format("%.0fk", v) or string.format("%.1fk", v):gsub("%.0k$", "k")
    end
    local v = value / 1000000
    return v >= 100 and string.format("%.0fm", v) or string.format("%.1fm", v):gsub("%.0m$", "m")
end

local function command_link(label, command, hint, color)
    local P = colors()
    color = color or P.mint
    if type(hechoLink) == "function" then
        hechoLink(color .. label, string.format("expandAlias(%q, false)", command), hint or command, true)
    else
        hecho(color .. label)
    end
end

local function xp_link(current, required)
    local P = colors()
    current, required = tonumber(current), tonumber(required)
    if not current or not required then return end
    local short = compact_number(current) .. " / " .. compact_number(required)
    local hint = U.format_int(current) .. " / " .. U.format_int(required) .. " exp"
    if type(hechoLink) == "function" then
        hechoLink(P.peach .. short, "", hint, true)
    else
        hecho(P.peach .. short)
    end
end

function M:parse_stone_line(line)
    line = trim(line)
    line = line:gsub("^%*%s*", "")
    local name, rank, percent, current, required = line:match(
        "^(.-)%s+([IVX]+)%s+%(do nastepnego:%s*(%d+)%%,%s*(%d+)/(%d+)%s+exp%)%s*$"
    )
    if name then
        return {
            name=trim(name), rank=rank, percent=tonumber(percent),
            current=tonumber(current), required=tonumber(required),
        }
    end
    name, rank = line:match("^(.-)%s+([IVX]+)%s*$")
    if name and trim(name) ~= "" then return {name=trim(name), rank=rank} end
    return nil
end

function M:parse_overview_lines(lines)
    local out = {kind="overview", attributes={}, order={}}
    local current
    for _, raw in ipairs(lines or {}) do
        local line = trim(raw)
        local active, maximum = line:match("^Kamienie Milowe %-%- aktywne (%d+) z (%d+)%.?$")
        if active then
            out.active, out.maximum = tonumber(active), tonumber(maximum)
        else
            local name, peak, selected, unlocked = line:match(
                "^(.-) %(szczyt (%d+)%), wybrane (%d+) z (%d+) %(odblokowane szczytem cechy%):$"
            )
            if name then
                current = {
                    name=trim(name), peak=tonumber(peak), selected=tonumber(selected),
                    unlocked=tonumber(unlocked), stones={},
                }
                out.attributes[normalize(name)] = current
                out.order[#out.order+1] = normalize(name)
            elseif current and line:match("^%*") then
                local stone = self:parse_stone_line(line)
                if stone then current.stones[#current.stones+1] = stone end
            elseif line:match("^Masz juz pelny zestaw") then
                out.full_set = true
            end
        end
    end
    return out
end

function M:parse_attribute_lines(lines)
    local out = {kind="attribute", selected_stones={}, available_stones={}, locked_stones={}}
    local section, last_stone
    for _, raw in ipairs(lines or {}) do
        local line = trim(raw)
        if line ~= "" then
            if not out.name and line:match("^[A-Z]+$") then
                out.name = line
            else
                local peak = line:match("^Szczyt cechy:%s*(%d+)$")
                local selected, unlocked = line:match("^Wybrane (%d+) z (%d+) %(odblokowane szczytem cechy%)$")
                local full = line:match("^Zablokowane %(masz juz pelny zestaw (%d+) Kamieni%):$")
                if peak then
                    out.peak = tonumber(peak)
                elseif selected then
                    out.selected, out.unlocked = tonumber(selected), tonumber(unlocked)
                elseif line == "Wybrane:" then
                    section, last_stone = "selected", nil
                elseif line == "Dostepne:" then
                    section, last_stone = "available", nil
                elseif full then
                    out.full_set = tonumber(full)
                    section, last_stone = "locked", nil
                elseif line:match("^%[[IVX]+%]%s+") then
                    local rank, name = line:match("^%[([IVX]+)%]%s+(.+)$")
                    last_stone = {name=trim(name), rank=rank, description={}}
                    local target = section == "selected" and out.selected_stones
                        or section == "available" and out.available_stones
                        or out.locked_stones
                    target[#target+1] = last_stone
                elseif line ~= "-" and last_stone
                    and not line:match("^Szczegoly:")
                    and not line:match("^kamien%s+") then
                    last_stone.description[#last_stone.description+1] = line
                end
            end
        end
    end
    return out
end

function M:parse_detail_lines(lines)
    local out = {kind="detail", effect={}}
    local section
    for _, raw in ipairs(lines or {}) do
        local line = trim(raw)
        if line ~= "" then
            if not out.name and line:match("^[A-Z0-9 ]+$") then
                out.name = line
            else
                local attr = line:match("^Cecha:%s*(.+)$")
                local status, rank, percent, current, required = line:match(
                    "^wybrany, poziom ([IVX]+) %(do nastepnego:%s*(%d+)%%,%s*(%d+)/(%d+)%s+exp%)$"
                )
                local status_rank = line:match("^wybrany, poziom ([IVX]+)$")
                local cost = line:match("^Porzucenie kosztuje (%d+) zlotych monet")
                local command = line:match("^kamien porzuc (.+)$")
                if attr then
                    out.attribute = trim(attr)
                elseif line == "Status:" then
                    section = "status"
                elseif status then
                    out.selected, out.rank = true, status
                    out.percent, out.current, out.required = tonumber(rank), tonumber(percent), tonumber(current)
                    -- Korekta przypisan wynikajacych z wielu capture group.
                    out.rank = status
                    out.percent = tonumber(rank)
                    out.current = tonumber(percent)
                    out.required = tonumber(current)
                elseif status_rank then
                    out.selected, out.rank = true, status_rank
                elseif line == "Dzialanie:" then
                    section = "effect"
                elseif cost then
                    out.abandon_cost = tonumber(cost)
                    section = "abandon"
                elseif command then
                    out.abandon_command = "kamien porzuc " .. trim(command)
                elseif section == "effect" then
                    out.effect[#out.effect+1] = line
                end
            end
        end
    end
    return out
end

-- Osobny, prostszy parser statusu karty. Lua przypisuje capture'y pozycyjnie,
-- dlatego utrzymujemy go oddzielnie od parsera struktury.
function M:parse_detail_status(line, out)
    local rank, percent, current, required = trim(line):match(
        "^wybrany, poziom ([IVX]+) %(do nastepnego:%s*(%d+)%%,%s*(%d+)/(%d+)%s+exp%)$"
    )
    if rank then
        out.selected, out.rank = true, rank
        out.percent, out.current, out.required = tonumber(percent), tonumber(current), tonumber(required)
        return true
    end
    rank = trim(line):match("^wybrany, poziom ([IVX]+)$")
    if rank then out.selected, out.rank = true, rank; return true end
    return false
end

function M:parse_detail_lines(lines)
    local out = {kind="detail", effect={}}
    local section
    for _, raw in ipairs(lines or {}) do
        local line = trim(raw)
        if line ~= "" then
            if not out.name and line:match("^[A-Z0-9 ]+$") then
                out.name = line
            else
                local attr = line:match("^Cecha:%s*(.+)$")
                local cost = line:match("^Porzucenie kosztuje (%d+) zlotych monet")
                local command = line:match("^kamien porzuc (.+)$")
                if attr then
                    out.attribute = trim(attr)
                elseif line == "Status:" then
                    section = "status"
                elseif section == "status" and self:parse_detail_status(line, out) then
                    section = nil
                elseif line == "Dzialanie:" then
                    section = "effect"
                elseif cost then
                    out.abandon_cost = tonumber(cost)
                    section = "abandon"
                elseif command then
                    out.abandon_command = "kamien porzuc " .. trim(command)
                elseif section == "effect" then
                    out.effect[#out.effect+1] = line
                end
            end
        end
    end
    return out
end

function M:render_overview(data)
    local P = colors()
    hecho("\n\n" .. P.lavender .. "KAMIENIE MILOWE  "
        .. P.mint .. tostring(data.active or "?") .. "/" .. tostring(data.maximum or "?")
        .. P.text_muted .. " aktywne"
        .. "\n" .. P.separator .. "-------------------------------------------------------")

    for _, key in ipairs(data.order or {}) do
        local attr = data.attributes[key]
        hecho("\n\n  ")
        command_link(string.format("%-4s", ({
            sila="Sil", zrecznosc="Zr", wytrzymalosc="Wt",
            inteligencja="Int", madrosc="Md", odwaga="Odw",
        })[key] or attr.name), "kamienie " .. key, "Pokaz Kamienie cechy: " .. attr.name, P.blue)
        hecho(P.text_muted .. "  " .. P.text .. tostring(attr.peak or "?")
            .. P.text_muted .. "   " .. tostring(attr.selected or 0) .. "/" .. tostring(attr.unlocked or 0))

        for _, stone in ipairs(attr.stones or {}) do
            hecho("\n      ")
            command_link(stone.name, "kamien " .. normalize(stone.name), "Szczegoly Kamienia", P.text)
            hecho(P.lavender .. "  " .. tostring(stone.rank or ""))
            if stone.percent then
                hecho(P.text_muted .. "   " .. P.mint .. tostring(stone.percent) .. "%   ")
                xp_link(stone.current, stone.required)
            end
        end
    end
    if data.full_set then hecho("\n\n" .. P.text_muted .. "  Pelny zestaw Kamieni.") end
    hecho("\n")
end

local function render_stone_list(title, stones, color)
    if not stones or #stones == 0 then return end
    local P = colors()
    hecho("\n\n" .. color .. title)
    for _, stone in ipairs(stones) do
        hecho("\n  " .. P.lavender .. "[" .. tostring(stone.rank or "?") .. "] ")
        command_link(stone.name, "kamien " .. normalize(stone.name), "Szczegoly Kamienia", P.text)
        for _, desc in ipairs(stone.description or {}) do
            hecho("\n      " .. P.text_muted .. desc)
        end
    end
end

function M:render_attribute(data)
    local P = colors()
    hecho("\n\n" .. P.lavender .. tostring(data.name or "KAMIENIE")
        .. P.text_muted .. "   szczyt " .. P.text .. tostring(data.peak or "?")
        .. P.text_muted .. "   wybrane " .. P.mint .. tostring(data.selected or 0)
        .. P.text_muted .. "/" .. P.text .. tostring(data.unlocked or "?")
        .. "\n" .. P.separator .. "-------------------------------------------------------")

    render_stone_list("WYBRANE", data.selected_stones, P.mint)
    if #data.selected_stones == 0 then hecho("\n\n" .. P.mint .. "WYBRANE\n  " .. P.text_muted .. "-") end
    render_stone_list("DOSTEPNE", data.available_stones, P.blue)
    if #data.locked_stones > 0 then
        local title = data.full_set and ("DOSTEPNE  " .. P.text_muted .. "(wybor zablokowany — pelny zestaw "
            .. tostring(data.full_set) .. "/" .. tostring(data.full_set) .. ")") or "ZABLOKOWANE"
        render_stone_list(title, data.locked_stones, P.yellow)
    end
    hecho("\n")
end

function M:render_detail(data)
    local P = colors()
    hecho("\n\n" .. P.lavender .. tostring(data.name or "KAMIEN")
        .. (data.rank and (P.text_muted .. "  [" .. P.lavender .. data.rank .. P.text_muted .. "]") or "")
        .. "\n" .. P.separator .. "-------------------------------------------------------")
    if data.attribute then hecho("\n" .. P.text_muted .. "  Cecha     " .. P.text .. data.attribute) end
    if data.selected then
        hecho("\n" .. P.text_muted .. "  Status    " .. P.mint .. "wybrany"
            .. P.text_muted .. "  |  poziom " .. P.lavender .. tostring(data.rank or "?"))
        if data.percent then
            hecho("\n" .. P.text_muted .. "  Postep    " .. P.mint .. tostring(data.percent) .. "%  ")
            xp_link(data.current, data.required)
        end
    end
    if #data.effect > 0 then
        hecho("\n\n" .. P.blue .. "DZIALANIE")
        for _, line in ipairs(data.effect) do hecho("\n  " .. P.text .. line) end
    end
    if data.abandon_cost then
        hecho("\n\n" .. P.rose .. "PORZUCENIE"
            .. "\n  " .. P.text_muted .. "koszt: " .. P.peach .. tostring(data.abandon_cost) .. " zl"
            .. P.text_muted .. "  |  poziom Kamienia przepada")
        if data.abandon_command then
            hecho("\n  ")
            command_link("[PORZUC KAMIEN]", data.abandon_command,
                "Porzuc Kamien. Koszt " .. tostring(data.abandon_cost) .. " zl; poziom przepada.", P.rose)
        end
    end
    hecho("\n")
end

function M:finish_capture()
    local capture = self.capture
    self.capture = nil
    if self.capture_timer then pcall(killTimer, self.capture_timer); self.capture_timer=nil end
    if not capture or #capture.lines == 0 then return end

    if capture.kind == "overview" then self:render_overview(self:parse_overview_lines(capture.lines))
    elseif capture.kind == "attribute" then self:render_attribute(self:parse_attribute_lines(capture.lines))
    elseif capture.kind == "detail" then self:render_detail(self:parse_detail_lines(capture.lines)) end
end

function M:touch_capture()
    if self.capture_timer then pcall(killTimer, self.capture_timer) end
    self.capture_timer = tempTimer(self.capture_delay, function() M:finish_capture() end)
end

function M:start_capture(kind, command)
    if self.capture_timer then pcall(killTimer, self.capture_timer) end
    self.capture = {kind=kind, command=command, lines={}}
    self.capture_timer = nil
    send(command, false)
end

function M:capture_line()
    if not self.capture then return end
    local current = getCurrentLine and getCurrentLine() or line or ""
    self.capture.lines[#self.capture.lines+1] = current
    gag_line()
    self:touch_capture()
end

function M:install()
    U.clear_triggers(self)
    U.clear_aliases(self)

    self.alias_ids[#self.alias_ids+1] = tempAlias([[^kamienie$]], function()
        M:start_capture("overview", "kamienie")
    end)
    self.alias_ids[#self.alias_ids+1] = tempAlias([[^kamienie\s+(.+)$]], function()
        M:start_capture("attribute", "kamienie " .. matches[2])
    end)
    self.alias_ids[#self.alias_ids+1] = tempAlias([[^kamien\s+(.+)$]], function()
        local arg = trim(matches[2])
        if arg:match("^porzuc%s+") then send("kamien " .. arg, false); return end
        M:start_capture("detail", "kamien " .. arg)
    end)

    -- Wstepna wersja: podczas aktywnego capture przechwytujemy odpowiedz tekstowa
    -- do chwili krotkiej ciszy. Poza capture trigger niczego nie zmienia.
    self.trigger_ids[#self.trigger_ids+1] = tempRegexTrigger([[^.*$]], function()
        if M.capture then M:capture_line() end
    end)
end

M:install()
return M
