chimera_vip = chimera_vip or {}
local C = chimera_vip
local U = C.util

local UP = C.updater or {}
C.updater = UP

UP.handlers = UP.handlers or {}
UP.raw_base = "https://raw.githubusercontent.com/gnomidlo/ChimeraVIP/main/"
UP.root_dir = C.root_dir or (getMudletHomeDir() .. "/ChimeraVIP")
UP.staging_dir = UP.root_dir .. "/.staging"
UP.manifest_path = UP.staging_dir .. "/manifest.lua"
UP.pending = UP.pending or {}
UP.mode = nil
UP.remote_manifest = nil
UP.auto_checked = UP.auto_checked or false

local function out(text, color)
    cecho("\n<" .. (color or "light_grey") .. ">[ChimeraVIP]<reset> " .. tostring(text) .. "\n")
end

function UP:cleanup_handlers()
    if self.handlers.done then pcall(killAnonymousEventHandler, self.handlers.done) end
    if self.handlers.error then pcall(killAnonymousEventHandler, self.handlers.error) end
    self.handlers.done, self.handlers.error = nil, nil
end

function UP:load_manifest(path)
    local ok, result = pcall(dofile, path)
    if not ok or type(result) ~= "table" then return nil, result end
    return result
end

function UP:check(quiet)
    if self.mode then
        if not quiet then out("Aktualizator jest juz zajety.", "yellow") end
        return
    end
    U.ensure_dir(self.staging_dir)
    self.mode = "check"
    self:cleanup_handlers()
    self.handlers.done = registerAnonymousEventHandler("sysDownloadDone", function(_, filename)
        if filename ~= UP.manifest_path then return end
        UP:cleanup_handlers()
        local manifest, err = UP:load_manifest(filename)
        UP.mode = nil
        if not manifest then
            if not quiet then out("Nie moge odczytac manifestu: " .. tostring(err), "orange") end
            return
        end
        UP.remote_manifest = manifest
        if U.version_gt(manifest.version, C.version) then
            out("Dostepna wersja " .. tostring(manifest.version) .. " (masz " .. tostring(C.version) .. "). Uzyj /cvip aktualizuj.", "aquamarine")
        elseif not quiet then
            out("Masz aktualna wersje " .. tostring(C.version) .. ".", "aquamarine")
        end
    end)
    self.handlers.error = registerAnonymousEventHandler("sysDownloadError", function(_, err, filename)
        if filename ~= UP.manifest_path then return end
        UP:cleanup_handlers(); UP.mode = nil
        if not quiet then out("Blad sprawdzania aktualizacji: " .. tostring(err), "orange") end
    end)
    downloadFile(self.manifest_path, self.raw_base .. "manifest.lua")
end

function UP:update()
    if self.mode then out("Aktualizator jest juz zajety.", "yellow"); return end
    U.ensure_dir(self.staging_dir)
    self.mode = "manifest"
    self:cleanup_handlers()
    self.handlers.done = registerAnonymousEventHandler("sysDownloadDone", function(_, filename)
        if filename ~= UP.manifest_path then return end
        UP:cleanup_handlers()
        local manifest, err = UP:load_manifest(filename)
        if not manifest then UP.mode = nil; out("Nie moge odczytac manifestu: " .. tostring(err), "orange"); return end
        UP.remote_manifest = manifest
        UP:start_files()
    end)
    self.handlers.error = registerAnonymousEventHandler("sysDownloadError", function(_, err, filename)
        if filename ~= UP.manifest_path then return end
        UP:cleanup_handlers(); UP.mode = nil
        out("Nie udalo sie pobrac manifestu: " .. tostring(err), "orange")
    end)
    out("Sprawdzam manifest aktualizacji...", "light_grey")
    downloadFile(self.manifest_path, self.raw_base .. "manifest.lua")
end

function UP:start_files()
    local manifest = self.remote_manifest
    if not manifest or type(manifest.files) ~= "table" then self.mode = nil; out("Manifest nie zawiera listy plikow.", "orange"); return end
    self.mode = "files"
    self.pending = {}
    self:cleanup_handlers()
    for _, rel in ipairs(manifest.files) do
        local target = self.staging_dir .. "/" .. rel
        local dir = target:match("^(.*)[/\\][^/\\]+$")
        if dir then U.ensure_dir(dir) end
        self.pending[target] = rel
    end
    self.handlers.done = registerAnonymousEventHandler("sysDownloadDone", function(_, filename)
        if not UP.pending[filename] then return end
        UP.pending[filename] = nil
        if next(UP.pending) == nil then UP:finish_update() end
    end)
    self.handlers.error = registerAnonymousEventHandler("sysDownloadError", function(_, err, filename)
        if not UP.pending[filename] then return end
        UP:cleanup_handlers(); UP.mode = nil; UP.pending = {}
        out("Aktualizacja przerwana. Blad pobierania " .. tostring(filename) .. ": " .. tostring(err), "orange")
    end)
    local count = 0
    for target, rel in pairs(self.pending) do
        count = count + 1
        downloadFile(target, self.raw_base .. rel)
    end
    out("Pobieram " .. tostring(count) .. " plikow wersji " .. tostring(manifest.version) .. "...", "light_grey")
end

function UP:finish_update()
    self:cleanup_handlers()
    local manifest = self.remote_manifest
    for _, rel in ipairs(manifest.files) do
        local source = self.staging_dir .. "/" .. rel
        local target = self.root_dir .. "/" .. rel
        local dir = target:match("^(.*)[/\\][^/\\]+$")
        if dir then U.ensure_dir(dir) end
        os.remove(target)
        local ok, err = os.rename(source, target)
        if not ok then
            self.mode = nil
            out("Nie udalo sie podmienic " .. rel .. ": " .. tostring(err), "orange")
            return
        end
    end
    U.write_file(self.root_dir .. "/VERSION", tostring(manifest.version) .. "\n")
    C.version = tostring(manifest.version)
    self.mode = nil
    out("Zaktualizowano ChimeraVIP do " .. C.version .. ". Przeladowuje moduly...", "aquamarine")
    raiseEvent("chimeraVipUpdated", C.version)
    tempTimer(0.2, function()
        local ok, err = pcall(dofile, UP.root_dir .. "/src/init.lua")
        if not ok then out("Aktualizacja zapisana, ale przeladowanie nie powiodlo sie: " .. tostring(err), "orange") end
    end)
end

function UP:reload()
    local ok, err = pcall(dofile, self.root_dir .. "/src/init.lua")
    if ok then out("Przeladowano lokalne moduly " .. tostring(C.version) .. ".", "aquamarine")
    else out("Blad przeladowania: " .. tostring(err), "orange") end
end

function UP:command(arg)
    arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if arg == "" then
        out("Wersja " .. tostring(C.version) .. " | upstream " .. tostring(C:get_upstream_version()) .. ". Komendy: /cvip sprawdz, /cvip aktualizuj, /cvip przeladuj.", "light_grey")
    elseif arg == "sprawdz" or arg == "check" then self:check(false)
    elseif arg == "aktualizuj" or arg == "update" then self:update()
    elseif arg == "przeladuj" or arg == "reload" then self:reload()
    else out("Nieznana komenda. Uzyj /cvip.", "yellow") end
end

if UP.alias_id then pcall(killAlias, UP.alias_id) end
UP.alias_id = tempAlias("^/cvip(?:\\s+(.*))?$", function() UP:command(matches[2]) end)

if not UP.auto_checked then
    UP.auto_checked = true
    tempTimer(4, function() UP:check(true) end)
end

return UP
