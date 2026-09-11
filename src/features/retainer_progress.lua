-- ChimeraVIP / Retainer Progress
-- Zwarte karty poziomu wyszkolenia oraz listy pacholkow.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
C.retainer_progress = C.retainer_progress or {}
chimera_overlay.retainer_progress = C.retainer_progress
local R = C.retainer_progress

R.trigger_ids = R.trigger_ids or {}
R.capture = nil
R.capture_timer = nil
R.roster = nil
R.roster_timer = nil
R.capture_timeout = 2.0
R.roster_timeout = 3.0

local colors = U.palette
local normalize = U.normalize
local fmt_int = U.format_int
local gag_line = U.gag_line
local pad = U.pad_right

local function reset_capture()
    if R.capture_timer then pcall(killTimer, R.capture_timer) end
    R.capture_timer = nil
    R.capture = nil
end

local function touch_capture()
    if R.capture_timer then pcall(killTimer, R.capture_timer) end
    R.capture_timer = tempTimer(R.capture_timeout, function()
        R.capture_timer = nil
        R.capture = nil
    end)
end

local function reset_roster()
    if R.roster_timer then pcall(killTimer, R.roster_timer) end
    R.roster_timer = nil
    R.roster = nil
end

local function touch_roster()
    if R.roster_timer then pcall(killTimer, R.roster_timer) end
    R.roster_timer = tempTimer(R.roster_timeout, function()
        R.roster_timer = nil
        R.roster = nil
    end)
end

local function display_role(role)
    return tostring(role or ""):gsub("_", " ")
end

function R:show_card()
    local c = self.capture
    if not c or not c.name or not c.role or not c.level or not c.total or not c.since_call or not c.to_next then
        return false
    end

    local P = colors()
    local width = 55
    local left = normalize(c.name):upper() .. "  [" .. normalize(c.role):upper() .. "]"
    local right = "POZIOM " .. tostring(c.level)
    local gap = math.max(1, width - U.text_width(left) - U.text_width(right))

    hecho("\n\n" .. P.lavender .. left .. P.text_muted .. string.rep(" ", gap) .. P.peach .. right)
    hecho("\n" .. P.separator .. "-------------------------------------------------------")
    hecho("\n  " .. P.text_muted .. string.format("%-27s", "Do nastepnej rangi:")
        .. P.yellow .. fmt_int(c.to_next) .. " XP")
    hecho("\n  " .. P.text_muted .. string.format("%-27s", "Zdobyte od wezwania:")
        .. P.mint .. "+" .. fmt_int(c.since_call) .. " XP")
    hecho("\n  " .. P.text_muted .. string.format("%-27s", "Laczne doswiadczenie:")
        .. P.text .. fmt_int(c.total) .. " XP")
    hecho("\n" .. P.separator .. "-------------------------------------------------------\n")

    return true
end

function R:start(name, role, level, total)
    reset_capture()
    self.capture = {
        name = name,
        role = role,
        level = tonumber(level),
        total = tonumber(total),
    }
    gag_line()
    touch_capture()
end

function R:start_roster()
    reset_roster()
    self.roster = {entries={}}
    gag_line()
    touch_roster()
end

