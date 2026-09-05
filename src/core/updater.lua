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
if UP.handlers.done then pcall(killAnonymousEventHandler, UP.handlers.done) end
if UP.handlers.error then pcall(killAnonymousEventHandler, UP.handlers.error) end
if UP.timeout_timer then pcall(killTimer, UP.timeout_timer) end
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

local function copy_file(source, target)
    local input, err = io.open(source, "rb")
    if not input then return false, err end
    local data = input:read("*a")
    input:close()
    local dir = dirname(target)
    if dir then U.ensure_dir(dir) end
    local output, write_err = io.open(target, "wb")
    if not output then return false, write_err end
    local ok, result, detail = pcall(function() return output:write(data) end)
    local closed, close_err = output:close()
    if not ok or not result then return false, detail or result end
    if not closed then return false, close_err end
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
    if self.timeout_timer then pcall(killTimer, self.timeout_timer) end
    self.timeout_timer=nil
    if self.handlers.done then pcall(killAnonymousEventHandler, self.handlers.done) end
    if self.handlers.error then pcall(killAnonymousEventHandler, self.handlers.error) end
    self.handlers.done, self.handlers.error = nil, nil
end

function UP:load_manifest(path)
    local chunk,err=loadfile(path)
    if not chunk then return nil,err end
    setfenv(chunk,{})
    local ok, result = pcall(chunk)
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

local function read_file(path)
    local f,err=io.open(path,"rb")
    if not f then return nil,err end
    local data=f:read("*a"); f:close(); return data
end

function UP:arm_timeout()
    if self.timeout_timer then pcall(killTimer,self.timeout_timer) end
    self.timeout_timer=tempTimer(60,function()
        UP:cleanup_handlers(); UP.mode=nil; UP.pending={}
        out("Przekroczono czas pobierania. Mozesz ponowic aktualizacje.","orange")
    end)
end

function UP:fetch_manifest(install,quiet)
    if self.mode then if not quiet then out("Aktualizator jest juz zajety.","yellow") end; return end
    U.ensure_dir(self.staging_dir)
    self:cleanup_handlers()
    self.mode="resolve"
    -- A separate path per attempt ignores late callbacks from cancelled downloads.
    self.attempt=(self.attempt or 0)+1
    local request_dir=self.staging_dir.."/request-"..os.time().."-"..self.attempt
    U.ensure_dir(request_dir)
    local commit_path=request_dir.."/commit.json"
    self.manifest_path=request_dir.."/manifest.lua"
    local manifest_path=self.manifest_path
    local function fail(message)
        UP:cleanup_handlers(); UP.mode=nil
        if not quiet or install then out(message,"orange") end
    end
    self.handlers.error=registerAnonymousEventHandler("sysDownloadError",function(_,err,filename)
        if filename==commit_path or filename==manifest_path then fail("Blad pobierania: "..tostring(err)) end
    end)
    self.handlers.done=registerAnonymousEventHandler("sysDownloadDone",function(_,filename)
        if filename==commit_path then
            local data=read_file(filename)
            local ok,value=pcall(function() return yajl.to_value(data) end)
            local sha=ok and type(value)=="table" and value.sha
            if type(sha)~="string" or #sha~=40 or not sha:match("^%x+$") then fail("Nie mozna ustalic commita wydania."); return end
            UP.snapshot_base="https://raw.githubusercontent.com/gnomidlo/ChimeraVIP/"..sha.."/"
            UP.mode="manifest"
            UP:arm_timeout()
            downloadFile(manifest_path,UP.snapshot_base.."manifest.lua")
        elseif filename==manifest_path then
            local manifest,err=UP:load_manifest(filename)
            if not manifest then fail("Nie moge odczytac manifestu: "..tostring(err)); return end
            UP:cleanup_handlers(); UP.mode=nil; UP.remote_manifest=manifest
            if U.version_gt(manifest.version,C.version) then
                if install then UP:start_files()
                else out("Dostepna wersja "..tostring(manifest.version).." (masz "..tostring(C.version)..").","aquamarine"); show_changes(manifest.changes) end
            elseif not quiet then out("Masz aktualna wersje "..tostring(C.version)..".","aquamarine") end
        end
    end)
    self:arm_timeout()
    downloadFile(commit_path,"https://api.github.com/repos/gnomidlo/ChimeraVIP/commits/main")
end
function UP:check(quiet) return self:fetch_manifest(false,quiet) end
function UP:update() return self:fetch_manifest(true,false) end

