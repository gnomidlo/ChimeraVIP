-- ChimeraVIP / Defense Tracker
-- Sesyjne statystyki obrony. Nic nie jest zapisywane na dysku.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
C.defense_tracker = C.defense_tracker or {}
local D = C.defense_tracker
chimera_overlay.defense_tracker = D

D.trigger_ids = D.trigger_ids or {}
D.alias_ids = D.alias_ids or {}
D.handlers = D.handlers or {}
D.pending_hits = D.pending_hits or {}
D.max_events = 200
D.hit_delay = 0.06
D.defense_grace_ms = 100
D.recent_defense_ms = D.recent_defense_ms or 0
D.started_at = D.started_at or os.time()

local colors = U.palette
local trim = U.trim
local text_width = U.text_width
local pad_right = U.pad_right
local function normalize_item(s) s=trim(s):gsub("%s+"," "):gsub("[%.%!%?]+$",""); return s end
local function now_ms() return getEpochMs and getEpochMs() or (os.time()*1000) end
local function finish_output() hecho("\n") end
local function pct(value,total) if not total or total<=0 then return "  0.0%" end; return string.format("%5.1f%%",value*100/total) end
local function sorted_pairs_by_count(t)
    local rows={}; for name,count in pairs(t or {}) do rows[#rows+1]={name=name,count=count} end
    table.sort(rows,function(a,b) if a.count==b.count then return a.name<b.name end; return a.count>b.count end); return rows
end

local function actions(kind)
    if not U or type(U.action_links) ~= "function" then return end
    if kind=="summary" then
        U.action_links({
            {"SPRZET","/def sprzet","Statystyki obrony wedlug sprzetu"},
            {"LAST 10","/def last 10","Ostatnie 10 zdarzen obrony"},
            {"RESET","/def reset","Wyzeruj sesje obrony"},
        })
    elseif kind=="equipment" then
        U.action_links({{"SESJA","/def","Podsumowanie obrony"},{"LAST 10","/def last 10","Ostatnie 10 zdarzen obrony"}})
    elseif kind=="last" then
        U.action_links({{"SESJA","/def","Podsumowanie obrony"},{"SPRZET","/def sprzet","Statystyki obrony wedlug sprzetu"}})
    end
end

function D:clear_pending_hits()
    for _,pending in ipairs(self.pending_hits or {}) do if pending.timer then pcall(killTimer,pending.timer) end; pending.cancelled=true end
    self.pending_hits={}
end
function D:cancel_latest_pending_hit()
    for i=#self.pending_hits,1,-1 do local p=self.pending_hits[i]; if p and not p.cancelled then p.cancelled=true; if p.timer then pcall(killTimer,p.timer) end; table.remove(self.pending_hits,i); return true end end
    return false
end
function D:new_session()
    self:clear_pending_hits()
    self.session={miss=0,dodge=0,parry=0,block=0,armor=0,hits={brak=0,niskie=0,srednie=0,wysokie=0},parry_items={},block_items={},armor_items={},events={}}
    self.recent_defense_ms=0; self.started_at=os.time()
end
if type(D.session)~="table" then D:new_session() end

function D:add_event(kind,detail,raw)
    local S=self.session; if not S then self:new_session(); S=self.session end
    if kind~="hit" then self.recent_defense_ms=now_ms(); self:cancel_latest_pending_hit() end
    if kind=="miss" then S.miss=S.miss+1
    elseif kind=="dodge" then S.dodge=S.dodge+1
    elseif kind=="parry" then S.parry=S.parry+1; detail=normalize_item(detail); if detail~="" then S.parry_items[detail]=(S.parry_items[detail] or 0)+1 end
    elseif kind=="block" then S.block=S.block+1; detail=normalize_item(detail); if detail~="" then S.block_items[detail]=(S.block_items[detail] or 0)+1 end
    elseif kind=="armor" then S.armor=S.armor+1; detail=normalize_item(detail); if detail~="" then S.armor_items[detail]=(S.armor_items[detail] or 0)+1 end
    elseif kind=="hit" then local level=tostring(detail or ""); if S.hits[level]==nil then return end; S.hits[level]=S.hits[level]+1
    else return end
    local event={time=os.time(),kind=kind,detail=detail,raw=trim(raw)}; S.events[#S.events+1]=event
    while #S.events>self.max_events do table.remove(S.events,1) end
    raiseEvent("chimeraVipDefenseEvent",kind,detail,event,S)
end

function D:is_defense_line(text)
    local s=trim(text):lower():gsub("%s+"," ")
    return s:find("lecz udaje ci sie oslonic ",1,true) or s:find("lecz tobie udaje sie oslonic ",1,true)
        or s:find("lecz tobie udaje sie zbic je z lini ataku ",1,true) or s:find("lecz tobie udaje sie zbic je z linii ataku ",1,true)
        or s:find("lecz tobie udaje je zbic z lini ataku ",1,true) or s:find("lecz tobie udaje je zbic z linii ataku ",1,true)
        or s:find("lecz tobie udaje sie go sparowac ",1,true) or s:find("lecz tobie udaje sie uniknac tego ciosu",1,true)
        or s:find("nie udaje sie trafic ciebie",1,true) or s:find("lecz caly impet uderzenia wyparowany zostaje przez ",1,true)
end
function D:queue_incoming_hit(level,raw)
    local map={otrzymane_brak="brak",otrzymane_niskie="niskie",otrzymane_srednie="srednie",otrzymane_wysokie="wysokie",brak="brak",niskie="niskie",srednie="srednie",wysokie="wysokie"}
    local normalized=map[tostring(level or "")]; if not normalized then return end
    if now_ms()-(self.recent_defense_ms or 0)<=self.defense_grace_ms then return end
    local pending={level=normalized,raw=tostring(raw or ""),cancelled=false}; self.pending_hits[#self.pending_hits+1]=pending
    pending.timer=tempTimer(self.hit_delay,function()
        if pending.cancelled then return end
        for i,item in ipairs(D.pending_hits) do if item==pending then table.remove(D.pending_hits,i); break end end
        D:add_event("hit",pending.level,pending.raw)
    end)
end
function D:on_incoming_hit(level,raw) self:queue_incoming_hit(level,raw) end
function D:known_hits() local h=self.session.hits; return (h.brak or 0)+(h.niskie or 0)+(h.srednie or 0)+(h.wysokie or 0) end
function D:defended() local S=self.session; return S.miss+S.dodge+S.parry+S.block end
function D:known_attempts() return self:defended()+self.session.armor+self:known_hits() end
function D:zero_hits_complete()
    local CC=C.combat_colors; if not CC or not CC.game_colors then return false end
    local ansi=tonumber(CC.game_colors.otrzymane_brak); return ansi~=nil and ansi>=0 and ansi<=255 and CC.enabled~=false
end

local function line_row(label,value,total,color)
    local P=colors(); hecho("\n  "..(color or P.text_muted)..pad_right(label,22)..P.text..string.format("%6d",value)..P.text_muted.."   "..pct(value,total))
end
function D:show_summary()
    local P=colors(); local S=self.session; local defended=self:defended(); local hits=self:known_hits(); local total=self:known_attempts()
    hecho("\n\n"..P.lavender.."OBRONA — SESJA\n"..P.separator.."--------------------------------------------------")
    hecho("\n"..P.text_muted..pad_right("Znane próby ataku",24)..P.text..string.format("%6d",total))
    hecho("\n\n"..P.mint.."OBRONIONE"); line_row("Pudło",S.miss,total,P.text_muted); line_row("Unik",S.dodge,total,P.mint); line_row("Parowanie",S.parry,total,P.blue); line_row("Zasłona",S.block,total,P.lavender)
    hecho("\n\n"..P.yellow.."ZATRZYMANE PANCERZEM"); line_row("Pancerz",S.armor,total,P.yellow)
    hecho("\n\n"..P.rose.."TRAFIENIA"); line_row("Brak / 0",S.hits.brak,total,P.mint); line_row("Niskie / 1",S.hits.niskie,total,P.yellow); line_row("Średnie / 2",S.hits.srednie,total,P.peach); line_row("Wysokie / 3",S.hits.wysokie,total,P.rose)
    hecho("\n\n"..P.separator.."--------------------------------------------------"); line_row("Obronione",defended,total,P.mint); line_row("Pancerz",S.armor,total,P.yellow); line_row("Przeszło (znane)",hits,total,P.rose)
    actions("summary")
end
local function show_items(title,table_data,color)
    local P=colors(); hecho("\n\n"..color..title); local rows=sorted_pairs_by_count(table_data)
    if #rows==0 then hecho("\n  "..P.text_muted.."brak danych"); return end
    local total=0; for _,row in ipairs(rows) do total=total+row.count end
    for _,row in ipairs(rows) do hecho("\n  "..P.text_muted..pad_right(row.name,36)..P.text..string.format("%5d",row.count)..P.text_muted.."   "..pct(row.count,total)) end
end
function D:show_equipment()
    local P=colors(); hecho("\n\n"..P.lavender.."OBRONA — SPRZĘT (SESJA)\n"..P.separator.."--------------------------------------------------")
    show_items("ZASŁONY",self.session.block_items,P.lavender); show_items("PAROWANIA",self.session.parry_items,P.blue); show_items("PANCERZ",self.session.armor_items,P.yellow)
    hecho("\n\n"..P.text_muted.."Udział oznacza część udanych obron danego typu, nie skuteczność/AC przedmiotu.")
    actions("equipment")
end
local event_labels={miss="pudło",dodge="unik",parry="parowanie",block="zasłona",armor="pancerz",hit="trafienie"}
function D:show_last(n)
    n=math.max(1,math.min(50,tonumber(n) or 10)); local P=colors(); local events=self.session.events
    hecho("\n\n"..P.lavender.."OBRONA — OSTATNIE "..tostring(math.min(n,#events)).."\n"..P.separator.."--------------------------------------------------")
    if #events==0 then hecho("\n"..P.text_muted.."Brak danych w tej sesji."); actions("last"); return end
    local first=math.max(1,#events-n+1)
    for i=first,#events do local e=events[i]; local suffix=e.detail and tostring(e.detail)~="" and (" — "..tostring(e.detail)) or ""; hecho("\n"..P.text_muted..os.date("%H:%M:%S",e.time).."  "..P.text..tostring(event_labels[e.kind] or e.kind)..P.text_muted..suffix) end
    actions("last")
end
function D:show_help()
    local P=colors(); local rows={{"/def","podsumowanie sesji"},{"/def sprzet","tarcze, bronie i pancerz"},{"/def last [N]","ostatnie zdarzenia"},{"/def reset","wyzeruj sesję"},{"/def pomoc","ta pomoc"}}
    local w=0; for _,row in ipairs(rows) do w=math.max(w,text_width(row[1])) end; w=w+2
    hecho("\n\n"..P.lavender.."OBRONA — POMOC")
    for _,row in ipairs(rows) do hecho("\n"..P.text..pad_right(row[1],w)..P.text_muted..row[2]) end
    hecho("\n\n"..P.text_muted.."Dane istnieją wyłącznie w pamięci bieżącej sesji Mudleta."); finish_output()
end

function D:command(arg)
    arg=trim(arg):lower(); if arg=="" then self:show_summary(); return end
    if arg=="sprzet" or arg=="sprzęt" then self:show_equipment(); return end
    if arg=="reset" then self:new_session(); cecho("\n<aquamarine>[ChimeraVIP]<reset> Statystyki obrony wyzerowane.\n"); return end
    if arg=="help" or arg=="pomoc" then self:show_help(); return end
    local n=arg:match("^last%s*(%d*)$"); if n~=nil then self:show_last(n~="" and tonumber(n) or 10); return end
    self:show_help()
end
function D:clear_runtime() U.clear_triggers(self); U.clear_aliases(self) end
function D:add_trigger(pattern,code) local ok,id=pcall(tempRegexTrigger,pattern,code); if ok and id then self.trigger_ids[#self.trigger_ids+1]=id end end
function D:install_runtime()
    self:clear_runtime()
    self:add_trigger([[lecz\s+(?:udaje\s+ci\s+sie|tobie\s+udaje\s+sie)\s+oslonic\s+(.+?)\.\s*$]],[[chimera_vip.defense_tracker:add_event("block", matches[2], line)]])
    self:add_trigger([[lecz\s+tobie\s+udaje\s+sie\s+zbic\s+je\s+z\s+linii?\s+ataku\s+(.+?)\.\s*$]],[[chimera_vip.defense_tracker:add_event("parry", matches[2], line)]])
    self:add_trigger([[lecz\s+tobie\s+udaje\s+je\s+zbic\s+z\s+linii?\s+ataku\s+(.+?)\.\s*$]],[[chimera_vip.defense_tracker:add_event("parry", matches[2], line)]])
    self:add_trigger([[lecz\s+tobie\s+udaje\s+sie\s+go\s+sparowac\s+(.+?)\.\s*$]],[[chimera_vip.defense_tracker:add_event("parry", matches[2], line)]])
    self:add_trigger([[lecz\s+tobie\s+udaje\s+sie\s+uniknac\s+tego\s+ciosu\.]],[[chimera_vip.defense_tracker:add_event("dodge", nil, line)]])
    self:add_trigger([[nie\s+udaje\s+sie\s+trafic\s+ciebie\b]],[[chimera_vip.defense_tracker:add_event("miss", nil, line)]])
    self:add_trigger([[lecz\s+caly\s+impet\s+uderzenia\s+wyparowany\s+zostaje\s+przez\s+(.+?)\.\s*$]],[[chimera_vip.defense_tracker:add_event("armor", matches[2], line)]])
    local ok,id=pcall(tempAlias,[[^/def(?:\s+(.*))?$]],[[chimera_vip.defense_tracker:command(matches[2] or "")]]); if ok and id then self.alias_ids[#self.alias_ids+1]=id end
end
if U and U.replace_handler then U.replace_handler(D,"incoming_hit","chimeraVipIncomingHit",function(_,level,raw) D:on_incoming_hit(level,raw) end) end
D:install_runtime(); raiseEvent("chimeraVipDefenseReady",D.session)
return D
