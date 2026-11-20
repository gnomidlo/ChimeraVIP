-- ChimeraVIP 0.197 / Magic UserWindow
-- Samodzielne natywne okno Mudleta. Styl na podstawie le/ui.lua i
-- le/zlecenia.lua (Arka): cienki akcent, spokojne powierzchnie, Qt rich text.
-- Brak Geyser overlay na glownej konsoli; brak zmian w Kondycjach.
local M=chimera_vip.magia
local U=chimera_vip.util

local DESIGN=4
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
-- Reserve only enough space for "lada chwila" at 11px + gutter and scrollbar.
-- Layout: [beginning of item name, growing] [lifetime, fixed to the right].
local TIME_WIDTH=90
local TIME_RIGHT=17
local NAME_GAP=13
local NAME_RESERVED=TIME_WIDTH+TIME_RIGHT+NAME_GAP
local function negpx(n) return "-"..n.."px" end

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
local function window_width(self)
    -- sysUserWindowResizeEvent daje aktualna szerokosc docka. Jesli
    -- nie bylo jeszcze resize, zapytaj Mudleta o natywny rozmiar okna.
    local cached=tonumber(self._window_width)
    if cached and cached>0 then return cached end
    if type(getUserWindowSize)=="function" then
        local ok,w=pcall(getUserWindowSize,WINDOW_NAME)
        if ok and type(w)=="number" and w>0 then return w end
    end
    return 360
