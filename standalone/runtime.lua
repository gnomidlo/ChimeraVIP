local C = chimera_vip
local R = {}
C.runtime = R
function R:room() return C.protocol:get("room") end
function R:group() return C.protocol:get("group") end
function R:vitals() return C.protocol:get("vitals") end
function R:entities()
    local room, entities = self:room(), C.protocol:get("entities")
    if room and entities and entities.room==room.id then return entities end
end
function R:combat()
    local entities, combat = self:entities(), C.protocol:get("combat")
    if entities and combat and entities.room==combat.room then return combat end
end
function R:room_key()
    local room = self:room()
    if room then return room.id .. "#" .. tostring(room.instance or 0) end
end
-- No upstream fallback: action implementations arrive in a later milestone.
function R:can_action() return false end
function R:action() return false, "Akcje 2.0 nie sa jeszcze zaimplementowane" end
return R
