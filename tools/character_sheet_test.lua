chimera_vip = {}
local output, links, timers = {}, {}, {}
tempTimer = function(_, callback) timers[#timers+1] = callback; return #timers end
killTimer = function() end
killTrigger = function() end
tempRegexTrigger = function() return 1 end
hecho = function(text) output[#output+1] = text end
echoLink = function(text, callback, hint)
    output[#output+1] = text
    links[#links+1] = {callback=callback, hint=hint}
end
dofile('src/core/util.lua')
local V = dofile('src/features/character_sheet.lua')
local function render(line)
    local draw = V:render(line)
    assert(draw, line)
    draw()
end
assert(V:render('  Zrecznosc 161') == nil)
render('POSTAC')
render('Cechy')
render('  Zrecznosc        nieskoordynowana jak na herosa161')
assert(table.concat(output):find('161', 1, true))
assert(table.concat(output):find('  nieskoordynowana jak na herosa', 1, true))
render('  Precyzyjny Cios                [walka]')
assert(links[#links].callback == 'send("specjalizacja Precyzyjny Cios", false)')
render('  Zrecznosc  Czujne Zmysly I  (do nastepnego: 0%, 30/39283324 exp)')
assert(table.concat(output):find('0%', 1, true))
assert(not table.concat(output):find('39283324', 1, true))
-- New POSTAC report: preserve game percentages, never display "paski".
render('  Kamienie Milowe                               3/3')
render('  Odwaga          Charyzmatyczny Przywodca II  (do nastepnego: 91%, 4.55 z 5 paskow doswiadczenia)')
render('  Wytrzymalosc    Wola Zycia II  (do nastepnego: 90%, 4.50 z 5 paskow doswiadczenia)')
render('  Madrosc         Niezlomny Umysl II  (do nastepnego: 89%, 4.49 z 5 paskow doswiadczenia)')
local character_rendered = table.concat(output)
for _, percent in ipairs({'91%', '90%', '89%'}) do
    assert(character_rendered:find(percent, 1, true), percent)
end
for _, stone in ipairs({'Charyzmatyczny Przywodca II', 'Wola Zycia II', 'Niezlomny Umysl II'}) do
    assert(character_rendered:find(stone, 1, true), stone)
end
assert(not character_rendered:find('paskow', 1, true))
assert(not character_rendered:find('4.55', 1, true))
assert(not character_rendered:find('4.50', 1, true))
assert(not character_rendered:find('4.49', 1, true))

render('Szczegoly:')
assert(links[#links].callback == 'send("postac kamienie", false)')
render('  postac cechy')
render('PROFESJA')
render('Zbrojny -- Strazniczka')
render('Rola:')
render('  kontrola przeciwnika i druga linia.')
render('Szczegoly:')
render('  postac profesja umiejetnosci')
assert(links[#links].callback == 'send("postac profesja umiejetnosci", false)')
render('KAMIENIE MILOWE')
render('Zrecznosc         161')
assert(links[#links].callback == 'send("postac kamienie zrecznosc", false)')
render('  [I] Cichy Krok  (do nastepnego: 0%, 30/39283324 exp)')
render('Szczegoly:')
render('  postac kamienie <cecha>')
assert(#links > 10)
assert(V:render('Goblin uderza cie.') == nil and V.section == nil)
render('SPECJALIZACJE')
render('Wybrane: 2/2')
render('  Lowczy [pasywna]')
render('Dostepne kategorie:')
render('  postac specjalizacje komendy')
timers[#timers]()
assert(V:render('  Lowczy [pasywna]') == nil)
print('Character sheet rendering and links: PASS')
