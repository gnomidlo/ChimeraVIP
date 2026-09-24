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
