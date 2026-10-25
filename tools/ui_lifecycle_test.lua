-- Native Qt dock contract + Chimera 5.0.1 stop/start ordering, Lua 5.1.
-- CHIMERA501_SOURCE optionally runs the two original window modules from
-- the audited ZIP instead of the small contract doubles below.
local source=os.getenv("CHIMERA501_SOURCE")
local windows,opens,saved,loads={}, {}, nil,0
local widgets,timers,contexts,aliases={}, {}, {}, {}
local config={values={henchman_window={okno=true},room_window={okno=true},status_bar={pasek=true}}}
local W="chimeravip_kondycje"
local function copy(t)
    if type(t)~="table" then return t end
    local r={} for k,v in pairs(t) do r[k]=copy(v) end return r
end
local function emit(event,...)
    for _,ctx in ipairs(contexts) do
        if not ctx.dead and ctx.events[event] then ctx.events[event](...) end
    end
end
function config:get(name,key) return self.values[name] and self.values[name][key] end
function config:set(name,key,value)
    self.values[name]=self.values[name] or {}
    self.values[name][key]=value
    emit("chimera.config.changed",name,key,value)
end
local function flush()
    local count=0
    while #timers>0 do
        count=count+1; assert(count<100,"timer loop")
        local item=table.remove(timers,1)
        if not item.ctx.dead then item.fn() end
    end
end
function windowType(n) return windows[n] and "userwindow" end
function openUserWindow(n,restore,autoDock,area)
    opens[n]=(opens[n] or 0)+1
    -- Reopening an existing window re-docks it; deliberately model the
    -- dangerous behaviour that a boolean visible/hidden stub would miss.
    windows[n]={x=900,y=400,width=340,height=25,dock=area,visible=true}
    if restore and saved and saved[n] then windows[n]=copy(saved[n]) end
end
function showWindow(n) if windows[n] then windows[n].visible=true end end
function hideWindow(n) if windows[n] then windows[n].visible=false end end
function getUserWindowSize(n)
    local w=windows[n]; if w then return w.width,w.height end
end
function setUserWindowStyleSheet(n,css)
    local w=assert(windows[n]); w.css=css
    -- Qt respects stylesheet minima on restoreState too.
    w.width=math.max(w.width,260); w.height=math.max(w.height,160)
end
function getUserWindowStyleSheet(n) return windows[n].css end
function saveWindowLayout() saved=copy(windows); return true end
function loadWindowLayout()
    loads=loads+1
    for n,w in pairs(saved or {}) do
        local css=windows[n] and windows[n].css
        windows[n]=copy(w)
        if css then setUserWindowStyleSheet(n,css) end
    end
