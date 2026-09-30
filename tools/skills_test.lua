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

local ability_output = {}
hecho = function(text) ability_output[#ability_output+1] = text end
S:print_ability({name='kowalstwo', level='kiepsko', value=2000, maximum=2000, percent=100})
local ability_rendered = table.concat(ability_output):gsub('#%x%x%x%x%x%x', '')
assert(ability_rendered:find('kiepsko', 1, true))
assert(ability_rendered:find('2000/2000', 1, true))
assert(ability_rendered:find('100%', 1, true))
assert(ability_rendered:find('LEKCJA', 1, true))

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
    local function row(name, level, theory, bonus, exercises)
        return name .. string.rep(' ', width - #name)
            .. string.format('%10s%8s%8s%12s', level, theory, bonus, exercises)
    end
    assert(rendered:find(row('', 'praktyka', 'teoria', 'premia', 'cwiczenia'), 1, true))
    assert(rendered:find(row('bronie drzewcowe', '30', '65', '--', '154/281'), 1, true))
    assert(rendered:find(row('opieka nad zwierzetami', '74%', '--', '--', '--'), 1, true))
    assert(rendered:find(row('tropienie', '75%', '--', '--', '--'), 1, true))
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
assert(cells[1] == c75 .. string.format('%10s', '30'))
render(30, 100)
assert(cells[3] == c30 .. string.format('%10s', '30'))
render(40, 40)
assert(cells[5] == c100 .. string.format('%10s', '40'))
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
local combined = 'parowanie: 72 (teoria 75; premia +7; cwiczenia 0/439)'
assert(S:parse_skill_line(combined))
assert(S:parse_skill_line(combined))
assert(S.skill_capture.skills.parowanie.value == 72)
assert(S.skill_capture.skills.parowanie.theory == 75)
assert(S.skill_capture.skills.parowanie.bonus == 7)
assert(S.skill_capture.skills.parowanie.exercises == 0)
assert(S.skill_capture.skills.parowanie.required == 439)
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
assert(table.concat(numeric_output):find('+20', 1, true))
assert(table.concat(numeric_output):find('+7', 1, true))
assert(S.previous_skills['ukrywanie sie'].value == 100)
print('Numeric skills, two columns, bonus and repeated report: PASS')
S:start_skills()
local beginner = {
    'walka bez broni: 17 (teoria 17)',
    'uniki: 18 (teoria 18)',
    'tarczownictwo: 20 (teoria 20)',
}
for pass = 1, 2 do
    for _, row in ipairs(beginner) do assert(S:parse_skill_line(row), row) end
end
assert(#S.skill_capture.order == 3)
assert(S.skill_capture.skills['walka bez broni'].theory == 17)
assert(S.skill_capture.skills.uniki.theory == 18)
assert(S.skill_capture.skills.tarczownictwo.theory == 20)
local beginner_output = {}
hecho = function(text) beginner_output[#beginner_output+1] = text end
hechoLink = function(text) beginner_output[#beginner_output+1] = text end
S:finish_skills()
local beginner_rendered = table.concat(beginner_output):gsub('#%x%x%x%x%x%x', '')
assert(beginner_rendered:find('walka bez broni', 1, true))
assert(beginner_rendered:find(string.format('%10s%8s%8s%12s', '17', '17', '--', '--'), 1, true))
assert(beginner_rendered:find(string.format('%10s%8s%8s%12s', '18', '18', '--', '--'), 1, true))
assert(beginner_rendered:find(string.format('%10s%8s%8s%12s', '20', '20', '--', '--'), 1, true))
print('Theory-only beginner skills and duplicate block: PASS')

S:start_skills()
local table_rows = {
    'topory                       10      10',
    'mloty                        26      26',
    'wprawne uderzenie            31      70          141/265',
    'parowanie                    72      75      +7    0/439',
}
for _, row in ipairs(table_rows) do assert(S:parse_practice_table_line(row), row) end
assert(S:parse_remaining_skill_line('Kowalstwo: 1/500'))
assert(S.skill_capture.skills.topory.value == 10 and S.skill_capture.skills.topory.theory == 10)
assert(S.skill_capture.skills['wprawne uderzenie'].exercises == 141)
assert(S.skill_capture.skills.parowanie.bonus == 7 and S.skill_capture.skills.parowanie.required == 439)
assert(S.skill_capture.abilities.kowalstwo.kind == 'remaining')
local new_output = {}
hecho = function(text) new_output[#new_output+1] = text end
hechoLink = nil
S:finish_skills()
local new_rendered = table.concat(new_output):gsub('#%x%x%x%x%x%x', '')
assert(new_rendered:find('praktyka', 1, true) and new_rendered:find('premia', 1, true))
assert(new_rendered:find('POZOSTALE UMIEJETNOSCI', 1, true))
assert(new_rendered:find('1/500', 1, true) and new_rendered:find('0.20%', 1, true))
print('Table skills and remaining progress: PASS')

S:start_skills()
local trainable = 'silne pchniecie              --      --          (do wytrenowania)'
assert(S:parse_trainable_skill_line(trainable))
assert(S:parse_trainable_skill_line(trainable))
assert(#S.skill_capture.order == 1 and S.skill_capture.skills['silne pchniecie'].untrained)
assert(S:parse_skill_line('plywanie: 45                   spostrzegawczosc: 74 (+12)'))
assert(S.skill_capture.skills.spostrzegawczosc.bonus == 12)
local changed_output = {}
hecho = function(text) changed_output[#changed_output+1] = text end
hechoLink = nil
S.previous_skills = {['silne pchniecie']={value=20}, plywanie={value=52}, spostrzegawczosc={value=62}}
S:finish_skills()
local changed_rendered = table.concat(changed_output):gsub('#%x%x%x%x%x%x', '')
assert(changed_rendered:find('do wytrenowania', 1, true))
assert(changed_rendered:find('+12', 1, true))
assert(not changed_rendered:find('-7', 1, true))
print('Trainable skills, short bonuses and safe deltas: PASS')

-- Growth messages are visual only; session totals come from complete snapshots.
S.previous_skills = {}
S.previous_abilities = {}
S.session_gains = {}
S:start_skills()
assert(S:parse_skill_line('walka mieczem: 17 (teoria 20)'))
assert(S:parse_ability_line('Technika lowcy: poczatkujaco [10/100]'))
S:finish_skills()
assert(next(S.session_gains) == nil)
S:start_skills()
assert(S:parse_skill_line('walka mieczem: 19 (teoria 20)'))
assert(S:parse_ability_line('Technika lowcy: poczatkujaco [13/100]'))
S:finish_skills()
assert(S.session_gains['walka mieczem'] == 2)
assert(S.session_gains['Technika lowcy'] == 3)

local selected, bold, underlined, colored = nil, false, false, false
selectString = function(text) selected = text; return 0 end
setFgColor = function(r, g, b) colored = r ~= nil and g ~= nil and b ~= nil end
setBold = function(value) bold = value end
setUnderline = function(value) underlined = value end
resetFormat = function() end
assert(S:highlight_growth('walce mieczem'))
assert(selected == 'walce mieczem' and bold and underlined and colored)
print('Snapshot growth totals and inline emphasis: PASS')
