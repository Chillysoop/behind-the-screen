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

-- "twice", "three times": how many times, for a line about it ({n} in "went down {n}").
local TIMES = { [2] = "twice", [3] = "three times", [4] = "four times", [5] = "five times", [6] = "six times" }
function M.times(n)
    return TIMES[n] or (tostring(n) .. " times")
end

-- The words a beat is told with, from the adventure (MODULE.beats.words): key, and what fills it in.
-- An adventure without them falls back to the key's own neutral words, given here as `plain`.
-- (The words any adventure's beats are told with, when it doesn't write its own: MODULE.beats.words.)
M.WORDS = {
    enter = "they went into {room}", hooked = "{enter}, the place {char} came for",
    back = "they went back to {room}", flee = "they fell back to {room}", rest = "they went back to {room} to rest",
    look = "{char} had a look at {what}", tried = "{who} tried to {want}", didnt = "it didn't work",
    trap = "a trap went off: {what}",
    lifted = "{char} lifted {thing}", lifted_off = "{char} lifted {thing} off {who}",
    caught = "{char} went for {thing}, and {who} caught {char_them} at it",
    spotted = "{who} spotted their own {thing} on {char}",
    helped = "{char} helped {who}", refused = "{who} wouldn't answer {char}",
    death = "{char} died in {room}", down = "{char} went down", down_n = "{char} went down {n}",
    ally_lost = "they lost {name}", wipe = "the whole party went down in {room}",
    came_back = "{char} nearly died, and came back",
    friendly = "{char}'s {spell} caught {hit} too", friendly_down = "{char}'s own {spell} dropped {downed}",
}
function M.word(key, vars, plain)
    local ok, adv = pcall(require, "game.model.adventure")
    local w = ok and adv.data and adv.data.beats and adv.data.beats.words or {}
    return util.fill(w[key] or M.WORDS[key] or plain or key, vars or {})
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

