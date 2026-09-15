-- Read existing Mudlet maps; never rewrite coordinates, hashes or user data.
local C=chimera_vip
local M={index={},keys={},active=false,delay=(C.mapper and C.mapper.delay) or 2,timeout=10}
C.mapper=M
local directions={n="polnoc",ne="polnocny-wschod",e="wschod",se="poludniowy-wschod",
    s="poludnie",sw="poludniowy-zachod",w="zachod",nw="polnocny-zachod",up="gora",down="dol",
    u="gora",d="dol"}

local function integer(value)
    value=tonumber(value)
    return value and value>0 and value<9007199254740992 and value%1==0 and value or nil
end
local function normalize(value)
    if type(value)~="string" then return nil end
    local base,instance=value:lower():match("^([^#]+)#(%d+)$")
    base=base or value:lower()
    if #base~=16 or not base:match("^%x+$") then return nil end
    if instance then
        local n=integer(instance)
        if not n then return nil end
        return base.."#"..string.format("%.0f",n)
    end
    return base
end
function M:key(info)
    if type(info)~="table" then return nil end
    local base=normalize(info.id)
    if not base or base:find("#",1,true) then return nil end
    if info.instance==nil or tonumber(info.instance)==0 then return base end
    local instance=integer(info.instance)
    return instance and base.."#"..string.format("%.0f",instance) or nil
end
function M:log(message) cecho("\n<cyan>[VIP mapa]<reset> "..message.."\n") end
function M:stop(reason)
    local run=self.walk
    self.walk=nil
    C.lifecycle:close("mapper-walk")
    if run then run.result=reason or "stop"; self:log(run.result) end
end
function M:resolve(key)
    local id=key and self.index[key]
    if id==false then return nil,"sprzeczne przypisanie" end
    if not id then return nil,"brak przypisania" end
    return id
end
function M:reindex()
    self:stop("odswiezenie mapy")
    self.current=nil
    self.index={}; self.keys={}
    local rooms=getRooms()
    assert(type(rooms)=="table","Nie odczytano pokojow mapy")
    local conflicts={}
    for value in pairs(rooms) do
        local id=integer(value)
        if id then
            local hash=normalize(getRoomHashByID(id))
            local data=normalize(getRoomUserData(id,"chimera_id"))
            if hash and data and hash~=data then conflicts[hash]=true; conflicts[data]=true end
            local key=data or hash
            if key then
                if self.index[key] and self.index[key]~=id then conflicts[key]=true end
                self.index[key]=id
                self.keys[id]=key
            end
        end
    end
    for key in pairs(conflicts) do self.index[key]=false end
    self:update_position()
end
function M:update_position()
    local key=self:key(C.runtime:room())
    local id,reason=self:resolve(key)
    local old=self.current
    self.current=id; self.reason=reason
    if id and id~=old then centerview(id) end
    return key,id
end

function M:on_room()
    local key,id=self:update_position()
    local run=self.walk
    if not run then return end
    if C.protocol.epoch~=run.epoch or not id then self:stop("utrata lokalizacji"); return end
    if run.waiting and key==run.expected then
        run.waiting=false; run.at=key; run.position=id
        C.lifecycle:close("mapper-walk")
        if run.next>#run.steps then self:stop("cel osiagniety"); return end
        local scope=C.lifecycle:open("mapper-walk")
        scope:timer(self.delay,function() self:guard_step(run) end)
    elseif key~=run.at then self:stop("nieoczekiwana lokacja") end
end

function M:step(run)
    if self.walk~=run then return end
    local room=C.runtime:room()
    if not C.protocol.active or C.protocol.epoch~=run.epoch or self:key(room)~=run.at then
        self:stop("zmiana sesji lub lokacji"); return
    end
    local step=run.steps[run.next]
    local exits=room and room.exits
    local target=type(exits)=="table" and exits[step.command]
    if target==nil or (target~=0 and target~="0" and normalize(target)~=step.key
        and normalize(target)~=step.key:match("^[^#]+")) then
        self:stop("wyjscie GMCP nie zgadza sie z trasa"); return
    end
    run.expected=step.key; run.waiting=true; run.next=run.next+1
    local scope=C.lifecycle:open("mapper-walk")
    scope:timer(self.timeout,function() if self.walk==run then self:stop("timeout ruchu") end end)
    -- The room handler and timeout are armed before send can synchronously ACK.
    send(step.command,false)
