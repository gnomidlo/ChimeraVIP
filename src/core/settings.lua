chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
C.settings = C.settings or {}
local S = C.settings

S.data_dir = getMudletHomeDir() .. "/ChimeraVIP-data"
S.data_file = S.data_dir .. "/settings.lua"
S.data = S.data or {}
S.module_defs = S.module_defs or {}
S.defaults = {ui={states_font_size=10},modules={combat_colors=true}}

local function merge_defaults(target,defaults)
    for key,value in pairs(defaults or {}) do
        if type(value)=="table" then if type(target[key])~="table" then target[key]={} end; merge_defaults(target[key],value)
        elseif target[key]==nil then target[key]=value end
    end
end
local function trim(value) return tostring(value or ""):gsub("^%s+",""):gsub("%s+$","") end
local function pad(value,width)
    if U and U.pad_right then return U.pad_right(value,width) end
    local text=tostring(value or ""); return text..string.rep(" ",math.max(0,width-#text))
end
local function text_width(value) if U and U.text_width then return U.text_width(value) end; return #tostring(value or "") end
local function normalize_module_id(id)
    id=trim(id):lower():gsub("%-","_"):gsub("%s+","_")
    local aliases={kolory="combat_colors",walka="combat_colors",combat="combat_colors",combatcolors="combat_colors",kolory_walki="combat_colors",postacie="postacie",characters="postacie"}
    return aliases[id] or id
end

function S:register_module(id,definition)
    id=normalize_module_id(id); if id=="" then return false end; definition=definition or {}
    self.module_defs[id]={id=id,title=tostring(definition.title or id),description=tostring(definition.description or ""),default=definition.default~=false}
    self.defaults.modules=self.defaults.modules or {}; if self.defaults.modules[id]==nil then self.defaults.modules[id]=self.module_defs[id].default end
    if self.data and self.data.modules and self.data.modules[id]==nil then self.data.modules[id]=self.module_defs[id].default; self:save() end
    return true
end
function S:load()
    if U and U.ensure_dir then U.ensure_dir(self.data_dir) end
    local loaded={}
    if U and U.file_exists and U.file_exists(self.data_file) then local ok,err=pcall(table.load,self.data_file,loaded); if not ok then cecho("\n<orange>[ChimeraVIP]<reset> Nie udalo sie wczytac ustawien: "..tostring(err).."\n"); loaded={} end end
    loaded.ui=loaded.ui or {}; if loaded.ui.states_font_size==nil and loaded.ui.condition_font_size~=nil then loaded.ui.states_font_size=loaded.ui.condition_font_size end
    loaded.ui.condition_font_size=nil; loaded.ui.condition_font_family=nil; merge_defaults(loaded,self.defaults)
    loaded.ui.states_font_size=tonumber(loaded.ui.states_font_size) or 10; loaded.ui.states_font_size=math.max(7,math.min(14,math.floor(loaded.ui.states_font_size+0.5)))
    loaded.modules=loaded.modules or {}; loaded.modules.combat_colors=loaded.modules.combat_colors~=false
    self.data=loaded; self:save()
end
function S:save()
    if U and U.ensure_dir then U.ensure_dir(self.data_dir) end
    local ok,err=pcall(table.save,self.data_file,self.data); if not ok then cecho("\n<red>[ChimeraVIP]<reset> Nie udalo sie zapisac ustawien: "..tostring(err).."\n"); return false end; return true
end
function S:get(path,fallback)
    local node=self.data; for part in tostring(path or ""):gmatch("[^%.]+") do if type(node)~="table" then return fallback end; node=node[part]; if node==nil then return fallback end end; return node
end
function S:set(path,value)
    local parts={}; for part in tostring(path or ""):gmatch("[^%.]+") do parts[#parts+1]=part end; if #parts==0 then return false end
    local node=self.data; for i=1,#parts-1 do if type(node[parts[i]])~="table" then node[parts[i]]={} end; node=node[parts[i]] end
    node[parts[#parts]]=value; if not self:save() then return false end; raiseEvent("chimeraVipSettingsChanged",path,value); return true
end
function S:set_states_font_size(size)
    size=tonumber(size); if not size then return false end; size=math.floor(size+0.5)
    if size<7 or size>14 then cecho("\n<yellow>[ChimeraVIP]<reset> Rozmiar czcionki musi byc w zakresie 7-14.\n"); return false end
    if not self:set("ui.states_font_size",size) then return false end
    cecho("\n<aquamarine>[ChimeraVIP]<reset> Rozmiar tekstu okna stanow: "..tostring(size)..".\n"); return true
end
S.set_condition_font_size=S.set_states_font_size
function S:is_module_enabled(id,fallback)
    id=normalize_module_id(id); local value=self.data.modules and self.data.modules[id]
    if value==nil then if fallback~=nil then return fallback==true end; local definition=self.module_defs[id]; if definition then return definition.default~=false end; local default=self.defaults.modules and self.defaults.modules[id]; return default~=false end
    return value==true
end
function S:set_module_enabled(id,enabled)
    id=normalize_module_id(id); if id=="" or not self.module_defs[id] then return false end
    self.data.modules=self.data.modules or {}; self.data.modules[id]=enabled==true; if not self:save() then return false end; raiseEvent("chimeraVipModuleChanged",id,enabled==true); return true
end
function S:toggle_module(id)
    id=normalize_module_id(id); if not self.module_defs[id] then return nil end
    local next_value=not self:is_module_enabled(id); self:set_module_enabled(id,next_value); return next_value
end
function S:show_modules()
    hecho("\n\n#C7B9E8CHIMERAVIP — MODULY\n#2B303C------------------------------------------")
    local ids={}; for id in pairs(self.module_defs) do ids[#ids+1]=id end
    table.sort(ids,function(a,b) return self.module_defs[a].title:lower()<self.module_defs[b].title:lower() end)
    local title_width=0; for _,id in ipairs(ids) do title_width=math.max(title_width,text_width(self.module_defs[id].title)) end; title_width=title_width+2
    for _,id in ipairs(ids) do
        local definition=self.module_defs[id]; local enabled=self:is_module_enabled(id)
        hecho("\n#AEB6C5"..pad(definition.title,title_width)..(enabled and "#A8DCC2ON" or "#F0A8B8OFF"))
        if definition.description~="" then hecho("\n  #AEB6C5"..definition.description) end
    end
    hecho("\n")
end
function S:show()
    if C.settings_panel and type(C.settings_panel.open)=="function" then C.settings_panel:open(); return end
    local size=tonumber(self:get("ui.states_font_size",10)) or 10
    hecho("\n\n#C7B9E8CHIMERAVIP — USTAWIENIA"
        .."\n#2B303C--------------------------------------------------"
        .."\n#AEB6C5Rozmiar tekstu okna stanow   #D8DCE6"..tostring(size)
        .."\n#AEB6C5Dostepne: #D8DCE67  8  9  10  11  12  13  14"
        .."\n\n#AEB6C5Uzyj /cvip ustawienia rozmiar <7-14>."
        .."\n#AEB6C5Moduly: /cvip moduly\n")
end
function S:command(argument)
    local raw=trim(argument); local lower=raw:lower(); if lower=="" then self:show(); return true end
    if lower=="moduly" or lower=="modules" then self:show_modules(); return true end
    local size=lower:match("^rozmiar%s+(%d+)$") or lower:match("^size%s+(%d+)$"); if size then self:set_states_font_size(size); return true end
    local module_id,state=lower:match("^modul%s+(%S+)%s+(%S+)$")
    if module_id and state then
        module_id=normalize_module_id(module_id); local definition=self.module_defs[module_id]
        if not definition then cecho("\n<yellow>[ChimeraVIP]<reset> Nie znam modulu '"..tostring(module_id).."'. Uzyj /cvip moduly.\n"); return true end
        local enabled
        if state=="on" or state=="wlacz" or state=="włącz" or state=="1" then enabled=true
        elseif state=="off" or state=="wylacz" or state=="wyłącz" or state=="0" then enabled=false
        elseif state=="toggle" or state=="przelacz" or state=="przełącz" then enabled=self:toggle_module(module_id)
        else cecho("\n<yellow>[ChimeraVIP]<reset> Uzyj on, off albo toggle.\n"); return true end
        if state~="toggle" and state~="przelacz" and state~="przełącz" then self:set_module_enabled(module_id,enabled) end
        cecho("\n<aquamarine>[ChimeraVIP]<reset> "..definition.title..": "..(enabled and "ON" or "OFF")..".\n"); return true
    end
    cecho("\n<yellow>[ChimeraVIP]<reset> Nieznane ustawienie. Uzyj /cvip ustawienia.\n"); return false
end

S:register_module("combat_colors",{title="Kolory walki",description="Pastelowe prefiksy obrazen zamiast oficjalnego gags.",default=true})
S:load()
return S
