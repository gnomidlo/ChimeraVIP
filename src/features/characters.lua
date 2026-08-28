-- ChimeraVIP / Characters
-- Rejestr odmian postaci, relacji i kolorowania nazw.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
C.characters = C.characters or {}
chimera_overlay.characters = C.characters
local R = C.characters

R.trigger_ids = R.trigger_ids or {}
R.alias_ids = R.alias_ids or {}
R.handlers = R.handlers or {}
R.highlight_trigger = R.highlight_trigger or nil
R.capture_timer = R.capture_timer or nil
R.form_index = R.form_index or {}
R.highlight_entries = R.highlight_entries or {}
R.data_dir = getMudletHomeDir() .. "/ChimeraVIP-data"
R.data_file = R.data_dir .. "/characters.lua"

R.case_order={"mianownik","dopelniacz","celownik","biernik","narzednik","miejscownik"}
R.case_labels={Mianownik="mianownik",Dopelniacz="dopelniacz",Celownik="celownik",Biernik="biernik",Narzednik="narzednik",Miejscownik="miejscownik"}
R.groups={przyjaciele={label="przyjaciel",highlight_priority=2},neutralni={label="neutralny",highlight_priority=1},wrogowie={label="wrog",highlight_priority=3}}
R.group_aliases={p="przyjaciele",przyjaciel="przyjaciele",przyjaciele="przyjaciele",n="neutralni",neutralny="neutralni",neutralni="neutralni",w="wrogowie",wrog="wrogowie",["wróg"]="wrogowie",wrogowie="wrogowie",brak="",nieprzypisany="",nieprzypisani="",["?"]=""}
R.defaults={version=2,highlight_enabled=true,colors={przyjaciele="#A8DCC2",neutralni="#D8DCE6",wrogowie="#F0A8B8"},people={}}
local ANSI16={[0]={0,0,0},[1]={128,0,0},[2]={0,128,0},[3]={128,128,0},[4]={0,0,128},[5]={128,0,128},[6]={0,128,128},[7]={192,192,192},[8]={128,128,128},[9]={255,0,0},[10]={0,255,0},[11]={255,255,0},[12]={0,0,255},[13]={255,0,255},[14]={0,255,255},[15]={255,255,255}}

