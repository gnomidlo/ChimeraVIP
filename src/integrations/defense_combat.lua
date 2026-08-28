-- ChimeraVIP / Defense Tracker <-> Combat Colors
-- Klasyfikuje semantyke linii otrzymanej przed zapisaniem jej jako trafienie.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local I = C.defense_combat_integration or {}
C.defense_combat_integration = I
chimera_overlay.defense_combat_integration = I

local function trim(s)
    return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalize(s)
    return trim(s):lower():gsub("%s+", " ")
end

local function tail_after(raw, pattern)
    local lower = tostring(raw or ""):lower()
    local _, finish = lower:find(pattern)
    if not finish then return nil end
    local tail = trim(tostring(raw):sub(finish + 1))
    tail = tail:gsub("^[%s,:%-]+", ""):gsub("[%.%!%?]+$", "")
    return trim(tail)
end

function I:classify_defense(raw_line)
    local D = C.defense_tracker
    if not D or type(D.add_event) ~= "function" then return false end

    local raw = tostring(raw_line or "")
    local s = normalize(raw)

    if s:find("lecz tobie udaje sie oslonic", 1, true) then
        local item = tail_after(raw, "lecz%s+tobie%s+udaje%s+sie%s+oslonic%s*") or ""
        D:add_event("block", item, raw)
        return true
    end
    if s:find("lecz udaje ci sie oslonic", 1, true) then
        local item = tail_after(raw, "lecz%s+udaje%s+ci%s+sie%s+oslonic%s*") or ""
        D:add_event("block", item, raw)
        return true
    end

    if s:find("lecz tobie udaje sie zbic je z lini ataku", 1, true)
        or s:find("lecz tobie udaje sie zbic je z linii ataku", 1, true)
    then
        local item = tail_after(raw, "lecz%s+tobie%s+udaje%s+sie%s+zbic%s+je%s+z%s+linii?%s+ataku%s*") or ""
        D:add_event("parry", item, raw)
        return true
    end
    if s:find("lecz tobie udaje je zbic z lini ataku", 1, true)
        or s:find("lecz tobie udaje je zbic z linii ataku", 1, true)
    then
        local item = tail_after(raw, "lecz%s+tobie%s+udaje%s+je%s+zbic%s+z%s+linii?%s+ataku%s*") or ""
        D:add_event("parry", item, raw)
        return true
    end
    if s:find("lecz tobie udaje sie go sparowac", 1, true) then
        local item = tail_after(raw, "lecz%s+tobie%s+udaje%s+sie%s+go%s+sparowac%s*") or ""
        D:add_event("parry", item, raw)
        return true
    end

    if s:find("lecz tobie udaje sie uniknac tego ciosu", 1, true) then
        D:add_event("dodge", nil, raw)
        return true
    end

    if s:find("nie udaje sie trafic ciebie", 1, true) then
        D:add_event("miss", nil, raw)
        return true
    end

    if s:find("lecz caly impet uderzenia wyparowany zostaje przez", 1, true) then
        local item = tail_after(raw, "lecz%s+caly%s+impet%s+uderzenia%s+wyparowany%s+zostaje%s+przez%s*") or ""
        D:add_event("armor", item, raw)
        return true
    end

    return false
end

function I:install()
    local CC = C.combat_colors
    if not CC then return false end

    function CC:show_prefix(key)
        local definition = self.definitions and self.definitions[key]
        if not definition then return end

        local raw_line = tostring(line or "")

        if tostring(key):match("^otrzymane_") then
            local defended = I:classify_defense(raw_line)
            if not defended then
                raiseEvent("chimeraVipIncomingHit", key, raw_line)
            end
        end

        if not self:is_eligible_line() then return end

        local prefix_color = self.prefix_colors and self.prefix_colors[definition.color]
        if not prefix_color then return end

        prefix(
            "<" .. self.prefix_colors.muted .. ">["
            .. "<" .. prefix_color .. ">" .. definition.level
            .. "<" .. self.prefix_colors.muted .. ">]"
            .. "<r> ",
            decho
        )
    end

    CC.showPrefix = CC.show_prefix
    return true
end

I:install()

return I
