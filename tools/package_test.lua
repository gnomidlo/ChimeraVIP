-- The Python test extracts and runs the exact permanent script from the XML.
local script=assert(arg[1])
local starts,stops,cleanups=0,0,0
local fail_start,fail_stop=false,false
local home='/profile with spaces'
local root=home..'/ChimeraVIP2'
function getMudletHomeDir() return home end
function cecho() end
local load=loadfile
loadfile=function(path)
    assert(path==root..'/standalone/init.lua')
    return function(directory)
        assert(directory==root)
        if fail_start then error('startup failed') end
        starts=starts+1
        chimera_vip={ready=true,mode='standalone',root_dir=directory,
            stop=function(self)
                stops=stops+1; self.ready=false
                if fail_stop then error('flush failed') end
            end,
            lifecycle={stop=function() cleanups=cleanups+1 end}}
        chimera_overlay=chimera_vip
    end
end
assert(load(script))()
chimeraVip2PackageEvent('sysInstallPackage','other'); assert(starts==0)
chimeraVip2PackageEvent('sysInstallPackage','ChimeraVIP2'); assert(starts==1)
chimeraVip2PackageEvent('sysLoadEvent'); assert(starts==1)
chimeraVip2PackageEvent('sysUninstallPackage','other'); assert(stops==0)
local stale=chimeraVip2PackageEvent
chimeraVip2PackageEvent('sysUninstallPackage','ChimeraVIP2')
assert(stops==1 and chimera_vip==nil and chimera_overlay==nil)
stale('sysLoadEvent'); assert(starts==1)
-- Reinstall creates a fresh permanent script and a fresh runtime.
assert(load(script))()
chimeraVip2PackageEvent('sysLoadEvent'); assert(starts==2)
chimeraVip2PackageEvent('sysExitEvent'); assert(stops==2)
-- A failed start is reported; a subsequent profile-load may retry.
fail_start=true
chimeraVip2PackageEvent('sysLoadEvent'); assert(starts==2)
fail_start=false
chimeraVip2PackageEvent('sysLoadEvent'); assert(starts==3)
fail_stop=true
chimeraVip2PackageEvent('sysUninstallPackage','ChimeraVIP2')
assert(cleanups==1 and chimera_vip==nil)
-- Uninstall must not stop a development checkout or a VIP 1.x runtime.
assert(load(script))()
chimera_vip={mode='standalone',root_dir='/other',stop=function() error('foreign runtime') end}
chimeraVip2PackageEvent('sysUninstallPackage','ChimeraVIP2')
assert(chimera_vip.root_dir=='/other')
print('PASS packaged bootstrap: install, profile load, uninstall, exit, failures and ownership')
