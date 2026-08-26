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
load("src/theme/pastel.lua")
load("src/ui/quiet_footer.lua")
load("src/features/auto_support.lua")
load("src/ui/footer_controls.lua")
load("src/core/updater.lua")

return chimera_vip
