chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
C.help = C.help or {}
local H = C.help

H.sections = H.sections or {}
H.order = H.order or {}
H.alias_ids = H.alias_ids or {}

local function colors()
    if C.pastel_ui and C.pastel_ui.colors then return C.pastel_ui.colors end
    return {
        text="#D8DCE6", text_muted="#AEB6C5", mint="#A8DCC2", blue="#AFCBF4",
        lavender="#C7B9E8", peach="#F2C4A0", yellow="#EFD8A6", rose="#F0A8B8", separator="#2B303C",
    }
end

local function print_line(text, color)
    hecho("\n" .. (color or colors().text) .. tostring(text or ""))
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

    self:register("interface", {
        title="INTERFEJS",
        description={
            "Pastelowy motyw i Quiet Footer porządkują oficjalny interfejs Chimery.",
            "Footer pokazuje kompas, wyjścia specjalne, KOND/SIŁY/MANA, potrzeby, OBC/UPI, EXP oraz kontrolki walki.",
        },
        commands={
            {"/ui pomoc", "ta pomoc"},
            {"/cvip ustawienia", "panel ustawień interfejsu i modułów"},
        },
    })

    self:register("combat", {
        title="KOLORY WALKI",
        description={
            "Combat Colors dodaje prefiksy siły obrażeń 0/3–3/3 i integruje otrzymywane ciosy z Defense Trackerem.",
            "Kolory są odczytywane z oficjalnej komendy 'kolory'.",
        },
        commands={
            {"/walka pomoc", "ta pomoc"},
            {"KOL ● / KOL ○", "włącz lub wyłącz Combat Colors w footerze"},
            {"kolory", "oficjalna lista kolorów komunikatów Chimery"},
        },
    })

    self:register("automation", {
        title="AUTO-WSPARCIE",
        description={
            "Auto-wsparcie obserwuje GMCP drużyny i pilnuje celu lidera.",
            "Próba wsparcia wysyła 'wesprzyj' dwukrotnie z krótkim odstępem i ma anty-spam 1,5 s.",
        },
        commands={
            {"/wsparcie pomoc", "ta pomoc"},
            {"AUTO-WSPARCIE ON/OFF", "przełącznik w prawej części footera"},
        },
    })

    self:register("defense", {
        title="OBRONA",
        description={
            "Defense Tracker prowadzi wyłącznie sesyjne statystyki obrony: pudła, uniki, parowania, zasłony, pancerz i trafienia.",
            "Parowania, zasłony i zatrzymania pancerzem są rozbijane według użytego sprzętu.",
        },
        commands={
            {"/def", "podsumowanie sesji"},
            {"/def sprzet", "statystyki tarcz, broni i pancerza"},
            {"/def last [N]", "ostatnie zdarzenia"},
            {"/def reset", "wyzeruj sesję"},
            {"/def pomoc", "ta pomoc"},
        },
    })

    self:register("xp", {
        title="DOŚWIADCZENIE",
        description={
            "Tracker XP liczy XP z własnych i drużynowych zabójstw, XP/h, aktywny czas, trend i statystyki typów mobów.",
            "Niestandardowe klasyfikacje mobów są utrzymywane centralnie w ChimeraVIP, bez lokalnych reguł użytkownika.",
        },
        commands={
            {"/xp", "podsumowanie sesji"},
            {"/xp mobs", "statystyki typów mobów"},
            {"/xp mob <nazwa>", "szczegóły typu"},
            {"/xp last [N]", "ostatnie zabójstwa"},
            {"/xp reset", "wyzeruj sesję"},
            {"/xp pomoc", "ta pomoc"},
        },
    })

    self:register("stats", {
        title="CECHY",
        description={
            "Moduł formatuje wynik cech i wylicza Fiz, Ment, Odw oraz sumę wszystkich cech.",
            "Pełny odczyt tworzy snapshot używany przez moduł progresji.",
        },
        commands={
            {"/cechy pomoc", "ta pomoc"},
            {"/cechy info", "informacje progresji aktualnej postaci"},
            {"/cechy historia [N]", "historia zmian cech"},
        },
    })

    self:register("progression", {
        title="PROGRES POSTACI",
        description={
            "Łączy snapshoty cech z XP i zapisuje historię rozwoju osobno dla każdej postaci.",
        },
        commands={
            {"/progres", "stan aktualnej postaci"},
            {"/progres historia [N]", "ostatnie zmiany"},
            {"/progres postacie", "zapisane postacie"},
            {"/progres pomoc", "ta pomoc"},
        },
    })

    self:register("postacie", {
        title="POSTACIE I RELACJE",
        description={
            "Rejestruje sześć odmian imienia, relację z postacią i koloruje wszystkie znane formy w tekście gry.",
            "Nowe postacie są nieprzypisane do czasu wybrania relacji.",
        },
        commands={
            {"odmien <imie>", "zapisz lub odśwież odmianę"},
            {"/postacie", "lista zapisanych postaci"},
            {"/postacie szukaj <tekst>", "wyszukaj postać"},
            {"/postacie pomoc", "ta pomoc"},
        },
    })

    self:register("settings", {
        title="USTAWIENIA",
        description={
            "Trwałe ustawienia ChimeraVIP: rozmiar oficjalnych okien stanów i przełączniki modułów.",
        },
        commands={
            {"/ustawienia pomoc", "ta pomoc"},
            {"/cvip ustawienia", "otwórz panel"},
            {"/cvip moduly", "lista stanów modułów"},
        },
    })

    self:register("system", {
        title="SYSTEM I AKTUALIZACJE",
        description={
            "ChimeraVIP jest nakładką na oficjalne skrypty Chimery i nie edytuje ich kodu.",
            "Kod nakładki jest aktualizowany z GitHuba, a dane użytkownika pozostają w ChimeraVIP-data.",
        },
        commands={
            {"/cvip", "główne informacje i lista modułów"},
            {"/cvip status", "wersja ChimeraVIP i upstreamu"},
            {"/cvip sprawdz", "sprawdź aktualizację"},
            {"/cvip aktualizuj", "pobierz aktualizację"},
            {"/cvip przeladuj", "przeładuj lokalne moduły"},
        },
    })
