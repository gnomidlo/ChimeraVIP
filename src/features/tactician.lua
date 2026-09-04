chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
local T = C.tactician or {}
C.tactician = T
chimera_overlay.tactician = T

T.handlers = T.handlers or {}
T.ui = T.ui or {}
T.cache = T.cache or {
    ready = false,
    debounce_timer = nil,
    last_observation = nil,
    last_action = nil,
}
T.debounce_delay = T.debounce_delay or 0.04
T.modes = {"off", "observe", "auto"}

local function palette()
    return U.palette()
end

local function same_id(a, b)
    return a ~= nil and b ~= nil and tostring(a) == tostring(b)
end

local function truthy(value)
    if value == true then return true end
    if value == false or value == nil then return false end
    if type(value) == "number" then return value > 0 end
    local text = tostring(value):lower():gsub("^%s+", ""):gsub("%s+$", "")
    return text ~= "" and text ~= "0" and text ~= "false" and text ~= "off" and text ~= "nie"
end

local function percent(hp, maxhp)
    hp, maxhp = tonumber(hp), tonumber(maxhp)
    if not hp or not maxhp or maxhp <= 0 then return nil end
    return math.max(0, math.min(100, hp * 100 / maxhp))
end

local function combat_state()
    if not gmcp or not gmcp.Chimera or not gmcp.Chimera.Combat then return nil end
    return gmcp.Chimera.Combat.State or gmcp.Chimera.Combat
end

local function group_state()
    if not gmcp or not gmcp.Chimera or not gmcp.Chimera.Group then return nil end
    return gmcp.Chimera.Group.State or gmcp.Chimera.Group
end

local function room_entities()
    if not gmcp or not gmcp.Chimera or not gmcp.Chimera.Room then return nil end
    local source = gmcp.Chimera.Room.Entities
    if not source then return nil end
    return source.entities or source
end

function T:get_mode()
    local mode = C.settings and C.settings:get("automation.tactician_mode", "off") or "off"
    if mode ~= "observe" and mode ~= "auto" then return "off" end
    return mode
end

function T:set_mode(mode, silent)
    mode = tostring(mode or "off"):lower()
    local aliases = {
        off="off", wylacz="off", ["wyłącz"]="off", stop="off",
        observe="observe", obserwuj="observe", obs="observe",
        auto="auto", on="auto", wlacz="auto", ["włącz"]="auto",
    }
    mode = aliases[mode]
    if not mode then return false end

    if C.settings then C.settings:set("automation.tactician_mode", mode) end
    self.cache.last_observation = nil
    if mode ~= "off" then self:sync_readiness() end
    self:update_ui()
    raiseEvent("chimeraTacticianModeChanged", mode)

    if not silent then
        local labels = {off="OFF", observe="OBS", auto="AUTO"}
        local colors = {off="light_pink", observe="khaki", auto="aquamarine"}
        cecho("\n<" .. colors[mode] .. ">[Tactician]<reset> Tryb: <" .. colors[mode] .. ">" .. labels[mode] .. "<reset>\n")
    end
    if mode ~= "off" then self:schedule_evaluation() end
    return true
end

function T:cycle_mode()
    local current = self:get_mode()
    if current == "off" then return self:set_mode("observe") end
    if current == "observe" then return self:set_mode("auto") end
    return self:set_mode("off")
end

function T:sync_readiness()
    local nav = scripts and scripts.ui and scripts.ui.states_window_nav_states
    local official = scripts and scripts.ui and scripts.ui.footer_info_cover_ready_enable_click
    if truthy(official) then
        self.cache.ready = true
        return true
    end
    local guard = nav and tonumber(nav.guard_state)
    if guard and guard <= 0 then
        self.cache.ready = true
        return true
    end
    return self.cache.ready
end

function T:mark_ready()
    self.cache.ready = true
    self.cache.last_action = nil
    self:update_ui()
    self:schedule_evaluation()
end