end
function moveWindow() error("moving a native dock detaches it") end
function resizeWindow() error("resizing a native dock detaches it") end
function setBorderBottom(n) _G.border=n end
function setUserWindowTitle() end
function setFontSize() end
function getMainWindowSize() return 1200,800 end
function getColumnCount() return 72 end
function clearWindow() end
function echo() end
function cecho() end
function cechoLink() end
function echoLink() end
function setFgColor() end
function setBgColor() end
function resetFormat() end
function expandAlias(command)
    aliases[#aliases+1]=command
    local section,key,value=command:match("^/ustaw (%S+) (%S+) (%S+)$")
    if section then
        local module=({kondycje="room_window",okno_pacholka="henchman_window"})[section]
        if module then config:set(module,key,value=="tak") end
    elseif command:match("^/pasek pasek") then
        config:set("status_bar","pasek",command:match("tak$")~=nil)
    end
end
local function element(props,parent)
    assert(not widgets[props.name],"Geyser name collision: "..props.name)
    local w={name=props.name,children={},parent=parent}
    widgets[w.name]=w
    if parent then parent.children[#parent.children+1]=w end
    for _,method in ipairs({"setStyleSheet","setClickCallback","setToolTip","move","resize","echo"}) do
        w[method]=function() end
    end
    function w:show() self.hidden=false end
    function w:hide() self.hidden=true end
    function w:delete()
        for _,child in ipairs(self.children) do child:delete() end
        widgets[self.name]=nil
    end
    return w
end
Geyser={Container={new=function(_,p,parent) return element(p,parent) end},
    Label={new=function(_,p,parent) assert(parent);return element(p,parent) end}}
local deps={
    gmcp={room=function() return {} end,vitals=function() return {} end,
        group=function() return {members={}} end,entities=function() return {entities={}} end},
    team={view=function() return {self={},members={},enemies={},others={}} end},
    locations={room_actions=function() return {} end},
    status_bar={model=function() return {} end},lamp={state=function() return {} end},
    henchmen={names=function() return {} end},
}
local function context(spec)
    local settings=config.values[spec.name] or {}; config.values[spec.name]=settings
    for key,field in pairs(spec.settings or {}) do if settings[key]==nil then settings[key]=field.default end end
    local ctx={name=spec.name,state={},events={},settings=settings,app={config=config},commands={}}
    function ctx:on(event,fn) self.events[event]=fn end
    function ctx:timer(_,fn,repeating) if not repeating then timers[#timers+1]={ctx=self,fn=fn} end end
    function ctx:use(name) return deps[name] end
    function ctx:set(k,v) config:set(self.name,k,v) end
    function ctx:command(cmd) self.commands[cmd[1]]=cmd.fn end
    function ctx:cleanup(fn) self.clean=fn end
    function ctx:send() end
    contexts[#contexts+1]=ctx
    return ctx
end
local function native_spec(name,window)
    -- Official modules render synchronously in setup; persist settings but
    -- have no cleanup that hides their native userwindows.
    return {name=name,settings={okno={default=true}},setup=function(ctx)
        local opened=false
        local function render()
            if not ctx.settings.okno then return end
            if not opened and not windowType(window) then openUserWindow(window,true,true,"right") end
            showWindow(window); opened=true
        end
        ctx:on("chimera.config.changed",function(module,key,value)
            if module==name and key=="okno" then
                if value then render() elseif opened then hideWindow(window) end
            end
        end)
        render()
    end}
end
local function start_native()
    for _,entry in ipairs({{"room_window","chimera_lokacja"},{"henchman_window","chimera_pacholek"}}) do
        local spec
        if source then
            package.path=source.."/src/?.lua;"..package.path
            spec=dofile(source.."/src/chimera/ui/"..entry[1]..".lua")
        else spec=native_spec(entry[1],entry[2]) end
        spec.setup(context(spec))
    end
end
local function start()
    start_native()
    local spec=dofile("plugins/chimeravip_ui/init.lua")
    local ctx=context(spec)
    local api=spec.setup(ctx)
    flush(); assert(api.active(),"VIP failed to activate")
    return ctx,api
end
local function stop(ctx)
    ctx.clean()
    for _,c in ipairs(contexts) do c.dead=true end
end
chimera_vip={}
windows.mapper={x=900,y=0,width=340,height=400,dock="right",visible=true}
windows[W]={x=900,y=400,width=340,height=280,dock="right",visible=true}
local mapper=copy(windows.mapper)
local ctx,api=start()
assert(not opens[W],"existing VIP window was re-docked")
assert(not windows.chimera_pacholek.visible and not config:get("henchman_window","okno"))
assert(config:get("chimeravip_ui","pacholek_before")=="on")
local widget_count=0 for _ in pairs(widgets) do widget_count=widget_count+1 end
for i=1,3 do
    -- A resize is deliberately NOT saved by the user before restart.
    windows[W].width=360+i*10; windows[W].height=280+i*15
    windows[W].dock=i==2 and "floating" or "left"
    local expected=copy(windows[W])
    local oldtimer=timers[1]
    local alias_count=#aliases
    stop(ctx)
    assert(#aliases==alias_count,"cleanup enabled official windows")
    assert(next(widgets)==nil,"Geyser objects leaked on cleanup")
    ctx,api=start()
    assert(loads==i,"layout must restore exactly once per restart")
    for _,key in ipairs({"x","y","width","height","dock"}) do
        assert(windows[W][key]==expected[key],"VIP geometry lost: "..key)
        assert(windows.mapper[key]==mapper[key],"mapper changed: "..key)
    end
    assert(not windows.chimera_pacholek.visible,"henchman resurrected")
    assert(opens[W]==nil,"restart reopened existing dock")
    local count=0 for _ in pairs(widgets) do count=count+1 end
    assert(count==widget_count,"Geyser objects duplicated")
end
-- 0.179 migration: its old cleanup made official docks visible AFTER save.
saveWindowLayout(); chimera_vip._pending_ui_layout=true
config:set("room_window","okno",true)
config:set("henchman_window","okno",true)
windows[W].height=25
stop(ctx); ctx,api=start()
assert(windows[W].height==325 and not windows.chimera_pacholek.visible)
-- A previously corrupt saved layout is repaired using minima, without
-- moveWindow/resizeWindow or resetting dock position / mapper geometry.
windows[W].height=20; saveWindowLayout()
stop(ctx); ctx,api=start()
assert(windows[W].height>=160 and windows[W].dock=="left")
assert(windows.mapper.height==400)
-- Explicit switch restores the pre-VIP henchman preference; repeated restart
-- must not replace that preference with the suppressed false value.
ctx.commands.cvhud("oficjalny")
assert(windows.chimera_pacholek.visible and not windows[W].visible)
assert(config:get("henchman_window","okno"))
config:set("henchman_window","okno",false)
ctx.commands.cvhud("vip"); flush()
ctx.commands.cvhud("oficjalny")
assert(not windows.chimera_pacholek.visible,"explicit hidden preference lost")
ctx:set("kondycje",false); ctx:set("kondycje",true)
assert(not windows[W].visible,"setting toggle must not open VIP in official mode")
ctx.commands.cvhud("vip"); flush()
ctx:set("kondycje",false)
stop(ctx); ctx,api=start()
assert(not windows[W].visible,"disabled VIP window resurrected on restart")
ctx:set("kondycje",true)
-- Queued startup/render callbacks from a disposed instance cannot revive it.
stop(ctx)
local spec=dofile("plugins/chimeravip_ui/init.lua")
local abandoned=context(spec); local dead_api=spec.setup(abandoned)
local stale=timers[#timers].fn
abandoned.clean(); abandoned.dead=true; stale(); flush()
assert(not dead_api.active() and next(widgets)==nil)
print("PASS native layout lifecycle: repeated restart, docking, dimensions, mapper, henchman, stale callbacks"..
    (source and " (original Chimera 5.0.1 window sources)" or " (contract doubles)"))
