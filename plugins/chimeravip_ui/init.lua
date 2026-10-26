-- ChimeraVIP 5: public plugin entry point and event lifecycle.
-- Load siblings from this installed copy, without require's stale helper cache.
local source=assert(debug.getinfo(1,"S").source:match("^@(.+[/\\])"),"plugin path missing")
local function sibling(name) return dofile(source..name..".lua") end
local T=sibling("theme")
local modules={actions=sibling("actions"),footer=sibling("footer"),
    conditions=sibling("conditions"),layout=sibling("layout")}
local WINDOW,HEIGHT,clean,info,alias=T.WINDOW,T.HEIGHT,T.clean,T.info,T.alias

return {
    name="chimeravip_ui",
    title="Pastelowy HUD ChimeraVIP",
    section="vip_hud",
    description="Alternatywny HUD i okno Kondycje z powrotem do oficjalnego",
    deps={"gmcp","team","locations","status_bar","room_window","henchman_window","lamp"},
    settings={
        mode={type="enum",values={"vip","oficjalny"},default="vip",label="Interfejs",order=1},
        kondycje={type="boolean",default=true,label="VIP Kondycje",order=2},
        czcionka={type="number",default=7,min=6,max=24,label="Czcionka Kondycji (pt)",order=3},
        rozmiar={type="enum",values={"s","m","xl"},default="s",label="Rozmiar HUD",order=5},
        akcje={type="boolean",default=true,label="Plywajace akcje lokacji",order=4},
        pacholek_before={type="enum",values={"unknown","on","off"},default="unknown",hidden=true},
    },
    setup=function(ctx)
        local gmcp,team,locations=ctx:use("gmcp"),ctx:use("team"),ctx:use("locations")
        local vip=rawget(_G,"chimera_vip")
        if type(vip)~="table" then vip={}; _G.chimera_vip=vip end
        ctx.state.vip_generation=math.max(ctx.state.vip_generation or 0,
            vip and vip._ui_generation or 0)+1
        if vip then vip._ui_generation=ctx.state.vip_generation end
        local generation=ctx.state.vip_generation
        local S={active=false,built=false,opened=false,pending=false,widgets={},
            marks={members={},enemies={}},signature=nil,root=nil,cached_vitals=nil,
            floating=nil,floating_widgets={},specials={},action_count=0,exp_progress=nil}
        local schedule,footer
        local actions=modules.actions(ctx,S,T,gmcp,locations,
            function() return footer.resolve_exits() end,
            function() if schedule then schedule() end end)
        footer=modules.footer(ctx,S,T,gmcp,actions,generation)
        local conditions=modules.conditions(ctx,S,T)
        local layout=modules.layout(ctx,S,T)
        local open_window,official,restore=layout.open,layout.official,layout.restore
        local function render()
            S.pending=false
            if S.destroyed or not S.active then return end
            local ok,err=pcall(function()
                local v=team.view() or {self={},members={},enemies={},others={}}
                footer.draw(v)
                conditions.draw(v)
            end)
            if not ok then
                info("Blad rysowania: "..clean(err)..". Wracam do oficjalnego.")
                restore()
            end
        end
        schedule=function()
            if S.destroyed or not S.active or S.pending then return end
            S.pending=true
            ctx:timer(0.10,render)
        end
        local function activate()
            if S.destroyed then return false end
            if not footer.available() then
                info("Brak Geyser lub API okien. Pozostawiam oficjalny HUD.")
                official(true); layout.finish()
                return false
            end
            local ok,err=pcall(function() footer.build(); official(false); open_window() end)
            if not ok then
                info("Nie udalo sie utworzyc HUD: "..clean(err))
                restore(); official(true); layout.finish()
                return false
            end
            S.active=true
            S.root:show()
            setBorderBottom(T.profile(ctx.settings).height)
            S.signature=nil
            render()
            ctx:timer(0,function()
                if not S.destroyed then layout.finish(); schedule() end
            end)
            return S.active
        end
        local function switch(mode)
            if mode=="vip" then return activate() end
            restore()
            official(true)
            return true
        end
        local old_size=vip.ui.set_size
        local function select_size(size)
            if S.destroyed or not T.profiles[size] then return false end
            ctx:set("rozmiar",size)
            -- Explicitly reselecting a preset resets a manual font override.
            ctx:set("czcionka",T.profiles[size].font)
            if ctx.settings.mode~="vip" then ctx:set("mode","vip") end
            S.signature=nil
            schedule()
            info("Rozmiar "..size:upper().." | Kondycje "..T.profiles[size].font.." pt")
            return true
        end
        vip.ui.set_size=select_size
        ctx:command{"cvhud",args="[vip|oficjalny|status|ustawienia]",
            help="Przelacz HUD ChimeraVIP",fn=function(arg)
                local mode=tostring(arg or "status"):lower():gsub("^%s+",""):gsub("%s+$","")
                if mode=="vip" or mode=="oficjalny" then
                    ctx:set("mode",mode) -- config event invokes switch()
                elseif mode=="ustawienia" then
                    alias("/ustawienia vip_hud")
                else
                    info("Interfejs: "..(S.active and "VIP" or "oficjalny")
                        .." | /cvhud vip | /cvhud oficjalny")
                end
            end}

        ctx:on("chimera.team.changed",function()
            S.signature=nil
            schedule()
        end)
        ctx:on("chimera.progress",function(data)
            -- Some servers provide only capped percent; this is conditional.
            if type(data)=="table" and tonumber(data.percent) then
                S.exp_progress=tonumber(data.percent)
            end
            schedule()
        end)
        ctx:on("chimera.room.changed",schedule)
        ctx:on("chimera.locations.actions",schedule)
        ctx:on("chimera.char.vitals",function(vitals)
            if type(vitals)=="table" then S.cached_vitals=vitals end
            schedule()
        end)
        ctx:on("gmcp.Char.Vitals",function()
            local raw=rawget(_G,"gmcp")
            local values=type(raw)=="table" and raw.Char and raw.Char.Vitals
            if type(values)=="table" then S.cached_vitals=values end
            schedule()
        end)
        ctx:on("sysWindowResizeEvent",schedule)
        ctx:on("chimera.config.changed",function(module_name,key,value)
            if module_name=="chimeravip_ui" then
                if key=="mode" then switch(value)
                elseif key=="rozmiar" then
                    ctx:set("czcionka",T.profile(ctx.settings).font)
                    S.signature=nil
                    schedule()
                elseif key=="czcionka" then
                    if S.opened and type(setFontSize)=="function" then
                        setFontSize(WINDOW,tonumber(value) or 7)
                    end
                    S.signature=nil
                    schedule()
                elseif key=="kondycje" then
                    if value and S.active then open_window()
                    elseif S.opened and type(hideWindow)=="function" then
                        hideWindow(WINDOW)
                    end
                    S.signature=nil
                    schedule()
                else schedule() end
            end
        end)
        ctx:on("sysExitEvent",function()
            if S.opened and type(saveWindowLayout)=="function" then saveWindowLayout() end
        end)
        ctx:timer(1.5,schedule,true)
        ctx:cleanup(function()
            S.destroyed=true
            if vip.ui.set_size==select_size then vip.ui.set_size=old_size end
            actions.cleanup()
            layout.dispose()
            if S.root and type(S.root.delete)=="function" then
                pcall(function() S.root:delete() end)
            end
            if S.floating and type(S.floating.delete)=="function" then
                pcall(function() S.floating:delete() end)
            end
        end)
        -- Loader start_all is synchronous. The next event-loop turn runs
        -- after dependencies/ready, and also works for single-plugin reloads.
        ctx:timer(0,function()
            if S.destroyed then return end
            if ctx.settings.mode=="vip" then activate()
            else official(true); layout.finish() end
        end)
        return {
            active=function() return S.active end,
            targets=function() return S.marks end,
        }
    end,
}
