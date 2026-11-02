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
    local out=text:gsub("(%d+)%s+mithrylow%a*","%1 mth")
        :gsub("(%d+)%s+zlot%a*","%1 zl")
        :gsub("(%d+)%s+srebrn%a*","%1 sr")
        :gsub("(%d+)%s+miedzian%a*","%1 md")
        :gsub("%s+monet%a*",""):gsub("%s+i%s+"," "):gsub(",%s*"," ")
    return out
end

function W:render(rows)
    local P=U.palette()
    local columns={"NR","PACHOLEK","STAWKA / DOBA","OPLACONE","CZAS PRZY TOBIE"}
    local widths={2,8,14,8,16}
    local cells={}
    for _,r in ipairs(rows) do
        local values={r.number,r.name,self:money(r.rate).." / "..r.interval.."m",
            self:money(r.paid),"~"..r.time}
        cells[#cells+1]=values
        for i,v in ipairs(values) do widths[i]=math.max(widths[i],U.text_width(v)) end
    end
    local function print_row(values,colors)
        for i,v in ipairs(values) do hecho(colors[i]..U.pad_right(v,widths[i]).."  ") end
        hecho("\n")
    end
    hecho("\n"..P.lavender.."ZOLD PACHOLKOW\n")
    print_row(columns,{P.text_muted,P.text_muted,P.text_muted,P.text_muted,P.text_muted})
    for i,values in ipairs(cells) do
        local minutes=tonumber(rows[i].time:match("^(%d+) min$"))
        local tint=minutes and minutes<10 and P.rose or minutes and minutes<60 and P.yellow or P.mint
        print_row(values,{P.text_muted,P.lavender,P.text,P.peach,tint})
    end
    hecho(P.text_muted.."mth/mithryl, zl/zloto, sr/srebro, md/miedz. Czas biegnie tylko przy tobie.\n")
    hecho(P.text_muted.."pazold IMIE: 3 doby | 2 godziny | 1 dzien | 9 zlotych monet | splac\n")
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
