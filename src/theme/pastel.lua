chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip
local C = chimera_vip
local U = C.util

local UI = C.pastel_ui or {}
C.pastel_ui = UI
chimera_overlay.pastel_ui = UI

UI.theme_name = "chimera_vip_pastel"
UI.handlers = UI.handlers or {}
UI.applying = false
UI.ensure_timer = nil
UI.colors = UI.colors or {
    background = "#12151D", background_soft = "#181C26", separator = "#2B303C", inactive = "#303542",
    text = "#D8DCE6", text_muted = "#AEB6C5", rose = "#F0A8B8", mint = "#A8DCC2",
    blue = "#AFCBF4", lavender = "#C7B9E8", peach = "#F2C4A0", yellow = "#EFD8A6",
}

local function hex_rgb(hex)
    local r,g,b=tostring(hex):match("#?(%x%x)(%x%x)(%x%x)")
    if not r then return 18,21,29 end
    return tonumber(r,16),tonumber(g,16),tonumber(b,16)
end

function UI:get_states_font_size()
    if C.settings and type(C.settings.get)=="function" then
        local n=tonumber(C.settings:get("ui.states_font_size",10))
        if n then return math.max(7,math.min(14,math.floor(n+0.5))) end
    end
    return 10
end

function UI:install_theme()
    if not scripts or not scripts.ui or not scripts.ui.themes or not scripts.ui.themes.plain then return false end
    local P=self.colors
    local theme=scripts.ui.themes.plain:new(); theme._chimera_vip_pastel=true
    function theme:apply_app_stylesheet()
        setAppStyleSheet([[QDockWidget { background-color: ]]..P.background..[[; color: ]]..P.text..[[; }
QDockWidget::title { background-color: ]]..P.background_soft..[[; color: ]]..P.text_muted..[[; padding: 4px 8px; border-bottom: 1px solid ]]..P.separator..[[; }
QToolBar { background-color: ]]..P.background..[[; background-image: none; border: 0px; border-bottom: 1px solid ]]..P.separator..[[; }]])
    end
    function theme:get_footer_stylesheet() return "background-color:"..P.background..";background-image:none;border:0px;border-top:1px solid "..P.separator..";" end
    function theme:get_window_stylesheet() return "QWidget { padding:4px; background-color:"..P.background.."; background-image:none; color:"..P.text.."; }" end
    function theme:get_button_window_stylesheet(height) return string.format("QWidget { padding:%dpx 4px 4px 4px; background-color:%s; background-image:none; color:%s; }",height+4,P.background,P.text) end
    function theme:get_button_area_bg() return "background-color:"..P.background_soft..";background-image:none;border:0px;border-bottom:1px solid "..P.separator..";" end
    function theme:get_border_stylesheet() return "background:none;border:1px solid "..P.separator..";" end
    function theme:get_notification_color() return closestColor(P.lavender) end
    function theme:get_notification_stylesheet() return "QLabel { color:"..P.text.."; padding:7px 10px; border:1px solid "..P.separator.."; border-radius:5px; background-color:"..P.background_soft.."; qproperty-wordWrap:true; }" end
    function theme:get_notification_close_stylesheet() return "QLabel { background-color:transparent;color:"..P.text_muted..";border:0px;} QLabel:hover {color:"..P.rose..";}" end
    function theme:get_button_stylesheet(_,font_size) return "QLabel {border:1px solid "..P.separator..";border-radius:3px;padding:0px 5px;background-color:"..P.background_soft..";background-image:none;color:"..P.text..";font-size:"..tostring(font_size).."px;} QLabel:hover {border-color:"..P.lavender..";color:"..P.lavender..";}" end
    scripts.ui.themes[self.theme_name]=theme
    return true
end

function UI:select_theme()
    if not self:install_theme() then return false end
    local P=self.colors
    scripts.ui.theme=self.theme_name
    scripts.ui.footer_color=P.background
    scripts.ui.footer_info_normal=P.text_muted
    scripts.ui.footer_info_neutral=P.yellow
    scripts.ui.footer_info_green=P.mint
    scripts.ui.footer_info_yellow=P.yellow
    scripts.ui.footer_info_red=P.rose
    scripts.ui.states_font_size=self:get_states_font_size()
    return true
end

function UI:is_current()
    return scripts and scripts.ui and scripts.ui.theme==self.theme_name and scripts.ui.current_theme and scripts.ui.current_theme._chimera_vip_pastel==true
end

function UI:style_console(name,font_size)
    local br,bg,bb=hex_rgb(self.colors.background); local fr,fg,fb=hex_rgb(self.colors.text)
    pcall(setBackgroundColor,name,br,bg,bb,255); pcall(setFgColor,name,fr,fg,fb)
    if font_size then pcall(setFontSize,name,font_size) end
end

function UI:style_known_windows()
    local states_size=self:get_states_font_size()
    self:style_console("states_window",states_size)
    self:style_console("enemy_states_window",states_size)
    self:style_console("talk_window"); self:style_console("team_talk_window")
    self:style_console("combat_window"); self:style_console("search_results")
end

function UI:finish_ready()
    if not self:is_current() then return false end
    self:style_known_windows(); C.theme_ready=true; chimera_overlay.theme_ready=true; raiseEvent("chimeraThemeReady",self.theme_name); return true
end

function UI:apply()
    if self.applying or not self:select_theme() or not scripts.ui.setup then return end
    self.applying=true; C.theme_ready=false; chimera_overlay.theme_ready=false
    local ok,err=pcall(function() scripts.ui:setup() end); self.applying=false
    if not ok then cecho("\n<orange>[ChimeraVIP]<reset> Nie udalo sie zastosowac motywu: "..tostring(err).."\n"); return end
    self:finish_ready()
end

function UI:ensure()
    if self.applying or not self:select_theme() then return end
    if not scripts.ui.bottom then return end
    if not self:is_current() then self:apply(); return end
    self:finish_ready()
end

function UI:schedule_ensure(delay)
    if self.ensure_timer then pcall(killTimer,self.ensure_timer) end
    self.ensure_timer=tempTimer(delay or 0,function() UI.ensure_timer=nil; UI:ensure() end)
end

U.replace_handler(UI,"vip_ready","chimeraVipReady",function() UI:schedule_ensure(0) end)
U.replace_handler(UI,"sys_load","sysLoadEvent",function() UI:schedule_ensure(0.10) end)
U.replace_handler(UI,"ui_ready","uiReady",function() if not UI.applying then UI:schedule_ensure(0) end end)
if scripts_loaded==true and scripts and scripts.ui then UI:schedule_ensure(0) end

return UI
