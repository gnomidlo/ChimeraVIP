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
XP.max_recent_events = 100
XP.trigger_ids = XP.trigger_ids or {}
XP.alias_ids = XP.alias_ids or {}

XP.rules = {
    { name = "krasnolud chaosu", match = "krasnoluda chaosu" },
    { name = "smoczy ogr",       match = "smoczego ogra" },
    { name = "czarny ork",       match = "czarnego orka" },
}

XP.colors = U and U.palette and U.palette() or {
    text="#D8DCE6", text_muted="#AEB6C5", rose="#F0A8B8", mint="#A8DCC2",
    blue="#AFCBF4", lavender="#C7B9E8", peach="#F2C4A0", yellow="#EFD8A6", separator="#2B303C",
}

if U and U.clear_triggers then U.clear_triggers(XP) else
    for _, id in ipairs(XP.trigger_ids) do pcall(killTrigger, id) end
    XP.trigger_ids = {}
end
if U and U.clear_aliases then U.clear_aliases(XP) else
    for _, id in ipairs(XP.alias_ids) do pcall(killAlias, id) end
    XP.alias_ids = {}
end

local trim = U and U.trim or function(text) return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "") end
local normalize = U and U.normalize or function(text) return string.lower(trim(text):gsub("%s+", " ")) end
local format_integer = U and U.format_int or function(value) return tostring(math.floor(tonumber(value) or 0)) end
local function ends_with(text, suffix) return suffix ~= "" and #suffix <= #text and text:sub(-#suffix) == suffix end
local function pad(text, width)
    if U and U.pad_right then return U.pad_right(text, width) end
    text=tostring(text or ""); return text .. string.rep(" ", math.max(0, width-#text))
end
local function finish_output() hecho("\n") end

local function format_time(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local hours = math.floor(seconds / 3600); local minutes = math.floor((seconds % 3600) / 60); local secs = seconds % 60
    if hours > 0 then return string.format("%dh %02dm", hours, minutes) end
    if minutes > 0 then return string.format("%dm %02ds", minutes, secs) end
    return string.format("%ds", secs)
end
local function calculate_rate(amount, seconds) if not seconds or seconds < XP.min_rate_seconds then return nil end; return amount / seconds * 3600 end
local function format_rate(value)
    if not value then return "..." end
    if value >= 1000000 then return string.format("%.2fm/h", value / 1000000) end
    if value >= 1000 then return string.format("%.1fk/h", value / 1000) end
    return string.format("%.0f/h", value)
end

function XP:new_session()
    self.session = {
        started_at=nil, last_kill_at=nil, active_seconds=0, total_xp=0,
        kills=0, own_kills=0, group_kills=0, own_xp=0, group_xp=0,
        events={}, rate_events={}, mob_stats={},
    }
end

function XP:rebuild_mob_stats(events)
    local stats = {}
    for _, event in ipairs(events or {}) do
        local key = event.mob
        if key then
            stats[key] = stats[key] or {name=key,xp=0,kills=0,builtin=false,own_kills=0,group_kills=0}
            local data = stats[key]
            data.xp = data.xp + (tonumber(event.xp) or 0)
            data.kills = data.kills + 1
            if event.own then data.own_kills=data.own_kills+1 else data.group_kills=data.group_kills+1 end
            if event.classification == "rule" then data.builtin = true end
        end
    end
    return stats
end

function XP:ensure_session_schema()
    if type(self.session) ~= "table" then self:new_session(); return end
    local S = self.session
    S.events = type(S.events) == "table" and S.events or {}
    S.own_xp = tonumber(S.own_xp) or 0
    S.group_xp = tonumber(S.group_xp) or 0

    if type(S.mob_stats) ~= "table" then
        S.mob_stats = self:rebuild_mob_stats(S.events)
    end

    if type(S.rate_events) ~= "table" then
        S.rate_events = {}
        local cutoff = os.time() - self.rolling_window * 2
        for _, event in ipairs(S.events) do
            if tonumber(event.time) and event.time >= cutoff then S.rate_events[#S.rate_events + 1] = event end
        end
    end

    while #S.events > self.max_recent_events do table.remove(S.events, 1) end
end

XP:ensure_session_schema()

function XP:classify_mob(raw_name)
    local normalized = normalize(raw_name); local best_rule = nil
    for _, rule in ipairs(self.rules) do
        if ends_with(normalized, rule.match) and (not best_rule or #rule.match > #best_rule.match) then best_rule = rule end
    end
    if best_rule then return best_rule.name, "rule" end
    return normalized:match("([^%s]+)$") or normalized, "auto"
end

function XP:get_active_seconds(now)
    local S = self.session; if not S.last_kill_at then return 0 end
    now = now or os.time(); local tail = math.min(math.max(0, now - S.last_kill_at), self.active_timeout)
    return S.active_seconds + tail
end

function XP:prune_rate_events(now)
    local events = self.session.rate_events
    local cutoff = (now or os.time()) - self.rolling_window * 2
    local first = 1
    while first <= #events and (tonumber(events[first].time) or 0) < cutoff do first = first + 1 end
    if first > 1 then
        local kept = {}
        for i=first,#events do kept[#kept+1] = events[i] end
        self.session.rate_events = kept
    end
end

function XP:update_mob_stats(event)
    local stats = self.session.mob_stats
    local key = event.mob
    stats[key] = stats[key] or {name=key,xp=0,kills=0,builtin=false,own_kills=0,group_kills=0}
    local data = stats[key]
    data.xp = data.xp + event.xp
    data.kills = data.kills + 1
    if event.own then data.own_kills=data.own_kills+1 else data.group_kills=data.group_kills+1 end
    if event.classification == "rule" then data.builtin = true end
end

function XP:add_event(raw_mob, amount, killer, own)
    amount = tonumber(amount); if not amount then return end
    local now = os.time(); local S = self.session
    if not S.started_at then S.started_at = now end
    if S.last_kill_at then local gap = now - S.last_kill_at; S.active_seconds = S.active_seconds + math.min(math.max(gap, 0), self.active_timeout) end
    S.last_kill_at = now

    local mob, classification = self:classify_mob(raw_mob)
    local event = {time=now,xp=amount,mob_raw=trim(raw_mob),mob=mob,classification=classification,killer=killer,own=own==true}
    S.events[#S.events + 1] = event
    while #S.events > self.max_recent_events do table.remove(S.events, 1) end
    S.rate_events[#S.rate_events + 1] = event
    self:prune_rate_events(now)
    self:update_mob_stats(event)

    S.total_xp = S.total_xp + amount; S.kills = S.kills + 1
    if own then S.own_kills=S.own_kills+1; S.own_xp=S.own_xp+amount else S.group_kills=S.group_kills+1; S.group_xp=S.group_xp+amount end
    raiseEvent("chimeraVipXpGained", amount, mob, own == true)
end

function XP:get_window_stats(from_time, to_time)
    local amount, kills = 0, 0
    for _, event in ipairs(self.session.rate_events) do
        if event.time >= from_time and event.time <= to_time then amount=amount+event.xp; kills=kills+1 end
    end
    return amount, kills
end
function XP:get_current_rate(now)
    local S=self.session; if not S.started_at then return nil end
    self:prune_rate_events(now)
    local from_time=math.max(S.started_at,now-self.rolling_window); local amount=self:get_window_stats(from_time,now)
    return calculate_rate(amount,now-from_time)
end
function XP:get_previous_rate(now)
    local S=self.session; if not S.started_at then return nil end
    self:prune_rate_events(now)
    local from_time=math.max(S.started_at,now-self.rolling_window*2); local to_time=now-self.rolling_window
    if to_time<=from_time then return nil end
    local amount=self:get_window_stats(from_time,to_time); return calculate_rate(amount,to_time-from_time)
end
function XP:get_trend(current, previous) if not current or not previous or previous<=0 then return nil end; return (current-previous)/previous*100 end

function XP:get_mob_stats()
    local list = {}
    for _, data in pairs(self.session.mob_stats or {}) do
        list[#list+1] = {
            name=data.name, xp=data.xp or 0, kills=data.kills or 0, builtin=data.builtin==true,
            own_kills=data.own_kills or 0, group_kills=data.group_kills or 0,
            average=(data.kills or 0) > 0 and (data.xp or 0)/(data.kills or 1) or 0,
        }
    end
    table.sort(list,function(a,b) if a.xp==b.xp then return a.kills>b.kills end; return a.xp>b.xp end)
    return list
end
function XP:find_mob(name)
    name=normalize(name)
    local data=self.session.mob_stats and self.session.mob_stats[name]
    if not data then return nil end
    return {
        name=data.name, xp=data.xp or 0, kills=data.kills or 0, builtin=data.builtin==true,
        own_kills=data.own_kills or 0, group_kills=data.group_kills or 0,
        average=(data.kills or 0)>0 and (data.xp or 0)/(data.kills or 1) or 0,
    }
end

function XP:show_summary()
    local Cc,S=self.colors,self.session
    if S.kills==0 then hecho("\n"..Cc.text_muted.."XP: "..Cc.text.."brak danych w tej sesji.\n"); return end
    local now=os.time(); local session_seconds=now-S.started_at; local active_seconds=self:get_active_seconds(now)
    local session_rate=calculate_rate(S.total_xp,session_seconds); local active_rate=calculate_rate(S.total_xp,active_seconds)
    local current_rate=self:get_current_rate(now); local previous_rate=self:get_previous_rate(now); local trend=self:get_trend(current_rate,previous_rate)
    local average=S.total_xp/S.kills; local trend_text=""
    if trend then
        if trend>=3 then trend_text=string.format("  %s↗ +%.1f%%",Cc.mint,trend)
        elseif trend<=-3 then trend_text=string.format("  %s↘ %.1f%%",Cc.rose,trend)
        else trend_text=string.format("  %s→ %.1f%%",Cc.text_muted,trend) end
    end
    local top=self:get_mob_stats()[1]; local top_text=top and (top.name.." ("..format_integer(top.xp).." xp)") or "..."
    hecho("\n\n"..Cc.lavender.."XP — SESJA\n"..Cc.separator.."------------------------------------------\n"
        ..Cc.text_muted.."Czas       "..Cc.text..string.format("%12s",format_time(session_seconds)).."\n"
        ..Cc.text_muted.."Aktywnie   "..Cc.text..string.format("%12s",format_time(active_seconds)).."\n\n"
        ..Cc.text_muted.."Zdobyto    "..Cc.peach..string.format("%12s xp",format_integer(S.total_xp)).."\n"
        ..Cc.text_muted.."Zabici     "..Cc.text..string.format("%12s",format_integer(S.kills)).."\n"
        ..Cc.text_muted.."  ty       "..Cc.text..string.format("%6s",format_integer(S.own_kills))..Cc.text_muted.." / "..Cc.peach..format_integer(S.own_xp).." xp\n"
        ..Cc.text_muted.."  druzyna  "..Cc.text..string.format("%6s",format_integer(S.group_kills))..Cc.text_muted.." / "..Cc.peach..format_integer(S.group_xp).." xp\n"
        ..Cc.text_muted.."XP / kill  "..Cc.text..string.format("%12s",format_integer(average)).."\n"
        ..Cc.text_muted.."Top mob    "..Cc.mint..top_text.."\n\n"
        ..Cc.text_muted.."TERAZ      "..Cc.mint..string.format("%12s",format_rate(current_rate))..trend_text.."\n"
        ..Cc.text_muted.."AKTYWNIE   "..Cc.blue..string.format("%12s",format_rate(active_rate)).."\n"
        ..Cc.text_muted.."SESJA      "..Cc.lavender..string.format("%12s",format_rate(session_rate))
        .."\n"..Cc.separator.."------------------------------------------\n")
end

function XP:show_mobs()
    local Cc=self.colors; local list=self:get_mob_stats()
    hecho("\n\n"..Cc.lavender.."XP — MOBY\n"..Cc.separator.."-------------------------------------------------------")
    if #list==0 then hecho("\n"..Cc.text_muted.."Brak danych w tej sesji.\n"); return end
    for _,data in ipairs(list) do
        local marker=data.builtin and "*" or " "
        hecho(string.format("\n%s%s %-24s %s%4d  %s%9s xp  %s%6s/k",Cc.lavender,marker,data.name,Cc.text,data.kills,Cc.peach,format_integer(data.xp),Cc.text_muted,format_integer(data.average)))
    end
    hecho("\n"..Cc.text_muted.."* = wbudowana klasyfikacja ChimeraVIP\n")
end

function XP:show_mob(name)
    local Cc=self.colors; local data=self:find_mob(name)
    if not data then hecho("\n"..Cc.rose.."[XP] Brak moba w tej sesji: "..Cc.text..trim(name).."\n"); return end
    hecho("\n\n"..Cc.lavender.."XP — "..string.upper(data.name)
        .."\n"..Cc.separator.."------------------------------------------"
        .."\n"..Cc.text_muted.."Zabicia    "..Cc.text..format_integer(data.kills)
        .."\n"..Cc.text_muted.."  ty       "..Cc.text..format_integer(data.own_kills)
        .."\n"..Cc.text_muted.."  druzyna  "..Cc.text..format_integer(data.group_kills)
        .."\n"..Cc.text_muted.."XP razem   "..Cc.peach..format_integer(data.xp)
        .."\n"..Cc.text_muted.."XP / kill  "..Cc.text..format_integer(data.average).."\n")
end

function XP:show_last(count)
    count=math.max(1,math.min(self.max_recent_events,tonumber(count) or 10)); local Cc,events=self.colors,self.session.events
    hecho("\n\n"..Cc.lavender.."XP — OSTATNIE ZABICIA\n"..Cc.separator.."-------------------------------------------------------")
    if #events==0 then hecho("\n"..Cc.text_muted.."Brak danych.\n"); return end
    local first=math.max(1,#events-count+1)
    for i=first,#events do
        local event=events[i]; local marker=event.classification=="rule" and "*" or " "
        hecho("\n"..Cc.text_muted..os.date("%H:%M:%S",event.time).."  "..Cc.peach.."+"..format_integer(event.xp).." xp  "..Cc.text..event.mob_raw..Cc.text_muted.."  ->  "..Cc.mint..marker..event.mob)
    end
    finish_output()
end

function XP:reset()
    self:new_session()
    hecho("\n"..self.colors.mint.."[XP] Sesja wyzerowana.\n")
end

function XP:show_help()
    local Cc=self.colors
    local rows={
        {"/xp","podsumowanie sesji"},
        {"/xp mobs","statystyki typów mobów"},
        {"/xp mob <nazwa>","szczegóły typu"},
        {"/xp last [N]","ostatnie N zabójstw"},
        {"/xp reset","wyzeruj sesję"},
        {"/xp pomoc","ta pomoc"},
    }
    local command_width=0
    for _,row in ipairs(rows) do command_width=math.max(command_width,U and U.text_width and U.text_width(row[1]) or #row[1]) end
    command_width=command_width+2
    hecho("\n\n"..Cc.lavender.."XP — POMOC\n"..Cc.separator.."--------------------------------------------------"
        .."\n"..Cc.text_muted.."Sesyjny licznik doświadczenia, zabójstw, XP/h i wydajności typów przeciwników."
        .."\n"..Cc.text_muted.."Niestandardowe typy mobów są utrzymywane centralnie w ChimeraVIP.\n")
    for _,row in ipairs(rows) do hecho("\n"..Cc.text..pad(row[1],command_width)..Cc.text_muted..row[2]) end
    finish_output()
end

table.insert(XP.trigger_ids,tempRegexTrigger([[^(Zabilas|Zabiles) (.+)\. \[(\d+)xp\]$]],function() XP:add_event(matches[3],matches[4],"TY",true) end))
table.insert(XP.trigger_ids,tempRegexTrigger([[^(.+?) (zabil|zabila) (.+)\. \[(\d+)xp\]$]],function() XP:add_event(matches[4],matches[5],matches[2],false) end))

local function alias(pattern,fn) table.insert(XP.alias_ids,tempAlias(pattern,fn)) end
alias([[^/xp$]],function() XP:show_summary() end)
alias([[^/xp reset$]],function() XP:reset() end)
alias([[^/xp (?:mobs|moby)$]],function() XP:show_mobs() end)
alias([[^/xp last(?:\s+(\d+))?$]],function() XP:show_last(matches[2]) end)
alias([[^/xp mob (.+)$]],function() XP:show_mob(matches[2]) end)
alias([[^/xp (?:help|pomoc)$]],function() XP:show_help() end)

return XP
