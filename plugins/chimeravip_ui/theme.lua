-- ChimeraVIP 5: theme module.
local WINDOW, HEIGHT = "chimeravip_kondycje", 76
local P = {
    bg="#181C26", soft="#232938", edge="#353C4C", text="#D8DCE6",
    hp="#AC6A78", mp="#5D82A6", zm="#A08C64", neutral="#BDC4CE",
    muted="#AEB6C5", mint="#A8DCC2", blue="#AFCBF4",
    lavender="#C7B9E8", peach="#F2C4A0", rose="#F0A8B8", yellow="#EFD8A6",
}
local EXITS = {
    {"polnocny-zachod","NW"},{"polnoc","N"},{"polnocny-wschod","NE"},
    {"zachod","W"},{"","·"},{"wschod","E"},
    {"poludniowy-zachod","SW"},{"poludnie","S"},{"poludniowy-wschod","SE"},
}
local GAUGES = {
    {"hp","życie","hp"},{"mana","mana","mp"},
    {"fatigue","siły","zm"},{"thirst","pragnienie","blue"},
    {"hunger","głód","mint"},{"encumbrance","obciążenie","peach"},
    {"panic","panika","rose"},{"progress","EXP","lavender"},
}
local BUTTONS = {
    {"⚔","/tryb_ataku","Tryb ataku"},
    {"⬡","/autowsparcie","Autowsparcie"},
    {"➤","/autopogon","Autopogoń"},
    {"♣","/zbieranie","Zbieranie"},
    {"✦","/lampa","Lampa"},
    {"◐","@kolory","Kolorowanie walki"},
    {"⌨","/mbind","MBindy"},
    {"⚙","/cvhud ustawienia","Ustawienia"},
    {"↶","/cvhud oficjalny","Oficjalny HUD"},
}
local function clean(value)
    return tostring(value == nil and "?" or value):gsub("[<>\r]", "")
end
local function alpha(i)
    local out={}
    repeat
        table.insert(out,1,string.char(65+(i-1)%26))
        i=math.floor((i-1)/26)
    until i==0
    return table.concat(out)
end
local function color(name) return P[name] or P.text end
-- Mudlet's rich-text QLabel can ignore CSS foreground color when echo()
-- inserts formatted text. Set the compass foreground inside the text too.
local function compass_html(label,active)
    local shade=active and "#86E7BC" or "#4A5363"
    local body=active and ("<b>"..label.."</b>") or label
    return "<center><font color='"..shade.."'>"..body.."</font></center>"
end
local function style(name)
    return "QLabel { background-color:"..P.soft..";color:"..color(name)
        ..";border:1px solid "..P.edge..";border-radius:4px;"
        .."font-family:'Bitstream Vera Sans Mono';font-size:7pt; }"
        .." QLabel:hover {border-color:"..P.lavender..";}"
end
local function alias(command)
    if type(expandAlias)=="function" then expandAlias(command,false) end
end
local function info(message)
    if type(cecho)=="function" then
        cecho("\n<aquamarine>[ChimeraVIP HUD]<reset> "..message.."\n")
    end
end

local function html_escape(v)
    return tostring(v or ""):gsub("&","&amp;"):gsub("<","&lt;")
        :gsub(">","&gt;"):gsub('"',"&quot;")
end
local PROFILES={s={font=7,height=76,bar=41},m={font=11,height=148,bar=64},xl={font=16,height=164,bar=80}}
local function profile(settings) return PROFILES[settings.rozmiar] or PROFILES.s end
local function upper(value)
    local text=tostring(value)
    for from,to in pairs({["ą"]="Ą",["ć"]="Ć",["ę"]="Ę",["ł"]="Ł",["ń"]="Ń",["ó"]="Ó",["ś"]="Ś",["ź"]="Ź",["ż"]="Ż"}) do
        text=text:gsub(from,to)
    end
    -- Do not run locale-dependent string.upper over UTF-8 continuation bytes.
    return (text:gsub("[a-z]",function(c) return string.char(c:byte()-32) end))
end
return {profile=profile, profiles=PROFILES, upper=upper, html_escape=html_escape, WINDOW=WINDOW, HEIGHT=HEIGHT, P=P, EXITS=EXITS, GAUGES=GAUGES, BUTTONS=BUTTONS,
 clean=clean, alpha=alpha, color=color, compass_html=compass_html, style=style, alias=alias, info=info}
