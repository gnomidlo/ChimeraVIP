chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util

C.settings_panel = C.settings_panel or {}
local SP = C.settings_panel

if SP.root then pcall(function() SP.root:hide() end); pcall(function() SP.root:delete() end) end
SP.handlers = SP.handlers or {}
SP.root=nil; SP.controls={}; SP.visible=false
SP.section_labels={interface="INTERFEJS",combat="WALKA",defense="OBRONA",xp="DOSWIADCZENIE",characters="POSTACIE",automation="AUTOMATYZACJA",system="SYSTEM"}

local function P() return U.palette() end

function SP:destroy()
    if self.root then pcall(function() self.root:hide() end); pcall(function() self.root:delete() end) end
    self.root=nil; self.controls={}; self.visible=false
end

function SP:panel_position(width,height)
    local ww,wh=1366,768
    if type(getMainWindowSize)=="function" then local w,h=getMainWindowSize(); if type(w)=="number" and w>0 then ww=w end; if type(h)=="number" and h>0 then wh=h end end
    return math.max(10,math.floor((ww-width)/2)),math.max(10,math.floor((wh-height)/2))
end

function SP:button_css(active, accent)
    local c=P(); accent=accent or c.mint
    return "QLabel {background-color:"..c.background_soft..";color:"..(active and accent or c.text_muted)..";border:1px solid "..(active and accent or c.separator)..";border-radius:4px;padding:0px;font-size:9px;} QLabel:hover {border-color:"..c.lavender..";color:"..c.lavender..";}"
end

function SP:color_css(value)
    local c=P(); local color=tostring(value or c.text)
    return "QLabel {background-color:"..color..";color:"..c.background..";border:1px solid "..c.separator..";border-radius:4px;padding:0px;font-size:9px;} QLabel:hover {border-color:"..c.lavender..";}"
end

function SP:set_value(id,value)
    if not C.settings then return end
    if C.settings:set_setting_value(id,value) then self:update() end
end

function SP:toggle(id)
    local current=C.settings:get_setting_value(id)==true
    self:set_value(id,not current)
end

