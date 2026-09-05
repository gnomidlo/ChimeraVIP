local root=os.tmpname(); os.remove(root); assert(os.execute('mkdir -p '..string.format('%q',root))==0)
local handlers,timers={},{}; local seq=0
local function new_id() seq=seq+1; return seq end
function registerAnonymousEventHandler(event,fn) local n=new_id(); handlers[n]={event=event,fn=fn}; return n end
function killAnonymousEventHandler(n) handlers[n]=nil end
function tempTimer(_,fn) local n=new_id(); timers[n]=fn; return n end
function killTimer(n) timers[n]=nil end
function tempAlias() return 1 end
function killAlias() end
function cecho() end
function raiseEvent() end
function getMudletHomeDir() return root end
local function emit(event,...)
    local callbacks={}; for _,h in pairs(handlers) do if h.event==event then callbacks[#callbacks+1]=h.fn end end
    for _,fn in ipairs(callbacks) do fn(event,unpack(arg)) end
end
local function write(path,data) local f=assert(io.open(path,'wb')); assert(f:write(data)); assert(f:close()) end
local function read(path) local f=assert(io.open(path,'rb')); local s=f:read('*a'); f:close(); return s end
chimera_vip={root_dir=root,version='0.110'}
dofile('src/core/util.lua'); local U=chimera_vip.util
U.ensure_dir=function(path) return os.execute('mkdir -p '..string.format('%q',path))==0 end
local H=dofile('src/core/hash.lua')
assert(H.sha1('')=='da39a3ee5e6b4b0d3255bfef95601890afd80709')
assert(H.sha1('abc')=='a9993e364706816aba3e25717850c26c9cd0d89d')
assert(H.sha1('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')=='84983e441c3bd26ebaae4aa1f95129e5e54670f1')
assert(H.blob('hello\n')=='ce013625030ba8dba906f756967f9e9ca394464a')
print('PASS SHA-1 published vectors and Git blob vector')
dofile('src/core/updater.lua'); local UP=chimera_vip.updater
local payload='return 123\n'; local corrupt=false; local requests={}
local sha=string.rep('a',40)
yajl={to_value=function(text) assert(text=='commit-fixture'); return {sha=sha} end}
local manifest=string.format('return {schema=2,version="0.111",files={"fixture.lua"},remove={},file_meta={["fixture.lua"]={hash=%q,size=%d}}}',H.blob(payload),#payload)
function downloadFile(path,url)
    requests[#requests+1]=url
    if url:find('/commits/main',1,true) then write(path,'commit-fixture')
    elseif url:find('/manifest.lua',1,true) then assert(url:find('/'..sha..'/',1,true)); write(path,manifest)
    else assert(url:find('/'..sha..'/',1,true)); write(path,corrupt and 'return 456\n' or payload) end
    emit('sysDownloadDone',path)
end
local function reset()
    chimera_vip.version='0.110'; write(root..'/VERSION','0.110\n')
    write(root..'/fixture.lua','return 1\n'); write(root..'/installed_manifest.lua','return {version="0.110"}\n')
end
reset(); corrupt=true; UP:update()
assert(UP.mode==nil and read(root..'/fixture.lua')=='return 1\n','corrupt download installed')
assert(read(root..'/VERSION')=='0.110\n')
print('PASS same-size corruption rejected before replacement')
corrupt=false; reset(); local save=UP.save_installed_manifest
UP.save_installed_manifest=function() return false end
UP:update(); UP.save_installed_manifest=save
assert(read(root..'/VERSION')=='0.110\n' and read(root..'/fixture.lua')=='return 1\n','rollback lost version or code')
assert(read(root..'/installed_manifest.lua')=='return {version="0.110"}\n','rollback lost manifest')
print('PASS metadata failure restores code, VERSION and installed manifest')
reset(); UP:update()
assert(chimera_vip.version=='0.111' and read(root..'/fixture.lua')==payload)
assert(read(root..'/VERSION')=='0.111\n' and #requests==9)
assert(UP.mode==nil)
local meta={hash=H.blob(payload),size=#payload}
write(root..'/fixture.lua','return 456\n')
local plan=UP:build_plan({files={'fixture.lua'},file_meta={['fixture.lua']=meta}})
assert(#plan.changed==1,'local corruption skipped by differential plan')
write(root..'/fixture.lua','return )\n')
assert(not UP:verify_file(root..'/fixture.lua',{hash=H.blob('return )\n'),size=9}),'invalid syntax accepted')
print('PASS pinned snapshot, successful update, local corruption and syntax check')
local original=downloadFile; local paths={}
downloadFile=function(path) paths[#paths+1]=path end
UP:check(false); local expired=UP.timeout_timer; timers[expired]()
assert(UP.mode==nil)
UP:check(false); assert(paths[1]~=paths[2])
emit('sysDownloadDone',paths[1]); assert(UP.mode=='resolve','late callback consumed by retry')
UP:cleanup_handlers(); UP.mode=nil; downloadFile=original
print('PASS timeout and stale response isolation')
assert(os.execute('rm -rf '..string.format('%q',root))==0)
