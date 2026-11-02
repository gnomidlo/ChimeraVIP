-- Compact rendering only for explicitly requested, bare pazold.
local C=chimera_vip
local U=C.util
C.retainer_wages=C.retainer_wages or {}
local W=C.retainer_wages
local footer={
    "Zaplacisz w dobach ('pazold <imie> 3 doby'), w czasie rzeczywistym",
    "('pazold <imie> 2 godziny', 'pazold <imie> 1 dzien') albo kwota",
    "('pazold <imie> 9 zlotych monet'). Dlug zamyka 'pazold <imie> splac'.",
    "Czas liczy sie tylko wtedy, gdy pacholek jest przy tobie.",
}

function W:reset(replay)
    if self.timer then pcall(killTimer,self.timer) end
    self.timer=nil
    local c=self.capture
    self.capture=nil; self.armed=false
    -- An unknown/debt variant or interrupted response must remain readable.
    if replay and c then
        for _,text in ipairs(c.raw) do echo(text.."\n") end
    end
end
function W:cleanup()
    self:reset(true)
    U.clear_triggers(self); U.clear_aliases(self)
    for _,id in pairs(self.handlers or {}) do pcall(killAnonymousEventHandler,id) end
    self.handlers={}
end
W:cleanup()

function W:request()
    if self.armed then return false end
    self.armed=true
    self.timer=tempTimer(10,function() W:reset(true) end)
    send("pazold",false)
    return true
end

function W:money(text)
    -- Same suffixes and denomination colors as weapon_info.colored_money.
    local plain=text:gsub("(%d+)%s+mithrylow%a*","%1mt")
        :gsub("(%d+)%s+zlot%a*","%1z")
        :gsub("(%d+)%s+srebrn%a*","%1s")
        :gsub("(%d+)%s+miedzian%a*","%1m")
        :gsub("%s+monet%a*",""):gsub("%s+i%s+"," "):gsub(",%s*"," ")
    local P=U.palette()
    local colors={mt=P.lavender,z=P.yellow,s=P.text,m=P.peach}
    local rich=plain:gsub("(%d+)(%a+)",function(amount,coin)
        return (colors[coin] or P.text)..amount..coin..P.text_muted
    end)
    return plain,rich
end

function W:render(rows)
    local P=U.palette()
    local columns={"#","IMIE","STAWKA","OPLACONE","POZOSTALO"}
    local widths={1,10,8,8,9}
    local cells,intervals,seen={},{},{}
    for _,r in ipairs(rows) do
        local rate,rate_rich=self:money(r.rate)
        local paid,paid_rich=self:money(r.paid)
        local minutes=tonumber(r.time:match("^(%d+) min$"))
        local tint=minutes and minutes<10 and P.rose or minutes and minutes<60 and P.yellow or P.mint
        local values={r.number,r.name,rate,paid,"~"..r.time}
        local rich={P.text_muted..r.number,P.text..r.name,rate_rich,paid_rich,tint..values[5]}
        cells[#cells+1]={plain=values,rich=rich}
        for i,v in ipairs(values) do widths[i]=math.max(widths[i],U.text_width(v)) end
        if not seen[r.interval] then intervals[#intervals+1]=r.interval; seen[r.interval]=true end
    end
    -- Layout follows palista: two-space inset, muted headers, separators and
    -- a short footer. Padding uses visible text, never embedded color tags.
    local width=2+2*(#columns-1)
    for _,n in ipairs(widths) do width=width+n end
    local rule=P.separator..string.rep("-",math.max(72,width))
    local function print_row(values,rich)
        hecho("\n  ")
        for i,v in ipairs(values) do
            hecho((rich and rich[i] or P.text_muted..v))
            if i<#values then hecho(string.rep(" ",widths[i]-U.text_width(v)+2)) end
        end
    end
    hecho("\n\n"..P.lavender.."ZOLD PACHOLKOW\n"..rule)
    print_row(columns)
    for _,cell in ipairs(cells) do print_row(cell.plain,cell.rich) end
    hecho("\n"..rule)
    table.sort(intervals,function(a,b) return tonumber(a)<tonumber(b) end)
    hecho("\n  "..P.text_muted.."Doba: "..P.lavender..table.concat(intervals,"/").." min"
        ..P.text_muted.."  |  czas liczy sie tylko przy tobie.")
    hecho("\n  "..P.text_muted.."pazold IMIE: 3 doby | 2 godziny | 1 dzien | 9 zlotych monet | splac")
    hecho("\n"..rule.."\n")
end

function W:consume(text)
    if not self.armed then return false end
    local c=self.capture
    if not c then
        if text~="Zold twoich pacholkow:" then return false end
        c={raw={},rows={},state="row"}; self.capture=c
    elseif c.footer then
        if text~=footer[c.footer] then self:reset(true); return false end
        c.footer=c.footer+1
    elseif text=="" and c.state=="row" then
        -- separators between complete rows
    elseif c.state=="row" and text==footer[1] and #c.rows>0 then
        c.footer=2
    elseif c.state=="row" then
        local number,name=text:match("^%s+(%d+)%.%s+(%S+)%s*$")
        if not number then self:reset(true); return false end
        c.row={number=number,name=name}; c.state="rate"
    elseif c.state=="rate" then
        local rate,interval=text:match("^%s+stawka:%s+(.+) za dobe %((%d+) minut sluzby%)%s*$")
        if not rate then self:reset(true); return false end
        c.row.rate=rate; c.row.interval=interval; c.state="paid"
    elseif c.state=="paid" then
        local paid=text:match("^%s+oplacone:%s+(.+)%s*$")
        if not paid then self:reset(true); return false end
        c.row.paid=paid:gsub("%s+%-%- starczy na .+$",""); c.state="time"
    elseif c.state=="time" then
        local time=text:match("^%s+czyli ok%. (.+) sluzby przy tobie%s*$")
        if not time then self:reset(true); return false end
        c.row.time=time; c.rows[#c.rows+1]=c.row; c.row=nil; c.state="row"
    end
    c.raw[#c.raw+1]=text
    U.gag_line()
    if c.footer==#footer+1 then
        local rows=c.rows
        self:reset(false)
        self:render(rows)
    end
    return true
end

W.trigger_ids={tempRegexTrigger("^.*$",function() W:consume(line or matches[1] or "") end)}
W.alias_ids={tempAlias("^pazold\\s*$",function() W:request() end)}
U.replace_handler(W,"disconnect","sysDisconnectionEvent",function() W:reset(true) end)
U.replace_handler(W,"uninstall","sysUninstallPackage",function(_,name)
    if tostring(name):lower()=="chimeravip" then W:cleanup() end
end)
return W
