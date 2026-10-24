-- ChimeraVIP v5 bridge: official Chimera 5 documented plugin API.
return {
    name = "chimeravip_bridge",
    deps = { "gmcp", "team" },
    setup = function(ctx)
        local gmcp_api = ctx:use("gmcp")
        local team = ctx:use("team")
        local bridge = { api = 5 }
        function bridge.team_view() return team.view() end
        function bridge.team_resolve(mark) return team.resolve(mark) end
        function bridge.gmcp_room() return gmcp_api.room() end
        function bridge.gmcp_group() return gmcp_api.group() end
        function bridge.gmcp_combat() return gmcp_api.combat() end
        function bridge.gmcp_vitals() return gmcp_api.vitals() end
        function bridge.gmcp_entities() return gmcp_api.entities() end

        local function notify(kind, value)
            if type(raiseEvent) == "function" then
                raiseEvent("chimeraVipUpstream" .. kind, value)
            end
        end

        -- Documented, stable events in Chimera 5 docs/API.md.
        ctx:on("chimera.room.changed", function(data) notify("Room", data) end)
        ctx:on("chimera.killed", function(data) notify("Killed", data) end)
        ctx:on("chimera.progress", function(data) notify("Progress", data) end)

        -- Native Mudlet GMCP events, delayed to allow official team refresh.
        local pending = false
        local function refresh_team()
            if pending then return end
            pending = true
            ctx:timer(0, function()
                pending = false
                if _G.chimera_vip_bridge == bridge then
                    notify("Team", team.view())
                end
            end)
        end
        for _, event in ipairs({
            "gmcp.Chimera.Group.State", "gmcp.Chimera.Combat.State",
            "gmcp.Chimera.Room.Entities", "gmcp.Char.Vitals",
        }) do
            ctx:on(event, refresh_team)
        end
        _G.chimera_vip_bridge = bridge
        ctx:cleanup(function()
            if _G.chimera_vip_bridge == bridge then
                _G.chimera_vip_bridge = nil
                notify("Ready", false)
            end
        end)
        notify("Ready", true)
        return { connected = function() return _G.chimera_vip_bridge == bridge end }
    end,
}
