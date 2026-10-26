-- ChimeraVIP 5: actions module.
return function(ctx,S,T,gmcp,locations,resolve_exits,schedule)
local WINDOW,HEIGHT,P,EXITS,GAUGES,BUTTONS=T.WINDOW,T.HEIGHT,T.P,T.EXITS,T.GAUGES,T.BUTTONS
local clean,alpha,color,compass_html,style,alias,info=T.clean,T.alpha,T.color,T.compass_html,T.style,T.alias,T.info
local function slot_number(index,limit)
    local n=tonumber(index)
    if n and n==math.floor(n) and n>=1 and n<=limit then return n end
    return nil
end

local function trim(v)
    return tostring(v or ""):gsub("^%s+",""):gsub("%s+$","")
end
local function html_escape(v)
    return tostring(v or ""):gsub("&","&amp;"):gsub("<","&lt;")
        :gsub(">","&gt;"):gsub('"',"&quot;")
end
local function current_room_id()
    local room=gmcp.room()
    local id=type(room)=="table" and room.id
    if not id then
        local raw=rawget(_G,"gmcp")
        local fallback=type(raw)=="table" and raw.Room and raw.Room.Info
        id=type(fallback)=="table" and fallback.id
    end
    return type(id)=="string" and id~="" and id or nil
end
local db={version=2,next_id=1,rooms={},defaults={}}
local function database_path()
    if type(getMudletHomeDir)~="function" then return nil end
    local home=getMudletHomeDir()
    if type(home)~="string" or home=="" then return nil end
    local dir=home.."/ChimeraVIP-data"
    local vip=rawget(_G,"chimera_vip")
    if vip and vip.util and type(vip.util.ensure_dir)=="function" then
        vip.util.ensure_dir(dir)
    elseif type(createDirectory)=="function" then
        createDirectory(dir)
    elseif type(lfs)=="table" and type(lfs.mkdir)=="function" then
        lfs.mkdir(dir)
    end
    return dir.."/room_actions.lua"
end
local actions_path=database_path()
local function load_actions()
    if not actions_path or type(table.load)~="function" then return end
    local loaded={}
    local ok=pcall(table.load,actions_path,loaded)
    if ok and type(loaded.rooms)=="table" then
        db.rooms=loaded.rooms
        db.defaults=type(loaded.defaults)=="table" and loaded.defaults or {}
        db.next_id=math.max(1,tonumber(loaded.next_id) or 1)
    end
end
local function save_actions()
    if not actions_path or type(table.save)~="function" then
        info("Nie mozna zapisac akcji: brak table.save lub katalogu profilu.")
        return false
    end
    local ok,result=pcall(table.save,actions_path,db)
    if not ok or result==false then
        info("Blad zapisu wlasnych akcji. Sprawdz katalog ChimeraVIP-data.")
        return false
    end
    return true
end
load_actions()
local function room_records(roomid,create)
    if not roomid then return nil end
    local list=db.rooms[roomid]
    if type(list)~="table" then
        if not create then return {} end
        list={}
        db.rooms[roomid]=list
    end
    return list
