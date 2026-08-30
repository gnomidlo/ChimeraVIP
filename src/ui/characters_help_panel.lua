-- ChimeraVIP / Characters Help Panel
-- Klikalna pomoc modulu Postacie w stylistyce panelu ustawien.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util

C.characters_help_panel = C.characters_help_panel or {}
local HP = C.characters_help_panel

if HP.root then
    pcall(function() HP.root:hide() end)
    pcall(function() HP.root:delete() end)
end

HP.handlers = HP.handlers or {}
HP.root = nil
HP.widgets = {}
HP.visible = false

local function palette()
    if C.pastel_ui and C.pastel_ui.colors then return C.pastel_ui.colors end
    return {
        background="#12151D", background_soft="#181C26", separator="#2B303C",
        text="#D8DCE6", text_muted="#AEB6C5", mint="#A8DCC2",
        lavender="#C7B9E8", blue="#AFCBF4", peach="#F2C4A0",
        yellow="#EFD8A6", rose="#F0A8B8",
    }
end

local function html_escape(value)
    return tostring(value or "")
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
end

local function transparent_css()
    if U and type(U.transparent_css) == "function" then return U.transparent_css() end
    return "QLabel {background-color:transparent;border:0px;padding:0px;}"
end

function HP:destroy()
    if self.root then
        pcall(function() self.root:hide() end)
        pcall(function() self.root:delete() end)
    end
    self.root = nil
    self.widgets = {}
    self.visible = false
end

function HP:panel_position(width, height)
    local ww, wh = 1366, 768
    if type(getMainWindowSize) == "function" then
        local w, h = getMainWindowSize()
        if type(w) == "number" and w > 0 then ww = w end
        if type(h) == "number" and h > 0 then wh = h end
    end
    return math.max(10, math.floor((ww - width) / 2)), math.max(10, math.floor((wh - height) / 2))
end

