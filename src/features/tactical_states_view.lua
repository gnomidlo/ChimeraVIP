-- ChimeraVIP / tactical states view refinements
-- Owns rendering of the official states window, applies VIP font settings
-- and preserves the most useful tail of long entity names.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
local T = C.tactical_states

if not T then
    error("tactical_states musi byc zaladowany przed tactical_states_view")
end

T.view_handlers = T.view_handlers or {}
T.default_columns = T.default_columns or 72

local base_render = T.render
local base_row_text = T.row_text
local base_schedule_render = T.schedule_render

local function text_width(value)
    if U and U.text_width then return U.text_width(value) end
    return #tostring(value or "")
end

local function fit_tail_words(value, width)
    local text = tostring(value or "")
    width = math.max(1, math.floor(tonumber(width) or 1))
    if text_width(text) <= width then return text end
    if width <= 1 then return "…" end

    local words = {}
    for word in text:gmatch("%S+") do words[#words + 1] = word end

    local kept = {}
    local used = 2 -- ellipsis + space
    for i = #words, 1, -1 do
        local word = words[i]
        local extra = text_width(word) + (#kept > 0 and 1 or 0)
        if used + extra > width then break end
        table.insert(kept, 1, word)
        used = used + extra
    end

    if #kept > 0 then return "… " .. table.concat(kept, " ") end

    -- MUD entity names are ASCII in normal play; keep the tail even when
    -- the last single word alone is wider than the available space.
    local keep = math.max(1, width - 1)
    return "…" .. text:sub(-keep)
end

local function marks_for(ids, snapshot)
    local out, seen = {}, {}
    for _, id in ipairs(ids or {}) do
        local mark = snapshot and snapshot.marks and snapshot.marks[id]
        if mark and not seen[mark] then
            seen[mark] = true
            out[#out + 1] = tostring(mark)
        end
    end
    table.sort(out, function(a, b)
        local an, bn = tonumber(a), tonumber(b)
        if an and bn then return an < bn end
        if an then return true end
        if bn then return false end
        return a < b
    end)
    return out
end

function T:relation_plain(id, snapshot)
    local parts = {}
    local outgoing = marks_for(snapshot and snapshot.outgoing and snapshot.outgoing[id] or {}, snapshot)
    local incoming = marks_for(snapshot and snapshot.incoming and snapshot.incoming[id] or {}, snapshot)
    if #outgoing > 0 then parts[#parts + 1] = " ->[" .. table.concat(outgoing, ",") .. "]" end
    if #incoming > 0 then parts[#parts + 1] = " <-[" .. table.concat(incoming, ",") .. "]" end
    return table.concat(parts)
end

function T:window_columns()
    local name = self:window_name()
    if type(getColumnCount) == "function" then
        local ok, columns = pcall(getColumnCount, name)
        columns = ok and tonumber(columns) or nil
        if columns and columns > 20 then return math.floor(columns) end
    end
    return self.default_columns
end

function T:font_size()
    local size = C.settings and C.settings.get and C.settings:get("ui.states_font_size", 10) or 10
    size = math.floor((tonumber(size) or 10) + 0.5)
    return math.max(7, math.min(14, size))
end

function T:apply_font()
    local name = self:window_name()
    local size = self:font_size()
    if scripts and scripts.ui then scripts.ui.states_font_size = size end
    if type(setFontSize) == "function" then pcall(setFontSize, name, size) end
    return size
end

function T:install_official_renderer_guard()
    local team = rawget(_G, "ateam")
    if type(team) ~= "table" or type(team.print_status) ~= "function" then return false end

    if not self._official_print_wrapper then
        self._official_print_wrapper = function(...)
            T:schedule_render(0)
            return true
        end
    end

    if team.print_status ~= self._official_print_wrapper then
        self._official_print_status = team.print_status
        team.print_status = self._official_print_wrapper
    end
    return true
end

function T:row_text(row, snapshot, category, palette)
    local original_name = row.name
    local columns = self:window_columns()
    local relation = self:relation_plain(row.id, snapshot)
    local mark_width = text_width(tostring(row.mark or "?"))

    -- Visible fixed prefix:
    -- flag(2) + hp bar(10) + space + percent(4) + space + [mark] + space.
    local prefix_width = 2 + 10 + 1 + 4 + 1 + mark_width + 2 + 1
    local available = columns - prefix_width - text_width(relation) - 1
    available = math.max(7, available)

    row.name = fit_tail_words(original_name or row.id, available)
    local result = base_row_text(self, row, snapshot, category, palette)
    row.name = original_name
    return result
end

function T:render(force)
    self:install_official_renderer_guard()
    self:ensure_window()
    self:apply_font()
    return base_render(self, force)
end

function T:schedule_render(delay, force)
    self:install_official_renderer_guard()
    return base_schedule_render(self, delay, force)
end

if C.settings and C.settings.setting_defs and C.settings.setting_defs.ui_states_font_size then
    C.settings.setting_defs.ui_states_font_size.title = "Rozmiar tekstu Kondycji"
    C.settings.setting_defs.ui_states_font_size.description = "Rozmiar tekstu taktycznego okna Kondycje (7-14)."
end

U.replace_handler(T.view_handlers, "settings", "chimeraVipSettingsChanged", function(_, path)
    if path == "ui.states_font_size" or path == "ui_states_font_size" then
        T:apply_font()
        T.last_frame = nil
        T:schedule_render(0.02, true)
    end
end)

U.replace_handler(T.view_handlers, "scripts_loaded", "scriptsLoaded", function()
    tempTimer(0, function()
        T:install_official_renderer_guard()
        T:apply_font()
        T:schedule_render(0.02, true)
    end)
end)

U.replace_handler(T.view_handlers, "ui_ready", "uiReady", function()
    tempTimer(0, function()
        T:install_official_renderer_guard()
        T:apply_font()
        T:schedule_render(0.02, true)
    end)
end)

T:install_official_renderer_guard()
tempTimer(0, function()
    T:apply_font()
    T:schedule_render(0.02, true)
end)

return T
