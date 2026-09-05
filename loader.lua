-- ChimeraVIP persistent loader
-- Wklej ten plik RAZ jako zwykly Script w Mudlecie.

chimera_vip = chimera_vip or {}
local C = chimera_vip
C.root_dir = getMudletHomeDir() .. "/ChimeraVIP"
C.raw_base = "https://raw.githubusercontent.com/gnomidlo/ChimeraVIP/main/"

local function ensure_dir(path)
    local ok, lfs = pcall(require, "lfs")
    if not ok then return false end
    local sep = package.config:sub(1, 1)
    local current = ""
    local prefix = ""
    if path:match("^%a:[/\\]") then prefix = path:sub(1, 2) .. sep; path = path:sub(4)
    elseif path:sub(1, 1) == sep then prefix = sep; path = path:sub(2) end
    current = prefix
    for part in path:gmatch("[^/\\]+") do
        if current ~= "" and current:sub(-1) ~= sep then current = current .. sep end
        current = current .. part
        lfs.mkdir(current)
    end
    return true
end

local function exists(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

local function start_local()
    local init = C.root_dir .. "/src/init.lua"
    if not exists(init) then return false end
    local version_file = io.open(C.root_dir .. "/VERSION", "rb")
    if version_file then C.version = (version_file:read("*l") or "0.72"); version_file:close() end
    local ok, err = pcall(dofile, init)
    if not ok then cecho("\n<orange>[ChimeraVIP]<reset> Blad startu: " .. tostring(err) .. "\n") end
    return ok
end

if exists(C.root_dir .. "/src/init.lua") then
    start_local()
    -- A module error is not permission to reinstall an existing runtime.
    return
end

local staging = C.root_dir .. "/.install"
local manifest_path = staging .. "/manifest.lua"
ensure_dir(staging)
cecho("\n<aquamarine>[ChimeraVIP]<reset> Pierwsza instalacja - pobieram wersje z GitHuba...\n")

local done_id, error_id
local pending = {}

local function cleanup()
    if done_id then pcall(killAnonymousEventHandler, done_id) end
    if error_id then pcall(killAnonymousEventHandler, error_id) end
    done_id, error_id = nil, nil
end

local function fail(text)
    cleanup()
    cecho("\n<orange>[ChimeraVIP]<reset> " .. tostring(text) .. "\n")
end

local function install_files(manifest)
    cleanup()
    if type(manifest) ~= "table" or type(manifest.files) ~= "table" then fail("Nieprawidlowy manifest."); return end
    for _, rel in ipairs(manifest.files) do
        local target = staging .. "/" .. rel
        local dir = target:match("^(.*)[/\\][^/\\]+$")
        if dir then ensure_dir(dir) end
        pending[target] = rel
    end
    done_id = registerAnonymousEventHandler("sysDownloadDone", function(_, filename)
        local rel = pending[filename]
        if not rel then return end
        pending[filename] = nil
        if next(pending) ~= nil then return end
        cleanup()
        for _, file_rel in ipairs(manifest.files) do
            local source = staging .. "/" .. file_rel
            local target = C.root_dir .. "/" .. file_rel
            local dir = target:match("^(.*)[/\\][^/\\]+$")
            if dir then ensure_dir(dir) end
            os.remove(target)
            local ok, err = os.rename(source, target)
            if not ok then fail("Nie udalo sie zapisac " .. file_rel .. ": " .. tostring(err)); return end
        end
        local vf = io.open(C.root_dir .. "/VERSION", "wb")
        if vf then vf:write(tostring(manifest.version) .. "\n"); vf:close() end
        C.version = tostring(manifest.version)
        cecho("\n<aquamarine>[ChimeraVIP]<reset> Zainstalowano wersje " .. C.version .. ".\n")
        tempTimer(0.1, start_local)
    end)
    error_id = registerAnonymousEventHandler("sysDownloadError", function(_, err, filename)
        if not pending[filename] then return end
        fail("Blad pobierania " .. tostring(filename) .. ": " .. tostring(err))
    end)
    for target, rel in pairs(pending) do downloadFile(target, C.raw_base .. rel) end
end

done_id = registerAnonymousEventHandler("sysDownloadDone", function(_, filename)
    if filename ~= manifest_path then return end
    cleanup()
    local ok, manifest = pcall(dofile, manifest_path)
    if not ok then fail("Nie moge odczytac manifestu: " .. tostring(manifest)); return end
    install_files(manifest)
end)

error_id = registerAnonymousEventHandler("sysDownloadError", function(_, err, filename)
    if filename ~= manifest_path then return end
    fail("Nie udalo sie pobrac manifestu: " .. tostring(err))
end)

downloadFile(manifest_path, C.raw_base .. "manifest.lua")
