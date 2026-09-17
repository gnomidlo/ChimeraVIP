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
    if not refresh_snapshot() then return nil end
    local id = T:get_enemy_target(mark)
    if not id then
        note("Nie ma przeciwnika oznaczonego [" .. mark .. "].", P().rose)
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

function A:install_aliases()
    U.clear_aliases(self)
    self:disable_official_aliases()
    -- Catch the entire command, including missing/invalid arguments, so it
    -- cannot silently fall through to an official alias or to the server.
    for _, command in ipairs({"z", "za", "rza"}) do
        local action = command
        local id = tempAlias("^/" .. action .. "(?:\\s+(.*))?\\s*$", function()
            A:command(action, matches[2])
        end)
        if id then self.alias_ids[#self.alias_ids + 1] = id end
    end
end

for _, event in ipairs({"sysLoadEvent", "scriptsLoaded", "uiReady", "chimeraVipReady", "sysInstallPackage"}) do
    U.replace_handler(A, event, event, function()
        A:disable_official_aliases()
        -- Package loading may finish after the event's other listeners.
        tempTimer(0, function() A:disable_official_aliases() end)
    end)
end

A:install_aliases()
return A
