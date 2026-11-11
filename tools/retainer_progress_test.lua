-- Retainer roster regression: multiword roles, specializations, active status.
chimera_vip = {}
local triggers, output = {}, {}
local next_id = 0
tempRegexTrigger = function(pattern, callback)
    next_id = next_id + 1
    triggers[#triggers + 1] = {pattern=pattern, callback=callback}
    return next_id
end
killTrigger = function() end
killTimer = function() end
tempTimer = function() next_id = next_id + 1; return next_id end
hecho = function(text) output[#output + 1] = text end
deleteLine = function() end

assert(dofile("src/core/util.lua"))
local R = dofile("src/features/retainer_progress.lua")

-- Exercise the same callback installed for the game output, not only the
-- individual storage method. Mudlet/PCRE supplies matches[1] as full line.
local row_callback
for _, trigger in ipairs(triggers) do
    if trigger.pattern:find("wymaga posluchu", 1, true) then
        row_callback = trigger.callback
        break
    end
end
assert(row_callback, "Missing palista roster trigger")

local rows = {
    "  1. Rakthar pomocnik poziom 7 czeka (wymaga posluchu 32)",
    "  2. Rethkal rekrut poziom 8 czeka (wymaga posluchu 36)",
    "  3. Xisstan pomocnik poziom 3 czeka (wymaga posluchu 16)",
    "  4. Isskana sierzantka poziom 16 czeka na wezwanie, specjalizacja: porzadek (wymaga posluchu 68)",
    "  5. Visshan milicjant poziom 5 czeka (wymaga posluchu 24)",
    "  6. Vharkana banitka poziom 18 przy tobie, specjalizacja: doswiadczenie (wymaga posluchu 76)",
    "   7. Zathrika       lowczyni nagrod poziom 16   przy tobie, specjalizacja: precyzja (wymaga posluchu 68)",
    "  8. Yssarana przepatrywaczka poziom 2 czeka (wymaga posluchu 12)",
    "  9. Chasstana oprawczyni poziom 17 czeka na wezwanie, specjalizacja: opieka (wymaga posluchu 72)",
    "  10. Lisstana pomocniczka poziom 9 czeka na wezwanie, specjalizacja: opieka (wymaga posluchu 40)",
    "  11. Uzzarna paz poziom 2 czeka (wymaga posluchu 12)",
}

R:start_roster()
for _, row in ipairs(rows) do
    matches = {row}
    row_callback()
end
assert(#R.roster.entries == 11, "All 11 retainers must be recognized")
assert(R.roster.entries[7].name == "Zathrika")
assert(R.roster.entries[7].role == "lowczyni nagrod")
assert(R.roster.entries[7].status == "przy tobie")
assert(R.roster.entries[7].specialization == "precyzja")
assert(R.roster.entries[6].status == "przy tobie")
assert(R.roster.entries[6].specialization == "doswiadczenie")
assert(R.roster.entries[4].status == "czeka na wezwanie")
assert(R.roster.entries[4].specialization == "porzadek")
assert(R.roster.entries[1].specialization == "")
assert(R:show_roster("mozesz prowadzic dwoch naraz", 318))
local rendered = table.concat(output):gsub("#%x%x%x%x%x%x", "")
assert(rendered:find("Zathrika", 1, true))
assert(rendered:find("lowczyni nagrod", 1, true))
assert(rendered:find("[precyzja]", 1, true))
assert(rendered:find("[opieka]", 1, true))
assert(rendered:find("aktywnych: 2", 1, true))
assert(rendered:find("posluch: 144/318", 1, true))
assert(rendered:find("Limit: dwoch naraz", 1, true))
print("Palista multiword roles and specialization statuses: PASS")

-- Old format, underscored roles, warnings and future longer professions.
output = {}
R:start_roster()
assert(R:add_roster_line("  1. Stary pomocnik poziom 3 przy tobie (wymaga posluchu 16)"))
assert(R:add_roster_line("  2. Nowa lowczyni_nagrod poziom 16 czeka (wymaga posluchu 68; za ciezki przy obecnej charyzmie)"))
assert(R:add_roster_line("  3. Przyszla starsza pani szamanka bagiennych gnomow poziom 11 czeka (wymaga posluchu 40)"))
assert(#R.roster.entries == 3)
assert(R.roster.entries[2].role == "lowczyni nagrod")
assert(R.roster.entries[2].warning == "za ciezki przy obecnej charyzmie")
assert(R.roster.entries[3].role == "starsza pani szamanka bagiennych gnomow")
assert(not R:add_roster_line("To nie jest linia pachołka."))
assert(not R:add_roster_line("  4. Uszkodzona lowczyni poziom 16 czeka (wymaga posluchu ?)"))
assert(#R.roster.entries == 3)
assert(R:show_roster("jednego naraz", 100))
rendered = table.concat(output):gsub("#%x%x%x%x%x%x", "")
assert(rendered:find("aktywnych: 1", 1, true))
assert(rendered:find("posluch: 16/100", 1, true))
assert(rendered:find("ZA CIEZKI", 1, true))
assert(rendered:find("starsza pani szamanka bagiennych gnomow", 1, true))
print("Palista legacy format, warnings and long professions: PASS")