end

H.catalog = {
    {"/ui pomoc",       "Interfejs",       "motyw, Quiet Footer i układ UI"},
    {"/walka pomoc",    "Kolory walki",    "prefiksy siły obrażeń i integracja walki"},
    {"/wsparcie pomoc", "Auto-wsparcie",   "automatyczne podążanie za celem lidera"},
    {"/def pomoc",      "Obrona",          "sesyjne statystyki defensywy i sprzętu"},
    {"/xp pomoc",       "Doświadczenie",   "XP/h, zabójstwa i typy mobów"},
    {"/cechy pomoc",    "Cechy",           "formatowanie i snapshoty cech"},
    {"/progres pomoc",  "Progres",         "historia rozwoju postaci powiązana z XP"},
    {"/postacie pomoc", "Postacie",        "odmiany, relacje i kolorowanie imion"},
    {"/ustawienia pomoc","Ustawienia",      "konfiguracja interfejsu i modułów"},
}

local function print_section(section)
    local P = colors()
    print_line("", P.text)
    print_line(section.title or "MODUL", P.lavender)
    for _, text in ipairs(section.description or {}) do print_line("  " .. tostring(text), P.text_muted) end
    if #(section.commands or {}) > 0 then print_line("", P.text) end
    for _, item in ipairs(section.commands or {}) do
        hecho("\n  " .. P.mint .. string.format("%-30s", tostring(item[1] or ""))
            .. P.text_muted .. tostring(item[2] or ""))
    end
end

function H:show_summary()
    local P = colors()
    local upstream = type(C.get_upstream_version) == "function" and C:get_upstream_version() or "?"
    hecho("\n\n" .. P.lavender .. "CHIMERAVIP " .. P.peach .. tostring(C.version or "?")
        .. P.text_muted .. "  |  Chimera " .. tostring(upstream)
        .. "\n" .. P.separator .. "============================================================")
    print_line("Nakładka na oficjalne skrypty Chimera MUD. Moduły działają razem, ale każdy ma własną pomoc.", P.text_muted)
    print_line("", P.text)
    print_line("MODULY", P.lavender)
    for _, row in ipairs(self.catalog) do
        hecho("\n  " .. P.mint .. string.format("%-20s", row[1])
            .. P.text .. string.format("%-18s", row[2])
            .. P.text_muted .. row[3])
    end
    print_line("", P.text)
    print_line("SYSTEM", P.lavender)
    hecho("\n  " .. P.mint .. string.format("%-20s", "/cvip ustawienia") .. P.text_muted .. "panel ustawień")
    hecho("\n  " .. P.mint .. string.format("%-20s", "/cvip sprawdz") .. P.text_muted .. "sprawdź aktualizację")
    hecho("\n  " .. P.mint .. string.format("%-20s", "/cvip aktualizuj") .. P.text_muted .. "pobierz nową wersję")
    hecho("\n  " .. P.mint .. string.format("%-20s", "/cvip status") .. P.text_muted .. "wersje ChimeraVIP i Chimery")
end

function H:resolve(section_id)
    local id = tostring(section_id or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local aliases = {
        cechy="stats", progres="progression", exp="xp", ui="interface",
        walka="combat", kolory="combat", combat="combat",
        wsparcie="automation", auto="automation", automation="automation",
        obrona="defense", def="defense", defense="defense",
        postacie="postacie", characters="postacie",
        ustawienia="settings", settings="settings", moduly="settings", modules="settings",
        system="system",
    }
    return aliases[id] or id
end

function H:show(section_id)
    local id = tostring(section_id or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if id == "" then self:show_summary(); return end
    id = self:resolve(id)
    local section = self.sections[id]
    if not section then
        print_line("Nie znam modułu '" .. tostring(section_id) .. "'. Użyj /cvip, aby zobaczyć listę modułów.", colors().rose)
        return
    end
    local P = colors()
    local upstream = type(C.get_upstream_version) == "function" and C:get_upstream_version() or "?"
    hecho("\n\n" .. P.lavender .. "CHIMERAVIP " .. P.peach .. tostring(C.version or "?")
        .. P.text_muted .. "  |  Chimera " .. tostring(upstream))
    print_section(section)
end

function H:install_aliases()
    for _, id in ipairs(self.alias_ids or {}) do pcall(killAlias, id) end
    self.alias_ids = {}
    local function add(pattern, section)
        local id = tempAlias(pattern, function() H:show(section) end)
        if id then self.alias_ids[#self.alias_ids + 1] = id end
    end
    add([[^/ui (?:pomoc|help)$]], "interface")
    add([[^/walka (?:pomoc|help)$]], "combat")
    add([[^/wsparcie (?:pomoc|help)$]], "automation")
    add([[^/cechy (?:pomoc|help)$]], "stats")
    add([[^/progres pomoc$]], "progression")
    add([[^/ustawienia (?:pomoc|help)$]], "settings")
end

H:register_defaults()
H:install_aliases()
return H
