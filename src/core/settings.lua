chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util

C.settings = C.settings or {}
local S = C.settings

S.data_dir = getMudletHomeDir() .. "/ChimeraVIP-data"
S.data_file = S.data_dir .. "/settings.lua"
S.data = S.data or {}

S.defaults = {
    ui = {
        condition_font_family = "",
        condition_font_size = 10,
    },
    modules = {
        combat_colors = true,
    },
}

local function deep_copy(source)
    local out = {}
    for key, value in pairs(source or {}) do
        if type(value) == "table" then out[key] = deep_copy(value) else out[key] = value end
    end
    return out
end

local function merge_defaults(target, defaults)
    for key, value in pairs(defaults or {}) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            merge_defaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function unquote(value)
    value = trim(value)
    if #value >= 2 then
        local first, last = value:sub(1, 1), value:sub(-1)
        if (first == '"' and last == '"') or (first == "'" and last == "'") then
            value = value:sub(2, -2)
        end
    end
    return trim(value)
end

local function normalize_module_id(id)
    id = trim(id):lower():gsub("%-", "_"):gsub("%s+", "_")
    local aliases = {
        kolory = "combat_colors",
        walka = "combat_colors",
        combat = "combat_colors",
        combatcolors = "combat_colors",
        kolory_walki = "combat_colors",
    }
    return aliases[id] or id
end

function S:load()
    if U and U.ensure_dir then U.ensure_dir(self.data_dir) end

    local loaded = {}
    if U and U.file_exists and U.file_exists(self.data_file) then
        local ok, err = pcall(table.load, self.data_file, loaded)
        if not ok then
            cecho("\n<orange>[ChimeraVIP]<reset> Nie udalo sie wczytac ustawien: " .. tostring(err) .. "\n")
            loaded = {}
        end
    end

    merge_defaults(loaded, self.defaults)

    loaded.ui.condition_font_family = tostring(loaded.ui.condition_font_family or "")
    loaded.ui.condition_font_size = tonumber(loaded.ui.condition_font_size) or 10
    loaded.ui.condition_font_size = math.max(8, math.min(11, math.floor(loaded.ui.condition_font_size + 0.5)))
    loaded.modules.combat_colors = loaded.modules.combat_colors ~= false

    self.data = loaded
    self:save()
end

function S:save()
    if U and U.ensure_dir then U.ensure_dir(self.data_dir) end
    local ok, err = pcall(table.save, self.data_file, self.data)
    if not ok then
        cecho("\n<red>[ChimeraVIP]<reset> Nie udalo sie zapisac ustawien: " .. tostring(err) .. "\n")
        return false
    end
    return true
end

function S:get(path, fallback)
    local node = self.data
    for part in tostring(path or ""):gmatch("[^%.]+") do
        if type(node) ~= "table" then return fallback end
        node = node[part]
        if node == nil then return fallback end
    end
    return node
end

