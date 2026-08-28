chimera_vip = chimera_vip or {}
local U = chimera_vip.util or {}
chimera_vip.util = U

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
