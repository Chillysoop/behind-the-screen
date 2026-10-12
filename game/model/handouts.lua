-- Handouts (game/data/handouts.lua): an hour of prep makes a real thing for a card on the board.
-- When the card's scene plays it lands in front of a player and stays at their seat; the
-- storyline the card belongs to stays warm a week longer, and its clue leads next week's recap.
-- Pure Lua.
--
-- prep.handouts     = { [card id] = true }                 made this week
-- campaign.handouts = { { card, kind, seat, week } }        every one that landed, oldest first

local data = require "game.data.handouts"
local content = require "game.model.content"
local score = require "game.model.score"
local util = require "game.model.util"

local M = {}
M.data = data

-- What kind of handout a card makes: "map", "letter", "sketch" or "note".
function M.kind(c)
    if data.MAPS[c.id] then
        return "map"
    end
    return data.KIND[c.kind] or "note"
end

-- What the table calls it ("a letter from Corin").
function M.what(campaign, c)
    local short = c.short or c.name
    if c.kind == "cast" then
        local ledger = require "game.model.ledger"
        local pid = ledger.person_of(c)
        local about = pid and ledger.about(pid)
        short = (about and about.name) or (string.match(c.name, "^([^,]+)") or c.name)
    end
    return util.fill(data.WHAT[M.kind(c)], { short = util.lower_first(short) })
end

-- Can this card on the board get a handout? A card that tells the story: a story card with a
-- reveal still to tell, or one that moves a storyline.
function M.worth_it(campaign, c)
    if not c then
        return false
    end
    local story = require "game.model.story"
    if story.pending_reveal(campaign, c) then
        return true
    end
    return #require("game.model.storylines").of_card(campaign, c) > 0
end

function M.count(prep)
    local n = 0
    for _ in pairs(prep.handouts or {}) do
        n = n + 1
    end
    return n
end

-- Make (or unmake) a handout for a card on this week's board. Returns ok, why.
function M.toggle(prep, id)
    prep.handouts = prep.handouts or {}
    if prep.handouts[id] then
        prep.handouts[id] = nil
        return true
    end
    local c = content.components[id]
    if not c or not prep:placed_at(id) then
        return false, "Put the card on the board first."
    end
    if not M.worth_it(prep.campaign, c) then
        return false, "Handouts are for cards that tell the story."
    end
    if M.count(prep) >= data.PER_WEEK then
        return false, "Two handouts a week. That's all the evenings you have."
    end
    if prep:left() < data.COST then
        return false, "Not enough prep time left."
    end
    prep.handouts[id] = true
    return true
end

-- Prep hours this week's handouts cost (only for cards still on the board).
function M.cost(prep)
    local n = 0
    for id in pairs(prep.handouts or {}) do
        if prep:placed_at(id) then
            n = n + data.COST
        end
    end
    return n
end

-- Who gets it: the hero whose story it is, else whoever has had the fewest, story lovers first.
local function holder(night, c)
    if c.thread then
        for _, p in ipairs(night.players) do
            if p.key == c.thread then
                return p
            end
        end
    end
    local have = {}
    for _, h in ipairs(night.campaign.handouts or {}) do
        have[h.seat] = (have[h.seat] or 0) + 1
    end
    for _, key in pairs(night.handouts_landed or {}) do
        have[key] = (have[key] or 0) + 1
    end
    local best, bv
    for _, p in ipairs(night.players) do
        local v = (have[p.key] or 0) * 10 - (data.FANS[p.primary] or 0) - night.rng:next()
        if not bv or v < bv then
            best, bv = p, v
        end
    end
    return best
end

-- A scene plays: any handout made for its cards lands now.
function M.on_scene(night, sc)
    local prep = night.prep
    if not prep or not prep.handouts then
        return
    end
    local campaign = night.campaign
    for _, kind in ipairs(content.kinds) do
        local c = sc.comps[kind]
        if c and prep.handouts[c.id] and not (night.handouts_landed or {})[c.id] and not night:muted(c) then
            local p = holder(night, c)
            if p then
                night.handouts_landed = night.handouts_landed or {}
                night.handouts_landed[c.id] = p.key
                local what = M.what(campaign, c)
                night:say(util.fill(night:fresh(data.LAND, "handout_land"), { what = what, name = p.name, char = p.char }), "dm")
                night:emit({ kind = "handout", who = p.key, card = c.id, hkind = M.kind(c), what = what })
                night:emit({ kind = "say", who = p.key, text = night:fresh(data.REACT, "handout_react"), ic = false })
                for k, v in pairs(data.HOLDER) do
                    score.add(p, k, v)
                end
                for _, q in ipairs(night.players) do
                    for k, v in pairs(data.ALL) do
                        score.add(q, k, v)
                    end
                    score.add(q, "fun", data.FANS[q.primary] or 0)
                end
                night:react({ [p.key] = "lean" })
                night:highlight(6, p.name .. " got a handout: " .. what, { p }, "handout")
                -- The story sticks: its storylines stay warm a week longer.
                local storylines = require "game.model.storylines"
                for _, id in ipairs(storylines.of_card(campaign, c)) do
                    local st = storylines.get(campaign)[id]
                    if st and st.state == "open" then
                        st.kept = campaign.week + 1
                    end
                end
            end
        end
    end
end

-- After the night: every handout that landed stays at its seat.
function M.after_night(campaign, night)
    campaign.handouts = campaign.handouts or {}
    local out = {}
    for id, key in pairs(night.handouts_landed or {}) do
        local c = content.components[id]
        if c then
            table.insert(campaign.handouts, { card = id, kind = M.kind(c), seat = key, week = campaign.week })
            table.insert(out, { card = id, seat = key, what = M.what(campaign, c) })
        end
    end
    table.sort(out, function(a, b) return a.card < b.card end)
    return out
end

-- What's in front of each seat now: { [key] = { kind... } }, newest last, PER_SEAT at most.
function M.at_seats(campaign)
    local out = {}
    for _, h in ipairs(campaign.handouts or {}) do
        out[h.seat] = out[h.seat] or {}
        table.insert(out[h.seat], h.kind)
        while #out[h.seat] > data.PER_SEAT do
            table.remove(out[h.seat], 1)
        end
    end
    return out
end

-- The clues their handouts carried last week (they lead the recap).
function M.last_week_cards(campaign)
    local out = {}
    for _, h in ipairs(campaign.handouts or {}) do
        if h.week == (campaign.week or 0) - 1 then
            out[h.card] = true
        end
    end
    return out
end

return M