end
local function personal_actions()
    local rid=current_room_id()
    local records=room_records(rid,false) or {}
    local output={}
    for _,entry in ipairs(records) do
        if type(entry)=="table" and type(entry.name)=="string" and
            type(entry.value)=="string" and
            (entry.kind=="send" or entry.kind=="alias" or entry.kind=="sequence") then
            output[#output+1]=entry
        end
    end
    return output
end
local function combined_actions()
    local result={}
    local official=locations.room_actions()
    if type(official)=="table" then
        for i,entry in ipairs(official) do
            if type(entry)=="table" and type(entry.command)=="string" and
                entry.command~="" then
                result[#result+1]={source="official",index=i,
                    title=entry.command,command=entry.command,key=entry.key}
            end
        end
    end
    for _,entry in ipairs(personal_actions()) do
        result[#result+1]={source="vip",entry=entry,
            title=entry.name,command=entry.value}
    end
    return result
end
local function run_personal(entry)
    if entry.kind=="alias" then
        if type(expandAlias)~="function" then return false end
        expandAlias(entry.value,false)
    elseif entry.kind=="sequence" then
        for i,command in ipairs(entry.steps or {}) do
            local step=command
            if i==1 then
                ctx:send(command,true)
            else
                ctx:timer((i-1)*0.15,function()
                    if not S.destroyed then ctx:send(step,true) end
                end)
            end
        end
    else
        ctx:send(entry.value,true)
    end
    return true
end
-- An explicit default wins; with exactly one custom action, use it
-- automatically. Avoid ever guessing among multiple candidates.
local function map_default()
    local rid=current_room_id()
    if not rid then return nil end
    local entries=personal_actions()
    local stored=db.defaults[rid]
    if stored then
        for _,entry in ipairs(entries) do
            if tonumber(entry.id)==tonumber(stored) then return entry end
        end
        return nil
    end
    if #entries==1 then return entries[1] end
    return nil
end
local function map_default_name()
    local entry=map_default()
    return entry and entry.name or nil
end
local function map_run()
    local entry=map_default()
    if not entry then return false end
    return run_personal(entry)
end
local function delete_action(roomid,id)
    if current_room_id()~=roomid then return false end
    local records=room_records(roomid,false)
    for i,entry in ipairs(records) do
        if tonumber(entry.id)==tonumber(id) then
            table.remove(records,i)
            if db.defaults[roomid]==entry.id then db.defaults[roomid]=nil end
            if #records==0 then db.rooms[roomid]=nil end
            save_actions()
            info("Usunieto akcje: "..entry.name)
            if schedule then schedule() end
            return true
        end
    end
    return false
end
local function current_special_exits()
    if not resolve_exits then return {} end
    local exits=resolve_exits()
    local normal={gora=true,dol=true}
    for _,entry in ipairs(EXITS) do normal[entry[1]]=true end
    local result={}
    for command in pairs(exits) do
        if not normal[command] then result[#result+1]=command end
    end
    table.sort(result)
    return result
end
local function special_exit(index)
    local slot=slot_number(index,3)
    if not slot then return false end
    local command=current_special_exits()[slot]
    if not command then return false end
    ctx:send(command,true)
    return true
end
local function room_action(index)
    local slot=slot_number(index,12)
    if not slot then return false end
    local action=combined_actions()[slot]
    if not action then return false end
    if action.source=="official" then
        locations.run_action(action.index)
        return true
    end
    return run_personal(action.entry)
end
local vip=rawget(_G,"chimera_vip")
if type(vip)~="table" then
    vip={}
    _G.chimera_vip=vip
end
if type(vip.ui)~="table" then vip.ui={} end
local public_ui=vip.ui
local old_special,old_action=public_ui.special_exit,public_ui.room_action
local old_delete=public_ui.delete_action
local map_actions=type(vip.map_action)=="table" and vip.map_action or nil
local old_map_run=map_actions and map_actions._runner
local old_map_status=map_actions and map_actions._status
if map_actions then
    map_actions._runner=map_run
    map_actions._status=map_default_name
end
public_ui.special_exit=special_exit
public_ui.room_action=room_action
public_ui.delete_action=delete_action
local function usage()
    info("Akcje bieżącej lokacji:")
    cecho("<light_grey>  /cvakcja dodaj Nazwa - komenda<reset>\n")
    cecho("<light_grey>  /cvakcja alias Nazwa - alias (np. naps lub /wlm)<reset>\n")
    cecho("<light_grey>  /cvakcja sekwencja Nazwa - komenda1, komenda2, ...<reset>\n")
    cecho("<light_grey>  /cvakcja usun Nazwa<reset>\n")
    cecho("<light_grey>  /cvakcja domyslna Nazwa | brak<reset>\n")
    local selected=map_default()
    if selected then
        cecho("<199,185,232>  [⌖ Mapa]<reset> "..html_escape(selected.name).."\n")
    end
    local rid=current_room_id()
    if not rid then
        info("Brak ID lokacji w GMCP — nie moge dodawac akcji.")
        return
    end
    local records=room_records(rid,false)
    if #records==0 then
        info("Brak wlasnych akcji w tej lokacji.")
        return
    end
    for i,entry in ipairs(records) do
        local kind=entry.kind=="send" and "komenda" or
            (entry.kind=="alias" and "alias" or "sekwencja")
        local chosen=selected and entry.id==selected.id
        cecho(string.format("<lavender> %d.<reset> %s <dim_grey>(%s)<reset>%s",
            i,html_escape(entry.name),kind,
            chosen and " <199,185,232>[⌖]<reset>" or ""))
        if type(echoLink)=="function" then
            local script="chimera_vip.ui.delete_action("..
                string.format("%q",rid)..","..tostring(entry.id)..")"
            echoLink(" [usun]",script,"Usun: "..entry.name,true)
        else
            cecho(" [usun: /cvakcja usun "..entry.name.."]")
        end
        cecho("\n")
    end
end
ctx:command{"cvakcja",args="[dodaj|alias|sekwencja|usun|domyslna] ...",
    help="Wlasne akcje przypisane do aktualnej lokacji",fn=function(arg)
        local input=trim(arg)
        if input=="" or input=="pomoc" or input=="lista" then
            usage()
            return
        end
        local op,rest=input:match("^(%S+)%s+(.+)$")
        if input=="domyslna" then
            local selected=map_default()
            if selected then
                cecho("\n<199,185,232>[⌖ Mapa]<reset> Domyslna: "..html_escape(selected.name).."\n")
            else
                info("Brak domyslnej akcji mapowej w tym pokoju.")
            end
            return
        end
        if not op then usage(); return end
        if op=="domyslna" then
            local rid=current_room_id()
            if not rid then info("Brak ID lokacji GMCP."); return end
            local name=trim(rest)
            if name:lower()=="brak" then
                db.defaults[rid]=nil
                save_actions()
                info("Usunieto domyslna akcje mapowa.")
                if schedule then schedule() end
                return
            end
            for _,entry in ipairs(personal_actions()) do
                if entry.name:lower()==name:lower() then
                    db.defaults[rid]=entry.id
                    if save_actions() then
                        cecho("\n<199,185,232>[⌖ Mapa]<reset> Domyslna: "..
                            html_escape(entry.name).."\n")
                    end
                    if schedule then schedule() end
                    return
                end
            end
            info("Nie znaleziono takiej wlasnej akcji w pokoju.")
            return
        end
        if op=="usun" then
            local rid=current_room_id()
            if not rid then info("Brak ID lokacji GMCP."); return end
            local records=room_records(rid,false)
            for _,entry in ipairs(records) do
                if entry.name:lower()==trim(rest):lower() then
                    delete_action(rid,entry.id)
                    return
                end
            end
            info("Nie znaleziono takiej wlasnej akcji w pokoju.")
            return
        end
        if op~="dodaj" and op~="alias" and op~="sekwencja" then
            usage()
            return
        end
        local name,value=rest:match("^(.-)%s+%-%s+(.+)$")
        name,value=trim(name),trim(value)
        if name=="" or value=="" then
            info("Skladnia: /cvakcja "..op.." Nazwa - tresc")
            return
        end
        local rid=current_room_id()
        if not rid then info("Brak ID lokacji GMCP."); return end
        local steps=nil
        if op=="sekwencja" then
            steps={}
            for part in (value..","):gmatch("(.-),") do
                part=trim(part)
                if part=="" then
                    info("Sekwencja nie moze zawierac pustych krokow.")
                    return
                end
                steps[#steps+1]=part
            end
        end
        local records=room_records(rid,true)
        local entry=nil
        for _,item in ipairs(records) do
            if item.name:lower()==name:lower() then entry=item; break end
        end
        if entry==nil then
            entry={id=db.next_id}
            db.next_id=db.next_id+1
            records[#records+1]=entry
        end
        entry.name=name
        entry.kind=op=="dodaj" and "send" or (op=="sekwencja" and "sequence" or op)
        entry.value=value
        entry.steps=steps
        if save_actions() then
            info("Zapisano akcje '"..name.."' dla obecnej lokacji.")
        end
        if schedule then schedule() end
    end}

local function cleanup()
            if public_ui.delete_action==delete_action then
                public_ui.delete_action=old_delete
            end
            if map_actions and map_actions._runner==map_run then
                map_actions._runner=old_map_run
            end
            if map_actions and map_actions._status==map_default_name then
                map_actions._status=old_map_status
            end
            if public_ui.special_exit==special_exit then
                public_ui.special_exit=old_special
            end
            if public_ui.room_action==room_action then
                public_ui.room_action=old_action
            end
end
return {special_exit=special_exit, room_action=room_action, combined_actions=combined_actions,
 current_special_exits=current_special_exits, map_default_name=map_default_name, cleanup=cleanup}
end
