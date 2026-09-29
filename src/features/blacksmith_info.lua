-- ChimeraVIP / Blacksmith information
-- Collects the multi-line blacksmith appraisal and adds a compact summary.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
C.blacksmith_info = C.blacksmith_info or {}
chimera_overlay.blacksmith_info = C.blacksmith_info
local B = C.blacksmith_info

B.trigger_ids = B.trigger_ids or {}
B.capture = nil
B.timer = nil
B.timeout = 4

local trim = U.trim
local colors = U.palette

local function quality_from(description)
    local text = U.normalize(description)
    if text:find("niezrownanym kunsztem", 1, true) then return "wybitne" end
    if text:find("po mistrzowsku", 1, true) then return "perfekcyjne" end
    return nil
end

function B:touch()
    if self.timer then pcall(killTimer, self.timer) end
    self.timer = tempTimer(self.timeout, function()
        B.capture = nil
        B.timer = nil
    end)
end

function B:start(item, description, stamp_state, maker)
    self.capture = {
        item=trim(item), description=trim(description), quality=quality_from(description),
        stamp_state=trim(stamp_state), maker=trim(maker),
    }
    self:touch()
end

function B:on_condition(current, message, ceiling)
    if not self.capture then return end
    self.capture.condition = tonumber(current)
    self.capture.repair_message = trim(message)
    self.capture.repair_ceiling = tonumber(ceiling)
    self:touch()
end

function B:on_active(kind, stamp_state, remaining, refresh)
    if not self.capture then return end
    self.capture.active_kind = trim(kind)
    self.capture.active_stamp_state = trim(stamp_state)
    self.capture.remaining = trim(remaining)
    self.capture.refresh = trim(refresh)
    self:touch()
end

function B:on_options(kinds, pieces, piece_bonus, piece_duration, ingots, ingot_bonus, ingot_duration, work_time)
    if not self.capture then return end
    self.capture.options = trim(kinds)
    self.capture.pieces = tonumber(pieces)
    self.capture.piece_bonus = tonumber(piece_bonus)
    self.capture.piece_duration = trim(piece_duration)
    self.capture.ingots = tonumber(ingots)
    self.capture.ingot_bonus = tonumber(ingot_bonus)
    self.capture.ingot_duration = trim(ingot_duration)
    self.capture.work_time = trim(work_time)
    self:touch()
end

function B:on_salvage(amount, duration)
    if not self.capture then return end
    self.capture.salvage = tonumber(amount)
    self.capture.salvage_time = trim(duration)
    self:show()
    self.capture = nil
    if self.timer then pcall(killTimer, self.timer) end
    self.timer = nil
end

function B:show()
    local c = self.capture
    if not c then return end
    local P = colors()
    hecho("\n" .. P.separator .. "-------------------------------------------------------")
    hecho("\n" .. P.lavender .. "KOWAL" .. P.text_muted .. " - " .. P.text .. (c.item ~= "" and c.item or "przedmiot"))

    local condition = c.condition and (tostring(c.condition) .. "%") or "-"
    local ceiling = c.repair_ceiling and (tostring(c.repair_ceiling) .. "%") or "-"
    local repair = c.repair_message ~= "" and c.repair_message or "brak danych"
    hecho("\n  " .. P.text_muted .. "STAN: " .. P.mint .. condition
        .. P.text_muted .. "  |  pulap naprawy: " .. P.blue .. ceiling
        .. P.text_muted .. "  |  " .. P.text .. repair)

    if c.active_kind then
        local quality = c.quality and ("  |  jakosc: " .. P.lavender .. c.quality) or ""
        hecho("\n  " .. P.text_muted .. "AKTYWNE: " .. P.mint .. c.active_kind
            .. quality .. P.text_muted .. "  |  punca: " .. P.text .. c.maker
            .. P.text_muted .. "/" .. P.yellow .. c.active_stamp_state
            .. P.text_muted .. "  |  pozostalo: " .. P.peach .. "~" .. c.remaining)
    end
    if c.options then
        hecho("\n  " .. P.text_muted .. "MOZLIWE: " .. P.text .. c.options
            .. P.text_muted .. "  |  praca: " .. P.peach .. "~" .. c.work_time)
        hecho("\n    " .. P.blue .. string.format("%-10s", "KAWALKI:") .. P.text .. tostring(c.pieces)
            .. P.text_muted .. " -> " .. P.mint .. string.format("%+d", c.piece_bonus or 0)
            .. P.text_muted .. " / " .. P.text .. c.piece_duration)
        hecho("\n    " .. P.lavender .. string.format("%-10s", "SZTABKI:") .. P.text .. tostring(c.ingots)
            .. P.text_muted .. " -> " .. P.mint .. string.format("%+d", c.ingot_bonus or 0)
            .. P.text_muted .. " / " .. P.text .. c.ingot_duration)
    end
    if c.salvage then
        hecho("\n  " .. P.text_muted .. "ROZBIORKA: " .. P.mint .. tostring(c.salvage) .. " kawalki"
            .. P.text_muted .. "  |  czas: " .. P.peach .. "~" .. c.salvage_time)
    end
    hecho("\n" .. P.separator .. "-------------------------------------------------------\n")
