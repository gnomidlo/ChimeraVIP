chimera_vip = {}
getMudletHomeDir = function() return "/tmp" end
tempRegexTrigger = function() return 1 end
tempAlias = function() return 1 end
killTrigger = function() end
killAlias = function() end
killTimer = function() end
tempTimer = function() return 1 end
send = function() end
hecho = function() end
io.exists = function() return false end

assert(dofile("src/core/util.lua"))
local M = dofile("src/features/milestones.lua")

local overview = M:parse_overview_lines({
    "Kamienie Milowe -- aktywne 3 z 3.",
    "",
    "  Sila (szczyt 142), wybrane 0 z 2 (odblokowane szczytem cechy):",
    "",
    "  Zrecznosc (szczyt 151), wybrane 0 z 3 (odblokowane szczytem cechy):",
    "",
    "  Wytrzymalosc (szczyt 147), wybrane 0 z 2 (odblokowane szczytem cechy):",
    "",
    "  Inteligencja (szczyt 156), wybrane 1 z 3 (odblokowane szczytem cechy):",
    "    * Zestrojenie z Ghyran       II  (do nastepnego: 46%, 51024090/109842755 exp)",
    "",
    "  Madrosc (szczyt 152), wybrane 1 z 3 (odblokowane szczytem cechy):",
    "    * Glebokie Zrodlo            I  (do nastepnego: 24%, 10553430/43937102 exp)",
    "",
    "  Odwaga (szczyt 152), wybrane 1 z 3 (odblokowane szczytem cechy):",
    "    * Charyzmatyczny Przywodca   IV",
    "",
    "  Masz juz pelny zestaw. Zmiana wyboru bedzie mozliwa za oplate, ktorej",
    "  wysokosc nie jest jeszcze ustalona.",
})

assert(overview.active == 3 and overview.maximum == 3)
assert(#overview.order == 6)
assert(overview.attributes.sila.peak == 142 and overview.attributes.sila.unlocked == 2)
assert(#overview.attributes.inteligencja.stones == 1)
assert(overview.attributes.inteligencja.stones[1].name == "Zestrojenie z Ghyran")
assert(overview.attributes.inteligencja.stones[1].rank == "II")
assert(overview.attributes.inteligencja.stones[1].percent == 46)
assert(overview.attributes.inteligencja.stones[1].current == 51024090)
assert(overview.attributes.madrosc.stones[1].required == 43937102)
assert(overview.attributes.odwaga.stones[1].rank == "IV")
assert(overview.full_set == true)
print("Milestones overview parsing: PASS")

local attribute = M:parse_attribute_lines({
    "SILA",
    "",
    "Szczyt cechy: 142",
    "",
    "Wybrane:",
    "  -",
    "",
    "Wybrane 0 z 2 (odblokowane szczytem cechy)",
    "",
    "Zablokowane (masz juz pelny zestaw 3 Kamieni):",
    "  [I] Sila Tytana",
    "      udzwig +5/10/15%.",
    "  [I] Zelazny Chwyt",
    "      zmniejsza szanse skutecznego rozbrojenia o 10/20/30%.",
    "  [I] Niepowstrzymany",
    "      przelamywanie zaslony lub blokady wyjscia kosztuje o 5/10/15% mniej",
    "      zmeczenia.",
    "  [I] Zywy Taran",
    "      skuteczniejsze proby silowego otwierania i niszczenia przeszkod.",
    "  [I] Zelazny Uscisk",
    "      zwieksza skutecznosc blokowania wyjscia przeciwnikowi walczacemu z",
    "      postacia.",
    "",
    "Szczegoly:",
    "  kamien <nazwa>",
})

assert(attribute.name == "SILA")
assert(attribute.peak == 142)
assert(attribute.selected == 0 and attribute.unlocked == 2)
assert(attribute.full_set == 3)
assert(#attribute.selected_stones == 0)
assert(#attribute.locked_stones == 5)
assert(attribute.locked_stones[1].name == "Sila Tytana")
assert(attribute.locked_stones[3].description[1]:find("przelamywanie", 1, true))
assert(attribute.locked_stones[3].description[2] == "zmeczenia.")
print("Milestones attribute parsing: PASS")

local detail = M:parse_detail_lines({
    "GLEBOKIE ZRODLO",
    "",
    "Cecha:        madrosc",
    "Status:",
    "  wybrany, poziom I (do nastepnego: 24%, 10553430/43937102 exp)",
    "",
    "Dzialanie:",
    "  Regeneracja many +5/10/15%.",
    "",
    "Porzucenie kosztuje 50 zlotych monet, a poziom Kamienia przepada:",
    "  kamien porzuc glebokie zrodlo",
})

assert(detail.name == "GLEBOKIE ZRODLO")
assert(detail.attribute == "madrosc")
assert(detail.selected == true and detail.rank == "I")
assert(detail.percent == 24)
assert(detail.current == 10553430 and detail.required == 43937102)
assert(detail.effect[1] == "Regeneracja many +5/10/15%.")
assert(detail.abandon_cost == 50)
assert(detail.abandon_command == "kamien porzuc glebokie zrodlo")
print("Milestones detail parsing: PASS")
