chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local root = chimera_vip.root_dir or (getMudletHomeDir() .. "/ChimeraVIP")
chimera_vip.root_dir = root

chimera_vip.load_errors = {}
chimera_vip.module_status = {}

local function load(rel)
    local path = root .. "/" .. rel
    local ok, err = pcall(dofile, path)
    if not ok then
        cecho("\n<orange>[ChimeraVIP]<reset> Blad ladowania " .. rel .. ": " .. tostring(err) .. "\n")
        chimera_vip.load_errors[#chimera_vip.load_errors+1] = {path=rel, error=tostring(err)}
        chimera_vip.module_status[rel] = "error"
        return false
    end
    chimera_vip.module_status[rel] = "loaded"
    return true
end

load("src/core/util.lua")
load("src/integrations/runtime.lua")
load("src/core/bootstrap.lua")
load("src/integrations/chimera5.lua")
load("src/core/settings.lua")
load("src/core/safety.lua")
load("src/core/help.lua")
load("src/features/context_action.lua")
-- On Chimera 5 the new UI is a real upstream plugin; old scripts.ui widgets
-- must never be instantiated or monkeypatched.
local upstream_v5=chimera_vip.runtime and chimera_vip.runtime:is_chimera5()
if not upstream_v5 then
    load("src/theme/pastel.lua")
    load("src/ui/quiet_footer.lua")
    load("src/ui/settings_apply.lua")
end
load("src/ui/settings_panel.lua")
load("src/features/combat_colors.lua")
if not (chimera_vip.runtime and chimera_vip.runtime:is_chimera5()) then
    load("src/features/auto_support.lua")
end
-- Legacy tactical snapshots and renderer belong only to Chimera 4.x.
-- Chimera 5 exposes the same targets through the VIP UI plugin/team.view().
if upstream_v5 then
    -- Updating an already-running 0.182 profile must also detach listeners
    -- registered by its old tactical module; merely skipping dofile is not
    -- enough because Mudlet keeps those anonymous event handlers alive.
    local legacy=chimera_vip.tactical_states
    if type(legacy)=="table" then
        for _,id in pairs(legacy.handlers or {}) do
            if type(killAnonymousEventHandler)=="function" then
                pcall(killAnonymousEventHandler,id)
            end
        end
        if legacy.render_timer and type(killTimer)=="function" then
            pcall(killTimer,legacy.render_timer)
        end
        legacy.handlers={}
        legacy.render_timer=nil
        legacy.last_frame=nil
    end
else
    load("src/features/tactical_states.lua")
    load("src/features/tactical_states_view.lua")
end
load("src/features/tactical_aliases.lua")
load("src/features/xp_tracker.lua")
load("src/features/xp_kill_card_view.lua")
load("src/features/stats.lua")
load("src/features/stats_compact_view.lua")
load("src/features/report_actions.lua")
load("src/features/containers.lua")
load("src/features/skills_view.lua")
load("src/features/character_sheet.lua")
load("src/features/milestones.lua")
load("src/features/retainer_progress.lua")
load("src/features/equipment_view.lua")
load("src/features/weapon_info.lua")
load("src/features/blacksmith_info.lua")
if not upstream_v5 then
    load("src/ui/footer_controls.lua")
    load("src/ui/module_controls.lua")
end
load("src/core/hash.lua")
load("src/core/updater.lua")

if #chimera_vip.load_errors > 0 then
    error("Nie zaladowano " .. #chimera_vip.load_errors .. " modulow; /cvip diagnostyka")
end
chimera_vip:signal_ready("modulesLoaded")
return chimera_vip