function HP:remember(widget)
    self.widgets[#self.widgets + 1] = widget
    return widget
end

function HP:fill_command(value)
    if type(setCmdLine) == "function" then
        setCmdLine(value)
        return
    end
    local c = palette()
    hecho("\n" .. c.text_muted .. "[Postacie] Komenda: " .. c.text .. value .. "\n")
end

function HP:command_css()
    local c = palette()
    return "QLabel {background-color:" .. c.background .. ";color:" .. c.mint
        .. ";border:1px solid " .. c.separator .. ";border-radius:4px;padding:0px 7px;} "
        .. "QLabel:hover {border-color:" .. c.lavender .. ";color:" .. c.lavender .. ";}"
end

function HP:add_section(prefix, x, y, width, height, title, accent, rows, note)
    local c = palette()
    local card = self:remember(Geyser.Label:new({
        name=prefix .. ".card", x=x, y=y, width=width, height=height,
    }, self.root))
    card:setStyleSheet("QLabel {background-color:" .. c.background_soft .. ";border:1px solid "
        .. c.separator .. ";border-radius:5px;padding:0px;}")

    local heading = self:remember(Geyser.Label:new({
        name=prefix .. ".title", x=10, y=8, width=width - 20, height=20, fontSize=9,
    }, card))
    heading:setStyleSheet(transparent_css())
    heading:echo("<font color='" .. accent .. "'>" .. html_escape(title) .. "</font>")

    for index, row in ipairs(rows) do
        local row_y = 36 + (index - 1) * 50
        local command = row.command
        local button = self:remember(Geyser.Label:new({
            name=prefix .. ".command." .. index, x=10, y=row_y, width=width - 20, height=23, fontSize=8,
        }, card))
        button:setStyleSheet(self:command_css())
        button:echo(html_escape(row.label or command))
        button:setClickCallback(function() HP:fill_command(command) end)
        pcall(setLabelCursor, button.name, "PointingHand")
        pcall(setLabelToolTip, button.name, "Kliknij, aby wstawic komende do linii polecen.", 8)

        local description = self:remember(Geyser.Label:new({
            name=prefix .. ".description." .. index, x=12, y=row_y + 25,
            width=width - 24, height=18, fontSize=7,
        }, card))
        description:setStyleSheet(transparent_css())
        description:echo("<font color='" .. c.text_muted .. "'>" .. html_escape(row.description) .. "</font>")
    end

    if note then
        local info = self:remember(Geyser.Label:new({
            name=prefix .. ".note", x=12, y=height - 54, width=width - 24, height=42, fontSize=7,
        }, card))
        info:setStyleSheet(transparent_css())
        info:echo("<font color='" .. c.text_muted .. "'>" .. html_escape(note) .. "</font>")
    end
end

function HP:open()
    if type(Geyser) ~= "table" or type(Geyser.Label) ~= "table" then return false end

    self:destroy()
    local c = palette()
    local pw, ph = 800, 520
    local x, y = self:panel_position(pw, ph)
    local prefix = "chimera_vip.characters_help_panel." .. tostring(os.time()) .. "." .. tostring(math.random(1000, 9999))

    self.root = Geyser.Label:new({name=prefix .. ".root", x=x, y=y, width=pw, height=ph})
    self.root:setStyleSheet("QLabel {background-color:" .. c.background .. ";border:1px solid "
        .. c.separator .. ";border-radius:7px;padding:0px;}")

    local title = self:remember(Geyser.Label:new({
        name=prefix .. ".title", x=14, y=8, width=690, height=22, fontSize=10,
    }, self.root))
    title:setStyleSheet(transparent_css())
    title:echo("<font color='" .. c.lavender .. "'>POSTACIE — POMOC</font>")

    local close = self:remember(Geyser.Label:new({
        name=prefix .. ".close", x=763, y=6, width=25, height=22, fontSize=11,
    }, self.root))
    close:setStyleSheet("QLabel {background-color:transparent;color:" .. c.text_muted
        .. ";border:0px;padding:0px;} QLabel:hover {color:" .. c.rose .. ";}")
    close:echo("<center>×</center>")
    close:setClickCallback(function() HP:destroy() end)
    pcall(setLabelCursor, close.name, "PointingHand")

    local subtitle = self:remember(Geyser.Label:new({
        name=prefix .. ".subtitle", x=14, y=34, width=760, height=18, fontSize=8,
    }, self.root))
    subtitle:setStyleSheet(transparent_css())
    subtitle:echo("<font color='" .. c.text_muted
        .. "'>Odmiany, relacje i kolorowanie imion — kliknij komende, aby wstawic ja do linii polecen.</font>")

    self:add_section(prefix .. ".basic", 14, 62, 379, 192, "PODSTAWOWE", c.blue, {
        {label="odmien <imie>", command="odmien <imie>", description="Zapisz lub odswiez wszystkie szesc odmian imienia."},
        {label="/postacie", command="/postacie", description="Pokaz liste zapisanych postaci i szybkie akcje."},
        {label="/postacie szukaj <tekst>", command="/postacie szukaj <tekst>", description="Szukaj po imieniu albo dowolnej znanej odmianie."},
    })

    self:add_section(prefix .. ".relations", 14, 264, 379, 242, "RELACJE", c.mint, {
        {label="/postacie grupa <imie> p / n / w / ?", command="/postacie grupa <imie> p", description="Ustaw przyjaciela, neutralnego, wroga albo brak relacji."},
        {label="/postacie highlight <imie> on / off", command="/postacie highlight <imie> on", description="Wlacz lub wylacz kolorowanie tylko tej postaci."},
        {label="/postacie info <imie>", command="/postacie info <imie>", description="Pokaz relacje, highlight i wszystkie zapisane formy."},
    })

    self:add_section(prefix .. ".colors", 407, 62, 379, 192, "KOLORY I WIDOCZNOSC", c.peach, {
        {label="/postacie kolor <grupa> <0-255 lub #RRGGBB>", command="/postacie kolor przyjaciele #A8DCC2", description="Ustaw kolor przyjaciol, neutralnych albo wrogow."},
        {label="/postacie on / off", command="/postacie on", description="Globalnie wlacz lub wylacz kolorowanie zapisanych imion."},
    }, "Kolory i globalny highlight sa zapisywane w ChimeraVIP-data/characters.lua.")

    self:add_section(prefix .. ".manage", 407, 264, 379, 242, "ZARZADZANIE", c.yellow, {
        {label="/postacie usun <imie>", command="/postacie usun <imie>", description="Usun postac wraz ze wszystkimi zapisanymi odmianami."},
        {label="/postacie pomoc", command="/postacie pomoc", description="Ponownie otworz to okno pomocy."},
    }, "Na liscie i w widoku info przycisk [USUN] zawsze prosi o potwierdzenie.")

    self.visible = true
    self.root:show()
    return true
end

if U and U.replace_handler then
    U.replace_handler(HP, "window_resize", "sysWindowResizeEvent", function()
        if HP.visible then
            tempTimer(0.1, function() if HP.visible then HP:open() end end)
        end
    end)
end

return HP
