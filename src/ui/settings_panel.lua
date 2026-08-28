chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util

C.settings_panel = C.settings_panel or {}
local SP = C.settings_panel

if SP.root then pcall(function() SP.root:hide() end); pcall(function() SP.root:delete() end) end
SP.handlers = SP.handlers or {}
SP.root=nil; SP.size_buttons={}; SP.module_buttons={}; SP.visible=false

local function P()
    if C.pastel_ui and C.pastel_ui.colors then return C.pastel_ui.colors end
    return {background="#12151D",background_soft="#181C26",separator="#2B303C",text="#D8DCE6",text_muted="#AEB6C5",mint="#A8DCC2",lavender="#C7B9E8",rose="#F0A8B8"}
end

function SP:destroy()
    if self.root then pcall(function() self.root:hide() end); pcall(function() self.root:delete() end) end
    self.root=nil; self.size_buttons={}; self.module_buttons={}; self.visible=false
end

function SP:panel_position(width,height)
    local ww,wh=1366,768
    if type(getMainWindowSize)=="function" then local w,h=getMainWindowSize(); if type(w)=="number" and w>0 then ww=w end; if type(h)=="number" and h>0 then wh=h end end
    return math.max(10,math.floor((ww-width)/2)),math.max(10,math.floor((wh-height)/2))
end

function SP:size_css(_,selected)
    local c=P(); return "QLabel {background-color:"..c.background_soft..";color:"..(selected and c.mint or c.text)..";border:1px solid "..(selected and c.mint or c.separator)..";border-radius:4px;padding:0px;} QLabel:hover {border-color:"..c.lavender..";color:"..c.lavender..";}"
end
function SP:module_css(enabled)
    local c=P(); return "QLabel {background-color:"..c.background_soft..";color:"..(enabled and c.mint or c.rose)..";border:1px solid "..c.separator..";border-radius:4px;padding:0px;font-size:9px;} QLabel:hover {border-color:"..c.lavender..";color:"..c.lavender..";}"
end

function SP:update()
    if not self.visible or not C.settings then return end
    local selected=tonumber(C.settings:get("ui.states_font_size",10)) or 10
    for size,button in pairs(self.size_buttons or {}) do button:setStyleSheet(self:size_css(size,size==selected)); button:echo("<center>"..tostring(size).."</center>") end

    local defs={
        combat_colors={label="KOL",tip="Combat Colors\nON: prefiksy ChimeraVIP, oficjalny gags wyłączony.\nOFF: oficjalny gags włączony."},
        postacie={label="POST",tip="Postacie\nRejestr odmian i relacji.\nGlobalne kolorowanie można dodatkowo wyłączyć komendą /postacie off."},
    }
    for id,button in pairs(self.module_buttons or {}) do
        local def=defs[id]; local enabled=C.settings:is_module_enabled(id,true)
        button:setStyleSheet(self:module_css(enabled)); button:echo("<center>"..def.label.." "..(enabled and "● ON" or "○ OFF").."</center>")
        pcall(setLabelToolTip,button.name,def.tip,8)
    end
end

function SP:set_font_size(size) if C.settings then C.settings:set_states_font_size(size); self:update() end end
function SP:toggle_module(id)
    if not C.settings then return end
    local enabled=C.settings:toggle_module(id); if enabled==nil then return end
    cecho("\n<aquamarine>[ChimeraVIP]<reset> "..id..": "..(enabled and "ON" or "OFF")..".\n"); self:update()
end

function SP:open()
    self:destroy()
    local c=P(); local pw,ph=492,180; local x,y=self:panel_position(pw,ph); local prefix="chimera_vip.settings_panel."..tostring(os.time()).."."..tostring(math.random(1000,9999))
    self.root=Geyser.Label:new({name=prefix..".root",x=x,y=y,width=pw,height=ph}); self.root:setStyleSheet("QLabel {background-color:"..c.background..";border:1px solid "..c.separator..";border-radius:7px;padding:0px;}")
    local title=Geyser.Label:new({name=prefix..".title",x=14,y=8,width=420,height=22,fontSize=10},self.root); title:setStyleSheet(U.transparent_css()); title:echo("<font color='"..c.lavender.."'>CHIMERAVIP — USTAWIENIA</font>")
    local close=Geyser.Label:new({name=prefix..".close",x=455,y=6,width=25,height=22,fontSize=11},self.root); close:setStyleSheet("QLabel {background-color:transparent;color:"..c.text_muted..";border:0px;padding:0px;} QLabel:hover {color:"..c.rose..";}"); close:echo("<center>×</center>"); close:setClickCallback(function() SP:destroy() end); pcall(setLabelCursor,close.name,"PointingHand")
    local subtitle=Geyser.Label:new({name=prefix..".subtitle",x=14,y=34,width=460,height=18,fontSize=8},self.root); subtitle:setStyleSheet(U.transparent_css()); subtitle:echo("<font color='"..c.text_muted.."'>Rozmiar tekstu okna stanów (drużyna / wrogowie / inni) — kliknij:</font>")
    local sizes={7,8,9,10,11,12,13,14}; local start_x,gap,bw=14,6,52
    for i,size in ipairs(sizes) do local value=size; local b=Geyser.Label:new({name=prefix..".size."..value,x=start_x+(i-1)*(bw+gap),y=56,width=bw,height=42,fontSize=value},self.root); b:setClickCallback(function() SP:set_font_size(value) end); pcall(setLabelCursor,b.name,"PointingHand"); pcall(setLabelToolTip,b.name,"Ustaw rozmiar tekstu okna stanów na "..value..".",8); self.size_buttons[value]=b end

    local ml=Geyser.Label:new({name=prefix..".module_label",x=14,y=108,width=250,height=22,fontSize=8},self.root); ml:setStyleSheet(U.transparent_css()); ml:echo("<font color='"..c.text_muted.."'>Moduły:</font>")
    self.module_buttons={}
    local modules={{id="combat_colors",label="Kolory walki",y=132},{id="postacie",label="Postacie",y=132}}
    local lx={14,248}; local bx={122,365}
    for i,m in ipairs(modules) do
        local lab=Geyser.Label:new({name=prefix..".label."..m.id,x=lx[i],y=m.y,width=105,height=28,fontSize=8},self.root); lab:setStyleSheet(U.transparent_css()); lab:echo("<font color='"..c.text.."'>"..m.label.."</font>")
        local b=Geyser.Label:new({name=prefix..".module."..m.id,x=bx[i],y=m.y-3,width=113,height=28,fontSize=9},self.root); b:setClickCallback(function() SP:toggle_module(m.id) end); pcall(setLabelCursor,b.name,"PointingHand"); self.module_buttons[m.id]=b
    end

    self.visible=true; self.root:show(); self:update()
end

if U and U.replace_handler then
    U.replace_handler(SP,"settings_changed","chimeraVipSettingsChanged",function() if SP.visible then SP:update() end end)
    U.replace_handler(SP,"module_changed","chimeraVipModuleChanged",function() if SP.visible then SP:update() end end)
    U.replace_handler(SP,"window_resize","sysWindowResizeEvent",function() if SP.visible then tempTimer(0.1,function() if SP.visible then SP:open() end end) end end)
end

return SP
