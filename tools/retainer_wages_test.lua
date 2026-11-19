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
local plain=rendered:gsub("#%x%x%x%x%x%x","")
assert(plain:find('4mt 75z 18s 11m',1,true))
local P=chimera_vip.util.palette()
assert(rendered:find(P.lavender..'4mt',1,true))
assert(rendered:find(P.yellow..'75z',1,true))
assert(rendered:find(P.text..'18s',1,true))
assert(rendered:find(P.peach..'11m',1,true))
assert(plain:find('Doba: 48 min',1,true))
assert(not plain:find('/ 48m',1,true) and not plain:find('STAWKA / DOBA',1,true))
assert(plain:find('\n  #',1,true) and plain:find(string.rep('-',72),1,true))
-- Every monetary field starts in the same visible column despite color tags.
local rate_column,paid_column,time_column
for row in plain:gmatch('[^\n]+') do
    if row:find('Rakthar',1,true) then
        rate_column=row:find('10s 10m',1,true)
        paid_column=row:find('11s 5m',1,true)
        time_column=row:find('~',1,true)
    elseif row:find('Isskana',1,true) then
        assert(row:find('1z 3m',1,true)==rate_column)
        assert(row:find('4mt',1,true)==paid_column)
        assert(row:find('~',1,true)==time_column)
    end
end
assert(rate_column and paid_column and time_column)
assert(rendered:find('~15 dni 16 h',1,true))
assert(rendered:find(chimera_vip.util.palette().rose..'~1 min',1,true))
assert(table.concat(replayed):match('^%s*$') and gags==55)
-- Unpaid NPC: ordinary report may omit 'oplacone' and 'czyli ok.'.
-- A separate NPC may instead have an explicit DLUG line.
output,replayed={},{}
W:request()
assert(W:consume('Zold twoich pacholkow:'))
assert(W:consume('   2. Rakthar'))
assert(W:consume('      stawka:   5 srebrnych i 10 miedzianych monet za dobe (48 minut sluzby)'))
assert(W:consume('      oplacone: 11 srebrnych i 5 miedzianych monet -- starczy na 1 dobe'))
assert(W:consume('                czyli ok. 1 h 33 min sluzby przy tobie'))
assert(W:consume(''))
assert(W:consume('   3. Rethkal'))
-- The debt-only variant reported by the user: there is no 'stawka'.
assert(W:consume('      DLUG: 2 miedziane monety'))
assert(W:consume(''))
-- Separate synthetic variant without paid time, still parsed safely.
assert(W:consume('   4. Testowy'))
assert(W:consume('      stawka:   6 srebrnych i 8 miedzianych monet za dobe (48 minut sluzby)'))
assert(W:consume(''))
assert(W:consume('   5. Xisstan'))
assert(W:consume('      stawka:   2 srebrne i 6 miedzianych monet za dobe (48 minut sluzby)'))
assert(W:consume('      oplacone: 5 srebrnych monet -- starczy na 2 doby'))
assert(W:consume('                czyli ok. 1 h 36 min sluzby przy tobie'))
assert(W:consume(''))
assert(W:consume('   6. Isskana'))
assert(W:consume('      stawka:   1 zlota, 6 srebrnych i 8 miedzianych monet za dobe (48 minut sluzby)'))
assert(W:consume('      DLUG: 2 miedziane monety'))
assert(W:consume(''))
for _,item in ipairs(footer) do assert(W:consume(item)) end
assert(not W.armed and not W.capture)
local mixed=table.concat(output)
assert(mixed:find('Rakthar',1,true) and mixed:find('Rethkal',1,true))
assert(mixed:find('Xisstan',1,true) and mixed:find('Isskana',1,true))
assert(mixed:find('Testowy',1,true))
-- Rate is deliberately unknown, not inferred from the outstanding debt.
local debt_row
local plain_mixed=mixed:gsub("#%x%x%x%x%x%x","")
for text in plain_mixed:gmatch('[^\n]+') do
    if text:find('Rethkal',1,true) then debt_row=text;break end
end
assert(debt_row and debt_row:find('DLUG 2m',1,true),
    "debt-only member must retain amount without a rate")
assert(mixed:find('brak oplaty',1,true),"missing oplacone must not abort report")
assert(mixed:find('DLUG',1,true),"real debt must be listed in compact report")
assert(mixed:find('2m',1,true),"debt amount should be formatted")
assert(table.concat(replayed):match("^%s*$"),"known variants must not replay raw report")

-- Exact user sample: debt from an earlier, unterminated response can be
-- fused to the next header. Preserve that prefix; still parse new rows.
output,replayed={},{}
W:request()
assert(W:consume('      DLUG: 2 miedziane monetyZold twoich pacholkow:'))
assert(W:consume('   11. Zathrika'))
assert(W:consume('      stawka:   3 zlote, 19 srebrnych i 2 miedziane monety za dobe (48 minut sluzby)'))
assert(W:consume('      oplacone: 12 mithrylowych, 23 zlote, 14 srebrnych i 9 miedzianych monet -- starczy na 309 dob'))
assert(W:consume('                czyli ok. 10 dni 7 h sluzby przy tobie'))
for _,item in ipairs(footer) do assert(W:consume(item)) end
assert(table.concat(output):find('Zathrika',1,true),"fused header must not abort compact report")
assert(table.concat(replayed):find("DLUG: 2 miedziane monety",1,true),
    "preserve unrelated debt line before fused header")
assert(not table.concat(replayed):find("monetyZold",1,true),
    "never glue previous debt to suppressed wage heading")

-- Truly unknown grammar is fail-safe: restore original consumed lines.
W:request();W:consume('Zold twoich pacholkow:');W:consume('   3. Rethkal')
W:consume('      stawka:   1 srebrna moneta za dobe (48 minut sluzby)')
local before=gags
assert(not W:consume('      TO JEST NIEZNANY FORMAT'))
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
print('PASS retainer wages: paid, omitted payment, DLUG, fused header, currency formatting, capture recovery')
