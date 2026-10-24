-- Official Chimera 5 API (bridge) and native GMCP fallback for startup.
chimera_vip = chimera_vip or {}
local C = chimera_vip
local R = C.runtime or {handlers={}}
C.runtime = R

function R:bridge()
    local b = rawget(_G, "chimera_vip_bridge")
    return type(b)=="table" and b.api==5 and b or nil
end
function R:is_chimera5()
    return self:bridge() ~= nil or (package and type(package.loaded)=="table"
        and package.loaded["chimera.team"] ~= nil) or false
end
local function bridge_call(name, ...)
    local b=R:bridge()
    if not b or type(b[name])~="function" then return nil end
    local ok,value=pcall(b[name], ...)
    return ok and value or nil
end
function R:team_view() return bridge_call("team_view") end
function R:team_resolve(mark) return bridge_call("team_resolve",mark) end
function R:vitals()
    return bridge_call("gmcp_vitals") or (gmcp and gmcp.Char and gmcp.Char.Vitals)
end
function R:entities()
    return bridge_call("gmcp_entities") or (gmcp and gmcp.Chimera and gmcp.Chimera.Room and gmcp.Chimera.Room.Entities)
end
function R:group()
    local value=bridge_call("gmcp_group")
    if type(value)=="table" then return value end
    value=gmcp and gmcp.Chimera and gmcp.Chimera.Group
    return type(value)=="table" and (type(value.State)=="table" and value.State or value) or nil
end
function R:combat()
    local value=bridge_call("gmcp_combat")
    if type(value)=="table" then return value end
    value=gmcp and gmcp.Chimera and gmcp.Chimera.Combat
    return type(value)=="table" and (type(value.State)=="table" and value.State or value) or nil
end
function R:room()
    local source=bridge_call("gmcp_room") or (gmcp and gmcp.Room and gmcp.Room.Info)
    if type(source)=="table" then
        local exits,targets={},type(source.exits)=="table" and source.exits or {}
        for direction in pairs(targets) do
            if type(direction)=="string" then exits[#exits+1]=direction end
        end
        table.sort(exits)
        return {id=source.id,name=source.name,terrain=source.terrain,
            indoors=source.indoors,instance=source.instance,
            exits=exits,exits_targets=targets}
    end
    return gmcp and gmcp.room and gmcp.room.info or nil
end
function R:room_key()
    local room=self:room()
    return room and room.id and (tostring(room.id).."#"..tostring(room.instance or 0)) or nil
end
local actions={
    hidden="scripts_ui_info_hidden_click",sneaky="scripts_ui_info_sneaky_click",
    attack="scripts_ui_info_attack_mode_click",collect="scripts_ui_info_collect_mode",
    lamp="scripts_ui_info_lamp_click",cover="scripts_ui_info_cover_ready_click",
}
function R:can_action(key)
    if self:is_chimera5() then return false end
    if key=="combat" then
        local s=scripts and scripts.character and scripts.character.combat_state
        return s and type(s.run_command)=="function" or false
    end
    return actions[key]~=nil and type(_G[actions[key]])=="function"
end
function R:action(key)
    if not self:can_action(key) then return false,"brak zaleznosci: "..tostring(key) end
    if key=="combat" then return pcall(function() scripts.character.combat_state:run_command() end) end
    return pcall(_G[actions[key]])
end
function R:capabilities()
    local ui=scripts and scripts.ui
    return {
        {"Chimera 5: most API",self:bridge()~=nil},
        {"Chimera 5: silnik",self:is_chimera5()},
        {"Interfejs starszej Chimery",type(ui)=="table" and type(ui.themes)=="table"},
        {"GMCP lokacji",self:room()~=nil},
        {"GMCP druzyny",self:group()~=nil},
        {"GMCP walki",self:combat()~=nil},
        {"team.view()",type(self:team_view())=="table"},
    }
end
return R
