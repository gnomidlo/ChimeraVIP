-- ChimeraVIP / Progression
-- Historia rozwoju cech i XP przypisana do postaci po GMCP Char.Name.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
C.progression = C.progression or {}
chimera_overlay.progression = C.progression
local P = C.progression

P.handlers = P.handlers or {}
P.alias_ids = P.alias_ids or {}
P.data = P.data or {characters={}}
P.pending_xp = P.pending_xp or 0
P.save_timer = P.save_timer or nil
P.max_history = 100

local data_dir=getMudletHomeDir().."/ChimeraVIP-data"
P.data_file=data_dir.."/progression.lua"

local function colors()
    if chimera_overlay.pastel_ui and chimera_overlay.pastel_ui.colors then return chimera_overlay.pastel_ui.colors end
    return {text="#D8DCE6",text_muted="#AEB6C5",rose="#F0A8B8",mint="#A8DCC2",blue="#AFCBF4",lavender="#C7B9E8",peach="#F2C4A0",yellow="#EFD8A6",separator="#2B303C"}
end
local function pad(text,width)
    if U and U.pad_right then return U.pad_right(text,width) end
    text=tostring(text or ""); return text..string.rep(" ",math.max(0,width-#text))
end
local function text_width(text) if U and U.text_width then return U.text_width(text) end; return #tostring(text or "") end
local function finish_output() hecho("\n") end
local function fmt_int(value)
    local text=tostring(math.floor(tonumber(value) or 0)); local result=""
    while #text>3 do result=" "..text:sub(-3)..result; text=text:sub(1,-4) end
    return text..result
end
local function copy_table(source)
    local out={}; for k,v in pairs(source or {}) do if type(v)=="table" then local child={}; for ck,cv in pairs(v) do child[ck]=cv end; out[k]=child else out[k]=v end end; return out
end
local function safe_key(name)
    name=tostring(name or ""):lower():gsub("^%s+",""):gsub("%s+$",""):gsub("%s+","_"):gsub("[^%w_%-]","_"):gsub("_+","_"); return name
end

function P:get_character()
    local char=gmcp and gmcp.Char and gmcp.Char.Name; if type(char)~="table" then return nil,nil end
    local display=char.fullname or char.name; if not display or tostring(display)=="" then return nil,nil end
    display=tostring(display); return safe_key(display),display
end
function P:get_record(create)
    local key,display=self:get_character(); if not key or key=="" then return nil,nil end
    self.data.characters=self.data.characters or {}; local record=self.data.characters[key]
    if not record and create then
        record={key=key,display_name=display,tracked_xp=0,xp_since_change=0,baseline=nil,last_observed=nil,history={}}
        self.data.characters[key]=record
    end
    if record and display and display~="" then record.display_name=display end
    return record,key
end
function P:load()
    if U and U.ensure_dir then U.ensure_dir(data_dir) end
    local loaded={}
    if io.exists and io.exists(self.data_file) then
        local ok,err=pcall(table.load,self.data_file,loaded)
        if not ok then hecho("\n"..colors().rose.."[PROGRES] Nie udalo sie wczytac danych: "..tostring(err).."\n"); loaded={} end
    end
    loaded.characters=loaded.characters or {}; self.data=loaded
end
function P:save()
    if U and U.ensure_dir then U.ensure_dir(data_dir) end
    local ok,err=pcall(table.save,self.data_file,self.data)
    if not ok then hecho("\n"..colors().rose.."[PROGRES] Nie udalo sie zapisac danych: "..tostring(err).."\n"); return false end
    return true
end
function P:schedule_save()
    if self.save_timer then pcall(killTimer,self.save_timer) end
    self.save_timer=tempTimer(1.5,function() P.save_timer=nil; P:save() end)
end
function P:flush_pending_xp()
    if self.pending_xp<=0 then return end
    local record=self:get_record(true); if not record then return end
    record.tracked_xp=(record.tracked_xp or 0)+self.pending_xp; record.xp_since_change=(record.xp_since_change or 0)+self.pending_xp; self.pending_xp=0; self:schedule_save()
end
function P:on_xp(amount)
    amount=tonumber(amount) or 0; if amount<=0 then return end
    local record=self:get_record(true); if not record then self.pending_xp=self.pending_xp+amount; return end
    self:flush_pending_xp(); record.tracked_xp=(record.tracked_xp or 0)+amount; record.xp_since_change=(record.xp_since_change or 0)+amount; self:schedule_save()
end
function P:stat_diff(old_snapshot,new_snapshot)
    local keys={"Sil","Zr","Wt","Int","Md","Odw"}; local diff={}; local changed=false
    local old_stats=old_snapshot and old_snapshot.stats or {}; local new_stats=new_snapshot and new_snapshot.stats or {}
    for _,key in ipairs(keys) do local delta=(tonumber(new_stats[key]) or 0)-(tonumber(old_stats[key]) or 0); if delta~=0 then diff[key]=delta; changed=true end end
    return changed,diff
end
function P:append_history(record,entry)
    record.history=record.history or {}; table.insert(record.history,entry); while #record.history>self.max_history do table.remove(record.history,1) end
end
function P:on_stats(snapshot)
    if type(snapshot)~="table" or type(snapshot.stats)~="table" then return end
    local record=self:get_record(true)
    if not record then hecho("\n"..colors().yellow.."[PROGRES] Nie znam jeszcze postaci z GMCP Char.Name; snapshot nie zostal zapisany.\n"); return end
    self:flush_pending_xp(); local current=copy_table(snapshot); current.character=record.display_name
    if not record.last_observed then
        record.baseline=copy_table(current); record.last_observed=copy_table(current); record.xp_since_change=0
        self:append_history(record,{time=current.captured_at or os.time(),kind="baseline",snapshot=copy_table(current),diff={},xp_since_previous=0})
        self:schedule_save(); raiseEvent("chimeraVipProgressionUpdated",record.display_name,"baseline",record); return
    end
    local changed,diff=self:stat_diff(record.last_observed,current); record.last_observed=copy_table(current)
    if not changed then self:schedule_save(); raiseEvent("chimeraVipProgressionUpdated",record.display_name,"observed",record); return end
    local spent=record.xp_since_change or 0
    self:append_history(record,{time=current.captured_at or os.time(),kind="change",snapshot=copy_table(current),diff=diff,xp_since_previous=spent})
    record.baseline=copy_table(current); record.xp_since_change=0; self:schedule_save(); raiseEvent("chimeraVipProgressionUpdated",record.display_name,"change",record,diff,spent)
end

local function diff_text(diff,Cc)
    local order={"Sil","Zr","Wt","Int","Md","Odw"}; local parts={}
    for _,key in ipairs(order) do local value=diff and tonumber(diff[key]) or 0; if value~=0 then local color=value>0 and Cc.mint or Cc.rose; parts[#parts+1]=color..key..string.format(" %+d",value) end end
    return #parts>0 and table.concat(parts,Cc.text_muted.."  ") or (Cc.text_muted.."brak zmian")
end

function P:show_info()
    local Cc=colors(); local record=self:get_record(false); local _,display=self:get_character()
    if not display then hecho("\n"..Cc.rose.."[PROGRES] Brak danych gmcp.Char.Name.\n"); return end
    if not record or not record.last_observed then hecho("\n"..Cc.lavender.."PROGRES — "..display.."\n"..Cc.text_muted.."Brak snapshotu cech. Wyswietl cechy w grze, aby zalozyc punkt bazowy.\n"); return end
    local s=record.last_observed; local st=s.stats or {}; local last_change=nil
    for i=#(record.history or {}),1,-1 do if record.history[i].kind=="change" then last_change=record.history[i]; break end end
    hecho("\n\n"..Cc.lavender.."PROGRES — "..tostring(record.display_name)
        .."\n"..Cc.separator.."--------------------------------------------------"
        .."\n"..Cc.text_muted.."Sil "..Cc.text..tostring(st.Sil or "-")..Cc.text_muted.." | Zr "..Cc.text..tostring(st.Zr or "-")..Cc.text_muted.." | Wt "..Cc.text..tostring(st.Wt or "-")..Cc.text_muted.." | Int "..Cc.text..tostring(st.Int or "-")..Cc.text_muted.." | Md "..Cc.text..tostring(st.Md or "-")..Cc.text_muted.." | Odw "..Cc.text..tostring(st.Odw or "-")
        .."\n"..Cc.text_muted.."Fiz "..Cc.blue..tostring(s.physical or 0)..Cc.text_muted.." | Ment "..Cc.lavender..tostring(s.mental or 0)..Cc.text_muted.." | Odw "..Cc.yellow..tostring(s.courage or 0)..Cc.text_muted.." | Łącznie "..Cc.peach..tostring(s.total or 0)
        .."\n\n"..Cc.text_muted.."XP od zmiany   "..Cc.mint..fmt_int(record.xp_since_change or 0)
        ..Cc.text_muted.."\nXP śledzone     "..Cc.peach..fmt_int(record.tracked_xp or 0)
        ..(last_change and (Cc.text_muted.."\nOstatnia zmiana "..Cc.text..os.date("%Y-%m-%d %H:%M",last_change.time)..Cc.text_muted.."\n  "..diff_text(last_change.diff,Cc)..Cc.text_muted.."\n  XP w przedziale: "..Cc.peach..fmt_int(last_change.xp_since_previous or 0)) or "")
        .."\n"..Cc.separator.."--------------------------------------------------\n")
end
function P:show_history(count)
    count=math.max(1,math.min(50,tonumber(count) or 10)); local Cc=colors(); local record=self:get_record(false); local _,display=self:get_character()
    if not display then hecho("\n"..Cc.rose.."[PROGRES] Brak danych gmcp.Char.Name.\n"); return end
    if not record or #(record.history or {})==0 then hecho("\n"..Cc.text_muted.."[PROGRES] Brak historii dla "..display..".\n"); return end
    hecho("\n\n"..Cc.lavender.."PROGRES — HISTORIA — "..tostring(record.display_name).."\n"..Cc.separator.."--------------------------------------------------")
    local first=math.max(1,#record.history-count+1)
    for i=first,#record.history do local entry=record.history[i]; local label=entry.kind=="baseline" and "punkt bazowy" or diff_text(entry.diff,Cc); hecho("\n"..Cc.text_muted..os.date("%Y-%m-%d %H:%M",entry.time).."  "..label..(entry.kind=="change" and (Cc.text_muted.."  | XP "..Cc.peach..fmt_int(entry.xp_since_previous or 0)) or "")) end
    finish_output()
end
function P:show_characters()
    local Cc=colors(); hecho("\n\n"..Cc.lavender.."PROGRES — POSTACIE\n"..Cc.separator.."------------------------------------------")
    local list={}; for _,record in pairs(self.data.characters or {}) do list[#list+1]=record end
    table.sort(list,function(a,b) return tostring(a.display_name)<tostring(b.display_name) end)
    if #list==0 then hecho("\n"..Cc.text_muted.."Brak zapisanych postaci.\n"); return end
    for _,record in ipairs(list) do hecho("\n"..Cc.mint..tostring(record.display_name or record.key)..Cc.text_muted.."  XP "..Cc.peach..fmt_int(record.tracked_xp or 0)..Cc.text_muted.."  zmian "..Cc.text..tostring(math.max(0,#(record.history or {})-1))) end
    finish_output()
end
function P:help()
    local Cc=colors(); local rows={{"/progres","aktualna postać"},{"/progres historia [N]","ostatnie zmiany"},{"/progres postacie","zapisane postacie"},{"/cechy info","alias do /progres"},{"/cechy historia [N]","alias historii"},{"/progres pomoc","ta pomoc"}}
    local w=0; for _,row in ipairs(rows) do w=math.max(w,text_width(row[1])) end; w=w+2
    hecho("\n\n"..Cc.lavender.."PROGRES — POMOC")
    for _,row in ipairs(rows) do hecho("\n"..Cc.text..pad(row[1],w)..Cc.text_muted..row[2]) end
    finish_output()
end

for _,id in ipairs(P.alias_ids) do pcall(killAlias,id) end
P.alias_ids={}
if U and U.replace_handler then
    U.replace_handler(P,"xp","chimeraVipXpGained",function(_,amount) P:on_xp(amount) end)
    U.replace_handler(P,"stats","chimeraVipStatsUpdated",function(_,snapshot) P:on_stats(snapshot) end)
    U.replace_handler(P,"char_name","gmcp.Char.Name",function() P:flush_pending_xp() end)
else P.handlers=P.handlers or {} end
P.alias_ids[#P.alias_ids+1]=tempAlias([[^/progres$]],function() P:show_info() end)
P.alias_ids[#P.alias_ids+1]=tempAlias([[^/progres historia(?:\s+(\d+))?$]],function() P:show_history(matches[2]) end)
P.alias_ids[#P.alias_ids+1]=tempAlias([[^/progres postacie$]],function() P:show_characters() end)
P.alias_ids[#P.alias_ids+1]=tempAlias([[^/progres (?:help|pomoc)$]],function() P:help() end)
P.alias_ids[#P.alias_ids+1]=tempAlias([[^/cechy info$]],function() P:show_info() end)
P.alias_ids[#P.alias_ids+1]=tempAlias([[^/cechy historia(?:\s+(\d+))?$]],function() P:show_history(matches[2]) end)
P:load(); P:flush_pending_xp()
return P
