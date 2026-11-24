local function copy(t) if type(t)~="table" then return t end local r={} for k,v in pairs(t) do r[k]=copy(v) end return r end
local current={id="abc",name="Jaskinia"}
local sent,walk
local function noop() end
hecho=noop; hechoLink=noop; deselect=noop; resetFormat=noop
tempAlias=function() return 1 end; tempRegexTrigger=tempAlias; tempTimer=tempAlias; killTimer=noop
send=function(s) sent=s end
expandAlias=function(s) walk=s end
getRoomIDbyHash=function(h) if h=="abc" then return 42 end end
getRoomHashByID=function(id) if id==42 then return "abc" end end
chimera_vip={util={deep_copy=copy,clear_aliases=noop,clear_triggers=noop,replace_handler=noop},
    settings={data={},save=function() return true end},
    runtime={room=function() return current end,combat=function() return {relations={}} end}}
local B=dofile("src/features/bestiary.lua")
local function reply()
    for _,s in ipairs({
        "Garbaty wielkouchy troll odmienia sie nastepujaco:",
        "  Mianownik: garbaty wielkouchy troll,",
        " Dopelniacz: garbatego wielkouchego trolla,",
        "   Celownik: garbatemu wielkouchemu trollowi,",
        "    Biernik: garbatego wielkouchego trolla,",
        "  Narzednik: garbatym wielkouchym trollem,",
        "Miejscownik: garbatym wielkouchym trollu."}) do B:parse(s) end
end
assert(B:add("troll","III","uwaga")); assert(sent=="odmien troll"); reply()
local k="garbaty wielkouchy troll"
assert(B.data.entries[k].level=="III")
assert(B.data.entries[k].note=="uwaga")
assert(#B:spans("Garbaty wielkouchy troll i garbatego wielkouchego trolla.")==2)
assert(#B:spans("troll i supergarbaty wielkouchy troll")==0)
assert(B:travel(k) and walk=="/idz 42")
assert(B:add("troll")); reply(); assert(B.data.entries[k].note=="uwaga")
assert(B:add("troll")); B:parse("Inny potwor odmienia sie nastepujaco:"); assert(not B.pending)
B=dofile("src/features/bestiary.lua"); assert(B.data.entries[k].level=="III")
current.instance=2; assert(not B:travel(k))
current.instance=nil
B:relocate(k); assert(B.data.entries[k].location.hash=="abc")
chimera_vip.runtime.combat=function() return {primary="enemy"} end
assert(not B:travel(k))
chimera_vip.settings.save=function() return false end
assert(not B:difficulty(k,"IV")); assert(B.data.entries[k].level=="III")
print("Bestiary parser, persistence, full names and safe navigation: PASS")
