-- ChimeraVIP 0.179: deploy two plugins transactionally, no Mudlet needed.
local root=os.tmpname()
os.remove(root)
assert(os.execute('mkdir -p '..string.format('%q',root))==0)
local home=root.."/profile"
local source=root.."/ChimeraVIP/plugins"
local target=home.."/chimera_wtyczki"
local function mkdir(path)
    assert(os.execute('mkdir -p '..string.format('%q',path))==0)
    return true
end
local function write(path,value)
    mkdir(assert(path:match("^(.*)/[^/]+$")))
    local file=assert(io.open(path,"wb"))
    assert(file:write(value))
    assert(file:close())
end
local function read(path)
    local f=io.open(path,"rb")
    if not f then return nil end
    local data=f:read("*a")
    f:close()
    return data
end
local plugins={
    {"chimera_vip_bridge","ChimeraVIP v5 bridge"},
    {"chimeravip_ui","ChimeraVIP 5:"}
}
function getMudletHomeDir() return home end
function cecho() end
chimera_vip={root_dir=root.."/ChimeraVIP",util={ensure_dir=mkdir}}
for _,p in ipairs(plugins) do
    write(source.."/"..p[1].."/init.lua","-- "..p[2].."\nreturn 'new'")
    write(target.."/"..p[1].."/init.lua","-- "..p[2].."\nreturn 'old'")
end
local bridge=dofile("src/integrations/chimera5.lua")
local needed=assert(bridge:needs_install())
assert(needed==true)
local original_rename=os.rename
local break_second=false
os.rename=function(a,b)
    if break_second and a:find("chimeravip_ui/init.lua.cvip-new",1,true) then
        return nil,"simulated failed installation"
    end
    return original_rename(a,b)
end
break_second=true
local ok,err=bridge:sync()
assert(not ok and tostring(err):find("simulated",1,true),
    "Second-plugin failure must report an installation error")
for _,p in ipairs(plugins) do
    local file=target.."/"..p[1].."/init.lua"
    assert(read(file)=="-- "..p[2].."\nreturn 'old'",
        "Partial plugin deployment was not rolled back: "..p[1])
    assert(read(file..".cvip-new")==nil,"Staged file was left behind")
end
break_second=false
local installed,count=bridge:sync()
assert(installed and count==2)
for _,p in ipairs(plugins) do
    assert(read(target.."/"..p[1].."/init.lua")==
        "-- "..p[2].."\nreturn 'new'")
end
local again,changed=bridge:sync()
assert(again and changed==0 and bridge:needs_install()==false,
    "Repeated updates must be safe no-ops")
write(target.."/chimeravip_ui/init.lua","-- another person's plugin")
local blocked,explanation=bridge:sync()
assert(not blocked and tostring(explanation):find("obcej wtyczki",1,true),
    "Foreign plugin files must not be overwritten")
assert(read(target.."/chimeravip_ui/init.lua")=="-- another person's plugin")
-- Even if the other plugin needs updating, preflight should block it too.
write(source.."/chimera_vip_bridge/init.lua","-- ChimeraVIP v5 bridge\nreturn 'newer'")
blocked=bridge:sync()
assert(not blocked)
assert(read(target.."/chimera_vip_bridge/init.lua")==
    "-- ChimeraVIP v5 bridge\nreturn 'new'")
-- A missing plugin is created from the owned source, without a backup.
os.remove(target.."/chimeravip_ui/init.lua")
installed,count=bridge:sync()
assert(installed and count==2)
assert(read(target.."/chimeravip_ui/init.lua"):find("return 'new'",1,true))
os.rename=original_rename
assert(os.execute('rm -rf '..string.format('%q',root))==0)
print("PASS 0.179 plugin deployment, rollback, foreign-file protection, idempotence")
