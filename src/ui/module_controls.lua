chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util

C.module_controls = C.module_controls or {}
local M = C.module_controls
M.handlers = M.handlers or {}
M.button = M.button or nil
M.button_width = M.button_width or 0

local function P()
    if C.pastel_ui and C.pastel_ui.colors then return C.pastel_ui.colors end
    return {
        background_soft="#181C26", separator="#2B303C", text="#D8DCE6",
        text_muted="#AEB6C5", mint="#A8DCC2", lavender="#C7B9E8", rose="#F0A8B8",
    }
end

function M:destroy_ui()
    if not self.button then return end
    pcall(function() self.button:hide() end)
    pcall(function() self.button:delete() end)
    self.button = nil
end

function M:is_combat_colors_enabled()
    return C.settings and C.settings:is_module_enabled("combat_colors", true) or true
end

function M:update_ui()
    local b = self.button
    if not b then return end

    local palette = P()
    local enabled = self:is_combat_colors_enabled()
    local color = enabled and palette.mint or palette.rose
    local label = self.button_width >= 35
        and (enabled and "KOL ●" or "KOL ○")
        or (enabled and "KOL●" or "KOL○")

    b:setStyleSheet(
        "QLabel {background-color:" .. palette.background_soft
        .. ";color:" .. color
        .. ";border:1px solid " .. palette.separator
        .. ";border-radius:3px;padding:0px;font-size:7px;}"
        .. " QLabel:hover {border-color:" .. palette.lavender .. ";color:" .. palette.lavender .. ";}"
    )
    b:echo("<center>" .. label .. "</center>")

    local tooltip = "<b>Kolory walki ChimeraVIP</b>"
        .. "<br>Stan: <b>" .. (enabled and "ON" or "OFF") .. "</b>"
        .. "<br><br>ON: pastelowe prefiksy ChimeraVIP, oficjalny folder gags wyłączony."
        .. "<br>OFF: prefiksy ChimeraVIP usunięte, oficjalny folder gags włączony."
        .. "<br><br>Kliknij, aby przełączyć."

    pcall(setLabelToolTip, b.name, tooltip, 8)
    pcall(setLabelCursor, b.name, "PointingHand")
end

function M:toggle()
    if not C.settings then return end
    local enabled = C.settings:toggle_module("combat_colors")
    cecho("\n<aquamarine>[ChimeraVIP]<reset> Kolory walki: " .. (enabled and "ON" or "OFF") .. ".\n")
    self:update_ui()
end

function M:attach_ui()
    local HUD = C.quiet_footer
    if not HUD or not HUD.zone3 or not HUD.layout then return end

    self:destroy_ui()

    local width = HUD.layout.zone3_width or 0
    if width < 92 then return end

    local padding, gap, cols = 2, 3, 4
    local bw = math.floor((width - padding * 2 - gap * (cols - 1)) / cols)
    bw = math.max(20, math.min(44, bw))

    -- Ósme, wolne pole siatki footer_controls: drugi rząd, czwarta kolumna.
    local x = padding + 3 * (bw + gap)
    local y = 57
    local name = "chimera_vip.module_controls." .. tostring(HUD.generation or 0) .. ".combat_colors"

    self.button = Geyser.Label:new({name=name, x=x, y=y, width=bw, height=14, fontSize=7}, HUD.zone3)
    self.button_width = bw
    self.button:setClickCallback(function() M:toggle() end)
    self:update_ui()
end

if U and U.replace_handler then
    U.replace_handler(M, "footer_ready", "chimeraFooterReady", function()
        tempTimer(0, function() M:attach_ui() end)
    end)

    U.replace_handler(M, "module_changed", "chimeraVipModuleChanged", function(_, id)
        if tostring(id) == "combat_colors" then M:update_ui() end
    end)
end

if C.quiet_footer and C.quiet_footer.zone3 then tempTimer(0, function() M:attach_ui() end) end

return M
