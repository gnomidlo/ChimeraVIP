-- ChimeraVIP / Settings bindings
-- Adapter dla istniejacych modulow: rejestruje ich ustawienia w centralnym panelu.

chimera_vip = chimera_vip or {}
local C = chimera_vip
local S = C.settings

if not S or type(S.register_setting) ~= "function" then return false end

local COLOR_OPTIONS = {
    "#A8DCC2", -- mint
    "#D8DCE6", -- text
    "#F0A8B8", -- rose
    "#AFCBF4", -- blue
    "#C7B9E8", -- lavender
    "#F2C4A0", -- peach
    "#EFD8A6", -- yellow
}

-- Stary modul sam rejestruje toggle; tutaj nadajemy mu docelowa sekcje Settings 2.0.
if C.characters then
    S:register_module("postacie", {
        title="Postacie",
        description="Rejestr odmian, relacji i kolorowanie nazw.",
        default=true,
        section="characters",
        order=10,
    })
end

S:register_setting("characters_highlight", {
    type="toggle", section="characters", order=20,
    title="Kolorowanie postaci",
    description="Globalnie wlacza lub wylacza kolorowanie zapisanych postaci w tekscie gry.",
    default=true,
    getter=function()
        return C.characters and C.characters.data and C.characters.data.highlight_enabled ~= false
    end,
    setter=function(value)
        if not C.characters or type(C.characters.set_highlight_enabled) ~= "function" then return false end
        C.characters:set_highlight_enabled(value == true)
        return true
    end,
})

local groups = {
    {id="characters_color_friends", group="przyjaciele", title="Kolor przyjaciol", default="#A8DCC2", order=30},
    {id="characters_color_neutral", group="neutralni", title="Kolor neutralnych", default="#D8DCE6", order=40},
    {id="characters_color_enemies", group="wrogowie", title="Kolor wrogow", default="#F0A8B8", order=50},
}

for _, item in ipairs(groups) do
    local group = item.group
    S:register_setting(item.id, {
        type="color", section="characters", order=item.order,
        title=item.title,
        description="Kolor highlightu grupy " .. group .. ". Klikniecie przechodzi po pastelowej palecie ChimeraVIP.",
        default=item.default,
        options=COLOR_OPTIONS,
        getter=function()
            local colors=C.characters and C.characters.data and C.characters.data.colors
            return colors and colors[group] or item.default
        end,
        setter=function(value)
            if not C.characters or type(C.characters.set_color) ~= "function" then return false end
            return C.characters:set_color(group, value)
        end,
    })
end

raiseEvent("chimeraVipSettingsRegistryUpdated")
return true
