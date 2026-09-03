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

if type(manifest.files) ~= "table" or #manifest.files == 0 then fail("manifest.files jest puste") end
local seen = {}
for _, path in ipairs(manifest.files) do
    if seen[path] then fail("duplikat w manifest.files: " .. tostring(path)) end
    seen[path] = true
    local content = read_file(path)
    if not content then fail("brak pliku z manifestu: " .. tostring(path)) end
    if path:match("%.lua$") then
        local chunk, err = loadfile(path)
        if not chunk then fail("blad skladni " .. path .. ": " .. tostring(err)) end
    end
end
ok("manifest.files: " .. tostring(#manifest.files) .. " plikow istnieje, bez duplikatow")
ok("wszystkie pliki Lua z manifestu przechodza loadfile()")

local bootstrap, bootstrap_err = read_file("src/core/bootstrap.lua")
if not bootstrap then fail("bootstrap.lua: " .. tostring(bootstrap_err)) end
local escaped = tostring(version):gsub("([^%w])", "%%%1")
if not bootstrap:match('C%.version%s*=%s*C%.version%s*or%s*"' .. escaped .. '"') then
    fail("bootstrap.lua nie zawiera fallbacku wersji " .. tostring(version))
end
ok("bootstrap fallback = " .. tostring(version))

io.stdout:write("\nChimeraVIP release check: PASS\n")
