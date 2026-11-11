-- Regression for the palista report: multiple-word roles and specialties.
local triggers, timers, output = {}, {}, {}
local sequence = 0
local function add(bucket, value)
    sequence = sequence + 1
    bucket[sequence] = value
    return sequence
end
function tempRegexTrigger(pattern, fn) return add(triggers, {pattern = pattern, fn = fn}) end
function killTrigger(id) triggers[id] = nil end
function tempTimer(_, fn) return add(timers, fn) end
function killTimer(id) timers[id] = nil end
function deleteLine() end
function hecho(text) output[#output + 1] = text end

chimera_vip = {}
dofile("src/core/util.lua")
local R = dofile("src/features/retainer_progress.lua")

local function entry_trigger()
    for _, trigger in pairs(triggers) do
        if trigger.pattern:find("wymaga posluchu", 1, true) then
            -- The role capture must be non-greedy, not single-token.
            assert(trigger.pattern:find("(.+?)", 1, true))
            return trigger.fn
        end
    end
    error("No palista entry trigger")
end

local rows = {
    {1, "Rakthar", "pomocnik", 7, "czeka", 32},
    {2, "Rethkal", "rekrut", 8, "czeka", 36},
    {3, "Xisstan", "pomocnik", 3, "czeka", 16},
    {4, "Isskana", "sierzantka", 16, "czeka na wezwanie, specjalizacja: porzadek", 68},
    {5, "Visshan", "milicjant", 5, "czeka", 24},
    {6, "Vharkana", "banitka", 18, "przy tobie, specjalizacja: doswiadczenie", 76},
    {7, "Zathrika", "lowczyni nagrod", 16, "przy tobie, specjalizacja: precyzja", 68},
    {8, "Yssarana", "przepatrywaczka", 2, "czeka", 12},
    {9, "Chasstana", "oprawczyni", 17, "czeka na wezwanie, specjalizacja: opieka", 72},
    {10, "Lisstana", "pomocniczka", 9, "czeka na wezwanie, specjalizacja: opieka", 40},
    {11, "Uzzarna", "paz", 2, "czeka", 12},
}

R:start_roster()
local consume_entry = entry_trigger()
for _, row in ipairs(rows) do
    -- Mudlet regex callbacks are passed captures at matches[2]..matches[8].
    matches = {[2] = tostring(row[1]), [3] = row[2], [4] = row[3],
        [5] = tostring(row[4]), [6] = row[5], [7] = tostring(row[6])}
    consume_entry()
end
assert(#R.roster.entries == 11)
assert(R.roster.entries[7].role == "lowczyni nagrod")
assert(R.roster.entries[7].status == "przy tobie")
assert(R.roster.entries[7].specialization == "precyzja")
assert(R.roster.entries[6].status == "przy tobie")
assert(R.roster.entries[6].specialization == "doswiadczenie")
assert(R.roster.entries[4].status == "czeka na wezwanie")
assert(R.roster.entries[4].specialization == "porzadek")
assert(R.roster.entries[1].status == "czeka")
assert(R.roster.entries[1].specialization == "")

assert(R:show_roster("mozesz prowadzic dwoch naraz", 318))
local plain = table.concat(output):gsub("#%x%x%x%x%x%x", "")
assert(plain:find("aktywnych: 2", 1, true))
assert(plain:find("posluch: 144/318", 1, true))
assert(plain:find("lowczyni nagrod", 1, true))
assert(plain:find("PRZY TOBIE  [specjalizacja: precyzja]", 1, true))
assert(plain:find("czeka na wezwanie  [specjalizacja: opieka]", 1, true))
assert(plain:find("Limit: dwoch naraz", 1, true))

-- The warning suffix is still separate from status and specialization.
R:start_roster()
assert(R:add_roster_entry(12, "Testowa", "mag bitewny", 10,
    "czeka, specjalizacja: magia ognia", 80, "za ciezki przy obecnej charyzmie"))
assert(R:show_roster("dwoch naraz", 318))
plain = table.concat(output):gsub("#%x%x%x%x%x%x", "")
assert(plain:find("mag bitewny", 1, true))
assert(plain:find("[specjalizacja: magia ognia]", 1, true))
assert(plain:find("ZA CIEZKI", 1, true))

-- Reload must replace triggers instead of accumulating copies.
R = dofile("src/features/retainer_progress.lua")
local total = 0
for _ in pairs(triggers) do total = total + 1 end
assert(total == 8)
print("PASS retainer progress: multiword roles, specialties, active count, warnings")
