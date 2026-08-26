chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip
local C = chimera_vip
local U = C.util

local CTRL = C.footer_controls or {}
C.footer_controls = CTRL
chimera_overlay.footer_controls = CTRL
CTRL.handlers = CTRL.handlers or {}
CTRL.buttons = CTRL.buttons or {}
CTRL.refresh_timer = nil

local function P()
    if C.pastel_ui and C.pastel_ui.colors then return C.pastel_ui.colors end
    return {background_soft="#181C26",separator="#2B303C",text="#D8DCE6",text_muted="#AEB6C5",mint="#A8DCC2",blue="#AFCBF4",lavender="#C7B9E8",peach="#F2C4A0",yellow="#EFD8A6",rose="#F0A8B8"}
end

local function clean(v)
    local t=tostring(v or ""):gsub("<[^>]->",""):gsub("&nbsp;"," "):gsub("^%s+",""):gsub("%s+$","")
    return t
end

function CTRL:warn(text) cecho("\n<orange>[ChimeraVIP]<reset> "..tostring(text).."\n") end
function CTRL:call_global(name)
    local fn=_G[name]
    if type(fn)~="function" then self:warn("Funkcja "..name.." nie jest dostepna."); return false end
    local ok,err=pcall(fn); if not ok then self:warn("Blad kontrolki: "..tostring(err)); return false end
    return true
end

function CTRL:click(key)
    if key=="hidden" then self:call_global("scripts_ui_info_hidden_click")
    elseif key=="sneaky" then self:call_global("scripts_ui_info_sneaky_click")
    elseif key=="attack" then self:call_global("scripts_ui_info_attack_mode_click")
    elseif key=="collect" then self:call_global("scripts_ui_info_collect_mode")
    elseif key=="lamp" then self:call_global("scripts_ui_info_lamp_click")
    elseif key=="cover" then self:call_global("scripts_ui_info_cover_ready_click")
    elseif key=="combat" then
        local combat=scripts and scripts.character and scripts.character.combat_state
        if combat and type(combat.run_command)=="function" then
            local ok,err=pcall(function() combat:run_command() end); if not ok then self:warn("Blad kontrolki walki: "..tostring(err)) end
        else self:warn("Funkcja sterowania walka nie jest dostepna.") end
    end
    tempTimer(0.05,function() CTRL:update_all() end)
end

function CTRL:get_hidden_state()
    local v=scripts and scripts.ui and scripts.ui.states_window_nav_states and scripts.ui.states_window_nav_states.hidden_state
    if v==nil or v==false or v=="" then return {color=P().text_muted,text="nieukryta"} end
    if v=="ok" then return {color=P().mint,text="ukryta: ok"} end
    local n=tonumber(v); if n then return {color=n<5 and P().rose or (n<10 and P().yellow or P().mint),text="ukrycie: "..n} end
    return {color=P().lavender,text=tostring(v)}
end
function CTRL:get_sneaky_state()
    local mode=amap and tonumber(amap.walk_mode) or 1
    if mode==1 then return {color=P().text_muted,text="wylaczone"} end
    if mode==2 then return {color=P().lavender,text="ja"} end
    if mode==3 then return {color=P().mint,text="ja + druzyna"} end
    return {color=P().text_muted,text="tryb "..mode}
end
function CTRL:get_attack_state()
    local mode=ateam and tonumber(ateam.attack_mode); local text=""
    if mode and ateam and type(ateam.footer_info_attack_mode_to_text)=="table" then text=clean(ateam.footer_info_attack_mode_to_text[mode]) end
    if text=="" then text=mode and ("tryb "..mode) or "brak danych" end
    return {color=P().blue,text=text}
end
function CTRL:get_collect_state()
    local col=scripts and scripts.inv and scripts.inv.collect
    if not col then return {color=P().text_muted,text="brak danych"} end
    local mode=tonumber(col.current_mode); local text=""
    if mode and type(col.footer_info_collect_to_text)=="table" then text=clean(col.footer_info_collect_to_text[mode]) end
    if text=="" then text=mode and ("tryb "..mode) or "brak danych" end
    return {color=P().peach,text=text}
end
function CTRL:get_lamp_state()
    local working=scripts and scripts.inv and scripts.inv.lamp and scripts.inv.lamp.working
    return working and {color=P().yellow,text="zapalona"} or {color=P().text_muted,text="zgaszona"}
