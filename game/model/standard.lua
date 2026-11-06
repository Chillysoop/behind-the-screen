-- The adventure standard, turned into what game night plays (docs/design/adventure-standard.md; Conner, November 6:
-- any adventure he uploads or we write together, and in the end one a DM makes in the game). An adventure written in
-- the standard says what it is: its places by layer, its people, its creatures, its story events with their choices,
-- its secrets and endings. Game night was built on the museum's shapes: rooms with their cards (a place, who's
-- there, a goal, a snag, a prize), the moments in each room, the links between them, the fights' line-ups. This file
-- makes the second from the first, so the night plays any adventure in the standard, and the creation tool only
-- ever writes the standard.
--
--   M.compile(mod)   fills in the tables game night reads (rooms, order, start, links, moments, cards, and quiet
--                    defaults for the museum's own tables), from mod.places' scenes and mod.events. An adventure
--                    that has rooms already (the museum) is left as it is.
--   M.cards(mod)     the cards its rooms are dealt (content.lua reads them like the museum's).
--   M.creatures(mod) its own creatures as stat blocks for the rules (a core block with the book's changes, or the
--                    book's own numbers), keyed "<adventure>_<id>".
--
-- What a scene says, on an area of M.places (all of it plain data a DM could fill in by hand):
--   scene = { type = "social" | "combat" | "exploration" | "puzzle" | "downtime", sum = "...",
--             goal = { name, line, win, lose, got },                 -- what the party's here to do
--             cast = "<person id>",                                  -- who's here to talk to (M.people)
--             foes = { "<creature id>", ... }, boss_name = "...",    -- who fights them (M.creatures)
--             optional_fight = true, quick = true, stop = true, rest = true,
--             snag = { name, line, skill = {...} }, prize = { name, line, got } }
-- And a story event with `options` (game night's choice records: label, want, short, lean, log, roll, mus, tells,
-- when) plays as a moment where it happens (`at`), at the start of the scene, mid-way or at its end (`when`).

local util = require "game.model.util"

local M = {}

local function deep_copy(t)
    if type(t) ~= "table" then
        return t
    end
    local o = {}
    for k, v in pairs(t) do
        o[k] = deep_copy(v)
    end
    return o
end

-- What the museum's night reads that an adventure in the standard needn't have: quiet defaults, so a missing one is
-- "none", never an error. (The museum's own values stay its own.)
local DEFAULTS = {
    knobs = {}, moments = {}, explore = {}, explore_say = {}, behind_doors = {}, marks = {}, mark_order = {},
    sides = {}, outs = {}, broke_words = {}, items = {}, pocketables = {}, friction = {}, ruling_costs = {},
    keepsakes = {}, recap_beats = {}, beats = {}, recap = {}, asides = {}, ally_join = {}, ally_lines = {},
    reinforcements = {}, companions = {}, forks = {}, fork_at = {}, pull = {}, second_look = {}, revisit_why = {},
    left_behind = {}, no_return = {}, portraits = {}, requests = {}, loose_ends = {}, favors = {}, names_heard = {},
    foe_names = {}, lead_order = {}, foe_pronouns = {}, want_more = {}, want_more_sad = {}, chat = {}, chat_ask = {},
    chat_banter = {}, chat_intro = {}, chat_news = {}, memory = {}, talk = {}, npc_lines = {}, openings = {},
    openings_from = {}, mech_names = {}, answer_like = {}, prep_notes = {}, content_names = {}, all_in = {},
    thoughts = {}, epilogue = {}, after_talk = {}, people_lines = {}, people_memory = {}, ideas = {},
    ANSWERS = { "yes", "laugh", "reason", "danger" },
    ANSWER_NAMES = { yes = "Yes", laugh = "Yes, with a laugh", reason = "Yes, for a reason", danger = "Yes, but it's dangerous" },
    MAX_WEEKS = 4, BUDGET = 10, UNPREPPED_QUALITY = 0.22, CAREFUL_AT = 3, FAVOR_AT = 2,
}

-- The friends' kinds of player who'd enjoy an option, by how it leans (game night's effects), when the adventure
-- doesn't say: bold for the fighters and stirrers, safe for the planners, talk for the actors and storytellers.
local LEAN_FUN = {
    bold = { { "arch:butt_kicker", fun = 3 }, { "arch:instigator", fun = 2 }, { "all", challenge = 3 } },
    safe = { { "arch:tactician", fun = 3 }, { "arch:casual", fun = 2 } },
    talk = { { "arch:method_actor", fun = 3 }, { "arch:storyteller", fun = 2 } },
    look = { { "arch:explorer", fun = 3 }, { "arch:storyteller", fun = 1 } },
}

local function place_list(mod)
    local by = {}
    for _, pl in ipairs(mod.places or {}) do
        by[pl.id] = pl
    end
    return by
end

local function person(mod, id)
    for _, p in ipairs(mod.people or {}) do
        if p.id == id then
            return p
        end
    end
end

-- The areas that play as scenes, in the order the adventure lists them.
local function scenes(mod)
    local out = {}
    for _, pl in ipairs(mod.places or {}) do
        if pl.scene then
            table.insert(out, pl)
        end
    end
    return out
end

function M.creature_id(mod, id)
    return (mod.id or "adv") .. "_" .. id
end

function M.cards(mod)
    if mod.rooms and not mod.places then
        return {}
    end
    local out = {}
    for _, pl in ipairs(scenes(mod)) do
        local sc = pl.scene
        local fits = { sc.type or "exploration" }
        table.insert(out, { id = pl.id .. "_place", kind = "location", short = util.lower_first(pl.name), name = pl.name,
                            setting = sc.setting or { "indoor" }, fits = fits, tags = sc.tags or { "explore" },
                            line = pl.read, again = sc.again })
        if sc.cast then
            local p = person(mod, sc.cast) or {}
            table.insert(out, { id = pl.id .. "_cast", kind = "cast", short = p.short or p.name or sc.cast, pronoun = p.pronoun,
                                name = p.name or sc.cast, fits = fits, tags = { "talk" }, difficulty = 1,
                                line = p.look or p.about, person = sc.cast })
        elseif sc.foes and #sc.foes > 0 then
            table.insert(out, { id = pl.id .. "_cast", kind = "cast", short = sc.foes_short or "the foes", group = #sc.foes > 1,
                                foe = true, talks = sc.talks or false, name = sc.foes_name or "The foes", fits = fits,
                                tags = { "action", "danger" }, difficulty = 1, seen = sc.seen, wake = sc.wake,
                                line = sc.foes_line or pl.read })
        end
        local g = sc.goal or {}
        table.insert(out, { id = pl.id .. "_goal", kind = "goal", name = g.name or ("Get through " .. util.lower_first(pl.name)),
                            fits = fits, tags = g.tags or { "action" }, line = g.line or ("Goal: " .. (sc.sum or pl.name) .. "."),
                            win = g.win or "They're through.", win_if = g.win_if, lose = g.lose or "They're through, battered.",
                            lose_if = g.lose_if, got = g.got or "the way on", ask = g.ask })
        if sc.snag then
            table.insert(out, { id = pl.id .. "_snag", kind = "complication", name = sc.snag.name, skill = sc.snag.skill,
                                fits = fits, tags = { "danger" }, difficulty = 1, line = sc.snag.line, moment = sc.snag.moment })
        end
        if sc.prize then
            table.insert(out, { id = pl.id .. "_prize", kind = "reward", name = sc.prize.name, fits = fits, tags = { "loot" },
                                meters = { reward = 6 }, line = sc.prize.line, got = sc.prize.got })
        end
    end
    return out
end

-- The creatures as the rules' stat blocks: a core block copied with the book's changes, or the book's own numbers.
function M.creatures(mod, roster)
    local out = {}
    for id, cr in util.sorted_pairs(mod.creatures or {}) do
        local block
        if cr.core then
            local base = roster and roster[cr.core]
            if base then
                block = deep_copy(base)
                for k, v in pairs(cr.tweaks or {}) do
                    block[k] = deep_copy(v)
                end
                for _, k in ipairs({ "int", "wis" }) do
                    if cr[k] then
                        block.abilities = block.abilities or {}
                        block.abilities[k] = cr[k]
                    end
                end
                block.name = cr.name or base.name
            end
        else
            block = deep_copy(cr)
            block.saves = cr.saves
        end
        if block then
            block.id = M.creature_id(mod, id)
            block.source = mod.id
            block.page = cr.page or block.page
            block.flees_below = cr.flees_below or block.flees_below
            block.tactics, block.note, block.mind, block.look = nil, nil, nil, block.look
            block.spellcasting, block.breath = nil, block.breath
            -- (The book's spellcasting isn't played as spells yet: a caster fights with its listed attacks, and the
            -- adventure's rule module adds the rest. game/rules/<id>.lua.)
            block.role = block.role or (#(block.attacks or {}) > 0 and "brute" or "skirmisher")
            out[block.id] = block
        end
    end
    return out
end

-- A moment from a story event with options (or a plain event: a line said where it happens).
local function moment_of(mod, ev, rooms)
    local at = ev.at or (ev.trigger and ev.trigger.at)
    if not (at and rooms[at]) then
        return nil
    end
    local when = ev.when_in or ((ev.trigger and ev.trigger.on == "arrive") and "start") or "mid"
    local opts = {}
    for _, o in ipairs(ev.options or {}) do
        local c = util.copy(o)
        if not c.effects then
            c.effects = deep_copy(LEAN_FUN[c.lean or "bold"] or LEAN_FUN.bold)
        end
        table.insert(opts, c)
    end
    -- (A story event with no choice in it: one way on, so it plays as said, with no vote.)
    if #opts == 0 then
        opts = { { label = "Go on.", short = "go on", lean = "safe", effects = {} } }
    end
    return {
        id = ev.id, room = at, at = when, type = ev.type or (#(ev.options or {}) > 0 and "choice" or "story"),
        actor = ev.actor or { "storyteller", "explorer", "casual" }, party = ev.party, title = ev.title or ev.id,
        text = ev.text, when = ev.only_if, options = opts, page = ev.page, tells = ev.tells,
        mus = ev.sets and { flags = ev.sets } or nil, book = true,
    }
end

local compiled = setmetatable({}, { __mode = "k" })
function M.compile(src)
    if src.rooms or not src.places then
        return src
    end
    if compiled[src] then
        return compiled[src]
    end
    -- (A new table: the adventure as written stays as written, for the shape check and the creation tool.)
    local mod = {}
    for k, v in pairs(src) do
        mod[k] = v
    end
    compiled[src] = mod
    for k, v in pairs(DEFAULTS) do
        if mod[k] == nil then
            mod[k] = deep_copy(v)
        end
    end
    mod.moments = deep_copy(src.moments or {})
    local by = place_list(mod)
    local list = scenes(mod)
    mod.rooms, mod.order, mod.links = {}, {}, {}
    local is_scene = {}
    for _, pl in ipairs(list) do
        is_scene[pl.id] = true
    end
    for i, pl in ipairs(list) do
        local sc = pl.scene
        local nxt = {}
        for _, ex in ipairs(pl.exits or {}) do
            if is_scene[ex.to] and ex.to ~= pl.id and not (by[ex.to] and by[ex.to].scene_before) then
                local later = false
                for j = i + 1, #list do
                    if list[j].id == ex.to then later = true end
                end
                if later then
                    table.insert(nxt, ex.to)
                end
            end
        end
        -- (A scene's way on, when its exits don't lead to a later scene: the next one listed. The woods are a walk.)
        if #nxt == 0 and list[i + 1] then
            nxt = { list[i + 1].id }
        end
        local foes = {}
        for _, f in ipairs(sc.foes or {}) do
            table.insert(foes, M.creature_id(mod, f))
        end
        local comps = { location = pl.id .. "_place", goal = pl.id .. "_goal" }
        if sc.cast or (sc.foes and #sc.foes > 0) then comps.cast = pl.id .. "_cast" end
        if sc.snag then comps.complication = pl.id .. "_snag" end
        if sc.prize then comps.reward = pl.id .. "_prize" end
        mod.rooms[pl.id] = {
            name = pl.name, part = 1, type = sc.type or "exploration", cost = sc.cost or (sc.quick and 1 or 2),
            quick = sc.quick, at = sc.at_map or { 50, 98 - (i - 1) * 14 }, map = sc.map or pl.name, comps = comps,
            encounter = (#foes > 0) and foes or nil, boss_name = sc.boss_name, optional_fight = sc.optional_fight,
            read = pl.read, sum = sc.sum or pl.read, next = nxt, knobs = {}, stop = sc.stop, rest = sc.rest,
            level = sc.level, statues = nil, pages = pl.pages,
        }
        table.insert(mod.order, pl.id)
        for _, n in ipairs(nxt) do
            table.insert(mod.links, { pl.id, n })
        end
    end
    mod.start = (mod.start and mod.rooms[mod.start]) and mod.start or mod.order[1]
    -- (Its creatures join the rules' roster, under their own ids, so a fight can build them.)
    local roster = require "game.rules.data.monsters"
    for id, block in pairs(M.creatures(src, roster)) do
        if not roster[id] then
            roster[id] = block
        end
    end
    -- (The night's opening line: the adventure's own, or what the hand-off says, or its pitch.)
    if not src.openings then
        local h = src.handoff or {}
        local plain = type(h.say) == "table" and h.say[#h.say] or h.say
        mod.openings = { src.opening or plain or src.pitch or src.title }
    end
    for _, ev in ipairs(mod.events or {}) do
        local m = moment_of(mod, ev, mod.rooms)
        if m then
            table.insert(mod.moments, m)
        end
    end
    -- (Endings: each a condition on the log, the first that holds ends the adventure. adventure.check_endings.)
    return mod
end

return M
