-- ChimeraVIP / Combat Colors
-- Pastelowe prefiksy sily obrazen na podstawie kolorow ANSI Chimery.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
local legacy_damage = rawget(_G, "chimera_damage")

C.combat_colors = C.combat_colors or {}
chimera_overlay.combat_colors = C.combat_colors
local D = C.combat_colors
D.handlers = D.handlers or {}

if legacy_damage and legacy_damage ~= D then
    for _, id in ipairs(legacy_damage.damage_triggers or {}) do pcall(killTrigger, id) end
    if legacy_damage.learn_trigger then pcall(killTrigger, legacy_damage.learn_trigger) end
end

chimera_damage = D

D.min_line_length = 50
D.damage_triggers = D.damage_triggers or {}
D.learned_colors = D.learned_colors or {}
D.sync_timer = D.sync_timer or nil
D.enabled = D.enabled ~= false

D.defaults = {
    zadane_brak = -1,
    zadane_niskie = 176,
    zadane_srednie = 169,
    zadane_wysokie = 160,

    otrzymane_brak = -1,
    otrzymane_niskie = 225,
    otrzymane_srednie = 203,
    otrzymane_wysokie = 196,

    innych_zadane_brak = -1,
    innych_zadane_niskie = 108,
    innych_zadane_srednie = 71,
    innych_zadane_wysokie = 34,

    innych_otrzymane_brak = -1,
    innych_otrzymane_niskie = 180,
    innych_otrzymane_srednie = 173,
    innych_otrzymane_wysokie = 166,
}

D.order = {
    "zadane_brak", "zadane_niskie", "zadane_srednie", "zadane_wysokie",
    "otrzymane_brak", "otrzymane_niskie", "otrzymane_srednie", "otrzymane_wysokie",
    "innych_zadane_brak", "innych_zadane_niskie", "innych_zadane_srednie", "innych_zadane_wysokie",
    "innych_otrzymane_brak", "innych_otrzymane_niskie", "innych_otrzymane_srednie", "innych_otrzymane_wysokie",
}

D.prefix_colors = {
    muted = "174,182,197",
    mint = "168,220,194",
    blue = "175,203,244",
    lavender = "199,185,232",
    yellow = "239,216,166",
    peach = "242,196,160",
    rose = "240,168,184",
}

D.definitions = {
    zadane_brak = { level = "0/3", color = "mint" },
    zadane_niskie = { level = "1/3", color = "mint" },
    zadane_srednie = { level = "2/3", color = "blue" },
    zadane_wysokie = { level = "3/3", color = "lavender" },

    otrzymane_brak = { level = "0/3", color = "mint" },
    otrzymane_niskie = { level = "1/3", color = "yellow" },
    otrzymane_srednie = { level = "2/3", color = "peach" },
    otrzymane_wysokie = { level = "3/3", color = "rose" },

    innych_zadane_brak = { level = "0/3", color = "mint" },
    innych_zadane_niskie = { level = "1/3", color = "mint" },
    innych_zadane_srednie = { level = "2/3", color = "blue" },
    innych_zadane_wysokie = { level = "3/3", color = "lavender" },

    innych_otrzymane_brak = { level = "0/3", color = "mint" },
    innych_otrzymane_niskie = { level = "1/3", color = "yellow" },
    innych_otrzymane_srednie = { level = "2/3", color = "peach" },
    innych_otrzymane_wysokie = { level = "3/3", color = "rose" },
}

local data_dir = getMudletHomeDir() .. "/ChimeraVIP-data"
D.storage_path = data_dir .. "/combat_colors.lua"
D.legacy_storage_path = getMudletHomeDir() .. "/chimera_damage_colors.lua"
D.game_colors = D.game_colors or {}

