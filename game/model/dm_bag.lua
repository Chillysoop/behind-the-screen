-- The DM's bag (Conner, November 6): what the DM can tuck where a friend pokes about, in any adventure. Thirty things
-- (game/data/dm_bag.lua), from bits and bobs to strong magic; what's given goes into that hero's pack (items.lua) and
-- is gone from the bag for the rest of the campaign. Offered on a small moment's poke (table_life.lua). Pure Lua.

local util = require "game.model.util"
local items = require "game.model.items"

local M = {}

local function data()
    return require "game.data.dm_bag"
end

-- How many of an entry are left.
function M.left(campaign, e)
    local used = (campaign.dm_bag and campaign.dm_bag.used or {})[e.id] or 0
    return (e.stock or 1) - used
end

-- Everything still in the bag, least to most powerful.
function M.stock(campaign)
    local out = {}
    for _, e in ipairs(data().list) do
        if M.left(campaign, e) > 0 then
            table.insert(out, e)
        end
    end
    local rank = data().RANK
    table.sort(out, function(a, b)
        local ra, rb = rank[a.rarity] or 0, rank[b.rarity] or 0
        if ra ~= rb then
            return ra < rb
        end
        return a.id < b.id
    end)
    return out
end

-- Can this hero use it? A bit or a potion, always; a magic item, if the rules let them (a shield arm, attunement).
function M.fits(campaign, p, e)
    if e.kind ~= "magic" then
        return true
    end
    return items.can_use(campaign, p, e.magic)
end

-- Three to offer for this hero: a bit, something useful (a potion or an uncommon item they can use), and something
-- strong they can use, when the bag still has them.
function M.suggest(campaign, p, rng)
    local rank = data().RANK
    local bits, useful, strong = {}, {}, {}
    for _, e in ipairs(M.stock(campaign)) do
        if M.fits(campaign, p, e) then
            local r = rank[e.rarity] or 0
            if e.kind == "bit" then
                table.insert(bits, e)
            elseif r <= rank.Uncommon then
                table.insert(useful, e)
            else
                table.insert(strong, e)
            end
        end
    end
    local out = {}
    for _, list in ipairs({ bits, useful, strong }) do
        if #list > 0 then
            table.insert(out, rng and rng:pick(list) or list[1])
        end
    end
    return out
end

-- The card line for an entry: its name, and what it is.
function M.label(e)
    return util.capitalize(e.name)
end
function M.sub(e)
    local strong = (data().RANK[e.rarity] or 0) >= data().RANK.Rare
    return e.rarity .. ". " .. (e.text or "") .. (strong and " Strong: fights get easier from here." or "")
end

-- Give it: into the hero's pack (or, for a magic item they can't use, whoever in the party can), out of the bag.
-- Returns the inventory entry and who has it.
function M.give(campaign, p, e)
    if not e or M.left(campaign, e) <= 0 then
        return nil
    end
    campaign.dm_bag = campaign.dm_bag or { used = {} }
    campaign.dm_bag.used = campaign.dm_bag.used or {}
    campaign.dm_bag.used[e.id] = (campaign.dm_bag.used[e.id] or 0) + 1
    local it, who
    if e.kind == "magic" then
        local players = (p and items.can_use(campaign, p, e.magic)) and { p } or campaign.players
        it, who = items.earn(campaign, e.magic, players, "found")
    else
        it = items.give(campaign, e.thing or e.id, p and p.key, "found")
        who = it and it.holder and campaign:player(it.holder)
    end
    return it, who
end

return M
