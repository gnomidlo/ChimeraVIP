-- ChimeraVIP / Characters Color Panel
-- Klikalny wybor kolorow grup w stylistyce panelu ustawien.

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
HP.rows = {}
HP.visible = false

HP.presets = {
    "#A8DCC2", "#AFCBF4", "#C7B9E8", "#F2C4A0",
    "#EFD8A6", "#F0A8B8", "#D8DCE6", "#E8A87C",
}

HP.groups = {
    {id="przyjaciele", label="PRZYJACIELE", accent="mint"},
    {id="neutralni", label="NEUTRALNI", accent="text"},
    {id="wrogowie", label="WROGOWIE", accent="rose"},
}

local function palette()
    if C.pastel_ui and C.pastel_ui.colors then return C.pastel_ui.colors end
    return {
        background="#12151D", background_soft="#181C26", separator="#2B303C",
        text="#D8DCE6", text_muted="#AEB6C5", mint="#A8DCC2",
        lavender="#C7B9E8", blue="#AFCBF4", peach="#F2C4A0",
        yellow="#EFD8A6", rose="#F0A8B8",
    }
end

local function transparent_css()
    if U and type(U.transparent_css) == "function" then return U.transparent_css() end
    return "QLabel {background-color:transparent;border:0px;padding:0px;}"
end

local function normalized_hex(value)
    local hex = tostring(value or ""):match("^#?(%x%x%x%x%x%x)$")
    return hex and ("#" .. hex:upper()) or nil
end

function HP:destroy()
    if self.root then
        pcall(function() self.root:hide() end)
        pcall(function() self.root:delete() end)
    end
    self.root = nil
    self.widgets = {}
    self.rows = {}
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

function HP:current_hex(group)
    local characters = C.characters
    if not characters or not characters.data or not characters.data.colors then return "#D8DCE6" end
    local value = characters.data.colors[group]
    local direct = normalized_hex(value)
    if direct then return direct end
    if type(characters.color_to_rgb) == "function" then
        local r, g, b = characters:color_to_rgb(value)
        if r then return string.format("#%02X%02X%02X", r, g, b) end
    end
    return "#D8DCE6"
end

function HP:fill_custom_command(group)
    local command = "/postacie kolor " .. group .. " #RRGGBB"
    if type(setCmdLine) == "function" then
        setCmdLine(command)
        return
    end
    local c = palette()
    hecho("\n" .. c.text_muted .. "[Postacie] Komenda: " .. c.text .. command .. "\n")
end

function HP:set_group_color(group, color)
    if C.characters and type(C.characters.set_color) == "function" then
        C.characters:set_color(group, color)
        self:update()
    end
end

function HP:swatch_css(color, selected)
    local c = palette()
    return "QLabel {background-color:" .. color .. ";border:" .. (selected and "3px" or "1px")
        .. " solid " .. (selected and c.lavender or c.separator)
        .. ";border-radius:4px;padding:0px;} QLabel:hover {border:2px solid " .. c.text .. ";}"
end

function HP:custom_css()
    local c = palette()
    return "QLabel {background-color:" .. c.background .. ";color:" .. c.text_muted
        .. ";border:1px solid " .. c.separator .. ";border-radius:4px;padding:0px;} "
        .. "QLabel:hover {border-color:" .. c.lavender .. ";color:" .. c.lavender .. ";}"
end

function HP:update()
    if not self.visible then return end
    local c = palette()
    for group, row in pairs(self.rows or {}) do
        local current = self:current_hex(group)
        row.preview:setStyleSheet("QLabel {background-color:" .. current .. ";border:1px solid "
            .. c.separator .. ";border-radius:4px;padding:0px;}")
        row.value:echo("<font color='" .. c.text .. "'>" .. current .. "</font>")
        for color, swatch in pairs(row.swatches) do
            swatch:setStyleSheet(self:swatch_css(color, color == current))
        end
    end
end