function D:disable_legacy_package_triggers()
    if type(disableTrigger) ~= "function" then return end
    local names = {
        "CHIMERA+ obrazenia - zadane 0/3",
        "CHIMERA+ obrazenia - zadane 1/3",
        "CHIMERA+ obrazenia - zadane 2/3",
        "CHIMERA+ obrazenia - zadane 3/3",
        "CHIMERA+ obrazenia - otrzymane 0/3",
        "CHIMERA+ obrazenia - otrzymane 1/3",
        "CHIMERA+ obrazenia - otrzymane 2/3",
        "CHIMERA+ obrazenia - otrzymane 3/3",
    }
    for _, name in ipairs(names) do pcall(disableTrigger, name) end
end

function D:save_colors()
    U.ensure_dir(data_dir)
    local ok, err = pcall(table.save, self.storage_path, self.game_colors)
    if not ok then
        cecho("\n<red>[ChimeraVIP]<reset> Nie udalo sie zapisac kolorow walki: " .. tostring(err) .. "\n")
        return false
    end
    return true
end

function D:load_colors()
    self.game_colors = {}
    for key, value in pairs(self.defaults) do self.game_colors[key] = value end

    U.ensure_dir(data_dir)
    local source = nil
    if U.file_exists(self.storage_path) then
        source = self.storage_path
    elseif U.file_exists(self.legacy_storage_path) then
        source = self.legacy_storage_path
    end

    if not source then return end

    local saved = {}
    local ok, err = pcall(table.load, source, saved)
    if not ok then
        cecho("\n<orange>[ChimeraVIP]<reset> Nie udalo sie wczytac kolorow walki: " .. tostring(err) .. "\n")
        return
    end

    for key, value in pairs(saved) do
        local n = tonumber(value)
        if self.defaults[key] ~= nil and n and (n == -1 or (n >= 0 and n <= 255)) then
            self.game_colors[key] = n
        end
    end

    if source == self.legacy_storage_path and self:save_colors() then
        cecho("\n<light_grey>[ChimeraVIP]<reset> Przeniesiono ustawienia kolorow walki do ChimeraVIP-data.\n")
    end
end

function D:is_eligible_line()
    if not self.enabled then return false end

    local current_line = tostring(line or "")

    if current_line:match("^%s*zadane_")
        or current_line:match("^%s*otrzymane_")
        or current_line:match("^%s*innych_zadane_")
        or current_line:match("^%s*innych_otrzymane_")
    then
        return false
    end

    local length = U.text_width(current_line)
    if length < self.min_line_length then return false end
    if not current_line:find("[A-Za-z]") then return false end

    return true
end

function D:show_prefix(key)
    if not self:is_eligible_line() then return end

    local definition = self.definitions[key]
    if not definition then return end

    if tostring(key):match("^otrzymane_") then
        raiseEvent("chimeraVipIncomingHit", key, tostring(line or ""))
    end

    local prefix_color = self.prefix_colors[definition.color]
    if not prefix_color then return end

    prefix(
        "<" .. self.prefix_colors.muted .. ">["
        .. "<" .. prefix_color .. ">" .. definition.level
        .. "<" .. self.prefix_colors.muted .. ">]"
        .. "<r> ",
        decho
    )
end

D.showPrefix = D.show_prefix

function D:clear_damage_triggers()
    for _, trigger_id in ipairs(self.damage_triggers or {}) do
        if trigger_id then pcall(killTrigger, trigger_id) end
    end
    self.damage_triggers = {}
end

function D:remove_learn_trigger()
    if self.learn_trigger then pcall(killTrigger, self.learn_trigger) end
    self.learn_trigger = nil
end

function D:create_learn_trigger()
    self:remove_learn_trigger()
    if not self.enabled then return end

    local keys = table.concat(self.order, "|")
    self.learn_trigger = tempRegexTrigger(
        "^\\s*(" .. keys .. ")\\s+(-?\\d+)\\s+(?:przyklad.*|\\(bez koloru\\).*)$",
        [[chimera_damage:learn_color(matches[2], matches[3])]]
    )