function SP:cycle_color(id)
    local def=C.settings.setting_defs[id]; if not def then return end
    local options=def.options or {}
    if #options==0 then return end
    local current=tostring(C.settings:get_setting_value(id) or ""):upper()
    local index=0
    for i,value in ipairs(options) do if tostring(value):upper()==current then index=i; break end end
    self:set_value(id,options[(index % #options)+1])
end

function SP:update()
    if not self.visible or not C.settings then return end
    for id,control in pairs(self.controls or {}) do
        local def=C.settings.setting_defs[id]
        if def then
            local value=C.settings:get_setting_value(id)
            if def.type=="toggle" and control.button then
                local enabled=value==true
                control.button:setStyleSheet(self:button_css(enabled,enabled and P().mint or P().rose))
                control.button:echo("<center>"..(enabled and "● ON" or "○ OFF").."</center>")
            elseif def.type=="choice" then
                for option_value,button in pairs(control.buttons or {}) do
                    local selected=tostring(option_value)==tostring(value)
                    button:setStyleSheet(self:button_css(selected,P().mint))
                end
            elseif def.type=="color" and control.button then
                control.button:setStyleSheet(self:color_css(value))
                control.button:echo("<center>"..tostring(value or "-").."</center>")
            end
        end
    end
end

function SP:create_toggle(def,prefix,y)
    local c=P(); local control={}
    local label=Geyser.Label:new({name=prefix..".label."..def.id,x=20,y=y,width=285,height=25,fontSize=8},self.root); label:setStyleSheet(U.transparent_css()); label:echo("<font color='"..c.text.."'>"..U.escape_html(def.title).."</font>")
    local button=Geyser.Label:new({name=prefix..".control."..def.id,x=430,y=y-2,width=128,height=28,fontSize=9},self.root); button:setClickCallback(function() SP:toggle(def.id) end); pcall(setLabelCursor,button.name,"PointingHand"); pcall(setLabelToolTip,button.name,def.description,8)
    control.button=button; self.controls[def.id]=control
end

function SP:create_choice(def,prefix,y)
    local c=P(); local control={buttons={}}
    local label=Geyser.Label:new({name=prefix..".label."..def.id,x=20,y=y,width=230,height=25,fontSize=8},self.root); label:setStyleSheet(U.transparent_css()); label:echo("<font color='"..c.text.."'>"..U.escape_html(def.title).."</font>")
    local options=def.options or {}; local count=math.max(1,#options); local gap=4; local total_width=306; local bw=math.floor((total_width-gap*(count-1))/count); bw=math.max(30,math.min(52,bw)); local start_x=558-(bw*count+gap*(count-1))
    for i,option in ipairs(options) do
        local value=type(option)=="table" and option.value or option; local display=type(option)=="table" and (option.label or option.value) or option
        local button=Geyser.Label:new({name=prefix..".control."..def.id.."."..tostring(i),x=start_x+(i-1)*(bw+gap),y=y-2,width=bw,height=28,fontSize=8},self.root)
        button:echo("<center>"..U.escape_html(tostring(display)).."</center>"); button:setClickCallback(function() SP:set_value(def.id,value) end); pcall(setLabelCursor,button.name,"PointingHand"); pcall(setLabelToolTip,button.name,def.description,8); control.buttons[value]=button
    end
    self.controls[def.id]=control
end

function SP:create_color(def,prefix,y)
    local c=P(); local control={}
    local label=Geyser.Label:new({name=prefix..".label."..def.id,x=20,y=y,width=285,height=25,fontSize=8},self.root); label:setStyleSheet(U.transparent_css()); label:echo("<font color='"..c.text.."'>"..U.escape_html(def.title).."</font>")
    local button=Geyser.Label:new({name=prefix..".control."..def.id,x=430,y=y-2,width=128,height=28,fontSize=8},self.root); button:setClickCallback(function() SP:cycle_color(def.id) end); pcall(setLabelCursor,button.name,"PointingHand"); pcall(setLabelToolTip,button.name,(def.description~="" and def.description.."\n" or "").."Kliknij, aby zmienic kolor.",8); control.button=button; self.controls[def.id]=control
end

function SP:open()
    self:destroy(); if not C.settings then return end
    local settings=C.settings:list_settings(); local sections={}; local last_section=nil; local rows=0
    for _,def in ipairs(settings) do if def.section~=last_section then rows=rows+1; last_section=def.section end; rows=rows+1 end
    local pw=580; local ph=58+rows*34+12; ph=math.max(150,math.min(680,ph)); local x,y=self:panel_position(pw,ph); local c=P(); local prefix="chimera_vip.settings_panel."..tostring(os.time()).."."..tostring(math.random(1000,9999))
    self.root=Geyser.Label:new({name=prefix..".root",x=x,y=y,width=pw,height=ph}); self.root:setStyleSheet("QLabel {background-color:"..c.background..";border:1px solid "..c.separator..";border-radius:7px;padding:0px;}")
    local title=Geyser.Label:new({name=prefix..".title",x=16,y=9,width=500,height=22,fontSize=10},self.root); title:setStyleSheet(U.transparent_css()); title:echo("<font color='"..c.lavender.."'>CHIMERAVIP — USTAWIENIA</font>")
    local close=Geyser.Label:new({name=prefix..".close",x=pw-38,y=6,width=25,height=22,fontSize=11},self.root); close:setStyleSheet("QLabel {background-color:transparent;color:"..c.text_muted..";border:0px;padding:0px;} QLabel:hover {color:"..c.rose..";}"); close:echo("<center>×</center>"); close:setClickCallback(function() SP:destroy() end); pcall(setLabelCursor,close.name,"PointingHand")

    local current_section=nil; local row_y=42
    for _,def in ipairs(settings) do
        if def.section~=current_section then
            current_section=def.section
            local section=Geyser.Label:new({name=prefix..".section."..current_section,x=16,y=row_y,width=540,height=20,fontSize=8},self.root); section:setStyleSheet(U.transparent_css()); section:echo("<font color='"..c.text_muted.."'>"..(self.section_labels[current_section] or current_section:upper()).."</font>")
            row_y=row_y+28
        end
        if def.type=="toggle" then self:create_toggle(def,prefix,row_y)
        elseif def.type=="choice" then self:create_choice(def,prefix,row_y)
        elseif def.type=="color" then self:create_color(def,prefix,row_y) end
        row_y=row_y+34
    end

    self.visible=true; self.root:show(); self:update()
end

U.replace_handler(SP,"settings_changed","chimeraVipSettingsChanged",function() if SP.visible then SP:update() end end)
U.replace_handler(SP,"module_changed","chimeraVipModuleChanged",function() if SP.visible then SP:update() end end)
U.replace_handler(SP,"window_resize","sysWindowResizeEvent",function() if SP.visible then tempTimer(0.1,function() if SP.visible then SP:open() end end) end end)

return SP
