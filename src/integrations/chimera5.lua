-- Explicit installer of the Chimera 5 plugin bridge; never toggles official UI.
chimera_vip = chimera_vip or {}
local C, U = chimera_vip, chimera_vip.util
C.chimera5 = C.chimera5 or {}
local B = C.chimera5
B.source = (C.root_dir or (getMudletHomeDir() .. "/ChimeraVIP"))
    .. "/plugins/chimera_vip_bridge/init.lua"
B.target = getMudletHomeDir() .. "/chimera_wtyczki/chimera_vip_bridge/init.lua"

local function read(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local data = file:read("*a")
    file:close()
    return data
end

function B:status()
    local installed = read(self.target) and "tak" or "nie"
    local active = C.runtime and C.runtime:bridge() and "aktywne" or "nieaktywne"
    cecho("\n<aquamarine>[ChimeraVIP]<reset> Most API Chimera 5: "
        .. installed .. " (zainstalowany), " .. active .. " (polaczenie).\n")
    if active ~= "aktywne" then
        cecho("<light_grey>/cvip v5 instaluj, potem oficjalne /przeladuj.\n")
    end
end

function B:install()
    local source = read(self.source)
    if not source then
        cecho("\n<orange>[ChimeraVIP]<reset> Brak pliku mostu.\n")
        return false
    end
    local previous = read(self.target)
    if previous and not previous:find("ChimeraVIP v5 bridge", 1, true) then
        cecho("\n<orange>[ChimeraVIP]<reset> Obca wtyczka w katalogu mostu; nie nadpisuje jej.\n")
        return false
    end
    if previous == source then
        cecho("\n<aquamarine>[ChimeraVIP]<reset> Most aktualny. Wpisz /przeladuj.\n")
        return true
    end
    local dir = self.target:match("^(.*)[/\\][^/\\]+$")
    if not dir or not U.ensure_dir(dir) then
        cecho("\n<orange>[ChimeraVIP]<reset> Nie mozna utworzyc katalogu mostu.\n")
        return false
    end
    local file, err = io.open(self.target, "wb")
    if not file then
        cecho("\n<orange>[ChimeraVIP]<reset> " .. tostring(err) .. "\n")
        return false
    end
    local wrote, detail = file:write(source)
    local closed = file:close()
    if not wrote or not closed then
        cecho("\n<orange>[ChimeraVIP]<reset> Blad zapisu: " .. tostring(detail) .. "\n")
        return false
    end
    cecho("\n<aquamarine>[ChimeraVIP]<reset> Most zainstalowany. Wpisz /przeladuj.\n")
    return true
end
return B
