-- Standalone footer: native Mudlet labels, no upstream windows or GMCP cache.
local C = chimera_vip
local U = C.util
local UI = {active=false, labels={}, cache={}, height=100}
C.ui = UI
local required = {"createLabel", "deleteLabel", "moveWindow", "resizeWindow",
    "setLabelStyleSheet", "setLabelClickCallback", "echo", "getMainWindowSize",
    "getBorderBottom", "setBorderBottom"}
local directions = {
    {"polnocny-zachod", "NW"}, {"polnoc", "N"}, {"polnocny-wschod", "NE"},
    {"zachod", "W"}, {"wschod", "E"}, {"poludniowy-zachod", "SW"},
    {"poludnie", "S"}, {"poludniowy-wschod", "SE"}, {"gora", "U"}, {"dol", "D"},
}
local metric_defs = {
    {"hp", "KOND", "rose"}, {"moves", "SILY", "mint"}, {"mana", "MANA", "blue"},
    {"hunger", "SYTOSC", "peach"}, {"thirst", "WODA", "lavender"},
    {"encumbrance", "OBC", "yellow"}, {"progress", "EXP", "lavender"},
}

local function percent(value)
    if type(value)~="number" or value~=value or value==math.huge or value==-math.huge then return "—" end
    return tostring(math.floor(U.clamp(value, 0, 100)+0.5)) .. "%"
end

local function safe_command(command)
    return type(command)=="string" and command:match("%S")
        and not command:find("[%c;]") and not command:match("^%s*[/#]")
end

function UI:label(key)
    local name = "chimera_vip2.footer." .. key
    assert(createLabel(name, 0, 0, 1, 1, true), "Nie utworzono etykiety " .. name)
    self.scope:own(name, deleteLabel)
    self.labels[key] = name
    local P=U.palette()
    setLabelStyleSheet(name, "QLabel { background-color:"..P.background.."; color:"..P.text
        .."; border:0px; padding:2px; font-size:12px; }")
    return name
end

function UI:text(key, value)
    if self.cache[key]==value then return end
    echo(self.labels[key], value)
    self.cache[key]=value
end

function UI:place(key, x, y, width, height)
    moveWindow(self.labels[key], x, y)
    resizeWindow(self.labels[key], math.max(1,width), math.max(1,height))
end

function UI:layout()
    local w,h=getMainWindowSize()
    if type(w)~="number" or type(h)~="number" or w<1 or h<1 then return end
    local y=math.max(0,h-self.height)
    self:place("background",0,y,w,self.height)
    for i,def in ipairs(metric_defs) do
        local columns=i<=3 and 3 or 4
        local column=i<=3 and i-1 or i-4
        self:place(def[1],math.floor(column*w/columns),y+(i<=3 and 0 or 24),math.floor(w/columns),24)
    end
    self:place("room",0,y+48,w,24)
    for i=1,12 do
        self:place("exit"..i,math.floor((i-1)*w/12),y+72,math.floor(w/12),28)
    end
end

function UI:render()
    if not self.active then return end
    local P=U.palette()
    local vitals=C.runtime:vitals() or {}
    for _,def in ipairs(metric_defs) do
        self:text(def[1], "<font color='"..P.text_muted.."'>"..def[2]
            .."</font> <font color='"..P[def[3]].."'>"..percent(vitals[def[1]]).."</font>")
    end
    local room=C.runtime:room()
    self:text("room", room and U.escape_html(room.name or room.id)
        or (C.protocol.active and "Oczekiwanie na dane lokacji" or "Brak polaczenia GMCP"))
    local exits=room and type(room.exits)=="table" and room.exits or {}
    local choices, normal={},{}
    for i,def in ipairs(directions) do
        choices[i]={command=def[1],label=def[2]}; normal[def[1]]=true
    end
    local specials={}
    for command in pairs(exits) do
        if safe_command(command) and not normal[command] then specials[#specials+1]=command end
    end
    table.sort(specials)
    for i=1,2 do choices[10+i]={command=specials[i], label=specials[i]} end
    local epoch,room_key=C.protocol.epoch,C.runtime:room_key()
    for i,choice in ipairs(choices) do
        local command=choice.command
        local target=command and exits[command]
        local enabled=target~=nil and safe_command(command)
        self:text("exit"..i,enabled and ("<center><font color='"..P.lavender.."'>"
            ..U.escape_html(choice.label).."</font></center>") or "")
        setLabelClickCallback(self.labels["exit"..i],self.scope:guard(function()
            if not enabled or C.protocol.epoch~=epoch or C.runtime:room_key()~=room_key then return end
            local current=C.runtime:room()
            if not current or type(current.exits)~="table" or current.exits[command]~=target then return end
            send(command,false)
        end))
    end
end

function UI:schedule()
    if self.pending then return end
    self.pending=true
    self.scope:timer(0,function()
        self.pending=false
        self:layout()
        self:render()
    end)
end

function UI:start()
    for _,name in ipairs(required) do
        if type(_G[name])~="function" then self.unavailable=name; return false end
    end
    local scope=C.lifecycle:open("ui")
    self.scope=scope
    local old_border=getBorderBottom()
    assert(type(old_border)=="number", "Brak odczytu marginesu okna")
    self.reserved=math.max(old_border,self.height)
    scope:own(old_border,function(previous)
        -- Respect another package changing the margin while VIP is active.
        if getBorderBottom()==UI.reserved then setBorderBottom(previous) end
    end)
    scope:own(true,function() UI.active=false; UI.pending=false; UI.labels={}; UI.cache={} end)
    setBorderBottom(self.reserved)
    self:label("background")
    for _,def in ipairs(metric_defs) do self:label(def[1]) end
    self:label("room")
    for i=1,12 do self:label("exit"..i) end
    self.active=true
    scope:event("chimeraVipV2StateChanged",function(_,key)
        if key=="room" or key=="vitals" then UI:schedule() end
    end)
    scope:event("chimeraVipV2SessionReset",function() UI:render() end)
    scope:event("sysWindowResizeEvent",function() UI:schedule() end)
    self:layout()
    self:render()
    return true
end

return UI
