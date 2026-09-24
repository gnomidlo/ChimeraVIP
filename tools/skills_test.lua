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
    echoLink = clickable and function(text, _, hint)
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
