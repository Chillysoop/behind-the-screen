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
--             fight_mode = "story" (its fight told without the grid, by game/model/story_fight.lua),
--             leaves = { "<place id>", ... },                        -- walking in leaves these behind for good
--             stays = true,                                          -- its foes never run (the bed is a bed)
--             voiced = true,                                         -- one of the foes talks to them (Noke, over the rail)
--             snag = { name, line, skill = {...} }, prize = { name, line, got } }
-- And a story event with `options` (game night's choice records: label, want, short, lean, log, roll, mus, tells,
-- when) plays as a moment where it happens (`at`), as they walk in before anyone looks round (`when_in = "arrive"`), at
-- the start of the scene, mid-way or at its end.

-- (5e's engine only through the adventure's rule set: docs/design/rule-sets.md, no leaks.)
local ruleset = require "game.model.ruleset"
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

-- A scene card's id: the adventure's, the place's and the kind ("sheep_inn_common_place"), so two adventures' cards
-- never share one.
function M.card_id(mod, place_id, kind)
    return (mod.id or "adv") .. "_" .. place_id .. "_" .. kind
end
local card_id = M.card_id

-- (A line said at the table never carries the book's page: "(p2)" is the DM's note.)
local function aloud(text)
    if type(text) ~= "string" then
        return text
    end
    return (string.gsub(string.gsub(text, "%s*%(pp?%.? ?%d[%d, %-]*%)", ""), "%s+$", ""))
end

