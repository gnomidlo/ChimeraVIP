-- Git blob SHA-1 for download integrity (not an authentication mechanism).
-- Arithmetic fallback keeps the release tests compatible with plain Lua 5.1.
local H = {}
local MOD = 4294967296
local function bxor(a,b)
    local result, weight = 0,1
    for _=1,32 do
        local x,y=a%2,b%2
        if x~=y then result=result+weight end
        a=math.floor(a/2); b=math.floor(b/2); weight=weight*2
    end
    return result
end
local function band(a,b) return (a+b-bxor(a,b))/2 end
local ok, bits = pcall(require,"bit")
if ok then
    bxor=function(a,b) return bits.bxor(a,b)%MOD end
    band=function(a,b) return bits.band(a,b)%MOD end
end
local function rol(a,n)
    local divisor=2^(32-n)
    return (a%divisor)*2^n+math.floor(a/divisor)
end
local function word(n)
    return string.char(math.floor(n/16777216)%256,math.floor(n/65536)%256,math.floor(n/256)%256,n%256)
end
function H.sha1(data)
    local size=#data
    data=data..string.char(128)..string.rep("\0",(55-size)%64)
        ..word(math.floor(size/536870912))..word((size*8)%MOD)
    local h0,h1,h2,h3,h4=1732584193,4023233417,2562383102,271733878,3285377520
    for offset=1,#data,64 do
        local w={}
        for i=0,15 do
            local a,b,c,d=data:byte(offset+i*4,offset+i*4+3)
            w[i]=a*16777216+b*65536+c*256+d
        end
        for i=16,79 do w[i]=rol(bxor(bxor(w[i-3],w[i-8]),bxor(w[i-14],w[i-16])),1) end
        local a,b,c,d,e=h0,h1,h2,h3,h4
        for i=0,79 do
            local f,k
            if i<20 then f=band(b,c)+band(MOD-1-b,d); k=1518500249
            elseif i<40 then f=bxor(bxor(b,c),d); k=1859775393
            elseif i<60 then f=bxor(bxor(band(b,c),band(b,d)),band(c,d)); k=2400959708
            else f=bxor(bxor(b,c),d); k=3395469782 end
            local next_a=(rol(a,5)+f+e+k+w[i])%MOD
            e=d; d=c; c=rol(b,30); b=a; a=next_a
        end
        h0=(h0+a)%MOD; h1=(h1+b)%MOD; h2=(h2+c)%MOD; h3=(h3+d)%MOD; h4=(h4+e)%MOD
    end
    return string.format("%08x%08x%08x%08x%08x",h0,h1,h2,h3,h4)
end
function H.blob(data) return H.sha1("blob "..#data.."\0"..data) end
chimera_vip.hash=H
return H