end

function D:rebuild_damage_triggers()
    self:clear_damage_triggers()
    if not self.enabled then return end

    local used_colors = {}

    for _, key in ipairs(self.order) do
        local ansi = tonumber(self.game_colors[key])
        local definition = self.definitions[key]

        if ansi and ansi >= 0 and ansi <= 255 and definition then
            local previous_key = used_colors[ansi]

            if not previous_key then
                local code = string.format([[chimera_damage:show_prefix(%q)]], key)
                local ok, trigger_id = pcall(tempAnsiColorTrigger, ansi, -2, code)

                if ok and trigger_id then
                    self.damage_triggers[#self.damage_triggers + 1] = trigger_id
                    used_colors[ansi] = key
                else
                    cecho("\n<red>[ChimeraVIP]<reset> Nie udalo sie utworzyc triggera " .. key
                        .. " (ANSI " .. tostring(ansi) .. ").\n")
                end
            else
                local previous = self.definitions[previous_key]
                if previous and (previous.level ~= definition.level or previous.color ~= definition.color) then
                    cecho("\n<yellow>[ChimeraVIP]<reset> ANSI " .. tostring(ansi)
                        .. " jest przypisany jednoczesnie do " .. previous_key .. " i " .. key
                        .. "; sam kolor nie pozwala ich rozroznic.\n")
                end
            end
        end
    end
end

D.rebuildDamageTriggers = D.rebuild_damage_triggers
D.clearDamageTriggers = D.clear_damage_triggers

function D:finish_learning()
    self.sync_timer = nil
    if not self.enabled then
        self.learned_colors = {}
        return
    end

    self:save_colors()
    self:rebuild_damage_triggers()

    local learned = 0
    for _, key in ipairs(self.order) do
        if self.learned_colors[key] then learned = learned + 1 end
    end

    if learned > 0 then
        cecho("\n<aquamarine>[ChimeraVIP]<reset> Kolory walki zsynchronizowane ("
            .. tostring(learned) .. "/" .. tostring(#self.order) .. ").\n")
    end

    self.learned_colors = {}
    raiseEvent("chimeraVipCombatColorsUpdated", self.game_colors)
end

function D:schedule_finish_learning()
    if not self.enabled then return end
    if self.sync_timer then pcall(killTimer, self.sync_timer) end
    self.sync_timer = tempTimer(0.25, function() D:finish_learning() end)
end

function D:learn_color(key, ansi)
    if not self.enabled then return end

    ansi = tonumber(ansi)
    if self.defaults[key] == nil or not ansi then return end
    if ansi ~= -1 and (ansi < 0 or ansi > 255) then return end

    self.game_colors[key] = ansi
    self.learned_colors[key] = true
    self:schedule_finish_learning()
end

D.learnColor = D.learn_color

function D:apply_enabled(enabled)
    enabled = enabled == true
    self.enabled = enabled

    if enabled then
        self:disable_legacy_package_triggers()
        self:create_learn_trigger()
        self:rebuild_damage_triggers()
    else
        if self.sync_timer then pcall(killTimer, self.sync_timer) end
        self.sync_timer = nil
        self.learned_colors = {}
        self:remove_learn_trigger()
        self:clear_damage_triggers()
    end

    raiseEvent("chimeraVipCombatColorsStateChanged", enabled)
end

U.replace_handler(D, "module_changed", "chimeraVipModuleChanged", function(_, id, enabled)
    if tostring(id) == "combat_colors" then D:apply_enabled(enabled == true) end
end)

D:load_colors()

local start_enabled = true
if C.settings and type(C.settings.is_module_enabled) == "function" then
    start_enabled = C.settings:is_module_enabled("combat_colors", true)
end
D:apply_enabled(start_enabled)

raiseEvent("chimeraVipCombatColorsReady", D.game_colors, D.enabled)

return D