end
-- Minimalne poziome miejsce dla pierwszych liter nazwy po odjeciu
-- stalej kolumny czasu i paska przewijania. NIGDY nie ucinaj od lewej.
function M.name_char_limit(width)
    return math.max(1,math.min(96,
        math.floor(((tonumber(width) or 360)-NAME_RESERVED-18)/7.5)))
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
local function rich_time(item)
    local remaining=M:remaining(item)
    local color=M:color(remaining)
    local content=M:format_item(item)
    -- The elapsed approximation is NOT confirmation of destruction.
    -- Keep the longer wording in textual reports, but fit the right column.
    if remaining<=0 and not item.imminent then content="po czasie?" end
    return "<span style='color:"..color.."'><b>"..
        esc(content).."</b></span>"
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
        -- The compact list is a GLOBAL countdown: four items nearest to
        -- disintegration across the entire party, regardless of owner.
        -- M:rows() already orders by remaining time (including "lada chwila").
        for i=1,math.min(4,#rows) do
            displays[#displays+1]={kind="item",row=rows[i]}
        end
        -- Missing own scan is informational, never more important than
        -- a known urgent item. Show it only when a free slot exists.
        if #displays<4 and not self.data.owners["@"] then
            displays[#displays+1]={kind="missing",owner="JA",
                title="JA · brak odczytu magii",
                detail="Wykonaj /magia sprawdz"}
        end
        if #displays==0 then
            displays[1]={kind="missing",owner="JA",
                title="Brak magicznych przedmiotow",
                detail="Kliknij ↻, aby sprawdzic"}
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
    for _,collection in ipairs({self.row_labels or {},
                                 self.name_labels or {},
                                 self.time_labels or {}}) do
        for _,widget in ipairs(collection) do
            if widget and type(widget.delete)=="function" then pcall(widget.delete,widget)
            elseif widget then pcall(widget.hide,widget) end
        end
    end
    for _,widget in ipairs({self.header,self.scan_button,self.mode_button,
                            self.footer,self.body_bg,self.body,self.window_bg}) do
        if widget and type(widget.delete)=="function" then pcall(widget.delete,widget)
        elseif widget and type(widget.hide)=="function" then pcall(widget.hide,widget) end
    end
    self.header=nil;self.scan_button=nil;self.mode_button=nil
    self.footer=nil;self.body=nil;self.body_bg=nil;self.window_bg=nil
    self.row_labels=nil;self.name_labels=nil;self.time_labels=nil
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
        -- Native window and ScrollBox otherwise expose Mudlet's default
        -- pure black whenever the user makes the dock taller than its rows.
        self.window_bg=Geyser.Label:new({name="CVIP_Magia_V4_Background",
            x="0px",y="0px",width="100%",height="100%"},w)
        self.window_bg:setStyleSheet("background-color:"..BG..";border:none;padding:0px;")
        self.window_bg:echo("")
        if type(setBackgroundColor)=="function" then
            pcall(setBackgroundColor,WINDOW_NAME,16,18,22,255)
        end
        self.header=Geyser.Label:new({name="CVIP_Magia_V2_Header",
            x="0px",y="0px",width="100%",height=HEADER_H.."px"},w)
        self.scan_button=Geyser.Label:new({name="CVIP_Magia_V2_Scan",
            x="-78px",y="4px",width="34px",height="35px"},w)
        self.mode_button=Geyser.Label:new({name="CVIP_Magia_V2_Mode",
            x="-40px",y="4px",width="34px",height="35px"},w)
        self.body=Geyser.ScrollBox:new({name="CVIP_Magia_V2_List",
            x="0px",y=HEADER_H.."px",width="100%",
            height="-"..(HEADER_H+FOOTER_H).."px"},w)
        -- Covers unused space INSIDE the scroll area when only 1-3 items
        -- exist; rows are layered on top of this label.
        self.body_bg=Geyser.Label:new({name="CVIP_Magia_V4_ListBackground",
            x="0px",y="0px",width="100%",height="100%"},self.body)
        self.body_bg:setStyleSheet("background-color:"..SURFACE..";border:none;padding:0px;")
        self.body_bg:echo("")
        self.footer=Geyser.Label:new({name="CVIP_Magia_V2_Footer",
            x="0px",y="-"..FOOTER_H.."px",width="100%",
            height=FOOTER_H.."px"},w)
        self.row_labels={}
        self.name_labels={}
        self.time_labels={}
        self._window_design=DESIGN
        self.header:setClickCallback(function() M:toggle_mode() end)
        self.scan_button:setClickCallback(function() M:scan() end)
        self.mode_button:setClickCallback(function() M:toggle_mode() end)
        self.footer:setClickCallback(function() M:scan() end)
        if type(self.footer.raise)=="function" then self.footer:raise() end
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
    local owner=item.grouped and "" or ("<span style='color:"..MUTED.."'>"..
        esc(row.id=="@" and "JA" or row.owner).."</span>")
    local meta=owner..(owner~="" and "&nbsp;&nbsp;·&nbsp;&nbsp;" or "")
        .."<span style='color:"..MUTED.."'>czas orientacyjny</span>"
    -- Tylko nazwa: odcinamy jej KONIEC, nigdy poczatek. Czas ma swoja
    -- fizycznie oddzielona, zakotwiczona do prawej etykiete.
    return "<div style='font-size:11px;color:"..TEXT.."'><b>"
        ..esc(short(row.item.name,M.name_char_limit(width))).."</b></div>"
        .."<div style='font-size:9px;color:"..MUTED.."'>"..meta.."</div>"
end

function M:render()
    if not (self.win and self.body and self.header) then return end
    local view=self:display_rows()
    self._visible_rows=view
    local count=#self:rows()
    local width=window_width(self)
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
    self.footer:setStyleSheet("background-color:"..SURFACE..";border:none;"
        .."border-top:1px solid "..DIVIDER..";padding:4px 9px;"
        .."font-family:'DejaVu Sans Mono','Consolas',monospace;font-size:10px;")
    local status=self.current and "<span style='color:"..ACCENT.."'>SKANOWANIE...</span>"
        or "<span style='color:"..MUTED.."'>"
        ..(last>0 and ("skan "..os.date("%H:%M",last)) or "brak skanu").."</span>"
    self.footer:echo("<span style='color:"..MUTED.."'>"..count..
        " przedm.</span> &nbsp;&nbsp;·&nbsp;&nbsp; "..status)
    self.footer:show()
    if type(self.footer.raise)=="function" then self.footer:raise() end
    local y=0
    for i,item in ipairs(view) do
        local label=self.row_labels[i]
        if not label then
            label=Geyser.Label:new({name="CVIP_Magia_V3_Row_"..i,
                x="0px",y=y.."px",width="100%-16px",
                height=row_height(item).."px"},self.body)
            local index=i
            local click=function()
                local selected=M._visible_rows and M._visible_rows[index]
                if selected and selected.kind=="item" then M:report()
                else M:toggle_mode() end
            end
            label:setClickCallback(click)
            self.row_labels[i]=label
            -- Dwie niezalezne kolumny. Czas jest przy prawej krawedzi
            -- (z miejscem na pasek przewijania), nie moze go wyprzec
            -- nazwa przedmiotu ani rozciagajaca sie tabela HTML.
            local name=Geyser.Label:new({name="CVIP_Magia_V3_Name_"..i,
                x="3px",y=y.."px",width=negpx(NAME_RESERVED),
                height=ROW_H.."px"},self.body)
            local time=Geyser.Label:new({name="CVIP_Magia_V3_Time_"..i,
                x=negpx(TIME_WIDTH+TIME_RIGHT),y=y.."px",
                width=TIME_WIDTH.."px",
                height=ROW_H.."px"},self.body)
            name:setClickCallback(click)
            time:setClickCallback(click)
            self.name_labels[i]=name
            self.time_labels[i]=time
        end
        local name=self.name_labels[i]
        local time=self.time_labels[i]
        label:move("0px",y.."px")
        label:resize("100%-16px",row_height(item).."px")
        if item.kind=="group" then
            label:setStyleSheet(style(BG,ACCENT,"10px","4px 9px"))
            label:echo("<span style='color:"..ACCENT.."'><b>"..esc(item.title)
                .."</b></span>")
            name:hide();time:hide()
        elseif item.kind=="missing" then
            label:setStyleSheet(style(SURFACE,DIVIDER,"10px","5px 9px"))
            label:echo("<div style='color:"..MUTED.."'>"..esc(item.title)..
                "</div><div style='font-size:9px;color:"..MUTED.."'>"..
                esc(item.detail).."</div>")
            name:hide();time:hide()
        else
            local edge=self:color(item.row.seconds)
            label:setStyleSheet(style(i%2==0 and BG or SURFACE,edge,"11px","5px 9px"))
            label:echo("")
            name:move("3px",y.."px")
            name:resize(negpx(NAME_RESERVED),ROW_H.."px")
            name:setStyleSheet("background-color:transparent;border:none;padding:5px 1px 2px 7px;"
                .."font-family:'DejaVu Sans Mono','Consolas',monospace;")
            name:echo(item_html(self,item,width))
            name:show()
            time:move(negpx(TIME_WIDTH+TIME_RIGHT),y.."px")
            time:resize(TIME_WIDTH.."px",ROW_H.."px")
            time:setStyleSheet("background-color:transparent;border:none;padding:7px 0px 0px 0px;"
                .."font-family:'DejaVu Sans Mono','Consolas',monospace;")
            time:echo("<div align='right' style='font-size:11px'>"
                ..rich_time(item.row.item).."</div>")
            time:show()
            tooltip(label,item.row.owner.." • "..item.row.item.name..
                " • "..self:format_item(item.row.item))
        end
        label:show()
        y=y+row_height(item)
    end
    for i=#view+1,#self.row_labels do
        self.row_labels[i]:hide()
        if self.name_labels[i] then self.name_labels[i]:hide() end
        if self.time_labels[i] then self.time_labels[i]:hide() end
    end
    -- Etykiety nazw i czasu sa kotwiczone wewnatrz natywnego okna.
    -- Warstwa tla zajmuje caly obszar niezaleznie od liczby wierszy,
    -- a stopka pozostaje widoczna i klikalna przy dowolnej wysokosci.
end

-- Mudlet wysyla ten event dla natywnego okna oddzielnie od glownego.
-- Debounce: nie renderuj po kazdym pikselu podczas przeciagania.
U.replace_handler(M,"magia_resize","sysUserWindowResizeEvent",function(_,height,width,name)
    if name~=WINDOW_NAME or not M.win then return end
    M._window_width=tonumber(width) or nil
    if M._resize_timer then pcall(killTimer,M._resize_timer) end
    M._resize_timer=tempTimer(0.07,function()
        M._resize_timer=nil
        if M.win then M:render() end
    end)
end)
return M
