chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip
local C = chimera_vip
local U = C.util

local HUD = C.quiet_footer or {}
C.quiet_footer = HUD
chimera_overlay.quiet_footer = HUD

HUD.handlers = HUD.handlers or {}
HUD.seen_vitals = HUD.seen_vitals or {}
HUD.exp_turns = HUD.exp_turns or 0
HUD.last_progress = HUD.last_progress
HUD.generation = HUD.generation or 0
HUD.resize_timer = nil
HUD.height = 76
HUD.main_font = 10
HUD.small_font = 7
HUD.exp_font = 7
HUD.main_segments = 10
HUD.main_segment_gap = 2
HUD.max_special_exits = 2

local function colors()
    if C.pastel_ui and C.pastel_ui.colors then return C.pastel_ui.colors end
    return {background="#12151D",background_soft="#181C26",separator="#2B303C",inactive="#303542",text="#D8DCE6",text_muted="#AEB6C5",rose="#F0A8B8",mint="#A8DCC2",blue="#AFCBF4",lavender="#C7B9E8",peach="#F2C4A0",yellow="#EFD8A6"}
end
HUD.colors = colors()

function HUD:calculate_layout()
    local window_width = 1366
    if type(getMainWindowSize) == "function" then
        local w = select(1, getMainWindowSize())
        if type(w) == "number" and w > 0 then window_width = w end
    end
    local footer_percent = tonumber(scripts and scripts.ui and scripts.ui.footer_width) or 100
    local W = math.floor(window_width * footer_percent / 100)
    local L = {footer_width=W, edge=8, zone_gap=12}
    L.zone1_width = U.clamp(math.floor(W * 0.075), 105, 120)
    if W < 1050 then L.zone3_min = 120 elseif W < 1300 then L.zone3_min = 150 else L.zone3_min = 180 end

    L.main_label_width=38; L.main_label_gap=6; L.main_value_gap=6; L.main_value_width=38; L.metric_gap=12
    L.needs_gap=12; L.needs_width=230
    L.need_label_width=40; L.need_label_gap=5; L.need_bar_width=52; L.need_value_gap=5; L.need_value_width=30
    L.status_x=142; L.status_label_width=24; L.status_gap=4; L.obc_bar_width=32; L.obc_value_gap=4; L.obc_value_width=28

    local metric_without_bar = L.main_label_width + L.main_label_gap + L.main_value_gap + L.main_value_width
    local fixed_zone2 = metric_without_bar*3 + L.metric_gap*2 + L.needs_gap + L.needs_width
    local max_zone2 = W - L.edge*2 - L.zone1_width - L.zone_gap*2 - L.zone3_min
    local candidate = math.floor((max_zone2-fixed_zone2)/3)
    if candidate < 52 then
        L.zone3_min = 0
        max_zone2 = W - L.edge*2 - L.zone1_width - L.zone_gap*2
        candidate = math.floor((max_zone2-fixed_zone2)/3)
    end
    L.main_bar_width = U.clamp(candidate, 52, 110)
    local seg = math.floor((L.main_bar_width - self.main_segment_gap*(self.main_segments-1))/self.main_segments)
    L.segment_width = math.max(3, seg)
    L.main_bar_width = L.segment_width*self.main_segments + self.main_segment_gap*(self.main_segments-1)
    L.metric_width = L.main_label_width + L.main_label_gap + L.main_bar_width + L.main_value_gap + L.main_value_width
    L.zone2_width = L.metric_width*3 + L.metric_gap*2 + L.needs_gap + L.needs_width
    L.zone1_x = L.edge
    L.zone2_x = L.zone1_x + L.zone1_width + L.zone_gap
    L.zone3_x = L.zone2_x + L.zone2_width + L.zone_gap
    L.zone3_width = math.max(0, W - L.zone3_x - L.edge)
    return L
end

function HUD:get_extended(source,key)
    local value = source[key]
    if type(value)=="number" then self.seen_vitals[key]=true; return U.clamp(value,0,100) end
    if self.seen_vitals[key] then return 0 end
    local seen = scripts and scripts.character and scripts.character.chimera_vitals and scripts.character.chimera_vitals.seen
    if seen and seen[key] then self.seen_vitals[key]=true; return 0 end
    return nil
