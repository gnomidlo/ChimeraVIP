chimera_vip = chimera_vip or {}
local U = chimera_vip.util or {}
chimera_vip.util = U

U.default_palette = U.default_palette or {
    background="#12151D", background_soft="#181C26", separator="#2B303C", inactive="#303542",
    text="#D8DCE6", text_muted="#AEB6C5", rose="#F0A8B8", mint="#A8DCC2",
    blue="#AFCBF4", lavender="#C7B9E8", peach="#F2C4A0", yellow="#EFD8A6",
}

function U.palette()
    local C = chimera_vip
    if C and C.pastel_ui and type(C.pastel_ui.colors) == "table" then return C.pastel_ui.colors end
    return U.default_palette
end

function U.trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function U.normalize(value)
    return U.trim(value):lower():gsub("%s+", " ")
end

function U.format_int(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    local sign = ""
    if text:sub(1, 1) == "-" then sign, text = "-", text:sub(2) end
    local result = ""
    while #text > 3 do
        result = " " .. text:sub(-3) .. result
        text = text:sub(1, -4)
    end
    return sign .. text .. result
end

function U.clamp(value, minimum, maximum)
    if type(value) ~= "number" then return nil end
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function U.text_width(value)
    local text = tostring(value or "")
    if utf8 and type(utf8.len) == "function" then
        local ok, length = pcall(utf8.len, text)
        if ok and length then return length end
    end
    return #text
end

function U.pad_right(value, width)
    local text = tostring(value or "")
    local missing = math.max(0, (tonumber(width) or 0) - U.text_width(text))
    return text .. string.rep(" ", missing)
end

function U.deep_copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = U.deep_copy(child) end
    return out
end

function U.merge_defaults(target, defaults)
    target = type(target) == "table" and target or {}
    for key, value in pairs(defaults or {}) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            U.merge_defaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

function U.pcre_escape(value)
    return (tostring(value or ""):gsub("([\\%^%$%.|%?%*%+%(%)%[%]{}])", "\\%1"))
end

function U.transparent_css()
    return [[QLabel { background-color: transparent; border: 0px; padding: 0px; }]]
end

function U.escape_html(text)
    text = tostring(text or "")
    text = text:gsub("&", "&amp;")
    text = text:gsub("<", "&lt;")
    text = text:gsub(">", "&gt;")
    return text
end

function U.short_text(text, max_length)
    text = tostring(text or "")
    if #text <= max_length then return text end
    return text:sub(1, max_length - 1) .. "…"
end

function U.hex_to_rgb(value)
    local hex = tostring(value or ""):match("^#?(%x%x%x%x%x%x)$")
    if not hex then return nil, nil, nil end
    return tonumber(hex:sub(1,2),16), tonumber(hex:sub(3,4),16), tonumber(hex:sub(5,6),16)
end

function U.decho_tag(value)
    local r, g, b = U.hex_to_rgb(value)
    if not r then return "" end
    return string.format("<%d,%d,%d>", r, g, b)
end

function U.gag_line()
    if type(deleteLine) == "function" then
        local ok = pcall(deleteLine)
        if ok then return true end
    end
    local ok = pcall(function()
        selectCurrentLine()
        replace("")
    end)
    return ok
end

function U.clear_triggers(owner)
    if type(owner) ~= "table" then return end
    for _, id in ipairs(owner.trigger_ids or {}) do pcall(killTrigger, id) end
    owner.trigger_ids = {}
end

function U.clear_aliases(owner)
    if type(owner) ~= "table" then return end
    for _, id in ipairs(owner.alias_ids or {}) do pcall(killAlias, id) end
    owner.alias_ids = {}
end

-- Jednolinijkowe, dyskretne akcje pod raportami. Klik prowadzi przez alias,
-- dzieki czemu interfejs tekstowy pozostaje jedynym publicznym API modulu.
function U.action_links(actions)
    if type(actions) ~= "table" or #actions == 0 or type(echoLink) ~= "function" then return end
    local P = U.palette()
    hecho("\n" .. P.text_muted .. "  ")
    for i, action in ipairs(actions) do
        local label = tostring(action.label or action[1] or "")
        local command = tostring(action.command or action[2] or "")
        local hint = tostring(action.hint or action[3] or command)
        if label ~= "" and command ~= "" then
            if i > 1 then hecho(P.text_muted .. "  ") end
            local callback = string.format("expandAlias(%q, false)", command)
            echoLink("[" .. label .. "]", callback, hint, true)
        end
    end
    hecho("\n")
end

function U.replace_handler(owner, name, event, callback)
    owner.handlers = owner.handlers or {}
    if owner.handlers[name] then
        pcall(killAnonymousEventHandler, owner.handlers[name])
    end
    owner.handlers[name] = registerAnonymousEventHandler(event, callback)
    return owner.handlers[name]
end

function U.ensure_dir(path)
    local lfs_ok, lfs = pcall(require, "lfs")
    if not lfs_ok then return false end
    local sep = package.config:sub(1, 1)
    local current = ""
    local prefix = ""
    if path:match("^%a:[/\\]") then
        prefix = path:sub(1, 2) .. sep
        path = path:sub(4)
    elseif path:sub(1, 1) == sep then
        prefix = sep
        path = path:sub(2)
    end
    current = prefix
    for part in path:gmatch("[^/\\]+") do
        if current ~= "" and current:sub(-1) ~= sep then current = current .. sep end
        current = current .. part
        lfs.mkdir(current)
    end
    return true
end

function U.file_exists(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

function U.write_file(path, content)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    if dir then U.ensure_dir(dir) end
    local f, err = io.open(path, "wb")
    if not f then return false, err end
    f:write(content or "")
    f:close()
    return true
end

function U.version_gt(a, b)
    local function split(v)
        local out = {}
        for n in tostring(v or "0"):gmatch("%d+") do out[#out + 1] = tonumber(n) end
        return out
    end
    local aa, bb = split(a), split(b)
    for i = 1, math.max(#aa, #bb) do
        local av, bv = aa[i] or 0, bb[i] or 0
        if av ~= bv then return av > bv end
    end
    return false
end

return U
