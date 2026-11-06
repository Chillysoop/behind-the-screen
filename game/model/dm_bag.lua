-- The DM's bag (Conner, November 6): what the DM can tuck where a friend pokes about, in any adventure. Thirty things
-- (game/data/dm_bag.lua), from bits and bobs to strong magic; what's given goes into that hero's pack (items.lua) and
-- is gone from the bag for the rest of the campaign. Offered on a small moment's poke (table_life.lua). Pure Lua.

local util = require "game.model.util"
local items = require "game.model.items"

local M = {}

local function data()
    return require "game.data.dm_bag"
end

local function state(campaign)
    campaign.dm_bag = campaign.dm_bag or {}
    campaign.dm_bag.used = campaign.dm_bag.used or {}
    campaign.dm_bag.books = campaign.dm_bag.books or {}
    return campaign.dm_bag
end

-- How many of an entry are left.
function M.left(campaign, e)
    local used = (campaign.dm_bag and campaign.dm_bag.used or {})[e.id] or 0
    return (e.stock or 1) - used
end

-- In the bag yet: from the start, or its book has been read.
function M.unlocked(campaign, e)
    return not e.book or ((campaign.dm_bag and campaign.dm_bag.books) or {})[e.book] ~= nil
end

-- The books: read already, and whether one can be read now (its book before it read, and an hour of prep left).
function M.read_already(campaign, book_id)
    return ((campaign.dm_bag and campaign.dm_bag.books) or {})[book_id] ~= nil
end
function M.can_read(campaign, prep, book_id)
    local b = data().book_by_id[book_id]
    if not b or M.read_already(campaign, book_id) then
        return false
    end
    if b.needs and not M.read_already(campaign, b.needs) then
        return false
    end
    return prep ~= nil and prep:left() >= data().READ_COST
end
-- Read it: an hour of prep, and what it describes is in the bag from now on. Returns the entries it added.
function M.read(campaign, prep, book_id)
    if not M.can_read(campaign, prep, book_id) then
        return nil
    end
    prep.extra = (prep.extra or 0) + data().READ_COST
    state(campaign).books[book_id] = campaign.week or 0
    local added = {}
    for _, e in ipairs(data().list) do
        if e.book == book_id then
            table.insert(added, e)
        end
    end
    return added
end

-- Everything still in the bag, least to most powerful.
function M.stock(campaign)
    local out = {}
    for _, e in ipairs(data().list) do
        if M.unlocked(campaign, e) and M.left(campaign, e) > 0 then
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

-- Out of the bag and into someone's pockets (the person sheet, npcs.lua), or back into the bag.
function M.take(campaign, e)
    if not e or M.left(campaign, e) <= 0 or not M.unlocked(campaign, e) then
        return false
    end
    local st = state(campaign)
    st.used[e.id] = (st.used[e.id] or 0) + 1
    return true
end
function M.put_back(campaign, e)
    local st = state(campaign)
    if e and (st.used[e.id] or 0) > 0 then
        st.used[e.id] = st.used[e.id] - 1
    end
end

-- A thing from the bag reaching the party some other way (off someone it was put on): into a pack. The bag already
-- counted it out.
function M.hand_over(campaign, p, e)
    if e.kind == "magic" then
        local players = (p and items.can_use(campaign, p, e.magic)) and { p } or campaign.players
        local it, who = items.earn(campaign, e.magic, players, "found")
        -- (Nobody at the table can use it: whoever found it carries it anyway, never nobody.)
        if it and not it.holder then
            local q = p or (campaign.players or {})[1]
            it.holder = q and q.key
            who = q
        end
        return it, who
    end
    local it = items.give(campaign, e.thing or e.id, p and p.key, "found")
    return it, it and it.holder and campaign:player(it.holder)
end

-- Give it: into the hero's pack (or, for a magic item they can't use, whoever in the party can), out of the bag.
-- Returns the inventory entry and who has it.
function M.give(campaign, p, e)
    if not e or M.left(campaign, e) <= 0 then
        return nil
    end
    local st = state(campaign)
    st.used[e.id] = (st.used[e.id] or 0) + 1
    return M.hand_over(campaign, p, e)
end

return M
