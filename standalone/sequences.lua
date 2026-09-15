-- Confirmed command sequences for mapper, inventory and transport adapters.
-- A timeout cancels the sequence; commands are never retried automatically.
local C = chimera_vip
local S = {running={}}
C.sequences = S

local function valid_command(command)
    return type(command)=="string" and command:match("%S")
        and not command:find("[%c;]") and command:sub(1,1)~="/"
end

function S:cancel(name, reason)
    local run = self.running[name]
    if not run then return false end
    self.running[name] = nil
    run.result = reason or "cancelled"
    C.lifecycle:close(run.owner)
    return true
end

function S:stop(reason)
    local names = {}
    for name in pairs(self.running) do names[#names+1]=name end
    for _, name in ipairs(names) do self:cancel(name, reason) end
end

function S:start(name, steps)
    if type(name)~="string" or name=="" then return false, "Invalid sequence name" end
    if self.running[name] then return false, "Sequence already running" end
    if not C.protocol.active then return false, "No active GMCP session" end
    if type(steps)~="table" or #steps==0 then return false, "Empty sequence" end
    -- Validate and snapshot the entire plan before the first side effect.
    local plan = {}
    local count = 0
    for key in pairs(steps) do
        if type(key)~="number" or key<1 or key%1~=0 or key>#steps then
            return false, "Sequence must be an array"
        end
        count=count+1
    end
    if count~=#steps then return false, "Sequence must be dense" end
    for index, step in ipairs(steps) do
        if type(step)~="table" or not valid_command(step.command)
            or type(step.event)~="string" or step.event==""
            or type(step.confirm)~="function" or type(step.timeout)~="number"
            or step.timeout~=step.timeout or step.timeout<=0 or step.timeout==math.huge then
            return false, "Invalid sequence step " .. index
        end
        plan[index]={command=step.command, event=step.event,
            confirm=step.confirm, timeout=step.timeout}
    end
    local run = {owner="sequence:"..name, index=0, epoch=C.protocol.epoch, result="running"}
    self.running[name] = run
    local function current()
        return S.running[name]==run and C.protocol.active and C.protocol.epoch==run.epoch
    end
    local function finish(reason)
        if S.running[name]==run then S:cancel(name, reason) end
    end
    local advance
    local function safely_advance()
        local ok, err = pcall(advance)
        if not ok then
            finish("registration failed")
            C.lifecycle:report(run.owner, err)
        end
    end
    advance = function()
        if not current() then finish("session changed"); return end
        run.index = run.index + 1
        local step = plan[run.index]
        if not step then finish("completed"); return end
        local scope = C.lifecycle:open(run.owner)
        local waiting = true
        -- Register both acknowledgement and timeout BEFORE sending. Mudlet
        -- callbacks (and deterministic replay) may acknowledge synchronously.
        scope:event(step.event, function(...)
            if not waiting or not current() then return end
            local ok, accepted = pcall(step.confirm, ...)
            if not current() then finish("session changed"); return end
            if not ok then
                finish("confirmation failed")
                C.lifecycle:report(run.owner, accepted)
                return
            end
            if accepted~=true then return end
            waiting = false
            scope = C.lifecycle:open(run.owner)
            local scheduled, err = pcall(function() scope:timer(0, safely_advance) end)
            if not scheduled then
                finish("registration failed")
                C.lifecycle:report(run.owner, err)
            end
        end)
        scope:timer(step.timeout, function() finish("timeout") end)
        local ok, err = pcall(send, step.command, false)
        if not ok then
            finish("send failed")
            C.lifecycle:report(run.owner, err)
        end
    end
    local ok, err = pcall(advance)
    if not ok then
        finish("registration failed")
        return false, tostring(err)
    end
    if run.result=="send failed" then return false, run.result end
    return true, run
end

function S:setup()
    local scope = C.lifecycle:open("sequences")
    scope:event("chimeraVipV2SessionReset", function() S:stop("session changed") end)
end

return S
