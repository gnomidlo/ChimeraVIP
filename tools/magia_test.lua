-- Off-game regression tests for ChimeraVIP Magia.
local printed,sent,timers={},{},{}
local next_id=0
function hecho(s) printed[#printed+1]=tostring(s or "") end
function getMudletHomeDir() return "/tmp" end
function tempTimer(sec,fn,repeat_flag)
    next_id=next_id+1
    timers[next_id]={seconds=sec,callback=fn,repeating=repeat_flag}
    return next_id
end
function killTimer(id) timers[id]=nil end
function tempRegexTrigger() return 1 end
function killTrigger() end
function tempAlias() return 1 end
function killAlias() end
function registerAnonymousEventHandler() return 1 end
function killAnonymousEventHandler() end
function send(s) sent[#sent+1]=s end

chimera_vip={root_dir="/tmp/cvip-magia-test"}
dofile("src/core/util.lua")
local U=chimera_vip.util
U.file_exists=function() return false end
U.ensure_dir=function() return false end
chimera_vip.magia={}
local M=chimera_vip.magia
M.show_window=function() return true end
M.render=function() end
chimera_vip.xp_tracker={get_present_retainers=function()
    return {{id="npc-1",name="Zathrica"},{id="npc-2",name="Uzzarnia"}}
end}
gmcp={Char={Name={name="Veesa"}}}
dofile("src/features/magia.lua")

assert(M.parse_duration("25 godzin")==25*3600)
assert(M.parse_duration("1 godzine")==3600)
assert(M.parse_duration("2 godziny")==7200)
assert(M.parse_duration("1 dzien i 3 godziny")==27*3600)
assert(M.parse_duration("15 minut")==900)
assert(M.parse_duration("bez terminu")==nil)
assert(M.format(25*3600)=="~25h")

assert(M:scan())
assert(sent[1]=="efekty","start from own effects")
local function parse_lines(lines)
    for _,s in ipairs(lines) do M:on_line(s) end
end
parse_lines({
    "Kamienie Milowe:",
    "Magiczne przedmioty, ktore masz na sobie:",
    "  kamienny olbrzymi miecz",
    "   Dzialanie: nie potrafisz rozpoznac mocy.",
    "   Rozsypie sie w pyl za okolo 25 godzin.",
    "  zakorkowana szklana buteleczka",
    "   Dzialanie: nie potrafisz rozpoznac mocy.",
    "   Rozsypie sie w pyl za okolo 1 godzine.",
    "Kradziez zycia:",
})
assert(#M.data.owners["@"].items==2)
assert(sent[2]=="parozkaz npc-1 efekty","first retainer by GMCP ID")
parse_lines({
    "Magiczne przedmioty, ktore ma na sobie:",
    "  dlugi zaostrzony kord",
    "   Dzialanie: nie potrafisz rozpoznac mocy.",
    "   Rozsypie sie w pyl za okolo 2 godziny.",
    "  matowy pierscien",
    "   Dzialanie: dlugi opis pierscienia z Neverwinter.",
    "   Rozsypie sie w pyl za okolo 14 godzin.",
    "  matowy pierscien",
    "   Dzialanie: ten sam opis, lecz drugi przedmiot.",
    "   Rozsypie sie w pyl za okolo 16 godzin.",
    "Kradziez zycia:",
})
assert(#M.data.owners["npc-1"].items==3,"do not collapse duplicate rings")
assert(M.data.owners["npc-1"].items[2].expiry~=M.data.owners["npc-1"].items[3].expiry)
assert(sent[3]=="parozkaz npc-2 efekty")
parse_lines({
    "Magiczne przedmioty, ktore ma na sobie:",
    "  okragla poswiecona tarcza",
    "   Rozsypie sie w pyl za okolo 35 godzin.",
    "Kradziez zycia:",
})
assert(#M.data.owners["npc-2"].items==1)
assert(M.queue==nil and M.current==nil)
assert(#M:rows()==6)
-- Partial response does not erase complete snapshot.
M.current={id="npc-2",name="Uzzarnia",self=false}
parse_lines({
    "Magiczne przedmioty, ktore ma na sobie:",
    "  okragla poswiecona tarcza",
    "  matowy pierscien",
    "   Rozsypie sie w pyl za okolo 15 godzin.",
    "Kradziez zycia:",
})
assert(#M.data.owners["npc-2"].items==1,"incomplete data must not replace prior results")
assert(M:shortest("@")~=nil)
-- Check that the UI module is syntactically valid; it needs real Mudlet/Geyser at runtime.
assert(loadfile("src/features/magia_window.lua"))
print("Magia tests: PASS")
