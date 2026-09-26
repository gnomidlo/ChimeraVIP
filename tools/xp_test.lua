chimera_vip = {}

local next_id = 0
local function id()
    next_id = next_id + 1
    return next_id
end

tempRegexTrigger = function() return id() end
tempAlias = function() return id() end
killTrigger = function() end
killAlias = function() end
hecho = function() end
raiseEvent = function() end

assert(dofile('src/core/util.lua'))
local XP = dofile('src/features/xp_tracker.lua')

-- GMCP moze nadal wskazywac poprzednia ofiare, kiedy dociera tekst biezacego zabicia.
gmcp = {Chimera={Combat={Kill={
    victim={name='gigantyczny owlosiony pajak'},
    killer={name='Testowa'},
    by_self=1,
}}}}

XP:remember_death('Cuchnacy dlugouchy goblin')
local mob, killer = XP:get_kill_card_context('cuchnacego dlugouchego goblina', 'TY', true)
assert(mob == 'Cuchnacy dlugouchy goblin')
assert(killer == 'TY')

-- Bez poprzedzajacej linii smierci bezpieczniejszy jest aktualny tekst niz stare GMCP.
mob = XP:get_kill_card_context('wychudzonego zoltookiego goblina', 'TY', true)
assert(mob == 'wychudzonego zoltookiego goblina')

-- Przeterminowana nazwa nie moze przejsc do kolejnego zabicia.
XP.pending_death = {name='stary przeciwnik', time=os.time() - XP.death_window - 1}
mob = XP:get_kill_card_context('nowego przeciwnika', 'TY', true)
assert(mob == 'nowego przeciwnika')

print('XP kill card tests: PASS')
