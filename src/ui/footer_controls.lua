chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip
local C = chimera_vip
local U = C.util

local CTRL = C.footer_controls or {}
C.footer_controls = CTRL
chimera_overlay.footer_controls = CTRL
CTRL.handlers = CTRL.handlers or {}
CTRL.buttons = CTRL.buttons or {}
CTRL.button_widths = CTRL.button_widths or {}
CTRL.refresh_timer = nil

local function P()
    if C.pastel_ui and C.pastel_ui.colors then return C.pastel_ui.colors end
    return {
        background="#12151D", background_soft="#181C26", separator="#2B303C",
        text="#D8DCE6", text_muted="#AEB6C5", mint="#A8DCC2", blue="#AFCBF4",
        lavender="#C7B9E8", peach="#F2C4A0", yellow="#EFD8A6", rose="#F0A8B8",
    }
end

local function clean(v)
    return tostring(v or "")
        :gsub("<[^>]->", "")
        :gsub("&nbsp;", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end

local function is_active(v)
    if v == true then return true end
    if v == false or v == nil then return false end
    if type(v) == "number" then return v > 0 end
    local s = tostring(v):lower():gsub("^%s+", ""):gsub("%s+$", "")
    return s ~= "" and s ~= "0" and s ~= "false" and s ~= "off" and s ~= "nie"
end

local function mode_text(table_ref, mode)
    if not mode or type(table_ref) ~= "table" then return "" end
    return clean(table_ref[mode])
end

function CTRL:warn(text)
    cecho("\n<orange>[ChimeraVIP]<reset> " .. tostring(text) .. "\n")
end

function CTRL:call_global(name)
    local fn = _G[name]
    if type(fn) ~= "function" then
        self:warn("Funkcja " .. name .. " nie jest dostepna.")
        return false
    end
    local ok, err = pcall(fn)
    if not ok then
        self:warn("Blad kontrolki: " .. tostring(err))
        return false
    end
    return true
end

function CTRL:get_definition(key)
    for _, def in ipairs(self.definitions or {}) do
        if def.key == key then return def end
    end
    return nil
end

function CTRL:click(key)
    local def = self:get_definition(key)
    local state = def and def.state and def.state() or nil
    if state and state.clickable == false then return end

    if key == "hidden" then
        self:call_global("scripts_ui_info_hidden_click")
    elseif key == "sneaky" then
        self:call_global("scripts_ui_info_sneaky_click")
    elseif key == "attack" then
        self:call_global("scripts_ui_info_attack_mode_click")
    elseif key == "collect" then
        self:call_global("scripts_ui_info_collect_mode")
    elseif key == "lamp" then
        self:call_global("scripts_ui_info_lamp_click")
    elseif key == "cover" then
        self:call_global("scripts_ui_info_cover_ready_click")
    elseif key == "combat" then
        local combat = scripts and scripts.character and scripts.character.combat_state
        if combat and type(combat.run_command) == "function" then
            local ok, err = pcall(function() combat:run_command() end)
            if not ok then self:warn("Blad kontrolki walki: " .. tostring(err)) end
        else
            self:warn("Funkcja sterowania walka nie jest dostepna.")
        end
    end

    -- Część oficjalnych modułów aktualizuje stan z niewielkim opóźnieniem.
    tempTimer(0.05, function() CTRL:update_all() end)
    tempTimer(0.30, function() CTRL:update_all() end)
end

function CTRL:get_hidden_state()
    local v = scripts and scripts.ui and scripts.ui.states_window_nav_states
        and scripts.ui.states_window_nav_states.hidden_state

    if v == nil or v == false or v == "" then
        return {
            color=P().text_muted, text="nieukryta", label="UKR", compact="UKR",
            action="użyj oficjalnej funkcji ukrywania",
        }
    end

    if tostring(v):lower() == "ok" then
        return {
            color=P().mint, text="ukryta: ok", label="UKR ●", compact="UKR●",
            action="użyj oficjalnej funkcji ukrywania",
        }
    end

    local n = tonumber(v)
    if n then
        return {
            color=n < 5 and P().rose or (n < 10 and P().yellow or P().mint),
            text="ukrycie: " .. tostring(n), label="UKR " .. tostring(n), compact="UKR",
            action="użyj oficjalnej funkcji ukrywania",
        }
    end

    return {
        color=P().lavender, text=tostring(v), label="UKR", compact="UKR",
        action="użyj oficjalnej funkcji ukrywania",
    }
end

function CTRL:get_sneaky_state()
    local mode = amap and tonumber(amap.walk_mode) or 1
    if mode == 1 then
        return {color=P().text_muted, text="wyłączone", label="PRZ OFF", compact="PRZ 1", action="przełącz na następny tryb"}
    elseif mode == 2 then
        return {color=P().lavender, text="ja", label="PRZ JA", compact="PRZ 2", action="przełącz na następny tryb"}
    elseif mode == 3 then
        return {color=P().mint, text="ja + drużyna", label="PRZ DRU", compact="PRZ 3", action="przełącz na następny tryb"}
    end
    return {
        color=P().text_muted, text="tryb " .. tostring(mode), label="PRZ " .. tostring(mode), compact="PRZ",
        action="przełącz na następny tryb",
    }
end

function CTRL:get_attack_state()
    local mode = ateam and tonumber(ateam.attack_mode)
    local official = mode_text(ateam and ateam.footer_info_attack_mode_to_text, mode)
    local text = official ~= "" and official or (mode and ("tryb " .. tostring(mode)) or "brak danych")
    return {
        color=mode and P().blue or P().text_muted,
        text=text,
        label=mode and ("ATK " .. tostring(mode)) or "ATK",
        compact=mode and ("ATK " .. tostring(mode)) or "ATK",
        action="przełącz na następny oficjalny tryb ataku",
    }
end

function CTRL:get_collect_state()
    local col = scripts and scripts.inv and scripts.inv.collect
    if not col then
        return {color=P().text_muted, text="brak danych", label="ZBI", compact="ZBI", action="przełącz tryb zbierania"}
    end

    local mode = tonumber(col.current_mode)
    local official = mode_text(col.footer_info_collect_to_text, mode)
    local text = official ~= "" and official or (mode and ("tryb " .. tostring(mode)) or "brak danych")
    return {
        color=mode and P().peach or P().text_muted,
        text=text,
        label=mode and ("ZBI " .. tostring(mode)) or "ZBI",
        compact=mode and ("ZBI " .. tostring(mode)) or "ZBI",
        action="przełącz na następny oficjalny tryb zbierania",
    }
end

function CTRL:get_lamp_state()
    local working = scripts and scripts.inv and scripts.inv.lamp and scripts.inv.lamp.working
    if is_active(working) then
        return {color=P().yellow, text="zapalona", label="LAM ●", compact="LAM●", action="zgaś lampę"}
    end
    return {color=P().text_muted, text="zgaszona", label="LAM ○", compact="LAM○", action="zapal lampę"}
end

function CTRL:get_combat_state()
    local combat = scripts and scripts.character and scripts.character.combat_state
    if not combat then
        return {
            color=P().text_muted, text="brak danych", label="WAL", compact="WAL",
            clickable=false, action="niedostępne — brak modułu stanu walki",
        }
    end

    if is_active(combat.state) then
        return {
            color=P().rose, text="walka", label="WALKA ●", compact="WAL ●",
            action="wykonaj akcję oficjalnego modułu stanu walki",
        }
    end

    local cd = tonumber(combat.time_after_combat) or 0
    if cd > 0 then
        local rounded = math.max(1, math.ceil(cd))
        return {
            color=P().yellow, text="odpoczynek: " .. tostring(rounded) .. " s",
            label="WAL " .. tostring(rounded) .. "s", compact="WAL " .. tostring(rounded),
            action="wykonaj akcję oficjalnego modułu stanu walki",
        }
    end

    return {
        color=P().text_muted, text="poza walką", label="WAL", compact="WAL",
        action="wykonaj akcję oficjalnego modułu stanu walki",
    }
end

function CTRL:get_cover_state()
    local nav = scripts and scripts.ui and scripts.ui.states_window_nav_states
    local value = nav and nav.guard_state
    local ready = scripts and scripts.ui and scripts.ui.footer_info_cover_ready_enable_click

    if is_active(ready) then
        return {
            color=P().mint, text="gotowa", label="ZAS ✓", compact="ZAS✓",
            clickable=true, action="wykonaj oficjalną akcję zasłony",
        }
    end

    local n = tonumber(value)
    if n and n > 0 then
        local rounded = math.max(1, math.ceil(n))
        return {
            color=P().rose, text="odnowienie: " .. tostring(rounded),
            label="ZAS " .. tostring(rounded), compact="ZAS " .. tostring(rounded),
            clickable=false, action="niedostępne podczas odnowienia",
        }
    end

    return {
        color=P().text_muted, text="brak gotowości", label="ZAS —", compact="ZAS-",
        clickable=false, action="niedostępne w tej chwili",
    }
end

CTRL.definitions = {
    {key="hidden", label="UKR", title="Ukrywanie", kind="stan", state=function() return CTRL:get_hidden_state() end},
    {key="sneaky", label="PRZ", title="Przemykanie", kind="tryb cykliczny", state=function() return CTRL:get_sneaky_state() end},
    {key="attack", label="ATK", title="Tryb ataku", kind="tryb cykliczny", state=function() return CTRL:get_attack_state() end},
    {key="collect", label="ZBI", title="Zbieranie", kind="tryb cykliczny", state=function() return CTRL:get_collect_state() end},
    {key="lamp", label="LAM", title="Lampa", kind="przełącznik", state=function() return CTRL:get_lamp_state() end},
    {key="combat", label="WAL", title="Walka", kind="stan / akcja", state=function() return CTRL:get_combat_state() end},
    {key="cover", label="ZAS", title="Zasłona", kind="akcja warunkowa", state=function() return CTRL:get_cover_state() end},
}

function CTRL:destroy_ui()
    for _, b in pairs(self.buttons) do
        pcall(function() b:hide() end)
        pcall(function() b:delete() end)
    end
    self.buttons = {}
    self.button_widths = {}
end

function CTRL:button_css(color, clickable)
    local c = P()
    local css = "QLabel {background-color:" .. c.background_soft
        .. ";color:" .. color
        .. ";border:1px solid " .. c.separator
        .. ";border-radius:3px;padding:0px;font-size:7px;}"

    if clickable ~= false then
        css = css .. " QLabel:hover {border-color:" .. c.lavender .. ";color:" .. c.lavender .. ";}"
    end
    return css
end

function CTRL:display_label(def, state, width)
    if width >= 35 and state.label and state.label ~= "" then return state.label end
    if width >= 27 and state.compact and state.compact ~= "" then return state.compact end
    return def.label
end

function CTRL:update_button(def)
    local b = self.buttons[def.key]
    if not b then return end

    local state = def.state() or {
        color=P().text_muted, text="brak danych", label=def.label, compact=def.label,
        clickable=false, action="niedostępne",
    }

    local width = self.button_widths[def.key] or 30
    local clickable = state.clickable ~= false
    local label = self:display_label(def, state, width)

    b:setStyleSheet(self:button_css(state.color or P().text_muted, clickable))
    b:echo("<center>" .. tostring(label) .. "</center>")

    local tooltip = "<b>" .. def.title .. "</b>"
        .. "<br>Typ: " .. tostring(def.kind or "kontrolka")
        .. "<br>Stan: <b>" .. tostring(state.text or "brak danych") .. "</b>"
        .. "<br><br>Kliknięcie: " .. tostring(state.action or "wykonaj akcję") .. "."

    pcall(setLabelToolTip, b.name, tooltip, 8)
    pcall(setLabelCursor, b.name, clickable and "PointingHand" or "ArrowCursor")
end

function CTRL:update_all()
    for _, def in ipairs(self.definitions) do self:update_button(def) end
end

function CTRL:attach_ui()
    local HUD = C.quiet_footer
    if not HUD or not HUD.zone3 or not HUD.layout then return end

    self:destroy_ui()

    local width = HUD.layout.zone3_width or 0
    if width < 92 then return end

    local padding, gap, cols = 2, 3, 4
    local bw = math.floor((width - padding * 2 - gap * (cols - 1)) / cols)
    bw = math.max(20, math.min(44, bw))

    local ys = {40, 57}
    local bh = 14

    for i, def in ipairs(self.definitions) do
        local row = math.floor((i - 1) / cols) + 1
        local col = (i - 1) % cols
        local x = padding + col * (bw + gap)
        local y = ys[row]
        local key = def.key
        local name = "chimera_vip.footer_controls." .. tostring(HUD.generation or 0) .. "." .. key

        local b = Geyser.Label:new({name=name, x=x, y=y, width=bw, height=bh, fontSize=7}, HUD.zone3)
        b:setClickCallback(function() CTRL:click(key) end)

        self.buttons[key] = b
        self.button_widths[key] = bw
    end

    self:update_all()
end

function CTRL:start_refresh()
    if self.refresh_timer then pcall(killTimer, self.refresh_timer) end
    self.refresh_timer = tempTimer(0.75, function() CTRL:update_all() end, true)
end

U.replace_handler(CTRL, "footer_ready", "chimeraFooterReady", function()
    tempTimer(0, function() CTRL:attach_ui() end)
end)

if C.quiet_footer and C.quiet_footer.zone3 then
    tempTimer(0, function() CTRL:attach_ui() end)
end

CTRL:start_refresh()

return CTRL