function T:build_snapshot()
    local combat, group, entities = combat_state(), group_state(), room_entities()
    if type(combat) ~= "table" or type(group) ~= "table" or type(group.members) ~= "table" then
        return nil, "brak pelnego GMCP walki lub druzyny"
    end

    local snapshot = {
        room = combat.room,
        primary = combat.primary,
        self_id = nil,
        members = {},
        enemies = {},
        attackers = {},
        relations = {},
    }

    if type(entities) == "table" then
        for _, entity in pairs(entities) do
            if type(entity) == "table" and entity.id then
                local id = tostring(entity.id)
                if entity.relation == "hostile" then
                    snapshot.enemies[id] = {
                        id=id, name=entity.name or id,
                        hp=tonumber(entity.hp), maxhp=tonumber(entity.maxhp),
                    }
                end
                if tonumber(entity.self) == 1 then snapshot.self_id = id end
            end
        end
    end

    for _, member in ipairs(group.members) do
        if type(member) == "table" and member.id and (member.here == nil or truthy(member.here)) then
            local id = tostring(member.id)
            snapshot.members[id] = {
                id=id,
                name=member.name or id,
                hp=tonumber(member.hp) or 0,
                maxhp=tonumber(member.maxhp) or 0,
                hp_percent=percent(member.hp, member.maxhp),
                self=tonumber(member.self) == 1,
            }
            if tonumber(member.self) == 1 then snapshot.self_id = id end
        end
    end

    if not snapshot.self_id then return nil, "brak identyfikatora wlasnej postaci" end
    if not snapshot.members[snapshot.self_id] then return nil, "wlasna postac nie wystepuje w druzynie" end

    for id in pairs(snapshot.members) do snapshot.attackers[id] = {} end
    if type(combat.relations) == "table" then
        for _, relation in pairs(combat.relations) do
            if type(relation) == "table" and relation.attacker and relation.defender then
                local attacker, defender = tostring(relation.attacker), tostring(relation.defender)
                snapshot.relations[#snapshot.relations + 1] = {attacker=attacker, defender=defender}
                if snapshot.members[defender] and snapshot.enemies[attacker] then
                    snapshot.attackers[defender][#snapshot.attackers[defender] + 1] = attacker
                end
            end
        end
    end

    return snapshot
end

local function total_risk(snapshot, counts)
    local risk = 0
    for id, member in pairs(snapshot.members) do
        local count = counts[id] or #(snapshot.attackers[id] or {})
        local hp = math.max(1, tonumber(member.hp) or 0)
        local load = (count * 1000) / hp
        risk = risk + load * load
    end
    return risk
end

local function longest_threat(snapshot, ids)
    local best_id, best_hp = nil, -1
    for _, id in ipairs(ids or {}) do
        local enemy = snapshot.enemies[id] or {}
        local hp = tonumber(enemy.hp) or tonumber(enemy.maxhp) or 0
        if hp > best_hp or (hp == best_hp and tostring(id) < tostring(best_id or "~")) then
            best_id, best_hp = id, hp
        end
    end
    return best_id
end

function T:choose_decision(snapshot)
    if type(snapshot) ~= "table" or not snapshot.self_id then return nil end
    local self_id = snapshot.self_id
    local self_member = snapshot.members[self_id]
    local self_attackers = snapshot.attackers[self_id] or {}
    local counts = {}
    local ally_count = 0
    for id in pairs(snapshot.members) do
        counts[id] = #(snapshot.attackers[id] or {})
        if not same_id(id, self_id) then ally_count = ally_count + 1 end
    end
    if ally_count == 0 then return nil end

    local before = total_risk(snapshot, counts)
    local best = nil
    local function consider(candidate)
        if candidate.improvement <= 0 then return end
        local candidate_key = table.concat({candidate.action or "", candidate.ally_id or "", candidate.enemy_id or ""}, "|")
        local best_key = best and table.concat({best.action or "", best.ally_id or "", best.enemy_id or ""}, "|") or nil
        if not best
            or candidate.improvement > best.improvement + 0.000001
            or (math.abs(candidate.improvement - best.improvement) <= 0.000001 and candidate_key < best_key)
        then
            best = candidate
        end
    end

    -- Zaslona przenosi jednego, konkretnie wskazanego przeciwnika na nas.
    for ally_id, ally in pairs(snapshot.members) do
        local attackers = snapshot.attackers[ally_id] or {}
        if not same_id(ally_id, self_id) and #attackers > 0 and (ally.hp or 0) > 0 then
            local simulated = {}
            for id, count in pairs(counts) do simulated[id] = count end
            simulated[ally_id] = math.max(0, simulated[ally_id] - 1)
            simulated[self_id] = simulated[self_id] + 1
            local after = total_risk(snapshot, simulated)
            consider({
                action="cover", ally_id=ally_id, enemy_id=longest_threat(snapshot, attackers),
                improvement=before-after, before=before, after=after,
                reason=ally.name .. " ma " .. tostring(#attackers) .. " napastnikow i "
                    .. tostring(math.floor((ally.hp_percent or 0) + 0.5)) .. "% HP",
            })
        end
    end

    -- Wycofanie moze przeniesc od jednego do czterech przeciwnikow losowo.
    -- Kandydat jest oceniany po srednim ryzyku wszystkich mozliwych wynikow,
    -- zamiast zakladac najwygodniejszy dla nas rezultat.
    if #self_attackers > 0 and (self_member.hp or 0) > 0 then
        for ally_id, ally in pairs(snapshot.members) do
            if not same_id(ally_id, self_id) and (ally.hp or 0) > 0 then
                local max_shift = math.min(4, #self_attackers)
                local risk_sum = 0
                for shift = 1, max_shift do
                    local simulated = {}
                    for id, count in pairs(counts) do simulated[id] = count end
                    simulated[self_id] = math.max(0, simulated[self_id] - shift)
                    simulated[ally_id] = simulated[ally_id] + shift
                    risk_sum = risk_sum + total_risk(snapshot, simulated)
                end
                local after = risk_sum / max_shift
                consider({
                    action="retreat", ally_id=ally_id,
                    improvement=before-after, before=before, after=after,
                    reason=self_member.name .. " ma " .. tostring(#self_attackers) .. " napastnikow i "
                        .. tostring(math.floor((self_member.hp_percent or 0) + 0.5)) .. "% HP"
                        .. " (wycofanie 1-" .. tostring(max_shift) .. ")",
                })
            end
        end
    end

    if not best then return nil end
    local relative = before > 0 and (best.improvement / before) or 0
    if relative < 0.08 then return nil end
    best.relative_improvement = relative
    best.ally = snapshot.members[best.ally_id]
    best.enemy = best.enemy_id and snapshot.enemies[best.enemy_id] or nil
    return best
end

function T:decision_key(decision)
    if not decision then return "none" end
    return table.concat({decision.action or "", decision.ally_id or "", decision.enemy_id or ""}, "|")
end

function T:describe(decision)
    if not decision then return "brak korzystnego manewru" end
    if decision.action == "cover" then
        return "zaslon " .. tostring(decision.ally and decision.ally.name or decision.ally_id)
            .. " przed " .. tostring(decision.enemy and decision.enemy.name or decision.enemy_id)
    end
    return "wycofaj sie za " .. tostring(decision.ally and decision.ally.name or decision.ally_id)
end

function T:command_for(decision)
    if not decision then return nil end
    if decision.action == "cover" and decision.ally_id and decision.enemy_id then
        return "zaslon " .. tostring(decision.ally_id) .. " przed " .. tostring(decision.enemy_id)
    end
    if decision.action == "retreat" and decision.ally_id then
        return "wycofaj sie za " .. tostring(decision.ally_id)
    end
    return nil
end

function T:print_decision(decision, prefix)
    local P = palette()
    local gain = decision and math.floor((decision.relative_improvement or 0) * 100 + 0.5) or 0
    hecho("\n" .. P.lavender .. "[Tactician] " .. P.text .. tostring(prefix or "Rekomendacja") .. ": "
        .. P.mint .. self:describe(decision))
    if decision then
        hecho(P.text_muted .. "  |  " .. tostring(decision.reason) .. "  |  poprawa ryzyka: " .. tostring(gain) .. "%")
    end
    hecho("\n")
end

function T:evaluate()
    self.cache.debounce_timer = nil
    local mode = self:get_mode()
    if mode == "off" then return end

    local snapshot = self:build_snapshot()
    if not snapshot then return end
    local decision = self:choose_decision(snapshot)
    local key = self:decision_key(decision)

    if mode == "observe" then
        if decision and key ~= self.cache.last_observation then
            self.cache.last_observation = key
            self:print_decision(decision, "Rekomendacja")
        elseif not decision then
            self.cache.last_observation = "none"
        end
        self:update_ui()
        return
    end

    if not self.cache.ready or not decision then
        self:update_ui()
        return
    end

    local command = self:command_for(decision)
    if not command then return end
    self.cache.ready = false
    self.cache.last_action = {command=command, decision=decision}
    self.cache.last_observation = key
    self:print_decision(decision, "Wykonuje")
    send(command, false)
    self:update_ui()
end

function T:schedule_evaluation()
    if self:get_mode() == "off" then return end
    if self.cache.debounce_timer then pcall(killTimer, self.cache.debounce_timer) end
    self.cache.debounce_timer = tempTimer(self.debounce_delay, function() T:evaluate() end)
end

function T:status()
    local P = palette()
    local snapshot, err = self:build_snapshot()
    local labels = {off="OFF", observe="OBS", auto="AUTO"}
    hecho("\n" .. P.lavender .. "TACTICIAN" .. P.text_muted .. "  |  tryb: "
        .. P.text .. labels[self:get_mode()] .. P.text_muted .. "  |  manewr: "
        .. (self.cache.ready and P.mint .. "GOTOWY" or P.rose .. "ODNOWIENIE"))
    if not snapshot then hecho("\n" .. P.rose .. "  " .. tostring(err)); hecho("\n"); return end
    for id, member in pairs(snapshot.members) do
        local count = #(snapshot.attackers[id] or {})
        hecho("\n" .. P.text_muted .. "  " .. tostring(member.name) .. ": " .. P.text
            .. tostring(member.hp) .. "/" .. tostring(member.maxhp) .. " HP  |  napastnicy: " .. tostring(count))
    end
    local decision = self:choose_decision(snapshot)
    hecho("\n" .. P.text_muted .. "  decyzja: " .. P.mint .. self:describe(decision) .. "\n")
end

function T:command(argument)
    local arg = U.normalize(argument)
    if arg == "" or arg == "status" then self:status(); return true end
    if arg == "pomoc" or arg == "help" then
        hecho("\n" .. palette().lavender .. "TACTICIAN" .. palette().text_muted
            .. "\n  /tactician off       wylacz"
            .. "\n  /tactician obserwuj  pokazuj rekomendacje"
            .. "\n  /tactician auto      wykonuj manewry"
            .. "\n  /tactician status    pokaz stan pola walki\n")
        return true
    end
    if self:set_mode(arg) then return true end
    cecho("\n<yellow>[Tactician]<reset> Uzyj: off, obserwuj, auto, status albo pomoc.\n")
    return false
end

function T:destroy_ui()
    if not self.ui.button then return end
    pcall(function() self.ui.button:hide() end)
    pcall(function() self.ui.button:delete() end)
    self.ui.button = nil
end

function T:update_ui()
    local button = self.ui.button
    if not button then return end
    local P, mode = palette(), self:get_mode()
    local colors = {off=P.rose, observe=P.yellow, auto=P.mint}
    local labels = {off="OFF", observe="OBS", auto="AUTO"}
    local ready = mode ~= "off" and self.cache.ready and " ✓" or ""
    local text = self.ui.button_width and self.ui.button_width < 95
        and ("TACT " .. labels[mode])
        or ("TACTICIAN  ● " .. labels[mode] .. ready)
    button:echo("<center><font color='" .. colors[mode] .. "'>" .. text .. "</font></center>")
    button:setStyleSheet("QLabel {background-color:" .. P.background_soft .. ";color:" .. P.text
        .. ";border:1px solid " .. P.separator .. ";border-radius:4px;padding:0px 3px;font-size:8px;}"
        .. " QLabel:hover {border-color:" .. P.lavender .. ";}")
    local tooltip = "<b>Tactician</b><br>Tryb: <b>" .. labels[mode] .. "</b>"
        .. "<br>Manewr: <b>" .. (self.cache.ready and "gotowy" or "odnowienie / brak potwierdzenia") .. "</b>"
        .. "<br><br>OFF → OBS → AUTO → OFF"
        .. "<br>OBS pokazuje rekomendacje. AUTO wykonuje zaslone lub wycofanie po ID GMCP."
    pcall(setLabelToolTip, button.name, tooltip, 8)
end

function T:attach_ui()
    local HUD = C.quiet_footer
    if not HUD or not HUD.zone3 or not HUD.layout then return end
    self:destroy_ui()
    local width = HUD.layout.zone3_width or 0
    if width < 80 then return end
    local gap = 3
    local button_width = math.floor((math.min(width, 200) - gap) / 2)
    local x = button_width + gap
    local name = "chimera_vip.tactician." .. tostring(HUD.generation or 0) .. ".button"
    self.ui.button = Geyser.Label:new({name=name, x=x, y=8, width=button_width, height=25, fontSize=8}, HUD.zone3)
    self.ui.button_width = button_width
    self.ui.button:setClickCallback(function() T:cycle_mode() end)
    pcall(setLabelCursor, name, "PointingHand")
    self:update_ui()
end

if C.settings then
    C.settings:register_setting("tactician_mode", {
        type="choice", section="automation", order=20,
        title="Tactician", description="OFF, obserwacja rekomendacji albo automatyczne manewry szyku.",
        path="automation.tactician_mode", default="off",
        options={
            {value="off", label="OFF"},
            {value="observe", label="OBS"},
            {value="auto", label="AUTO"},
        },
    })
end

U.clear_aliases(T)
T.alias_ids = T.alias_ids or {}
local alias_id = tempAlias([[^/tactician(?:\s+(.*))?$]], function() T:command(matches[2] or "") end)
if alias_id then T.alias_ids[#T.alias_ids + 1] = alias_id end

if T.ready_trigger then pcall(killTrigger, T.ready_trigger) end
T.ready_trigger = tempRegexTrigger([[^Jestes gotowa do zmiany w szyku\.$]], function() T:mark_ready() end)

U.replace_handler(T, "combat_state", "gmcp.Chimera.Combat.State", function() T:schedule_evaluation() end)
U.replace_handler(T, "combat", "gmcp.Chimera.Combat", function() T:schedule_evaluation() end)
U.replace_handler(T, "group_state", "gmcp.Chimera.Group.State", function() T:schedule_evaluation() end)
U.replace_handler(T, "group", "gmcp.Chimera.Group", function() T:schedule_evaluation() end)
U.replace_handler(T, "entities", "gmcp.Chimera.Room.Entities", function() T:schedule_evaluation() end)
U.replace_handler(T, "vitals", "gmcp.Char.Vitals", function() T:schedule_evaluation() end)
U.replace_handler(T, "footer_ready", "chimeraFooterReady", function() tempTimer(0, function() T:attach_ui() end) end)
U.replace_handler(T, "settings_changed", "chimeraVipSettingsChanged", function(_, path)
    if tostring(path) == "automation.tactician_mode" or tostring(path) == "tactician_mode" then
        T.cache.last_observation = nil
        T:sync_readiness()
        T:update_ui()
        T:schedule_evaluation()
    end
end)

T:sync_readiness()
if C.quiet_footer and C.quiet_footer.zone3 then tempTimer(0, function() T:attach_ui() end) end
raiseEvent("chimeraTacticianReady", T:get_mode(), T.cache.ready)

return T
