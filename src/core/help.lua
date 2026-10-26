chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
C.help = C.help or {}
local H = C.help

H.sections = H.sections or {}
H.order = H.order or {}
H.alias_ids = H.alias_ids or {}

local colors = U.palette
local width = U.text_width
local pad = U.pad_right

local function print_line(text, color)
    hecho("\n" .. (color or colors().text) .. tostring(text or ""))
end

local function finish_output()
    hecho("\n")
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
            "Pastelowy HUD i dokowalne Kondycje dzialaja jako wtyczka Chimery 5.",
            "Przelaczanie: /cvhud vip lub /cvhud oficjalny. Ustawienia: /cvhud ustawienia.",
        },
        commands={{"/ui pomoc", "ta pomoc"},{"/cvhud vip", "włącz HUD VIP"},{"/cvhud oficjalny", "powrót do oficjalnego"},{"/cvhud ustawienia", "opcje UI"}},
    })

    self:register("combat", {
        title="KOLORY WALKI",
        description={"Combat Colors dodaje prefiksy siły obrażeń 0/3–3/3.","Kolory są odczytywane z oficjalnej komendy 'kolory'."},
        commands={{"/walka pomoc", "ta pomoc"},{"KOL ● / KOL ○", "włącz lub wyłącz Combat Colors w footerze"},{"kolory", "oficjalna lista kolorów komunikatów Chimery"}},
    })

    self:register("automation", {
        title="AUTO-WSPARCIE",
        description={"Chimera 5 obsługuje autowsparcie oficjalnie; VIP nie uruchamia drugiego automatu."},
        commands={{"/wsparcie pomoc", "ta pomoc"},{"AUTO-WSPARCIE ON/OFF", "przełącznik w prawej części footera"}},
    })

    self:register("xp", {
        title="DOŚWIADCZENIE",
        description={"Tracker XP liczy XP z własnych i drużynowych zabójstw, XP/h, aktywny czas, trend i statystyki typów mobów.","Niestandardowe klasyfikacje mobów są utrzymywane centralnie w ChimeraVIP, bez lokalnych reguł użytkownika."},
        commands={{"/xp", "podsumowanie sesji"},{"/xp mobs", "statystyki typów mobów"},{"/xp mob <nazwa>", "szczegóły typu"},{"/xp last [N]", "ostatnie zabójstwa"},{"/xp reset", "wyzeruj sesję"},{"/xp pomoc", "ta pomoc"}},
    })

    self:register("stats", {
        title="CECHY I ROZWOJ",
        description={"Komenda 'cechy' pokazuje cechy, sumy, zmiany względem poprzedniego snapshotu oraz XP związane z rozwojem postaci.","Historia zmian jest zapisywana osobno dla każdej postaci; szczegółowy tracker zdobywania doświadczenia pozostaje pod /xp."},
        commands={{"cechy", "pełny odczyt cech i bieżącego progresu"},{"/cechy historia [N]", "ostatnie zmiany cech i XP między nimi"},{"/cechy pomoc", "ta pomoc"}},
    })

    self:register("milestones", {
        title="KAMIENIE MILOWE",
        description={"Kompaktowe widoki Kamieni Milowych: przeglad buildu, lista Kamieni danej cechy i karta konkretnego Kamienia.","Nazwy cech i Kamieni sa klikalne; klik przechodzi do odpowiedniego widoku."},
        commands={{"kamienie", "przeglad aktywnych Kamieni"},{"kamienie <cecha>", "Kamienie wybranej cechy"},{"kamien <nazwa>", "szczegoly Kamienia"},{"/kamienie pomoc", "ta pomoc"}},
    })

    self:register("settings", {
        title="USTAWIENIA",
        description={"Trwałe ustawienia VIP i przełączniki modułów; UI w /cvhud ustawienia."},
        commands={{"/ustawienia pomoc", "ta pomoc"},{"/cvip ustawienia", "otwórz panel"},{"/cvip moduly", "lista stanów modułów"},
            {"/cvip s", "kompaktowy HUD, Kondycje 7 pt"},
            {"/cvip m", "pół wysokości pasków, kapitaliki, Kondycje 11 pt"},
            {"/cvip xl", "pełne paski z wartościami, Kondycje 16 pt"}},
    })

    self:register("system", {
        title="SYSTEM I AKTUALIZACJE",
        description={"ChimeraVIP jest nakladka na oficjalna Chimere 5 i nie edytuje jej kodu.","Kod nakładki jest aktualizowany z GitHuba, a dane użytkownika pozostają w ChimeraVIP-data."},
        commands={{"/cvip", "główne informacje i lista modułów"},{"/cvip status", "wersja ChimeraVIP i upstreamu"},{"/cvip diagnostyka", "lokalny stan manifestu i updatera"},{"/cvip sprawdz", "sprawdź aktualizację"},{"/cvip aktualizuj", "pobierz, zainstaluj wtyczki i przeładuj"},{"/cvip przeladuj", "przeładuj lokalne moduły"}},
    })
