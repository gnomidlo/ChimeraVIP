chimera_vip = {}
tempRegexTrigger = function() return 1 end
dofile('src/core/util.lua')
local R = dofile('src/features/containers.lua')
local function check(input, count, name)
    local a, n = R:parse_amount(input)
    assert(a == count and n == name, input)
end
for word, count in pairs(R.word_amounts) do
    check(word .. ' monet', tostring(count), 'monet')
end
for count = 0, 20 do check(count .. ' monet', tostring(count), 'monet') end
local expected = 11
for word in ('jedenascie dwanascie trzynascie czternascie pietnascie szesnascie siedemnascie osiemnascie dziewietnascie dwadziescia'):gmatch('%S+') do
    check(word .. ' monet', tostring(expected), 'monet')
    expected = expected + 1
end
check('siedmioro kurzych jajek', '7', 'kurzych jajek')
check('dwoje jajek', '2', 'jajek')
check('czworo pisklat', '4', 'pisklat')
check('dwadziescioro jajek', '20', 'jajek')
check('jedenascie mithrylowych monet', '11', 'mithrylowych monet')
check('dwadziescia srebrnych monet', '20', 'srebrnych monet')
check('wiele zlotych monet', '~', 'zlotych monet')
check('ogromny stos monet', '1k+', 'monet')
check('100 monet', '100', 'monet')

local selected, colored = {}, {}
selectString = function(text, occurrence)
    selected[#selected + 1] = {text=text, occurrence=occurrence}
    return 0
end
setFgColor = function(r, g, b)
    colored[#colored + 1] = {r, g, b}
end
resetFormat = function() end

assert(R:highlight_world_money('18 miedzianych monet i dwie mithrylowe monety.'))
assert(selected[1].text == '18 miedzianych monet')
assert(selected[2].text == 'dwie mithrylowe monety')
assert(#colored == 2)
assert(R:highlight_world_money('17 miedzianych monet.'))
assert(R:highlight_world_money('Mithrylowa moneta.'))
local before_mixed = #selected
assert(R:highlight_world_money('Ostry dlugi noz i 17 miedzianych monet.'))
assert(#selected == before_mixed + 1)
assert(selected[#selected].text == '17 miedzianych monet')
assert(R:highlight_world_money('Kupiec chce 17 miedzianych monet.'))
assert(selected[#selected].text == '17 miedzianych monet')
assert(R:highlight_world_money('Na stole lezy mithrylowa moneta.'))
assert(selected[#selected].text == 'mithrylowa moneta')
assert(R:highlight_world_money('17 miedzianych monet i 17 miedzianych monet.'))
assert(selected[#selected - 1].occurrence == 1 and selected[#selected].occurrence == 2)

local function phrase_set(line)
    local result = {}
    for _, phrase in ipairs(R:money_phrases(line)) do result[phrase] = true end
    return result
end
local shop = phrase_set('Zolty filcowy beret  1  4 zlote, 1 srebrna i 10 miedzianych monet')
assert(shop['4 zlote'] and shop['1 srebrna'] and shop['10 miedzianych monet'])
local offer = phrase_set('[*] dlugi stalowy noz - 3 zlote, 6 srebrnych i 8 miedzianych monet.')
assert(offer['3 zlote'] and offer['6 srebrnych'] and offer['8 miedzianych monet'])
local no_false_product = phrase_set('Zloty pierscien kosztuje 5 srebrnych monet.')
assert(not no_false_product['Zloty'] and no_false_product['5 srebrnych monet'])
print('World money highlighting: PASS')
check('miecz', '1', 'miecz')
print('Containers tests: PASS')