end
function CTRL:get_combat_state()
    local combat=scripts and scripts.character and scripts.character.combat_state
    if not combat then return {color=P().text_muted,text="brak danych"} end
    if combat.state then return {color=P().rose,text="walka"} end
    local cd=tonumber(combat.time_after_combat) or 0
    return cd>0 and {color=P().yellow,text="odpoczynek: "..cd.." s"} or {color=P().text_muted,text="poza walka"}
end
function CTRL:get_cover_state()
    local value=scripts and scripts.ui and scripts.ui.states_window_nav_states and scripts.ui.states_window_nav_states.guard_state
    local ready=scripts and scripts.ui and scripts.ui.footer_info_cover_ready_enable_click
    if ready then return {color=P().mint,text="gotowa"} end
    local n=tonumber(value); if n and n>0 then return {color=P().rose,text="odnowienie: "..n} end
    return {color=P().text_muted,text="brak gotowosci"}
end

CTRL.definitions={
 {key="hidden",label="UKR",title="Ukrywanie",description="Oficjalna funkcja ukrywania Chimery.",state=function() return CTRL:get_hidden_state() end},
 {key="sneaky",label="PRZ",title="Przemykanie",description="Przelacza oficjalny tryb przemykania.",state=function() return CTRL:get_sneaky_state() end},
 {key="attack",label="ATK",title="Tryb ataku",description="Przelacza oficjalny tryb ataku.",state=function() return CTRL:get_attack_state() end},
 {key="collect",label="ZBI",title="Zbieranie",description="Przelacza oficjalny tryb zbierania.",state=function() return CTRL:get_collect_state() end},
 {key="lamp",label="LAM",title="Lampa",description="Steruje oficjalna funkcja lampy.",state=function() return CTRL:get_lamp_state() end},
 {key="combat",label="WAL",title="Walka",description="Wykonuje akcje oficjalnego modulu stanu walki.",state=function() return CTRL:get_combat_state() end},
 {key="cover",label="ZAS",title="Zaslona",description="Wykonuje akcje zaslony, gdy jest dostepna.",state=function() return CTRL:get_cover_state() end},
}

function CTRL:destroy_ui()
    for _,b in pairs(self.buttons) do pcall(function() b:hide() end); pcall(function() b:delete() end) end
    self.buttons={}
end
function CTRL:button_css(color)
    local c=P(); return "QLabel {background-color:"..c.background_soft..";color:"..color..";border:1px solid "..c.separator..";border-radius:3px;padding:0px;font-size:7px;} QLabel:hover {border-color:"..c.lavender..";color:"..c.lavender..";}"
end
function CTRL:update_button(def)
    local b=self.buttons[def.key]; if not b then return end
    local state=def.state() or {color=P().text_muted,text="brak danych"}
    b:setStyleSheet(self:button_css(state.color)); b:echo("<center>"..def.label.."</center>")
    pcall(setLabelToolTip,b.name,"<b>"..def.title.."</b><br>"..def.description.."<br><br>Stan: <b>"..tostring(state.text).."</b>",8)
end
function CTRL:update_all() for _,d in ipairs(self.definitions) do self:update_button(d) end end

function CTRL:attach_ui()
    local HUD=C.quiet_footer
    if not HUD or not HUD.zone3 or not HUD.layout then return end
    self:destroy_ui()
    local width=HUD.layout.zone3_width or 0
    if width<92 then return end
    local padding,gap,cols=2,3,4
    local bw=math.floor((width-padding*2-gap*(cols-1))/cols); bw=math.max(18,math.min(34,bw))
    local ys={40,57}; local bh=14
    for i,def in ipairs(self.definitions) do
        local row=math.floor((i-1)/cols)+1; local col=(i-1)%cols; local x=padding+col*(bw+gap); local y=ys[row]; local key=def.key
        local name="chimera_vip.footer_controls."..tostring(HUD.generation or 0).."."..key
        local b=Geyser.Label:new({name=name,x=x,y=y,width=bw,height=bh,fontSize=7},HUD.zone3)
        b:setClickCallback(function() CTRL:click(key) end); pcall(setLabelCursor,name,"PointingHand"); self.buttons[key]=b
    end
    self:update_all()
end

function CTRL:start_refresh()
    if self.refresh_timer then pcall(killTimer,self.refresh_timer) end
    self.refresh_timer=tempTimer(0.75,function() CTRL:update_all() end,true)
end

U.replace_handler(CTRL,"footer_ready","chimeraFooterReady",function() tempTimer(0,function() CTRL:attach_ui() end) end)
if C.quiet_footer and C.quiet_footer.zone3 then tempTimer(0,function() CTRL:attach_ui() end) end
CTRL:start_refresh()

return CTRL