end

H.catalog = {
    {"/ui pomoc",         "Interfejs",     "motyw, Quiet Footer i układ UI"},
    {"/walka pomoc",      "Kolory walki",  "prefiksy siły obrażeń i integracja walki"},
    {"/wsparcie pomoc",   "Auto-wsparcie", "automatyczne podążanie za celem lidera"},
    {"/xp pomoc",         "Doświadczenie", "XP/h, zabójstwa i typy mobów"},
    {"/bron pomoc",       "Bron",          "skrocone parametry wywazenia i skutecznosci"},
    {"/cechy pomoc",      "Cechy",         "cechy, delty, historia rozwoju i XP między wzrostami"},
    {"/kamienie pomoc",   "Kamienie",       "Kamienie Milowe, poziomy i postep"},
    {"/ustawienia pomoc", "Ustawienia",    "konfiguracja interfejsu i modułów"},
}

local function print_section(section)
    local P = colors()
    print_line("", P.text)
    print_line(section.title or "MODUL", P.lavender)
    for _, text in ipairs(section.description or {}) do print_line("  " .. tostring(text), P.text_muted) end
    local commands = section.commands or {}
    if #commands > 0 then
        print_line("", P.text)
        local command_width = 0
        for _, item in ipairs(commands) do command_width = math.max(command_width, width(item[1])) end
        command_width = command_width + 2
        for _, item in ipairs(commands) do hecho("\n  " .. P.mint .. pad(item[1], command_width) .. P.text_muted .. tostring(item[2] or "")) end
    end
    finish_output()
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

    local command_width, title_width = 0, 0
    for _, row in ipairs(self.catalog) do command_width = math.max(command_width, width(row[1])); title_width = math.max(title_width, width(row[2])) end
    command_width = command_width + 2
    title_width = title_width + 2
    for _, row in ipairs(self.catalog) do
        hecho("\n  " .. P.mint .. pad(row[1], command_width) .. P.text .. pad(row[2], title_width) .. P.text_muted .. row[3])
    end

    print_line("", P.text)
    print_line("SYSTEM", P.lavender)
    local system_rows = {
        {"/cvip ustawienia", "panel ustawień"},
        {"/cvip s | m | xl", "rozmiar HUD i Kondycji, zapamiętany po restarcie"},
        {"/cvip diagnostyka", "lokalny stan updatera"},
        {"/cvip sprawdz", "sprawdź aktualizację"},
        {"/cvip aktualizuj", "zaktualizuj kod i wtyczki automatycznie"},
        {"/cvip status", "wersje ChimeraVIP i Chimery"},
    }
    local system_width = 0
    for _, row in ipairs(system_rows) do system_width = math.max(system_width, width(row[1])) end
    system_width = system_width + 2
    for _, row in ipairs(system_rows) do hecho("\n  " .. P.mint .. pad(row[1], system_width) .. P.text_muted .. row[2]) end
    finish_output()
end

function H:resolve(section_id)
    local id = U.normalize(section_id)
    local aliases = {
        cechy="stats", exp="xp", ui="interface", walka="combat", kolory="combat", combat="combat",
        wsparcie="automation", auto="automation", automation="automation", 
        bron="weapon", weapon="weapon", kamienie="milestones", milestone="milestones", milestones="milestones",
        ustawienia="settings", settings="settings", moduly="settings", modules="settings", system="system",
    }
    return aliases[id] or id
end

function H:show(section_id)
    local id = U.trim(section_id)
    if id == "" then self:show_summary(); return end
    id = self:resolve(id)
    local section = self.sections[id]
    if not section then
        print_line("Nie znam modułu '" .. tostring(section_id) .. "'. Użyj /cvip, aby zobaczyć listę modułów.", colors().rose)
        finish_output()
        return
    end
    local P = colors()
    local upstream = type(C.get_upstream_version) == "function" and C:get_upstream_version() or "?"
    hecho("\n\n" .. P.lavender .. "CHIMERAVIP " .. P.peach .. tostring(C.version or "?") .. P.text_muted .. "  |  Chimera " .. tostring(upstream))
    print_section(section)
end

function H:install_aliases()
    U.clear_aliases(self)
    local function add(pattern, section)
        local id = tempAlias(pattern, function() H:show(section) end)
        if id then self.alias_ids[#self.alias_ids + 1] = id end
    end
    add([[^/ui (?:pomoc|help)$]], "interface")
    add([[^/walka (?:pomoc|help)$]], "combat")
    add([[^/wsparcie (?:pomoc|help)$]], "automation")
    add([[^/cechy (?:pomoc|help)$]], "stats")
    add([[^/kamienie (?:pomoc|help)$]], "milestones")
    add([[^/ustawienia (?:pomoc|help)$]], "settings")
end

H:register_defaults()
H:install_aliases()
return H