end
function M:guard_step(run)
    local ok,err=pcall(self.step,self,run)
    if not ok then
        if self.walk==run then self:stop("blad chodzika") end
        C.lifecycle:report("mapper",err)
        return false,tostring(err)
    end
    return true
end

local function command(value)
    if type(value)~="string" or not value:match("%S") or value:find("[%c;]")
        or value:match("^%s*[/#]") then return nil end
    return directions[value:lower()] or value
end
function M:go(destination)
    if self.walk then return false,"Chodzik juz dziala; /stop" end
    if not self.active then return false,"Brak API mappera" end
    destination=integer(destination)
    local key,source=self:update_position()
    if not destination or not source then return false,"Brak poprawnego celu lub lokalizacji" end
    if source==destination then return false,"Jestes u celu" end
    if not getPath(source,destination) then return false,"Brak trasy" end
    if type(speedWalkPath)~="table" or type(speedWalkDir)~="table"
        or #speedWalkPath==0 or #speedWalkPath~=#speedWalkDir then return false,"Niepoprawna trasa" end
    local steps={}
    local previous=source
    for i=1,#speedWalkPath do
        local id=integer(speedWalkPath[i])
        local target=id and self.keys[id]
        local cmd=command(speedWalkDir[i])
        if not target or self:resolve(target)~=id or not cmd or id==previous then
            return false,"Trasa zawiera nieprzypisana lokacje lub nieobslugiwane polecenie"
        end
        steps[i]={key=target,command=cmd}; previous=id
    end
    if previous~=destination then return false,"Trasa nie prowadzi do celu" end
    local run={steps=steps,next=1,at=key,position=source,epoch=C.protocol.epoch,result="running"}
    self.walk=run
    local ok,err=self:guard_step(run)
    if not ok then return false,err end
    if run.result~="running" and run.result~="cel osiagniety" then return false,run.result end
    return true,run
end
function M:set_delay(value)
    value=tonumber(value)
    if not value or value~=value or value<0 or value>60 then return false,"Opoznienie: 0-60 sekund" end
    self.delay=value
    return true
end
function M:start()
    for _,name in ipairs({"getRooms","getRoomHashByID","getRoomUserData","getPath","centerview"}) do
        if type(_G[name])~="function" then self.reason="brak API: "..name; return false end
    end
    local scope=C.lifecycle:open("mapper")
    scope:own(true,function() M:stop("zatrzymanie VIP"); M.active=false; M.current=nil end)
    mudlet=mudlet or {}
    local registry=mudlet
    local previous=registry.mapper_script
    registry.mapper_script=true
    scope:own(true,function()
        if mudlet==registry and registry.mapper_script==true then registry.mapper_script=previous end
    end)
    -- Mudlet calls this public hook after selecting a destination on the map.
    -- Leave an unrelated mapper's existing hook alone.
    if doSpeedWalk==nil then
        local callback=scope:guard(function()
            local destination=type(speedWalkPath)=="table" and speedWalkPath[#speedWalkPath]
            local ok,err=M:go(destination); if not ok then M:log(err) end
        end)
        doSpeedWalk=callback
        scope:own(true,function() if doSpeedWalk==callback then doSpeedWalk=nil end end)
    end
    self.active=true
    self:reindex()
    scope:event("chimeraVipV2StateChanged",function(_,key) if key=="room" then M:on_room() end end)
    scope:event("chimeraVipV2SessionReset",function()
        M:stop("rozlaczenie"); M.current=nil; M.reason="brak lokalizacji po rozlaczeniu"
    end)
    scope:alias([[^/idz\s+(\d+)$]],function()
        local ok,err=M:go(matches[2]); if not ok then M:log(err) end
    end)
    scope:alias([[^/opoz\s+(\d+(?:\.\d+)?)$]],function()
        local ok,err=M:set_delay(matches[2]); M:log(ok and ("Opoznienie: "..M.delay.." s") or err)
    end)
    scope:alias([[^/stop$]],function() M:stop("stop") end)
    scope:alias([[^/cvip2 mapa(?: (odswiez))?$]],function()
        if matches[2]=="odswiez" then M:reindex() end
        if type(openMapWidget)=="function" then openMapWidget() end
        M:log(M.current and ("Lokacja mapy: "..M.current) or (M.reason or "brak lokalizacji"))
    end)
    return true
end
return M
