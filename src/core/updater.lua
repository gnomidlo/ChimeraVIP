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
UP.installed_manifest_path = UP.root_dir .. "/installed_manifest.lua"
UP.pending = UP.pending or {}
UP.mode = nil
UP.remote_manifest = nil
UP.install_plan = nil
UP.auto_checked = UP.auto_checked or false

local function out(text, color)
    cecho("\n<" .. (color or "light_grey") .. ">[ChimeraVIP]<reset> " .. tostring(text) .. "\n")
end

local trim = U and U.trim or function(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function show_changes(changes)
    if type(changes) ~= "table" or #changes == 0 then return end
    cecho("\n<light_slate_blue>NOWOSCI<reset>\n")
    for i = 1, math.min(#changes, 4) do
        cecho("<light_grey>  - <reset>" .. tostring(changes[i]) .. "\n")
    end
end

local function dirname(path)
    return tostring(path or ""):match("^(.*)[/\\][^/\\]+$")
end

local function file_size(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local size = f:seek("end")
    f:close()
    return size
end

local function copy_file(source, target)
    local input, err = io.open(source, "rb")
    if not input then return false, err end
    local data = input:read("*a")
    input:close()
    local dir = dirname(target)
    if dir then U.ensure_dir(dir) end
    local output, write_err = io.open(target, "wb")
    if not output then return false, write_err end
    local ok, result = pcall(function() output:write(data) end)
    output:close()
    if not ok then return false, result end
    return true
end

local function serialize(value, indent)
    indent = indent or ""
    local kind = type(value)
    if kind == "string" then return string.format("%q", value) end
    if kind == "number" or kind == "boolean" then return tostring(value) end
    if kind ~= "table" then return "nil" end

    local next_indent = indent .. "    "
    local parts = {"{"}
    local numeric = true
    local max_index = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then numeric = false; break end
        if key > max_index then max_index = key end
    end
    if numeric then
        for i = 1, max_index do
            parts[#parts + 1] = "\n" .. next_indent .. serialize(value[i], next_indent) .. ","
        end
    else
        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, key in ipairs(keys) do
            local key_text
            if type(key) == "string" and key:match("^[%a_][%w_]*$") then key_text = key
            else key_text = "[" .. serialize(key, next_indent) .. "]" end
            parts[#parts + 1] = "\n" .. next_indent .. key_text .. " = " .. serialize(value[key], next_indent) .. ","
        end
    end
    if #parts > 1 then parts[#parts + 1] = "\n" .. indent end
    parts[#parts + 1] = "}"
    return table.concat(parts)
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

function UP:save_installed_manifest(manifest)
    if type(manifest) ~= "table" then return false end
    return U.write_file(self.installed_manifest_path, "return " .. serialize(manifest) .. "\n")
end

function UP:get_installed_manifest()
    local manifest = self:load_manifest(self.installed_manifest_path)
    if manifest and tostring(manifest.version) == tostring(C.version) then return manifest end

    local staged = self:load_manifest(self.manifest_path)
    if staged and tostring(staged.version) == tostring(C.version) then
        self:save_installed_manifest(staged)
        return staged
    end
    return nil
end

function UP:remember_current_manifest(manifest)
    if type(manifest) ~= "table" then return end
    if tostring(manifest.version) ~= tostring(C.version) then return end
    if tonumber(manifest.schema) and tonumber(manifest.schema) >= 2 then self:save_installed_manifest(manifest) end
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
            out("Dostepna wersja " .. tostring(manifest.version) .. " (masz " .. tostring(C.version) .. ").", "aquamarine")
            show_changes(manifest.changes)
            cecho("\n<aquamarine>/cvip aktualizuj<reset>\n")
        else
            UP:remember_current_manifest(manifest)
            if not quiet then out("Masz aktualna wersje " .. tostring(C.version) .. ".", "aquamarine") end
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
        if not U.version_gt(manifest.version, C.version) then
            UP.mode = nil
            UP:remember_current_manifest(manifest)
            out("Masz aktualna wersje " .. tostring(C.version) .. ".", "aquamarine")
            return
        end
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

function UP:build_plan(manifest)
    local installed = self:get_installed_manifest()
    local changed = {}
    local meta = type(manifest.file_meta) == "table" and manifest.file_meta or {}
    local old_meta = installed and type(installed.file_meta) == "table" and installed.file_meta or nil

    for _, rel in ipairs(manifest.files or {}) do
        local remote = meta[rel]
        local previous = old_meta and old_meta[rel]
        local same = remote and previous and remote.hash and previous.hash and tostring(remote.hash) == tostring(previous.hash)
        if not same then changed[#changed + 1] = rel end
    end

    local remove = {}
    for _, rel in ipairs(manifest.remove or {}) do remove[#remove + 1] = rel end
    return {changed=changed, remove=remove, meta=meta}
end

function UP:start_files()
    local manifest = self.remote_manifest
    if not manifest or type(manifest.files) ~= "table" then self.mode = nil; out("Manifest nie zawiera listy plikow.", "orange"); return end

    self.install_plan = self:build_plan(manifest)
    local plan = self.install_plan
    self.mode = "files"
    self.pending = {}
    self:cleanup_handlers()

    local version_dir = self.staging_dir .. "/update-" .. tostring(manifest.version)
    U.ensure_dir(version_dir)
    plan.version_dir = version_dir

    for _, rel in ipairs(plan.changed) do
        local target = version_dir .. "/" .. rel
        local dir = dirname(target)
        if dir then U.ensure_dir(dir) end
        pcall(os.remove, target)
        self.pending[target] = rel
    end

    if next(self.pending) == nil then
        out("Brak zmienionych plikow do pobrania; stosuje porzadki wersji " .. tostring(manifest.version) .. "...", "light_grey")
        self:finish_update()
        return
    end

    self.handlers.done = registerAnonymousEventHandler("sysDownloadDone", function(_, filename)
        local rel = UP.pending[filename]
        if not rel then return end

        local expected = UP.install_plan and UP.install_plan.meta and UP.install_plan.meta[rel]
        if expected and tonumber(expected.size) then
            local actual = file_size(filename)
            if actual ~= tonumber(expected.size) then
                UP:cleanup_handlers(); UP.mode = nil; UP.pending = {}
                out("Aktualizacja przerwana. Nieprawidlowy rozmiar " .. tostring(rel) .. ".", "orange")
                return
            end
        end

        UP.pending[filename] = nil
        if next(UP.pending) == nil then UP:finish_update() end
    end)
    self.handlers.error = registerAnonymousEventHandler("sysDownloadError", function(_, err, filename)
        if not UP.pending[filename] then return end
        UP:cleanup_handlers(); UP.mode = nil; UP.pending = {}
        out("Aktualizacja przerwana. Blad pobierania " .. tostring(filename) .. ": " .. tostring(err), "orange")
    end)

    for target, rel in pairs(self.pending) do downloadFile(target, self.raw_base .. rel) end
    out("Pobieram " .. tostring(#plan.changed) .. " zmienionych plikow wersji " .. tostring(manifest.version) .. "...", "light_grey")
end

function UP:rollback(plan)
    if not plan or not plan.backup_dir then return end
    for _, rel in ipairs(plan.changed or {}) do
        local target = self.root_dir .. "/" .. rel
        local backup = plan.backup_dir .. "/" .. rel
        if U.file_exists(backup) then
            pcall(os.remove, target)
            copy_file(backup, target)
        elseif plan.created and plan.created[rel] then
            pcall(os.remove, target)
        end
    end
    for _, rel in ipairs(plan.remove or {}) do
        local target = self.root_dir .. "/" .. rel
        local backup = plan.backup_dir .. "/" .. rel
        if U.file_exists(backup) then copy_file(backup, target) end
    end
end

function UP:finish_update()
    self:cleanup_handlers()
    local manifest = self.remote_manifest
    local plan = self.install_plan or self:build_plan(manifest)
    plan.created = {}
    plan.backup_dir = self.staging_dir .. "/backup-" .. tostring(C.version) .. "-to-" .. tostring(manifest.version)
    U.ensure_dir(plan.backup_dir)

    for _, rel in ipairs(plan.changed) do
        local target = self.root_dir .. "/" .. rel
        if U.file_exists(target) then
            local ok, err = copy_file(target, plan.backup_dir .. "/" .. rel)
            if not ok then self.mode=nil; out("Nie udalo sie wykonac backupu " .. rel .. ": " .. tostring(err), "orange"); return end
        else
            plan.created[rel] = true
        end
    end
    for _, rel in ipairs(plan.remove) do
        local target = self.root_dir .. "/" .. rel
        if U.file_exists(target) then
            local ok, err = copy_file(target, plan.backup_dir .. "/" .. rel)
            if not ok then self.mode=nil; out("Nie udalo sie wykonac backupu " .. rel .. ": " .. tostring(err), "orange"); return end
        end
    end

    for _, rel in ipairs(plan.changed) do
        local source = plan.version_dir .. "/" .. rel
        local target = self.root_dir .. "/" .. rel
        local temp_target = target .. ".cvip-new"
        local ok, err = copy_file(source, temp_target)
        if not ok then
            self:rollback(plan); self.mode=nil
            out("Aktualizacja wycofana. Nie udalo sie przygotowac " .. rel .. ": " .. tostring(err), "orange")
            return
        end
        pcall(os.remove, target)
        local renamed, rename_err = os.rename(temp_target, target)
        if not renamed then
            pcall(os.remove, temp_target)
            self:rollback(plan); self.mode=nil
            out("Aktualizacja wycofana. Nie udalo sie podmienic " .. rel .. ": " .. tostring(rename_err), "orange")
            return
        end
    end

    for _, rel in ipairs(plan.remove) do pcall(os.remove, self.root_dir .. "/" .. rel) end

    local version_ok, version_err = U.write_file(self.root_dir .. "/VERSION", tostring(manifest.version) .. "\n")
    if not version_ok or not self:save_installed_manifest(manifest) then
        self:rollback(plan); self.mode=nil
        out("Aktualizacja wycofana. Nie udalo sie zapisac metadanych wersji: " .. tostring(version_err or "manifest"), "orange")
        return
    end

    C.version = tostring(manifest.version)
    self.mode = nil
    self.install_plan = nil
    out("Zaktualizowano ChimeraVIP do " .. C.version .. " (" .. tostring(#plan.changed) .. " plikow zmienionych). Przeladowuje moduly...", "aquamarine")
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

function UP:show_status()
    out("Wersja " .. tostring(C.version) .. " | upstream " .. tostring(C:get_upstream_version()) .. ".", "light_grey")
end

function UP:show_diagnostics()
    local manifest = self:get_installed_manifest()
    local schema = manifest and tonumber(manifest.schema) or nil
    local files = manifest and type(manifest.files) == "table" and #manifest.files or 0
    local has_local = U.file_exists(self.installed_manifest_path)
    local differential = schema and schema >= 2 and has_local
    local pending = 0
    for _ in pairs(self.pending or {}) do pending = pending + 1 end

    local P = U.palette()
    hecho("\n\n" .. P.lavender .. "CHIMERAVIP — DIAGNOSTYKA"
        .. "\n" .. P.separator .. "------------------------------------------"
        .. "\n" .. P.text_muted .. "Wersja       " .. P.text .. tostring(C.version or "?")
        .. "\n" .. P.text_muted .. "Upstream     " .. P.text .. tostring(C:get_upstream_version())
        .. "\n" .. P.text_muted .. "Manifest     " .. (schema and P.mint or P.rose) .. (schema and ("v" .. tostring(schema)) or "brak")
        .. "\n" .. P.text_muted .. "Pliki        " .. P.text .. tostring(files)
        .. "\n" .. P.text_muted .. "Updater      " .. (differential and P.mint or P.yellow) .. (differential and "differential" or "pelny / brak stanu")
        .. "\n" .. P.text_muted .. "Stan lokalny " .. (has_local and P.mint or P.rose) .. (has_local and "OK" or "brak installed_manifest.lua")
        .. "\n" .. P.text_muted .. "Runtime      " .. P.text .. tostring(self.mode or "idle")
        .. (pending > 0 and (P.text_muted .. "  |  pending " .. P.peach .. tostring(pending)) or "")
        .. "\n" .. P.separator .. "------------------------------------------\n")
end

function UP:command(argument)
    local raw = trim(argument)
    local arg = raw:lower()

    if arg == "" then
        if C.help and type(C.help.show) == "function" then C.help:show() else self:show_status() end
        return
    end

    local help_section = arg:match("^pomoc%s+(.+)$") or arg:match("^help%s+(.+)$")
    if arg == "pomoc" or arg == "help" then
        if C.help and type(C.help.show) == "function" then C.help:show() else self:show_status() end
    elseif help_section then
        if C.help and type(C.help.show) == "function" then C.help:show(help_section) else self:show_status() end
    elseif arg == "ustawienia" or arg == "settings" then
        if C.settings and type(C.settings.command) == "function" then C.settings:command("")
        else out("Modul ustawien nie jest dostepny.", "yellow") end
    elseif arg:match("^ustawienia%s+") or arg:match("^settings%s+") then
        local rest = raw:match("^%S+%s+(.+)$") or ""
        if C.settings and type(C.settings.command) == "function" then C.settings:command(rest)
        else out("Modul ustawien nie jest dostepny.", "yellow") end
    elseif arg == "moduly" or arg == "modules" then
        if C.settings and type(C.settings.show_modules) == "function" then C.settings:show_modules()
        else out("Modul ustawien nie jest dostepny.", "yellow") end
    elseif arg == "status" or arg == "wersja" or arg == "version" then self:show_status()
    elseif arg == "diagnostyka" or arg == "diag" or arg == "diagnostics" then self:show_diagnostics()
    elseif arg == "sprawdz" or arg == "check" then self:check(false)
    elseif arg == "aktualizuj" or arg == "update" then self:update()
    elseif arg == "przeladuj" or arg == "reload" then self:reload()
    else out("Nieznana komenda. Uzyj /cvip, aby zobaczyc pelna pomoc.", "yellow") end
end

if UP.alias_id then pcall(killAlias, UP.alias_id) end
UP.alias_id = tempAlias("^/cvip(?:\\s+(.*))?$", function() UP:command(matches[2]) end)

if not UP.auto_checked then
    UP.auto_checked = true
    tempTimer(4, function() UP:check(true) end)
end

return UP