end

function B:highlight_event(label, color_key)
    if type(selectString) ~= "function" then return end
    local found = selectString(label, 1)
    if not found or found < 0 then return end
    local r, g, b = U.hex_to_rgb(colors()[color_key or "lavender"])
    if r and type(setFgColor) == "function" then pcall(setFgColor, r, g, b) end
    if type(setBold) == "function" then pcall(setBold, true) end
    if type(resetFormat) == "function" then pcall(resetFormat) end
end

function B:install()
    U.clear_triggers(self)
    self.trigger_ids[#self.trigger_ids+1] = tempRegexTrigger(
        [[^(.+?) zostal(?:a|o|y)? (.+?) i oznaczon(?:y|a|e) (.+?) kowalska punca (.+?)\.$]],
        function() B:start(matches[2], matches[3], matches[4], matches[5]) end)
    self.trigger_ids[#self.trigger_ids+1] = tempRegexTrigger(
        [[^Jako kowal oceniasz (?:jego|jej|ich) stan na (\d+)% pierwotnego\. (.+?) \(twoj pulap to (\d+)%\)\.$]],
        function() B:on_condition(matches[2], matches[3], matches[4]) end)
    self.trigger_ids[#self.trigger_ids+1] = tempRegexTrigger(
        [[^Nosi kowalskie wzmocnienie \((.+?), punca (.+?), jeszcze okolo (.+?)\); (.+?)\.$]],
        function() B:on_active(matches[2], matches[3], matches[4], matches[5]) end)
    self.trigger_ids[#self.trigger_ids+1] = tempRegexTrigger(
        [[^Mozesz (?:go|ja|je) wzmocnic \((.+?)\): koszt (\d+) kawalki? metalu \(([+-]\d+), na (.+?)\) albo (\d+) sztabki? \(([+-]\d+), na (.+?)\), praca okolo (.+?)\.$]],
        function() B:on_options(matches[2], matches[3], matches[4], matches[5], matches[6], matches[7], matches[8], matches[9]) end)
    self.trigger_ids[#self.trigger_ids+1] = tempRegexTrigger(
        [[^Rozbiorka dalaby (\d+) kawalki? metalu i trwalaby okolo (.+?)\.$]],
        function() B:on_salvage(matches[2], matches[3]) end)

    for _, event in ipairs({
        {"Perfekcyjne wykonanie!", "lavender"}, {"Wybitne wykonanie!", "lavender"},
        {"Krytyczna rozbiorka!", "mint"}, {"Zaoszczedzony material:", "yellow"},
    }) do
        local label, color_key = event[1], event[2]
        self.trigger_ids[#self.trigger_ids+1] = tempRegexTrigger(U.pcre_escape(label), function()
            B:highlight_event(label, color_key)
        end)
    end
end

B:install()
return B
