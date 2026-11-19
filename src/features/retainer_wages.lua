-- ChimeraVIP 0.196 / retainer wages: compact "pazold" report.
-- Reports may omit "oplacone" for an unpaid retainer, or show "DLUG".
-- Never treat these normal variants as a failed capture.
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
    self.capture=nil;self.armed=false
    -- Some MUD messages do not terminate the output line. Begin replay on
    -- a fresh line so the original response cannot be glued to a DLUG line.
    if replay and c and #c.raw>0 then
        echo("\n")
        for _,text in ipairs(c.raw) do echo(text.."\n") end
    end
end
function W:cleanup()
    self:reset(true)
    U.clear_triggers(self);U.clear_aliases(self)
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
    -- Existing compact ChimeraVIP denominations and colors.
    local plain=tostring(text or ""):gsub("(%d+)%s+mithrylow%a*","%1mt")
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
        local paid,paid_rich,remaining,remaining_rich
        if r.debt then
            local debt,debt_rich=self:money(r.debt)
            paid="DLUG "..debt
            paid_rich=P.rose.."DLUG "..debt_rich
            remaining="DLUG"
            remaining_rich=P.rose..remaining
        elseif r.paid then
            paid,paid_rich=self:money(r.paid)
            remaining=r.time and ("~"..r.time) or "brak czasu"
            local minutes=r.time and tonumber(r.time:match("^(%d+) min$"))
            local tint=minutes and minutes<10 and P.rose
                or minutes and minutes<60 and P.yellow or P.mint
            remaining_rich=tint..remaining
        else
            -- When no 'oplacone' line is given, do not invent a balance.
            paid,paid_rich="-",P.text_muted.."-"
            remaining,remaining_rich="brak oplaty",P.yellow.."brak oplaty"
        end
        local values={r.number,r.name,rate,paid,remaining}
        local rich={P.text_muted..r.number,P.text..r.name,rate_rich,paid_rich,remaining_rich}
        cells[#cells+1]={plain=values,rich=rich}
        for i,v in ipairs(values) do widths[i]=math.max(widths[i],U.text_width(v)) end
        if r.interval and not seen[r.interval] then
            intervals[#intervals+1]=r.interval;seen[r.interval]=true
        end
    end
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

local function member(text)
    return text:match("^%s*(%d+)%.%s+(%S+)%s*$")
end
local function rate(text)
    return text:match("^%s*stawka:%s+(.+) za dobe %((%d+) minut sluzby%)%s*$")
end
local function paid(text)
    return text:match("^%s*oplacone:%s+(.+)%s*$")
end
local function debt(text)
    return text:match("^%s*DLUG:%s+(.+)%s*$")
end
local function remaining(text)
    return text:match("^%s*czyli ok%. (.+) sluzby przy tobie%s*$")
end
local function close_row(c)
    if not c.row or not c.row.rate then return false end
    c.rows[#c.rows+1]=c.row
    c.row=nil
    c.state="row"
    return true
end

function W:consume(text)
    if not self.armed then return false end
    text=tostring(text or ""):gsub("\r$","")
    local c=self.capture
    local header_prefix=nil
    local is_header=false
    if not c then
        -- Preserve any unrelated non-terminated output before a fused header:
        -- "DLUG: 2 miedziane monetyZold twoich pacholkow:"
        -- The server text itself remains untouched; our report can still
        -- continue with the next line instead of throwing away the capture.
        local prefix=text:match("^(.-)Zold twoich pacholkow:%s*$")
        if prefix==nil then return false end
        header_prefix=prefix
        is_header=true
        c={raw={},rows={},state="row"}
        self.capture=c
    else
        -- A member may have only 'stawka' and no paid/balance lines.
        -- The next numbered member or the report footer closes that row.
        local num,name=member(text)
        if c.state=="paid" and (num or text==footer[1]) then
            if not close_row(c) then self:reset(true);return false end
        elseif c.state=="time" and (num or text==footer[1]) then
            -- Unexpected missing time in an otherwise paid row: show
            -- "brak czasu" rather than inventing an expiry.
            if not close_row(c) then self:reset(true);return false end
        end

        if c.footer then
            if text~=footer[c.footer] then self:reset(true);return false end
            c.footer=c.footer+1
        elseif text=="" and c.state=="row" then
            -- Blank separators between rows.
        elseif c.state=="row" and text==footer[1] and #c.rows>0 then
            c.footer=2
        elseif c.state=="row" then
            local n,person=member(text)
            if not n then self:reset(true);return false end
            c.row={number=n,name=person}
            c.state="rate"
        elseif c.state=="rate" then
            local amount,interval=rate(text)
            if not amount then self:reset(true);return false end
            c.row.rate=amount;c.row.interval=interval;c.state="paid"
        elseif c.state=="paid" then
            local amount=paid(text)
            local owed=debt(text)
            if amount then
                c.row.paid=amount:gsub("%s+%-%- starczy na .+$","")
                c.state="time"
            elseif owed then
                c.row.debt=owed
                close_row(c)
            elseif text=="" then
                -- An optional blank line between 'stawka' and next row.
            else
                self:reset(true);return false
            end
        elseif c.state=="time" then
            local time=remaining(text)
            if time then
                c.row.time=time
                close_row(c)
            elseif text=="" then
                -- No need to fail early; next member/footer will close row.
            else
                self:reset(true);return false
            end
        end
    end
    if is_header then
        -- The previous unrelated MUD line may not have a trailing newline.
        -- Deleting the header must not glue it to the previous "DLUG".
        if U.gag_line() then
            if header_prefix~="" then
                echo("\n"..header_prefix.."\n")
            else
                echo("\n")
            end
        end
    else
        c.raw[#c.raw+1]=text
        U.gag_line()
    end
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
