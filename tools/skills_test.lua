chimera_vip = {}

local next_id = 0
local function id()
    next_id = next_id + 1
    return next_id
end

tempRegexTrigger = function() return id() end
tempAlias = function() return id() end
killTrigger = function() end
killAlias = function() end
killTimer = function() end
getMudletHomeDir = function() return "." end

-- Helpers potrzebne przez util.lua / skills_view.lua w tescie parsera.
hecho = function() end
send = function() end

assert(dofile('src/core/util.lua'))
local S = dofile('src/features/skills_view.lua')

S:start_skills()
assert(S:parse_skill_line('Topory: dobrze [63]'))
local skill = S.skill_capture.skills['topory']
assert(skill and skill.value == 63 and skill.level == 'dobrze')

assert(S:parse_ability_line('Zielarstwo: troszke [2/10000]'))
local ability = S.skill_capture.abilities['zielarstwo']
assert(ability and ability.value == 2 and ability.maximum == 10000)
assert(math.abs(ability.percent - 0.02) < 0.000001)

assert(S:parse_ability_line('Magiczna intuicja: zadziwiajaco dobrze [7500/10000]'))
local multi = S.skill_capture.abilities['magiczna intuicja']
assert(multi and multi.level == 'zadziwiajaco dobrze')
assert(math.abs(multi.percent - 75) < 0.000001)

print('Skills tests: PASS')
S:start_skills()
local line = 'bronie drzewcowe:  pobieznie (teoria: znakomicie) [30 z 65; cwiczenia 154/281]'
assert(S:parse_skill_line(line))
assert(S:parse_skill_line(line))
assert(#S.skill_capture.order == 1)
local modern = S.skill_capture.skills['bronie drzewcowe']
assert(modern.value == 30 and modern.theory == 65)
assert(modern.exercises == 154 and modern.required == 281)
assert(modern.level == 'pobieznie' and modern.theory_level == 'znakomicie')
assert(S:parse_skill_line('precyzyjny cios: pobieznie (teoria: mistrzowsko) [30 z 100; cwiczenia 0/281]'))
assert(not S:parse_skill_line('uniki: pobieznie (teoria: dobrze) [30 z 55; cwiczenia 0/0]'))
S:finish_skills()
assert(S.previous_skills['bronie drzewcowe'].value == 30)
print('Modern skills and duplicate rows: PASS')

-- Mixed reports must use the same name and numeric column boundaries.
for _, clickable in ipairs({false, true}) do
    local output, hints = {}, {}
    hecho = function(text) output[#output+1] = text end
    hechoLink = clickable and function(text, _, hint, use_format)
        assert(text:match('^#%x%x%x%x%x%x') and use_format == true)
        output[#output+1] = text
        hints[#hints+1] = hint
    end or nil
    S:start_skills()
    assert(S:parse_skill_line(line))
    assert(S:parse_skill_line('opieka nad zwierzetami: doskonale [74]'))
    assert(S:parse_skill_line('tropienie: doskonale [75]'))
    S:finish_skills()
    local rendered = table.concat(output):gsub('#%x%x%x%x%x%x', '')
    local width = math.max(22, #('opieka nad zwierzetami') + 2)
    local function row(name, level, theory, exercises)
        return name .. string.rep(' ', width - #name)
            .. string.format('%8s%8s%14s', level, theory, exercises)
    end
    assert(rendered:find(row('', 'poziom', 'teoria', 'cwiczenia'), 1, true))
    assert(rendered:find(row('bronie drzewcowe', '30', '65', '154/281'), 1, true))
    assert(rendered:find(row('opieka nad zwierzetami', '74%', '--', '--'), 1, true))
    assert(rendered:find(row('tropienie', '75%', '--', '--'), 1, true))
    if clickable then assert(table.concat(hints):find('doskonale', 1, true)) end
end
print('Mixed skill column alignment and tooltips: PASS')
local c0 = S:skill_color({value=0, theory=40})
local c100 = S:skill_color({value=40, theory=40})
assert(c0 == '#F0A8B8' and c100 == '#A8DCC2')
local c75, p75 = S:skill_color({value=30, theory=40})
local c30, p30 = S:skill_color({value=30, theory=100})
assert(p75 == 75 and p30 == 30 and c75 ~= c30)
assert(S:skill_color({value=75}) == c75)
assert(S:skill_color({value=50, theory=40}) == c100)
assert(S:skill_color({value=-1, theory=40}) == c0)
local neutral, percent = S:skill_color({value=0, theory=0})
assert(neutral == chimera_vip.util.palette().text_muted and percent == nil)
print('Pastel practice/theory scale: PASS')
local cells = {}
hechoLink = function(text, _, hint, use_format)
    assert(use_format == true and hint ~= '')
    cells[#cells+1] = text
end
local function render(value, theory)
    S:print_skill({name='test', value=value, theory=theory, level='pobieznie',
        theory_level='dobrze', exercises=0, required=281})
end
render(30, 40)
assert(cells[1] == c75 .. string.format('%8s', '30'))
render(30, 100)
assert(cells[3] == c30 .. string.format('%8s', '30'))
render(40, 40)
assert(cells[5] == c100 .. string.format('%8s', '40'))
print('Rendered tooltip links carry their own colors: PASS')
S:start_skills()
local rows = {
    'bronie drzewcowe: 31 (teoria 65; cwiczenia 63/293)',
    'uniki: 30 (teoria 55; cwiczenia 12/288)',
    'tropienie: 75                    spostrzegawczosc: 75',
    'parowanie: 30 (teoria 40; cwiczenia 7/288)',
    'atak z doskoku: 30 (teoria 100; cwiczenia 6/288)',
    'ukrywanie sie: 100 (premia +20)      skradanie sie: 80',
    'lowiectwo: 77    ',
    'precyzyjny cios: 30 (teoria 100; cwiczenia 7/288)',
    'plywanie: 55                    wspinaczka: 60',
    'wykrywanie pulapek: 55          wyczucie kierunku: 60',
    'opieka nad zwierzetami: 74    ',
}
for repeat_index = 1, 2 do
    for _, row in ipairs(rows) do assert(S:parse_skill_line(row), row) end
end
assert(#S.skill_capture.order == 15)
local skills = S.skill_capture.skills
assert(skills['bronie drzewcowe'].value == 31 and skills['bronie drzewcowe'].required == 293)
assert(skills['ukrywanie sie'].value == 100 and skills['ukrywanie sie'].bonus == 20)
assert(skills['skradanie sie'].value == 80)
assert(skills['opieka nad zwierzetami'].value == 74)
assert(not S:parse_skill_line('test: 10 (teoria 20; cwiczenia 0/0)'))
assert(not S:parse_skill_line('nowa: 15    uszkodzona: ?'))
assert(not S.skill_capture.skills.nowa)
local numeric_output = {}
hecho = function(text) numeric_output[#numeric_output+1] = text end
hechoLink = function(text, _, hint)
    assert(text:match('^#%x%x%x%x%x%x'))
    numeric_output[#numeric_output+1] = text
end
S:finish_skills()
assert(table.concat(numeric_output):find('(premia +20)', 1, true))
assert(S.previous_skills['ukrywanie sie'].value == 100)
print('Numeric skills, two columns, bonus and repeated report: PASS')
