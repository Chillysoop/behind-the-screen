-- The DM's ties and locks (v2, October 30): the adventure as structure the DM can see and bend.
-- The Discord feedback: "cards in and out nodes, and you kind of program them together", and "add
-- in ties, lock cards or characters behind certain story progression". Every card has ins (what it
-- needs) and outs (what it opens and marks); in prep the DM can
--   lock  a door or a room          (it stays shut until the condition has happened once),
--         a moment                  (it plays only while the condition holds, or never: cut),
--         a person                  (keeps out of sight until the condition has happened: their
--                                    moments are skipped and their room plays without them);
--   tie   an effect to a condition  (it fires once, the first time the condition holds):
--         Euryale gains a mark, or a hero's reason for coming pays off in another room. A tie that
--         opens something is a lock seen from the other end: its condition is the out.
-- Conditions: a room they've been through, an out of a card (named by its words, never its id),
-- a mark on her card, Francs at or above N, not before session N.
--
-- Nothing here is about the museum: it reads the module through adventure.data, so the next
-- adventure goes into the same slots. The state is campaign.adv.locks / .ties / .hook_room
-- (adventure.new_state); adventure.lua's walking reads the locks, museum_night.lua and
-- museum_week.lua call the beats (open_locks, fire), and the editor is game/ui/ties_view.lua.
-- Locking is always the DM's own choice: none of this closes anything by itself. Engine-free.

local util = require "game.model.util"
local adventure = require "game.model.adventure"

local MODULE = adventure.data
local M = {}

M.FRANCS = { 2, 4, 6, 8, 10 }   -- the Francs chips

-- Names ------------------------------------------------------------------------------------------

local function room(id)
    return MODULE.rooms[id]
end

function M.room_name(id)
    local r = room(id)
    return r and r.name or tostring(id)
end

-- "the garden", "the Hall of Paintings" (for the middle of a sentence).
function M.the(id)
    return util.lower_first(M.room_name(id))
end

local PEOPLE
local function people()
    if not PEOPLE then
        PEOPLE = {}
        for _, p in ipairs(MODULE.people or {}) do
            PEOPLE[p.id] = p
        end
    end
    return PEOPLE
end

function M.person(id)
    return people()[id]
end

function M.person_name(id)
    local p = people()[id]
    return p and p.name or tostring(id)
end

local MOMENTS
function M.moment(id)
    if not MOMENTS then
        MOMENTS = {}
        for _, m in ipairs(MODULE.moments or {}) do
            MOMENTS[m.id] = m
        end
    end
    return MOMENTS[id]
end

-- The rooms on the map, in its order (the ones the party walks through: no epilogue).
function M.map_rooms()
    local out = {}
    for _, id in ipairs(MODULE.order or {}) do
        if room(id) and not room(id).epilogue then
            table.insert(out, id)
        end
    end
    return out
end

-- The room it all leads to (the boss's).
function M.boss_room()
    for _, id in ipairs(MODULE.order or {}) do
        if room(id) and room(id).boss then
            return id
        end
    end
end

-- Who the boss is, by name ("Euryale"): her room's boss_name, else its cast.
function M.boss_name()
    local id = M.boss_room()
    local r = id and room(id)
    if r and r.boss_name then
        return r.boss_name
    end
    local cast = r and r.comps and r.comps.cast
    return cast and M.person(cast) and M.person(cast).name or "The boss"
end

-- "Euryale's card shows "Her pack"".
local function card_words()
    return M.boss_name() .. "'s card"
end

-- The doors, each once, as the module joins its rooms.
function M.doors()
    local out = {}
    for _, l in ipairs(MODULE.links or {}) do
        if room(l[1]) and room(l[2]) then
            table.insert(out, { l[1], l[2] })
        end
    end
    return out
end

function M.door_key(a, b)
    return a .. "_" .. b
end

function M.door_name(a, b)
    return "the door between " .. M.the(a) .. " and " .. M.the(b)
end

-- What a card's own words say, with its fill-ins made general ("{actor_char} pockets the twin
-- daggers" -> "A hero pockets the twin daggers").
local FILL = { actor_char = "a hero", painting = "a painting", gift = "what's in it", francs = "their", mech = "the Mech",
               boss = "the boss", char = "a hero" }
function M.plain(text)
    local s = string.gsub(text or "", "{([%w_]+)}", function(k)
        return FILL[k] or "someone"
    end)
    return util.sentence_case(s)
end

-- The outs of the cards ------------------------------------------------------------------------
-- Every flag a room's moment can set, named by its words (MODULE.outs, else the aspect the
-- option writes for the hero), with the moments and rooms that can set it; every mark, with where
-- it can come from. moments/rooms: the moments that set it and their rooms. after: rooms that set
-- it once they're done (a request asked after a room, MODULE.marks[id].from). outside: anywhere
-- (a loose end, a favor, a room left behind, or nothing we can see in the data).

local function each_mus(m, fn)
    for _, o in ipairs(m.options or {}) do
        if o.mus then
            fn(o, o.mus)
        end
        if o.roll then
            if o.roll.success and o.roll.success.mus then
                fn(o, o.roll.success.mus, "success")
            end
            if o.roll.fail and o.roll.fail.mus then
                fn(o, o.roll.fail.mus, "fail")
            end
        end
    end
end
M.each_mus = each_mus

