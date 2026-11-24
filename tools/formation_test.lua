local enabled=true
local settings={get=function() end,is_module_enabled=function() return enabled end,register_module=function() end}
chimera_vip={settings=settings,util={clear_aliases=function() end,clear_triggers=function() end}}
function tempRegexTrigger() return 1 end
function tempAlias() return 1 end
local F=dofile("src/features/formation_highlights.lua")
local g={Char={Info={name="Xochitl"}},Chimera={Group={State={members={{name="Uzzarna"},{name="Zathrika"}}}}}}
local function check(s,key,expected)
    local k,spans=F:parse(s,g)
    assert(k==key,tostring(k).." ~= "..key)
    local parts={}
    for _,v in ipairs(spans) do parts[#parts+1]=s:sub(v[1],v[2]) end
    assert(table.concat(parts,"|")==expected,table.concat(parts,"|"))
end
check("Uzzarna zaslania cie przed ciosami trolla.","druzyna_sukces","zaslania|cie|przed ciosami")
check("Zaslaniasz Uzzarne przed ciosami trolla.","druzyna_sukces","Zaslaniasz|przed ciosami")
check("Uzzarna probuje cie zaslonic przed ciosami trolla, lecz nie jest w stanie tego uczynic.","druzyna_porazka","probuje cie zaslonic|przed ciosami|lecz nie jest w stanie tego uczynic.")
check("Warg probuje zaslonic trolla przed twoimi ciosami, lecz nie jest w stanie tego uczynic.","inni_porazka","probuje zaslonic|przed twoimi ciosami|lecz nie jest w stanie tego uczynic.")
check("Warg zaslania trolla przed twoimi ciosami.","inni_sukces","zaslania|przed twoimi ciosami")
check("Zathrika jest gotowa do kolejnej zmiany w szyku.","druzyna_sukces","jest gotowa do kolejnej zmiany w szyku.")
check("Glosno wypowiadasz rozkaz ataku na trolla.","druzyna_sukces","Glosno wypowiadasz rozkaz ataku na")
assert(F:parse("Warg zaslania wejscie.",g)==nil)
enabled=false
F:highlight("Uzzarna zaslania cie przed ciosami trolla.")
print("Formation highlights: PASS")
