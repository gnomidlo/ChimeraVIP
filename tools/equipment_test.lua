local output = {}
local timers = {}
local next_timer_id = 0
function hecho(text) output[#output + 1] = tostring(text or "") end
function tempTimer(seconds, callback)
    next_timer_id = next_timer_id + 1
    timers[next_timer_id] = {seconds=seconds, callback=callback}
    return next_timer_id
end
function killTimer(id) timers[id] = nil end
function tempRegexTrigger() return 1 end
function tempAlias() return 1 end
function killTrigger() end
function killAlias() end
function getMudletHomeDir() return "/tmp" end

chimera_vip = {}
dofile("src/core/util.lua")
dofile("src/features/weapon_info.lua")
local W = chimera_vip.weapon_info

local function flush_short_timers()
    local pending = timers
    timers = {}
    for _, timer in pairs(pending) do
        if timer.seconds < W.capture_timeout then timer.callback() end
    end
end

local function summary(condition, kind)
    output = {}
    W:start("testowy przedmiot")
    W:on_condition(condition)
    if kind == "weapon" then
        W:on_weapon_header("miecz", "jednoreczny")
        W:on_weapon_scores("dobre", 5, "dobra", 5)
    else
        W:on_armor("prawe ramie 15/15/15")
    end
    flush_short_timers()
    return table.concat(output)
end

for _, ending in ipairs({"lekko podniszczony", "lekko podniszczona", "lekko podniszczone"}) do
    assert(summary(ending, "armor"):find("4/5", 1, true), ending)
end
for _, ending in ipairs({
    "gotowy sie rozpasc w kazdej chwili",
    "gotowa sie rozpasc w kazdej chwili",
    "gotowe sie rozpasc w kazdej chwili",
}) do
    assert(summary(ending, "armor"):find("1/5", 1, true), ending)
end
assert(summary("w znakomitym stanie", "armor"):find("5/5", 1, true))
assert(summary("w znakomitym stanie", "weapon"):find("7/7", 1, true))
assert(summary("liczne walki wyryly swoje pietno", "weapon"):find("5/7", 1, true))
assert(summary("wymagaja natychmiastowej konserwacji", "weapon"):find("2/7", 1, true))

output = {}
W:start("wzmacniana drewniana tarcze")
W:on_condition("lekko podniszczona")
W:on_physical("wzmacniana drewniana tarcza", "3700", "gramow", "1500")
W:on_value("15 srebrnych i 10 miedzianych monet")
W:on_duration("dlugo")
W:on_armor("prawe ramie 15/15/15")
flush_short_timers()
local shield = table.concat(output)
assert(shield:find("OCENA", 1, true) and shield:find("wzmacniana drewniana tarcza", 1, true))
assert(shield:find("stan: ", 1, true) and shield:find("4/5", 1, true))
assert(shield:find("15s", 1, true) and shield:find("10m", 1, true))
assert(shield:find("3.7 kg", 1, true) and shield:find("1500 ml", 1, true))
assert(shield:find("24-48h", 1, true))

output = {}
W:start("masywny wyszczerbiony tasak")
W:on_condition("w znakomitym stanie")
W:on_physical("masywny wyszczerbiony tasak", "1700", "gramow", "630")
W:on_value("3 zlotych, 10 srebrnych i 10 miedzianych monet")
W:on_duration("dlugo")
W:on_weapon_header("miecz", "jednoreczna")
W:on_damage("klute i ciete")
W:on_weapon_scores("srednio", "20", "bardzo skuteczne", "31")
assert(not table.concat(output):find("OCENA", 1, true), "podsumowanie nie powinno wyprzedzac linii o magii")
W:on_magic()
local magic_weapon = table.concat(output)
assert(magic_weapon:find("OCENA - masywny wyszczerbiony tasak  |  MAGIA", 1, true))
assert(magic_weapon:find("stan: ", 1, true) and magic_weapon:find("7/7", 1, true))
assert(magic_weapon:find("WYW: ", 1, true) and magic_weapon:find("20", 1, true))
assert(magic_weapon:find("SKUT: ", 1, true) and magic_weapon:find("31", 1, true))
flush_short_timers()
magic_weapon = table.concat(output)
assert(select(2, magic_weapon:gsub("OCENA %-", "")) == 1, "podsumowanie nie moze sie powielic")
print("Equipment tests: PASS")
