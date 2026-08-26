-- ChimeraVIP / Cechy
-- Formatuje wynik komendy cech i wylicza podsumowanie.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
C.stats = C.stats or {}
chimera_overlay.stats = C.stats
local ST = C.stats

ST.trigger_ids = ST.trigger_ids or {}
ST.current = ST.current or {}
ST.last = ST.last or nil
ST.header = ST.header or nil

local function get_colors()
    if chimera_overlay.pastel_ui and chimera_overlay.pastel_ui.colors then
        return chimera_overlay.pastel_ui.colors
    end
    return {
        text = "#D8DCE6",
        text_muted = "#AEB6C5",
        rose = "#F0A8B8",
        mint = "#A8DCC2",
        blue = "#AFCBF4",
        lavender = "#C7B9E8",
        peach = "#F2C4A0",
        yellow = "#EFD8A6",
        separator = "#2B303C",
    }
end

ST.colors = get_colors()

-- Hot reload: usuwamy tylko nasze tymczasowe triggery.
for _, id in ipairs(ST.trigger_ids) do
    pcall(killTrigger, id)
end
ST.trigger_ids = {}

local function trim(text)
    text = tostring(text or "")
    return text:gsub("^[ \t]+", ""):gsub("[ \t]+$", "")
end

local function copy_table(source)
    local out = {}
    for k, v in pairs(source or {}) do out[k] = v end
    return out
end

function ST:reset_current()
    self.current = {}
    self.header = nil
end

function ST:finish()
    local fiz = (self.current.Sil or 0) + (self.current.Zr or 0) + (self.current.Wt or 0)
    local ment = (self.current.Int or 0) + (self.current.Md or 0)
    local odw = self.current.Odw or 0

    self.last = {
        header = self.header,
        stats = copy_table(self.current),
        physical = fiz,
        mental = ment,
        courage = odw,
        total = fiz + ment + odw,
        captured_at = os.time(),
    }

    raiseEvent("chimeraVipStatsUpdated", self.last)
end

-- Naglowek postepow.
local trigger_header = tempRegexTrigger(
    [[^[ \t]*(?:[Nn]ie\s+)?[Pp]oczyni]],
    function()
        local current_line = line or (matches and matches[1]) or ""
        if current_line == "" then return end

        ST:reset_current()

        local postep_text = current_line:match("^[ \t]*(.-),[ \t]*od")
        if not postep_text then
            postep_text = current_line:match("^[ \t]*(.-)[ \t]*%[") or current_line
        end
        postep_text = trim(postep_text)

        local exp_total = current_line:match("(%[%d+%s+exp%])")
        local extra_tag = nil
        for bracket in current_line:gmatch("(%[[^%]]+%])") do
            if not bracket:find("exp") and not postep_text:find(bracket, 1, true) then
                extra_tag = bracket
                break
            end
        end

        ST.header = {
            progress = postep_text,
            exp = exp_total,
            extra = extra_tag,
        }

        selectCurrentLine()
        replace("")

        local extra_str = ""
        if extra_tag and extra_tag ~= "" then
            extra_str = extra_str .. " #A8DCC2" .. extra_tag
        end
        if exp_total and exp_total ~= "" then
            extra_str = extra_str .. " #F2C4A0" .. exp_total
        end

        hecho(string.format(
            "\n#D8DCE6Postępy: #C7B9E8%s%s",
            postep_text,
            extra_str
        ))
    end
)

table.insert(ST.trigger_ids, trigger_header)

-- Linie cech.
local trigger_stats = tempRegexTrigger(
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

        selectCurrentLine()
        replace("")

        if stat ~= "Odw" then
            hecho(string.format(
                "  #AFCBF4%-3s #2B303C: #EFD8A6%-18s #A8DCC2%3d  #AEB6C5brak #F0A8B8%6s #AEB6C5exp",
                stat, desc, val, exp_missing
            ))
            return
        end

        local fiz = (ST.current.Sil or 0) + (ST.current.Zr or 0) + (ST.current.Wt or 0)
        local ment = (ST.current.Int or 0) + (ST.current.Md or 0)
        local odw = ST.current.Odw or 0
        local total = fiz + ment + odw

        local line_odw = string.format(
            "  #AFCBF4%-3s #2B303C: #EFD8A6%-18s #A8DCC2%3d  #AEB6C5brak #F0A8B8%6s #AEB6C5exp\n",
            stat, desc, val, exp_missing
        )
        local line_sep = "  #2B303C--------------------------------------------------\n"
        local line_sum = string.format(
            "  #D8DCE6Suma: #AFCBF4Fiz #A8DCC2%d #AEB6C5| #C7B9E8Ment #A8DCC2%d #AEB6C5| #EFD8A6Odw #A8DCC2%d #AEB6C5| #C7B9E8Łącznie #F2C4A0%d",
            fiz, ment, odw, total
        )

        hecho(line_odw .. line_sep .. line_sum)
        ST:finish()
        ST.current = {}
    end
)

table.insert(ST.trigger_ids, trigger_stats)

return ST