end

function HUD:prepare_footer()
    if not scripts or not scripts.ui or not scripts.ui.bottom then return false end
    scripts.ui.footer_height=self.height; scripts.ui.footer_actions_height=0; scripts.ui.states_font_size=7
    pcall(function()
        scripts.ui.bottom:move(tostring(scripts.ui.footer_start).."%",-self.height)
        scripts.ui.bottom:resize(tostring(scripts.ui.footer_width).."%",self.height)
    end)
    local changed=true
    if type(getBorderBottom)=="function" then changed=getBorderBottom()~=self.height end
    if changed then setBorderBottom(self.height) end
    if scripts.ui.footer_vertical then pcall(function() scripts.ui.footer_vertical:hide() end) end
    return true
end

HUD.direction_defs={
 ["polnocny-zachod"]={"↖",0,9}, ["polnoc"]={"↑",17,9}, ["polnocny-wschod"]={"↗",34,9},
 ["zachod"]={"←",0,27}, ["wschod"]={"→",34,27},
 ["poludniowy-zachod"]={"↙",0,45}, ["poludnie"]={"↓",17,45}, ["poludniowy-wschod"]={"↘",34,45},
 ["gora"]={"⇡",48,18}, ["dol"]={"⇣",48,37},
}
function HUD:is_direction(cmd) return self.direction_defs[cmd]~=nil end
function HUD:send_exit(cmd) if cmd and cmd~="" then send(cmd,false) end end

function HUD:create_zone1(parent,prefix)
    local L=self.layout
    self.zone1=Geyser.Label:new({name=prefix..".zone1",x=L.zone1_x,y=0,width=L.zone1_width,height="100%"},parent)
    self.zone1:setStyleSheet(U.transparent_css())
    self.compass_buttons={}
    self.compass_center=Geyser.Label:new({name=prefix..".compass.center",x=17,y=27,width=17,height=15},self.zone1)
    self.compass_center:setStyleSheet(U.transparent_css()); self.compass_center:echo("<center><font color='"..self.colors.text_muted.."'>•</font></center>")
    for command,def in pairs(self.direction_defs) do
        local cmd=command
        local label=Geyser.Label:new({name=prefix..".compass."..cmd,x=def[2],y=def[3],width=17,height=15,fontSize=10},self.zone1)
        label:setStyleSheet(U.transparent_css())
        label:setClickCallback(function() if HUD.active_directions and HUD.active_directions[cmd] then HUD:send_exit(cmd) end end)
        self.compass_buttons[cmd]=label
    end
    self.special_labels={}
    local sx=56; local sw=math.max(45,L.zone1_width-sx)
    for i=1,self.max_special_exits do
        local label=Geyser.Label:new({name=prefix..".special."..i,x=sx,y=7+(i-1)*22,width=sw,height=19,fontSize=7},self.zone1)
        label:setStyleSheet(U.transparent_css()); self.special_labels[i]=label
    end
end