function S:set(path, value)
    local parts = {}
    for part in tostring(path or ""):gmatch("[^%.]+") do parts[#parts + 1] = part end
    if #parts == 0 then return false end

    local node = self.data
    for i = 1, #parts - 1 do
        if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
        node = node[parts[i]]
    end
    node[parts[#parts]] = value

    if not self:save() then return false end
    raiseEvent("chimeraVipSettingsChanged", path, value)
    return true
end

function S:is_module_enabled(id, fallback)
    id = normalize_module_id(id)
    local value = self.data.modules and self.data.modules[id]
    if value == nil then
        if fallback ~= nil then return fallback == true end
        local default = self.defaults.modules and self.defaults.modules[id]
        return default ~= false
    end
    return value == true
end

function S:set_module_enabled(id, enabled)
    id = normalize_module_id(id)
    if id == "" then return false end
    self.data.modules = self.data.modules or {}
    self.data.modules[id] = enabled == true
    if not self:save() then return false end
    raiseEvent("chimeraVipModuleChanged", id, enabled == true)
    return true
end

function S:toggle_module(id)
    id = normalize_module_id(id)
    local next_value = not self:is_module_enabled(id, true)
    self:set_module_enabled(id, next_value)
    return next_value
end

function S:show_modules()
    local enabled = self:is_module_enabled("combat_colors", true)
    hecho("\n\n#C7B9E8CHIMERAVIP — MODULY"
        .. "\n#2B303C------------------------------------------"
        .. "\n#AEB6C5Kolory walki       " .. (enabled and "#A8DCC2ON" or "#F0A8B8OFF")
        .. "\n#AEB6C5  ON  = prefiksy ChimeraVIP, oficjalny gags wylaczony"
        .. "\n#AEB6C5  OFF = prefiksy usuniete, oficjalny gags wlaczony")
end

function S:show()
    local family = trim(self:get("ui.condition_font_family", ""))
    local size = tonumber(self:get("ui.condition_font_size", 10)) or 10
    local combat = self:is_module_enabled("combat_colors", true)

    if family == "" then family = "domyslna Mudleta" end

    hecho("\n\n#C7B9E8CHIMERAVIP — USTAWIENIA"
        .. "\n#2B303C--------------------------------------------------"
        .. "\n#AEB6C5Okno kondycji"
        .. "\n  #AEB6C5czcionka   #D8DCE6" .. family
        .. "\n  #AEB6C5rozmiar    #D8DCE6" .. tostring(size)
        .. "\n\n#AEB6C5Moduly"
        .. "\n  #AEB6C5kolory walki   " .. (combat and "#A8DCC2ON" or "#F0A8B8OFF")
        .. "\n#2B303C--------------------------------------------------"
        .. "\n#D8DCE6/cvip ustawienia czcionka <nazwa>"
        .. "\n#D8DCE6/cvip ustawienia czcionka domyslna"
        .. "\n#D8DCE6/cvip ustawienia rozmiar <8-11>"
        .. "\n#D8DCE6/cvip ustawienia moduly"
        .. "\n#D8DCE6/cvip ustawienia modul kolory on|off|toggle")
end

function S:command(argument)
    local raw = trim(argument)
    local lower = raw:lower()

    if lower == "" then self:show(); return true end
    if lower == "moduly" or lower == "modules" then self:show_modules(); return true end

    local family = raw:match("^[Cc][Zz][Cc][Ii][Oo][Nn][Kk][Aa]%s+(.+)$")
    if family then
        family = unquote(family)
        local f_lower = family:lower()
        if f_lower == "domyslna" or f_lower == "domyslny" or f_lower == "default" or f_lower == "system" then family = "" end
        self:set("ui.condition_font_family", family)
        cecho("\n<aquamarine>[ChimeraVIP]<reset> Czcionka okna kondycji: " .. (family ~= "" and family or "domyslna Mudleta") .. ".\n")
        return true
    end

    local size = lower:match("^rozmiar%s+(%d+)$") or lower:match("^size%s+(%d+)$")
    if size then
        size = tonumber(size)
        if size < 8 or size > 11 then
            cecho("\n<yellow>[ChimeraVIP]<reset> Rozmiar czcionki musi byc w zakresie 8-11.\n")
            return true
        end
        self:set("ui.condition_font_size", size)
        cecho("\n<aquamarine>[ChimeraVIP]<reset> Rozmiar czcionki okna kondycji: " .. tostring(size) .. ".\n")
        return true
    end

    local module_id, state = lower:match("^modul%s+(%S+)%s+(%S+)$")
    if module_id and state then
        module_id = normalize_module_id(module_id)
        if module_id ~= "combat_colors" then
            cecho("\n<yellow>[ChimeraVIP]<reset> Nie znam modulu '" .. tostring(module_id) .. "'.\n")
            return true
        end

        local enabled
        if state == "on" or state == "wlacz" or state == "włącz" or state == "1" then enabled = true
        elseif state == "off" or state == "wylacz" or state == "wyłącz" or state == "0" then enabled = false
        elseif state == "toggle" or state == "przelacz" or state == "przełącz" then enabled = self:toggle_module(module_id)
        else
            cecho("\n<yellow>[ChimeraVIP]<reset> Uzyj on, off albo toggle.\n")
            return true
        end

        if state ~= "toggle" and state ~= "przelacz" and state ~= "przełącz" then self:set_module_enabled(module_id, enabled) end
        cecho("\n<aquamarine>[ChimeraVIP]<reset> Kolory walki: " .. (enabled and "ON" or "OFF") .. ".\n")
        return true
    end

    cecho("\n<yellow>[ChimeraVIP]<reset> Nieznane ustawienie. Uzyj /cvip ustawienia.\n")
    return false
end

S:load()

return S
