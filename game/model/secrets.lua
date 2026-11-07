-- Secrets, and what the table knows (docs/design/2026-11-05-secrets-and-knowledge.md; Conner's calls of
-- November 5: reveals cost nothing, the friends dig by their kind of player, their hero and the clues they
-- have, each hero's knowledge is tracked, and the prep board shows how each secret could come out).
--
-- One record per thing the DM knows that the table doesn't (`MODULE.secrets`, with the names the table
-- mustn't hear yet in `MODULE.told`: the same keys). Each secret says what it is (the DM's words, with the
-- book's page), what kind of thing holds it (a person, a document, a place, a body, an item, a creature), who
-- or what holds it, the lines the DM says when it comes out (`tell`) and when only a hint does (`hint`), and
-- the ways it can come out (`paths`): the book's own reveal, and more by the kind of thing it is (`DEFAULTS`).
--
-- What's known, per secret: campaign.adv.known[key] = { level = "hint" | "known" (the most anyone at the
-- table has), heard = level (said out loud to the whole table), heroes = { [hero key] = level } (what each
-- hero knows in character), parts = { [i] = week } (a secret told a line at a time: the tablet), how, by, week }.
-- A line said out loud teaches the heroes in the scene (night:at_hand); a note passed to one hero teaches
-- that hero; a hero who learned something alone tells the others when they're back together (`share`).
--   level(c, key, hero)   nil, "hint" or "known": the table's, or one hero's in character
--   learn(c, key, level, opts)   it comes out: opts.how (the path's kind, or "dm", "said"), by (a hero key),
--                          heroes (who learns; default the heroes in the scene), private (a note, not said
--                          out loud), path (the path)
--   paths(key)             the ways it can come out: { kind, on, skill, dc, gives, spell, item, room, spot, ... }
--   held_by(c, id)         the secrets someone (or something) holds, the DM's plants included
--   plant(c, key, id)      the DM gives someone a secret to keep
--   hold(c, key)           the DM holds it back tonight: no path opens it this session
--   ask(c, key, level)     the DM's "Reveal now" / "Drop a hint": said at the night's next beat
-- Pure Lua.

local util = require "game.model.util"

local M = {}

local RANK = { hint = 1, known = 2 }
M.RANK = RANK

local function module()
    local ok, adv = pcall(require, "game.model.adventure")
    return (ok and adv and adv.data) or {}
end

-- Every secret, the names the table mustn't hear yet merged in (MODULE.told: words, intro, mask, always).
local cache_for, cache
function M.defs()
    local mod = module()
    if cache_for == mod and cache then
        return cache
    end
    local out = {}
    for k, d in pairs(mod.told or {}) do
        out[k] = {}
        for f, v in pairs(d) do
            out[k][f] = v
        end
    end
    for k, d in pairs(mod.secrets or {}) do
        local e = out[k] or {}
        for f, v in pairs(d) do
            e[f] = v
        end
        out[k] = e
    end
    cache_for, cache = mod, out
    return out
end

function M.def(key)
    return M.defs()[key]
end

-- The secrets proper (what the DM knows): those with something to say when they come out.
function M.list()
    local out = {}
    for k, d in util.sorted_pairs(M.defs()) do
        if d.what then
            table.insert(out, k)
        end
    end
    return out
end

-- The night being played (a night sets it as it starts): who's in the scene when a line is said.
M.night = nil
function M.use(night)
    M.night = night
end

local function party_keys(c)
    local out = {}
    for _, p in ipairs((c and c.players) or {}) do
        table.insert(out, p.key)
    end
    return out
end

-- Who hears a line said out loud now: the heroes in this scene (a hero who went off alone doesn't).
function M.here(c)
    local night = M.night
    if night and night.campaign == c and night.scene and night.at_hand then
        local out = {}
        for _, p in ipairs(night:at_hand()) do
            table.insert(out, p.key)
        end
        -- (And anyone whose hero can't act but is at the table: stone hears, down doesn't, but the player
        -- at the table hears it all the same. What a hero knows in character is what they were there for.)
        if #out > 0 then
            return out
        end
    end
    return party_keys(c)
end

function M.state(c)
    local adv = c and c.adv
    if not adv then
        return nil
    end
    adv.known = adv.known or {}
    -- (A save from before secrets: what the table had been told, everyone knows.)
    if adv.told and not adv.known_from_told then
        adv.known_from_told = true
        for k, wk in util.sorted_pairs(adv.told) do
            if not adv.known[k] then
                local heroes = {}
                for _, hk in ipairs(party_keys(c)) do
                    heroes[hk] = "known"
                end
                adv.known[k] = { level = "known", heard = "known", heroes = heroes, week = wk, how = "said" }
            end
        end
    end
    return adv.known
end

-- nil, "hint" or "known". hero: what that hero knows in character. player: what that friend knows
-- (anything said out loud, and what their hero knows).
function M.level(c, key, hero, player)
    local st = M.state(c)
    local e = st and st[key]
    if not e then
        return nil
    end
    if hero then
        return e.heroes and e.heroes[hero] or nil
    end
    if player then
        local a, b = e.heard, e.heroes and e.heroes[player]
        if (RANK[a] or 0) >= (RANK[b] or 0) then
            return a
        end
        return b
    end
    return e.level
end

function M.knows(c, key, hero, player)
    return M.level(c, key, hero, player) == "known"
end

function M.hinted(c, key, hero, player)
    return M.level(c, key, hero, player) ~= nil
end

local function raise(cur, to)
    if (RANK[to] or 0) > (RANK[cur] or 0) then
        return to
    end
    return cur
end

-- It comes out. Returns true if anything new was learned.
function M.learn(c, key, level, opts)
    opts = opts or {}
    level = level or "known"
    local st = M.state(c)
    if not st then
        return false
    end
    local d = M.def(key) or {}
    local e = st[key] or { heroes = {} }
    e.heroes = e.heroes or {}
    local heroes = opts.heroes or (opts.by and opts.private and { opts.by }) or M.here(c)
    local new = (RANK[level] or 0) > (RANK[e.level] or 0)
    for _, hk in ipairs(heroes) do
        local was = e.heroes[hk]
        e.heroes[hk] = raise(was, level)
        new = new or e.heroes[hk] ~= was
    end
    if not opts.private then
        e.heard = raise(e.heard, level)
    end
    local was_level = e.level
    e.level = raise(e.level, level)
    if e.level ~= was_level then
        e.week = c.week or 0
        e.how = opts.how or e.how
        e.by = opts.by or e.by
    end
    st[key] = e
    if e.level == "known" and was_level ~= "known" then
        -- (Known as a whole, not piece by piece: then it has every piece.)
        if d.parts and not opts.from_part then
            e.parts = e.parts or {}
            for i = 1, #d.parts do
                e.parts[i] = e.parts[i] or (c.week or 0)
            end
        end
        -- (What it unlocks: the flags other systems read, the names it tells with it.)
        local u = d.unlocks
        if u and u.flag then
            c.adv.flags = c.adv.flags or {}
            c.adv.flags[u.flag] = true
        end
        for _, k in ipairs(d.with or {}) do
            M.learn(c, k, "known", { how = opts.how, by = opts.by, heroes = heroes, private = opts.private })
        end
    end
    if new and d.what and opts.log ~= false then
        local events = util.lazy("game.model.events")
        local night = M.night
        local where = night and night.campaign == c and night.scene and night.scene.room or nil
        local hint_ev = level == "known" and events.last(c, { kind = "learn", what = key, level = "hint" }) or nil
        -- (The whole truth follows from the hint that set them digging: a real cause, "therefore".)
        events.add(c, { kind = "learn", what = key, level = level, way = opts.how or "said", who = opts.by or "party",
                        where = where or nil, from = hint_ev and hint_ev.id or nil, heard = not opts.private })
    end
    return new
end

function M.hint(c, key, opts)
    return M.learn(c, key, "hint", opts)
end

function M.reveal(c, key, opts)
    return M.learn(c, key, "known", opts)
end

-- A secret told a part at a time (the tablet's seven lines, p12): learn part i. Once the parts it needs are
-- all in (`needs`, or every part), it's known; until then, a hint. Returns true if the part is new.
function M.learn_part(c, key, i, opts)
    local st = M.state(c)
    local d = M.def(key) or {}
    local e = st[key] or { heroes = {} }
    st[key] = e
    e.parts = e.parts or {}
    if e.parts[i] then
        return false
    end
    e.parts[i] = c.week or 0
    local all = true
    for _, j in ipairs(d.needs or {}) do
        if not e.parts[j] then
            all = false
        end
    end
    if not d.needs then
        for j = 1, #(d.parts or {}) do
            if not e.parts[j] then
                all = false
            end
        end
    end
    local o = {}
    for f, v in pairs(opts or {}) do
        o[f] = v
    end
    o.from_part = true
    M.learn(c, key, all and "known" or "hint", o)
    return true
end

function M.parts_known(c, key)
    local st = M.state(c)
    local e = st and st[key]
    local out = {}
    for i in util.sorted_pairs((e and e.parts) or {}) do
        table.insert(out, i)
    end
    table.sort(out)
    return out
end

-- The parts nobody's found yet.
function M.parts_left(c, key)
    local d = M.def(key) or {}
    local st = M.state(c)
    local e = st and st[key]
    local out = {}
    for i = 1, #(d.parts or {}) do
        if not (e and e.parts and e.parts[i]) then
            table.insert(out, i)
        end
    end
    return out
end

-- Who knows it in character: { hero key = level }.
function M.who(c, key)
    local st = M.state(c)
    local e = st and st[key]
    return (e and e.heroes) or {}
end

-- What a hero knows that someone else in the scene doesn't: { key... }.
function M.unshared(c, hk, others)
    local out = {}
    for key, e in util.sorted_pairs(M.state(c) or {}) do
        local mine = e.heroes and e.heroes[hk]
        if mine and (M.def(key) or {}).what then
            for _, o in ipairs(others) do
                if o ~= hk and (RANK[(e.heroes or {})[o]] or 0) < RANK[mine] then
                    table.insert(out, key)
                    break
                end
            end
        end
    end
    return out
end

-- A new night: whatever was said out loud at the table, every hero here has caught up on (the friends talk
-- between sessions, and the recap goes round). What one hero heard alone, a note or a whisper, stays theirs.
function M.catch_up(c, keys)
    local st = M.state(c)
    if not st then
        return
    end
    keys = keys or party_keys(c)
    for _, e in util.sorted_pairs(st) do
        if e.heard then
            e.heroes = e.heroes or {}
            for _, hk in ipairs(keys) do
                e.heroes[hk] = raise(e.heroes[hk], e.heard)
            end
        end
    end
end

-- A hero tells the others what they learned alone. Returns the keys shared.
function M.share(c, hk, others)
    local keys = M.unshared(c, hk, others)
    for _, key in ipairs(keys) do
        local mine = M.level(c, key, hk)
        M.learn(c, key, mine, { how = "shared", by = hk, heroes = others, log = false })
    end
    return keys
end

-- The ways out --------------------------------------------------------------------------------

-- What every kind of secret can come out by, besides what the book says (the design note's defaults):
-- a person's by reading them (a hint), talking them round, leaning on them, a good enough opinion, or a
-- spell; a document's by study or a spell; a place's by searching; a body's by examining it; an item's by
-- study; a creature's by knowing its kind. The book's own path, where there is one, says its DC.
-- (5e's: its skills and spells. Another rule set's adventure takes its set's own, `secret_defaults`: no leaks.)
M.DEFAULTS = {
    rules = "5e",
    person = {
        { kind = "check", skill = { "insight" }, dc = 13, gives = "hint" },
        { kind = "check", skill = { "persuasion" }, dc = 14, gives = "known" },
        { kind = "check", skill = { "intimidation" }, dc = 15, gives = "known" },
        { kind = "check", skill = { "deception" }, dc = 15, gives = "known" },
        { kind = "perform", skill = { "performance" }, dc = 13, gives = "known", opinion = "neutral" },
        { kind = "trade", francs = 1, gives = "hint", opinion = "neutral" },
        { kind = "ask", opinion = "warm", gives = "known" },
        { kind = "spell", spell = { "detect_thoughts", "zone_of_truth", "charm_person" }, gives = "known" },
        { kind = "check", skill = { "stealth" }, dc = 14, gives = "hint", eavesdrop = true },
    },
    document = {
        { kind = "read", skill = { "investigation", "history", "arcana", "religion" }, dc = 13, gives = "known" },
        { kind = "spell", spell = { "comprehend_languages" }, gives = "known" },
    },
    place = {
        { kind = "check", skill = { "investigation", "perception" }, dc = 13, gives = "known" },
        { kind = "spell", spell = { "detect_magic" }, gives = "hint" },
    },
    body = {
        { kind = "check", skill = { "medicine", "investigation" }, dc = 12, gives = "known" },
        { kind = "spell", spell = { "speak_with_dead" }, gives = "known" },
    },
    item = {
        { kind = "check", skill = { "arcana" }, dc = 13, gives = "known" },
        { kind = "spell", spell = { "identify", "detect_magic" }, gives = "known" },
    },
    creature = {
        { kind = "check", skill = { "arcana", "nature", "religion", "history" }, dc = 13, gives = "known" },
    },
}

-- The usual ways out for a kind of secret, by the adventure's rule set.
local function defaults_for(kind)
    local ruleset = require "game.model.ruleset"
    local defs = ruleset.fits(M.DEFAULTS) and M.DEFAULTS or ruleset.current().secret_defaults or {}
    return defs[kind or ""]
end
M.defaults_for = defaults_for

M.KIND_WORDS = { check = "a check", ask = "asking", read = "reading", see = "seeing it", spell = "a spell",
                 perform = "a performance", trade = "a trade", steal = "stealing it", event = "it happening", dm = "you" }

-- A path's holder: the secret's own unless the path names one.
local function holder_of(d, p)
    -- (A place or a thing is written on = { room, spot } or { item }: spread out, as the defaults have it.)
    if type(p.on) == "table" then
        local out = {}
        for f, v in pairs(p) do
            out[f] = v
        end
        out.on, out.room, out.spot, out.item = nil, p.on.room, p.on.spot, p.on.item
        return out
    end
    if p.on or p.item or p.spot or p.room then
        return p
    end
    local h = d.on or {}
    local out = {}
    for f, v in pairs(p) do
        out[f] = v
    end
    out.on, out.item, out.room, out.spot = h.on, h.item, h.room, h.spot
    if not out.on and type(d.held_by) == "table" then
        local h = d.held_by[1]
        out.on = type(h) == "table" and h.on or h
    end
    return out
end

local function same_way(a, b)
    if a.kind ~= b.kind or (a.on or "") ~= (b.on or "") or (a.item or "") ~= (b.item or "") or (a.spot or "") ~= (b.spot or "") then
        return false
    end
    local sa = (a.skill or a.spell or {})[1]
    for _, s in ipairs(b.skill or b.spell or {}) do
        for _, t in ipairs(a.skill or a.spell or {}) do
            if s == t then
                return true
            end
        end
    end
    return sa == nil and (b.skill or b.spell) == nil
end

-- The ways it can come out: the book's (and the module's) first, then the defaults for its kind of thing
-- that don't repeat one of those, for each holder. Every secret can also come out by the DM (kind "dm").
function M.paths(key, c)
    local d = M.def(key)
    if not d then
        return {}
    end
    local out = {}
    for _, p in ipairs(d.paths or {}) do
        table.insert(out, holder_of(d, p))
    end
    local kind_defaults = d.defaults ~= false and defaults_for(d.type) or nil
    if kind_defaults then
        local holders = {}
        if d.on then
            table.insert(holders, d.on)
        end
        -- (A holder can know only part of it, in their own words: Telpur's "horrible lady" is a hint.)
        for _, h in ipairs(type(d.held_by) == "table" and d.held_by or {}) do
            table.insert(holders, type(h) == "table" and h or { on = h })
        end
        for _, id in ipairs(c and M.planted(c, key) or {}) do
            table.insert(holders, { on = id, planted = true })
        end
        for _, h in ipairs(holders) do
            for _, dp in ipairs(kind_defaults) do
                local p = {}
                for f, v in pairs(dp) do
                    p[f] = v
                end
                p.on, p.item, p.room, p.spot, p.planted = h.on, h.item, h.room, h.spot, h.planted
                p.default = true
                -- (A person who only knows part of it gives what they know: a hint-holder never the whole, and
                -- in their own words.)
                if h.gives == "hint" then
                    p.gives = "hint"
                end
                p.says, p.hint_says = h.says or p.says, h.hint_says or p.hint_says
                local dup = false
                for _, q in ipairs(out) do
                    if same_way(q, p) then
                        dup = true
                    end
                end
                if not dup then
                    table.insert(out, p)
                end
            end
        end
    end
    table.insert(out, { kind = "dm", gives = "known" })
    return out
end

-- Something happened in play that shows a secret (an `event` path: her hood off, the hedges waking, the
-- scarabs pouring out): learn what it gives. opts as learn's. Returns the keys learned.
function M.event(c, name, opts)
    local out = {}
    for _, key in ipairs(M.list()) do
        for _, p in ipairs((M.def(key) or {}).paths or {}) do
            if p.kind == "event" and p.event == name then
                local o = {}
                for f, v in pairs(opts or {}) do
                    o[f] = v
                end
                o.how, o.path = "event", p
                if p.private and o.by then
                    o.private, o.heroes = true, { o.by }
                end
                if M.learn(c, key, p.gives or "known", o) then
                    table.insert(out, key)
                end
            end
        end
    end
    return out
end

-- Who holds it: its people (and the DM's plants).
function M.planted(c, key)
    local adv = c and c.adv
    local t = adv and adv.secret_plants and adv.secret_plants[key]
    return t or {}
end

function M.plant(c, key, id)
    c.adv.secret_plants = c.adv.secret_plants or {}
    local t = c.adv.secret_plants[key] or {}
    for _, x in ipairs(t) do
        if x == id then
            return
        end
    end
    table.insert(t, id)
    c.adv.secret_plants[key] = t
end

function M.unplant(c, key, id)
    local t = M.planted(c, key)
    for i, x in ipairs(t) do
        if x == id then
            table.remove(t, i)
            return
        end
    end
end

function M.holds(c, key, id)
    local d = M.def(key) or {}
    for _, x in ipairs(type(d.held_by) == "table" and d.held_by or {}) do
        if x == id or (type(x) == "table" and x.on == id) then
            return true
        end
    end
    if d.on and d.on.on == id then
        return true
    end
    for _, p in ipairs(d.paths or {}) do
        if p.on == id then
            return true
        end
    end
    for _, x in ipairs(M.planted(c, key)) do
        if x == id then
            return true, "planted"
        end
    end
    return false
end

-- The secrets someone holds: { key... }.
function M.held_by(c, id)
    local out = {}
    for _, key in ipairs(M.list()) do
        if M.holds(c, key, id) then
            table.insert(out, key)
        end
    end
    return out
end

-- The DM's say in when ------------------------------------------------------------------------

-- Held back tonight: no path opens it this session (the DM's "Hold it back").
function M.held(c, key)
    local h = c.adv and c.adv.secret_held
    return h ~= nil and h[key] ~= nil and h[key] == (c.week or 0)
end

function M.hold(c, key, on)
    c.adv.secret_held = c.adv.secret_held or {}
    if on == false then
        c.adv.secret_held[key] = nil
    else
        c.adv.secret_held[key] = c.week or 0
    end
end

-- "Reveal now" / "Drop a hint": the night says it at its next beat (museum_night.dm_reveals).
function M.ask(c, key, level)
    c.adv.secret_asks = c.adv.secret_asks or {}
    for _, a in ipairs(c.adv.secret_asks) do
        if a.key == key then
            a.level = raise(a.level, level)
            return
        end
    end
    table.insert(c.adv.secret_asks, { key = key, level = level })
end

function M.asked(c)
    return (c.adv and c.adv.secret_asks) or {}
end

function M.take_asks(c)
    local list = M.asked(c)
    if c.adv then
        c.adv.secret_asks = nil
    end
    return list
end

-- What the DM says when it comes out: the path's own words, else the secret's (three ways each, fresh).
function M.line(night, key, level, path, vars)
    local d = M.def(key) or {}
    local list
    if level == "hint" then
        list = (path and path.hint_says) or d.hint
    else
        list = (path and path.says) or d.tell
    end
    if type(list) == "string" then
        list = { list }
    end
    if not list or #list == 0 then
        return nil
    end
    local text = night and night.fresh and night:fresh(list, "secret_" .. key .. "_" .. level) or list[1]
    return util.sentence_case(util.fill(text, vars or {}))
end

-- The DM's words for a path's holder: a person's name, a place's on its board, a thing's name.
local function place_name(room, spot)
    local ok, lib = pcall(require, "game.data.map_library")
    local cur = util.lazy("game.model.adventure").current()
    for _, b in util.sorted_pairs(ok and lib.boards or {}) do
        if b.room == room and (b.adventure == nil or b.adventure == cur) then
            for _, pl in ipairs(b.places or {}) do
                if pl.id == spot then
                    return pl.name
                end
            end
        end
    end
    return nil
end

function M.holder_name(p)
    if type(p.on) == "string" then
        local n = util.lazy("game.model.npcs").get(p.on)
        return n and (n.short or n.name) or p.on
    end
    if p.item then
        local items = util.lazy("game.model.items")
        local def = items.thing(p.item) or items.def(p.item)
        return def and util.lower_first(def.name) or p.item
    end
    if p.spot then
        return place_name(p.room, p.spot)
    end
    return nil
end

-- One way out, for the DM: "Persuasion 12 on Flitwidget (the book's)", "Insight 12 on Flitwidget, for a hint",
-- "asking Telpur once he likes them", "her hood coming off".
local SKILL_NAME = function(s)
    return util.lazy("game.model.ruleset").current().name(s)
end
M.EVENT_WORDS = { hood_off = "her hood coming off", fight_garden = "the hedges waking", tentacles = "the pond grabbing someone", mech_burnt = "the Mech burning out",
                  fight_entrance = "the statue waking", scarabs = "the scarabs pouring out", fight_hunting = "fighting them",
                  paint_hit = "a painted weapon hitting it", whisper = "the whisper, to one hero alone", deafened = "someone fighting him deafened" }
function M.way_text(p)
    local on = M.holder_name(p)
    local at = on and (" on " .. on) or ""
    local text
    if p.kind == "check" or p.kind == "read" then
        local names = {}
        for _, s in ipairs(p.skill or {}) do
            table.insert(names, SKILL_NAME(s))
        end
        if #names == 0 then
            text = "reading " .. (on or "it")
        else
            text = table.concat(names, " or ") .. (p.dc and (" " .. p.dc) or "") .. ((p.kind == "read" and on) and (", reading " .. on) or at)
        end
    elseif p.kind == "spell" then
        local names = {}
        for _, s in ipairs(p.spell or {}) do
            table.insert(names, util.capitalize((string.gsub(s, "_", " "))))
        end
        text = table.concat(names, " or ") .. at
    elseif p.kind == "ask" then
        text = "asking " .. (on or "them") .. (p.opinion == "warm" and " once they like the party" or "")
    elseif p.kind == "perform" then
        text = "a song or a show for " .. (on or "them")
    elseif p.kind == "trade" then
        text = "paying " .. (on or "them") .. " a Franc"
    elseif p.kind == "see" then
        text = "seeing " .. (on or "it")
    elseif p.kind == "event" then
        text = M.EVENT_WORDS[p.event or ""] or "it happening"
    elseif p.kind == "dm" then
        text = "you telling them"
    else
        text = p.kind
    end
    if p.gives == "hint" then
        text = text .. ", for a hint"
    elseif p.gives == "part" then
        text = text .. ", a line at a time"
    end
    if p.needs == "hint" then
        text = text .. " (once they've a hint)"
    end
    if p.book then
        text = text .. " (the book's)"
    end
    return text
end

-- Every way out, for the DM's lists: the book's first, then the module's, then the usual ones for its kind.
function M.ways_text(key, c, max)
    local book, own, usual = {}, {}, {}
    for _, p in ipairs(M.paths(key, c)) do
        if p.kind ~= "dm" then
            table.insert(p.book and book or (p.default and usual or own), M.way_text(p))
        end
    end
    local all = {}
    for _, list in ipairs({ book, own, usual }) do
        for _, t in ipairs(list) do
            if not max or #all < max then
                table.insert(all, t)
            end
        end
    end
    return table.concat(all, "; ")
end

-- The secrets that can come out in a room (for the prep board): those whose room it is, or with a path there.
function M.in_room(room, c)
    local out = {}
    for _, key in ipairs(M.list()) do
        local d = M.def(key)
        local here = d.room == room
        if not here then
            for _, p in ipairs(M.paths(key, c)) do
                if p.room == room then
                    here = true
                end
            end
        end
        if here then
            table.insert(out, key)
        end
    end
    return out
end

-- A short phrase for a secret, for the DM's lists: its `name`, else what it is.
function M.name(key)
    local d = M.def(key) or {}
    return d.name or d.what or key
end

-- Where a secret stands for the DM: "Nobody knows", "A hint (Thessaly)", "Known (everyone)".
function M.standing(c, key)
    local lv = M.level(c, key)
    if not lv then
        return "The table doesn't know.", "dim"
    end
    local who = {}
    local all = true
    for _, p in ipairs(c.players or {}) do
        local l = M.level(c, key, p.key)
        if l == lv then
            table.insert(who, p.char or p.key)
        else
            all = false
        end
    end
    local names = all and "everyone" or table.concat(who, ", ")
    if lv == "hint" then
        return "A hint so far (" .. names .. ").", "gold"
    end
    return "They know (" .. names .. ").", "green"
end

return M
