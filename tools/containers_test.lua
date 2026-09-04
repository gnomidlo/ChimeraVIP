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
check('jedenascie mithrylowych monet', '11', 'mithrylowych monet')
check('dwadziescia srebrnych monet', '20', 'srebrnych monet')
check('wiele zlotych monet', '~', 'zlotych monet')
check('ogromny stos monet', '1k+', 'monet')
check('100 monet', '100', 'monet')
check('miecz', '1', 'miecz')
print('Containers tests: PASS')
