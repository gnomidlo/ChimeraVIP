-- ChimeraVIP / Compact Stats View
-- Zwarty renderer cech: skrocone brakujace XP + pelna wartosc w tooltipie.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
local ST = C.stats

if type(ST) ~= "table" then return false end

local colors = U.palette
local fmt_int = U.format_int

local function delta_markup(value)
    value = tonumber(value) or 0
    local P = colors()
    if value > 0 then return P.mint .. string.format("%+d", value) end
    if value < 0 then return P.rose .. string.format("%+d", value) end
    return ""
end

local function compact_xp(value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    if value < 1000 then return tostring(value) end
    if value < 1000000 then return tostring(math.floor(value / 1000)) .. "k" end
    local tenths = math.floor(value / 100000) / 10
    return string.format("%.1fm", tenths)
end

local function echo_xp(value)
    local short = compact_xp(value)
    local hint = "Brakuje: " .. fmt_int(value) .. " exp"
    if type(echoLink) == "function" then
        echoLink(short, "", hint, true)
    else
        hecho(short)
    end
end

-- stats.lua instaluje trigger linii cech jako ostatni trigger modulu.
-- Zastepujemy tylko renderer; historia, snapshoty i pozostale triggery zostaja bez zmian.
local old_id = ST.trigger_ids and ST.trigger_ids[#ST.trigger_ids]
if old_id then
    pcall(killTrigger, old_id)
    table.remove(ST.trigger_ids, #ST.trigger_ids)
end

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
        local missing = tonumber(exp_missing) or 0
        ST.current[stat] = val

        local old_stats = ST.previous_snapshot and ST.previous_snapshot.stats or {}
        local delta = val - (tonumber(old_stats[stat]) or val)
        local delta_str = delta ~= 0 and ("  " .. delta_markup(delta)) or ""

        selectCurrentLine(); replace("")

        local P = colors()
        hecho("  " .. P.blue .. string.format("%-3s", stat)
            .. P.separator .. ": "
            .. P.mint .. string.format("%3d", val)
            .. P.text_muted .. "  brak "
            .. P.rose .. string.format("%5s", compact_xp(missing)))

        -- Nadpisujemy skrot linkiem tylko wtedy, gdy Mudlet udostepnia tooltipy.
        -- Cofamy tekst i drukujemy cala linie ponownie jako segmenty, aby tooltip obejmowal tylko XP.
        if type(echoLink) == "function" then
            selectCurrentLine(); replace("")
            hecho("  " .. P.blue .. string.format("%-3s", stat)
                .. P.separator .. ": "
                .. P.mint .. string.format("%3d", val)
                .. P.text_muted .. "  brak " .. P.rose)
            echo_xp(missing)
            hecho(string.rep(" ", math.max(1, 5 - #compact_xp(missing)))
                .. P.text_muted .. "  | " .. P.yellow .. desc .. delta_str)
        else
            hecho(P.text_muted .. "  | " .. P.yellow .. desc .. delta_str)
        end

        if stat ~= "Odw" then return end

        local snapshot = ST:build_snapshot()
        local line_sep = "\n  " .. P.separator .. "--------------------------------------------------\n"
        local line_avg = string.format(
            "  %sSrednia: %sFiz %s%.1f %s| %sMent %s%.1f",
            P.text, P.blue, P.mint, snapshot.physical_average, P.text_muted,
            P.lavender, P.mint, snapshot.mental_average
        )

        hecho(line_sep .. line_avg)
        local record, event_kind, diff, spent = ST:update_progress(snapshot)
        ST:show_progress_footer(record, event_kind, diff, spent)
        hecho("\n")

        raiseEvent("chimeraVipStatsUpdated", snapshot)
        ST.current = {}
        ST.previous_snapshot = nil
        ST.active_record = nil
    end
)

return true
