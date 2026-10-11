-- New books (A13). Sourcebooks come out on their week; the group chat says so; reading the newest
-- one is the "new supplement" evening, and each reading pulls in up to books.PULLS entries:
-- monsters (a cast card, and the stat block in the encounter builder), magic items (a reward
-- card; earned, someone carries it and the rules apply it: game/model/items.lua), places and
-- hooks (deck cards), and published adventures (whole scenes for prep). What's not pulled stays
-- on the shelf. Pure Lua. Data: game/data/books.lua.
--
-- campaign.books = {
--   arrived = { [book] = week },  pulled = { [entry] = week },  readings = n,
--   bestiary = { [monster] = week },  modules = { [module] = week },
-- }

local content = require "game.model.content"
local score = require "game.model.score"
local util = require "game.model.util"

local M = {}

function M.data()
    return content.books
end

function M.get(campaign)
    campaign.books = campaign.books or { arrived = {}, pulled = {}, bestiary = {}, modules = {}, readings = 0 }
    local b = campaign.books
    b.arrived, b.pulled, b.bestiary, b.modules = b.arrived or {}, b.pulled or {}, b.bestiary or {}, b.modules or {}
    b.readings = b.readings or 0
    return b
end

function M.book(id)
    return content.books.books[id]
end

function M.entry(id)
    return content.book_entries[id]
end

-- Start of a week: any book due comes out, and the player who'd be most excited posts about it.
-- Returns the books that arrived.
function M.arrive(campaign, msgs)
    local st = M.get(campaign)
    local out = {}
    for _, id in ipairs(content.books.order) do
        local bk = M.book(id)
        if not st.arrived[id] and (campaign.week or 1) >= bk.week then
            st.arrived[id] = campaign.week
            table.insert(out, id)
            if msgs then
                local who, line
                for _, p in ipairs(campaign.players) do
                    if not p.on_break then
                        local l = bk.announce[p.primary]
                        if l and not who then
                            who, line = p, l
                        end
                    end
                end
                if not who then
                    for _, p in ipairs(campaign.players) do
                        if not p.on_break and not who then
                            who, line = p, bk.announce.default
                        end
                    end
                end
                if who then
                    table.insert(msgs, { who = who.name, key = who.key, text = line, book = id })
                end
            end
        end
    end
    return out
end

-- What's left on a book's shelf.
function M.left(campaign, book_id)
    local st = M.get(campaign)
    local n = 0
    for _, e in ipairs(M.book(book_id).entries) do
        if not st.pulled[e.id] then
            n = n + 1
        end
    end
    return n
end

-- The newest book that's out and still has something on the shelf.
function M.newest(campaign)
    local st = M.get(campaign)
    local best
    for _, id in ipairs(content.books.order) do
        if st.arrived[id] and M.left(campaign, id) > 0 then
            best = id
        end
    end
    return best
end

-- Who at the table would light up at this page (and who wouldn't want it: a line or veil).
function M.excited(campaign, entry)
    local out = {}
    for _, p in ipairs(campaign.players) do
        if not p.on_break and (util.contains(entry.excites or {}, p.primary) or util.contains(entry.excites or {}, p.secondary)) then
            table.insert(out, p)
        end
    end
    return out
end

function M.uneasy(campaign, entry)
    local card = entry.card and content.components[entry.card.id]
    if not card or not campaign.table then
        return {}
    end
    local out = {}
    for _, f in ipairs(require("game.model.social").content_flags(campaign, { card })) do
        local p = campaign:player(f.key)
        if p then
            table.insert(out, { player = p, kind = f.kind, tag = f.tag })
        end
    end
    return out
end

-- A reading: the book, pulls left, what was pulled (on prep, for this week).
function M.start(campaign, prep, book_id)
    book_id = book_id or M.newest(campaign)
    if not book_id then
        return nil
    end
    local st = M.get(campaign)
    st.readings = st.readings + 1
    local r = { book = book_id, left = content.books.PULLS, pulled = {} }
    if prep then
        prep.reading = r
    end
    return r
end

function M.can_pull(campaign, reading, entry_id)
    local st = M.get(campaign)
    local e = M.entry(entry_id)
    if not reading or not e then
        return false, "Nothing open."
    end
    if st.pulled[entry_id] then
        return false, "Already in your game."
    end
    if reading.left <= 0 then
        return false, "That's three for tonight. The rest will keep."
    end
    return true
end

-- Pull an entry into the game. Cards join the deck now and this week's hand ("New: from a book").
function M.pull(campaign, prep, reading, entry_id)
    local ok, why = M.can_pull(campaign, reading, entry_id)
    if not ok then
        return false, why
    end
    local st = M.get(campaign)
    local e = M.entry(entry_id)
    st.pulled[entry_id] = campaign.week
    reading.left = reading.left - 1
    table.insert(reading.pulled, entry_id)
    local deck = require "game.model.deck"
    local card = e.card and content.components[e.card.id]
    if card then
        deck.add(campaign, card.id, campaign.week, "book:" .. reading.book, "book")
        if prep then
            prep.hand[card.kind] = prep.hand[card.kind] or {}
            if not util.contains(prep.hand[card.kind], card) then
                table.insert(prep.hand[card.kind], 1, card)
            end
            prep.inspired[card.id] = "supplement"
            prep.inspired_by.supplement = prep.inspired_by.supplement or {}
            table.insert(prep.inspired_by.supplement, card)
        end
    end
    if e.kind == "monster" then
        st.bestiary[e.monster] = campaign.week
    elseif e.kind == "module" then
        st.modules[e.module] = campaign.week
    end
    -- Whoever was excited about this page is a little more invested.
    local lifted = {}
    for _, p in ipairs(M.excited(campaign, e)) do
        if p.present ~= false then
            for meter, n in pairs(content.books.EXCITED) do
                score.add(p, meter, n)
            end
            table.insert(lifted, p)
        end
    end
    return true, lifted
end

-- Monsters the encounter builder offers: the slice's own, plus every one pulled from a book.
function M.roster(campaign)
    local monsters = require "game.rules.data.monsters"
    local st = M.get(campaign)
    local out = {}
    for _, id in ipairs(monsters.base_order or monsters.order) do
        table.insert(out, id)
    end
    for _, id in ipairs(monsters.order) do
        if st.bestiary[id] and not util.contains(out, id) then
            table.insert(out, id)
        end
    end
    return out
end

-- Published adventures pulled in, ready for prep.
function M.modules(campaign)
    local st = M.get(campaign)
    local out = {}
    for _, id in ipairs(content.books.module_order) do
        if st.modules[id] then
            table.insert(out, id)
        end
    end
    return out
end

function M.module(id)
    return content.books.modules[id]
end

return M