function R:add_roster_entry(index, name, role, level, status, obedience)
    if not self.roster then return false end
    self.roster.entries[#self.roster.entries + 1] = {
        index = tonumber(index) or (#self.roster.entries + 1),
        name = tostring(name or ""),
        role = display_role(role),
        level = tonumber(level) or 0,
        status = normalize(status),
        obedience = tonumber(obedience) or 0,
    }
    gag_line()
    touch_roster()
    return true
end

function R:show_roster(limit_text, charisma)
    local roster = self.roster
    if not roster or #roster.entries == 0 then return false end

    local P = colors()
    charisma = tonumber(charisma) or 0
    limit_text = tostring(limit_text or ""):gsub("^mozesz prowadzic%s+", "")

    local active_count, active_obedience = 0, 0
    for _, entry in ipairs(roster.entries) do
        if entry.status == "przy tobie" then
            active_count = active_count + 1
            active_obedience = active_obedience + entry.obedience
        end
    end

    hecho("\n\n" .. P.lavender .. "PACHOLKOWIE")
    hecho("\n" .. P.separator .. "------------------------------------------------------------------------")
    hecho("\n" .. P.text_muted
        .. "  " .. pad("#", 3)
        .. pad("IMIE", 12)
        .. pad("PROFESJA", 19)
        .. pad("POZ", 6)
        .. pad("POSLUCH", 9)
        .. "STATUS")

    for _, entry in ipairs(roster.entries) do
        local active = entry.status == "przy tobie"
        local status_text = active and "PRZY TOBIE" or (entry.status == "czeka na wezwanie" and "czeka" or entry.status)
        local row_color = active and P.mint or P.text
        hecho("\n" .. row_color
            .. "  " .. pad(tostring(entry.index), 3)
            .. pad(entry.name, 12)
            .. pad(entry.role, 19)
            .. P.peach .. pad(tostring(entry.level), 6)
            .. P.yellow .. pad(tostring(entry.obedience), 9)
            .. (active and P.mint or P.text_muted) .. status_text)
    end

    hecho("\n" .. P.separator .. "------------------------------------------------------------------------")
    hecho("\n  " .. P.text_muted .. "Charyzma: " .. P.lavender .. fmt_int(charisma)
        .. P.text_muted .. "  |  aktywnych: " .. P.mint .. tostring(active_count)
        .. P.text_muted .. "  |  posluch: " .. P.yellow .. fmt_int(active_obedience) .. "/" .. fmt_int(charisma))
    if limit_text ~= "" then
        hecho("\n  " .. P.text_muted .. "Limit: " .. P.text .. limit_text)
    end
    hecho("\n" .. P.separator .. "------------------------------------------------------------------------\n")

    return true
end

function R:install()
    U.clear_triggers(self)
    reset_capture()
    reset_roster()

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^(.+) sluzy ci jako (.+), poziom wyszkolenia (\d+), zebrane doswiadczenie: (\d+)\.\s*$]],
        function()
            R:start(matches[2], matches[3], matches[4], matches[5])
        end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Zebrane doswiadczenie rozwija pacholka automatycznie w walce\.\s*$]],
        function()
            if not R.capture then return end
            gag_line()
            touch_capture()
        end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Od poczatku wspolpracy .* (\d+) punktow doswiadczenia\.\s*$]],
        function()
            if not R.capture then return end
            local value = tonumber(matches[2])
            if value then R.capture.total = value end
            gag_line()
            touch_capture()
        end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Od ostatniego wezwania .* (\d+) punktow doswiadczenia\.\s*$]],
        function()
            if not R.capture then return end
            R.capture.since_call = tonumber(matches[2])
            gag_line()
            touch_capture()
        end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Do nastepnej rangi brakuje .* (\d+) doswiadczenia\.\s*$]],
        function()
            if not R.capture then return end
            R.capture.to_next = tonumber(matches[2])
            gag_line()
            local shown = R:show_card()
            if shown then reset_capture() else touch_capture() end
        end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Twoi pacholkowie:\s*$]],
        function() R:start_roster() end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^\s*(\d+)\.\s+(\S+)\s+(\S+)\s+poziom\s+(\d+)\s+(.+?)\s+\(wymaga posluchu\s+(\d+)\)\s*$]],
        function()
            if not R.roster then return end
            R:add_roster_entry(matches[2], matches[3], matches[4], matches[5], matches[6], matches[7])
        end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Limit liczby pacholkow: (.+?); twoja charyzma to (\d+)\. Limit liczby i limit posluchu sa osobne; wymagania z wpisow sumuja sie\.\s*$]],
        function()
            if not R.roster then return end
            gag_line()
            local shown = R:show_roster(matches[2], matches[3])
            if shown then reset_roster() else touch_roster() end
        end
    )
end

R:install()
return R