function UP:verify_file(path,meta)
    if type(meta)~="table" or type(meta.hash)~="string" or not tonumber(meta.size) then return false,"brak metadanych" end
    local data,err=read_file(path)
    if not data then return false,err end
    if #data~=tonumber(meta.size) then return false,"rozmiar" end
    if C.hash.blob(data)~=meta.hash then return false,"Git blob SHA" end
    if path:match("%.lua$") then
        local chunk,syntax_err=loadfile(path)
        if not chunk then return false,syntax_err end
    end
    return true
end

local function safe_path(path)
    if type(path)~="string" or path=="" or path:find("[^%w_./%-]") or path:sub(1,1)=="/" then return false end
    for part in path:gmatch("[^/]+") do if part==".." or part=="." then return false end end
    return true
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
        if not same or not self:verify_file(self.root_dir.."/"..rel,remote) then changed[#changed + 1] = rel end
    end

    local remove = {}
    for _, rel in ipairs(manifest.remove or {}) do remove[#remove + 1] = rel end
    return {changed=changed, remove=remove, meta=meta}
end

function UP:start_files()
    local manifest = self.remote_manifest
    if not manifest or type(manifest.files) ~= "table" then self.mode = nil; out("Manifest nie zawiera listy plikow.", "orange"); return end

    if not self.snapshot_base then self.mode=nil; out("Brak przypietego commita.","orange"); return end
    for _, list in ipairs({manifest.files,manifest.remove or {}}) do
        for _,rel in ipairs(list) do
            if not safe_path(rel) then self.mode=nil; out("Nieprawidlowa sciezka manifestu.","orange"); return end
        end
    end
    self.install_plan = self:build_plan(manifest)
    local plan = self.install_plan
    self.mode = "files"
    self.pending = {}
    self:cleanup_handlers()

    local version_dir = self.manifest_path:gsub("/manifest%.lua$", "") .. "/files"
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
        local valid,reason=UP:verify_file(filename,expected)
        if not valid then
            UP:cleanup_handlers(); UP.mode=nil; UP.pending={}
            out("Aktualizacja przerwana: "..rel.." ("..tostring(reason)..").","orange")
            return
        end

        UP.pending[filename] = nil
        if next(UP.pending) == nil then UP:finish_update() end
    end)
    self.handlers.error = registerAnonymousEventHandler("sysDownloadError", function(_, err, filename)
        if not UP.pending[filename] then return end
        UP:cleanup_handlers(); UP.mode = nil; UP.pending = {}
        out("Aktualizacja przerwana. Blad pobierania " .. tostring(filename) .. ": " .. tostring(err), "orange")
    end)

    self:arm_timeout()
    local downloads={}
    for target,rel in pairs(self.pending) do downloads[#downloads+1]={target,rel} end
    for _,item in ipairs(downloads) do
        if self.mode~="files" then break end
        downloadFile(item[1],self.snapshot_base..item[2])
    end
    out("Pobieram " .. tostring(#plan.changed) .. " zmienionych plikow wersji " .. tostring(manifest.version) .. "...", "light_grey")
end

function UP:rollback(plan)
    if not plan or not plan.backup_dir then return end
    for _, rel in ipairs(plan.metadata or {}) do
        local target=self.root_dir.."/"..rel
        local backup=plan.backup_dir.."/"..rel
        if U.file_exists(backup) then copy_file(backup,target) else pcall(os.remove,target) end
    end
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
    plan.backup_dir = plan.version_dir .. "/backup"
    U.ensure_dir(plan.backup_dir)

    plan.metadata={"VERSION","installed_manifest.lua"}
    for _,rel in ipairs(plan.metadata) do
        local target=self.root_dir.."/"..rel
        if U.file_exists(target) then
            local ok,err=copy_file(target,plan.backup_dir.."/"..rel)
            if not ok then self.mode=nil; out("Blad backupu metadanych: "..tostring(err),"orange"); return end
        else pcall(os.remove,plan.backup_dir.."/"..rel) end
    end
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
    local capabilities=C.runtime and C.runtime:capabilities() or {{"Adapter runtime",false}}
    for _, capability in ipairs(capabilities) do
        out(capability[1] .. ": " .. (capability[2] and "OK" or "brak danych / zaleznosci"), capability[2] and "aquamarine" or "yellow")
    end
    for _, failure in ipairs(C.load_errors or {}) do
        out(failure.path .. ": " .. failure.error, "orange")
    end
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