-- (A goal's name inside a sentence, "we're here to get past the guards": its first letter lower case, unless it starts
-- with someone's name.)
local function mid(mod, text)
    local first = string.match(text, "^([%a]+)") or ""
    for _, p in ipairs(mod.people or {}) do
        for w in string.gmatch(p.name or "", "%a+") do
            if w == first then
                return text
            end
        end
    end
    return string.lower(string.sub(text, 1, 1)) .. string.sub(text, 2)
end

local cards_made = setmetatable({}, { __mode = "k" })
function M.cards(mod)
    if mod.rooms and not mod.places then
        return {}
    end
    if cards_made[mod] then
        return cards_made[mod]
    end
    local out = {}
    cards_made[mod] = out
    for _, pl in ipairs(scenes(mod)) do
        local sc = pl.scene
        local fits = { sc.type or "exploration" }
        table.insert(out, { id = card_id(mod, pl.id, "place"), kind = "location", short = util.lower_first(pl.name), name = pl.name,
                            setting = sc.setting or { "indoor" }, fits = fits, tags = sc.tags or { "explore" },
                            line = aloud(pl.read), again = aloud(sc.again),
                            board = sc.board or ((mod.id or "adv") .. "_" .. pl.id) })
        if sc.cast then
            local p = person(mod, sc.cast) or {}
            table.insert(out, { id = card_id(mod, pl.id, "cast"), kind = "cast", short = p.short or p.name or sc.cast, pronoun = p.pronoun,
                                name = p.name or sc.cast, fits = fits, tags = { "talk" }, difficulty = 1,
                                line = aloud(sc.cast_line == nil and (p.look or p.about) or sc.cast_line or nil), person = sc.cast })
        elseif sc.foes and #sc.foes > 0 then
            table.insert(out, { id = card_id(mod, pl.id, "cast"), kind = "cast", short = sc.foes_short or "the foes", group = #sc.foes > 1,
                                foe = true, talks = sc.talks or false, name = sc.foes_name or "The foes", fits = fits,
                                tags = { "action", "danger" }, difficulty = 1, seen = sc.seen, wake = sc.wake, stays = sc.stays, voiced = sc.voiced,
                                line = sc.foes_line or pl.read })
        end
        local g = sc.goal or {}
        local gname = g.name or ("Get through " .. util.lower_first(pl.name))
        table.insert(out, { id = card_id(mod, pl.id, "goal"), kind = "goal", name = gname, short = g.short or mid(mod, gname),
                            aim = g.aim or mid(mod, gname),
                            fits = fits, tags = g.tags or { "action" }, line = g.line or ("Goal: " .. (sc.sum or pl.name) .. "."),
                            line_if = g.line_if,
                            win = g.win or "They're through.", win_if = g.win_if, lose = g.lose or "They're through, battered.",
                            lose_if = g.lose_if, lose_sets = g.lose_sets, win_sets = g.win_sets, got = g.got or "the way on", ask = g.ask })
        if sc.snag then
            table.insert(out, { id = card_id(mod, pl.id, "snag"), kind = "complication", name = sc.snag.name, skill = sc.snag.skill,
                                fits = fits, tags = { "danger" }, difficulty = 1, line = sc.snag.line, moment = sc.snag.moment })
        end
        if sc.prize then
            table.insert(out, { id = card_id(mod, pl.id, "prize"), kind = "reward", name = sc.prize.name, fits = fits, tags = { "loot" },
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
            block.flee_line = cr.flee_line or block.flee_line
            block.escapes = cr.escapes or block.escapes
            -- (A turn of its own from the adventure's rule module, game/rules/<id>.lua: the bed dragon's breath.)
            block.rules = cr.rules_turn and mod.id or nil
            block.rules_turn = cr.rules_turn
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
-- (An event that fires on a fight, a choice, a count of rounds or a clock isn't a moment: a fight's is said as the
-- room's fight starts, `on_fight`; the rest are the systems' that own them.)
local NOT_MOMENTS = { fight = true, choice = true, round = true, clock = true }
local function moment_of(mod, ev, rooms)
    local at = ev.at or (ev.trigger and ev.trigger.at)
    if not (at and rooms[at]) then
        return nil
    end
    if not ev.when_in and ev.trigger and NOT_MOMENTS[ev.trigger.on] then
        if ev.trigger.on == "fight" and not ev.trigger.turn then
            local r = rooms[at]
            r.on_fight = r.on_fight or {}
            table.insert(r.on_fight, { id = ev.id, text = ev.text, sets = ev.sets })
        end
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
    -- (A story event with no choice in it: one way on, so it plays as said, with no vote. Said: its words are what the
    -- table sees happen, the sheep at a gallop, the bed rising. The playtest, November 6: "Go on." cards nobody heard.)
    local see
    if #opts == 0 then
        opts = { { label = "Go on.", short = "go on", lean = "safe", effects = {} } }
        see = ev.see == nil and true or ev.see
        -- (What it sets, when it plays: the heap in the cellar is theirs once the rats are gone.)
        if ev.sets and ev.sets[1] then
            local more = {}
            for i = 2, #ev.sets do
                table.insert(more, ev.sets[i])
            end
            opts[1].mus = { flag = ev.sets[1], flags = (#more > 0) and more or nil }
        end
    end
    -- (What the event itself tells the table, whichever way it goes: Shinebright's story.)
    if ev.tells then
        for _, o in ipairs(opts) do
            if not o.tells then
                o.tells, o.tells_how = ev.tells, o.tells_how or "moment"
            end
        end
    end
    return {
        id = ev.id, room = at, at = when, type = ev.type or (#(ev.options or {}) > 0 and "choice" or "story"),
        actor = ev.actor or { "storyteller", "explorer", "casual" }, party = ev.party, title = ev.title or ev.id,
        text = ev.text, text_if = ev.text_if, when = ev.only_if, options = opts, page = ev.page, tells = ev.tells, risks = ev.risks,
        mus = ev.sets and { flag = ev.sets[1] } or nil, book = true, see = see,
    }
end

-- Where a scene sits on the prep board's map when the adventure doesn't say (`at_map`): two columns, snaking up from the
-- bottom in the order they're played, so no two boxes overlap (the playtest, November 6: six rooms stacked in one column,
-- each over the next). Per cent of the map box, centre of the room.
function M.map_at(i, n)
    if n <= 1 then
        return { 50, 50 }
    end
    local rows = math.ceil(n / 2)
    local row, col = math.floor((i - 1) / 2), (i - 1) % 2
    if row % 2 == 1 then
        col = 1 - col
    end
    local cy = rows > 1 and (86 - row * (72 / (rows - 1))) or 50
    return { col == 0 and 28 or 72, math.floor(cy + 0.5) }
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
        local comps = { location = card_id(mod, pl.id, "place"), goal = card_id(mod, pl.id, "goal") }
        if sc.cast or (sc.foes and #sc.foes > 0) then comps.cast = card_id(mod, pl.id, "cast") end
        if sc.snag then comps.complication = card_id(mod, pl.id, "snag") end
        if sc.prize then comps.reward = card_id(mod, pl.id, "prize") end
        mod.rooms[pl.id] = {
            name = pl.name, part = 1, type = sc.type or "exploration", cost = sc.cost or (sc.quick and 1 or 2),
            quick = sc.quick, at = sc.at_map or M.map_at(i, #list), map = sc.map or pl.name, comps = comps,
            encounter = (#foes > 0) and foes or nil, boss_name = sc.boss_name, optional_fight = sc.optional_fight, fight_mode = sc.fight_mode, fight_hard = sc.difficulty,
            read = pl.read, sum = sc.sum or pl.read, next = nxt, knobs = {}, stop = sc.stop, rest = sc.rest, on = pl.on,
            hurry_on = sc.hurry_on, leaves = sc.leaves,
            level = sc.level, statues = nil, pages = pl.pages, digs = sc.digs, clears = sc.clears,
        }
        -- (Where one of its foes starts, when not with the rest: Noke up on the platform above the yard.)
        if sc.foes_at then
            local at = {}
            for cid, xy in pairs(sc.foes_at) do
                at[M.creature_id(mod, cid)] = xy
            end
            mod.rooms[pl.id].foes_at = at
        end
        -- (A piece of the board that gets up as the fight starts: the bed. fight.lua's wake.)
        if sc.wakes then
            local at = {}
            for cid, xy in pairs(sc.wakes.at or {}) do
                at[M.creature_id(mod, cid)] = xy
            end
            mod.rooms[pl.id].wake = { feature = sc.wakes.feature, at = at }
        end
        table.insert(mod.order, pl.id)
        for _, n in ipairs(nxt) do
            table.insert(mod.links, { pl.id, n })
        end
    end
    mod.start = (mod.start and mod.rooms[mod.start]) and mod.start or mod.order[1]
    -- (Its creatures join the rules' roster, under their own ids, so a fight can build them.)
    local roster = ruleset.part("data.monsters")
    for id, block in pairs(M.creatures(src, roster)) do
        if not roster[id] then
            roster[id] = block
        end
    end
    -- (Each hero's reasons for coming, as game night reads them: where it pays off (the first scene unless it says),
    -- how strongly the player leans to it, and what they say about it.)
    mod.hooks = {}
    for key, list in pairs(src.hooks or {}) do
        mod.hooks[key] = {}
        for _, hk in ipairs(list) do
            local h = util.copy(hk)
            h.room = (h.room and mod.rooms[h.room]) and h.room or mod.start
            h.lean = h.lean or (#list == 1 and 2 or 1)
            h.says = h.says or h.intro or h.text
            h.payoff = h.payoff or h.text
            table.insert(mod.hooks[key], h)
        end
    end
    -- (Who has a sheet the DM can open, and put things in their pockets: each named person in a scene, by the place they're
    -- found, and their stat block when they fight. npcs.lua; the museum writes its own.)
    if not src.npc_sheet then
        local sheet = { order = {} }
        for _, p in ipairs(src.people or {}) do
            local room
            for _, w in ipairs(p.where or {}) do
                if not room and mod.rooms[w] then
                    room = w
                end
            end
            for _, pl in ipairs(src.places or {}) do
                if not room and pl.scene and pl.scene.cast == p.id and mod.rooms[pl.id] then
                    room = pl.id
                end
            end
            if p.tier == "named" and room then
                local blk = type(p.stats) == "table" and p.stats.block
                local monster = blk and M.creature_id(mod, blk) or nil
                table.insert(sheet.order, p.id)
                sheet[p.id] = { room = room, monster = monster, short = p.short,
                                hows = monster and { "beaten", "pocket", "ask" } or { "ask", "pocket" },
                                match = { p.short or p.name } }
            end
        end
        mod.npc_sheet = sheet
    end
    -- (Each creature's pronoun, for the lines that name it: its own, or the person whose stats it is. util.pronoun_of.)
    if not src.foe_pronouns then
        mod.foe_pronouns = {}
        for _, p in ipairs(src.people or {}) do
            local blk = type(p.stats) == "table" and p.stats.block
            if blk and p.pronoun then
                mod.foe_pronouns[M.creature_id(mod, blk)] = p.pronoun
            end
        end
        for id, cr in util.sorted_pairs(src.creatures or {}) do
            if cr.pronoun then
                mod.foe_pronouns[M.creature_id(mod, id)] = cr.pronoun
            end
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
