-- Public data access for VIP modules; upstream UI remains optional to core.
chimera_vip = chimera_vip or {}
local C = chimera_vip
local R = C.runtime or {handlers={}}
C.runtime = R

function R:group()
    local value = gmcp and gmcp.Chimera and gmcp.Chimera.Group
    if type(value)~="table" then return nil end
    return type(value.State)=="table" and value.State or value
end
function R:combat()
    local value = gmcp and gmcp.Chimera and gmcp.Chimera.Combat
    if type(value)~="table" then return nil end
    return type(value.State)=="table" and value.State or value
end
function R:room()
    local source = gmcp and gmcp.Room and gmcp.Room.Info
    if type(source)=="table" then
        local exits = {}
        if type(source.exits)=="table" then
            for command in pairs(source.exits) do
                if type(command)=="string" then exits[#exits+1]=command end
            end
        end
        table.sort(exits)
        return {id=source.id, instance=source.instance, exits=exits, exits_targets=source.exits}
    end
    return gmcp and gmcp.room and gmcp.room.info or nil
end
function R:room_key()
    local room = self:room()
    if not room or room.id==nil then return nil end
    return tostring(room.id).."#"..tostring(room.instance or 0)
end
local actions = {
    hidden="scripts_ui_info_hidden_click", sneaky="scripts_ui_info_sneaky_click",
    attack="scripts_ui_info_attack_mode_click", collect="scripts_ui_info_collect_mode",
    lamp="scripts_ui_info_lamp_click", cover="scripts_ui_info_cover_ready_click",
}
function R:can_action(key)
    if key=="combat" then
        local state=scripts and scripts.character and scripts.character.combat_state
        return state and type(state.run_command)=="function" or false
    end
    return actions[key]~=nil and type(_G[actions[key]])=="function"
end
function R:action(key)
    if not self:can_action(key) then return false,"brak zaleznosci: "..tostring(key) end
    if key=="combat" then
        return pcall(function() scripts.character.combat_state:run_command() end)
    end
    return pcall(_G[actions[key]])
end
function R:capabilities()
    local ui = scripts and scripts.ui
    return {
        {"Oficjalny interfejs", type(ui)=="table" and type(ui.themes)=="table"},
        {"Stopka oficjalna", ui and ui.bottom~=nil or false},
        {"Mapper", type(amap)=="table"},
        {"Druzyna oficjalna", type(ateam)=="table"},
        {"Ekwipunek oficjalny", scripts and type(scripts.inv)=="table" or false},
        {"GMCP lokacji", self:room()~=nil},
        {"GMCP druzyny", self:group()~=nil},
        {"GMCP walki", self:combat()~=nil},
    }
end

return R
