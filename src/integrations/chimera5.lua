-- ChimeraVIP v5 plugin installer. Public Chimera plugin directory only.
chimera_vip=chimera_vip or {}
local C,U=chimera_vip,chimera_vip.util
C.chimera5=C.chimera5 or {}
local B=C.chimera5
local home=getMudletHomeDir()
local root=C.root_dir or (home.."/ChimeraVIP")
local plugins={
    {name="chimera_vip_bridge", marker="ChimeraVIP v5 bridge"},
    {name="chimeravip_ui", marker="ChimeraVIP 5:"},
}
local function path(p,source)
    local base=source and root.."/plugins" or home.."/chimera_wtyczki"
    return base.."/"..p.name.."/init.lua"
end
local function read(location)
    local file=io.open(location,"rb")
    if not file then return nil end
    local text=file:read("*a")
    file:close()
    return text
end
function B:status()
    for _,plugin in ipairs(plugins) do
        local target=path(plugin,false)
        cecho("\n<aquamarine>[ChimeraVIP]<reset> "..plugin.name..": "
            ..(read(target) and "zainstalowana" or "brak"))
    end
    local bridge=C.runtime and C.runtime:bridge() and "aktywny" or "nieaktywny"
    cecho("\n<light_grey>Most API: "..bridge
        ..". HUD: /cvhud vip | /cvhud oficjalny | /cvhud ustawienia\n")
end
function B:install()
    local copied=0
    for _,plugin in ipairs(plugins) do
        local source=read(path(plugin,true))
        local target=path(plugin,false)
        if not source then
            cecho("\n<orange>[ChimeraVIP]<reset> Brak pliku "..plugin.name..".\n")
            return false
        end
        local existing=read(target)
        if existing and not existing:find(plugin.marker,1,true) then
            cecho("\n<orange>[ChimeraVIP]<reset> Nie nadpisuje obcej wtyczki: "
                ..plugin.name.."\n")
            return false
        end
        if existing~=source then
            local dir=target:match("^(.*)[/\\][^/\\]+$")
            if not dir or not U.ensure_dir(dir) then
                cecho("\n<orange>[ChimeraVIP]<reset> Nie moge utworzyc "..dir.."\n")
                return false
            end
            local f,err=io.open(target,"wb")
            if not f then
                cecho("\n<orange>[ChimeraVIP]<reset> Blad: "..tostring(err).."\n")
                return false
            end
            local written,werr=f:write(source)
            local closed,cerr=f:close()
            if not written or not closed then
                cecho("\n<orange>[ChimeraVIP]<reset> Blad zapisu: "
                    ..tostring(werr or cerr).."\n")
                return false
            end
            copied=copied+1
        end
    end
    cecho("\n<aquamarine>[ChimeraVIP]<reset> Wtyczki gotowe (zaktualizowano "
        ..copied.."). Wpisz oficjalne /przeladuj.\n")
    return true
end
return B
