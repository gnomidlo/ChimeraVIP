-- Native GMCP only. Never import cached legacy gmcp.objects/room data.
local C = chimera_vip
local P = C.protocol or {active=false, subscribed=false, epoch=0, sequence=0, snapshots={}}
C.protocol = P
local copy = C.util.deep_copy

function P:reset()
    self.active = false
    self.subscribed = false
    self.epoch = self.epoch + 1
    self.snapshots = {}
end

function P:subscribe()
    if not self.active or self.subscribed then return end
    -- Set before sending: a synchronous response may call receive again.
    self.subscribed = true
    local ok, err = pcall(sendGMCP,
        'Core.Supports.Add ["Char 1", "Room 1", "Chimera.Group 1", "Chimera.Room.Entities 1", "Chimera.Combat 1"]')
    if not ok then self.subscribed = false; error(err) end
end

function P:enable()
    self.active = true
    self:subscribe()
end

local definitions = {
    {key="name", path={"Char", "Name"}},
    {key="vitals", path={"Char", "Vitals"}},
    {key="room", path={"Room", "Info"}, field="id", field_type="string"},
    {key="entities", path={"Chimera", "Room", "Entities"}, field="entities", field_type="table"},
    {key="group", path={"Chimera", "Group", "State"}, field="members", field_type="table"},
    {key="combat", path={"Chimera", "Combat", "State"}, field="relations", field_type="table"},
    {key="kill", path={"Chimera", "Combat", "Kill"}, field="victim", field_type="table"},
}

function P:receive(definition)
    local value = gmcp
    for _, part in ipairs(definition.path) do
        value = type(value)=="table" and value[part] or nil
    end
    if type(value)~="table" then return end
    if definition.field and type(value[definition.field])~=definition.field_type then return end
    -- An incoming native packet is evidence of GMCP even if this runtime
    -- started after sysProtocolEnabled. Do not infer it from cached tables.
    local received = copy(value)
    local key = definition.key
    if key == "room" then
        local previous = self.snapshots.room
        local old = previous and previous.value
        if not old or old.id~=received.id or old.instance~=received.instance then
            for _, dependent in ipairs({"entities", "combat"}) do
                local snapshot = self.snapshots[dependent]
                if snapshot and (snapshot.value.room~=received.id
                    or (old and old.id==received.id and old.instance~=received.instance)) then
                    self.snapshots[dependent] = nil
                end
            end
            self.snapshots.kill = nil
        end
    elseif key == "entities" then
        local old = self.snapshots.entities
        if old and old.value.room~=received.room then
            local combat = self.snapshots.combat
            if combat and combat.value.room~=received.room then self.snapshots.combat=nil end
            self.snapshots.kill=nil
        end
    end
    self.sequence = self.sequence + 1
    self.snapshots[key] = {value=received, epoch=self.epoch, sequence=self.sequence}
    self:enable()
    raiseEvent("chimeraVipV2StateChanged", key, self.epoch)
end

function P:get(key)
    if not self.active then return nil end
    local snapshot = self.snapshots[key]
    if not snapshot or snapshot.epoch~=self.epoch then return nil end
    return copy(snapshot.value)
end

function P:start()
    local scope = C.lifecycle:open("protocol")
    scope:event("sysProtocolEnabled", function(_, protocol)
        if protocol=="GMCP" then P:enable() end
    end)
    scope:event("sysProtocolDisabled", function(_, protocol)
        if protocol=="GMCP" then P:reset() end
    end)
    scope:event("sysConnectionEvent", function() P:reset() end)
    scope:event("sysDisconnectionEvent", function() P:reset() end)
    for _, definition in ipairs(definitions) do
        local def = definition
        scope:event("gmcp." .. table.concat(def.path, "."), function() P:receive(def) end)
    end
    -- A hot reload preserves only snapshots received by this service during
    -- this connection. It does not read the global GMCP cache at startup.
    self.subscribed = false
    self:subscribe()
end

return P
