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
load("src/core/settings.lua")
load("src/core/help.lua")
load("src/integrations/chimera.lua")
load("src/theme/pastel.lua")
load("src/ui/quiet_footer.lua")
load("src/ui/settings_apply.lua")
load("src/ui/settings_panel.lua")
load("src/features/combat_colors.lua")
load("src/features/defense_tracker.lua")
load("src/integrations/defense_combat.lua")
load("src/features/auto_support.lua")
load("src/features/xp_tracker.lua")
load("src/features/stats.lua")
load("src/features/report_actions.lua")
load("src/features/characters.lua")
load("src/features/settings_bindings.lua")
load("src/features/characters_delete_ui.lua")
load("src/ui/characters_help_panel.lua")
load("src/features/containers.lua")
load("src/features/skills_view.lua")
load("src/features/equipment_view.lua")
load("src/features/weapon_info.lua")
load("src/ui/footer_controls.lua")
load("src/ui/module_controls.lua")
load("src/core/hash.lua")
load("src/core/updater.lua")

if #chimera_vip.load_errors > 0 then
    error("Nie zaladowano " .. #chimera_vip.load_errors .. " modulow; /cvip diagnostyka")
end
chimera_vip:signal_ready("modulesLoaded")
return chimera_vip
