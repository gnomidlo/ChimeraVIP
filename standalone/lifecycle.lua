-- Owned resources for the experimental standalone runtime.
local C = chimera_vip
local L = C.lifecycle or {scopes={}, errors={}}
C.lifecycle = L

function L:report(owner, err)
    self.errors[#self.errors+1] = {owner=owner, message=tostring(err)}
    if #self.errors > 20 then table.remove(self.errors, 1) end
    cecho("\n<orange>[ChimeraVIP 2.0] " .. owner .. ": " .. tostring(err) .. "<reset>\n")
end

function L:close(name)
    local scope = self.scopes[name]
    if not scope then return end
    scope.active = false
    self.scopes[name] = nil
    for i=#scope.resources,1,-1 do
        local resource = scope.resources[i]
        local ok, err = pcall(resource.dispose, resource.id)
        if not ok then self:report(name, err) end
    end
    scope.resources = {}
end

function L:stop()
    local names = {}
    for name in pairs(self.scopes) do names[#names+1] = name end
    for _, name in ipairs(names) do self:close(name) end
end

function L:open(name)
    self:close(name)
    local scope = {active=true, resources={}}
    self.scopes[name] = scope
    function scope:guard(callback)
        return function(...)
            if not self.active then return end
            local ok, err = pcall(callback, ...)
            if not ok then L:report(name, err) end
        end
    end
    function scope:own(id, dispose)
        assert(id ~= nil and id ~= false and id ~= -1, "Nie utworzono zasobu: " .. name)
        local resource = {id=id, dispose=dispose}
        self.resources[#self.resources+1] = resource
        return resource
    end
    function scope:event(event, callback)
        return self:own(registerAnonymousEventHandler(event, self:guard(callback)), killAnonymousEventHandler).id
    end
    function scope:alias(pattern, callback)
        return self:own(tempAlias(pattern, self:guard(callback)), killAlias).id
    end
    function scope:timer(delay, callback)
        local resource
        local wrapped = self:guard(function()
            for i, item in ipairs(self.resources) do
                if item == resource then table.remove(self.resources, i); break end
            end
            callback()
        end)
        resource = self:own(tempTimer(delay, wrapped), killTimer)
        return resource.id
    end
    return scope
end

return L
