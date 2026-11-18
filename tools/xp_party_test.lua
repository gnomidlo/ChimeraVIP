-- End-to-end party XP, GMCP combat time and silent retainer snapshots.
chimera_vip = {}
local clock = 1000
local original_time = os.time
os.time = function() return clock end
local triggers, aliases, handlers, timers, killed_timers, sent, output = {}, {}, {}, {}, {}, {}, {}
local next_id = 0
local function id() next_id = next_id + 1; return next_id end
tempRegexTrigger = function(pattern, callback)
    local n = id()
    triggers[#triggers+1] = {pattern=pattern, callback=callback}
    return n
end
tempAlias = function(pattern, callback)
    local n = id()
    aliases[#aliases+1] = {pattern=pattern, callback=callback}
    return n
end
killTrigger, killAlias = function() end, function() end
tempTimer = function(_, callback)
    local n = id(); timers[n] = callback; return n
end
killTimer = function(n) killed_timers[n] = true end
registerAnonymousEventHandler = function(event, callback)
    local n = id(); handlers[event] = callback; return n
end
killAnonymousEventHandler = function() end
hecho = function(msg) output[#output+1] = msg end
echoLink = function(msg) output[#output+1] = msg end
hechoLink = function(msg) output[#output+1] = msg end
send = function(cmd) sent[#sent+1] = cmd end
deleteLine = function() end
raiseEvent = function() end

assert(dofile("src/core/util.lua"))
local XP = dofile("src/features/xp_tracker.lua")
assert(dofile("src/features/xp_kill_card_view.lua"))
local R = dofile("src/features/retainer_progress.lua")
local function clean() return table.concat(output):gsub("#%x%x%x%x%x%x", "") end

-- One party leader, two NPC retainers and a player companion.
gmcp = {
    Char = {Info={id="self",name="Xochitl"}},
    Chimera = {
        Group = {State={members={
            {id="self",name="Xochitl",self=1,here=1},
            {id="ch",name="Chasstana",self=0,here=1},
            {id="uz",name="Uzzarna",self=0,here=1},
            {id="other",name="Inny Gracz",self=0,here=1},
        }}},
        Room = {Entities={entities={
            {id="self",kind="player",relation="self",group_role="leader"},
            {id="ch",kind="npc",relation="ally",group_role="member"},
            {id="uz",kind="npc",relation="ally",group_role="member"},
            {id="other",kind="player",relation="ally",group_role="member"},
        }}},
        Combat = {State={relations={
            {attacker="self",defender="enemy"},
            {attacker="ch",defender="enemy"},
            {attacker="enemy",defender="uz"},
        }},Kill={victim={name="Nieaktualny mob"},killer={name="Chasstana"}}},
    },
}
assert(#XP:get_present_retainers() == 2)
assert(XP:find_present_retainer("Chasstana").id == "ch")
assert(not XP:find_present_retainer("Inny Gracz"))
assert(handlers["gmcp.Chimera.Combat.State"] and handlers["sysDisconnectionEvent"])

XP:on_combat_state(clock)
clock=1010
XP:on_combat_state(clock)
XP:remember_reward("Chasstana", 542)
XP:remember_reward("Uzzarna", 542)
XP:add_event("umiesnionego pijanego krasnoluda", 2170, "Chasstana", false)
assert(XP.session.total_xp == 2170 and XP.session.kills == 1)
assert(XP.session.retainers.ch.xp == 542)
assert(XP.session.retainers.uz.xp == 542)
assert(XP.session.killer_stats.Chasstana.kills == 1)

-- A stale GMCP Kill record must not keep combat open.
clock=1050
gmcp.Chimera.Combat.State.relations = {{attacker="ch",defender="enemy"}}
XP:on_combat_state(clock)
clock=1080
gmcp.Chimera.Combat.State.relations = {}
XP:on_combat_state(clock)
assert(XP.session.party_combat_seconds == 80)
assert(XP.session.self_combat_seconds == 50)
assert(XP.session.member_combat_seconds.ch == 80)
assert(XP.session.member_combat_seconds.uz == 50)
-- Even a resting helper receives XP while the party fights.
assert(XP.session.member_party_seconds.ch == 80)
assert(XP.session.member_party_seconds.uz == 80)
assert(XP.combat_clock.party == false)

-- /xp sends one ID command at a time; only the owning NPC gets its response.
local xp_alias
for _, alias in ipairs(aliases) do
    if alias.pattern == "^/xp$" then xp_alias = alias.callback end
end
assert(xp_alias)
output = {}
sent = {}
xp_alias()
assert(#sent == 1 and sent[1] == "parozkaz ch postepy")
assert(XP.snapshot_current.id == "ch")
assert(R:add_progress_line("Do nastepnej rangi Chasstanie brakuje 691373 doswiadczenia."))
assert(#sent == 2 and sent[2] == "parozkaz uz postepy")
assert(XP.snapshot_current.id == "uz")
assert(R:add_progress_line("Uzzarna osiagnela juz najwyzsza range wyszkolenia."))
assert(XP.snapshot_current == nil and XP.snapshot_queue == nil)
assert(XP.session.retainers.ch.snapshot.remaining == 691373)
assert(XP.session.retainers.ch.snapshot.xp_at_read == 542)
assert(XP.session.retainers.uz.snapshot.max_rank == true)
assert(R.progress == nil)
assert(clean():find("XP — SESJA", 1, true))
assert(clean():find("W walce druzyna", 1, true))
assert(clean():find("PACHOLKOWIE", 1, true))
assert(not clean():find("PACHOLKOWIE  POSTEPY", 1, true))

-- Further messages subtract from the snapshot, but never inflate own XP.
XP:remember_reward("Chasstana", 542)
assert(XP:retainer_remaining(XP.session.retainers.ch) == 690831)
assert(XP.session.retainers.ch.xp == 1084)
assert(XP.session.total_xp == 2170)
XP:remember_reward("Chasstana", 100)
assert(XP.session.retainers.ch.xp == 1184)
assert(XP:retainer_rate(XP.session.retainers.ch) ~= nil)
assert(XP:retainer_remaining(XP.session.retainers.uz) == "MAX")
output = {}
XP:show_retainers()
assert(clean():find("690 731", 1, true))
assert(clean():find("MAX", 1, true))
output = {}
XP:show_killers()
assert(clean():find("DOBICIA", 1, true))
assert(not clean():find("63 243", 1, true))

-- If one retainer does not answer, abort instead of assigning its late
-- reply to the next ID (names in replies are dative).
sent = {}
output = {}
assert(XP:request_snapshots("summary"))
local pending_id = XP.snapshot_timer
assert(pending_id and timers[pending_id])
timers[pending_id]()
assert(#sent == 1)
assert(XP.snapshot_current == nil and XP.snapshot_queue == nil)
assert(XP.session.retainers.ch.snapshot_error == true)
assert(clean():find("brak odpowiedzi", 1, true))

-- No NPC retainers -> /xp sends no parozkaz commands.
gmcp.Chimera.Group.State.members = {{id="self",name="Xochitl",self=1,here=1}}
gmcp.Chimera.Room.Entities.entities = {
    {id="self",kind="player",relation="self",group_role="leader"}}
sent, output = {}, {}
xp_alias()
assert(#sent == 0)
assert(clean():find("Brak pacholkow", 1, true))

-- Manual progress messages still reach the original parser after /xp ended.
output = {}
assert(R:add_progress_line("Zathrika osiagnela juz najwyzsza range wyszkolenia."))
assert(R.progress and #R.progress.entries == 1)
assert(R:finish_progress())
assert(clean():find("MAKSYMALNA RANGA", 1, true))

-- Reset clears both XP kinds, projections and accumulated combat time.
XP:reset()
assert(XP.session.total_xp == 0 and XP.session.kills == 0)
assert(next(XP.session.retainers) == nil)
assert(XP.session.party_combat_seconds == 0)
-- Long fights with only start/end GMCP messages are still timed correctly
-- because a 5-second heartbeat advances the combat clock between updates.
clock = 2000
gmcp.Chimera.Combat.State.relations = {{attacker="self", defender="enemy"}}
XP:on_combat_state(clock)
assert(XP.combat_tick)
for n=1,20 do
    clock = 2000 + n * 5
    local current_tick = XP.combat_tick
    assert(current_tick and timers[current_tick])
    timers[current_tick]()
end
gmcp.Chimera.Combat.State.relations = {}
XP:on_combat_state(clock)
assert(XP.session.party_combat_seconds == 100)
assert(XP.session.self_combat_seconds == 100)
assert(XP.combat_tick == nil)

os.time = original_time
print("GMCP party XP and silent per-ID snapshot workflow: PASS")
