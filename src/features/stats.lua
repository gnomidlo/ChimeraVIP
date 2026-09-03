-- ChimeraVIP / Cechy i progres postaci
-- Formatuje wynik komendy cechy, pokazuje delty snapshotow i przechowuje historie rozwoju.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
C.stats = C.stats or {}
chimera_overlay.stats = C.stats
local ST = C.stats

ST.trigger_ids = ST.trigger_ids or {}
ST.alias_ids = ST.alias_ids or {}
ST.handlers = ST.handlers or {}
ST.current = ST.current or {}
ST.last = ST.last or nil
ST.header = ST.header or nil
ST.previous_snapshot = nil
ST.active_record = nil
ST.data = ST.data or {characters={}}
ST.pending_xp = ST.pending_xp or 0
ST.save_timer = ST.save_timer or nil
ST.max_history = 100

local data_dir = getMudletHomeDir() .. "/ChimeraVIP-data"
-- Zachowujemy stara nazwe pliku, aby dotychczasowa historia /progres zostala przejeta bez migracji.
ST.data_file = data_dir .. "/progression.lua"

local function colors()
    if chimera_overlay.pastel_ui and chimera_overlay.pastel_ui.colors then
        return chimera_overlay.pastel_ui.colors
    end
    return {
        text="#D8DCE6", text_muted="#AEB6C5", rose="#F0A8B8", mint="#A8DCC2",
        blue="#AFCBF4", lavender="#C7B9E8", peach="#F2C4A0", yellow="#EFD8A6", separator="#2B303C",
    }
end

local function trim(text)
    return tostring(text or ""):gsub("^[ \t]+", ""):gsub("[ \t]+$", "")
end

