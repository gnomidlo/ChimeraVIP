-- ChimeraVIP / tactical aliases
-- Short formation/combat commands resolved through the tactical GMCP window marks.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
local T = C.tactical_states

if not T then
    error("tactical_states musi byc zaladowany przed tactical_aliases")
end

C.tactical_aliases = C.tactical_aliases or {}
chimera_overlay.tactical_aliases = C.tactical_aliases
local A = C.tactical_aliases

A.alias_ids = A.alias_ids or {}

local function P()
    return U and U.palette and U.palette() or {
        text="#D8DCE6", text_muted="#AEB6C5", mint="#A8DCC2",
        rose="#F0A8B8", lavender="#C7B9E8", yellow="#EFD8A6",
    }
end

local function note(text, color)
    local palette = P()
    hecho("\n" .. (color or palette.text_muted) .. "[TAKTYKA] " .. palette.text .. tostring(text or "") .. "\n")
end

local function refresh_snapshot()
    local ok, snapshot = pcall(function() return T:build_snapshot() end)
    if not ok or type(snapshot) ~= "table" then
        note("Brak aktualnych danych GMCP.", P().rose)
        return nil
    end
    return snapshot
end

local function group_target(mark, allow_self)
    mark = tostring(mark or ""):upper()
    if mark == "" then return nil end
    local targets=rawget(_G,"chimera_vip_ui_targets")
    if targets and targets.members and targets.members[mark] then
        return tostring(targets.members[mark])
    end
    if not refresh_snapshot() then return nil end
    if mark == "@" and not allow_self then
        note("Znacznik @ oznacza ciebie i nie jest dozwolony w tej komendzie.", P().yellow)
        return nil
    end
    local id = T:get_group_target(mark)
    if not id then
        note("Nie ma czlonka druzyny oznaczonego [" .. mark .. "].", P().rose)
        return nil
    end
    return tostring(id)
end

local function enemy_target(mark)
    mark = tostring(mark or "")
    if mark == "" then return nil end
    local targets=rawget(_G,"chimera_vip_ui_targets")
    if targets and targets.enemies and targets.enemies[mark] then
        return tostring(targets.enemies[mark])
    end
    if not refresh_snapshot() then return nil end
    local id = T:get_enemy_target(mark)
    if not id then
        note("Nie ma postaci spoza druzyny oznaczonej [" .. mark .. "].", P().rose)
        return nil
    end
    return tostring(id)
end

function A:attack(mark)
    local id = enemy_target(mark)
    if not id then return false end
    send("zabij " .. id, false)
    return true
end

function A:cover(mark)
    local id = group_target(mark, false)
    if not id then return false end
    send("zaslon " .. id, false)
    return true
end

function A:retreat(mark)
    local id = group_target(mark, false)
    if not id then return false end
    send("wycofaj sie za " .. id, false)
    return true
end

function A:order_cover(actor_mark, target_mark)
    local actor_id = group_target(actor_mark, false)
    if not actor_id then return false end
    local target_id = group_target(target_mark, true)
    if not target_id then return false end
    if actor_id == target_id then
        note("Nie mozna rozkazac postaci zaslonic samej siebie.", P().yellow)
        return false
    end
    send("parozkaz " .. actor_id .. " zaslon " .. target_id, false)
    return true
end

-- Names from the official Chimera team alias folder. Only /z and /za
-- are replaced; the rest of the official package stays active.
A.official_alias_names = {
    "zabij_id", "zabij_noarg", "zaslon_team", "zaslon_team_def", "zaslon_team_wzm",
}

function A:disable_official_aliases()
    if type(disableAlias) ~= "function" then return end
    for _, name in ipairs(self.official_alias_names) do
        disableAlias(name)
    end
end

function A:command(command, arguments)
    local args = {}
    for word in tostring(arguments or ""):gmatch("%S+") do args[#args + 1] = word end
    if command == "z" and #args == 1 and args[1]:match("^%d+$") then
        return self:attack(args[1])
    elseif command == "za" and #args == 1 and args[1]:match("^[A-Za-z@]+$") then
        return self:cover(args[1])
    elseif command == "rza" and #args == 2
        and args[1]:match("^[A-Za-z@]+$") and args[2]:match("^[A-Za-z@]+$") then
        return self:order_cover(args[1], args[2])
    end
    note("Uzycie: /z NUMER | /za LITERA | /rza LITERA LITERA (lub @ jako cel zaslony).", P().yellow)
    return false
end

-- On Chimera 5, official /z and /za remain authoritative.
-- /vz, /vza and /vrza preserve VIP's original direct-ID logic.
function A:install_aliases()
    U.clear_aliases(self)
    local v5=C.runtime and C.runtime:is_chimera5() or false
    self.v5_mode=v5
    if not v5 then self:disable_official_aliases() end
    local names=v5 and {{"vz","z"},{"vza","za"},{"vrza","rza"}}
        or {{"z","z"},{"za","za"},{"rza","rza"}}
    for _,entry in ipairs(names) do
        local alias,action=entry[1],entry[2]
        local id=tempAlias("^/"..alias.."(?:\\s+(.*))?\\s*$",function()
            A:command(action,matches[2])
        end)
        if id then self.alias_ids[#self.alias_ids+1]=id end
    end
end
for _,event in ipairs({"sysLoadEvent","scriptsLoaded","uiReady",
    "chimeraVipReady","sysInstallPackage","chimeraVipUpstreamReady"}) do
    U.replace_handler(A,event,event,function()
        local v5=C.runtime and C.runtime:is_chimera5() or false
        if v5~=A.v5_mode then A:install_aliases()
        elseif not v5 then A:disable_official_aliases() end
    end)
end

A:install_aliases()
return A
