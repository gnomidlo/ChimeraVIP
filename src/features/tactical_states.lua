-- ChimeraVIP / tactical states window
-- Compact GMCP-driven replacement view for the official "Kondycje" window.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
local R = C.runtime

C.tactical_states = C.tactical_states or {}
chimera_overlay.tactical_states = C.tactical_states
local T = C.tactical_states

T.handlers = T.handlers or {}
T.team_marks = T.team_marks or {}
T.room_enemy_marks = T.room_enemy_marks or {}
T.room_other_marks = T.room_other_marks or {}
T.team_next = T.team_next or 1
T.enemy_next = T.enemy_next or 1
T.other_next = T.other_next or 1
T.render_delay = 0.04
T.render_generation = T.render_generation or 0
T.last_frame = nil
T.room_key = T.room_key
T.snapshot = T.snapshot or nil

local function tostring_id(value)
    if value == nil then return nil end
    local text = tostring(value)
    return text ~= "" and text or nil
end

local function truthy(value)
    return value == true or tonumber(value) == 1
end

local function alpha_mark(index, upper)
    index = math.max(1, math.floor(tonumber(index) or 1))
    local chars = {}
    while index > 0 do
        local rem = (index - 1) % 26
        chars[#chars + 1] = string.char((upper and 65 or 97) + rem)
        index = math.floor((index - 1) / 26)
    end
    local out = {}
    for i = #chars, 1, -1 do out[#out + 1] = chars[i] end
    return table.concat(out)
end

local function percent(hp, maxhp)
    hp, maxhp = tonumber(hp), tonumber(maxhp)
    if not hp or not maxhp or maxhp <= 0 then return nil end
    return math.max(0, math.min(100, math.floor(hp * 100 / maxhp + 0.5)))
end

local function add_unique(list, seen, value)
    value = tostring_id(value)
    if not value or seen[value] then return end
    seen[value] = true
    list[#list + 1] = value
end

local function sorted_marks(ids, marks)
    local out = {}
    local seen = {}
    for _, id in ipairs(ids or {}) do
        local mark = marks[id]
        if mark and not seen[mark] then
            seen[mark] = true
            out[#out + 1] = mark
        end
    end
    table.sort(out, function(a, b)
        local an, bn = tonumber(a), tonumber(b)
        if an and bn then return an < bn end
        if an then return true end
        if bn then return false end
        return tostring(a) < tostring(b)
    end)
    return out
end

function T:reset_room_marks(room_key)
    self.room_key = room_key
    self.room_enemy_marks = {}
    self.room_other_marks = {}
    self.enemy_next = 1
    self.other_next = 1
end

function T:ensure_room()
    local room_key = R and R.room_key and R:room_key() or nil
    if room_key ~= self.room_key then
        self:reset_room_marks(room_key)
    end
end

function T:team_mark(id, is_self)
    id = tostring_id(id)
    if not id then return "?" end
    if is_self then return "@" end
    if not self.team_marks[id] then
        self.team_marks[id] = alpha_mark(self.team_next, true)
        self.team_next = self.team_next + 1
    end
    return self.team_marks[id]
end

function T:enemy_mark(id)
    id = tostring_id(id)
    if not id then return "?" end
    if not self.room_enemy_marks[id] then
        self.room_enemy_marks[id] = tostring(self.enemy_next)
        self.enemy_next = self.enemy_next + 1
    end
    return self.room_enemy_marks[id]
end

function T:other_mark(id)
    id = tostring_id(id)
    if not id then return "?" end
    if not self.room_other_marks[id] then
        self.room_other_marks[id] = alpha_mark(self.other_next, false)
        self.other_next = self.other_next + 1
    end
    return self.room_other_marks[id]
end

function T:build_snapshot()
    self:ensure_room()

    local group = R and R.group and R:group() or nil
    local combat = R and R.combat and R:combat() or nil
    local room_entities = gmcp and gmcp.Chimera and gmcp.Chimera.Room and gmcp.Chimera.Room.Entities
    local entities_source = room_entities and room_entities.entities

    if type(entities_source) ~= "table" then entities_source = {} end

    local snapshot = {
        room = self.room_key,
        leader_id = group and tostring_id(group.leader) or nil,
        self_id = nil,
        entities = {},
        group = {},
        enemies = {},
        others = {},
        group_ids = {},
        engaged_ids = {},
        group_in_combat = false,
        marks = {},
        outgoing = {},
        incoming = {},
    }

    for _, entity in pairs(entities_source) do
        if type(entity) == "table" and entity.id ~= nil then
            local id = tostring(entity.id)
            snapshot.entities[id] = {
                id = id,
                name = tostring(entity.name or id),
                hp = tonumber(entity.hp),
                maxhp = tonumber(entity.maxhp),
                kind = entity.kind,
                relation = entity.relation,
                self = truthy(entity.self),
            }
            if truthy(entity.self) then snapshot.self_id = id end
        end
    end

    if type(group) == "table" and type(group.members) == "table" then
        for _, member in ipairs(group.members) do
            if type(member) == "table" and member.id ~= nil and (member.here == nil or truthy(member.here)) then
                local id = tostring(member.id)
                snapshot.group_ids[id] = true
                if truthy(member.self) then snapshot.self_id = id end
                local entity = snapshot.entities[id] or {}
                snapshot.group[#snapshot.group + 1] = {
                    id = id,
                    name = (truthy(member.self) or id == snapshot.self_id) and "JA" or tostring(member.name or entity.name or id),
                    hp = tonumber(member.hp) or entity.hp,
                    maxhp = tonumber(member.maxhp) or entity.maxhp,
                    self = truthy(member.self) or id == snapshot.self_id,
                }
            end
        end
    end

    -- Group.State may contain an empty members table when playing solo.
    -- Room.Entities still identifies us; keep JA in DRUZYNA in that case too.
    if snapshot.self_id and not snapshot.group_ids[snapshot.self_id] and snapshot.entities[snapshot.self_id] then
        local entity = snapshot.entities[snapshot.self_id]
        snapshot.group_ids[snapshot.self_id] = true
        snapshot.group[#snapshot.group + 1] = {
            id = snapshot.self_id,
            name = "JA",
            hp = entity.hp,
            maxhp = entity.maxhp,
            self = true,
        }
    end

    local relation_seen = {}
    if type(combat) == "table" and type(combat.relations) == "table" then
        for _, relation in pairs(combat.relations) do
            if type(relation) == "table" then
                local attacker = tostring_id(relation.attacker)
                local defender = tostring_id(relation.defender)
                if attacker and defender then
                    local key = attacker .. "\0" .. defender
                    if not relation_seen[key] then
                        relation_seen[key] = true
                        snapshot.engaged_ids[attacker] = true
                        snapshot.engaged_ids[defender] = true
                        snapshot.outgoing[attacker] = snapshot.outgoing[attacker] or {}
                        snapshot.incoming[defender] = snapshot.incoming[defender] or {}
                        local out_seen = snapshot.outgoing[attacker]._seen or {}
                        local in_seen = snapshot.incoming[defender]._seen or {}
                        snapshot.outgoing[attacker]._seen = out_seen
                        snapshot.incoming[defender]._seen = in_seen
                        add_unique(snapshot.outgoing[attacker], out_seen, defender)
                        add_unique(snapshot.incoming[defender], in_seen, attacker)
                    end
                end
            end
        end
    end

    for id in pairs(snapshot.group_ids) do
        if snapshot.engaged_ids[id] then snapshot.group_in_combat = true; break end
    end

    local enemy_ids = {}
    for id in pairs(snapshot.engaged_ids) do
        if not snapshot.group_ids[id] then enemy_ids[#enemy_ids + 1] = id end
    end
    table.sort(enemy_ids)

    for _, id in ipairs(enemy_ids) do
        local entity = snapshot.entities[id] or {}
        snapshot.enemies[#snapshot.enemies + 1] = {
            id = id,
            name = tostring(entity.name or id),
            hp = entity.hp,
            maxhp = entity.maxhp,
            relation = entity.relation,
        }
    end

    local other_ids = {}
    for id in pairs(snapshot.entities) do
        if not snapshot.group_ids[id] and not snapshot.engaged_ids[id] then
            other_ids[#other_ids + 1] = id
        end
    end
    table.sort(other_ids)

    for _, id in ipairs(other_ids) do
        local entity = snapshot.entities[id]
        snapshot.others[#snapshot.others + 1] = {
            id = id,
            name = tostring(entity.name or id),
            hp = entity.hp,
            maxhp = entity.maxhp,
            relation = entity.relation,
            kind = entity.kind,
        }
    end

    table.sort(snapshot.group, function(a, b)
        if a.self ~= b.self then return a.self end
        local al = a.id == snapshot.leader_id
        local bl = b.id == snapshot.leader_id
        if al ~= bl then return al end
        if tostring(a.name) == tostring(b.name) then return a.id < b.id end
        return tostring(a.name) < tostring(b.name)
    end)

    -- Assign a dense alphabet to the current displayed group, not its history.
    -- The sorted rows give rendering and maneuver aliases the same ordering.
    self.team_marks = {}
    self.team_next = 1
    for _, row in ipairs(snapshot.group) do
        local mark = self:team_mark(row.id, row.self)
        row.mark = mark
        row.hp_percent = percent(row.hp, row.maxhp)
        row.leader = row.id == snapshot.leader_id
        snapshot.marks[row.id] = mark
    end

    table.sort(snapshot.enemies, function(a, b)
        local am = tonumber(self:enemy_mark(a.id)) or math.huge
        local bm = tonumber(self:enemy_mark(b.id)) or math.huge
        if am == bm then return tostring(a.name) < tostring(b.name) end
        return am < bm
    end)
    for _, row in ipairs(snapshot.enemies) do
        local mark = self:enemy_mark(row.id)
        row.mark = mark
        row.hp_percent = percent(row.hp, row.maxhp)
        snapshot.marks[row.id] = mark
    end

    table.sort(snapshot.others, function(a, b)
        local am = self:other_mark(a.id)
        local bm = self:other_mark(b.id)
        if am == bm then return tostring(a.name) < tostring(b.name) end
        return am < bm
    end)
    for _, row in ipairs(snapshot.others) do
        local mark = self:other_mark(row.id)
        row.mark = mark
        row.hp_percent = percent(row.hp, row.maxhp)
        snapshot.marks[row.id] = mark
    end

    for _, links in pairs(snapshot.outgoing) do links._seen = nil end
    for _, links in pairs(snapshot.incoming) do links._seen = nil end

    self.snapshot = snapshot
    return snapshot
end

local function health_color(P, value)
    if value == nil then return P.text_muted end
    if value <= 25 then return P.rose end
    if value <= 50 then return P.peach end
    if value <= 75 then return P.yellow end
    return P.mint
end

local function color_tag(value)
    return U and U.decho_tag and U.decho_tag(value) or ""
end

local function reset_tag()
    return "<r>"
end

function T:bar(value, P)
    if value == nil then
        return color_tag(P.separator) .. "[" .. color_tag(P.text_muted) .. "????????" .. color_tag(P.separator) .. "]" .. reset_tag()
    end
    local filled = math.floor(value / 100 * 8 + 0.5)
    filled = math.max(0, math.min(8, filled))
    local empty = 8 - filled
    local hc = health_color(P, value)
    return color_tag(P.separator) .. "["
        .. color_tag(hc) .. string.rep("#", filled)
        .. color_tag(P.inactive) .. string.rep("-", empty)
        .. color_tag(P.separator) .. "]" .. reset_tag()
end

function T:is_idle_member(id, snapshot)
    return snapshot.group_in_combat and snapshot.group_ids[id]
        and not snapshot.engaged_ids[id] or false
end

function T:relation_text(id, snapshot, P)
    if self:is_idle_member(id, snapshot) then
        return color_tag(P.yellow) .. " [X]" .. reset_tag()
    end
    local parts = {}
    local outgoing = sorted_marks(snapshot.outgoing[id] or {}, snapshot.marks)
    local incoming = sorted_marks(snapshot.incoming[id] or {}, snapshot.marks)

    if #outgoing > 0 then
        parts[#parts + 1] = color_tag(P.text_muted) .. " ->[" .. color_tag(P.lavender)
            .. table.concat(outgoing, ",") .. color_tag(P.text_muted) .. "]"
    end
    if #incoming > 0 then
        parts[#parts + 1] = color_tag(P.text_muted) .. " <-[" .. color_tag(P.rose)
            .. table.concat(incoming, ",") .. color_tag(P.text_muted) .. "]"
    end
    if #parts == 0 then return "" end
    return table.concat(parts) .. reset_tag()
end

function T:row_text(row, snapshot, category, P)
    local flag = row.leader and "★" or ""
    local flag_text = (U and U.pad_right and U.pad_right(flag, 2)) or (flag .. (flag == "" and "  " or " "))
    local hp_text
    if row.hp_percent == nil then
        hp_text = color_tag(P.text_muted) .. " --%"
    else
        hp_text = color_tag(health_color(P, row.hp_percent)) .. string.format("%3d%%", row.hp_percent)
    end

    local mark_color = P.text_muted
    local name_color = P.text
    if category == "group" then
        mark_color = row.self and P.mint or P.lavender
        name_color = row.self and P.mint or P.blue
    elseif category == "enemy" then
        mark_color = P.rose
        name_color = P.rose
    elseif category == "other" then
        mark_color = P.blue
        if row.relation == "hostile" then name_color = P.peach else name_color = P.text end
    end

    return color_tag(row.leader and P.lavender or P.text_muted) .. flag_text
        .. self:bar(row.hp_percent, P) .. " "
        .. hp_text .. " "
        .. color_tag(mark_color) .. "[" .. tostring(row.mark or "?") .. "] "
        .. color_tag(name_color) .. tostring(row.name or row.id)
        .. self:relation_text(row.id, snapshot, P)
        .. reset_tag()
end

function T:build_frame(snapshot)
    local P = U and U.palette and U.palette() or {
        text="#D8DCE6", text_muted="#AEB6C5", rose="#F0A8B8", mint="#A8DCC2",
        blue="#AFCBF4", lavender="#C7B9E8", peach="#F2C4A0", yellow="#EFD8A6",
        separator="#2B303C", inactive="#303542",
    }

    local lines = {}
    local function section(title, rows, category)
        if #rows == 0 then return end
        if #lines > 0 then lines[#lines + 1] = "" end
        lines[#lines + 1] = color_tag(P.text_muted) .. title .. reset_tag()
        for _, row in ipairs(rows) do
            lines[#lines + 1] = self:row_text(row, snapshot, category, P)
        end
    end

    section("DRUZYNA", snapshot.group, "group")
    section("WROGOWIE", snapshot.enemies, "enemy")
    section("INNI", snapshot.others, "other")

    if #lines == 0 then
        lines[1] = color_tag(P.text_muted) .. "Brak danych GMCP o postaciach na lokacji." .. reset_tag()
    end
    return table.concat(lines, "\n") .. "\n"
end

function T:window_name()
    if scripts and scripts.ui and scripts.ui.states_window_name then
        return scripts.ui.states_window_name
    end
    return "states_window"
end

function T:ensure_window()
    local name = self:window_name()
    if scripts and scripts.ui and type(scripts.ui.create_state_window) == "function" then
        local loaded = scripts.ui.states_windows_loaded
        if type(loaded) ~= "table" or not loaded[name] then
            pcall(function() scripts.ui:create_state_window(name) end)
        end
    end
    return name
end

function T:render(force)
    local snapshot = self:build_snapshot()
    local frame = self:build_frame(snapshot)
    if not force and frame == self.last_frame then return true end

    local name = self:ensure_window()
    local cleared = pcall(clearUserWindow, name)
    if not cleared then return false end
    local ok = pcall(decho, name, frame)
    if ok then
        self.last_frame = frame
        raiseEvent("chimeraVipTacticalStatesUpdated", snapshot)
    end
    return ok
end

function T:schedule_render(delay, force)
    self.render_generation = (self.render_generation or 0) + 1
    local generation = self.render_generation
    if self.render_timer then pcall(killTimer, self.render_timer) end
    self.render_timer = tempTimer(delay or self.render_delay, function()
        if generation ~= T.render_generation then return end
        T.render_timer = nil
        if force then T.last_frame = nil end
        T:render(force)
    end)
end

function T:get_group_target(mark)
    mark = tostring(mark or ""):upper()
    if mark == "@" and self.snapshot and self.snapshot.self_id then return self.snapshot.self_id end
    for _, row in ipairs(self.snapshot and self.snapshot.group or {}) do
        if tostring(row.mark or ""):upper() == mark then return row.id end
    end
    return nil
end

function T:get_enemy_target(mark)
    mark = tostring(mark or "")
    for _, row in ipairs(self.snapshot and self.snapshot.enemies or {}) do
        if tostring(row.mark or "") == mark then return row.id end
    end
    return nil
end

function T:get_other_target(mark)
    mark = tostring(mark or ""):lower()
    for _, row in ipairs(self.snapshot and self.snapshot.others or {}) do
        if tostring(row.mark or ""):lower() == mark then return row.id end
    end
    return nil
end

U.replace_handler(T, "group_state", "gmcp.Chimera.Group.State", function() T:schedule_render() end)
U.replace_handler(T, "group", "gmcp.Chimera.Group", function() T:schedule_render() end)
U.replace_handler(T, "combat_state", "gmcp.Chimera.Combat.State", function() T:schedule_render() end)
U.replace_handler(T, "combat", "gmcp.Chimera.Combat", function() T:schedule_render() end)
U.replace_handler(T, "room_entities", "gmcp.Chimera.Room.Entities", function() T:schedule_render() end)
U.replace_handler(T, "room_info", "gmcp.Room.Info", function()
    T:ensure_room()
    T:schedule_render()
end)
U.replace_handler(T, "ui_ready", "uiReady", function() T:schedule_render(0.08, true) end)
U.replace_handler(T, "theme_ready", "chimeraThemeReady", function() T:schedule_render(0.02, true) end)
U.replace_handler(T, "scripts_loaded", "scriptsLoaded", function() T:schedule_render(0.08, true) end)
U.replace_handler(T, "disconnect", "sysDisconnectionEvent", function()
    T:reset_room_marks(nil)
    T.snapshot = nil
    T.last_frame = nil
end)

tempTimer(0.10, function() T:schedule_render(0, true) end)

return T
