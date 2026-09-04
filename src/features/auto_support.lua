chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip
local C = chimera_vip
local U = C.util

local AS = C.auto_support or {}
C.auto_support = AS
chimera_overlay.auto_support = AS

AS.enabled = AS.enabled ~= false
AS.cooldown_ms = AS.cooldown_ms or 1500
AS.confirm_delay = AS.confirm_delay or 0.18
AS.cache = AS.cache or {team={}, my_id=nil, leader_id=nil, last_send=0, confirm_timer=nil}
AS.handlers = AS.handlers or {}
AS.ui = AS.ui or {}

local function colors()
    if C.pastel_ui and C.pastel_ui.colors then return C.pastel_ui.colors end
    return {background_soft="#181C26",separator="#2B303C",text="#D8DCE6",text_muted="#AEB6C5",mint="#A8DCC2",rose="#F0A8B8",lavender="#C7B9E8"}
end

local function same_id(a,b)
    if a==nil or b==nil then return false end
    return tostring(a)==tostring(b)
end

function AS:update_group()
    if not gmcp or not gmcp.Chimera or not gmcp.Chimera.Group then return end
    local group = gmcp.Chimera.Group.State or gmcp.Chimera.Group
    if not group or type(group.members) ~= "table" then return end

    self.cache.team = {}
    self.cache.my_id = nil
    self.cache.leader_id = group.leader

    for _,m in ipairs(group.members) do
        if tonumber(m.self)==1 then
            self.cache.my_id=m.id
        elseif m.id then
            self.cache.team[m.id]=true
        end
    end
end

function AS:relation_target(combat, actor_id)
    if not actor_id or type(combat.relations)~="table" then return nil end
    for _,rel in pairs(combat.relations) do
        if type(rel)=="table" and same_id(rel.attacker,actor_id) and rel.defender~=nil then
            return rel.defender
        end
    end
    return nil
end

function AS:my_target(combat)
    local target=self:relation_target(combat,self.cache.my_id)
    if target~=nil and tostring(target)~="" then return target end
    if combat.primary~=nil and tostring(combat.primary)~="" then return combat.primary end
    return nil
end

function AS:leader_target(combat)
    return self:relation_target(combat,self.cache.leader_id)
end

function AS:team_is_fighting(combat)
    if type(combat.relations)~="table" then return false end
    for _,rel in pairs(combat.relations) do
        if type(rel)=="table" and (self.cache.team[rel.attacker] or self.cache.team[rel.defender]) then
            return true
        end
    end
    return false
end

function AS:send_support_pair()
    local now = getEpochMs and getEpochMs() or (os.time()*1000)
    self.cache.last_send=now

    if self.cache.confirm_timer then pcall(killTimer,self.cache.confirm_timer) end
    self.cache.confirm_timer=nil

    send("wesprzyj",false)
    self.cache.confirm_timer=tempTimer(self.confirm_delay,function()
        AS.cache.confirm_timer=nil
        if AS.enabled then send("wesprzyj",false) end
    end)
end

function AS:combat()
    if not self.enabled then return end

    local now = getEpochMs and getEpochMs() or (os.time()*1000)
    if now-self.cache.last_send < self.cooldown_ms then return end
    if not gmcp or not gmcp.Chimera or not gmcp.Chimera.Combat then return end

    local combat=gmcp.Chimera.Combat.State or gmcp.Chimera.Combat
    if not combat then return end
    if next(self.cache.team)==nil or not self.cache.my_id or not self.cache.leader_id then self:update_group() end

    local leader_target=self:leader_target(combat)
    local own_target=self:my_target(combat)

    -- Jeśli możemy ustalić, kogo faktycznie bije lider, pilnujemy właśnie
    -- tego celu. Dotyczy to także sytuacji, gdy sami już walczymy, ale z kimś innym.
    if leader_target~=nil and tostring(leader_target)~="" then
        if not same_id(own_target,leader_target) then
            self:send_support_pair()
        end
        return
    end

    -- Fallback zachowuje wcześniejsze zachowanie, gdy GMCP nie daje jeszcze
    -- relacji lider -> cel: dołączamy, jeśli drużyna walczy, a my jeszcze nie.
    local self_active=tonumber(combat.self_active) or 0
    if self_active==1 or own_target~=nil then return end

    if type(combat.relations)=="table" then
        for _,rel in pairs(combat.relations) do
            if type(rel)=="table" and self.cache.my_id and (same_id(rel.attacker,self.cache.my_id) or same_id(rel.defender,self.cache.my_id)) then
                return
            end
        end
    end

    if self:team_is_fighting(combat) then self:send_support_pair() end