local CAT
function M.catalog()
    if CAT then
        return CAT
    end
    local flags, flag_order, marks = {}, {}, {}
    local function mark_of(id)
        marks[id] = marks[id] or { id = id, moments = {}, rooms = {}, after = {}, outside = false }
        return marks[id]
    end
    for _, m in ipairs(MODULE.moments or {}) do
        each_mus(m, function(_, mus)
            if mus.flag then
                local f = flags[mus.flag]
                if not f then
                    f = { id = mus.flag, moments = {}, rooms = {}, after = {}, outside = false }
                    flags[mus.flag] = f
                    table.insert(flag_order, mus.flag)
                end
                f.name = f.name or mus.aspect
                if not util.contains(f.moments, m.id) then
                    table.insert(f.moments, m.id)
                end
                f.rooms[m.room] = true
            end
            if mus.mark then
                local mk = mark_of(mus.mark)
                if not util.contains(mk.moments, m.id) then
                    table.insert(mk.moments, m.id)
                end
                mk.rooms[m.room] = true
            end
        end)
    end
    for id, f in pairs(flags) do
        f.name = (MODULE.outs or {})[id] or f.name
    end
    -- Between sessions (requests, loose ends, favors) can set flags and marks too: a request once its
    -- room is done, the others whatever doors are shut.
    local function outside(mus, after)
        if not mus then
            return
        end
        if mus.flag and flags[mus.flag] then
            if after then
                flags[mus.flag].after[after] = true
            else
                flags[mus.flag].outside = true
            end
        end
        if mus.mark then
            if after then
                mark_of(mus.mark).after[after] = true
            else
                mark_of(mus.mark).outside = true
            end
        end
    end
    for _, rq in ipairs(MODULE.requests or {}) do
        for _, a in pairs(rq.answers or {}) do
            outside(a.mus, rq.after or false)
        end
    end
    for _, le in ipairs(MODULE.loose_ends or {}) do
        for _, o in ipairs(le.options or {}) do
            outside(o.mus)
        end
    end
    for _, fv in pairs(MODULE.favors or {}) do
        for _, o in ipairs(fv.helps or {}) do
            outside(o.mus)
        end
        for _, o in ipairs(fv.hurts or {}) do
            outside(o.mus)
        end
    end
    for _, lb in pairs(MODULE.left_behind or {}) do
        if lb.mark then
            mark_of(lb.mark).outside = true
        end
    end
    for id, def in pairs(MODULE.marks or {}) do
        local mk = mark_of(id)
        for _, rid in ipairs(def.from or {}) do
            mk.after[rid] = true
        end
        -- A mark the data never hands out by name (the night's own bookkeeping) could come from anywhere.
        if #mk.moments == 0 and not next(mk.after) then
            mk.outside = true
        end
    end
    local out_list = {}
    for _, id in ipairs(flag_order) do
        if flags[id].name then
            table.insert(out_list, id)
        end
    end
    CAT = { flags = flags, flag_order = out_list, marks = marks }
    return CAT
end

function M.flag_name(id)
    local f = M.catalog().flags[id]
    return (f and f.name) or (MODULE.outs or {})[id]
end

function M.mark_name(id)
    local m = (MODULE.marks or {})[id]
    return m and m.name or tostring(id)
end

-- Conditions in words --------------------------------------------------------------------------
-- A condition: { kind = "room", room } | { kind = "flag", flag } | { kind = "mark", mark } |
-- { kind = "francs", n } | { kind = "session", n } | { kind = "never" } (a moment, cut).

-- The clause, for "...until <it>" turned round as "opens after <it>", "only if <it>", "After <it>, ...".
function M.clause(cond)
    local k = cond and cond.kind
    if k == "room" then
        return "they've been through " .. M.the(cond.room)
    elseif k == "flag" then
        return "someone " .. util.mid_sentence(M.flag_name(cond.flag) or "did something", {})
    elseif k == "mark" then
        return card_words() .. " shows \"" .. M.mark_name(cond.mark) .. "\""
    elseif k == "francs" then
        return "they have " .. util.int(cond.n) .. " Francs or more"
    elseif k == "session" then
        return "session " .. util.int(cond.n) .. " has begun"
    end
    return "never"
end

-- A chip's short label.
function M.chip(cond)
    local k = cond and cond.kind
    if k == "room" then
        return M.room_name(cond.room)
    elseif k == "flag" then
        return M.flag_name(cond.flag) or cond.flag
    elseif k == "mark" then
        return M.mark_name(cond.mark)
    elseif k == "francs" then
        return util.int(cond.n) .. " Francs or more"
    elseif k == "session" then
        return "Session " .. util.int(cond.n)
    end
    return "Never"
end

function M.same_cond(a, b)
    return a and b and a.kind == b.kind and a.room == b.room and a.flag == b.flag and a.mark == b.mark and a.n == b.n
end

-- What a lock is on, in words: "the door between the entrance hall and the Hall of Paintings".
function M.target_name(l)
    if l.kind == "door" then
        return M.door_name(l.a, l.b)
    elseif l.kind == "room" then
        return M.the(l.room)
    elseif l.kind == "moment" then
        local m = M.moment(l.moment)
        return "\"" .. M.plain(m and m.title or l.moment) .. "\" in " .. M.the(m and m.room or "")
    elseif l.kind == "person" then
        return M.person_name(l.person)
    end
    return "?"
end

-- What a tie does, in words: "Euryale gains "Her pack"".
function M.effect_words(e, c)
    if e.kind == "mark" then
        return M.boss_name() .. " gains \"" .. M.mark_name(e.mark) .. "\""
    elseif e.kind == "hook" then
        return M.hero_name(e.key, c) .. "'s reason for coming pays off in " .. M.the(e.room)
    end
    return "something happens"
end

-- A lock's rule, after its name: "Shut. Opens after they've been through the garden." A tie's
-- whole sentence: "After they've been through the garden, Euryale gains "Her pack"."
function M.rule(x, c)
    local cond = x.cond
    local when = cond.kind == "session" and ("from session " .. util.int(cond.n)) or ("after " .. M.clause(cond))
    if x.effect then
        local what = M.effect_words(x.effect, c)
        return util.capitalize(when) .. ", " .. what .. "."
    elseif x.kind == "moment" then
        if cond.kind == "never" then
            return "Cut: it never plays."
        end
        return "Plays only if " .. (cond.kind == "session" and ("it's session " .. util.int(cond.n) .. " or later")
            or M.clause(cond)) .. "."
    elseif x.kind == "person" then
        return "Out of sight. Comes out " .. when .. "."
    end
    return "Shut. Opens " .. when .. "."
end

-- The whole lock or tie in one line, for the list and the log.
function M.describe(x, c)
    if x.effect then
        return M.rule(x, c)
    end
    return util.capitalize(M.target_name(x)) .. ": " .. util.lower_first(M.rule(x, c))
end

-- The heroes, by player key: "Thessaly".
function M.hero_name(key, campaign)
    local c = campaign
    local p = c and c.player and c:player(key)
    if p and p.char then
        return p.char
    end
    local h = MODULE.heroes and MODULE.heroes[key]
    return h and (string.match(h.gist or "", "^(%a+)") or key) or tostring(key)
end

-- State -----------------------------------------------------------------------------------------

local function st_of(c)
    return adventure.fill(c.adv)
end

function M.locks(c)
    return st_of(c).locks
end

function M.ties(c)
    return st_of(c).ties
end

-- Anything set at all?
function M.any(c)
    local st = c and c.adv
    return st ~= nil and ((st.locks and #st.locks > 0) or (st.ties and #st.ties > 0) or (st.lock_news and #st.lock_news > 0))
end

local function same_target(a, b)
    if a.kind ~= b.kind then
        return false
    end
    if a.kind == "door" then
        return (a.a == b.a and a.b == b.b) or (a.a == b.b and a.b == b.a)
    end
    return a.room == b.room and a.moment == b.moment and a.person == b.person
end

-- The lock on a thing, if there is one.
function M.lock_on(c, target)
    for _, l in ipairs(M.locks(c)) do
        if same_target(l, target) then
            return l
        end
    end
end

function M.find(c, id)
    for i, l in ipairs(M.locks(c)) do
        if l.id == id then
            return l, i, "lock"
        end
    end
    for i, t in ipairs(M.ties(c)) do
        if t.id == id then
            return t, i, "tie"
        end
    end
end

-- What a moment belongs to: its own `who`, or the person its room is about (adventure).
M.moment_people = adventure.moment_people

-- The people who can be hidden: every person with a room or a moment of their own, but the boss.
function M.people_rooms(pid)
    local out = {}
    for _, id in ipairs(M.map_rooms()) do
        local r = room(id)
        if r.comps and r.comps.cast == pid then
            table.insert(out, id)
        end
    end
    return out
end

-- Working it out: where they can get to, what can happen ----------------------------------------

-- The rooms the party can walk to from where it stands, through any room not locked shut (done or
-- not: a room on the way just has to be played), with the locks in `open` counted open.
local function walk(c, locks, open)
    local st = st_of(c)
    local from = st.pos or MODULE.start
    local R = { [from] = true }
    local queue = { from }
    local function shut_room(id)
        for _, l in ipairs(locks) do
            if l.kind == "room" and l.room == id and not open[l] then
                return true
            end
        end
        return false
    end
    local function shut_door(a, b)
        for _, l in ipairs(locks) do
            if l.kind == "door" and not open[l] and ((l.a == a and l.b == b) or (l.a == b and l.b == a)) then
                return true
            end
        end
        return false
    end
    while #queue > 0 do
        local id = table.remove(queue, 1)
        if not (room(id) and room(id).boss) then
            for _, n in ipairs(adventure.neighbors(id)) do
                if not R[n] and room(n) and not (MODULE.no_return or {})[n] and not shut_door(id, n) and not shut_room(n) then
                    R[n] = true
                    table.insert(queue, n)
                end
            end
        end
    end
    return R
end

-- Could this moment still play (not cut, its people not hidden for good, not the card we're
-- checking)?
local function moment_can(c, mid, locks, open, skip)
    if skip and skip[mid] then
        return false
    end
    local m = M.moment(mid)
    for _, l in ipairs(locks) do
        if l.kind == "moment" and l.moment == mid and l.cond.kind == "never" then
            return false
        end
        if l.kind == "person" and not open[l] and m and util.contains(adventure.moment_people(m), l.person) then
            return false
        end
    end
    return true
end

-- Can a flag or mark come from somewhere the party can get to (a moment that can still play there, or
-- a room that hands it out once done)? Not from the boss's room: by then it's all over.
local function from_rooms(c, entry, R, locks, open, skip)
    for _, mid in ipairs(entry.moments) do
        local m = M.moment(mid)
        if m and R[m.room] and not (room(m.room) and room(m.room).boss) and moment_can(c, mid, locks, open, skip) then
            return true
        end
    end
    for rid in pairs(entry.after) do
        if R[rid] and not (room(rid) and room(rid).boss) then
            return true
        end
    end
    return false
end

-- Can the condition happen? mode "possible": it could (its card can still play somewhere they can
-- get to); mode "certain": it will (a room they can get to and must go through sooner or later, a
-- session, or something already done). sure: marks a tie will surely add.
local function holds(c, cond, R, locks, open, mode, sure, skip)
    local st = st_of(c)
    local k = cond.kind
    if k == "never" then
        return false
    elseif k == "session" then
        return (cond.n or 0) <= (MODULE.MAX_WEEKS or 99)
    elseif k == "room" then
        return st.done[cond.room] ~= nil or R[cond.room] == true
    elseif k == "francs" then
        return (st.francs or 0) >= (cond.n or 0) or mode == "possible"
    elseif k == "flag" then
        if st.flags[cond.flag] then
            return true
        end
        if mode ~= "possible" then
            return false
        end
        local f = M.catalog().flags[cond.flag]
        if not f or f.outside then
            return true
        end
        return from_rooms(c, f, R, locks, open, skip)
    elseif k == "mark" then
        if st.marks[cond.mark] or (sure and sure[cond.mark]) then
            return true
        end
        if mode ~= "possible" then
            return false
        end
        local mk = M.catalog().marks[cond.mark]
        if not mk or mk.outside then
            return true
        end
        for _, t in ipairs(M.ties(c)) do
            if not t.fired and t.effect.kind == "mark" and t.effect.mark == cond.mark then
                return true
            end
        end
        return from_rooms(c, mk, R, locks, open, skip)
    end
    return false
end

-- Which door, room and person locks open in the end, if `mode` things happen (and which rooms the
-- party can then get to). `skip`: moments that don't count as able to play.
local function settle(c, locks, mode, skip)
    local open = {}
    for _, l in ipairs(locks) do
        if l.open or l.kind == "moment" then
            open[l] = true
        end
    end
    local sure = {}
    local R = walk(c, locks, open)
    for _ = 1, 60 do
        local changed = false
        for _, l in ipairs(locks) do
            if not open[l] and holds(c, l.cond, R, locks, open, mode, sure, skip) then
                open[l] = true
                changed = true
            end
        end
        if mode == "certain" then
            for _, t in ipairs(M.ties(c)) do
                if not t.fired and t.effect.kind == "mark" and not sure[t.effect.mark]
                    and holds(c, t.cond, R, locks, open, mode, sure, skip) then
                    sure[t.effect.mark] = true
                    changed = true
                end
            end
        end
        if not changed then
            break
        end
        R = walk(c, locks, open)
    end
    return R, open
end
M.settle = settle

-- Where the party could still go from where it stands (or starts), with these locks as they are
-- now: the rooms past this one, not done and not left behind.
local function next_rooms(c, locks)
    local st = st_of(c)
    if st.ending then
        return { "end" }
    end
    local from = st.pos or MODULE.start
    local open = {}
    for _, l in ipairs(locks) do
        if l.open or l.kind == "moment" or l.kind == "person" then
            open[l] = true
        end
    end
    local R = walk(c, locks, open)
    local out = {}
    for id in pairs(R) do
        if id ~= from and not st.done[id] and not st.skipped[id] then
            table.insert(out, id)
        end
    end
    return out
end

local function room_list(set)
    local names = {}
    for _, id in ipairs(MODULE.order or {}) do
        if set[id] then
            table.insert(names, M.the(id))
        end
    end
    return util.join_names(names)
end

-- Why a condition could never come true here, in plain words (for a lock that would never open).
local function never_why(c, l)
    local cond = l.cond
    local shut = l.kind == "person" and (M.person_name(l.person) .. " would never come out")
        or (l.kind == "moment" and "it would never play") or "it would never open"
    if cond.kind == "room" then
        return "Your locks keep them from getting to " .. M.the(cond.room) .. " first, so " .. shut .. "."
    elseif cond.kind == "flag" or cond.kind == "mark" then
        local srcs = {}
        local cat = M.catalog()
        local entry = cond.kind == "flag" and cat.flags[cond.flag] or cat.marks[cond.mark]
        for _, set in ipairs({ entry and entry.rooms or {}, entry and entry.after or {} }) do
            for rid in pairs(set) do
                if not (room(rid) and room(rid).boss) then
                    srcs[rid] = true
                end
            end
        end
        if l.kind == "person" then
            return "Only " .. M.person_name(l.person) .. "'s own moments can make that happen, so " .. shut .. "."
        elseif l.kind == "moment" then
            return "Only this card can make that happen, so " .. shut .. "."
        end
        local where = room_list(srcs)
        return "Only " .. (where ~= "" and where or "a room behind it") .. " can make that happen, and your locks keep them "
            .. "from getting there first, so " .. shut .. "."
    elseif cond.kind == "session" then
        return "The adventure is over by then, so " .. shut .. "."
    end
    return "That could never happen, so " .. shut .. "."
end

-- Checks ----------------------------------------------------------------------------------------

local function valid_cond(c, cond, allow_never)
    if type(cond) ~= "table" then
        return "Pick when it happens."
    end
    local k = cond.kind
    if k == "never" then
        return (not allow_never) and "Only a moment can be cut." or nil
    elseif k == "room" then
        if not room(cond.room) or room(cond.room).epilogue then
            return "That room isn't on the map."
        end
        if room(cond.room).boss then
            return "Once they've been through " .. M.the(cond.room) .. " it's all over."
        end
    elseif k == "flag" then
        if not M.flag_name(cond.flag) then
            return "That isn't something a card can make happen."
        end
    elseif k == "mark" then
        if not (MODULE.marks or {})[cond.mark] then
            return "That isn't one of her marks."
        end
    elseif k == "francs" or k == "session" then
        if type(cond.n) ~= "number" or cond.n < 1 then
            return "Pick a number."
        end
        if k == "session" and cond.n > (MODULE.MAX_WEEKS or 99) then
            return "The adventure is over by then."
        end
    else
        return "Pick when it happens."
    end
end

-- Is this lock all right? Returns nil, or why not in plain words. `locks` (optional): the locks it
-- would join (the current ones by default).
function M.check_lock(c, l)
    local st = st_of(c)
    local k = l.kind
    local why = valid_cond(c, l.cond, k == "moment")
    if why then
        return why
    end
    if k == "door" then
        local ok = false
        for _, d in ipairs(M.doors()) do
            if (d[1] == l.a and d[2] == l.b) or (d[1] == l.b and d[2] == l.a) then
                ok = true
            end
        end
        if not ok then
            return "There's no door there."
        end
    elseif k == "room" then
        local r = room(l.room)
        if not r or r.epilogue or not util.contains(MODULE.order or {}, l.room) then
            return "That room isn't on the map."
        end
        if l.room == MODULE.start then
            return "The adventure starts in " .. M.the(l.room) .. ", so it can't be locked."
        end
        if st.pos == l.room and not st.done[l.room] then
            return "They're in there right now."
        end
    elseif k == "moment" then
        local m = M.moment(l.moment)
        if not m then
            return "That card isn't in the adventure."
        end
        if l.cond.kind == "room" and l.cond.room == m.room then
            return "This card comes up while they're in " .. M.the(m.room) .. ", before it's done."
        end
    elseif k == "person" then
        if not M.person(l.person) then
            return "That person isn't in the adventure."
        end
        for _, id in ipairs(M.people_rooms(l.person)) do
            if room(id).boss then
                return M.person_name(l.person) .. " is who it all leads to, and can't be kept out of sight."
            end
        end
        if #M.people_rooms(l.person) == 0 then
            local any = false
            for _, m in ipairs(MODULE.moments or {}) do
                if util.contains(adventure.moment_people(m), l.person) then
                    any = true
                end
            end
            if not any then
                return M.person_name(l.person) .. " has no room or moment of their own to keep out of."
            end
        end
    else
        return "That can't be locked."
    end
    if k ~= "moment" and adventure.cond_true(c, l.cond) then
        return "That has already happened, so it would be open straight away."
    end
    -- The locks as they'd be, this one in place of any old one on the same thing.
    local locks = {}
    for _, o in ipairs(M.locks(c)) do
        if not same_target(o, l) then
            table.insert(locks, o)
        end
    end
    local new = util.copy(l)
    new.open = nil
    table.insert(locks, new)
    -- 1. It can open at all (its condition isn't only behind itself), and doesn't shut any other for good.
    local skip
    if k == "moment" then
        skip = { [l.moment] = true }
    elseif k == "person" then
        skip = {}
        for _, m in ipairs(MODULE.moments or {}) do
            if util.contains(adventure.moment_people(m), l.person) then
                skip[m.id] = true
            end
        end
    end
    if k == "moment" then
        if l.cond.kind ~= "never" then
            local R, open = settle(c, locks, "possible")
            if not holds(c, l.cond, R, locks, open, "possible", nil, skip) then
                return never_why(c, l)
            end
        end
    else
        local _, open = settle(c, locks, "possible", nil)
        if not open[new] then
            -- (Count the lock's own cards out when it hides a person: they can't make it happen.)
            return never_why(c, new)
        end
        if skip then
            local R2, open2 = settle(c, locks, "possible")
            open2[new] = nil
            if not holds(c, l.cond, R2, locks, open2, "possible", nil, skip) then
                return never_why(c, new)
            end
        end
        local _, before = settle(c, M.locks(c), "possible")
        for _, o in ipairs(locks) do
            if o ~= new and before[o] and not open[o] then
                return "That would keep your lock on " .. M.target_name(o) .. " shut for good: what opens it is behind this one."
            end
        end
    end
    -- 2. The boss is still in reach for sure, whatever the uncertain things do.
    local boss = M.boss_room()
    if boss and k ~= "moment" then
        local R = settle(c, locks, "certain")
        if not R[boss] then
            local cond_txt = (l.cond.kind == "room" or l.cond.kind == "session") and "" or " if that never happens,"
            return "That could leave " .. M.the(boss) .. " out of reach:" .. cond_txt .. " there'd be no way to get there."
        end
        -- 3. Somewhere to go next session.
        if k ~= "person" and #next_rooms(c, locks) == 0 then
            return "They'd soon have nowhere left to go: that shuts every way on from where they are."
        end
    end
    return nil
end

-- Lock something: { kind = "door", a, b } | { kind = "room", room } | { kind = "moment", moment } |
-- { kind = "person", person }, with cond. A new lock on the same thing replaces the old one.
-- Returns the lock, or nil and why not.
function M.add_lock(c, l)
    local why = M.check_lock(c, l)
    if why then
        return nil, why
    end
    local st = st_of(c)
    for i = #st.locks, 1, -1 do
        if same_target(st.locks[i], l) then
            table.remove(st.locks, i)
        end
    end
    st.tie_seq = (st.tie_seq or 0) + 1
    local lock = { id = "L" .. util.int(st.tie_seq), kind = l.kind, a = l.a, b = l.b, room = l.room, moment = l.moment,
                   person = l.person, cond = util.copy(l.cond), week = c.week }
    table.insert(st.locks, lock)
    M.changed(c)
    return lock
end

-- Is this tie all right? nil, or why not.
function M.check_tie(c, t)
    local st = st_of(c)
    local why = valid_cond(c, t.cond, false)
    if why then
        return why
    end
    local e = t.effect
    if type(e) ~= "table" then
        return "Pick what happens."
    end
    if e.kind == "mark" then
        if not (MODULE.marks or {})[e.mark] then
            return "That isn't one of her marks."
        end
        if st.marks[e.mark] then
            return "Her card already shows that."
        end
    elseif e.kind == "hook" then
        local h = c.player and c:player(e.key) and adventure.hook(c, e.key)
        if not h then
            return "That hero has no reason for coming yet."
        end
        local r = room(e.room)
        if not r or r.virtual or r.epilogue or not util.contains(MODULE.order or {}, e.room) then
            return "Pick a room on the map."
        end
        if st.done[h.room] then
            return M.hero_name(e.key, c) .. " already found what they came for."
        end
        if h.room == e.room then
            return "That's where it pays off already."
        end
        if st.done[e.room] or st.skipped[e.room] then
            return "They've already been through " .. M.the(e.room) .. "."
        end
    else
        return "Pick what happens."
    end
    for _, o in ipairs(st.ties) do
        if not o.fired and M.same_cond(o.cond, t.cond) and o.effect.kind == e.kind and o.effect.mark == e.mark
            and o.effect.key == e.key and o.effect.room == e.room then
            return "You've tied that already."
        end
    end
    return nil
end

function M.add_tie(c, t)
    local why = M.check_tie(c, t)
    if why then
        return nil, why
    end
    local st = st_of(c)
    st.tie_seq = (st.tie_seq or 0) + 1
    local tie = { id = "T" .. util.int(st.tie_seq), cond = util.copy(t.cond), effect = util.copy(t.effect), week = c.week }
    table.insert(st.ties, tie)
    return tie
end

-- Take a lock or a tie away (a hook already moved stays where it went).
function M.remove(c, id)
    local x, i, what = M.find(c, id)
    if not x then
        return false
    end
    if what == "lock" then
        table.remove(M.locks(c), i)
        M.changed(c)
    else
        table.remove(M.ties(c), i)
    end
    return true
end

-- The map changed under the party (a lock set, removed or opened): where they can go next.
function M.changed(c)
    adventure.refresh_frontier(c)
end

-- The beats -------------------------------------------------------------------------------------

-- Locks whose condition has come true open, for good. Returns the ones that opened just now.
function M.open_locks(c)
    local out = {}
    if not (c.adv and c.adv.locks and #c.adv.locks > 0) then
        return out
    end
    local walls = false
    for _, l in ipairs(M.locks(c)) do
        if l.kind ~= "moment" and not l.open and adventure.cond_true(c, l.cond) then
            l.open = c.week or true
            table.insert(out, l)
            walls = walls or l.kind ~= "person"
        end
    end
    if walls then
        M.changed(c)
    end
    return out
end

-- Ties whose condition holds fire, once each. on_mark(id): how a mark goes on her card (the night
-- passes its own, for the usual event and her thought; adventure.add_mark otherwise). Returns the
-- ties that fired.
function M.fire(c, on_mark)
    local out = {}
    local st = c.adv
    if not (st and st.ties and #st.ties > 0) then
        return out
    end
    for _, t in ipairs(st.ties) do
        if not t.fired and adventure.cond_true(c, t.cond) then
            t.fired = c.week or true
            local e = t.effect
            if e.kind == "mark" then
                if on_mark then
                    on_mark(e.mark)
                else
                    adventure.add_mark(c, e.mark, st.pos)
                end
            elseif e.kind == "hook" then
                local h = adventure.hook(c, e.key)
                if h and not st.done[h.room] and not st.done[e.room] and not st.skipped[e.room] then
                    st.hook_room = st.hook_room or {}
                    st.hook_room[e.key] = e.room
                else
                    t.missed = true
                end
            end
            table.insert(out, t)
        end
    end
    return out
end

-- The line the table hears when a lock opens.
function M.open_line(l)
    if l.kind == "door" then
        return "Somewhere behind them, " .. M.door_name(l.a, l.b) .. ", the one that wouldn't budge, swings open."
    elseif l.kind == "room" then
        return "The way into " .. M.the(l.room) .. ", shut all this time, swings open."
    elseif l.kind == "person" then
        return M.person_name(l.person) .. " steps out of hiding."
    end
    return "Something that was shut opens."
end

function M.fired_line(c, t)
    local e = t.effect
    if e.kind == "hook" and not t.missed then
        return "(Your tie: what " .. M.hero_name(e.key, c) .. " came for is waiting in " .. M.the(e.room) .. " now.)"
    end
end

-- Between sessions: open what's come true, and queue the lines for the next game night.
function M.week(c)
    local st = c.adv
    if not (st and st.locks and #st.locks > 0) then
        return
    end
    st.lock_news = st.lock_news or {}
    for _, l in ipairs(M.open_locks(c)) do
        table.insert(st.lock_news, M.open_line(l))
    end
    M.unstick(c)
end

-- The lines waiting from between sessions (once).
function M.news(c)
    local st = c.adv
    local out = st and st.lock_news or {}
    if st then
        st.lock_news = {}
    end
    return out
end

-- A safety net: a party with nowhere at all to go (every way on shut, nothing left to play) goes
-- back for a room it walked past, or failing that the stuck locks give. Validation keeps this from
-- happening; it's here so a week can never stall.
function M.unstick(c)
    local st = st_of(c)
    if st.ending or not st.pos or not st.done[st.pos] or #adventure.frontier(c) > 0 or adventure.boss_week(c) then
        return false
    end
    local fresh = adventure.reachable(c, st.pos)
    local back = {}
    for _, id in ipairs(MODULE.order or {}) do
        if fresh[id] and st.passed[id] and not room(id).boss then
            table.insert(back, id)
        end
    end
    if #back > 0 then
        if #back == 1 then
            st.at, st.choices = back[1], nil
        else
            st.at, st.choices = nil, back
        end
        return true
    end
    local gave = false
    st.lock_news = st.lock_news or {}
    for _, l in ipairs(M.locks(c)) do
        if (l.kind == "door" or l.kind == "room") and not l.open then
            l.open = c.week or true
            l.gave = true
            gave = true
            table.insert(st.lock_news, "With nowhere else to go, " .. util.lower_first(M.open_line(l)))
        end
    end
    if gave then
        M.changed(c)
    end
    return gave
end

-- The ways on from a room that a lock is holding shut: { { id, door = bool } }.
function M.shut_ways(c, from)
    local out = {}
    if not (c.adv and c.adv.locks and #c.adv.locks > 0) or not from then
        return out
    end
    local all = adventure.options_after(c, from, true)
    local now = adventure.options_after(c, from)
    for _, id in ipairs(all) do
        if not util.contains(now, id) then
            table.insert(out, id)
        end
    end
    return out
end

-- "The way into the Hall of Paintings won't open yet." (nil when nothing's shut).
function M.shut_line(c, from)
    local ids = M.shut_ways(c, from)
    if #ids == 0 then
        return nil
    end
    local names = {}
    for _, id in ipairs(ids) do
        table.insert(names, M.the(id))
    end
    if #names == 1 then
        return "The way into " .. names[1] .. " won't open yet."
    end
    return "The ways into " .. util.join_names(names) .. " won't open yet."
end

-- What the editor shows on a card -----------------------------------------------------------------

-- A moment's ins, in words: when in the room it comes up, and what it needs.
function M.moment_ins(c, m)
    local out = {}
    local at = { start = "As they come in", mid = "Partway through", ["end"] = "On the way out" }
    table.insert(out, at[m.at or "start"] or "In the room")
    local function need(cond, neg)
        if not cond or not next(cond) then
            return
        end
        local words
        if cond.knob then
            local k = (MODULE.knobs or {})[cond.knob]
            words = k and ("you chose \"" .. k.name .. "\"") or "a choice in prep"
        elseif cond.flag then
            words = M.flag_name(cond.flag) and ("someone " .. util.mid_sentence(M.flag_name(cond.flag), {})) or "something earlier"
        elseif cond.mark then
            words = card_words() .. " shows \"" .. M.mark_name(cond.mark) .. "\""
        elseif cond.talk then
            words = "she's easy to talk round"
        end
        if words then
            table.insert(out, (neg and "unless " or "only if ") .. words)
        end
    end
    need(m.when)
    need(m.unless, true)
    for _, pid in ipairs(adventure.moment_people(m)) do
        table.insert(out, "with " .. M.person_name(pid))
    end
    return out
end

-- What one `mus` hands out, as short words: { "1 Franc", "\"Pulled a weapon out of a painting\"", ... }.
function M.mus_words(mus)
    local out = {}
    if not mus then
        return out
    end
    if mus.flag and M.flag_name(mus.flag) then
        table.insert(out, "\"" .. M.flag_name(mus.flag) .. "\"")
    end
    if mus.mark then
        table.insert(out, "on " .. card_words() .. ": \"" .. M.mark_name(mus.mark) .. "\"")
    end
    if mus.unmark then
        table.insert(out, "takes \"" .. M.mark_name(mus.unmark) .. "\" off " .. card_words())
    end
    if mus.francs then
        table.insert(out, util.int(mus.francs) .. (mus.francs == 1 and " Franc" or " Francs"))
    end
    if mus.spend then
        table.insert(out, "spends " .. util.int(mus.spend) .. " Francs")
    end
    if mus.careful then
        table.insert(out, "gentle with the exhibits")
    end
    if mus.favor then
        local who = (MODULE.favors or {})[mus.favor.who]
        table.insert(out, (who and who.name or mus.favor.who) .. (mus.favor.n > 0 and " likes it" or " minds"))
    end
    if mus.fight then
        table.insert(out, "starts the fight")
    end
    if mus.no_fight then
        table.insert(out, "no fight")
    end
    if mus.ending then
        local e = (MODULE.endings or {})[mus.ending]
        table.insert(out, "ends it: " .. (e and e.name or mus.ending))
    end
    return out
end

-- A moment's outs: each option, with what it hands out (only the ones that hand out something).
function M.moment_outs(m)
    local out = {}
    for _, o in ipairs(m.options or {}) do
        local words = M.mus_words(o.mus)
        if o.roll then
            local s = M.mus_words(o.roll.success and o.roll.success.mus)
            local f = M.mus_words(o.roll.fail and o.roll.fail.mus)
            if #s > 0 then
                table.insert(words, "if it works: " .. table.concat(s, ", "))
            end
            if #f > 0 then
                table.insert(words, "if not: " .. table.concat(f, ", "))
            end
        end
        if #words > 0 then
            table.insert(out, { label = M.plain(o.label), words = words })
        end
    end
    return out
end

-- The conditions a card's outs can be (for a tie from that card): its flags and marks.
function M.moment_conds(m)
    local out, seen = {}, {}
    each_mus(m, function(_, mus)
        if mus.flag and M.flag_name(mus.flag) and not seen["f" .. mus.flag] then
            seen["f" .. mus.flag] = true
            table.insert(out, { kind = "flag", flag = mus.flag })
        end
        if mus.mark and not seen["m" .. mus.mark] then
            seen["m" .. mus.mark] = true
            table.insert(out, { kind = "mark", mark = mus.mark })
        end
    end)
    return out
end

-- The marks a room can leave on her card without a moment (MODULE.marks[id].from) and if it's left
-- behind (MODULE.left_behind).
function M.room_marks(id)
    local out = {}
    for _, mid in ipairs(MODULE.mark_order or {}) do
        local def = MODULE.marks[mid]
        if def and util.contains(def.from or {}, id) then
            table.insert(out, { mark = mid, how = def.why })
        end
    end
    local lb = (MODULE.left_behind or {})[id]
    if lb and lb.mark then
        local dup
        for _, o in ipairs(out) do
            dup = dup or o.mark == lb.mark
        end
        if dup then
            for _, o in ipairs(out) do
                if o.mark == lb.mark then
                    o.how = o.how .. ", or if they never go in"
                end
            end
        else
            table.insert(out, { mark = lb.mark, how = "if they never go in" })
        end
    end
    return out
end

-- The moments of a room, in their order.
function M.room_moments(id)
    local out = {}
    for _, m in ipairs(MODULE.moments or {}) do
        if m.room == id then
            table.insert(out, m)
        end
    end
    return out
end

-- The heroes whose reason for coming pays off in a room (by the hook as it stands now).
function M.room_hooks(c, id)
    local out = {}
    for _, p in ipairs(c.players or {}) do
        local h = adventure.hook(c, p.key)
        if h and h.room == id then
            table.insert(out, { key = p.key, hook = h })
        end
    end
    return out
end

-- Every condition the DM can pick, by tab: { { id, name, chips = { { cond, label } } } }.
function M.cond_tabs(c, only)
    local tabs = {}
    local function tab(id, name, chips)
        if #chips > 0 then
            table.insert(tabs, { id = id, name = name, chips = chips })
        end
    end
    if only then
        local chips = {}
        for _, cond in ipairs(only) do
            table.insert(chips, { cond = cond, label = M.chip(cond) })
        end
        tab("outs", "What this card can do", chips)
        return tabs
    end
    local rooms = {}
    for _, id in ipairs(M.map_rooms()) do
        if not room(id).boss then
            table.insert(rooms, { cond = { kind = "room", room = id }, label = M.room_name(id) })
        end
    end
    tab("room", "A room they've been through", rooms)
    local outs = {}
    for _, id in ipairs(M.catalog().flag_order) do
        table.insert(outs, { cond = { kind = "flag", flag = id }, label = M.flag_name(id) })
    end
    tab("flag", "Something someone did", outs)
    local marks = {}
    for _, id in ipairs(MODULE.mark_order or {}) do
        table.insert(marks, { cond = { kind = "mark", mark = id }, label = M.mark_name(id) })
    end
    tab("mark", "On " .. card_words(), marks)
    local francs = {}
    for _, n in ipairs(M.FRANCS) do
        table.insert(francs, { cond = { kind = "francs", n = n }, label = util.int(n) .. " Francs or more" })
    end
    tab("francs", "Francs", francs)
    local sessions = {}
    local w = math.max(1, (c.week or 1))
    for n = w, math.min(MODULE.MAX_WEEKS or 8, w + 5) do
        table.insert(sessions, { cond = { kind = "session", n = n }, label = "Session " .. util.int(n) })
    end
    tab("session", "Not before session", sessions)
    return tabs
end

return M
