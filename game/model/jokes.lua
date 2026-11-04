-- Running jokes (M8, B5): a die that keeps going to dice jail (game/model/fails.lua) becomes
-- one, and the report says so the night it's born. They're kept with the campaign. Pure Lua.

local M = {}

function M.list(campaign)
    campaign.jokes = campaign.jokes or {}
    return campaign.jokes
end

-- After the night: tonight's moments that became running jokes (two a night at most). Returns
-- the new ones. One dice-jail joke per player: "Jess's d20 is a repeat offender".
function M.after_night(campaign, night)
    local list = M.list(campaign)
    local new = {}
    local have = {}
    for _, j in ipairs(list) do
        have[j.text] = true
    end
    local jailed = {}
    for _, e in ipairs(night.ledger or {}) do
        if e.ev == "jail" then
            local text
            local n = (campaign.fails and campaign.fails.jail and campaign.fails.jail[e.who]) or 0
            if n >= 2 and not jailed[e.who] then
                local p = campaign:player(e.who)
                text = p and (p.name .. "'s d20 is a repeat offender") or nil
                jailed[e.who] = true
            end
            if text and not have[text] and #new < 2 then
                local j = { text = text, born = campaign.week, uses = 0, who = e.who, origin = e.ev }
                table.insert(list, j)
                table.insert(new, j)
                have[text] = true
            end
        end
    end
    return new
end

return M
