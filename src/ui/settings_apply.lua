chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util

C.settings_apply = C.settings_apply or {}
local A = C.settings_apply
A.handlers = A.handlers or {}

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function css_family(value)
    value = trim(value)
    value = value:gsub("\\", "\\\\"):gsub('"', '\\"')
    return value
end

function A:style_label(label, size, family)
    if not label or type(label.setStyleSheet) ~= "function" then return end

    local css = "QLabel { background-color: transparent; border: 0px; padding: 0px;"
        .. " font-size: " .. tostring(size) .. "pt;"

    family = trim(family)
    if family ~= "" then css = css .. ' font-family: "' .. css_family(family) .. '";' end
    css = css .. " }"

    pcall(function() label:setStyleSheet(css) end)
end

function A:apply()
    local HUD = C.quiet_footer
    local S = C.settings
    if not HUD or not S then return end

    local main = tonumber(S:get("ui.condition_font_size", 10)) or 10
    main = math.max(8, math.min(12, math.floor(main + 0.5)))
    local small = math.max(6, main - 3)
    local family = tostring(S:get("ui.condition_font_family", "") or "")

    for _, metric in pairs(HUD.metrics or {}) do
        self:style_label(metric.label, main, family)
        self:style_label(metric.value, main, family)
    end

    for _, need in pairs(HUD.needs or {}) do
        self:style_label(need.label, small, family)
        self:style_label(need.value, small, family)
    end

    if HUD.obc then
        self:style_label(HUD.obc.label, small, family)
        self:style_label(HUD.obc.value, small, family)
    end

    self:style_label(HUD.intox, small, family)
    self:style_label(HUD.exp_label, small, family)
    self:style_label(HUD.exp_value, small, family)

    raiseEvent("chimeraVipConditionFontApplied", family, main)
end

if U and U.replace_handler then
    U.replace_handler(A, "footer_ready", "chimeraFooterReady", function()
        tempTimer(0, function() A:apply() end)
    end)

    U.replace_handler(A, "settings_changed", "chimeraVipSettingsChanged", function(_, key)
        key = tostring(key or "")
        if key == "ui.condition_font_family" or key == "ui.condition_font_size" then
            tempTimer(0, function() A:apply() end)
        end
    end)
end

if C.quiet_footer and C.quiet_footer.metrics then tempTimer(0, function() A:apply() end) end

return A
