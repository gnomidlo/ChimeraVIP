-- Reuse VIP modules in a scoped Lua 5.1 environment. No upstream runtime.
local C=chimera_vip
local F={active=false,loaded={},errors={}}
C.features=F
F.files={
    'src/core/settings.lua',
    'src/features/combat_colors.lua','src/features/defense_tracker.lua',
    'src/integrations/defense_combat.lua','src/features/auto_support.lua',
    'src/features/xp_tracker.lua','src/features/xp_kill_card_view.lua',
    'src/features/stats.lua','src/features/stats_compact_view.lua',
    'src/features/report_actions.lua','src/features/characters.lua',
    'src/features/settings_bindings.lua','src/features/characters_delete_ui.lua',
    'src/features/containers.lua','src/features/skills_view.lua',
    'src/features/retainer_progress.lua','src/features/equipment_view.lua','src/features/weapon_info.lua',
}
local native={timer=tempTimer,killTimer=killTimer,alias=tempAlias,killAlias=killAlias,
    trigger=tempRegexTrigger,ansi=tempAnsiColorTrigger,killTrigger=killTrigger,
    event=registerAnonymousEventHandler,killEvent=killAnonymousEventHandler}
local event_keys={['gmcp.Char.Name']='name',['gmcp.Char.Vitals']='vitals',['gmcp.Room.Info']='room',
    ['gmcp.Chimera.Group.State']='group',['gmcp.Chimera.Group']='group',
    ['gmcp.Chimera.Combat.State']='combat',['gmcp.Chimera.Combat']='combat',
    ['gmcp.Chimera.Room.Entities']='entities'}

function F:snapshot()
    -- No legacy objects cache or uncorrelated Combat.Kill enrichment.
    return {Char={Name=C.protocol:get('name'),Vitals=C.runtime:vitals()},
        Room={Info=C.runtime:room()},Chimera={Group={State=C.runtime:group()},
        Room={Entities=C.runtime:entities()},Combat={State=C.runtime:combat()}}}
