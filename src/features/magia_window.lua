-- ChimeraVIP 0.193 / Magic UserWindow
-- Samodzielne natywne okno Mudleta. Styl na podstawie le/ui.lua i
-- le/zlecenia.lua (Arka): cienki akcent, spokojne powierzchnie, Qt rich text.
-- Brak Geyser overlay na glownej konsoli; brak zmian w Kondycjach.
local M=chimera_vip.magia
local U=chimera_vip.util

local DESIGN=2
local WINDOW_NAME="ChimeraVIP_Magia"
local ACCENT="#B6A2E1"
local BG="#101216"
local SURFACE="#171A21"
local MUTED="#8B909A"
local DIVIDER="#2C3038"
local TEXT="#D8DBE2"
local HEADER_H=43
local FOOTER_H=28
local ROW_H=48
local SECTION_H=28

local function esc(value)
    return U.escape_html(value)
end
local function short(value,max_chars)
    local chars={}
    for ch in tostring(value or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        chars[#chars+1]=ch
    end
    if #chars<=max_chars then return table.concat(chars) end
    return table.concat(chars,"",1,math.max(1,max_chars-1)).."…"
end
local function window_width()
    if type(getUserWindowSize)=="function" then
        local ok,w=pcall(getUserWindowSize,WINDOW_NAME)
        if ok and type(w)=="number" and w>0 then return w end
    end
    return 360
end
local function style(bg,edge,font_size,padding)
    return "background-color:"..bg..";border:none;border-left:3px solid "
        ..(edge or bg)..";border-bottom:1px solid "..DIVIDER
        ..";padding:"..(padding or "3px 9px")..";font-family:"
        .."'DejaVu Sans Mono','Consolas',monospace;font-size:"
        ..(font_size or "11px")..";"
end
local function button_style()
    return "background-color:transparent;border:none;border-bottom:1px solid "
        ..DIVIDER..";padding:0px;font-family:'Consolas',monospace;font-size:14px;"
end
local function rich_time(seconds)
    local color=M:color(seconds)
    return "<span style='color:"..color.."'><b>"..esc(M.format(seconds)).."</b></span>"
end
local function tooltip(widget,message)
    if type(setLabelToolTip)=="function" then
        pcall(setLabelToolTip,widget.name,esc(message),7)
    elseif widget and type(widget.setToolTip)=="function" then
        pcall(widget.setToolTip,widget,message)
    end
end

function M:display_rows()
    local rows=self:rows()
    local present=self:present()
    local displays={}
    if self.data.mode=="compact" then
        -- Kompakt to skrot calej druzyny, a nie 4 najkrotsze przedmioty
        -- jednej postaci. W szczegolnosci nie gubimy wlasnego ekwipunku.
        local first,used={},{}
        local order={"@"}
        for _,r in ipairs(self:retainers()) do order[#order+1]=tostring(r.id) end
        local unique={}
        for _,id in ipairs(order) do
            if present[id] and not unique[id] then
                unique[id]=true
                for i,row in ipairs(rows) do
                    if row.id==id then
                        first[#first+1]={row=row,index=i}
                        used[i]=true
                        break
                    end
                end
            end
        end
        -- Jezeli pacholkow jest wiecej niz miejsc, pokaz tych z
        -- najkrotsza trwaloscia, nie pierwszych alfabetycznie.
        table.sort(first,function(a,b)
            if a.row.id=="@" then return true end
            if b.row.id=="@" then return false end
            return a.row.seconds<b.row.seconds
        end)
        -- Rezerwuj miejsce dla JA nawet jesli odczyt jeszcze nie dotarl.
        local own_known=false
        for _,v in ipairs(first) do if v.row.id=="@" then own_known=true end end
        if not own_known then
            local own=self.data.owners["@"]
            local scanned=own and (own.last_scan or 0)>0
            displays[#displays+1]={kind="missing",owner="JA",
                title=scanned and "JA · brak magicznego wyposazenia"
                    or "JA · brak odczytu magii",
                detail=scanned and "Ostatni skan nie wykazal magii"
                    or "Wykonaj /magia sprawdz"}
        end
        -- Po jednym najwazniejszym przedmiocie na wlasciciela, potem
        -- wolne miejsca uzupelniamy wedlug czasu (bez powielania).
        for _,v in ipairs(first) do
            if #displays>=4 then break end
            displays[#displays+1]={kind="item",row=v.row}
        end
        for i,row in ipairs(rows) do
            if #displays>=4 then break end
            if not used[i] then displays[#displays+1]={kind="item",row=row} end
        end
    else
        -- Pelny widok grupuje wszystkie przedmioty, w tym dwa pierscienie
        -- tego samego rodzaju o roznych terminach rozpadu.
        local owners={"@"}
        for _,r in ipairs(self:retainers()) do owners[#owners+1]=tostring(r.id) end
        local seen={}
        for _,id in ipairs(owners) do
            if present[id] and not seen[id] then
                seen[id]=true
                local owner=self.data.owners[id]
                local name=id=="@" and "TWOJA POSTAC"
                    or tostring((owner and owner.name) or
                        (function()
                            for _,r in ipairs(self:retainers()) do
                                if tostring(r.id)==id then return r.name end
                            end
                        end)() or id):upper()
                displays[#displays+1]={kind="group",title=name}
                local count=0
                for _,row in ipairs(rows) do
                    if row.id==id then
                        displays[#displays+1]={kind="item",row=row,grouped=true}
                        count=count+1
                    end
                end
                if count==0 then displays[#displays+1]={
                    kind="missing",owner=name,
                    title=id=="@" and "Brak odczytu twojej magii" or "Brak odczytanych przedmiotow",
                    detail="Kliknij ↻, aby sprawdzic"}
                end
            end
        end
    end
    return displays
end

function M:clear_old_content()
    -- W czasie aktualizacji Geyser.UserWindow zachowuje istniejacy dock.
    -- Kasujemy tylko dzieci starego interfejsu, nie samo okno (geometria!).
    for _,widget in ipairs(self.row_labels or {}) do
        if widget and type(widget.delete)=="function" then pcall(widget.delete,widget)
        elseif widget then pcall(widget.hide,widget) end
    end
    for _,widget in ipairs({self.header,self.scan_button,self.mode_button,
                            self.footer,self.body}) do
        if widget and type(widget.delete)=="function" then pcall(widget.delete,widget)
        elseif widget and type(widget.hide)=="function" then pcall(widget.hide,widget) end
    end
    self.header=nil;self.scan_button=nil;self.mode_button=nil
    self.footer=nil;self.body=nil;self.row_labels=nil
end

function M:show_window()
    if not (Geyser and Geyser.UserWindow and Geyser.Label and Geyser.ScrollBox) then
        hecho("\n<#D98282>[Magia] Brak Geyser.UserWindow. Uzyj /magia.\n")
        return false
    end
    if not self.win then
        local ok,window=pcall(function()
            return Geyser.UserWindow:new({
                name=WINDOW_NAME,titleText="Magia — ChimeraVIP",
                x="38%",y="16%",width="360px",height="262px",
                dockPosition="floating",autoDock=false,restoreLayout=true,
            })
        end)
        if not ok or not window then
            hecho("\n<#D98282>[Magia] Nie udalo sie utworzyc okna: "..tostring(window).."\n")
            return false
        end
        self.win=window
    end
    if self._window_design~=DESIGN or not self.body then
        self:clear_old_content()
        local w=self.win
        self.header=Geyser.Label:new({name="CVIP_Magia_V2_Header",
            x="0px",y="0px",width="100%",height=HEADER_H.."px"},w)
        self.scan_button=Geyser.Label:new({name="CVIP_Magia_V2_Scan",
            x="-78px",y="4px",width="34px",height="35px"},w)
        self.mode_button=Geyser.Label:new({name="CVIP_Magia_V2_Mode",
            x="-40px",y="4px",width="34px",height="35px"},w)
        self.body=Geyser.ScrollBox:new({name="CVIP_Magia_V2_List",
            x="0px",y=HEADER_H.."px",width="100%",
            height="-"..(HEADER_H+FOOTER_H).."px"},w)
        self.footer=Geyser.Label:new({name="CVIP_Magia_V2_Footer",
            x="0px",y="-"..FOOTER_H.."px",width="100%",
            height=FOOTER_H.."px"},w)
        self.row_labels={}
        self._window_design=DESIGN
        self.header:setClickCallback(function() M:toggle_mode() end)
        self.scan_button:setClickCallback(function() M:scan() end)
        self.mode_button:setClickCallback(function() M:toggle_mode() end)
        self.footer:setClickCallback(function() M:scan() end)
        tooltip(self.scan_button,"Sprawdz magie calej druzyny")
        tooltip(self.mode_button,"Przelacz widok kompaktowy/pelny")
    end
    self.win:show()
    if type(showWindow)=="function" then pcall(showWindow,WINDOW_NAME) end
    self:render()
    return true
end
function M:hide_window()
    if self.win then self.win:hide() end
end
function M:set_mode(mode)
    self.data.mode=mode=="full" and "full" or "compact"
    self:save();self:show_window()
end
function M:toggle_mode()
    self:set_mode(self.data.mode=="full" and "compact" or "full")
end

local function row_height(v)
    if v.kind=="group" then return SECTION_H end
    return ROW_H
end
local function item_html(self,item,width)
    local row=item.row
    local len=math.max(15,math.min(62,math.floor((width-132)/7)))
    local owner=item.grouped and "" or ("<span style='color:"..MUTED.."'>"..
        esc(row.id=="@" and "JA" or row.owner).."</span>")
    local meta=owner..(owner~="" and "&nbsp;&nbsp;·&nbsp;&nbsp;" or "")
        .."<span style='color:"..MUTED.."'>szacowany czas</span>"
    return "<table width='100%' cellspacing='0' cellpadding='0'><tr>"
        .."<td><span style='color:"..TEXT..";font-size:11px'><b>"
        ..esc(short(row.item.name,len)).."</b></span></td>"
        .."<td align='right' width='90'><span style='font-size:11px'>"
        ..rich_time(row.seconds).."</span></td></tr></table>"
        .."<div style='font-size:9px;color:"..MUTED.."'>"..meta.."</div>"
end

function M:render()
    if not (self.win and self.body and self.header) then return end
    local view=self:display_rows()
    self._visible_rows=view
    local count=#self:rows()
    local width=window_width()
    self.header:setStyleSheet(style(SURFACE,ACCENT,"11px","4px 9px"))
    self.header:echo("<div><b><span style='color:"..ACCENT.."'>✦&nbsp; MAGIA</span></b>"
        .."</div><div style='font-size:9px;color:"..MUTED
        .."'>TRWALOSC WYPOSAZENIA</div>")
    self.scan_button:setStyleSheet(button_style())
    self.mode_button:setStyleSheet(button_style())
    self.scan_button:echo("<center><span style='color:"..ACCENT.."'>↻</span></center>")
    self.mode_button:echo("<center><span style='color:"..ACCENT.."'>"
        ..(self.data.mode=="full" and "▣" or "▤").."</span></center>")
    local last=0
    local present=self:present()
    for id,owner in pairs(self.data.owners) do
        if present[id] then last=math.max(last,tonumber(owner.last_scan) or 0) end
    end
    self.footer:setStyleSheet(style(SURFACE,SURFACE,"10px","4px 9px"))
    local status=self.current and "<span style='color:"..ACCENT.."'>SKANOWANIE...</span>"
        or "<span style='color:"..MUTED.."'>"
        ..(last>0 and ("skan "..os.date("%H:%M",last)) or "brak skanu").."</span>"
    self.footer:echo("<span style='color:"..MUTED.."'>"..count..
        " przedm.</span> &nbsp;&nbsp;·&nbsp;&nbsp; "..status)
    local y=0
    for i,item in ipairs(view) do
        local label=self.row_labels[i]
        if not label then
            label=Geyser.Label:new({name="CVIP_Magia_V2_Row_"..i,
                x="0px",y=y.."px",width="100%",height=row_height(item).."px"},self.body)
            local index=i
            label:setClickCallback(function()
                local selected=M._visible_rows and M._visible_rows[index]
                if selected and selected.kind=="item" then M:report()
                else M:toggle_mode() end
            end)
            self.row_labels[i]=label
        end
        label:move("0px",y.."px")
        label:resize("100%",row_height(item).."px")
        if item.kind=="group" then
            label:setStyleSheet(style(BG,ACCENT,"10px","4px 9px"))
            label:echo("<span style='color:"..ACCENT.."'><b>"..esc(item.title)
                .."</b></span>")
        elseif item.kind=="missing" then
            label:setStyleSheet(style(SURFACE,DIVIDER,"10px","5px 9px"))
            label:echo("<div style='color:"..MUTED.."'>"..esc(item.title)..
                "</div><div style='font-size:9px;color:"..MUTED.."'>"..
                esc(item.detail).."</div>")
        else
            local edge=self:color(item.row.seconds)
            label:setStyleSheet(style(i%2==0 and BG or SURFACE,edge,"11px","5px 9px"))
            label:echo(item_html(self,item,width))
            tooltip(label,item.row.owner.." • "..item.row.item.name..
                " • "..M.format(item.row.seconds))
        end
        label:show()
        y=y+row_height(item)
    end
    for i=#view+1,#self.row_labels do self.row_labels[i]:hide() end
    -- Qt/Geyser ScrollBox scrolluje zawartosc; nie zmieniamy
    -- natywnej geometrii ani pozycji dokowania przy odswiezaniu.
end
return M
