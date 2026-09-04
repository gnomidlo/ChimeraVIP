-- Test logiki Tactician poza Mudletem.

chimera_vip = {}
chimera_overlay = chimera_vip
gmcp = {}
scripts = {}

local output = {}
local sent = {}
local next_id = 0

local function id()
    next_id = next_id + 1
    return next_id
end

tempAlias = function() return id() end
tempRegexTrigger = function() return id() end
registerAnonymousEventHandler = function() return id() end
killAnonymousEventHandler = function() end
killAlias = function() end
killTrigger = function() end
killTimer = function() end
raiseEvent = function() end
cecho = function(text) output[#output + 1] = text end
hecho = function(text) output[#output + 1] = text end
send = function(command) sent[#sent + 1] = command end
tempTimer = function() return id() end

dofile("src/core/util.lua")

local settings_data = {automation={tactician_mode="off"}}
chimera_vip.settings = {
    get=function(_, path, fallback)
        if path == "automation.tactician_mode" then return settings_data.automation.tactician_mode end
        return fallback
    end,
    set=function(_, path, value)
        assert(path == "automation.tactician_mode")
        settings_data.automation.tactician_mode = value
        return true
    end,
    register_setting=function() return true end,
}

local T = dofile("src/features/tactician.lua")

local function fixture()
    gmcp = {
        Chimera={
            Combat={State={
                primary="enemy-33", room="room-1", self_active=1,
                relations={
                    {attacker="self-1", defender="enemy-33"},
                    {attacker="ally-2", defender="enemy-33"},
                    {attacker="enemy-33", defender="self-1"},
                    {attacker="enemy-34", defender="ally-2"},
                    {attacker="enemy-35", defender="ally-2"},
                    {attacker="enemy-36", defender="ally-2"},
                },
            }},
            Group={State={
                leader="self-1",
                members={
                    {here=1, hp=1219, maxhp=1800, id="self-1", name="Veesa", self=1},
                    {here=1, hp=214, maxhp=340, id="ally-2", name="Ephelia", self=0},
                },
            }},
            Room={Entities={entities={
                {hp=1219, maxhp=1800, id="self-1", name="Veesa", relation="self", self=1},
                {hp=214, maxhp=340, id="ally-2", name="Ephelia", relation="group", self=0},
                {hp=249, maxhp=1120, id="enemy-33", name="Smierdzacy fimir", relation="hostile", self=0},
                {hp=1060, maxhp=1060, id="enemy-34", name="Oblocony fimir", relation="hostile", self=0},
                {hp=940, maxhp=940, id="enemy-35", name="Maly fimir", relation="hostile", self=0},
                {hp=2100, maxhp=2100, id="enemy-36", name="Potezny fimir", relation="hostile", self=0},
            }}},
        },
    }
end

fixture()
local snapshot, err = T:build_snapshot()
assert(snapshot, err)
assert(snapshot.self_id == "self-1")
assert(#snapshot.attackers["self-1"] == 1)
assert(#snapshot.attackers["ally-2"] == 3)

local decision = T:choose_decision(snapshot)
assert(decision and decision.action == "cover", "oczekiwano zaslony Ephelii")
assert(decision.ally_id == "ally-2")
assert(decision.enemy_id == "enemy-36", "oczekiwano przeciwnika z najwiekszym HP")
assert(T:command_for(decision) == "zaslon ally-2 przed enemy-36")

-- Gdy Veesa jest przeciazona, a wytrzymaly sojusznik wolny, wybieramy wycofanie.
gmcp.Chimera.Group.State.members[1].hp = 200
gmcp.Chimera.Group.State.members[2].hp = 1000
gmcp.Chimera.Group.State.members[2].maxhp = 1200
gmcp.Chimera.Combat.State.relations = {
    {attacker="enemy-33", defender="self-1"},
    {attacker="enemy-34", defender="self-1"},
    {attacker="enemy-35", defender="self-1"},
}
snapshot = assert(T:build_snapshot())
decision = T:choose_decision(snapshot)
assert(decision and decision.action == "retreat", "oczekiwano wycofania za sojusznika")
assert(T:command_for(decision) == "wycofaj sie za ally-2")

-- Rowny rozklad przy rownym HP nie powinien powodowac przestawiania szyku.
gmcp.Chimera.Group.State.members[1].hp = 1000
gmcp.Chimera.Group.State.members[1].maxhp = 1000
gmcp.Chimera.Group.State.members[2].hp = 1000
gmcp.Chimera.Group.State.members[2].maxhp = 1000
gmcp.Chimera.Combat.State.relations = {
    {attacker="enemy-33", defender="self-1"},
    {attacker="enemy-34", defender="ally-2"},
}
snapshot = assert(T:build_snapshot())
assert(T:choose_decision(snapshot) == nil, "rowny rozklad powinien pozostac bez zmian")

-- OBS nie wysyla komendy, AUTO wysyla ja tylko przy gotowym manewrze.
fixture()
sent = {}
settings_data.automation.tactician_mode = "observe"
T.cache.ready = true
T:evaluate()
assert(#sent == 0, "tryb OBS nie moze wysylac komend")

settings_data.automation.tactician_mode = "auto"
T:evaluate()
assert(#sent == 1 and sent[1] == "zaslon ally-2 przed enemy-36")
assert(T.cache.ready == false, "proba manewru musi zuzyc gotowosc")
T:evaluate()
assert(#sent == 1, "bez promptu gotowosci nie wolno ponowic manewru")
T:mark_ready()
assert(T.cache.ready == true, "prompt gotowosci musi odblokowac manewr")
T:evaluate()
assert(#sent == 2, "po nowym promptcie gotowosci manewr moze zostac wykonany ponownie")

print("Tactician tests: PASS")