end

function AS:set_enabled(value,silent)
    self.enabled=value==true
    if not self.enabled and self.cache.confirm_timer then
        pcall(killTimer,self.cache.confirm_timer)
        self.cache.confirm_timer=nil
    end
    if self.enabled then self:update_group() end
    self:update_ui(); raiseEvent("chimeraAutoSupportChanged",self.enabled)
    if not silent then
        local color=self.enabled and "aquamarine" or "light_pink"
        cecho("\n<"..color..">[ChimeraVIP]<reset> Auto-wsparcie: <"..color..">"..(self.enabled and "ON" or "OFF").."<reset>\n")
    end
end
function AS:toggle() self:set_enabled(not self.enabled) end

function AS:destroy_ui()
    if not self.ui.button then return end
    pcall(function() self.ui.button:hide() end); pcall(function() self.ui.button:delete() end); self.ui.button=nil
end

function AS:update_ui()
    local b=self.ui.button; if not b then return end
    local P=colors(); local active=self.enabled and P.mint or P.rose; local state=self.enabled and "ON" or "OFF"
    local width=self.ui.button_width or ((C.quiet_footer and C.quiet_footer.layout and C.quiet_footer.layout.zone3_width) or 150)
    local text
    if width<95 then text="<center><font color='"..P.text_muted.."'>AS</font>&nbsp;<font color='"..active.."'>"..state.."</font></center>"
    else text="<center><font color='"..P.text_muted.."'>AUTO-WSPARCIE</font>&nbsp;&nbsp;<font color='"..active.."'>● "..state.."</font></center>" end
    b:echo(text)
    b:setStyleSheet("QLabel {background-color:"..P.background_soft..";color:"..P.text..";border:1px solid "..P.separator..";border-radius:4px;padding:0px 6px;font-size:8px;} QLabel:hover {border-color:"..P.lavender..";}")
    pcall(setLabelToolTip,b.name,"Auto-wsparcie drużyny<br>Podąża za celem lidera i wysyła wesprzyj dwukrotnie.<br>Kliknij, aby "..(self.enabled and "wyłączyć" or "włączyć")..".",8)
end

function AS:attach_ui()
    local HUD=C.quiet_footer
    if not HUD or not HUD.zone3 or not HUD.layout then return end
    self:destroy_ui()
    local zone_width=HUD.layout.zone3_width or 0
    if zone_width<40 then return end
    local width
    if zone_width>=80 then
        width=math.floor((math.min(zone_width,200)-3)/2)
    else
        width=math.max(40,zone_width-4)
    end
    local name="chimera_vip.auto_support."..tostring(HUD.generation or 0)..".button"
    self.ui.button=Geyser.Label:new({name=name,x=0,y=8,width=width,height=25,fontSize=8},HUD.zone3)
    self.ui.button_width=width
    self.ui.button:setClickCallback(function() AS:toggle() end)
    pcall(setLabelCursor,name,"PointingHand")
    self:update_ui()
end

U.replace_handler(AS,"combat_state","gmcp.Chimera.Combat.State",function() AS:combat() end)
U.replace_handler(AS,"combat","gmcp.Chimera.Combat",function() AS:combat() end)
U.replace_handler(AS,"group_state","gmcp.Chimera.Group.State",function() AS:update_group() end)
U.replace_handler(AS,"group","gmcp.Chimera.Group",function() AS:update_group() end)
U.replace_handler(AS,"footer_ready","chimeraFooterReady",function() tempTimer(0,function() AS:attach_ui() end) end)

AS:update_group()
if C.quiet_footer and C.quiet_footer.zone3 then tempTimer(0,function() AS:attach_ui() end) end
raiseEvent("chimeraAutoSupportReady",AS.enabled)

return AS