-- How the chain reads as a story, not a list (the third playtest, alive 18 and the engine run's 8_29):
-- a plain step into a room isn't a line of its own ("They went into the entrance hall."), it says where
-- the next thing happened ("In the entrance hall, they dropped a coin in"); a fight told right after the
-- choice that started it doesn't say the fight twice ("skipped the tablet and fought the guardian, so they
-- fought the Bone Construct": its `tail`, how it ended, is enough); a beat that only repeats the one it
-- follows from is left out, or says only what's new (MODULE.beats.same: "Euryale got away. So Euryale
-- slipped away."); and the Francs found along the way are one sentence at the end, not a "so ... found a
-- Flitwidget Franc" after every look.
M.FIGHT_WORDS = { "fought", "fight", "blades", "steel", "weapons out", "came at them", "swinging" }
local function names_a_fight(text)
    local t = string.lower(text or "")
    for _, w in ipairs(M.FIGHT_WORDS) do
        if string.find(t, w, 1, true) then
            return true
        end
    end
    return false
end
-- What a beat that would repeat its cause says instead: nil to leave it out, or its new part.
local function same_as(prev_text, ev)
    local ok, adv = pcall(require, "game.model.adventure")
    local same = ok and adv.data and adv.data.beats and adv.data.beats.same or {}
    local s = same[ev.text or ""]
    if not (s and prev_text) then
        return false
    end
    local t = string.lower(prev_text)
    for _, w in ipairs(s.words or {}) do
        if string.find(t, w, 1, true) then
            return true, s.rest
        end
    end
    return false
end
-- The Francs found along the way, as one sentence: "Along the way, Thessaly found two Flitwidget
-- Francs." / "Along the way, Flitwidget Francs turned up: two for Thessaly, one for Pip."
local NUM = { "one", "two", "three", "four", "five", "six" }
local function francs_line(finds)
    local by, order = {}, {}
    for _, ev in ipairs(finds) do
        local who = string.match(ev.text or "", "^(.-) found ")
        local n = tonumber(ev.n) or 1
        if who then
            if not by[who] then
                table.insert(order, who)
                by[who] = 0
            end
            by[who] = by[who] + n
        end
    end
    if #order == 0 then
        return nil
    end
    local function count(n)
        return (n == 1 and "a" or (NUM[n] or tostring(n)))
    end
    if #order == 1 then
        local n = by[order[1]]
        return "Along the way, " .. order[1] .. " found " .. count(n) .. " Flitwidget Franc" .. (n == 1 and "" or "s") .. "."
    end
    local parts = {}
    for _, who in ipairs(order) do
        table.insert(parts, (NUM[by[who]] or tostring(by[who])) .. " for " .. who)
    end
    return "Along the way, Flitwidget Francs turned up: " .. util.join_names(parts) .. "."
end
M.francs_line = francs_line

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
    -- (The Francs found, folded into one line at the end: the whole night's chain only.)
    local finds = {}
    if not room then
        local keep = {}
        for _, ev in ipairs(beats) do
            if ev.kind == "find" and not ev.pay and ev.thing == "francs" then
                table.insert(finds, ev)
            else
                table.insert(keep, ev)
            end
        end
        beats = keep
    end
    beats = M.told_order(beats)
    -- (The night's losses lead, a death first: round three, B1 and A7. "Euryale came at them, until she
    -- asked them to stop" told a night Oswin died in. Told on their own, with no link word.)
    if not room then
        local lead, rest = M.lead_beats(beats)
        if #lead > 0 then
            beats = lead
            for _, ev in ipairs(rest) do
                table.insert(beats, ev)
            end
        end
    end
    return M.tell_beats(beats, max, finds)
end

-- The night's losses, first (round three, B1, A7): its lead beats, a hero who went down in two fights
-- as one, a death before a wipe before an ally lost before friendly fire before who went down. Returns
-- them, and the rest of the beats as they were.
function M.lead_beats(beats)
    local lead, rest = {}, {}
    do
        -- (A hero who went down in two fights is one line: "Brannoc went down three times".)
        local downs = {}
        for _, ev in ipairs(beats) do
            if ev.lead and ev.kind == "down" and ev.who then
                local d = downs[ev.who]
                if d then
                    d.n = d.n + (ev.n or 1)
                    d.text = M.word("down_n", { char = d.char, n = M.times(d.n) }, "{char} went down {n}")
                else
                    d = { kind = "down", who = ev.who, char = ev.char, n = ev.n or 1, text = ev.text, lead = true, beat = true, id = ev.id }
                    downs[ev.who] = d
                    table.insert(lead, d)
                end
            else
                table.insert(ev.lead and lead or rest, ev)
            end
        end
        -- (A death first, then a wipe, the ones they lost, friendly fire, and who went down.)
        local ORDER = { death = 1, wipe = 2, lost = 3, friendly = 4, down = 5 }
        local at = {}
        for i, ev in ipairs(lead) do
            at[ev] = i
        end
        table.sort(lead, function(a, b)
            local oa, ob = ORDER[a.kind] or 9, ORDER[b.kind] or 9
            if oa ~= ob then
                return oa < ob
            end
            return at[a] < at[b]
        end)
    end
    return lead, rest
end

-- What last session cost them, as clauses (the night's opening recap leads with it).
function M.losses(c, session)
    local lead = M.lead_beats(M.beats(c, session))
    local out = {}
    for _, ev in ipairs(lead) do
        table.insert(out, ev.text)
    end
    return out
end

-- Told as sentences: each clause joined to the one before with "so" or "but" when it follows from it.
-- (finds: the Francs found along the way, told as one line at the end; the whole night's chain only.)
function M.tell_beats(beats, max, finds)
    finds = finds or {}
    local out, cur, joined, prev, last_word = {}, nil, 0, nil, nil
    local used, words = {}, {}
    local told = {}
    local where_next        -- ("in the entrance hall": said with the next beat, not on its own)
    local function flush()
        if cur then
            table.insert(out, util.sentence_case(cur) .. ".")
        end
        cur, joined, last_word = nil, 0, nil
    end
    for k, ev in ipairs(beats) do
        if max and #used >= max then
            break
        end
        -- (The link word only when what it follows from is the clause just told: a beat that follows
        -- from something unseen, a hero's reason for coming, says why in its own words.)
        local word = M.linked(ev) and prev and ev.from == prev.id and M.LINK_WORD[ev.how] or nil
        local clause = ev.text
        local nxt = beats[k + 1]
        local into = ev.kind == "enter" and not ev.back and string.match(clause or "", "^they went into (.+)$")
        local onto = ev.kind == "enter" and not ev.back and not into and string.match(clause or "", "^they went onto (.+)$")
        into = into or onto
        if into and not (M.linked(ev) and told[ev.from]) and nxt and nxt.where == ev.where and nxt.from ~= ev.id then
            -- A step into a room: where the next thing happened (on a path or a platform: "on").
            where_next = (onto and "on " or "in ") .. into
            table.insert(used, ev)
            table.insert(words, false)
            told[ev.id] = true
        else
            local skip_it = false
            -- (A step into a room where nothing else that's told happened, said on its own: where they got
            -- to, not a bare "They went into the gift shop." The final pass's merge, 38 random.)
            if into and not word then
                clause = "they reached " .. into
            end
            if word == "so" and ev.kind == "fight" and ev.tail and prev and names_a_fight(prev.text) then
                -- (The fight they chose, told by how it ended.)
                clause = string.gsub(ev.tail, "^, ", "")
                word = nil
                if cur and joined < M.MAX_JOIN then
                    cur = cur .. ", " .. clause
                    joined = joined + 1
                    skip_it = true
                end
            elseif word and prev then
                local same, rest = same_as(prev.text, ev)
                if same then
                    word = nil
                    skip_it = true
                    if rest and cur then
                        cur = cur .. ", and " .. rest
                    elseif rest then
                        cur = rest
                    end
                end
            end
            if skip_it then
                -- (said, folded into the clause before)
            elseif word and cur and joined < M.MAX_JOIN and word ~= last_word
                and not string.find(cur, ", " .. word .. " ", 1, true) then
                -- (Nor "but" onto a clause that already turns on one: "they won, but some got away, but ...".)
                cur = cur .. ", " .. word .. " " .. clause
                joined = joined + 1
                last_word = word
            elseif word then
                flush()
                if where_next and string.find(where_next, ",", 1, true) then
                    clause = string.gsub(clause, "^they ", "the party ")
                end
                cur = util.capitalize(word) .. (where_next and (" " .. where_next .. ",") or "") .. " " .. clause
                last_word = word
                where_next = nil
            else
                flush()
                -- ("In the garden, the place Brannoc came for, the party set...": not "they" right after a hero.)
                if where_next and string.find(where_next, ",", 1, true) then
                    clause = string.gsub(clause, "^they ", "the party ")
                end
                cur = (where_next and (where_next .. ", ") or "") .. clause
                where_next = nil
            end
            prev = ev
            told[ev.id] = true
            table.insert(used, ev)
            table.insert(words, (not skip_it) and word or false)
            where_next = nil
        end
    end
    flush()
    local fl = #finds > 0 and francs_line(finds)
    if fl then
        table.insert(out, fl)
    end
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