local function copy(v) if type(v)~="table" then return v end; local t={}; for k,c in pairs(v) do t[k]=copy(c) end; return t end
local function merge_defaults(target,defaults) for k,v in pairs(defaults or {}) do if type(v)=="table" then if type(target[k])~="table" then target[k]={} end; merge_defaults(target[k],v) elseif target[k]==nil then target[k]=v end end end
local function trim(v) return tostring(v or ""):gsub("^%s+",""):gsub("%s+$","") end
local function normalize(v) return trim(v):lower():gsub("%s+"," ") end
local function utf8_len(v) if U and U.text_width then return U.text_width(v) end; local s=tostring(v or ""); if utf8 and type(utf8.len)=="function" then local ok,n=pcall(utf8.len,s); if ok and n then return n end end; return #s end
local function pad(v,w) if U and U.pad_right then return U.pad_right(v,w) end; local s=tostring(v or ""); return s..string.rep(" ",math.max(0,w-#s)) end
local function pcre_escape(v) return (tostring(v):gsub("([\\%^%$%.|%?%*%+%(%)%[%]{}])","\\%1")) end
local function palette() if C.pastel_ui and C.pastel_ui.colors then return C.pastel_ui.colors end; return {text="#D8DCE6",text_muted="#AEB6C5",mint="#A8DCC2",blue="#AFCBF4",lavender="#C7B9E8",peach="#F2C4A0",yellow="#EFD8A6",rose="#F0A8B8",separator="#2B303C"} end
local function out(text,color) hecho("\n"..(color or palette().text_muted)..tostring(text or "").."\n") end
local function finish_output() hecho("\n") end

function R:is_module_enabled() if C.settings and type(C.settings.is_module_enabled)=="function" then return C.settings:is_module_enabled("postacie",true) end; return true end
function R:normalize_group(value) local key=normalize(value); if self.group_aliases[key]~=nil then return self.group_aliases[key] end; if self.groups[key] then return key end; return nil end
function R:color_to_rgb(value)
    if type(value)=="string" then local hex=value:match("^#?(%x%x%x%x%x%x)$"); if hex then return tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16) end end
    local index=tonumber(value); if not index or index<0 or index>255 or index~=math.floor(index) then return nil end
    if index<16 then return unpack(ANSI16[index]) end
    if index<232 then local cube=index-16; local r=math.floor(cube/36); local g=math.floor((cube%36)/6); local b=cube%6; local levels={0,95,135,175,215,255}; return levels[r+1],levels[g+1],levels[b+1] end
    local gray=8+(index-232)*10; return gray,gray,gray
end
function R:save() if U and U.ensure_dir then U.ensure_dir(self.data_dir) end; local ok,err=pcall(table.save,self.data_file,self.data); if not ok then out("[Postacie] Nie udalo sie zapisac bazy: "..tostring(err),palette().rose); return false end; return true end
function R:load()
    self.data=copy(self.defaults); if U and U.ensure_dir then U.ensure_dir(self.data_dir) end
    if U and U.file_exists and U.file_exists(self.data_file) then
        local loaded={}; local ok,err=pcall(table.load,self.data_file,loaded)
        if ok and type(loaded)=="table" then if loaded.highlight_enabled==nil and loaded.enabled~=nil then loaded.highlight_enabled=loaded.enabled~=false end; loaded.enabled=nil; merge_defaults(loaded,self.defaults); self.data=loaded else out("[Postacie] Nie udalo sie wczytac bazy: "..tostring(err),palette().rose) end
    end
    self.data.people=self.data.people or {}; self.data.colors=self.data.colors or copy(self.defaults.colors); self.data.highlight_enabled=self.data.highlight_enabled~=false; self.data.version=2
    for _,person in pairs(self.data.people) do if person.highlight==nil then person.highlight=true end; if person.group and not self.groups[person.group] then person.group=nil end end
    self:rebuild_cache(); self:save()
end
function R:rebuild_cache()
    self.form_index={}; local unique={}
    for key,person in pairs(self.data.people or {}) do
        for _,form in pairs(person.forms or {}) do
            local identity=normalize(form)
            if identity~="" then
                local previous=self.form_index[identity]; local priority=person.group and self.groups[person.group] and self.groups[person.group].highlight_priority or 0; local prev_priority=previous and previous.group and self.groups[previous.group] and self.groups[previous.group].highlight_priority or -1
                if not previous or priority>prev_priority then self.form_index[identity]={key=key,group=person.group,form=form} end
                if person.highlight~=false and person.group and self.groups[person.group] then local old=unique[identity]; local old_priority=old and self.groups[old.group] and self.groups[old.group].highlight_priority or -1; if not old or priority>old_priority then unique[identity]={form=form,group=person.group,key=key} end end
            end
        end
    end
    self.highlight_entries={}; for _,entry in pairs(unique) do self.highlight_entries[#self.highlight_entries+1]=entry end
    table.sort(self.highlight_entries,function(a,b) local al,bl=utf8_len(a.form),utf8_len(b.form); if al==bl then return normalize(a.form)<normalize(b.form) end; return al>bl end)
end
function R:find_person(name_or_form) local wanted=normalize(name_or_form); if wanted=="" then return nil,nil end; if self.data.people[wanted] then return self.data.people[wanted],wanted end; local indexed=self.form_index[wanted]; if indexed then return self.data.people[indexed.key],indexed.key end; return nil,nil end
function R:get(name_or_form,case_name) local person=self:find_person(name_or_form); if not person then return nil end; case_name=normalize(case_name or "mianownik"); if case_name=="name" or case_name=="nazwa" then case_name="mianownik" end; return person.forms and person.forms[case_name] or nil end
function R:begin_capture(name) if not self:is_module_enabled() then return end; if self.capture_timer then pcall(killTimer,self.capture_timer) end; self.capture={name=trim(name),forms={}}; self.capture_timer=tempTimer(15,function() R.capture=nil; R.capture_timer=nil end) end
function R:on_case(label,value) if not self.capture then return end; local case_name=self.case_labels[label]; if not case_name then return end; value=trim(value):gsub("[,%.]+$",""); if value=="" then return end; self.capture.forms[case_name]=value; for _,required in ipairs(self.case_order) do if not self.capture.forms[required] then return end end; self:finish_capture() end
function R:finish_capture()
    local captured=self.capture; if not captured then return end
    local nominative=captured.forms.mianownik or captured.name; local existing,old_key=self:find_person(nominative); local key=normalize(nominative); local now=os.time(); if old_key and old_key~=key then self.data.people[old_key]=nil end
    local highlight=true; if existing and existing.highlight~=nil then highlight=existing.highlight==true end
    self.data.people[key]={name=nominative,forms=copy(captured.forms),group=existing and existing.group or nil,highlight=highlight,added_at=existing and existing.added_at or now,updated_at=now}
    self.capture=nil; if self.capture_timer then pcall(killTimer,self.capture_timer) end; self.capture_timer=nil
    self:save(); self:rebuild_cache(); self:rebuild_highlight_trigger(); raiseEvent("chimeraVipCharactersUpdated",nominative,self.data.people[key].group)
    local action=existing and "Zaktualizowano odmiane" or "Zapisano nowa postac"
    hecho("\n"..palette().mint.."[Postacie] "..action..": "..nominative..".\n"..palette().text_muted.."Relacja: "); self:print_group_links(nominative); finish_output()
end
function R:set_group(name_or_form,group)
    local normalized=self:normalize_group(group); if normalized==nil then out("[Postacie] Grupa: przyjaciele/p, neutralni/n, wrogowie/w albo brak/? .",palette().rose); return false end
    local person=self:find_person(name_or_form); if not person then out("[Postacie] Nie znam postaci: "..trim(name_or_form)..". Najpierw uzyj odmien <imie>.",palette().rose); return false end
    person.group=normalized~="" and normalized or nil; person.updated_at=os.time(); self:save(); self:rebuild_cache(); self:rebuild_highlight_trigger(); raiseEvent("chimeraVipCharactersUpdated",person.name,person.group); out("[Postacie] "..person.name.." -> "..(person.group or "nieprzypisany")..".",palette().mint); return true
end
function R:set_person_highlight(name_or_form,enabled) local person=self:find_person(name_or_form); if not person then out("[Postacie] Nie znam postaci: "..trim(name_or_form)..".",palette().rose); return false end; person.highlight=enabled==true; person.updated_at=os.time(); self:save(); self:rebuild_cache(); self:rebuild_highlight_trigger(); out("[Postacie] Highlight "..person.name..": "..(person.highlight and "ON" or "OFF")..".",palette().mint); return true end
function R:remove(name_or_form) local person,key=self:find_person(name_or_form); if not person then out("[Postacie] Nie znam postaci: "..trim(name_or_form)..".",palette().rose); return false end; self.data.people[key]=nil; self:save(); self:rebuild_cache(); self:rebuild_highlight_trigger(); raiseEvent("chimeraVipCharactersUpdated",person.name,nil); out("[Postacie] Usunieto: "..person.name..".",palette().yellow); return true end
function R:set_color(group,value)
    group=self:normalize_group(group); if not group or group=="" then out("[Postacie] Kolor mozna ustawic dla: przyjaciele, neutralni, wrogowie.",palette().rose); return false end
    local r,g,b=self:color_to_rgb(value); if not r then out("[Postacie] Kolor podaj jako numer 0-255 albo #RRGGBB.",palette().rose); return false end
    local stored=tonumber(value); if not stored then stored=("#"..tostring(value):gsub("^#","")):upper() end; self.data.colors[group]=stored; self:save(); local preview=string.format("#%02X%02X%02X",r,g,b)
    hecho("\n"..palette().mint.."[Postacie] Kolor "..group..": "..palette().text..tostring(stored).."  "..preview.."przyklad\n"); return true
end
function R:set_highlight_enabled(enabled) self.data.highlight_enabled=enabled==true; self:save(); self:rebuild_highlight_trigger(); out("[Postacie] Kolorowanie "..(self.data.highlight_enabled and "wlaczone." or "wylaczone."),palette().mint) end
function R:print_group_links(name)
    echoLink("[PRZYJACIEL]",string.format("chimera_vip.characters:set_group(%q,'p')",name),"Przypisz do przyjaciol",true); echo(" ")
    echoLink("[NEUTRALNY]",string.format("chimera_vip.characters:set_group(%q,'n')",name),"Przypisz do neutralnych",true); echo(" ")
    echoLink("[WROG]",string.format("chimera_vip.characters:set_group(%q,'w')",name),"Przypisz do wrogow",true); echo(" ")
    echoLink("[BRAK]",string.format("chimera_vip.characters:set_group(%q,'?')",name),"Pozostaw bez przypisanej relacji",true)
end
function R:show(filter)
    filter=normalize(filter); local wanted=nil
    if filter~="" then wanted=self:normalize_group(filter); if wanted==nil then out("[Postacie] Filtr: przyjaciele, neutralni, wrogowie albo nieprzypisani.",palette().rose); return end end
    local people={}; for _,person in pairs(self.data.people) do local group=person.group or ""; if filter=="" or group==wanted then people[#people+1]=person end end
    table.sort(people,function(a,b) return normalize(a.name)<normalize(b.name) end)
    local P=palette(); hecho("\n\n"..P.lavender.."POSTACIE"..(filter~="" and " — "..(wanted~="" and wanted:upper() or "NIEPRZYPISANI") or "").."\n"..P.separator.."-------------------------------------------------------")
    if #people==0 then hecho("\n"..P.text_muted.."Brak zapisanych postaci.") end
    for _,person in ipairs(people) do local group=person.group or "nieprzypisany"; local color=P.text_muted; if person.group then local r,g,b=self:color_to_rgb(self.data.colors[person.group]); if r then color=string.format("#%02X%02X%02X",r,g,b) end end; hecho("\n"..color..person.name..P.text_muted.."  ["..group.."]"..(person.highlight==false and " [HL OFF]" or "").." "); self:print_group_links(person.name) end
    hecho("\n"..P.separator.."-------------------------------------------------------\n"..P.text_muted.."Modul: "..(self:is_module_enabled() and P.mint.."ON" or P.rose.."OFF")..P.text_muted.."  Kolorowanie: "..(self.data.highlight_enabled and P.mint.."ON" or P.rose.."OFF")); finish_output()
end
function R:show_info(name_or_form)
    local person=self:find_person(name_or_form); if not person then out("[Postacie] Nie znam postaci: "..trim(name_or_form)..".",palette().rose); return end
    local P=palette(); hecho("\n\n"..P.lavender.."POSTAC — "..person.name:upper().."\n"..P.separator.."------------------------------------------\n"..P.text_muted.."Grupa        "..P.text..(person.group or "nieprzypisany").."\n"..P.text_muted.."Highlight    "..P.text..(person.highlight~=false and "ON" or "OFF"))
    local w=0; for _,case_name in ipairs(self.case_order) do w=math.max(w,utf8_len(case_name)) end; w=w+2
    for _,case_name in ipairs(self.case_order) do hecho("\n"..P.text_muted..pad(case_name,w)..P.text..tostring(person.forms[case_name] or "-")) end
    hecho("\n"..P.text_muted); self:print_group_links(person.name); finish_output()
end
function R:search(query)
    local q=normalize(query); if q=="" then self:show(); return end
    local found={}; for _,person in pairs(self.data.people) do local hit=normalize(person.name):find(q,1,true)~=nil; if not hit then for _,form in pairs(person.forms or {}) do if normalize(form):find(q,1,true) then hit=true; break end end end; if hit then found[#found+1]=person end end
    table.sort(found,function(a,b) return normalize(a.name)<normalize(b.name) end); local P=palette(); hecho("\n\n"..P.lavender.."POSTACIE — SZUKAJ: "..query.."\n"..P.separator.."------------------------------------------")
    if #found==0 then hecho("\n"..P.text_muted.."Brak wynikow.\n"); return end
    for _,person in ipairs(found) do hecho("\n"..P.text..person.name..P.text_muted.."  ["..(person.group or "nieprzypisany").."]") end; finish_output()
end
local function byte_to_char_index(text,byte_index) if byte_index<=1 then return 0 end; return utf8_len(text:sub(1,byte_index-1)) end
function R:color_current_line()
    if not self:is_module_enabled() or not self.data.highlight_enabled or self.capture then return end
    local current=tostring(getCurrentLine() or ""); if current=="" then return end; local occupied={}
    for _,entry in ipairs(self.highlight_entries) do local start_at=1; while true do local first,last=current:find(entry.form,start_at,true); if not first then break end; local before=first>1 and current:sub(first-1,first-1) or ""; local after=last<#current and current:sub(last+1,last+1) or ""; local boundary=not before:match("[%w_]") and not after:match("[%w_]"); local char_start=byte_to_char_index(current,first); local char_len=utf8_len(current:sub(first,last)); local free=true; for pos=char_start,char_start+char_len-1 do if occupied[pos] then free=false; break end end; if boundary and free then local r,g,b=self:color_to_rgb(self.data.colors[entry.group]); if r then selectSection(char_start,char_len); setFgColor(r,g,b); resetFormat(); for pos=char_start,char_start+char_len-1 do occupied[pos]=true end end end; start_at=last+1 end end
end
function R:rebuild_highlight_trigger()
    if self.highlight_trigger then pcall(killTrigger,self.highlight_trigger) end; self.highlight_trigger=nil
    if not self:is_module_enabled() or not self.data.highlight_enabled then return end
    local forms={}; for _,entry in ipairs(self.highlight_entries) do forms[#forms+1]=entry.form end; if #forms==0 then return end
    table.sort(forms,function(a,b) return utf8_len(a)>utf8_len(b) end); for i,form in ipairs(forms) do forms[i]=pcre_escape(form) end
    self.highlight_trigger=tempRegexTrigger("(?<![A-Za-z0-9_])(?:"..table.concat(forms,"|")..")(?![A-Za-z0-9_])",[[chimera_vip.characters:color_current_line()]])
end
function R:show_help()
    local P=palette(); local rows={{"odmien <imie>","zapisz lub odśwież odmianę"},{"/postacie","lista postaci"},{"/postacie szukaj <tekst>","szukaj po imieniu lub odmianie"},{"/postacie grupa <imie> p|n|w|?","przypisz relację"},{"/postacie highlight <imie> on|off","kolorowanie jednej postaci"},{"/postacie info <imie>","pokaż odmianę"},{"/postacie kolor <grupa> <0-255|#RRGGBB>","ustaw kolor"},{"/postacie usun <imie>","usuń z bazy"},{"/postacie on|off","globalny highlight"},{"/postacie pomoc","ta pomoc"}}
    local w=0; for _,row in ipairs(rows) do w=math.max(w,utf8_len(row[1])) end; w=w+2
    hecho("\n\n"..P.lavender.."POSTACIE — POMOC\n"..P.separator.."-------------------------------------------------------")
    for _,row in ipairs(rows) do hecho("\n"..P.text..pad(row[1],w)..P.text_muted..row[2]) end; finish_output()
end
function R:command(argument)
    local raw=trim(argument); local lower=raw:lower(); if raw=="" then self:show(); return end
    if lower=="help" or lower=="pomoc" then self:show_help(); return end
    if lower=="on" then self:set_highlight_enabled(true); return end; if lower=="off" then self:set_highlight_enabled(false); return end
    local normalized_filter=self:normalize_group(lower); if normalized_filter~=nil and (lower~="p" and lower~="n" and lower~="w" and lower~="?") then self:show(lower); return end
    local name,group=raw:match("^grupa%s+(.+)%s+(%S+)$"); if name then self:set_group(name,group); return end
    local hname,state=raw:match("^highlight%s+(.+)%s+(%S+)$"); if hname then self:set_person_highlight(hname,normalize(state)=="on" or normalize(state)=="1" or normalize(state)=="wlacz"); return end
    local color_group,color=raw:match("^kolor%s+(%S+)%s+(%S+)$"); if color_group then self:set_color(color_group,color); return end
    local info=raw:match("^info%s+(.+)$"); if info then self:show_info(info); return end
    local query=raw:match("^szukaj%s+(.+)$"); if query then self:search(query); return end
    local remove=raw:match("^usun%s+(.+)$"); if remove then self:remove(remove); return end; self:show_help()
end
function R:install()
    for _,id in ipairs(self.trigger_ids or {}) do pcall(killTrigger,id) end; for _,id in ipairs(self.alias_ids or {}) do pcall(killAlias,id) end
    if self.highlight_trigger then pcall(killTrigger,self.highlight_trigger) end; if self.capture_timer then pcall(killTimer,self.capture_timer) end
    self.trigger_ids,self.alias_ids={},{}; self.highlight_trigger,self.capture_timer,self.capture=nil,nil,nil
    if self:is_module_enabled() then self.trigger_ids[#self.trigger_ids+1]=tempRegexTrigger([[^(.+?) odmienia sie nastepujaco:$]],function() R:begin_capture(matches[2]) end); self.trigger_ids[#self.trigger_ids+1]=tempRegexTrigger([[^\s*(Mianownik|Dopelniacz|Celownik|Biernik|Narzednik|Miejscownik)\s*:\s*(.+?)\s*$]],function() R:on_case(matches[2],matches[3]) end) end
    self.alias_ids[#self.alias_ids+1]=tempAlias([[^/postacie(?:\s+(.*))?$]],function() R:command(matches[2] or "") end); self:rebuild_highlight_trigger()
end
if C.settings and type(C.settings.register_module)=="function" then C.settings:register_module("postacie",{title="Postacie",description="Rejestr odmian, relacji i kolorowanie nazw.",default=true}) end
if U and U.replace_handler then U.replace_handler(R,"module_changed","chimeraVipModuleChanged",function(_,id) if tostring(id)=="postacie" then R:install() end end) end
if C.help and type(C.help.register)=="function" then C.help:register("postacie",{title="POSTACIE I RELACJE",description={"Wynik komendy 'odmien <imie>' zapisuje wszystkie szesc form imienia.","Nowa postac pozostaje nieprzypisana, dopoki nie wybierzesz relacji: przyjaciel, neutralny albo wrog.","Modul utrzymuje szybki indeks wszystkich odmian i cache highlightow; baza jest zapisywana w ChimeraVIP-data/characters.lua.","API dla innych modulow: chimera_vip.characters:get(<imie>, <przypadek>)."},commands={{"odmien <imie>","zapisz albo odswiez odmiane"},{"/postacie","lista postaci"},{"/postacie szukaj <tekst>","szukaj po nazwie lub odmianie"},{"/postacie grupa <imie> p|n|w|?","ustaw relacje lub brak"},{"/postacie highlight <imie> on|off","kolorowanie konkretnej postaci"},{"/postacie info <imie>","pokaz wszystkie formy"}}}) end
R:load(); R:install(); raiseEvent("chimeraVipCharactersReady",R.data)
return R
