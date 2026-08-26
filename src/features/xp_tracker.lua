-- ChimeraVIP / XP tracker
-- Session efficiency tracker for Chimera kill messages.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util

C.xp_tracker = C.xp_tracker or {}
chimera_overlay.xp_tracker = C.xp_tracker
local XP = C.xp_tracker

XP.active_timeout = 120
XP.rolling_window = 600
XP.min_rate_seconds = 10
XP.trigger_ids = XP.trigger_ids or {}
XP.alias_ids = XP.alias_ids or {}

local data_dir = getMudletHomeDir() .. "/ChimeraVIP-data"
XP.data_file = data_dir .. "/xp_mobs.lua"
XP.legacy_data_file = getMudletHomeDir() .. "/chimera_xp_mobs.lua"

local function get_colors()
    if chimera_overlay.pastel_ui and chimera_overlay.pastel_ui.colors then
        return chimera_overlay.pastel_ui.colors
    end
    return {
        text = "#D8DCE6", text_muted = "#AEB6C5", rose = "#F0A8B8",
        mint = "#A8DCC2", blue = "#AFCBF4", lavender = "#C7B9E8",
        peach = "#F2C4A0", yellow = "#EFD8A6", separator = "#2B303C",
    }
end

XP.colors = get_colors()

-- Hot reload cleanup.
for _, id in ipairs(XP.trigger_ids) do pcall(killTrigger, id) end
for _, id in ipairs(XP.alias_ids) do pcall(killAlias, id) end
XP.trigger_ids = {}
XP.alias_ids = {}

-- Session intentionally survives module reload, but not a Mudlet restart.
XP.session = XP.session or {
    started_at = nil,
    last_kill_at = nil,
    active_seconds = 0,
    total_xp = 0,
    kills = 0,
    own_kills = 0,
    group_kills = 0,
    own_xp = 0,
    group_xp = 0,
    events = {},
}
XP.session.own_xp = XP.session.own_xp or 0
XP.session.group_xp = XP.session.group_xp or 0

local function trim(text)
    return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalize(text)
    return string.lower(trim(text):gsub("%s+", " "))
end

local function ends_with(text, suffix)
    return suffix ~= "" and #suffix <= #text and text:sub(-#suffix) == suffix
end

