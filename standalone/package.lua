-- Embedded in the package's permanent Script; Mudlet owns its event bindings.
local package_name = 'ChimeraVIP2'
local root = getMudletHomeDir() .. '/' .. package_name
local enabled = true

local function report(message)
    cecho('\n<orange>[ChimeraVIP 2.0]<reset> ' .. tostring(message) .. '\n')
end

function chimeraVip2PackageEvent(event, name)
    if not enabled then return end
    local uninstall = event == 'sysUninstallPackage' and name == package_name
    if uninstall or event == 'sysExitEvent' then
        local C = chimera_vip
        if C and C.mode == 'standalone' and C.root_dir == root then
            local ok, err = pcall(function() C:stop() end)
            if not ok then
                report(err)
                if C.lifecycle then C.lifecycle:stop() end
            end
            if uninstall then
                if chimera_overlay == C then chimera_overlay = nil end
                chimera_vip = nil
            end
        end
        if uninstall then enabled = false end
        return
    end
    if event ~= 'sysLoadEvent' and not (event == 'sysInstallPackage' and name == package_name) then return end
    -- Both install and profile-load may fire for the same package.
    if chimera_vip and chimera_vip.ready and chimera_vip.root_dir == root then return end
    local ok, err = pcall(function()
        assert(loadfile(root .. '/standalone/init.lua'))(root)
    end)
    if not ok then report('Start zatrzymany: ' .. tostring(err)) end
end
