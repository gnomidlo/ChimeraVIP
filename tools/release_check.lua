-- ChimeraVIP release checker
-- Uruchom z katalogu glownego repo: lua tools/release_check.lua

local function read_file(path)
    local f, err = io.open(path, "rb")
    if not f then return nil, err end
    local content = f:read("*a")
    f:close()
    return content
end

local function fail(message)
    io.stderr:write("[FAIL] " .. tostring(message) .. "\n")
    os.exit(1)
end

local function ok(message)
    io.stdout:write("[ OK ] " .. tostring(message) .. "\n")
end

local function git_blob_hash(path)
    local pipe = io.popen("git hash-object " .. string.format("%q", path) .. " 2>/dev/null")
    if not pipe then return nil end
    local value = pipe:read("*l")
    pipe:close()
    return value and value:match("^%x+$") and value or nil
end

local manifest_chunk, manifest_err = loadfile("manifest.lua")
if not manifest_chunk then fail("manifest.lua: " .. tostring(manifest_err)) end
local manifest_ok, manifest = pcall(manifest_chunk)
if not manifest_ok or type(manifest) ~= "table" then fail("manifest.lua nie zwraca tabeli") end

local version_text, version_err = read_file("VERSION")
if not version_text then fail("VERSION: " .. tostring(version_err)) end
local version = version_text:match("^%s*([^%s]+)")
if tostring(manifest.version) ~= tostring(version) then
    fail("wersja manifestu " .. tostring(manifest.version) .. " != VERSION " .. tostring(version))
end
ok("VERSION = manifest.version = " .. tostring(version))

if tonumber(manifest.schema) ~= 2 then fail("manifest.schema musi wynosic 2") end
if type(manifest.file_meta) ~= "table" then fail("manifest.file_meta jest wymagane dla schema 2") end
if type(manifest.remove) ~= "table" then fail("manifest.remove musi byc tabela") end

if type(manifest.files) ~= "table" or #manifest.files == 0 then fail("manifest.files jest puste") end
local seen = {}
for _, path in ipairs(manifest.files) do
    if seen[path] then fail("duplikat w manifest.files: " .. tostring(path)) end
    seen[path] = true
    local content = read_file(path)
    if not content then fail("brak pliku z manifestu: " .. tostring(path)) end

    local meta = manifest.file_meta[path]
    if type(meta) ~= "table" then fail("brak file_meta dla: " .. tostring(path)) end
    if tonumber(meta.size) ~= #content then
        fail("zly rozmiar file_meta dla " .. path .. ": " .. tostring(meta.size) .. " != " .. tostring(#content))
    end
    local hash = git_blob_hash(path)
    if not hash then fail("nie moge policzyc git hash-object dla: " .. tostring(path)) end
    if tostring(meta.hash) ~= hash then
        fail("zly blob hash dla " .. path .. ": " .. tostring(meta.hash) .. " != " .. tostring(hash))
    end

    if path:match("%.lua$") then
        local chunk, err = loadfile(path)
        if not chunk then fail("blad skladni " .. path .. ": " .. tostring(err)) end
    end
end
ok("manifest.files: " .. tostring(#manifest.files) .. " plikow istnieje, bez duplikatow")
ok("file_meta: rozmiary i Git blob SHA sa zgodne")
ok("wszystkie pliki Lua z manifestu przechodza loadfile()")

for path in pairs(manifest.file_meta) do
    if not seen[path] then fail("file_meta zawiera plik spoza manifest.files: " .. tostring(path)) end
end

local remove_seen = {}
for _, path in ipairs(manifest.remove) do
    if remove_seen[path] then fail("duplikat w manifest.remove: " .. tostring(path)) end
    if seen[path] then fail("plik nie moze byc jednoczesnie w files i remove: " .. tostring(path)) end
    remove_seen[path] = true
end
ok("manifest.remove jest spojny")

local bootstrap, bootstrap_err = read_file("src/core/bootstrap.lua")
if not bootstrap then fail("bootstrap.lua: " .. tostring(bootstrap_err)) end
local escaped = tostring(version):gsub("([^%w])", "%%%1")
if not bootstrap:match('C%.version%s*=%s*C%.version%s*or%s*"' .. escaped .. '"') then
    fail("bootstrap.lua nie zawiera fallbacku wersji " .. tostring(version))
end
ok("bootstrap fallback = " .. tostring(version))

io.stdout:write("\nChimeraVIP release check: PASS\n")
