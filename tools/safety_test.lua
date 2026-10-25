-- 0.178 safety contract test, deterministic fake Mudlet profile and filesystem.
local home="/fake/profile"
local dir=home.."/ChimeraVIP-data"
local dirs={[home]=true}
local files={}
local fail_write=nil
local function attr(path)
    if dirs[path] then return {mode="directory"} end
    if files[path]~=nil then return {mode="file"} end
    return nil
end
local fs={}
function fs.attributes(path) return attr(path) end
function fs.dir(path)
    assert(dirs[path],"Not a directory")
    local entries={".",".."}
    local found={}
    for key in pairs(files) do
        local name=key:match("^"..path:gsub("([^%w])","%%%1").."/([^/]+)$")
        if name and not found[name] then found[name]=true;entries[#entries+1]=name end
    end
    for key in pairs(dirs) do
        local name=key:match("^"..path:gsub("([^%w])","%%%1").."/([^/]+)$")
        if name and not found[name] then found[name]=true;entries[#entries+1]=name end
    end
    local index=0
    return function()
        index=index+1
        return entries[index]
    end
end
package.loaded.lfs=fs
function getMudletHomeDir() return home end
local real_open=io.open
io.open=function(path,mode)
    if mode=="rb" then
        if files[path]==nil then return nil,"not found" end
        return {
            read=function(_,how) assert(how=="*a");return files[path] end,
            close=function() return true end,
        }
    elseif mode=="wb" then
        if fail_write and path:find(fail_write,1,true) then
            return nil,"blocked write"
        end
        local content=""
        return {
            write=function(_,data) content=content..data;return true end,
            close=function() files[path]=content;return true end,
        }
    end
    error("Unsupported io mode: "..tostring(mode))
end
chimera_vip={util={ensure_dir=function(path)
    local p=""
    for part in path:gmatch("[^/]+") do
        p=p.."/"..part
        dirs[p]=true
    end
    return true
end}}
local S=dofile("src/core/safety.lua")
local ok,empty=S:backup()
assert(ok and empty.skipped and empty.files==0)
dirs[dir]=true
files[dir.."/settings.lua"]="return {ui=1}"
files[dir.."/room_actions.lua"]="return {rooms={}}"
files[dir.."/progression.lua"]="return {exp=9}"
files[dir.."/custom.json"]='{"custom":true}'
files[dir.."/readme.exe"]="unsafe"
dirs[dir.."/subdirectory"]=true
files[dir.."/subdirectory/hidden.lua"]="not backed"
ok,empty=S:backup()
assert(ok and not empty.skipped and empty.files==4, "Data snapshot must contain all top-level user data")
for _,name in ipairs({"settings.lua","room_actions.lua","progression.lua","custom.json"}) do
    assert(files[empty.path.."/"..name]==files[dir.."/"..name],
        "Snapshot corrupted file "..name)
end
assert(files[empty.path.."/readme.exe"]==nil and
    files[empty.path.."/hidden.lua"]==nil,"Unexpected data outside safe allowlist")
local first=empty.path
files[dir.."/settings.lua"]="return {ui=2}"
local another=assert(select(2,S:backup()))
assert(another.path~=first,"Snapshots must never overwrite each other")
assert(files[first.."/settings.lua"]=="return {ui=1}" and
    files[another.path.."/settings.lua"]=="return {ui=2}")
fail_write="/room_actions.lua"
local good,err=S:backup()
assert(not good and tostring(err):find("blocked write",1,true),
    "Backup failure must reject update")
assert(files[dir.."/room_actions.lua"]=="return {rooms={}}",
    "Backup must never alter originals")
io.open=real_open
package.loaded.lfs=nil
print("PASS 0.178 user-data snapshots, collision safety, backup-failure abort")
