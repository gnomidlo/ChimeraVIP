chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local root = chimera_vip.root_dir or (getMudletHomeDir() .. "/ChimeraVIP")
chimera_vip.root_dir = root

local function load(rel)
    local path = root .. "/" .. rel
    local ok, err = pcall(dofile, path)
    if not ok then
        cecho("\n<orange>[ChimeraVIP]<reset> Blad ladowania " .. rel .. ": " .. tostring(err) .. "\n")
        return false
    end
    return true
end

load("src/core/util.lua")
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
load("src/features/progression.lua")
load("src/features/characters.lua")
load("src/features/characters_delete_ui.lua")
load("src/features/weapon_info.lua")
load("src/ui/footer_controls.lua")
load("src/ui/module_controls.lua")
load("src/core/updater.lua")

return chimera_vip
