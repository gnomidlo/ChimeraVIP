local triggers,aliases,handlers,timers={},{},{},{}
local serial=0
local function add(t,v) serial=serial+1; t[serial]=v; return serial end
function tempRegexTrigger(p,f) return add(triggers,f) end
function tempAlias(p,f) return add(aliases,f) end
function registerAnonymousEventHandler(e,f) return add(handlers,{e,f}) end
function tempTimer(_,f) return add(timers,f) end
function killTrigger(id) triggers[id]=nil end
function killAlias(id) aliases[id]=nil end
function killAnonymousEventHandler(id) handlers[id]=nil end
function killTimer(id) timers[id]=nil end
local output,replayed,sent,gags={},{},{},0
function hecho(s) output[#output+1]=s end
function echo(s) replayed[#replayed+1]=s end
function send(s) sent[#sent+1]=s end
function deleteLine() gags=gags+1 end
chimera_vip={}
dofile('src/core/util.lua')
local W=dofile('src/features/retainer_wages.lua')
local rows={
    {2,'Rakthar','10 srebrnych i 10 miedzianych monet','11 srebrnych i 5 miedzianych monet','50 min'},
    {3,'Rethkal','12 srebrnych i 5 miedzianych monet','6 miedzianych monet','1 min'},
    {5,'Xisstan','4 srebrne i 8 miedzianych monet','5 srebrnych monet','51 min'},
    {6,'Isskana','1 zlota i 3 miedziane monety','4 mithrylowe, 75 zlotych, 18 srebrnych i 11 miedzianych monet','15 dni 16 h'},
    {7,'Visshan','7 srebrnych i 9 miedzianych monet','8 srebrnych i 4 miedziane monety','51 min'},
    {10,'Vharkana','2 zlote, 9 srebrnych i 10 miedzianych monet','4 mithrylowe, 42 zlote, 5 srebrnych i 5 miedzianych monet','5 dni 22 h'},
    {11,'Zathrika','1 srebrna i 6 miedzianych monet','1 srebrna i 7 miedzianych monet','50 min'},
    {12,'Yssarana','3 srebrne i 1 miedziana moneta','3 srebrne i 4 miedziane monety','51 min'},
    {13,'Chasstana','10 srebrnych i 10 miedzianych monet','1 mithrylowa, 96 zlotych, 13 srebrnych i 8 miedzianych monet','12 dni 2 h'},
    {14,'Lisstana','4 srebrne i 8 miedzianych monet','5 srebrnych monet','51 min'},
}
local footer={
    "Zaplacisz w dobach ('pazold <imie> 3 doby'), w czasie rzeczywistym",
    "('pazold <imie> 2 godziny', 'pazold <imie> 1 dzien') albo kwota",
    "('pazold <imie> 9 zlotych monet'). Dlug zamyka 'pazold <imie> splac'.",
    "Czas liczy sie tylko wtedy, gdy pacholek jest przy tobie.",
}
assert(not W:consume('Zold twoich pacholkow:') and gags==0) -- official /pa untouched
assert(W:request() and not W:request() and #sent==1 and sent[1]=='pazold')
assert(not W:consume('pazold'))
assert(W:consume('Zold twoich pacholkow:'))
for _,r in ipairs(rows) do
    assert(W:consume('   '..r[1]..'. '..r[2]))
    assert(W:consume('      stawka:   '..r[3]..' za dobe (48 minut sluzby)'))
    assert(W:consume('      oplacone: '..r[4]..(r[1]==3 and '' or ' -- starczy na 1 dobe')))
    assert(W:consume('                czyli ok. '..r[5]..' sluzby przy tobie'))
    assert(W:consume(''))
end
for _,s in ipairs(footer) do assert(W:consume(s)) end
assert(not W.armed and not W.capture and not W.timer)
local rendered=table.concat(output)
for _,r in ipairs(rows) do assert(rendered:find(r[2],1,true)) end
assert(rendered:find('4 mth 75 zl 18 sr 11 md',1,true))
assert(rendered:find('~15 dni 16 h',1,true))
assert(rendered:find(chimera_vip.util.palette().rose..'~1 min',1,true))
assert(#replayed==0 and gags==55)
-- Unknown debt grammar is retained, not mistaken for paid-up time.
W:request(); W:consume('Zold twoich pacholkow:'); W:consume('   3. Rethkal')
W:consume('      stawka:   1 srebrna moneta za dobe (48 minut sluzby)')
local before=gags
assert(not W:consume('      DLUG: 9 zlotych monet'))
assert(not W.capture and gags==before and table.concat(replayed):find('Rethkal',1,true))
-- Timeout and reload restore the hidden prefix, preserving the report.
W:request(); W:consume('Zold twoich pacholkow:')
local callback=timers[W.timer]; callback(); assert(not W.armed)
W:request(); W:consume('Zold twoich pacholkow:')
W=dofile('src/features/retainer_wages.lua'); assert(not W.armed)
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
assert(count(aliases)==1 and count(triggers)==1 and count(handlers)==2 and count(timers)==0)
W:request(); assert(not W:consume('Nie masz pacholkow.'))
W:cleanup(); assert(count(aliases)==0 and count(triggers)==0 and count(handlers)==0)
print('PASS retainer wages: ten rows, currencies, time, capture isolation and recovery')
