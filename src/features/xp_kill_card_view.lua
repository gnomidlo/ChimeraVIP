-- ChimeraVIP / XP kill card view
-- Presentation override for compact kill summaries.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
local XP = C.xp_tracker

if not XP then
    error("xp_tracker musi byc zaladowany przed xp_kill_card_view")
end

local format_integer = U and U.format_int or function(value)
    return tostring(math.floor(tonumber(value) or 0))
end

function XP:show_kill_card(raw_mob, amount, killer, own)
    local Cc = self.colors
    local mob_name, killer_name = self:get_kill_card_context(raw_mob, killer, own)
    self:prune_pending_rewards(os.time())

    local function reward_row(xp, name, name_color)
        local xp_text = "+" .. format_integer(xp) .. " xp"
        hecho("\n" .. Cc.yellow .. string.format("%11s", xp_text) .. "  " .. (name_color or Cc.text) .. name)
    end

    hecho("\n" .. Cc.separator .. "-------------------------")
    hecho("\n" .. Cc.peach .. string.upper(mob_name) .. Cc.text_muted .. " GRYZIE PIACH")
    hecho("\n" .. Cc.text_muted .. "Dobija: " .. Cc.lavender .. killer_name)
    reward_row(amount, "TY", Cc.mint)
    for _, reward in ipairs(self.pending_rewards) do
        reward_row(reward.xp, reward.name, Cc.text)
    end
    hecho("\n" .. Cc.separator .. "-------------------------")
    self:clear_pending_rewards()
end

return XP
