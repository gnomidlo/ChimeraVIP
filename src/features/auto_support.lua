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
    local group = C.runtime:group()
    self.cache.team = {}
    self.cache.my_id = nil
    self.cache.leader_id = nil
    if not group or type(group.members) ~= "table" then self:cancel_confirmation(); return end
    self.cache.leader_id = group.leader

    for _,m in ipairs(group.members) do
        if m.self==true or tonumber(m.self)==1 then
            self.cache.my_id=m.id
        elseif m.id then
            self.cache.team[tostring(m.id)]=true
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
        if type(rel)=="table" and (self.cache.team[tostring(rel.attacker)] or self.cache.team[tostring(rel.defender)]) then
            return true
        end
    end
    return false
end

function AS:cancel_confirmation()
    self.generation=(self.generation or 0)+1
    if self.cache.confirm_timer then pcall(killTimer,self.cache.confirm_timer) end
    self.cache.confirm_timer=nil
end

function AS:needs_support(combat)
    if type(combat)~="table" or not self.cache.my_id or not self.cache.leader_id then return false end
    local leader_target=self:leader_target(combat)
    local own_target=self:my_target(combat)
    if leader_target~=nil and tostring(leader_target)~="" then
        return not same_id(own_target,leader_target)
    end
    if tonumber(combat.self_active)==1 or own_target~=nil then return false end
    for _,rel in pairs(combat.relations or {}) do
        if type(rel)=="table" and (same_id(rel.attacker,self.cache.my_id) or same_id(rel.defender,self.cache.my_id)) then return false end
    end
    return self:team_is_fighting(combat)
end

function AS:send_support_pair()
    self:cancel_confirmation()
    self.cache.last_send=getEpochMs and getEpochMs() or (os.time()*1000)
    local generation=self.generation
    local leader=self.cache.leader_id
    local target=self:leader_target(C.runtime:combat() or {})
    local room=C.runtime:room_key()
    self.confirm_room=room
    -- Arm before send: a synchronous response can cancel this attempt.
    self.cache.confirm_timer=tempTimer(self.confirm_delay,function()
        AS.cache.confirm_timer=nil
        if generation~=AS.generation or not AS.enabled then return end
        AS:update_group()
        local combat=C.runtime:combat()
        local current_target=AS:leader_target(combat or {})
        if same_id(leader,AS.cache.leader_id) and room==C.runtime:room_key()
            and tostring(target)==tostring(current_target) and AS:needs_support(combat) then
            send("wesprzyj",false)
        end
    end)
    send("wesprzyj",false)
end

function AS:combat()
    if not self.enabled then return end

    local now = getEpochMs and getEpochMs() or (os.time()*1000)
    if now-self.cache.last_send < self.cooldown_ms then return end
    self:update_group()
    if self:needs_support(C.runtime:combat()) then self:send_support_pair() end
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
    local width=(C.quiet_footer and C.quiet_footer.layout and C.quiet_footer.layout.zone3_width) or 150
    local text
    if width<95 then text="<center><font color='"..P.text_muted.."'>AS</font>&nbsp;<font color='"..active.."'>"..state.."</font></center>"
    else text="<center><font color='"..P.text_muted.."'>AUTO-WSPARCIE</font>&nbsp;&nbsp;<font color='"..active.."'>● "..state.."</font></center>" end
    b:echo(text)
    b:setStyleSheet("QLabel {background-color:"..P.background_soft..";color:"..P.text..";border:1px solid "..P.separator..";border-radius:4px;padding:0px 6px;font-size:8px;} QLabel:hover {border-color:"..P.lavender..";}")
    pcall(setLabelToolTip,b.name,"Auto-wsparcie drużyny<br>Podąża za celem lidera; ponawia wsparcie, gdy nadal jest potrzebne.<br>Kliknij, aby "..(self.enabled and "wyłączyć" or "włączyć")..".",8)
end

function AS:attach_ui()
    local HUD=C.quiet_footer
    if not HUD or not HUD.zone3 or not HUD.layout then return end
    self:destroy_ui()
    local zone_width=HUD.layout.zone3_width or 0
    if zone_width<40 then return end
    local width=math.max(40,math.min(165,zone_width-4))
    local name="chimera_vip.auto_support."..tostring(HUD.generation or 0)..".button"
    self.ui.button=Geyser.Label:new({name=name,x=0,y=8,width=width,height=25,fontSize=8},HUD.zone3)
    self.ui.button:setClickCallback(function() AS:toggle() end)
    pcall(setLabelCursor,name,"PointingHand")
    self:update_ui()
end

U.replace_handler(AS,"combat_state","gmcp.Chimera.Combat.State",function() AS:combat() end)
U.replace_handler(AS,"combat","gmcp.Chimera.Combat",function() AS:combat() end)
U.replace_handler(AS,"group_state","gmcp.Chimera.Group.State",function() AS:update_group() end)
U.replace_handler(AS,"group","gmcp.Chimera.Group",function() AS:update_group() end)
U.replace_handler(AS,"footer_ready","chimeraFooterReady",function() tempTimer(0,function() AS:attach_ui() end) end)

AS:cancel_confirmation()
U.replace_handler(AS,"disconnect","sysDisconnectionEvent",function()
    AS:cancel_confirmation(); AS.cache.team={}; AS.cache.my_id=nil; AS.cache.leader_id=nil
end)
U.replace_handler(AS,"room","gmcp.Room.Info",function()
    if AS.cache.confirm_timer and AS.confirm_room~=C.runtime:room_key() then AS:cancel_confirmation() end
end)
AS:update_group()
if C.quiet_footer and C.quiet_footer.zone3 then tempTimer(0,function() AS:attach_ui() end) end
raiseEvent("chimeraAutoSupportReady",AS.enabled)

return AS
