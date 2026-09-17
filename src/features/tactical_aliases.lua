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
    refresh_snapshot()
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
    refresh_snapshot()
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

function A:install_aliases()
    U.clear_aliases(self)

    local function add(pattern, callback)
        local id = tempAlias(pattern, callback)
        if id then self.alias_ids[#self.alias_ids + 1] = id end
    end

    add([[^/z\s+(\d+)\s*$]], function()
        A:attack(matches[2])
    end)

    add([[^/za\s+([A-Za-z@]+)\s*$]], function()
        A:cover(matches[2])
    end)

    add([[^/q\s+([A-Za-z@]+)\s*$]], function()
        A:retreat(matches[2])
    end)

    add([[^/rza\s+([A-Za-z]+)\s+([A-Za-z@]+)\s*$]], function()
        A:order_cover(matches[2], matches[3])
    end)
end

A:install_aliases()
return A
