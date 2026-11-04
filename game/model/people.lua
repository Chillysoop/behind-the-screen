-- People who remember (roadmap R11; the Main Campaign Design doc: "people's memory is the log read
-- through them"). Flitwidget, Telpur, the Lecturer, Euryale and the companions each hold an opinion
-- of each hero and of the party, on a short scale from hostile to devoted. Nobody keeps a copy: an
-- opinion is worked out from the event log (game/model/events.lua), from the events that person saw
-- or was told about, by the general consequence rules below (the adventure only writes exceptions:
-- MODULE.people). It changes what they say (their lines carry conditions on it, most specific first:
-- M.line), what they charge (Telpur's prices: M.price), and what they do (a refusal, a word passed on,
-- a smaller reward), and what the party did reaches boss night through them (M.pass_on).
-- Pure Lua.

local util = require "game.model.util"
local events = require "game.model.events"

local M = {}

M.SCALE = { "hostile", "wary", "neutral", "warm", "devoted" }
M.RANK = { hostile = -2, wary = -1, neutral = 0, warm = 1, devoted = 2 }
-- Where each step of the scale starts, as a score: at or below -5 hostile, at or below -1.5 wary,
-- under 1.5 neutral, under 5 warm, then devoted (the museum is a short story: a deed or two shows).
function M.level_of(score)
    if score <= -5 then
        return "hostile"
    elseif score <= -1.5 then
        return "wary"
    elseif score < 1.5 then
        return "neutral"
    elseif score < 5 then
        return "warm"
    end
    return "devoted"
end

-- The general rules: how far a deed moves someone who knows about it. `to`: it was done to them (or
-- theirs); `other`: done to someone else. A favor or a deed's own `n` scales it.
M.WEIGHT = {
    help = { to = 3, other = 1 },
    harm = { to = -3, other = -1 },
    ["break"] = { to = -2, other = 0 },        -- (something of theirs broken: Flitwidget's exhibits)
    steal = { to = -6, other = -2 },           -- (caught at it, or told)
    refuse = { to = 0, other = 0 },
}
-- A purchase: a shopkeeper likes a paying customer.
M.BUY = 1

local function module()
    local ok, adv = pcall(require, "game.model.adventure")
    return ok and adv.data or {}
end

-- The people who remember, as the adventure lists them (MODULE.people_memory): id, name, and where
-- they'd see what happens (`sees`: rooms; `hears`: rooms they hear through the floor), and who they
-- start out fond of (`start`: hero key -> score).
function M.all()
    return (module().people_memory or {}).order or {}
end

function M.def(id)
    return (module().people_memory or {})[id] or {}
end

local function weight(ev, person)
    local own = M.def(person).weights
    local w = (own and own[ev.kind]) or M.WEIGHT[ev.kind]
    local n = math.abs(ev.n or 1)
    if w then
        return (ev.whom == person and w.to or w.other) * n
    end
    if ev.kind == "get" and ev.how_got == "bought" and ev.whom == person then
        return M.BUY
    end
    return 0
end

-- What this person thinks of a hero (key), or of the party (key nil): { score, level }. Only what
-- they know counts (they saw it, or someone told them). A hero's own deed counts in full for that hero
-- and half for the party; a deed by the whole party counts in full for the party and half for each hero.
function M.opinion(c, person, key)
    local d = M.def(person)
    local score = key and (d.start or {})[key] or (d.start or {}).party or 0
    for _, ev in ipairs(events.list(c)) do
        local w = (M.WEIGHT[ev.kind] or ev.kind == "get") and weight(ev, person) or 0
        if w ~= 0 and events.knows(c, person, ev) then
            if key then
                if ev.who == key then
                    score = score + w
                elseif ev.who == "party" then
                    score = score + w * 0.5
                end
            else
                score = score + ((ev.who == "party") and w or w * 0.5)
            end
        end
    end
    return score, M.level_of(score)
end

function M.level(c, person, key)
    local _, lv = M.opinion(c, person, key)
    return lv
end

-- A condition (adventure.test's `opinion`): { who = person, of = hero key (nil: the party), at_least,
-- at_most } with levels from the scale.
function M.test(c, cond, hero)
    local of = cond.of
    if of == "actor" then
        of = hero
    end
    local lv = M.level(c, cond.who, of)
    local r = M.RANK[lv]
    if cond.at_least and r < M.RANK[cond.at_least] then
        return false
    end
    if cond.at_most and r > M.RANK[cond.at_most] then
        return false
    end
    return true
end

-- Does this person know of a deed of this kind (by this hero, if one is named), done to them if `to`?
function M.knows_of(c, person, kind, by, to)
    for _, ev in ipairs(events.list(c)) do
        if ev.kind == kind and (not by or ev.who == by) and (not to or ev.whom == person) and events.knows(c, person, ev) then
            return ev
        end
    end
    return nil
end

-- Their line for a moment (MODULE.people_lines[person][what]): the first entry whose `when` holds,
-- most specific first, as the data lists them; each entry's text is one line or several (picked
-- fresh). vars fill it ({char}: the hero it's about). Returns the line, and the entry it came from.
function M.line(night, person, what, hero, vars)
    local lines = ((module().people_lines or {})[person] or {})[what]
    if not lines then
        return nil
    end
    local adv = util.lazy("game.model.adventure")
    local c = night.campaign
    local knobs = night.prep and night.prep.museum and night.prep.museum.knobs or {}
    for i, e in ipairs(lines) do
        local ok = not e.when or adv.test(c, e.when, knobs, hero and hero.key)
        if ok then
            local text = e.text
            if type(text) == "table" then
                text = night:fresh(text, "people_" .. person .. "_" .. what .. "_" .. i)
            end
            if text then
                local v = vars or {}
                v.char = v.char or (hero and hero.char) or "them"
                return util.fill(text, v), e
            end
        end
    end
    return nil
end

-- Telpur's price for something on his shelf: the price the module sets (MODULE.PRICE), plus what he
-- thinks of the party now. A thief costs more; a friend gets a Franc off. Returns the price and how
-- much it moved.
M.MARKUP = { hostile = 2, wary = 1, neutral = 0, warm = 0, devoted = -1 }
function M.price(c, base, seller)
    if not base then
        return base, 0
    end
    local lv = M.level(c, seller or "mus_telpur")
    local d = M.MARKUP[lv] or 0
    return math.max(1, base + d), d
end

-- Word gets round (the design's consequence rules: "word spreads from the witness"). The teller
-- passes on what they know that the listener doesn't, of these kinds, and each passing-on is in the
-- log. Returns the tell events. opts.where: the room it's told in; opts.rooms: only what happened
-- there; opts.kinds: a set of kinds (default: deeds that change an opinion).
M.TELLABLE = { steal = true, harm = true, ["break"] = true, help = true }
function M.pass_on(c, teller, listener, opts)
    opts = opts or {}
    local kinds = opts.kinds or M.TELLABLE
    local out = {}
    for _, ev in ipairs(events.list(c)) do
        if kinds[ev.kind] and ev.who ~= listener and events.knows(c, teller, ev) and not events.knows(c, listener, ev)
            and (not opts.rooms or (ev.where and opts.rooms[ev.where])) then
            local t = events.tell(c, teller, listener, ev, { where = opts.where })
            if t then
                table.insert(out, t)
            end
        end
    end
    return out
end

-- Someone sees what's in front of them (the rooms they're in, or listen to): every event there of
-- these kinds becomes one they know. Used for Flitwidget seeing his museum again, and the Lecturer
-- hearing through the floor. Returns the events newly noticed.
function M.notice(c, person, rooms, kinds)
    local out = {}
    for _, ev in ipairs(events.list(c)) do
        if (not kinds or kinds[ev.kind]) and ev.where and rooms[ev.where] and not events.knows(c, person, ev) and ev.who ~= person then
            ev.seen = ev.seen or {}
            ev.seen[person] = true
            table.insert(out, ev)
        end
    end
    return out
end

-- Who's in this room to see something happen: the museum's people whose room it is (or who hear it),
-- not the heroes. For a deed done in front of them.
function M.watchers(c, room)
    local out = {}
    for _, id in ipairs(M.all()) do
        local d = M.def(id)
        if d.sees and util.contains(d.sees, room) then
            table.insert(out, id)
        end
    end
    return out
end

-- The Recap's line for each of them (the DM's Story sidebar): how they feel about the party now.
M.FEEL = { hostile = "Can't stand them", wary = "Wary of them", neutral = nil, warm = "Fond of them", devoted = "Would do anything for them" }

return M