local function format_integer(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    local result = ""
    while #text > 3 do
        result = " " .. text:sub(-3) .. result
        text = text:sub(1, -4)
    end
    return text .. result
end

local function format_time(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if hours > 0 then return string.format("%dh %02dm", hours, minutes) end
    if minutes > 0 then return string.format("%dm %02ds", minutes, secs) end
    return string.format("%ds", secs)
end

local function calculate_rate(amount, seconds)
    if not seconds or seconds < XP.min_rate_seconds then return nil end
    return amount / seconds * 3600
end

local function format_rate(value)
    if not value then return "..." end
    if value >= 1000000 then return string.format("%.2fm/h", value / 1000000) end
    if value >= 1000 then return string.format("%.1fk/h", value / 1000) end
    return string.format("%.0f/h", value)
end

local function out(text, color)
    local Cc = XP.colors
    hecho("\n" .. (color or Cc.text_muted) .. tostring(text))
end

-- Rules ---------------------------------------------------------------------
XP.rules = XP.rules or {}

function XP:save_rules()
    if U and U.ensure_dir then U.ensure_dir(data_dir) end
    local ok, err = pcall(table.save, self.data_file, self.rules)
    if not ok then
        out("[XP] Nie udalo sie zapisac regul mobow: " .. tostring(err), self.colors.rose)
        return false
    end
    return true
end

function XP:load_rules()
    self.rules = {}
    if U and U.ensure_dir then U.ensure_dir(data_dir) end

    local source = nil
    if io.exists(self.data_file) then
        source = self.data_file
    elseif io.exists(self.legacy_data_file) then
        source = self.legacy_data_file
    end

    if not source then return end

    local ok, err = pcall(table.load, source, self.rules)
    if not ok then
        out("[XP] Nie udalo sie wczytac regul mobow: " .. tostring(err), self.colors.rose)
        self.rules = {}
        return
    end

    -- One-time migration from the pre-repository tracker path.
    if source == self.legacy_data_file then
        if self:save_rules() then
            out("[XP] Przeniesiono reguly mobow do ChimeraVIP-data.", self.colors.text_muted)
        end
    end
end

function XP:add_rule(canonical, suffix)
    canonical, suffix = normalize(canonical), normalize(suffix)
    if canonical == "" or suffix == "" then return false end
    for _, rule in ipairs(self.rules) do
        if rule.name == canonical and rule.match == suffix then return true end
    end
    table.insert(self.rules, { name = canonical, match = suffix })
    self:save_rules()
    return true
end

function XP:delete_rule(canonical)
    canonical = normalize(canonical)
    local removed = 0
    for i = #self.rules, 1, -1 do
        if self.rules[i].name == canonical then
            table.remove(self.rules, i)
            removed = removed + 1
        end
    end
    if removed > 0 then self:save_rules() end
    return removed
end

function XP:classify_mob(raw_name)
    local normalized = normalize(raw_name)
    local best_rule = nil
    for _, rule in ipairs(self.rules) do
        if ends_with(normalized, rule.match) and (not best_rule or #rule.match > #best_rule.match) then
            best_rule = rule
        end
    end
    if best_rule then return best_rule.name, "manual" end
    return normalized:match("([^%s]+)$") or normalized, "auto"
end

-- Timing and events ----------------------------------------------------------
function XP:get_active_seconds(now)
    local S = self.session
    if not S.last_kill_at then return 0 end
    now = now or os.time()
    local tail = math.min(math.max(0, now - S.last_kill_at), self.active_timeout)
    return S.active_seconds + tail
end

function XP:add_event(raw_mob, amount, killer, own)
    amount = tonumber(amount)
    if not amount then return end

    local now = os.time()
    local S = self.session
    if not S.started_at then S.started_at = now end

    if S.last_kill_at then
        local gap = now - S.last_kill_at
        S.active_seconds = S.active_seconds + math.min(math.max(gap, 0), self.active_timeout)
    end
    S.last_kill_at = now

    local mob, classification = self:classify_mob(raw_mob)
    table.insert(S.events, {
        time = now,
        xp = amount,
        mob_raw = trim(raw_mob),
        mob = mob,
        classification = classification,
        killer = killer,
        own = own == true,
    })

    S.total_xp = S.total_xp + amount
    S.kills = S.kills + 1
    if own then
        S.own_kills = S.own_kills + 1
        S.own_xp = S.own_xp + amount
    else
        S.group_kills = S.group_kills + 1
        S.group_xp = S.group_xp + amount
    end

    raiseEvent("chimeraVipXpGained", amount, mob, own == true)
end

function XP:get_window_stats(from_time, to_time)
    local amount, kills = 0, 0
    for _, event in ipairs(self.session.events) do
        if event.time >= from_time and event.time <= to_time then
            amount = amount + event.xp
            kills = kills + 1
        end
    end
    return amount, kills
end

function XP:get_current_rate(now)
    local S = self.session
    if not S.started_at then return nil end
    local from_time = math.max(S.started_at, now - self.rolling_window)
    local amount = self:get_window_stats(from_time, now)
    return calculate_rate(amount, now - from_time)
end

function XP:get_previous_rate(now)
    local S = self.session
    if not S.started_at then return nil end
    local from_time = math.max(S.started_at, now - self.rolling_window * 2)
    local to_time = now - self.rolling_window
    if to_time <= from_time then return nil end
    local amount = self:get_window_stats(from_time, to_time)
    return calculate_rate(amount, to_time - from_time)
end

function XP:get_trend(current, previous)
    if not current or not previous or previous <= 0 then return nil end
    return (current - previous) / previous * 100
end

-- Mob statistics -------------------------------------------------------------
function XP:get_mob_stats()
    local stats = {}
    for _, event in ipairs(self.session.events) do
        local key = event.mob
        stats[key] = stats[key] or {
            name = key, xp = 0, kills = 0,
            manual = event.classification == "manual",
            own_kills = 0, group_kills = 0,
        }
        local data = stats[key]
        data.xp = data.xp + event.xp
        data.kills = data.kills + 1
        if event.own then data.own_kills = data.own_kills + 1 else data.group_kills = data.group_kills + 1 end
        if event.classification == "manual" then data.manual = true end
    end

    local list = {}
    for _, data in pairs(stats) do
        data.average = data.xp / data.kills
        table.insert(list, data)
    end
    table.sort(list, function(a, b)
        if a.xp == b.xp then return a.kills > b.kills end
        return a.xp > b.xp
    end)
    return list
end

function XP:find_mob(name)
    name = normalize(name)
    for _, data in ipairs(self:get_mob_stats()) do
        if data.name == name then return data end
    end
    return nil
end

-- Views ---------------------------------------------------------------------
function XP:show_summary()
    local Cc, S = self.colors, self.session
    if S.kills == 0 then
        hecho("\n" .. Cc.text_muted .. "XP: " .. Cc.text .. "brak danych w tej sesji.")
        return
    end

    local now = os.time()
    local session_seconds = now - S.started_at
    local active_seconds = self:get_active_seconds(now)
    local session_rate = calculate_rate(S.total_xp, session_seconds)
    local active_rate = calculate_rate(S.total_xp, active_seconds)
    local current_rate = self:get_current_rate(now)
    local previous_rate = self:get_previous_rate(now)
    local trend = self:get_trend(current_rate, previous_rate)
    local average = S.total_xp / S.kills
    local trend_text = ""

    if trend then
        if trend >= 3 then trend_text = string.format("  %s↗ +%.1f%%", Cc.mint, trend)
        elseif trend <= -3 then trend_text = string.format("  %s↘ %.1f%%", Cc.rose, trend)
        else trend_text = string.format("  %s→ %.1f%%", Cc.text_muted, trend) end
    end

    local top = self:get_mob_stats()[1]
    local top_text = top and (top.name .. " (" .. format_integer(top.xp) .. " xp)") or "..."

    hecho(
        "\n\n" .. Cc.lavender .. "XP — SESJA\n" .. Cc.separator .. "------------------------------------------\n"
        .. Cc.text_muted .. "Czas       " .. Cc.text .. string.format("%12s", format_time(session_seconds)) .. "\n"
        .. Cc.text_muted .. "Aktywnie   " .. Cc.text .. string.format("%12s", format_time(active_seconds)) .. "\n\n"
        .. Cc.text_muted .. "Zdobyto    " .. Cc.peach .. string.format("%12s xp", format_integer(S.total_xp)) .. "\n"
        .. Cc.text_muted .. "Zabici     " .. Cc.text .. string.format("%12s", format_integer(S.kills)) .. "\n"
        .. Cc.text_muted .. "  ty       " .. Cc.text .. string.format("%6s", format_integer(S.own_kills))
        .. Cc.text_muted .. " / " .. Cc.peach .. format_integer(S.own_xp) .. " xp\n"
        .. Cc.text_muted .. "  druzyna  " .. Cc.text .. string.format("%6s", format_integer(S.group_kills))
        .. Cc.text_muted .. " / " .. Cc.peach .. format_integer(S.group_xp) .. " xp\n"
        .. Cc.text_muted .. "XP / kill  " .. Cc.text .. string.format("%12s", format_integer(average)) .. "\n"
        .. Cc.text_muted .. "Top mob    " .. Cc.mint .. top_text .. "\n\n"
        .. Cc.text_muted .. "TERAZ      " .. Cc.mint .. string.format("%12s", format_rate(current_rate)) .. trend_text .. "\n"
        .. Cc.text_muted .. "AKTYWNIE   " .. Cc.blue .. string.format("%12s", format_rate(active_rate)) .. "\n"
        .. Cc.text_muted .. "SESJA      " .. Cc.lavender .. string.format("%12s", format_rate(session_rate))
        .. "\n" .. Cc.separator .. "------------------------------------------"
    )
end

function XP:show_mobs()
    local Cc = self.colors
    local list = self:get_mob_stats()
    hecho("\n\n" .. Cc.lavender .. "XP — MOBY\n" .. Cc.separator .. "-------------------------------------------------------")
    if #list == 0 then hecho("\n" .. Cc.text_muted .. "Brak danych w tej sesji."); return end
    for _, data in ipairs(list) do
        local marker = data.manual and "*" or " "
        hecho(string.format("\n%s%s %-24s %s%4d  %s%9s xp  %s%6s/k", Cc.lavender, marker, data.name,
            Cc.text, data.kills, Cc.peach, format_integer(data.xp), Cc.text_muted, format_integer(data.average)))
    end
    hecho("\n" .. Cc.text_muted .. "* = klasyfikacja reczna")
end

function XP:show_mob(name)
    local Cc = self.colors
    local data = self:find_mob(name)
    if not data then
        hecho("\n" .. Cc.rose .. "[XP] Brak moba w tej sesji: " .. Cc.text .. trim(name))
        return
    end
    hecho("\n\n" .. Cc.lavender .. "XP — " .. string.upper(data.name)
        .. "\n" .. Cc.separator .. "------------------------------------------"
        .. "\n" .. Cc.text_muted .. "Zabicia    " .. Cc.text .. format_integer(data.kills)
        .. "\n" .. Cc.text_muted .. "  ty       " .. Cc.text .. format_integer(data.own_kills)
        .. "\n" .. Cc.text_muted .. "  druzyna  " .. Cc.text .. format_integer(data.group_kills)
        .. "\n" .. Cc.text_muted .. "XP razem   " .. Cc.peach .. format_integer(data.xp)
        .. "\n" .. Cc.text_muted .. "XP / kill  " .. Cc.text .. format_integer(data.average))
end

function XP:show_rules()
    local Cc = self.colors
    hecho("\n\n" .. Cc.lavender .. "XP — REGULY MOBOW\n" .. Cc.separator .. "------------------------------------------")
    if #self.rules == 0 then hecho("\n" .. Cc.text_muted .. "Brak regul recznych."); return end
    local copy = {}
    for _, rule in ipairs(self.rules) do table.insert(copy, rule) end
    table.sort(copy, function(a, b) return a.name == b.name and a.match < b.match or a.name < b.name end)
    for _, rule in ipairs(copy) do
        hecho("\n" .. Cc.mint .. rule.name .. Cc.text_muted .. "  <-  " .. Cc.text .. rule.match)
    end
end

function XP:show_last(count)
    count = math.max(1, math.min(100, tonumber(count) or 10))
    local Cc, events = self.colors, self.session.events
    hecho("\n\n" .. Cc.lavender .. "XP — OSTATNIE ZABICIA\n" .. Cc.separator .. "-------------------------------------------------------")
    if #events == 0 then hecho("\n" .. Cc.text_muted .. "Brak danych."); return end
    local first = math.max(1, #events - count + 1)
    for i = first, #events do
        local event = events[i]
        local marker = event.classification == "manual" and "*" or " "
        hecho("\n" .. Cc.text_muted .. os.date("%H:%M:%S", event.time) .. "  "
            .. Cc.peach .. "+" .. format_integer(event.xp) .. " xp  "
            .. Cc.text .. event.mob_raw .. Cc.text_muted .. "  ->  " .. Cc.mint .. marker .. event.mob)
    end
end

function XP:reset()
    self.session = {
        started_at = nil, last_kill_at = nil, active_seconds = 0, total_xp = 0,
        kills = 0, own_kills = 0, group_kills = 0, own_xp = 0, group_xp = 0, events = {},
    }
    hecho("\n" .. self.colors.mint .. "[XP] Sesja wyzerowana.")
end

function XP:show_help()
    local Cc = self.colors
    hecho("\n\n" .. Cc.lavender .. "XP — KOMENDY\n"
        .. Cc.text .. "/xp" .. Cc.text_muted .. "                    podsumowanie\n"
        .. Cc.text .. "/xp mobs" .. Cc.text_muted .. "               statystyki mobow\n"
        .. Cc.text .. "/xp mob " .. Cc.mint .. "nazwa" .. Cc.text_muted .. "           szczegoly moba\n"
        .. Cc.text .. "/xp last [N]" .. Cc.text_muted .. "           ostatnie N zabic (domyslnie 10)\n"
        .. Cc.text .. "/xp rules" .. Cc.text_muted .. "              reczne reguly\n"
        .. Cc.text .. "/xp add " .. Cc.mint .. "nazwa#forma" .. Cc.text_muted .. "    dodaj regule\n"
        .. Cc.text .. "/xp del " .. Cc.mint .. "nazwa" .. Cc.text_muted .. "          usun reguly\n"
        .. Cc.text .. "/xp reset" .. Cc.text_muted .. "              nowa sesja")
end

-- Triggers ------------------------------------------------------------------
table.insert(XP.trigger_ids, tempRegexTrigger([[^(Zabilas|Zabiles) (.+)\. \[(\d+)xp\]$]], function()
    XP:add_event(matches[3], matches[4], "TY", true)
end))

table.insert(XP.trigger_ids, tempRegexTrigger([[^(.+?) (zabil|zabila) (.+)\. \[(\d+)xp\]$]], function()
    XP:add_event(matches[4], matches[5], matches[2], false)
end))

-- Aliases -------------------------------------------------------------------
local function alias(pattern, fn)
    table.insert(XP.alias_ids, tempAlias(pattern, fn))
end

alias([[^/xp$]], function() XP:show_summary() end)
alias([[^/xp reset$]], function() XP:reset() end)
alias([[^/xp (?:mobs|moby)$]], function() XP:show_mobs() end)
alias([[^/xp last(?:\s+(\d+))?$]], function() XP:show_last(matches[2]) end)
alias([[^/xp mob (.+)$]], function() XP:show_mob(matches[2]) end)
alias([[^/xp (?:rules|reguly)$]], function() XP:show_rules() end)
alias([[^/xp add (.+)#(.+)$]], function()
    local canonical, suffix = trim(matches[2]), trim(matches[3])
    if XP:add_rule(canonical, suffix) then
        hecho("\n" .. XP.colors.mint .. "[XP] Dodano: " .. XP.colors.text .. canonical
            .. XP.colors.text_muted .. " <- " .. XP.colors.lavender .. suffix)
    end
end)
alias([[^/xp del (.+)$]], function()
    local canonical = trim(matches[2])
    local removed = XP:delete_rule(canonical)
    if removed > 0 then
        hecho("\n" .. XP.colors.mint .. "[XP] Usunieto " .. tostring(removed) .. " regul dla: " .. XP.colors.text .. canonical)
    else
        hecho("\n" .. XP.colors.rose .. "[XP] Nie znaleziono: " .. XP.colors.text .. canonical)
    end
end)
alias([[^/xp help$]], function() XP:show_help() end)

XP:load_rules()

return XP
