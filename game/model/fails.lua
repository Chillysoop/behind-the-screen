-- Dice jail (M8, B2): a natural 1 on a big roll sends the die to the cup on the table, and
-- everyone laughs. The counts per player stay with the campaign (a die that keeps going back
-- becomes a running joke, game/model/jokes.lua). Pure Lua.

local M = {}

M.JAIL_SOCIAL = 2   -- a natural 1 goes to dice jail: Social for everyone

-- The records kept on the campaign: each player's trips to dice jail.
function M.get(campaign)
    campaign.fails = campaign.fails or { jail = {} }
    return campaign.fails
end

-- A natural 1 goes to dice jail: the die sits in the cup on the table, and everyone laughs.
function M.jail(night, p)
    local f = M.get(night.campaign)
    f.jail[p.key] = (f.jail[p.key] or 0) + 1
    night:apply({ { "all", social = M.JAIL_SOCIAL } })
    night:event("jail", { who = p.key, text = p.name .. "'s d20 goes to dice jail.", weight = 3 })
    night:emit({ kind = "jail", who = p.key })
end

return M
