-- ChimeraVIP 5: native dock ownership, separate from Geyser rendering.
return function(ctx,S,T)
    local WINDOW=T.WINDOW
    local function hide(name)
        if type(hideWindow)=="function" then hideWindow(name) end
    end
    local function official(on)
        -- Only an explicit switch/fallback restores official controls. Teardown
        -- must not persist `okno=true` and spawn extra docks during restart.
        if not on and ctx.settings.pacholek_before=="unknown" then
            local config=ctx.app and ctx.app.config
            local before=config and config:get("henchman_window","okno")
            if type(before)=="boolean" then
                ctx:set("pacholek_before",before and "on" or "off")
            end
        end
        T.alias("/pasek pasek "..(on and "tak" or "nie"))
        T.alias("/ustaw kondycje okno "..(on and "tak" or "nie"))
        if not on then
            T.alias("/ustaw okno_pacholka okno nie")
            hide("chimera_lokacja")
            hide("chimera_pacholek")
        elseif ctx.settings.pacholek_before~="unknown" and ctx.settings.pacholek_before then
            T.alias("/ustaw okno_pacholka okno "..
                (ctx.settings.pacholek_before=="on" and "tak" or "nie"))
            ctx:set("pacholek_before","unknown")
        end
    end
    local function open()
        if not ctx.settings.kondycje then return end
        if not S.opened then
            local exists=type(windowType)=="function" and windowType(WINDOW)=="userwindow"
            -- Older Mudlet lacks windowType; size lookup also detects an
            -- existing userwindow without reopening/re-docking it.
            if not exists and type(windowType)~="function" and type(getUserWindowSize)=="function" then
                local ok,width=pcall(getUserWindowSize,WINDOW)
                exists=ok and type(width)=="number"
            end
            -- Mudlet creates new docks on the right before restoring layout.
            -- An explicit area is applied AFTER restore and would discard the
            -- saved docking/floating placement on every fresh profile start.
            if not exists then openUserWindow(WINDOW,true,true) end
            if type(setUserWindowTitle)=="function" then
                setUserWindowTitle(WINDOW,"Kondycje — ChimeraVIP")
            end
            -- resizeWindow/moveWindow would float a dock. A minimum on this
            -- dock alone repairs collapsed layouts without moving the mapper
            -- or replacing the player's larger dimensions or docking area.
            if type(setUserWindowStyleSheet)=="function" then
                local css=""
                if type(getUserWindowStyleSheet)=="function" then
                    css=getUserWindowStyleSheet(WINDOW) or ""
                end
                if not css:find("/* cvip minimum */",1,true) then
                    setUserWindowStyleSheet(WINDOW,css..
                        "\n/* cvip minimum */ QDockWidget { min-width: 260px; min-height: 160px; }")
                end
            end
            S.opened=true
        end
        if type(showWindow)=="function" then showWindow(WINDOW) end
        if type(setFontSize)=="function" then setFontSize(WINDOW,ctx.settings.czcionka or 7) end
    end
    local function restore()
        if S.root then S.root:hide() end
        if S.floating then S.floating:hide() end
        if S.opened then hide(WINDOW) end
        if type(setBorderBottom)=="function" then setBorderBottom(0) end
        if S.active then official(true) end
        S.active=false
        if rawget(_G,"chimera_vip_ui_targets")==S.marks then
            _G.chimera_vip_ui_targets=nil
        end
    end
    local function reconcile()
        if S.active then
            official(false)
            if ctx.settings.kondycje then open() else hide(WINDOW) end
        else
            hide(WINDOW)
        end
    end
    local function finish()
        local vip=rawget(_G,"chimera_vip")
        if vip and vip._pending_ui_layout then
            vip._pending_ui_layout=nil
            if type(loadWindowLayout)=="function" then
                local ok,result=pcall(loadWindowLayout)
                if not ok or result==false then
                    T.info("Nie udalo sie odtworzyc ukladu okien: "..tostring(result))
                end
            end
        end
        -- Qt's saved layout includes visibility too. Reapply mode after load.
        reconcile()
    end
    local function dispose()
        local vip=rawget(_G,"chimera_vip")
        if S.active and vip and not vip._pending_ui_layout and type(saveWindowLayout)=="function" then
            local ok,result=pcall(saveWindowLayout)
            if ok and result~=false then vip._pending_ui_layout=true end
        end
        -- Preserve official settings across stop_all()/start_all().
        S.active=false
        restore()
    end
    return {open=open,official=official,restore=restore,reconcile=reconcile,
        finish=finish,dispose=dispose}
end
