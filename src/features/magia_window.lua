-- ChimeraVIP 0.192 / Magia: natywne okno Mudleta z zawartoscia Geysera.
-- Geyser.UserWindow jest niezaleznym QDockWidget, nie overlayem main output.
local M=chimera_vip.magia
local U=chimera_vip.util
local function colors() return U.palette() end
local function css(bg,fg,border)
    return "QLabel{background-color:"..bg..";color:"..fg..
        ";border:0px;border-bottom:1px solid "..border..
        ";padding:4px 8px;font-size:11px;font-family:Consolas,monospace;}"
end

function M:show_window()
    if not (Geyser and Geyser.UserWindow and Geyser.Label and Geyser.ScrollBox) then
        hecho("\n"..colors().rose.."[Magia] Brak Geyser.UserWindow — uzyj /magia.\n")
        return false
    end
    if not self.win then
        local ok,window=pcall(function() return Geyser.UserWindow:new({
            name="ChimeraVIP_Magia",titleText="Magia — ChimeraVIP",
            width=415,height=260,docked=false,dockPosition="floating",
            autoDock=true,restoreLayout=true,
        }) end)
        if not ok or not window then
            hecho("\n"..colors().rose.."[Magia] Blad okna: "..tostring(window).."\n")
            return false
        end
        self.win=window
        self.header=Geyser.Label:new({name="CVIP_Magia_Header",x=0,y=0,width="100%",height=38},window)
        self.scan_button=Geyser.Label:new({name="CVIP_Magia_Scan",x=-88,y=4,width=34,height=30},window)
        self.mode_button=Geyser.Label:new({name="CVIP_Magia_Mode",x=-48,y=4,width=34,height=30},window)
        self.body=Geyser.ScrollBox:new({name="CVIP_Magia_Body",
            x=0,y=39,width="100%",height=-72},window)
        self.footer=Geyser.Label:new({name="CVIP_Magia_Footer",
            x=0,y=-31,width="100%",height=31},window)
        self.row_labels={}
        self.header:setClickCallback(function() M:toggle_mode() end)
        self.scan_button:setClickCallback(function() M:scan() end)
        self.mode_button:setClickCallback(function() M:toggle_mode() end)
        self.footer:setClickCallback(function() M:scan() end)
    end
    self.win:show()
    self:render()
    return true
end
function M:hide_window()
    if self.win then self.win:hide() end
end
function M:set_mode(mode)
    self.data.mode=mode=="full" and "full" or "compact"
    self:save()
    self:show_window()
end
function M:toggle_mode()
    self:set_mode(self.data.mode=="full" and "compact" or "full")
end
local function list_rows(self,items)
    local rows={}
    if self.data.mode=="compact" then
        for i=1,math.min(#items,4) do
            local v=items[i]
            rows[#rows+1]={
                text=string.format("%-12s %-11s %s",
                    self.format(v.seconds),v.owner,v.item.name),
                seconds=v.seconds,tooltip=v.owner..": "..v.item.name
            }
        end
    else
        local by_id,order={},{}
        for _,v in ipairs(items) do
            if not by_id[v.id] then by_id[v.id]={};order[#order+1]=v.id end
            by_id[v.id][#by_id[v.id]+1]=v
        end
        table.sort(order,function(a,b)
            if a=="@" then return true end
            if b=="@" then return false end
            return (self.data.owners[a].name or "")<(self.data.owners[b].name or "")
        end)
        for _,id in ipairs(order) do
            rows[#rows+1]={text=(self.data.owners[id].name or "?"):upper(),heading=true}
            for _,v in ipairs(by_id[id]) do
                rows[#rows+1]={text=self.format(v.seconds).."  "..v.item.name,
                    seconds=v.seconds,tooltip=v.owner..": "..v.item.name}
            end
        end
    end
    if #rows==0 then
        rows[1]={text="Brak danych. Kliknij ↻, aby sprawdzic.",heading=true}
    end
    return rows
end
function M:render()
    if not self.win or not self.body then return end
    local P=colors()
    local items=self:rows()
    local rows=list_rows(self,items)
    self.header:setStyleSheet(css(P.background_soft,P.lavender,P.separator))
    self.header:echo("✦ MAGIA")
    for _,label in ipairs({self.scan_button,self.mode_button}) do
        label:setStyleSheet(css(P.background_soft,P.mint,P.separator))
    end
    self.scan_button:echo("↻")
    self.mode_button:echo(self.data.mode=="full" and "▣" or "⛶")
    local latest,present=0,self:present()
    for id,owner in pairs(self.data.owners) do
        if present[id] then latest=math.max(latest,owner.last_scan or 0) end
    end
    self.footer:setStyleSheet(css(P.background_soft,P.text_muted,P.separator))
    self.footer:echo(#items.." przedm.    "..(latest>0 and
        ("Skan: "..os.date("%H:%M",latest)) or "Bez skanu").."  ↻")
    for i,row in ipairs(rows) do
        local label=self.row_labels[i]
        if not label then
            label=Geyser.Label:new({name="CVIP_Magia_Row_"..i,
                x=0,y=(i-1)*29,width="100%",height=29},self.body)
            label:setClickCallback(function() M:toggle_mode() end)
            self.row_labels[i]=label
        end
        label:move(0,(i-1)*29)
        label:setStyleSheet(css(row.heading and P.background_soft or P.background,
            row.heading and P.lavender or self:color(row.seconds),P.separator))
        label:echo(U.escape_html(row.text))
        if row.tooltip then pcall(function() label:setToolTip(row.tooltip) end) end
        label:show()
    end
    for i=#rows+1,#self.row_labels do self.row_labels[i]:hide() end
end
return M
