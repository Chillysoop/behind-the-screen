-- The event log (roadmap R7, the Main Campaign Design doc: "the log is the single source of truth: a
-- line never states something that isn't in it"). One append-only list of what happened in the
-- adventure, saved with the campaign: who did what to whom, where and when (the session, the room),
-- who saw it, and which earlier event it follows from or turns ("therefore" or "but"). When two
-- systems need the same fact, both read it here; neither keeps its own copy. People's memory is the
-- log read through them (game/model/people.lua): someone knows Pip stole because an event names them
-- as a witness, or because a witness told them (a `tell` event).
--
-- Who writes it: items.lua (every thing that changes hands: found, bought, given, stolen, used up),
-- adventure.lua (Euryale's marks on and off her card; a deed for or against one of the museum's
-- people), museum_night.lua (rooms walked into, the moments played, Francs found), night.lua (every
-- fight and how it ended, a hero going off alone), ideas.lua (the friends' own ideas: asking, lifting
-- something, helping), people.lua (word passed on, and what people do about it).
--
-- campaign.events = { { id, kind, session, where, who, whom, thing, seen = { [id] = true }, told =
--     { [id] = tell id }, from = earlier id, how = "therefore" | "but", beat = true, text, ... }... }
--   kind     enter, moment, setback, fight, find, get (a thing changes hands), use, mark, unmark,
--            help, harm, break, steal, alone, tell, price, refuse, hook
--   who      who did it: a hero (player key), one of the museum's people (an npc id), or "party"
--   whom     who it was done to (an npc id or a hero key), if anyone
--   seen     who saw it happen (npc ids; the party always knows what the party did)
--   beat     a story beat: the night's chain (the report, the journey) is told from these
--   text     the beat as a short clause for the chain: "they set the garden on fire"
-- Pure Lua; requires nothing but util.

local util = require "game.model.util"

local M = {}

-- How the chain joins a beat to the one it follows from.
M.LINK_WORD = { therefore = "so", but = "but" }

-- (Reading never makes the log: a campaign has none until something happens, so a save made before
-- then reads back the same.)
local NONE = setmetatable({}, { __newindex = function()
    error("the event log is written with events.add", 2)
end })
function M.list(c)
    return c.events or NONE
end

function M.get(c, id)
    return id and M.list(c)[id] or nil
end

-- The cause the night is working from right now (the moment being played, the fight being fought):
-- what an item changing hands or a mark landing follows from. Lives on the night, never saved.
function M.cause(c)
    local n = c and c.night
    return n and n.ev_cause or nil
end

function M.set_cause(c, ev)
    local n = c and c.night
    if n then
        n.ev_cause = ev and (type(ev) == "table" and ev.id or ev) or nil
    end
end

-- Write one event. ev.from may be an event or its id; with ev.from == nil and ev.follows ~= false,
-- nothing is linked (links are the caller's to make: a beat that only comes next has none).
function M.add(c, ev)
    c.events = c.events or {}
    local list = c.events
    ev.id = #list + 1
    ev.session = ev.session or c.week or 0
    if ev.where == nil and c.adv then
        ev.where = c.adv.pos or c.adv.last_room
    end
    if type(ev.from) == "table" then
        ev.from = ev.from.id
    end
    if ev.from and not ev.how then
        ev.how = "therefore"
    end
    ev.seen = ev.seen or {}
    if ev.where == false then
        ev.where = nil
    end
    ev.follows = nil
    table.insert(list, ev)
    return ev
end

-- Link an event to the one it follows from (or turns).
function M.link(ev, from, how)
    if ev and from then
        ev.from = type(from) == "table" and from.id or from
        ev.how = how or "therefore"
    end
    return ev
end

local function matches(ev, q)
    for k, v in pairs(q) do         -- (every field has to match: the order can't change the answer)
        if k == "kind" and type(v) == "table" then
            if not v[ev.kind] then
                return false
            end
        elseif k == "seen_by" then
            if not (ev.seen and ev.seen[v]) then
                return false
            end
        elseif k == "since" then
            if (ev.session or 0) < v then
                return false
            end
        elseif k == "after" then
            if ev.id <= v then
                return false
            end
        elseif ev[k] ~= v then
            return false
        end
    end
    return true
end

-- Every event matching q (a table of fields: kind (a name or a set), who, whom, where, session, thing,
-- beat, outcome; seen_by = a witness; since = a session; after = an event id), oldest first.
function M.find(c, q)
    local out = {}
    for _, ev in ipairs(M.list(c)) do
        if matches(ev, q or {}) then
            table.insert(out, ev)
        end
    end
    return out
end

function M.last(c, q)
    local list = M.list(c)
    for i = #list, 1, -1 do
        if matches(list[i], q or {}) then
            return list[i]
        end
    end
    return nil
end

function M.any(c, q)
    return M.last(c, q) ~= nil
end

function M.count(c, q)
    return #M.find(c, q)
end

-- Does this person know it happened: they saw it, or someone told them (a `tell` event)? The party
-- knows everything the party did, and anything done to them.
function M.knows(c, person, ev)
    if not ev then
        return false
    end
    if ev.seen and ev.seen[person] then
        return true
    end
    if ev.told and ev.told[person] then
        return true
    end
    return false
end

-- Word gets round: the teller passes an event on to the listener. Logged as its own event (it
-- follows from the one it's about), and the listener knows from then on. Nothing happens if the
-- listener already knows, or the teller doesn't.
function M.tell(c, teller, listener, about, opts)
    if not about or M.knows(c, listener, about) or not (M.knows(c, teller, about) or about.who == teller) then
        return nil
    end
    opts = opts or {}
    local ev = M.add(c, { kind = "tell", who = teller, whom = listener, about = about.id, from = about.id, how = "therefore",
                          where = opts.where, beat = opts.beat or nil, text = opts.text, seen = { [teller] = true, [listener] = true } })
    about.told = about.told or {}
    about.told[listener] = ev.id
    return ev
end

-- The words a beat is told with, from the adventure (MODULE.beats.words): key, and what fills it in.
-- An adventure without them falls back to the key's own neutral words, given here as `plain`.
function M.word(key, vars, plain)
    local ok, adv = pcall(require, "game.model.adventure")
    local w = ok and adv.data and adv.data.beats and adv.data.beats.words or {}
    return util.fill(w[key] or plain or key, vars or {})
end

-- The night's chain (R14) ---------------------------------------------------------------------

-- The story beats of one session, in the order they happened.
function M.beats(c, session)
    local out = {}
    for _, ev in ipairs(M.list(c)) do
        if ev.beat and ev.session == session and ev.text then
            table.insert(out, ev)
        end
    end
    return out
end

-- Is this beat linked: it follows from, or turns, an earlier event (any earlier event: a theft two
-- rooms back, a mark from last week)?
function M.linked(ev)
    return ev.from ~= nil and (ev.how == "therefore" or ev.how == "but")
end

-- How the session hangs together: the share of beats linked by therefore or but, the longest run of
-- unlinked beats ("and then"), and where each unlinked run starts (its room and what kind of beat).
-- The first beat of a session counts as linked when it follows from an earlier session.
function M.measure(c, session)
    local beats = M.beats(c, session)
    local linked, run, longest = 0, 0, 0
    local starts = {}
    for _, ev in ipairs(beats) do
        if M.linked(ev) then
            linked = linked + 1
            run = 0
        else
            if run == 0 then
                table.insert(starts, { where = ev.where or "?", kind = ev.kind, card = ev.card, id = ev.id })
            end
            run = run + 1
            longest = math.max(longest, run)
        end
    end
    return { beats = #beats, linked = linked, share = #beats > 0 and linked / #beats or 1, longest = longest, starts = starts }
end

-- The session as the table could tell it: each beat's clause, joined to the one before with "so" or
-- "but" when it follows from that one, or starting a sentence with "So" or "But" when the one before
-- ended a sentence. A link word only ever sits right after the clause it follows from: a beat that
-- follows from something further back (two things a choice led to, the second of them) starts a plain
-- sentence, as does a beat with no link, so the chain never claims a cause it doesn't have ("So word
-- reached Euryale. So they fought the Sentinel" read as the word bringing the fight). Of two beats that
-- follow from the same one, the one that moves the story (a fight, a setback, a moment) is told first,
-- and the one on the side (her card, a thing changing hands, a find) after it. Nothing is stitched on
-- with "and then". Returns { sentences }, the beats used, and the link word each one was told with.
M.MAX_JOIN = 2           -- clauses joined into one sentence before a new one starts
M.SIDE = { mark = true, unmark = true, get = true, find = true, use = true, tell = true, price = true, notice = true,
           docked = true, refuse = true }

-- The beats in the order they're told: as they happened, except that a beat that moves the story is
-- moved ahead of a side beat that follows from the same thing, and a side beat that came later in the
-- same room (the scarabs crawling upstairs, said at the room's end) is told right after what it follows
-- from, when nothing else that follows from it is told there: each is told right after its cause.
function M.told_order(beats)
    local out = {}
    for i, ev in ipairs(beats) do
        out[i] = ev
    end
    local moved = true
    while moved do
        moved = false
        for i = 1, #out - 1 do
            local a, b = out[i], out[i + 1]
            if M.SIDE[a.kind] and not M.SIDE[b.kind] and M.linked(a) and M.linked(b) and a.from == b.from then
                out[i], out[i + 1] = b, a
                moved = true
            end
        end
    end
    local i = 1
    while i <= #out do
        local ev = out[i]
        local j
        if M.SIDE[ev.kind] and M.linked(ev) then
            for k = i - 2, 1, -1 do
                if out[k].id == ev.from then
                    j = k
                    break
                end
            end
        end
        local cause = j and out[j]
        if cause and cause.where == ev.where and out[j + 1].from ~= cause.id then
            table.remove(out, i)
            table.insert(out, j + 1, ev)
        end
        i = i + 1
    end
    return out
end

-- room: only the beats in that room (the journey recap tells each room's own chain); skip: kinds of
-- beat to leave out (the journey keeps the big ones: no Francs found or looks round).
function M.chain(c, session, max, room, skip)
    local beats = M.beats(c, session)
    if room or skip then
        local keep = {}
        for _, ev in ipairs(beats) do
            if (not room or (ev.where == room and ev.kind ~= "enter")) and not (skip and (skip[ev.kind] or (ev.look and skip.look))) then
                table.insert(keep, ev)
            end
        end
        beats = keep
    end
    beats = M.told_order(beats)
    -- (The night's losses lead, a death first: round three, B1 and A7. "Euryale came at them, until she
    -- asked them to stop" told a night Oswin died in. Told on their own, with no link word.)
    if not room then
        local lead, rest = {}, {}
        for _, ev in ipairs(beats) do
            table.insert(ev.lead and lead or rest, ev)
        end
        if #lead > 0 then
            beats = lead
            for _, ev in ipairs(rest) do
                table.insert(beats, ev)
            end
        end
    end
    local out, cur, joined, prev, last_word = {}, nil, 0, nil, nil
    local used, words = {}, {}
    local function flush()
        if cur then
            table.insert(out, util.sentence_case(cur) .. ".")
        end
        cur, joined, last_word = nil, 0, nil
    end
    for _, ev in ipairs(beats) do
        if max and #used >= max then
            break
        end
        -- (The link word only when what it follows from is the clause just told: a beat that follows
        -- from something unseen, a hero's reason for coming, says why in its own words.)
        local word = M.linked(ev) and prev and ev.from == prev.id and M.LINK_WORD[ev.how] or nil
        local clause = ev.text
        -- (Nor "but" onto a clause that already turns on one: "they won, but some got away, but ...".)
        local twice = word and cur and string.find(cur, ", " .. word .. " ", 1, true)
        if word and cur and joined < M.MAX_JOIN and word ~= last_word and not twice then
            cur = cur .. ", " .. word .. " " .. clause
            joined = joined + 1
            last_word = word
        elseif word then
            flush()
            cur = util.capitalize(word) .. " " .. clause
            last_word = word
        else
            flush()
            cur = clause
        end
        prev = ev
        table.insert(used, ev)
        table.insert(words, word or false)
    end
    flush()
    return out, used, words
end

-- A save from before the log (R7) still has its story: the rooms walked (st.path), Euryale's marks,
-- the things in the heroes' packs, the favors done. Written into the log once, so everything that
-- reads the log reads an old save too. They're not beats (their links are lost).
function M.start(c)
    if c.events or not c.adv then
        return
    end
    local st = c.adv
    local started = #(st.path or {}) > 0 or #(st.mark_list or {}) > 0
    if not started then
        return
    end
    c.events = {}
    local list = c.events
    for _, step in ipairs(st.path or {}) do
        M.add(c, { kind = "enter", who = "party", where = step.room, session = step.week or 0, old = true })
        if step.fought then
            M.add(c, { kind = "fight", who = "party", where = step.room, session = step.week or 0,
                       outcome = step.outcome == "win" and "won" or "lost", old = true })
        end
    end
    for _, id in ipairs(st.mark_list or {}) do
        local m = st.marks[id]
        M.add(c, { kind = "mark", who = "party", thing = id, where = type(m) == "table" and m.room or false,
                   session = type(m) == "table" and m.week or 0, old = true })
    end
    for _, it in ipairs(c.items or {}) do
        if it.from ~= "start" then
            M.add(c, { kind = "get", who = it.holder, thing = it.thing or it.id, how_got = it.from, entry = it, where = false,
                       session = it.week or 0, old = true })
        end
    end
    for who, n in util.sorted_pairs(st.favors or {}) do
        if n ~= 0 then
            M.add(c, { kind = n > 0 and "help" or "harm", who = "party", whom = "mus_" .. who, n = n, favor = true,
                       seen = { ["mus_" .. who] = true }, where = false, old = true })
        end
    end
    st.favors = {}              -- (the log has them now: one owner)
    return list
end

return M