function HP:add_group_row(prefix, definition, y)
    local c = palette()
    local group = definition.id
    local card = self:remember(Geyser.Label:new({
        name=prefix .. ".card", x=14, y=y, width=652, height=58,
    }, self.root))
    card:setStyleSheet("QLabel {background-color:" .. c.background_soft .. ";border:1px solid "
        .. c.separator .. ";border-radius:5px;padding:0px;}")

    local label = self:remember(Geyser.Label:new({
        name=prefix .. ".label", x=12, y=18, width=112, height=22, fontSize=8,
    }, card))
    label:setStyleSheet(transparent_css())
    label:echo("<font color='" .. (c[definition.accent] or c.text) .. "'>" .. definition.label .. "</font>")

    local preview = self:remember(Geyser.Label:new({
        name=prefix .. ".preview", x=122, y=11, width=36, height=36,
    }, card))

    local value = self:remember(Geyser.Label:new({
        name=prefix .. ".value", x=168, y=18, width=70, height=22, fontSize=8,
    }, card))
    value:setStyleSheet(transparent_css())

    local swatches = {}
    local start_x, size, gap = 238, 30, 6
    for index, color in ipairs(self.presets) do
        local selected_color = color
        local swatch = self:remember(Geyser.Label:new({
            name=prefix .. ".swatch." .. index,
            x=start_x + (index - 1) * (size + gap), y=14, width=size, height=size,
        }, card))
        swatch:setClickCallback(function() HP:set_group_color(group, selected_color) end)
        pcall(setLabelCursor, swatch.name, "PointingHand")
        pcall(setLabelToolTip, swatch.name, "Ustaw " .. selected_color .. " dla grupy " .. group .. ".", 8)
        swatches[selected_color] = swatch
    end

    local custom = self:remember(Geyser.Label:new({
        name=prefix .. ".custom", x=534, y=14, width=104, height=30, fontSize=8,
    }, card))
    custom:setStyleSheet(self:custom_css())
    custom:echo("<center>WLASNY HEX</center>")
    custom:setClickCallback(function() HP:fill_custom_command(group) end)
    pcall(setLabelCursor, custom.name, "PointingHand")
    pcall(setLabelToolTip, custom.name, "Wstaw komende z wlasnym kolorem #RRGGBB.", 8)

    self.rows[group] = {preview=preview, value=value, swatches=swatches}
end

function HP:open()
    if type(Geyser) ~= "table" or type(Geyser.Label) ~= "table" then return false end

    self:destroy()
    local c = palette()
    local pw, ph = 680, 286
    local x, y = self:panel_position(pw, ph)
    local prefix = "chimera_vip.characters_color_panel." .. tostring(os.time()) .. "." .. tostring(math.random(1000, 9999))

    self.root = Geyser.Label:new({name=prefix .. ".root", x=x, y=y, width=pw, height=ph})
    self.root:setStyleSheet("QLabel {background-color:" .. c.background .. ";border:1px solid "
        .. c.separator .. ";border-radius:7px;padding:0px;}")

    local title = self:remember(Geyser.Label:new({
        name=prefix .. ".title", x=14, y=8, width=580, height=22, fontSize=10,
    }, self.root))
    title:setStyleSheet(transparent_css())
    title:echo("<font color='" .. c.lavender .. "'>POSTACIE — KOLORY GRUP</font>")

    local close = self:remember(Geyser.Label:new({
        name=prefix .. ".close", x=643, y=6, width=25, height=22, fontSize=11,
    }, self.root))
    close:setStyleSheet("QLabel {background-color:transparent;color:" .. c.text_muted
        .. ";border:0px;padding:0px;} QLabel:hover {color:" .. c.rose .. ";}")
    close:echo("<center>×</center>")
    close:setClickCallback(function() HP:destroy() end)
    pcall(setLabelCursor, close.name, "PointingHand")

    local subtitle = self:remember(Geyser.Label:new({
        name=prefix .. ".subtitle", x=14, y=34, width=640, height=18, fontSize=8,
    }, self.root))
    subtitle:setStyleSheet(transparent_css())
    subtitle:echo("<font color='" .. c.text_muted
        .. "'>Wybierz pastelowa probke albo kliknij WLASNY HEX, aby wpisac dowolny kolor.</font>")

    for index, definition in ipairs(self.groups) do
        self:add_group_row(prefix .. "." .. definition.id, definition, 62 + (index - 1) * 66)
    end

    self.visible = true
    self.root:show()
    self:update()
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