local function fmt_int(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    local result = ""
    while #text > 3 do
        result = " " .. text:sub(-3) .. result
        text = text:sub(1, -4)
    end
    return text .. result
end

local function copy_table(source)
    local out = {}
    for k, v in pairs(source or {}) do
        if type(v) == "table" then
            local child = {}
            for ck, cv in pairs(v) do child[ck] = cv end
            out[k] = child
        else
            out[k] = v
        end
    end
    return out
end

local function safe_key(name)
    return tostring(name or ""):lower()
        :gsub("^%s+", ""):gsub("%s+$", "")
        :gsub("%s+", "_"):gsub("[^%w_%-]", "_"):gsub("_+", "_")
end

local function delta_markup(value)
    value = tonumber(value) or 0
    local P = colors()
    if value > 0 then return P.mint .. string.format("%+d", value) end
    if value < 0 then return P.rose .. string.format("%+d", value) end
    return ""
end

local function diff_text(diff)
    local P = colors()
    local order = {"Sil", "Zr", "Wt", "Int", "Md", "Odw"}
    local parts = {}
    for _, key in ipairs(order) do
        local value = diff and tonumber(diff[key]) or 0
        if value ~= 0 then
            parts[#parts + 1] = delta_markup(value):gsub("^", P.text .. key .. " ")
        end
    end
    return #parts > 0 and table.concat(parts, P.text_muted .. "  ") or (P.text_muted .. "brak zmian")
end

function ST:get_character()
    local char = gmcp and gmcp.Char and gmcp.Char.Name
    if type(char) ~= "table" then return nil, nil end
    local display = char.fullname or char.name
    if not display or tostring(display) == "" then return nil, nil end
    display = tostring(display)
    return safe_key(display), display
end

function ST:get_record(create)
    local key, display = self:get_character()
    if not key or key == "" then return nil, nil end
    self.data.characters = self.data.characters or {}
    local record = self.data.characters[key]
    if not record and create then
        record = {
            key=key, display_name=display, tracked_xp=0, xp_since_change=0,
            baseline=nil, last_observed=nil, history={},
        }
        self.data.characters[key] = record
    end
    if record and display and display ~= "" then record.display_name = display end
    return record, key
end

function ST:load_data()
    if U and U.ensure_dir then U.ensure_dir(data_dir) end
    local loaded = {}
    if io.exists and io.exists(self.data_file) then
        local ok, err = pcall(table.load, self.data_file, loaded)
        if not ok then
            hecho("\n" .. colors().rose .. "[CECHY] Nie udalo sie wczytac historii: " .. tostring(err) .. "\n")
            loaded = {}
        end
    end
    loaded.characters = loaded.characters or {}
    self.data = loaded
end

function ST:save_data()
    if U and U.ensure_dir then U.ensure_dir(data_dir) end
    local ok, err = pcall(table.save, self.data_file, self.data)
    if not ok then
        hecho("\n" .. colors().rose .. "[CECHY] Nie udalo sie zapisac historii: " .. tostring(err) .. "\n")
        return false
    end
    return true
end

function ST:schedule_save()
    if self.save_timer then pcall(killTimer, self.save_timer) end
    self.save_timer = tempTimer(1.5, function()
        ST.save_timer = nil
        ST:save_data()
    end)
end

function ST:flush_pending_xp()
    if self.pending_xp <= 0 then return end
    local record = self:get_record(true)
    if not record then return end
    record.tracked_xp = (record.tracked_xp or 0) + self.pending_xp
    record.xp_since_change = (record.xp_since_change or 0) + self.pending_xp
    self.pending_xp = 0
    self:schedule_save()
end

function ST:on_xp(amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return end
    local record = self:get_record(true)
    if not record then
        self.pending_xp = self.pending_xp + amount
        return
    end
    self:flush_pending_xp()
    record.tracked_xp = (record.tracked_xp or 0) + amount
    record.xp_since_change = (record.xp_since_change or 0) + amount
    self:schedule_save()
end

function ST:stat_diff(old_snapshot, new_snapshot)
    local keys = {"Sil", "Zr", "Wt", "Int", "Md", "Odw"}
    local diff, changed = {}, false
    local old_stats = old_snapshot and old_snapshot.stats or {}
    local new_stats = new_snapshot and new_snapshot.stats or {}
    for _, key in ipairs(keys) do
        local delta = (tonumber(new_stats[key]) or 0) - (tonumber(old_stats[key]) or 0)
        if delta ~= 0 then diff[key] = delta; changed = true end
    end
    return changed, diff
end

function ST:append_history(record, entry)
    record.history = record.history or {}
    table.insert(record.history, entry)
    while #record.history > self.max_history do table.remove(record.history, 1) end
end

function ST:last_change(record)
    for i = #(record and record.history or {}), 1, -1 do
        local entry = record.history[i]
        if entry.kind == "change" then return entry end
    end
    return nil
end

function ST:update_progress(snapshot)
    local record = self:get_record(true)
    if not record then return nil, "no_character" end
    self:flush_pending_xp()

    local current = copy_table(snapshot)
    current.character = record.display_name

    if not record.last_observed then
        record.baseline = copy_table(current)
        record.last_observed = copy_table(current)
        record.xp_since_change = 0
        self:append_history(record, {
            time=current.captured_at or os.time(), kind="baseline", snapshot=copy_table(current), diff={}, xp_since_previous=0,
        })
        self:schedule_save()
        return record, "baseline", {}, 0
    end

    local changed, diff = self:stat_diff(record.last_observed, current)
    record.last_observed = copy_table(current)

    if not changed then
        self:schedule_save()
        return record, "observed", {}, 0
    end

    local spent = record.xp_since_change or 0
    self:append_history(record, {
        time=current.captured_at or os.time(), kind="change", snapshot=copy_table(current), diff=diff, xp_since_previous=spent,
    })
    record.baseline = copy_table(current)
    record.xp_since_change = 0
    self:schedule_save()
    return record, "change", diff, spent
end

function ST:reset_current()
    self.current = {}
    self.header = nil
    local record = self:get_record(false)
    self.active_record = record
    self.previous_snapshot = record and record.last_observed and copy_table(record.last_observed) or nil
end

function ST:build_snapshot()
    local fiz = (self.current.Sil or 0) + (self.current.Zr or 0) + (self.current.Wt or 0)
    local ment = (self.current.Int or 0) + (self.current.Md or 0)
    local odw = self.current.Odw or 0
    self.last = {
        header=self.header, stats=copy_table(self.current), physical=fiz, mental=ment,
        courage=odw, total=fiz + ment + odw, captured_at=os.time(),
    }
    return self.last
end

function ST:show_progress_footer(record, event_kind, diff, spent)
    local P = colors()
    if not record then
        hecho("\n  " .. P.text_muted .. "Historia: brak danych GMCP postaci")
        return
    end

    hecho("\n  " .. P.text_muted .. "XP od zmiany " .. P.mint .. fmt_int(record.xp_since_change or 0)
        .. P.text_muted .. "  |  sledzone " .. P.peach .. fmt_int(record.tracked_xp or 0))

    local last_change = self:last_change(record)
    if event_kind == "change" then
        hecho("\n  " .. P.text_muted .. "Nowa zmiana  " .. diff_text(diff)
            .. P.text_muted .. "  |  XP " .. P.peach .. fmt_int(spent or 0))
    elseif last_change then
        hecho("\n  " .. P.text_muted .. "Ostatnia     " .. diff_text(last_change.diff)
            .. P.text_muted .. "  |  " .. P.text .. os.date("%Y-%m-%d %H:%M", last_change.time)
            .. P.text_muted .. "  |  XP " .. P.peach .. fmt_int(last_change.xp_since_previous or 0))
    end
end

function ST:show_history(count)
    count = math.max(1, math.min(50, tonumber(count) or 10))
    local P = colors()
    local record = self:get_record(false)
    local _, display = self:get_character()

    if not display then
        hecho("\n" .. P.rose .. "[CECHY] Brak danych GMCP postaci.\n")
        return
    end
    if not record then
        hecho("\n" .. P.text_muted .. "[CECHY] Brak historii dla " .. display .. ".\n")
        return
    end

    local changes = {}
    for _, entry in ipairs(record.history or {}) do
        if entry.kind == "change" then changes[#changes + 1] = entry end
    end

    hecho("\n\n" .. P.lavender .. "CECHY - HISTORIA - " .. tostring(record.display_name or display)
        .. "\n" .. P.separator .. "-------------------------------------------------------")

    if #changes == 0 then
        hecho("\n" .. P.text_muted .. "Brak zarejestrowanych zmian cech.\n")
        return
    end

    local first = math.max(1, #changes - count + 1)
    for i = first, #changes do
        local entry = changes[i]
        hecho("\n" .. P.text_muted .. os.date("%Y-%m-%d %H:%M", entry.time)
            .. "  " .. diff_text(entry.diff)
            .. P.text_muted .. "  |  XP " .. P.peach .. fmt_int(entry.xp_since_previous or 0))
    end
    hecho("\n")
end

-- Hot reload: usuwamy nasze tymczasowe triggery i aliasy.
for _, id in ipairs(ST.trigger_ids) do pcall(killTrigger, id) end
for _, id in ipairs(ST.alias_ids) do pcall(killAlias, id) end
ST.trigger_ids, ST.alias_ids = {}, {}

-- Migracja 0.94: wyczysc handlery i aliasy starego modulu /progres z biezacej sesji.
if C.progression then
    for _, id in ipairs(C.progression.alias_ids or {}) do pcall(killAlias, id) end
    for _, id in pairs(C.progression.handlers or {}) do pcall(killAnonymousEventHandler, id) end
end
C.progression = nil
chimera_overlay.progression = nil
if C.root_dir then pcall(os.remove, C.root_dir .. "/src/features/progression.lua") end

ST:load_data()
ST:flush_pending_xp()

if U and U.replace_handler then
    U.replace_handler(ST, "xp", "chimeraVipXpGained", function(_, amount) ST:on_xp(amount) end)
    U.replace_handler(ST, "char_name", "gmcp.Char.Name", function() ST:flush_pending_xp() end)
end

-- Naglowek postepow.
ST.trigger_ids[#ST.trigger_ids + 1] = tempRegexTrigger(
    [[^[ \t]*(?:[Nn]ie\s+)?[Pp]oczyni]],
    function()
        local current_line = line or (matches and matches[1]) or ""
        if current_line == "" then return end

        ST:reset_current()

        local postep_text = current_line:match("^[ \t]*(.-),[ \t]*od")
        if not postep_text then postep_text = current_line:match("^[ \t]*(.-)[ \t]*%[") or current_line end
        postep_text = trim(postep_text)

        local exp_total = current_line:match("(%[%d+%s+exp%])")
        local extra_tag = nil
        for bracket in current_line:gmatch("(%[[^%]]+%])") do
            if not bracket:find("exp") and not postep_text:find(bracket, 1, true) then
                extra_tag = bracket
                break
            end
        end

        ST.header = {progress=postep_text, exp=exp_total, extra=extra_tag}
        selectCurrentLine(); replace("")

        local extra_str = ""
        if extra_tag and extra_tag ~= "" then extra_str = extra_str .. " #A8DCC2" .. extra_tag end
        if exp_total and exp_total ~= "" then extra_str = extra_str .. " #F2C4A0" .. exp_total end
        hecho(string.format("\n#D8DCE6Postepy: #C7B9E8%s%s", postep_text, extra_str))
    end
)

-- Linie cech.
ST.trigger_ids[#ST.trigger_ids + 1] = tempRegexTrigger(
    [[^[ \t]*([Ss]il|[Zz]r|[Ww]t|[Ii]nt|[Mm]d|[Oo]dw):]],
    function()
        local current_line = line or (matches and matches[1]) or ""
        if current_line == "" then return end

        local raw_stat, desc, val_str, exp_missing = current_line:match(
            "^[ \t]*([%a]+):[ \t]*(.-)[ \t]+(%d+)[ \t]+brak[ \t]+(%d+)[ \t]+exp"
        )
        if not raw_stat then return end

        local stat = raw_stat:sub(1, 1):upper() .. raw_stat:sub(2):lower()
        local val = tonumber(val_str) or 0
        ST.current[stat] = val

        local old_stats = ST.previous_snapshot and ST.previous_snapshot.stats or {}
        local delta = val - (tonumber(old_stats[stat]) or val)
        local delta_str = delta ~= 0 and ("  " .. delta_markup(delta)) or ""

        selectCurrentLine(); replace("")

        local stat_line = string.format(
            "  #AFCBF4%-3s #2B303C: #EFD8A6%-18s #A8DCC2%3d  #AEB6C5brak #F0A8B8%6s #AEB6C5exp%s",
            stat, desc, val, exp_missing, delta_str
        )

        if stat ~= "Odw" then
            hecho(stat_line)
            return
        end

        local snapshot = ST:build_snapshot()
        local P = colors()
        local line_sep = "\n  " .. P.separator .. "--------------------------------------------------\n"
        local line_sum = string.format(
            "  %sSuma: %sFiz %s%d %s| %sMent %s%d %s| %sOdw %s%d %s| %sLacznie %s%d",
            P.text, P.blue, P.mint, snapshot.physical, P.text_muted,
            P.lavender, P.mint, snapshot.mental, P.text_muted,
            P.yellow, P.mint, snapshot.courage, P.text_muted,
            P.lavender, P.peach, snapshot.total
        )

        hecho(stat_line .. line_sep .. line_sum)
        local record, event_kind, diff, spent = ST:update_progress(snapshot)
        ST:show_progress_footer(record, event_kind, diff, spent)
        hecho("\n")

        raiseEvent("chimeraVipStatsUpdated", snapshot)
        ST.current = {}
        ST.previous_snapshot = nil
        ST.active_record = nil
    end
)

ST.alias_ids[#ST.alias_ids + 1] = tempAlias(
    [[^/cechy historia(?:\s+(\d+))?$]],
    function() ST:show_history(matches[2]) end
)

return ST
