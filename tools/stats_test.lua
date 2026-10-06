chimera_vip = {}
getMudletHomeDir = function() return "/tmp" end
local next_trigger_id = 0
local killed_triggers = {}
tempRegexTrigger = function()
    next_trigger_id = next_trigger_id + 1
    return next_trigger_id
end
tempAlias = function() return 1 end
killTrigger = function(id) killed_triggers[id] = true end
killAlias = function() end
registerAnonymousEventHandler = function() return 1 end
killAnonymousEventHandler = function() end
tempTimer = function() return 1 end
killTimer = function() end
hecho = function() end
raiseEvent = function() end
io.exists = function() return false end

assert(dofile("src/core/util.lua"))
local ST = dofile("src/features/stats.lua")
ST.current = {Sil=90, Zr=120, Wt=150, Int=80, Md=100, Odw=60}
local snapshot = ST:build_snapshot()
assert(snapshot.physical_average == 120)
assert(snapshot.mental_average == 90)
assert(snapshot.total == 600 and snapshot.average == 100)

local plain = {lavender="", mint="", text_muted="", blue=""}
local rendered = ST:average_line(snapshot, plain)
assert(rendered == "  SREDNIA: 100.0 (fizyczne: 120.0 | mentalne: 90.0)")

-- Regresja 0.155: compact view ma usunac tylko nazwany trigger cech,
-- a nie ostatni trigger modulu (ktorym moze byc np. gotowosc Przelomu).
local base_stat_trigger = ST.stat_trigger_id
local readiness_trigger = ST.trigger_ids[#ST.trigger_ids]
assert(base_stat_trigger and readiness_trigger and base_stat_trigger ~= readiness_trigger)
assert(dofile("src/features/stats_compact_view.lua"))
assert(killed_triggers[base_stat_trigger] == true)
assert(killed_triggers[readiness_trigger] ~= true)
assert(ST.stat_trigger_id ~= base_stat_trigger)

-- Regresja 0.155: niepelny snapshot z samym Odw i ujemnymi deltami
-- zostal zapisany przez zdublowany trigger. Naprawa ma odtworzyc pelne cechy
-- i usunac falszywy wpis historii.
local broken_record = {
    xp_since_change = 0,
    history = {
        {
            kind = "change",
            xp_since_previous = 1234,
            diff = {Sil=-142, Zr=-156, Wt=-147, Int=-156, Md=-152},
            snapshot = {
                stats = {Odw=152},
                captured_at = 1000,
            },
        },
    },
    last_observed = {
        stats = {Odw=152},
        captured_at = 1000,
    },
}
assert(ST:repair_0155_record(broken_record) == true)
assert(#broken_record.history == 0)
assert(ST:is_complete_snapshot(broken_record.last_observed))
assert(broken_record.last_observed.stats.Sil == 142)
assert(broken_record.last_observed.stats.Zr == 156)
assert(broken_record.last_observed.stats.Wt == 147)
assert(broken_record.last_observed.stats.Int == 156)
assert(broken_record.last_observed.stats.Md == 152)
assert(broken_record.last_observed.stats.Odw == 152)
assert(broken_record.xp_since_change == 1234)

-- Niepelny snapshot nie moze zostac zapisany jako prawdziwa zmiana.
gmcp = {Char={Name={name="Test"}}}
ST.data = {characters={}}
local record = ST:get_record(true)
record.last_observed = ST:snapshot_from_stats({Sil=142,Zr=156,Wt=147,Int=156,Md=152,Odw=152})
local incomplete = ST:snapshot_from_stats({Odw=152})
incomplete.stats = {Odw=152}
local _, kind = ST:update_progress(incomplete)
assert(kind == "incomplete")
assert(ST:is_complete_snapshot(record.last_observed))

print("Stats average and regression tests: PASS")
