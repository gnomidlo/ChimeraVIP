local output = {}
function hecho(text) output[#output+1] = tostring(text or "") end
function tempRegexTrigger() return 1 end
function killTrigger() end
function tempTimer() return 1 end
function killTimer() end

chimera_vip = {}
assert(dofile("src/core/util.lua"))
local B = dofile("src/features/blacksmith_info.lua")

B:start("Nieporeczny kamienny mlot", "z niezrownanym kunsztem dopracowany do zadawania ciosow", "wyrazna", "Xev")
B:on_condition("100", "Nie potrafisz obecnie poprawic jego stanu", "25")
B:on_active("skutecznosc", "wyrazna", "5 godzin", "odswiezenie bedzie mozliwe, gdy punca stanie sie niemal niewidoczna")
B:on_options("wywazenie, skutecznosc", "3", "+1", "2 godziny", "3", "+2", "4 godziny", "38 sekund")
B:on_salvage("4", "25 sekund")

local rendered = table.concat(output):gsub("#%x%x%x%x%x%x", "")
for _, expected in ipairs({
    "KOWAL", "Nieporeczny kamienny mlot", "100%", "25%", "wybitne", "Xev/wyrazna",
    "wywazenie, skutecznosc", "KAWALKI:", "+1", "SZTABKI:", "+2", "4 kawalki", "~25 sekund",
}) do
    assert(rendered:find(expected, 1, true), expected)
end
assert(B.capture == nil)
print("Blacksmith appraisal tests: PASS")
