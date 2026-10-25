-- ChimeraVIP 0.178: user-data safety before destructive migrations.
-- Backups contain ONLY top-level files in ChimeraVIP-data. Never
-- overwrite source files, never delete backups, never execute saved Lua.
chimera_vip=chimera_vip or {}
local C=chimera_vip
local U=assert(C.util,"ChimeraVIP util required")
C.safety=C.safety or {}
local S=C.safety

local function data_root()
    return getMudletHomeDir().."/ChimeraVIP-data"
end

local function available_files(dir,fs)
    local names={}
    local ok,iter,state=pcall(fs.dir,dir)
    if not ok or type(iter)~="function" then
        return nil,"Nie moge odczytac katalogu ChimeraVIP-data."
    end
    for name in iter,state do
        if type(name)=="string"
            and name:match("^[%w_%-]+%.[%w_%-]+$")
            and (name:match("%.lua$") or name:match("%.json$")
                or name:match("%.db$") or name:match("%.txt$")) then
            local path=dir.."/"..name
            local attr=fs.attributes(path)
            if attr and attr.mode=="file" then names[#names+1]=name end
        end
    end
    table.sort(names)
    return names
end

local function copy_file(src,dst)
    local input,open_error=io.open(src,"rb")
    if not input then return false,"Odczyt "..src..": "..tostring(open_error) end
    local data,read_error=input:read("*a")
    input:close()
    if data==nil then return false,"Odczyt "..src..": "..tostring(read_error) end
    local output,write_error=io.open(dst,"wb")
    if not output then return false,"Zapis "..dst..": "..tostring(write_error) end
    local written,err=output:write(data)
    local closed,close_err=output:close()
    if not written or not closed then
        return false,"Zapis "..dst..": "..tostring(err or close_err)
    end
    return true
end

-- Returns: ok, {path=absolute,files=count,skipped=boolean} or error.
-- Directories are unique even for two updates within one second.
function S:backup()
    local dir=data_root()
    local ok_fs,fs=pcall(require,"lfs")
    if not ok_fs or type(fs)~="table" then
        return false,"Brak lfs. Nie wykonuje aktualizacji bez kopii danych."
    end
    local attr=fs.attributes(dir)
    if not attr then return true,{files=0,skipped=true} end
    if attr.mode~="directory" then
        return false,"ChimeraVIP-data nie jest katalogiem."
    end
    local names,err=available_files(dir,fs)
    if not names then return false,err end
    if #names==0 then return true,{files=0,skipped=true} end
    local root=dir.."/backups"
    local stamp=os.date("%Y%m%d-%H%M%S")
    local dest
    for i=0,99 do
        local candidate=root.."/cvip-"..stamp..(i>0 and ("-"..i) or "")
        if not fs.attributes(candidate) then
            dest=candidate
            break
        end
    end
    if not dest then return false,"Nie mozna wyznaczyc nowego katalogu kopii." end
    if not U.ensure_dir(dest) or not (fs.attributes(dest) and
        fs.attributes(dest).mode=="directory") then
        return false,"Nie mozna utworzyc "..dest
    end
    for _,name in ipairs(names) do
        local copied,copy_err=copy_file(dir.."/"..name,dest.."/"..name)
        if not copied then return false,copy_err end
    end
    return true,{path=dest,files=#names,skipped=false}
end

return S