function HUD:update_special_exits(info)
    if not self.special_labels then return end
    for _,label in ipairs(self.special_labels) do label:echo(""); label:setClickCallback(function() end) end
    if type(info)~="table" or type(info.exits_targets)~="table" then return end
    local specials={}
    for command in pairs(info.exits_targets) do if type(command)=="string" and not self:is_direction(command) then specials[#specials+1]=command end end
    table.sort(specials)
    for i=1,math.min(#specials,self.max_special_exits) do
        local cmd=specials[i]; local label=self.special_labels[i]
        label:echo("<font color='"..self.colors.lavender.."'>◇</font> <font color='"..self.colors.text_muted.."'>"..U.escape_html(U.short_text(cmd,8)).."</font>")
        label:setClickCallback(function() HUD:send_exit(cmd) end)
        pcall(setLabelCursor,label.name,"PointingHand")
    end
end

function HUD:update_compass()
    if not self.compass_buttons then return end
    local info=gmcp and gmcp.room and gmcp.room.info
    if type(info)~="table" then return end
    self.active_directions={}
    if type(info.exits)=="table" then for _,cmd in pairs(info.exits) do if self:is_direction(cmd) then self.active_directions[cmd]=true end end end
    for cmd,label in pairs(self.compass_buttons) do
        local def=self.direction_defs[cmd]
        if self.active_directions[cmd] then
            label:echo("<center><font color='"..self.colors.lavender.."'>"..def[1].."</font></center>"); pcall(setLabelCursor,label.name,"PointingHand")
        else label:echo("") end
    end
    self:update_special_exits(info)
end

function HUD:create_segment_bar(parent,prefix,x,y)
    local L=self.layout
    local container=Geyser.Label:new({name=prefix,x=x,y=y,width=L.main_bar_width,height=12},parent); container:setStyleSheet(U.transparent_css())
    local segments={}
    for i=1,self.main_segments do
        segments[i]=Geyser.Label:new({name=prefix.."."..i,x=(i-1)*(L.segment_width+self.main_segment_gap),y=0,width=L.segment_width,height=11},container)
    end
    return segments
end

function HUD:update_segment_bar(segments,value,color)
    value=U.clamp(value,0,100); local filled=0
    if value then filled=math.floor(value/100*self.main_segments+0.5) end
    for i,segment in ipairs(segments) do
        local c=i<=filled and color or self.colors.inactive
        segment:setStyleSheet("QLabel {background-color:"..c..";border:0px;border-radius:1px;}")
    end
end

function HUD:create_metric(parent,prefix,key,x)
    local L=self.layout; local m={}
    m.label=Geyser.Label:new({name=prefix.."."..key..".label",x=x,y=12,width=L.main_label_width,height=21,fontSize=self.main_font},parent); m.label:setStyleSheet(U.transparent_css())
    local bx=x+L.main_label_width+L.main_label_gap
    m.segments=self:create_segment_bar(parent,prefix.."."..key..".bar",bx,17)
    m.value=Geyser.Label:new({name=prefix.."."..key..".value",x=bx+L.main_bar_width+L.main_value_gap,y=12,width=L.main_value_width,height=21,fontSize=self.main_font},parent); m.value:setStyleSheet(U.transparent_css())
    self.metrics[key]=m
end

function HUD:update_metric(m,title,value,color)
    m.label:echo("<font color='"..self.colors.text_muted.."'>"..title.."</font>")
    self:update_segment_bar(m.segments,value,color)
    if value then m.value:echo("<font color='"..self.colors.text.."'>"..math.floor(value+0.5).."%</font>") else m.value:echo("") end
end

function HUD:create_thin_bar(parent,prefix,x,y,color,width)
    local track=Geyser.Label:new({name=prefix..".track",x=x,y=y,width=width,height=3},parent)
    track:setStyleSheet("QLabel {background-color:"..self.colors.inactive..";border:0px;border-radius:1px;}")
    local fill=Geyser.Label:new({name=prefix..".fill",x=0,y=0,width="0%",height="100%"},track)
    fill:setStyleSheet("QLabel {background-color:"..color..";border:0px;border-radius:1px;}")
    return fill
end

function HUD:create_need(parent,prefix,key,y,color)
    local L=self.layout; local n={}
    n.label=Geyser.Label:new({name=prefix.."."..key..".label",x=0,y=y,width=L.need_label_width,height=18,fontSize=self.small_font},parent); n.label:setStyleSheet(U.transparent_css())
    local bx=L.need_label_width+L.need_label_gap
    n.fill=self:create_thin_bar(parent,prefix.."."..key,bx,y+9,color,L.need_bar_width)
    n.value=Geyser.Label:new({name=prefix.."."..key..".value",x=bx+L.need_bar_width+L.need_value_gap,y=y,width=L.need_value_width,height=18,fontSize=self.small_font},parent); n.value:setStyleSheet(U.transparent_css())
    self.needs[key]=n
end

function HUD:update_need(n,title,value)
    n.label:echo("<font color='"..self.colors.text_muted.."'>"..title.."</font>")
    value=U.clamp(value,0,100)
    if value and value>0 then n.fill:show(); n.fill:resize(tostring(value).."%","100%") else n.fill:hide() end
    n.value:echo("<font color='"..self.colors.text.."'>"..tostring(value and math.floor(value+0.5) or 0).."%</font>")
end

function HUD:get_obc_color(v) if v<=24 then return self.colors.mint elseif v<=49 then return self.colors.yellow elseif v<=74 then return self.colors.peach else return self.colors.rose end end
function HUD:create_obc(parent,prefix)
    local L=self.layout; self.obc={}
    self.obc.label=Geyser.Label:new({name=prefix..".obc.label",x=L.status_x,y=5,width=L.status_label_width,height=18,fontSize=self.small_font},parent); self.obc.label:setStyleSheet(U.transparent_css()); self.obc.label:echo("<font color='"..self.colors.text_muted.."'>OBC</font>")
    local bx=L.status_x+L.status_label_width+L.status_gap; self.obc.segments={}
    for i=1,5 do self.obc.segments[i]=Geyser.Label:new({name=prefix..".obc."..i,x=bx+(i-1)*7,y=11,width=5,height=6},parent) end
    self.obc.value=Geyser.Label:new({name=prefix..".obc.value",x=bx+L.obc_bar_width+L.obc_value_gap,y=5,width=L.obc_value_width,height=18,fontSize=self.small_font},parent); self.obc.value:setStyleSheet(U.transparent_css())
end
function HUD:update_obc(value)
    if value==nil or not self.obc then return end
    value=U.clamp(value,0,100); local c=self:get_obc_color(value); local filled=U.clamp(math.floor(value/20+0.5),0,5)
    for i,s in ipairs(self.obc.segments) do local sc=i<=filled and c or self.colors.inactive; s:setStyleSheet("QLabel {background-color:"..sc..";border:0px;border-radius:1px;}") end
    self.obc.value:echo("<font color='"..c.."'>"..math.floor(value+0.5).."%</font>")
end

function HUD:create_intox(parent,prefix)
    self.intox=Geyser.Label:new({name=prefix..".intox",x=self.layout.status_x,y=25,width=85,height=18,fontSize=self.small_font},parent); self.intox:setStyleSheet(U.transparent_css())
end
function HUD:update_intox(value)
    if not self.intox then return end
    if value and value>0 then self.intox:echo("<font color='"..self.colors.text_muted.."'>UPI</font>&nbsp;&nbsp;<font color='"..self.colors.lavender.."'>"..math.floor(value+0.5).."%</font>") else self.intox:echo("") end
end

function HUD:create_exp(parent,prefix)
    local L=self.layout
    self.exp_label=Geyser.Label:new({name=prefix..".exp.label",x=0,y=52,width=30,height=18,fontSize=self.exp_font},parent); self.exp_label:setStyleSheet(U.transparent_css()); self.exp_label:echo("<font color='"..self.colors.text_muted.."'>EXP</font>")
    local tx=38; local vw=58; local vg=8; local tw=L.zone2_width-tx-vg-vw
    self.exp_track=Geyser.Label:new({name=prefix..".exp.track",x=tx,y=60,width=tw,height=3},parent); self.exp_track:setStyleSheet("QLabel {background-color:"..self.colors.inactive..";border:0px;border-radius:1px;}")
    self.exp_fill=Geyser.Label:new({name=prefix..".exp.fill",x=0,y=0,width="0%",height="100%"},self.exp_track); self.exp_fill:setStyleSheet("QLabel {background-color:"..self.colors.lavender..";border:0px;border-radius:1px;}")
    self.exp_value=Geyser.Label:new({name=prefix..".exp.value",x=tx+tw+vg,y=52,width=vw,height=18,fontSize=self.exp_font},parent); self.exp_value:setStyleSheet(U.transparent_css())
end
function HUD:update_progress(progress)
    if progress==nil or not self.exp_fill then return end
    progress=U.clamp(progress,0,100)
    if self.last_progress and self.last_progress>=70 and progress<=30 and progress<self.last_progress then self.exp_turns=self.exp_turns+1 end
    self.last_progress=progress
    if progress>0 then self.exp_fill:show(); self.exp_fill:resize(tostring(progress).."%","100%") else self.exp_fill:hide() end
    local turns=self.exp_turns>0 and ("&nbsp;&nbsp;<font color='"..self.colors.lavender.."'>+"..self.exp_turns.."</font>") or ""
    self.exp_value:echo("<font color='"..self.colors.text.."'>"..math.floor(progress+0.5).."%</font>"..turns)
end

function HUD:create_zone2(parent,prefix)
    local L=self.layout
    self.zone2=Geyser.Label:new({name=prefix..".zone2",x=L.zone2_x,y=0,width=L.zone2_width,height="100%"},parent); self.zone2:setStyleSheet(U.transparent_css())
    self.metrics={}; self.needs={}
    local x1=0; local x2=x1+L.metric_width+L.metric_gap; local x3=x2+L.metric_width+L.metric_gap; local xn=x3+L.metric_width+L.needs_gap
    self:create_metric(self.zone2,prefix,"hp",x1); self:create_metric(self.zone2,prefix,"moves",x2); self:create_metric(self.zone2,prefix,"mana",x3)
    self.needs_panel=Geyser.Label:new({name=prefix..".needs",x=xn,y=0,width=L.needs_width,height=46},self.zone2); self.needs_panel:setStyleSheet(U.transparent_css())
    self:create_need(self.needs_panel,prefix,"hunger",5,self.colors.peach); self:create_need(self.needs_panel,prefix,"thirst",25,self.colors.lavender)
    self:create_obc(self.needs_panel,prefix); self:create_intox(self.needs_panel,prefix); self:create_exp(self.zone2,prefix)
end

function HUD:create_zone3(parent,prefix)
    local L=self.layout
    self.zone3=Geyser.Label:new({name=prefix..".zone3",x=L.zone3_x,y=0,width=L.zone3_width,height="100%"},parent); self.zone3:setStyleSheet(U.transparent_css())
end

function HUD:update_vitals()
    if not self.metrics then return end
    local s=gmcp and gmcp.Char and gmcp.Char.Vitals
    if type(s)~="table" then return end
    self:update_metric(self.metrics.hp,"KOND",U.clamp(s.hp,0,100),self.colors.rose)
    self:update_metric(self.metrics.moves,"SIŁY",U.clamp(s.moves,0,100),self.colors.mint)
    self:update_metric(self.metrics.mana,"MANA",U.clamp(s.mana,0,100),self.colors.blue)
    self:update_need(self.needs.hunger,"SYTOŚĆ",self:get_extended(s,"hunger"))
    self:update_need(self.needs.thirst,"WODA",self:get_extended(s,"thirst"))
    self:update_obc(self:get_extended(s,"encumbrance")); self:update_intox(self:get_extended(s,"intox")); self:update_progress(self:get_extended(s,"progress"))
end

function HUD:destroy()
    if not self.root then return end
    pcall(function() self.root:hide() end); pcall(function() self.root:delete() end); self.root=nil
end
function HUD:build()
    if not C.theme_ready or not self:prepare_footer() then return end
    self:destroy(); self.colors=colors(); self.layout=self:calculate_layout(); self.generation=self.generation+1
    local prefix="chimera_vip.quiet_footer."..self.generation
    self.root=Geyser.Label:new({name=prefix..".root",x=0,y=0,width="100%",height="100%"},scripts.ui.bottom); self.root:setStyleSheet(U.transparent_css())
    self:create_zone1(self.root,prefix); self:create_zone2(self.root,prefix); self:create_zone3(self.root,prefix); self.root:show(); self:update_compass(); self:update_vitals()
    raiseEvent("chimeraFooterReady",self.generation,self.layout.zone3_width)
end
function HUD:schedule_rebuild()
    if self.resize_timer then pcall(killTimer,self.resize_timer) end
    self.resize_timer=tempTimer(0.15,function() HUD.resize_timer=nil; if C.theme_ready then HUD:build() end end)
end

U.replace_handler(HUD,"theme_ready","chimeraThemeReady",function() HUD:schedule_rebuild() end)
U.replace_handler(HUD,"window_resize","sysWindowResizeEvent",function() HUD:schedule_rebuild() end)
U.replace_handler(HUD,"room_info","gmcp.room.info",function() HUD:update_compass() end)
U.replace_handler(HUD,"char_vitals","gmcp.Char.Vitals",function() HUD:update_vitals() end)
if C.theme_ready then HUD:schedule_rebuild() end

return HUD
