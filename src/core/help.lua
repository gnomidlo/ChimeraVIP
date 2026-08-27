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
        text = "#D8DCE6", text_muted = "#AEB6C5", mint = "#A8DCC2",
        blue = "#AFCBF4", lavender = "#C7B9E8", peach = "#F2C4A0",
        yellow = "#EFD8A6", rose = "#F0A8B8", separator = "#2B303C",
    }
end

function H:register(id, data)
    id = tostring(id or "")
    if id == "" or type(data) ~= "table" then return false end
    if not self.sections[id] then self.order[#self.order + 1] = id end
    self.sections[id] = data
    return true
end

function H:register_defaults()
    self.sections = {}
    self.order = {}

    self:register("start", {
        title = "CHIMERAVIP",
        description = {
            "Nakładka do oficjalnych skryptów Chimera MUD. Nie zastępuje upstreamu — korzysta z jego GMCP, eventów i publicznych struktur.",
            "Po instalacji działa automatycznie. /cvip wyświetla tę pomoc, a lokalne dane użytkownika są przechowywane poza katalogiem aktualizowanym.",
        },
    })

    self:register("interface", {
        title = "INTERFEJS",
        description = {
            "Pastelowy motyw upraszcza oficjalne UI, a Quiet Footer zbiera najważniejsze informacje w jednej belce.",
            "Footer pokazuje kompas i wyjścia specjalne, KOND/SIŁY/MANA, SYTOŚĆ/WODĘ, OBC, UPI oraz pasek EXP.",
            "Po prawej stronie znajdują się auto-wsparcie, stanowe przyciski oficjalnych funkcji Chimery oraz przełącznik KOL dla modułu kolorowania walki.",
        },
        commands = {
            { "AUTO-WSPARCIE", "klikany przełącznik ON/OFF w prawej części footera" },
            { "UKR / PRZ / ATK / ZBI", "ukrywanie, przemykanie, tryb ataku i zbieranie" },
            { "LAM / WAL / ZAS", "lampa, akcja walki i zasłona" },
            { "KOL ● / KOL ○", "włącz/wyłącz Combat Colors; stan jest zapamiętywany" },
        },
    })

    self:register("combat", {
        title = "WALKA I KOLORY",
        description = {
            "Combat Colors dodaje pastelowe prefiksy siły obrażeń 0/3–3/3 i może zastąpić prezentację obrażeń z oficjalnego folderu gags.",
            "Obsługuje obrażenia zadane i otrzymane przez Twoją postać oraz walkę osób postronnych: innych_zadane_* i innych_otrzymane_*.",
            "Kolory ANSI są automatycznie odczytywane z wyniku komendy 'kolory'. Wartość -1 oznacza 'bez koloru' i wtedy ChimeraVIP nie tworzy triggera dla tej kategorii.",
            "Prefiks pojawia się tylko na liniach mających co najmniej 50 znaków i zawierających przynajmniej jedną literę.",
            "Gdy moduł jest ON, ChimeraVIP wyłącza oficjalny gags i uruchamia własne prefiksy. Gdy jest OFF, usuwa własne triggery i ponownie włącza oficjalny gags.",
        },
        commands = {
            { "KOL ● / KOL ○", "szybki toggle w footerze" },
            { "/cvip ustawienia modul kolory on|off|toggle", "sterowanie modułem z linii poleceń" },
            { "kolory", "wyświetl ustawienia kolorów w grze; aktywny moduł zsynchronizuje się automatycznie" },
            { "kolory <nazwa> <0-255>", "ustaw kolor danej kategorii w oficjalnej Chimerze" },
            { "kolory <nazwa> domyslny", "przywróć domyślny kolor danej kategorii" },
        },
    })

    self:register("automation", {
        title = "AUTOMATYZACJA",
        description = {
            "Auto-wsparcie obserwuje GMCP drużyny i walki. Gdy ktoś z drużyny walczy, a Twoja postać jeszcze nie, wysyła komendę 'wesprzyj'.",
            "Mechanizm ma anty-spam 1,5 s i można go w dowolnej chwili wyłączyć przełącznikiem w footerze.",
        },
    })

    self:register("xp", {
        title = "DOŚWIADCZENIE",
        description = {
            "Tracker XP liczy doświadczenie z własnych i drużynowych zabójstw, XP/h, aktywny czas, trend oraz statystyki typów przeciwników.",
            "Ręczne reguły pozwalają rozróżnić np. 'ork' i 'czarny ork'. Reguły użytkownika nie są nadpisywane przez aktualizacje.",
        },
        commands = {
            { "/xp", "podsumowanie bieżącej sesji" },
            { "/xp mobs", "statystyki wszystkich typów przeciwników" },
            { "/xp mob <nazwa>", "szczegóły jednego typu przeciwnika" },
            { "/xp last [N]", "ostatnie N zabójstw, domyślnie 10" },
            { "/xp rules", "lista ręcznych reguł klasyfikacji" },
            { "/xp add nazwa#forma", "dodaj ręczną klasyfikację, np. czarny ork#czarnego orka" },
            { "/xp del <nazwa>", "usuń reguły dla danego typu" },
            { "/xp reset", "wyzeruj bieżącą sesję XP" },
            { "/xp help", "lokalna pomoc trackera XP" },
        },
    })

    self:register("stats", {
        title = "CECHY",
        description = {
            "Moduł cech przechwytuje standardowy wynik postępów, porządkuje go kolorystycznie i wylicza Fiz, Ment, Odw oraz sumę wszystkich cech.",
            "Pełny odczyt tworzy snapshot wykorzystywany przez moduł progresji.",
        },
    })

    self:register("progression", {
        title = "PROGRES POSTACI",
        description = {
            "Historia progresji łączy snapshoty cech z XP i zapisuje dane osobno dla każdej postaci.",
            "Postać jest rozpoznawana przez gmcp.Char.Name.fullname, a gdy go brak — przez gmcp.Char.Name.name.",
            "Samo ponowne sprawdzanie cech nie zeruje licznika. Dopiero rzeczywista zmiana cechy zapisuje wpis historii i XP zdobyte od poprzedniej zmiany.",
        },
        commands = {
            { "/progres", "stan progresji aktualnej postaci" },
            { "/progres historia [N]", "ostatnie wpisy historii" },
            { "/progres postacie", "lista wszystkich zapisanych postaci" },
            { "/progres help", "lokalna pomoc modułu progresji" },
            { "/cechy info", "alias do /progres" },
            { "/cechy historia [N]", "alias historii progresji" },
        },
    })

    self:register("settings", {
        title = "USTAWIENIA I MODULY",
        description = {
            "Ustawienia ChimeraVIP są trwałe i zapisywane w ChimeraVIP-data/settings.lua, więc przeżywają restart Mudleta i aktualizacje nakładki.",
            "Można zmienić rodzinę oraz rozmiar czcionki tekstowej części okna kondycji. Zmiana jest stosowana od razu.",
            "Rejestr modułów jest przygotowany pod kolejne funkcje. W 0.74 przełączalnym modułem jest Combat Colors.",
        },
        commands = {
            { "/cvip ustawienia", "pokaż wszystkie aktualne ustawienia" },
            { "/cvip ustawienia czcionka <nazwa>", "ustaw font, np. JetBrains Mono" },
            { "/cvip ustawienia czcionka domyslna", "wróć do domyślnej czcionki Mudleta" },
            { "/cvip ustawienia rozmiar <8-11>", "ustaw rozmiar tekstu okna kondycji" },
            { "/cvip ustawienia moduly", "pokaż stany przełączalnych modułów" },
            { "/cvip ustawienia modul kolory on|off|toggle", "steruj Combat Colors" },
            { "/cvip moduly", "krótka lista stanów modułów" },
        },
    })

    self:register("integration", {
        title = "INTEGRACJA Z OFICJALNĄ CHIMERĄ",
        description = {
            "ChimeraVIP działa jako nakładka i nie edytuje kodu oficjalnego pakietu.",
            "Stan oficjalnego folderu chimera/skrypty/ui/gags jest synchronizowany z Combat Colors: wyłączony dla KOL ON i włączony dla KOL OFF.",
        },
    })

    self:register("system", {
        title = "SYSTEM I AKTUALIZACJE",
        description = {
            "Kod ChimeraVIP jest przechowywany lokalnie w getMudletHomeDir()/ChimeraVIP/, a dane użytkownika w getMudletHomeDir()/ChimeraVIP-data/.",
            "Updater sprawdza manifest na GitHubie i pobiera całą nową wersję do stagingu przed podmianą plików.",
        },
        commands = {
            { "/cvip", "pełna pomoc ChimeraVIP" },
            { "/cvip pomoc [sekcja]", "pełna pomoc albo jedna sekcja, np. /cvip pomoc ustawienia" },
            { "/cvip ustawienia", "trwała konfiguracja użytkownika" },
            { "/cvip status", "wersja ChimeraVIP i wersja upstreamu" },
            { "/cvip sprawdz", "sprawdź, czy jest dostępna aktualizacja" },
            { "/cvip aktualizuj", "pobierz i przeładuj najnowszą wersję" },
            { "/cvip przeladuj", "przeładuj lokalne moduły bez pobierania" },
        },
    })
end

local function print_line(text, color)
    hecho("\n" .. (color or colors().text) .. tostring(text or ""))
end

local function print_section(section)
    local P = colors()
    print_line("", P.text)
    print_line(section.title or "SEKCJA", P.lavender)

    for _, text in ipairs(section.description or {}) do
        print_line("  " .. tostring(text), P.text_muted)
    end

    for _, item in ipairs(section.commands or {}) do
        local command = tostring(item[1] or "")
        local description = tostring(item[2] or "")
        hecho("\n  " .. P.mint .. string.format("%-34s", command) .. P.text_muted .. description)
    end
end

function H:show(section_id)
    local P = colors()
    local upstream = type(C.get_upstream_version) == "function" and C:get_upstream_version() or "?"

    hecho("\n\n" .. P.lavender .. "CHIMERAVIP " .. P.peach .. tostring(C.version or "?")
        .. P.text_muted .. "  |  Chimera " .. tostring(upstream)
        .. "\n" .. P.separator .. "================================================================")

    local id = tostring(section_id or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if id ~= "" then
        local aliases = {
            pomoc = "system", help = "system", cechy = "stats", progres = "progression",
            exp = "xp", ui = "interface", walka = "combat", kolory = "combat", combat = "combat",
            ustawienia = "settings", settings = "settings", moduly = "settings", modules = "settings",
        }
        id = aliases[id] or id
        local section = self.sections[id]
        if not section then
            print_line("Nie znam sekcji '" .. id .. "'. Użyj /cvip, aby zobaczyć pełną pomoc.", P.rose)
            return
        end
        print_section(section)
        print_line("", P.text)
        return
    end

    for _, key in ipairs(self.order) do
        local section = self.sections[key]
        if section then print_section(section) end
    end

    print_line("", P.text)
    print_line("Szybki start: /xp  |  /progres  |  /cvip ustawienia  |  /cvip sprawdz", P.peach)
end

H:register_defaults()

return H