end
function F:fail(message)
    self.errors[#self.errors+1]=tostring(message)
    error(message)
end
function F:release(id,dispose)
    for i,r in ipairs(self.scope.resources) do
        if r.id==id and r.kind==dispose then
            table.remove(self.scope.resources,i); return r.dispose(id)
        end
    end
    -- Modules may cancel an already fired timer; never kill unowned resources.
    return false
end
function F:callback(value)
    if type(value)=='string' then value=assert(loadstring(value)); setfenv(value,self.env) end
    assert(type(value)=='function','Callback must be Lua code or a function')
    return self.scope:guard(value)
end
function F:register(create,dispose,...)
    local args={...}
    local callback=args[#args]
    local alive=true
    args[#args]=function(...)
        if not alive then return end
        if dispose==native.killTimer then alive=false end
        return callback(...)
    end
    local ok,id=pcall(create,unpack(args))
    if not ok or id==nil or id==false or id==-1 then self:fail('Rejestracja zasobu: '..tostring(id)) end
    local resource=self.scope:own(id,function(value) alive=false; return dispose(value) end)
    resource.kind=dispose
    return id
end
function F:event(event,callback)
    callback=self:callback(callback)
    local key=event_keys[event]
    if key then
        return self:register(native.event,native.killEvent,'chimeraVipV2StateChanged',function(_,received)
            if received==key then callback(event) end
        end)
    end
    if event=='sysDisconnectionEvent' then
        return self:register(native.event,native.killEvent,'chimeraVipV2SessionReset',callback)
    end
    return self:register(native.event,native.killEvent,event,callback)
end

function F:flush()
    if C.stats and C.stats.save_timer then
        C.stats:save_data(); self.env.killTimer(C.stats.save_timer); C.stats.save_timer=nil
    end
end
function F:set_support(enabled)
    if not self.active then return false end
    if not C.settings:set('automation.auto_support',enabled) then return false end
    C.auto_support:set_enabled(enabled)
    return true
end
function F:reset()
    self:flush()
    for i=#self.scope.resources,1,-1 do
        local r=self.scope.resources[i]
        if r.kind==native.killTimer then table.remove(self.scope.resources,i); r.dispose(r.id) end
    end
    for _,name in ipairs({'weapon_info','characters','retainer_progress','skills_view'}) do
        local m=C[name]
        if m then
            for _,field in ipairs({'capture','capture_timer','summary_timer','roster','roster_timer',
                'skill_capture','skill_timer','job_capture','job_timer'}) do m[field]=nil end
        end
    end
    if C.stats then C.stats:reset_current(); C.stats.pending_xp=0 end
    if C.xp_tracker then C.xp_tracker.pending_rewards={} end
    if C.auto_support then C.auto_support:cancel_confirmation(); C.auto_support.cache.last_send=0 end
end

function F:start()
    for _,name in ipairs({'getMudletHomeDir','tempRegexTrigger','tempAnsiColorTrigger','hecho'}) do
        if type(_G[name])~='function' then self.unavailable=name; return false end
    end
    if type(table.save)~='function' or type(table.load)~='function' then self.unavailable='table.save/load'; return false end
    self.scope=C.lifecycle:open('features')
    local scope=self.scope
    scope:own(true,function() F.active=false end)
    local env={chimera_vip=C,chimera_overlay=C,disableTrigger=false,enableTrigger=false}
    self.env=env; env._G=env
    setmetatable(env,{__index=function(_,key)
        if key=='gmcp' then return F:snapshot() end
        return _G[key]
    end})
    env.tempAlias=function(pattern,fn) return F:register(native.alias,native.killAlias,pattern,F:callback(fn)) end
    env.tempRegexTrigger=function(pattern,fn) return F:register(native.trigger,native.killTrigger,pattern,F:callback(fn)) end
    env.tempAnsiColorTrigger=function(fg,bg,fn) return F:register(native.ansi,native.killTrigger,fg,bg,F:callback(fn)) end
    env.tempTimer=function(delay,fn)
        local id
        id=F:register(native.timer,native.killTimer,delay,F:callback(function()
            for i,r in ipairs(scope.resources) do
                if r.id==id and r.kind==native.killTimer then table.remove(scope.resources,i); break end
            end
            if type(fn)=='string' then F:callback(fn)() else fn() end
        end))
        return id
    end
    env.killTimer=function(id) return F:release(id,native.killTimer) end
    env.killAlias=function(id) return F:release(id,native.killAlias) end
    env.killTrigger=function(id) return F:release(id,native.killTrigger) end
    env.registerAnonymousEventHandler=function(event,fn) return F:event(event,fn) end
    env.killAnonymousEventHandler=function(id) return F:release(id,native.killEvent) end
    env.echoLink=function(text,fn,hint,format) return echoLink(text,F:callback(fn),hint,format) end

    local home=getMudletHomeDir()
    local data_home=home..'/ChimeraVIP-v2'
    self.data_home=data_home
    env.getMudletHomeDir=function() return data_home end
    local exists=C.util.file_exists
    local function source(path)
        if exists(path) then return path end
        if path:sub(1,#data_home+1)==data_home..'/' then return home..path:sub(#data_home+1) end
        return path
    end
    env.table=setmetatable({},{__index=table})
    env.io=setmetatable({exists=function(path) return exists(source(path)) end},{__index=io})
    env.table.load=function(path,destination)
        local ok,result,err=pcall(table.load,source(path),destination)
        if not ok or result==false or err then F:fail('Odczyt danych: '..tostring(err or result)) end
        return result
    end
    env.table.save=function(path,data)
        assert(path:sub(1,#data_home+1)==data_home..'/','Zapis poza danymi VIP 2.0')
        -- Fail closed after a read error, even when a legacy module caught it.
        if #F.errors>0 then error('Zapis wstrzymany po bledzie danych') end
        local temporary=path..'.tmp'
        local ok,result,err=pcall(table.save,temporary,data)
        if not ok or result==false or err then F:fail('Zapis danych: '..tostring(err or result)) end
        local renamed,rename_error=os.rename(temporary,path)
        -- Windows cannot rename over an existing file. Keep a recoverable backup.
        if not renamed and exists(path) then
            local backup=path..'.bak'
            if exists(backup) then
                local removed,remove_error=os.remove(backup)
                if not removed then F:fail('Usuniecie kopii danych: '..tostring(remove_error)) end
            end
            local moved,move_error=os.rename(path,backup)
            if not moved then F:fail('Kopia danych: '..tostring(move_error)) end
            renamed,rename_error=os.rename(temporary,path)
            if not renamed then
                local restored,restore_error=os.rename(backup,path)
                if not restored then F:fail('Przywroc dane z '..backup..': '..tostring(restore_error)) end
            end
        end
        if not renamed then F:fail('Podmiana danych: '..tostring(rename_error)) end
        return true
    end
    local function load(path)
        local chunk=assert(loadfile(C.root_dir..'/'..path))
        setfenv(chunk,env); chunk()
    end
    -- Reload helpers into the same environment, so their registrations are owned.
    load('src/core/util.lua')
    C.util.file_exists=function(path) return exists(source(path)) end
    for _,path in ipairs(self.files) do load(path); self.loaded[#self.loaded+1]=path end
    if #self.errors>0 then error(table.concat(self.errors,'\n')) end
    local S=C.settings
    S:register_module('combat_colors',{title='Kolory walki',default=true})
    C.auto_support:set_enabled(S:get('automation.auto_support',true),true)
    env.tempAlias([[^/wsparcie(?: (on|off))?$]],function()
        local enabled=matches[2]=='on' or (matches[2]~='off' and not C.auto_support.enabled)
        F:set_support(enabled)
    end)
    env.tempAlias([[^/kolory (on|off)$]],function() S:set_module_enabled('combat_colors',matches[2]=='on') end)
    env.tempAlias([[^/cvip$]],function()
        cecho('\n<cyan>ChimeraVIP 2.0<reset> /xp, /def, /cechy, /postacie, /bron pomoc, /wsparcie on|off, /kolory on|off\n'
            ..'Mapper: /idz ID, /opoz SEKUNDY, /stop. Diagnostyka: /cvip2.\n'
            ..'Lampa, zbieranie i pozostale akcje oficjalnej stopki: niedostepne.\n')
    end)
    scope:event('chimeraVipV2SessionReset',function() F:reset() end)
    self.active=true
    raiseEvent('chimeraVipV2FeaturesReady')
    return true
end
return F
