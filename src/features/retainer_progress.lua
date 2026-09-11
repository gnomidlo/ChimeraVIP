-- ChimeraVIP / Retainer Progress
-- Zwarta karta poziomu wyszkolenia pacholka.

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
R.capture_timeout = 2.0

local colors = U.palette
local normalize = U.normalize
local fmt_int = U.format_int
local gag_line = U.gag_line

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

function R:install()
    U.clear_triggers(self)
    reset_capture()

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
end

R:install()
return R
