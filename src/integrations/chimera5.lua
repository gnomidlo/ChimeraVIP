-- ChimeraVIP 0.179: transactional deployment into Chimera 5 public plugin folder.
-- No modification of official sources. Any failed operation restores prior plugins.
chimera_vip=chimera_vip or {}
local C,U=chimera_vip,chimera_vip.util
C.chimera5=C.chimera5 or {}
local B=C.chimera5
local home=getMudletHomeDir()
local root=C.root_dir or (home.."/ChimeraVIP")
local plugins={
    {name="chimera_vip_bridge",marker="ChimeraVIP v5 bridge",files={"init.lua"}},
    {name="chimeravip_ui",marker="ChimeraVIP 5:",files={
        "theme.lua","actions.lua","conditions.lua","footer.lua","layout.lua","init.lua"}},
}
local function path(p,source,relative)
    local base=source and root.."/plugins" or home.."/chimera_wtyczki"
    return base.."/"..p.name.."/"..(relative or "init.lua")
end
local function read(location)
    local file=io.open(location,"rb")
    if not file then return nil end
    local data=file:read("*a")
    file:close()
    return data
end
local function write(location,data)
    local file,err=io.open(location,"wb")
    if not file then return false,err end
    local ok,result=pcall(function() return file:write(data) end)
    local closed,close_error=file:close()
    if not ok or not result or not closed then
        return false,tostring(result or close_error)
    end
    return true
end
local function clean(paths)
    for _,p in ipairs(paths) do pcall(os.remove,p) end
end
-- Preflight every plugin before ANY target is changed.
function B:plan()
    local changed={}
    for _,plugin in ipairs(plugins) do
      for _,relative in ipairs(plugin.files) do
        local source=read(path(plugin,true,relative))
        local target=path(plugin,false,relative)
        if not source then
            return nil,"Brak pliku zrodlowego "..plugin.name
        end
        if not source:find(plugin.marker,1,true) then
            return nil,"Nieznany plik zrodlowy "..plugin.name
        end
        local chunk,syntax_error=loadstring(source,"@"..path(plugin,true,relative))
        if not chunk then return nil,"Blad skladni "..relative..": "..tostring(syntax_error) end
        local existing=read(target)
        if existing and not existing:find(plugin.marker,1,true) then
            return nil,"Nie nadpisuje obcej wtyczki: "..plugin.name
        end
        if source~=existing then
            changed[#changed+1]={name=plugin.name.."/"..relative,target=target,data=source}
        end
      end
    end
    return changed
end
function B:needs_install()
    local changes,err=self:plan()
    if not changes then return nil,err end
    return #changes>0
end
local function restore(items)
    local failures={}
    for i=#items,1,-1 do
        local item=items[i]
        pcall(os.remove,item.target)
        if item.backup then
            local moved,err=os.rename(item.backup,item.target)
            if not moved then
                failures[#failures+1]=item.name..": "..tostring(err)
            end
        end
    end
    return #failures==0,table.concat(failures,", ")
end
-- Returns ok, changed_count_or_error. Idempotent and rollback-capable.
function B:sync()
    local changes,err=self:plan()
    if not changes then return false,err end
    if #changes==0 then return true,0 end
    local temps={}
    for _,item in ipairs(changes) do
        local dir=item.target:match("^(.*)[/\\][^/\\]+$")
        if not dir or not U.ensure_dir(dir) then
            clean(temps)
            return false,"Nie moge utworzyc katalogu "..tostring(dir)
        end
        local temp=item.target..".cvip-new"
        if read(temp)~=nil then
            clean(temps)
            return false,"Zalegly plik tymczasowy: "..temp
        end
        local ok,write_err=write(temp,item.data)
        if not ok or read(temp)~=item.data then
            clean(temps)
            pcall(os.remove,temp)
            return false,"Nie mozna przygotowac "..item.name..": "..tostring(write_err or "weryfikacja")
        end
        item.temp=temp
        temps[#temps+1]=temp
    end
    local committed={}
    local function abort(message,current)
        if current then committed[#committed+1]=current end
        local restored,restore_err=restore(committed)
        clean(temps)
        return false,message..(restored and "" or
            " | UWAGA: przywracanie nie powiodlo sie: "..restore_err)
    end
    for i,item in ipairs(changes) do
        -- Unique on-disk backup for a crash between the two renames.
        local old=read(item.target)
        if old then
            local suffix=tostring(os.time()).."-"..tostring(i)
            local backup=item.target..".cvip-backup-"..suffix
            local index=0
            while read(backup)~=nil and index<99 do
                index=index+1
                backup=item.target..".cvip-backup-"..suffix.."-"..index
            end
            if read(backup)~=nil then
                return abort("Brak bezpiecznej nazwy kopii "..item.name)
            end
            local moved,move_err=os.rename(item.target,backup)
            if not moved then
                return abort("Nie moge zabezpieczyc "..item.name..": "..tostring(move_err))
            end
            item.backup=backup
        end
        local moved,move_err=os.rename(item.temp,item.target)
        if not moved then
            return abort("Nie moge zainstalowac "..item.name..": "..tostring(move_err),item)
        end
        committed[#committed+1]=item
    end
    clean(temps)
    for _,item in ipairs(committed) do
        if item.backup then pcall(os.remove,item.backup) end
    end
    return true,#committed
end
function B:status()
    local planned,err=self:plan()
    for _,plugin in ipairs(plugins) do
        local target=path(plugin,false)
        cecho("\n<aquamarine>[ChimeraVIP]<reset> "..plugin.name..": "..
            (read(target) and "zainstalowana" or "brak"))
    end
    if not planned then
        cecho("\n<orange>Stan wtyczek: "..tostring(err).."<reset>\n")
    elseif #planned>0 then
        cecho("\n<yellow>Wtyczki wymagaja synchronizacji ("..#planned..").<reset>\n")
    else
        cecho("\n<aquamarine>Wtyczki zsynchronizowane.<reset>\n")
    end
end
function B:install()
    local ok,result=self:sync()
    if ok then
        cecho("\n<aquamarine>[ChimeraVIP]<reset> Wtyczki gotowe ("..
            tostring(result).." zmienionych). Po recznej instalacji uzyj /przeladuj.\n")
    else
        cecho("\n<orange>[ChimeraVIP]<reset> "..tostring(result).."\n")
    end
    return ok
end
return B
