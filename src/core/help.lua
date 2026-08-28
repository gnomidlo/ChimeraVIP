chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
C.help = C.help or {}
local H = C.help

H.sections = H.sections or {}
H.order = H.order or {}

local function colors()
    if C.pastel_ui and C.pastel_ui.colors then return C.pastel_ui.colors end
    return {
        text="#D8DCE6", text_muted="#AEB6C5", mint="#A8DCC2", blue="#AFCBF4",
        lavender="#C7B9E8", peach="#F2C4A0", yellow="#EFD8A6", rose="#F0A8B8", separator="#2B303C",
    }
end

function H:register(id,data)
    id=tostring(id or "")
    if id=="" or type(data)~="table" then return false end
    if not self.sections[id] then self.order[#self.order+1]=id end
    self.sections[id]=data
    return true
end

function H:register_defaults()
    self.sections={}; self.order={}

    self:register("start",{
        title="CHIMERAVIP",
        description={
            "Nakładka do oficjalnych skryptów Chimera MUD. Nie zastępuje upstreamu — korzysta z jego GMCP, eventów i publicznych struktur.",
            "Po instalacji działa automatycznie. /cvip wyświetla tę pomoc, a lokalne dane użytkownika są przechowywane poza katalogiem aktualizowanym.",
        },
    })

    self:register("interface",{
        title="INTERFEJS",
        description={
            "Pastelowy motyw upraszcza oficjalne UI, a Quiet Footer zbiera najważniejsze informacje w jednej belce.",
            "Footer pokazuje kompas i wyjścia specjalne, KOND/SIŁY/MANA, SYTOŚĆ/WODĘ, OBC, UPI oraz pasek EXP.",
            "Po prawej stronie znajdują się auto-wsparcie, stanowe przyciski oficjalnych funkcji Chimery oraz przełącznik KOL dla modułu kolorowania walki.",
        },
        commands={
            {"AUTO-WSPARCIE","klikany przełącznik ON/OFF w prawej części footera"},
            {"UKR / PRZ / ATK / ZBI","ukrywanie, przemykanie, tryb ataku i zbieranie"},
            {"LAM / WAL / ZAS","lampa, akcja walki i zasłona"},
            {"KOL ● / KOL ○","włącz/wyłącz Combat Colors; stan jest zapamiętywany"},
        },
    })

    self:register("combat",{
        title="WALKA I KOLORY",
        description={
            "Combat Colors dodaje pastelowe prefiksy siły obrażeń 0/3–3/3 i może zastąpić prezentację obrażeń z oficjalnego folderu gags.",
            "Obsługuje obrażenia zadane i otrzymane przez Twoją postać oraz walkę osób postronnych: innych_zadane_* i innych_otrzymane_*.",
            "Kolory ANSI są automatycznie odczytywane z wyniku komendy 'kolory'. Wartość -1 oznacza 'bez koloru'.",
            "Prefiks pojawia się tylko na liniach mających co najmniej 50 znaków i zawierających przynajmniej jedną literę.",
            "Combat Colors przekazuje rozpoznane trafienia w naszą postać do sesyjnego Defense Trackera przez event chimeraVipIncomingHit.",
        },
        commands={
            {"KOL ● / KOL ○","szybki toggle w footerze"},
            {"/cvip ustawienia modul kolory on|off|toggle","sterowanie modułem z linii poleceń"},
            {"kolory","wyświetl ustawienia kolorów w grze; aktywny moduł zsynchronizuje się automatycznie"},
        },
    })

    self:register("automation",{
        title="AUTOMATYZACJA",
        description={
            "Auto-wsparcie obserwuje GMCP drużyny i walki. Jeśli można ustalić cel lidera, pilnuje aby Twoja postać biła ten sam cel; gdy cel się różni, ponawia 'wesprzyj'.",
            "Każda próba wsparcia wysyła 'wesprzyj' dwukrotnie z odstępem 0,18 s. Cała para podlega anty-spamowi 1,5 s.",
        },
    })

    self:register("defense",{
        title="OBRONA — STATYSTYKI SESJI",
        description={
            "Defense Tracker po cichu liczy w bieżącej sesji próby ataków skierowanych w Twoją postać. Niczego nie zapisuje na dysku.",
            "OBRONIONE obejmuje pudła, uniki, parowania i zasłony. Osobno liczone są ciosy zatrzymane pancerzem oraz znane trafienia 0/3–3/3.",
            "Zasłony, parowania i zatrzymania pancerzem są dodatkowo rozbijane według nazwy przedmiotu.",
            "Jeśli otrzymane_brak ma -1, trafienia 0/3 bez koloru nie mają obecnie pewnego sygnału tekstowego; raport jawnie zaznacza wtedy, że procenty obejmują tylko znane próby.",
        },
        commands={
            {"/def","podsumowanie sesji i procent znanych prób"},
            {"/def sprzet","tarcze/puklerze, bronie do parowania i elementy pancerza"},
            {"/def last [N]","ostatnie N zdarzeń obrony, domyślnie 10"},
            {"/def reset","wyzeruj statystyki bieżącej sesji"},
            {"/def help","lokalna pomoc Defense Trackera"},
        },
    })

    self:register("xp",{
        title="DOŚWIADCZENIE",
        description={
            "Tracker XP liczy doświadczenie z własnych i drużynowych zabójstw, XP/h, aktywny czas, trend oraz statystyki typów przeciwników.",
            "Ręczne reguły pozwalają rozróżnić np. 'ork' i 'czarny ork'.",
        },
        commands={
            {"/xp","podsumowanie bieżącej sesji"},{"/xp mobs","statystyki typów przeciwników"},
            {"/xp mob <nazwa>","szczegóły jednego typu"},{"/xp last [N]","ostatnie zabójstwa"},
            {"/xp rules","lista ręcznych reguł"},{"/xp add nazwa#forma","dodaj klasyfikację"},
            {"/xp del <nazwa>","usuń reguły"},{"/xp reset","wyzeruj bieżącą sesję XP"},{"/xp help","lokalna pomoc"},
        },
    })

    self:register("stats",{
        title="CECHY",
        description={
            "Moduł cech przechwytuje standardowy wynik postępów, porządkuje go kolorystycznie i wylicza Fiz, Ment, Odw oraz sumę wszystkich cech.",
            "Pełny odczyt tworzy snapshot wykorzystywany przez moduł progresji.",
        },
    })

    self:register("progression",{
        title="PROGRES POSTACI",
        description={
            "Historia progresji łączy snapshoty cech z XP i zapisuje dane osobno dla każdej postaci.",
            "Postać jest rozpoznawana przez gmcp.Char.Name.fullname, a gdy go brak — przez gmcp.Char.Name.name.",
        },
        commands={
            {"/progres","stan progresji aktualnej postaci"},{"/progres historia [N]","ostatnie wpisy historii"},
            {"/progres postacie","lista zapisanych postaci"},{"/progres help","lokalna pomoc"},
            {"/cechy info","alias do /progres"},{"/cechy historia [N]","alias historii progresji"},
        },
    })

    self:register("settings",{
        title="USTAWIENIA I MODULY",
        description={
            "Ustawienia ChimeraVIP są trwałe i zapisywane w ChimeraVIP-data/settings.lua.",
            "/cvip ustawienia otwiera panel. Rozmiary 7–14 sterują oficjalnymi oknami stanów drużyny, wrogów i innych postaci, bez zmiany Quiet Footera.",
        },
        commands={
            {"/cvip ustawienia","otwórz panel ustawień"},{"/cvip ustawienia rozmiar <7-14>","ustaw rozmiar tekstu okien stanów"},
            {"/cvip ustawienia moduly","pokaż stany modułów"},{"/cvip ustawienia modul kolory on|off|toggle","steruj Combat Colors"},
            {"/cvip moduly","krótka lista stanów modułów"},
        },
    })

    self:register("integration",{
        title="INTEGRACJA Z OFICJALNĄ CHIMERĄ",
        description={
            "ChimeraVIP działa jako nakładka i nie edytuje kodu oficjalnego pakietu.",
            "Stan oficjalnego folderu chimera/skrypty/ui/gags jest synchronizowany z Combat Colors: wyłączony dla KOL ON i włączony dla KOL OFF.",
        },
    })

    self:register("system",{
        title="SYSTEM I AKTUALIZACJE",
        description={
            "Kod ChimeraVIP jest przechowywany lokalnie w getMudletHomeDir()/ChimeraVIP/, a dane użytkownika w getMudletHomeDir()/ChimeraVIP-data/.",
            "Updater sprawdza manifest na GitHubie i pobiera całą nową wersję do stagingu przed podmianą plików.",
        },
        commands={
            {"/cvip","pełna pomoc ChimeraVIP"},{"/cvip pomoc [sekcja]","pełna pomoc albo jedna sekcja"},
            {"/cvip ustawienia","trwała konfiguracja użytkownika"},{"/cvip status","wersja ChimeraVIP i upstreamu"},
            {"/cvip sprawdz","sprawdź aktualizację"},{"/cvip aktualizuj","pobierz i przeładuj najnowszą wersję"},
            {"/cvip przeladuj","przeładuj lokalne moduły"},
        },
    })
end

local function print_line(text,color)
    hecho("\n"..(color or colors().text)..tostring(text or ""))
end

local function print_section(section)
    local P=colors()
    print_line("",P.text); print_line(section.title or "SEKCJA",P.lavender)
    for _,text in ipairs(section.description or {}) do print_line("  "..tostring(text),P.text_muted) end
    for _,item in ipairs(section.commands or {}) do
        hecho("\n  "..P.mint..string.format("%-34s",tostring(item[1] or ""))..P.text_muted..tostring(item[2] or ""))
    end
end

function H:show(section_id)
    local P=colors()
    local upstream=type(C.get_upstream_version)=="function" and C:get_upstream_version() or "?"
    hecho("\n\n"..P.lavender.."CHIMERAVIP "..P.peach..tostring(C.version or "?")..P.text_muted.."  |  Chimera "..tostring(upstream).."\n"..P.separator.."================================================================")

    local id=tostring(section_id or ""):lower():gsub("^%s+",""):gsub("%s+$","")
    if id~="" then
        local aliases={
            pomoc="system",help="system",cechy="stats",progres="progression",exp="xp",ui="interface",
            walka="combat",kolory="combat",combat="combat",obrona="defense",def="defense",defense="defense",
            ustawienia="settings",settings="settings",moduly="settings",modules="settings",
        }
        id=aliases[id] or id
        local section=self.sections[id]
        if not section then print_line("Nie znam sekcji '"..id.."'. Użyj /cvip, aby zobaczyć pełną pomoc.",P.rose); return end
        print_section(section); print_line("",P.text); return
    end

    for _,key in ipairs(self.order) do local section=self.sections[key]; if section then print_section(section) end end
    print_line("",P.text)
    print_line("Szybki start: /xp  |  /def  |  /progres  |  /cvip ustawienia  |  /cvip sprawdz",P.peach)
end

H:register_defaults()
return H
