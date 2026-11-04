-- An adventure module run as the campaign (v2: The Museum of Nightmares as a one-shot prologue).
-- Where the party is on the module's map, what each room left behind, the boss's card and its
-- marks, the fair-warning bank, and the questions between sessions. Engine-free.
--
-- campaign.module = "museum" switches the campaign into module mode; campaign.adv holds this
-- state. The data is game/data/museum/ (module.lua, cards.lua).

local content = require "game.model.content"
local util = require "game.model.util"
local score = require "game.model.score"

local M = {}

local MODULE = require "game.data.museum.module"
M.data = MODULE

-- The words that belong to the old Silent Bells story: lines that mention them never play in the
-- prologue (it's strictly the book).
M.FOREIGN = { "Ilsa", "Kessrick", "Velvet Hand", "Millbrook", "Sable", "relic", "abbot", "Tobin", "Kettle", "kettle", "Gus",
              "bells", "Bells", "bell tower", "bell%-ringer", "bell paths", "Vask", "Hale's", "Wren", "Corin",
              "warband", "scriptorium", "Lowmarket", "Silver Spurs", "Lamplighters", "Vale", "farmhand" }

function M.foreign(text)
    if type(text) ~= "string" then
        return false
    end
    for _, w in ipairs(M.FOREIGN) do
        if string.find(text, "%f[%w]" .. w .. "%f[%W]") then
            return true
        end
    end
    return false
end

-- The adventure's own words, for M.fits: every word its data uses, singular and plural.
local vocab
local function words_in(t, set, seen)
    if type(t) == "string" then
        for w in string.gmatch(string.lower(t), "[%a']+") do
            w = string.gsub(w, "'s$", "")
            set[w] = true
            set[(string.gsub(w, "e?s$", ""))] = true
        end
        return
    end
    if type(t) ~= "table" or seen[t] then
        return
    end
    seen[t] = true
    for _, v in pairs(t) do
        words_in(v, set, seen)
    end
end

function M.vocab()
    if not vocab then
        vocab = {}
        local seen = {}
        words_in(MODULE, vocab, seen)
        words_in(require("game.data.museum.cards"), vocab, seen)
        -- (And its own boards: the places on its maps are its words too, November 3.)
        local okb, lib = pcall(require, "game.data.map_library")
        for _, b in pairs(okb and lib.boards or {}) do
            if type(b) == "table" and b.adventure == MODULE.id then
                words_in(b.places, vocab, seen)
                words_in(b.features, vocab, seen)
            end
        end
    end
    return vocab
end

local LEX = require "game.data.fiction_words"

-- Does a shared line fit the adventure? Not if it names the old story, a thing in a story's
-- world that this adventure never mentions (game/data/fiction_words.lua: no goats in the museum,
-- so no "Someone mentions the goat"), or a callback to something nothing promises happened
-- ("just like last time"). Fill-ins ({boss}, {location}) are the night's own, so they're fine.
function M.fits(text)
    if type(text) ~= "string" then
        return true
    end
    if M.foreign(text) then
        return false
    end
    local low = string.lower(string.gsub(text, "{[%w_]+}", " "))
    for _, ph in ipairs(LEX.phrases) do
        -- (At a word's start: "as always" isn't in "I was always a boot".)
        local at = string.find(low, ph, 1, true)
        while at do
            local before = at > 1 and string.sub(low, at - 1, at - 1) or " "
            if not string.find(before, "%a") then
                return false
            end
            at = string.find(low, ph, at + 1, true)
        end
    end
    local v = M.vocab()
    for _, w in ipairs(LEX.words) do
        local lw = string.lower(w)
        if string.find(low, "%f[%a]" .. lw .. "%f[%A]") then
            local ok = true
            for part in string.gmatch(lw, "[%a']+") do
                if not (v[part] or v[(string.gsub(part, "e?s$", ""))]) then
                    ok = false
                end
            end
            if not ok then
                return false
            end
        end
    end
    return true
end

-- Fields that are never said out loud: names of things in the data, not lines.
local NOT_TEXT = { where = true, suits = true, id = true, tags = true, when = true, kind = true, type = true,
                   trigger = true, speaker = true, skill = true, actor = true, class = true, doers = true,
                   objects = true, enjoys = true, feeds = true, needs = true, tag_taste = true, style = true,
                   content = true, promise = true, card = true, cast = true, boss = true, minion = true, room = true }

local function deep_foreign(t, seen)
    if type(t) == "string" then
        return not M.fits(t)
    end
    if type(t) ~= "table" then
        return false
    end
    seen = seen or {}
    if seen[t] then
        return false
    end
    seen[t] = true
    for k, v in pairs(t) do
        if not NOT_TEXT[k] and deep_foreign(v, seen) then
            return true
        end
    end
    return false
end
M.deep_foreign = deep_foreign

-- Switch the game's shared content over to the prologue (once per run; the v2 build only ever
-- runs the module): the heroes are who the book needs, and the shared systems speak in its words.
-- (The shared data holds nothing from the old story since the November 4 purge; the museum's
-- tests check that nothing slips back in, with M.foreign and M.fits.)
function M.enter(campaign)
    if not M.entered then
        M.entered = true
        for key, h in pairs(MODULE.heroes) do
            local pd = content.players[key]
            if pd then
                pd.thread = "why they came to the museum"
                pd.gist = h.gist
                pd.premise = h.gist .. "."
                pd.intro = h.gist .. "."
                pd.short = h.short
            end
        end
        -- Session Zero for this adventure: its pitch and the asks that touch what's in it, over
        -- the shared one (same keys, so everything that reads them still does).
        local s0, ms0 = content.session_zero, MODULE.session_zero
        if s0 and ms0 then
            s0.pitch = ms0.pitch or s0.pitch
            for _, part in ipairs({ "tones", "asks" }) do
                for key, over in pairs(ms0[part] or {}) do
                    local base = s0[part][key]
                    if base then
                        for k, v in pairs(over) do
                            if type(v) == "table" and type(base[k]) == "table" then
                                for k2, v2 in pairs(v) do
                                    base[k][k2] = v2
                                end
                            else
                                base[k] = v
                            end
                        end
                    end
                end
            end
            for key, over in pairs(ms0.rules or {}) do
                local base = s0.rules[key]
                for k, v in pairs(over) do
                    if base then
                        base[k] = v
                    end
                end
            end
        end
        M.museum_death()
        -- What the friends do to each other, in this adventure's words.
        local fr = content.friction
        for part, over in pairs(MODULE.friction or {}) do
            local list = fr and fr[part]
            if list then
                for i = #list, 1, -1 do
                    local v = over[list[i].id]
                    if v == false then
                        table.remove(list, i)
                    elseif type(v) == "string" then
                        list[i].line = v
                    elseif type(v) == "table" then
                        for k, x in pairs(v) do
                            list[i][k] = x
                        end
                    end
                end
            end
        end
        -- A ruling's cost is a hurt the hero takes (night.lua), so its words say one.
        for tier, lines in pairs(MODULE.ruling_costs or {}) do
            local r = content.rulings and content.rulings[tier]
            for _, o in ipairs(r and r.options or {}) do
                if o.tone == "twist" then
                    o.lines = lines
                    o.log = lines[1]
                end
            end
        end
        -- The recap's words where the shared ones assume a campaign.
        local rc = require "game.model.recap"
        for k, list in pairs(MODULE.recap_beats or {}) do
            rc.TEMPLATES[k] = list
        end
        -- The friends' gifts at the table, in this adventure's words.
        local kd = require "game.data.keepsakes"
        for id, over in pairs(MODULE.keepsakes or {}) do
            local g = kd.GIFTS[id]
            if g then
                for k, v in pairs(over) do
                    g[k] = v
                end
            end
        end
        -- The adventure's own magic items join the rules' list (a pickup goes on a hero's sheet).
        local mi = require "game.rules.data.magic_items"
        for id, def in pairs(MODULE.magic_items or {}) do
            if not mi[id] then
                def.id = id
                mi[id] = def
            end
        end
        local bc = content.triggered and content.triggered.boss_crit
        if bc then
            bc.text = "{actor_char} is about to drop {boss} in round {round}. The whole table can see it coming."
            for _, o in ipairs(bc.options or {}) do
                if o.battle == "reinforce" then
                    o.log = "{boss} falls, and more of them come crashing out of the exhibits."
                end
            end
        end
        -- A way out in the museum: nobody "came in by" a back door, and a foe who runs does come
        -- back (museum_night.after_room puts them on Euryale's card).
        local ee = content.triggered and content.triggered.escape_earned
        if ee then
            ee.text = "{boss} is beaten, bleeding, and edging toward a way out."
            for _, o in ipairs(ee.options or {}) do
                if o.battle == "escape" then
                    o.label = "Let them go. They'll be waiting upstairs."
                    o.log = "{boss} is gone before anyone can stop them, up toward Euryale."
                elseif o.battle == "let" then
                    o.log = "Somebody gets in the way first. {boss} isn't leaving."
                end
            end
        end
        if content.conflicts and content.conflicts.tone then
            content.conflicts.tone.about = "Mara wants the museum's mysteries taken seriously. Jess can't resist a joke."
        end
        -- The friends' lines about things this adventure's world doesn't have (a goblin, a mayor)
        -- wait for an adventure that does.
        local lib = content.dialogue
        if lib then
            lib.exclude = function(l)
                return not M.fits(l.text) or not M.fits(l.reply)
            end
            M.add_npc_lines(lib)
        end
        -- The adventure's own goals play their own approaches.
        local cards = require "game.data.museum.cards"
        for id, gp in pairs(cards.goal_play) do
            content.goal_play[id] = gp
        end
        -- The book's DCs are real DCs (the old cards' were on a d20-only scale).
        local function true_dc(card)
            for _, o in ipairs(card.options or {}) do
                if o.roll then
                    o.roll.true_dc = true
                end
            end
        end
        for _, m in ipairs(MODULE.moments) do
            true_dc(m)
        end
        for _, k in ipairs({ "drink", "talk", "yield" }) do
            true_dc(MODULE.showdown[k])
        end
        -- The first session's introductions: each hero's story is the book's hook for them.
        local intros = require "game.data.intros"
        for key, p in pairs(intros.PLAYERS or {}) do
            local h = MODULE.hooks[key]
            if h then
                p.story = { h[1].intro, h[2].intro }
                p.grim = { false, false }
                p.all_in = MODULE.all_in[key] or p.all_in
            end
        end
    end
    if campaign then
        campaign.module = MODULE.id
        campaign.adv = campaign.adv or M.new_state()
    end
end

-- Death in the museum: the wake, the way back and the new heroes belong to this story.
function M.museum_death()
    local d = require "game.data.death"
    -- Last words: the museum adds its own.
    for cls, line in pairs({ wizard = "Don't let her put me in the collection.", rogue = "Tell the boot it still owes me a Franc." }) do
        local list = d.LAST_WORDS and d.LAST_WORDS[cls]
        if list and not util.contains(list, line) then
            table.insert(list, line)
        end
    end
    d.WAKE = "They hold the wake in the gift shop. Telpur leaves a candle burning on the counter for {char} all night."
    d.INTRO = {
        sibling = "{new} steps through the black curtain carrying {old}'s pack. 'I heard. I'm coming with you. Don't argue.'",
        hired = "{new} has been waiting by the caravan steps all evening. 'The gnome paid me in advance,' {new} says. 'I'd like to earn it.'",
        rescued = "The party finds {new} hiding in a diorama. {new} asks which way is out, then decides to come along instead.",
    }
    local hooks = {
        bryn = "A guard Flitwidget hired for the caravan, who was waiting outside the curtain the whole time.",
        hesk = "A sellsword who came for the same job and arrived one room too late.",
        tam = "A visitor who hid in a cupboard in the Hunting Grounds for three days, and owes the party everything.",
        lark = "A pickpocket from the crowd outside who slipped through the curtain to see what the fuss was about.",
        aldith = "A healer Flitwidget sends in after them, with a bag of medicinal leaves and very little patience.",
        rufus = "A friar who came to bless the exhibits and got swept up in the whole thing.",
        corwin = "A scholar who came to study the paintings and stayed to survive them.",
        ysolde = "Flitwidget's old apprentice, who knows the museum's back corridors and won't say why she left.",
    }
    for _, list in pairs(d.PREGENS or {}) do
        for _, pg in ipairs(list) do
            pg.hook = hooks[pg.id] or pg.hook
        end
    end
end

-- The museum's people get their lines in game night's dialogue.
function M.add_npc_lines(lib)
    if lib.museum_lines then
        return
    end
    lib.museum_lines = true
    for speaker, triggers in util.sorted_pairs(MODULE.npc_lines) do
        for trigger, list in util.sorted_pairs(triggers) do
            -- (Seeing the party again is a greeting too, by a speaker of its own: "{id}@again".)
            local tr, sp = trigger, speaker
            if trigger == "npc_again" then
                tr, sp = "npc_greet", speaker .. "@again"
            end
            for i, text in ipairs(list) do
                table.insert(lib.lines, { id = trigger .. "." .. speaker .. "." .. i, trigger = tr, speaker = sp,
                                          text = text, status = "approved" })
            end
        end
    end
    lib:index()
end

function M.new_state()
    return {
        at = MODULE.start,          -- the next room the party reaches
        done = {},                  -- room -> "win" | "lose"
        skipped = {},               -- rooms left behind for good (anything unseen once they're in the lair)
        passed = {},                -- rooms they walked past: the floor they're on was left behind
        pos = nil,                  -- the room the party is standing in
        floor = 1,                  -- the highest floor reached
        took = {},                  -- second-look moments they got something out of
        seen = {},                  -- moments played
        hints = {},                 -- rooms the DM hinted still have something in them
        rehomed = {},               -- room -> marks a loose end moved out of it
        looked = {},                -- rooms they've had their second look at
        hinted = {},                -- rooms the DM has hinted at (once each)
        path = {},                  -- rooms in the order they played: { room, week, outcome }
        marks = {}, mark_list = {}, -- Euryale's marks: id -> { week, room }
        flags = {},
        francs = 0,
        careful = 0,
        favors = {}, favor_done = {},
        bank = 0, harsh = { paid = 0, unpaid = 0 },
        hooks = {},                 -- player key -> hook id
        answered = {},              -- requests, loose ends: id -> answer
        weeks = 0,                  -- game nights played in the museum
        -- The DM's ties and locks (game/model/ties.lua): what's locked until what, what's tied to
        -- happen when, and the heroes' reasons a tie moved to another room.
        locks = {}, ties = {}, hook_room = {}, lock_news = {}, tie_seq = 0,
    }
end

-- Conditions on moments and options ------------------------------------------------------------

function M.test(campaign, cond, knobs)
    if not cond then
        return true
    end
    local st = campaign.adv
    if cond.knob and not (knobs and knobs[cond.knob]) then
        return false
    end
    if cond.flag and not st.flags[cond.flag] then
        return false
    end
    if cond.mark and not st.marks[cond.mark] then
        return false
    end
    if cond.talk and M.talk_score(campaign) < cond.talk then
        return false
    end
    -- (And the other way round, and what the DM chose on a card: { card id, option number }.)
    if cond.not_flag and st.flags[cond.not_flag] then
        return false
    end
    if cond.not_mark and st.marks[cond.not_mark] then
        return false
    end
    if cond.not_knob and knobs and knobs[cond.not_knob] then
        return false
    end
    if cond.chose and (st.chose or {})[cond.chose[1]] ~= cond.chose[2] then
        return false
    end
    if cond.done and not st.done[cond.done] then
        return false
    end
    if cond.met and not M.met(campaign, cond.met) then
        return false
    end
    if cond.ending and st.ending ~= cond.ending then
        return false
    end
    if cond.not_ending and st.ending == cond.not_ending then
        return false
    end
    if cond.seen and not (st.seen or {})[cond.seen] then
        return false               -- (a moment card that played)
    end
    if cond.from and st.came_from ~= cond.from then
        return false               -- (the room they've just walked in from)
    end
    if cond.not_soft and M.test(campaign, { soft = cond.not_soft }) then
        return false
    end
    -- What someone carries (items.lua): holds, anyone in the party; holds_here, someone at the table.
    if cond.holds and not require("game.model.items").owned(campaign, cond.holds) then
        return false
    end
    if cond.holds_here and not require("game.model.items").holding(campaign, cond.holds_here, true) then
        return false
    end
    -- What Session Zero agreed: a content tag the table veiled (it happens off screen) or drew a
    -- line under (it never happens). { soft = "gore" } holds for either.
    if cond.line then
        local t = campaign.table
        if not (t and t.lines and t.lines[cond.line]) then
            return false           -- (a line, not a veil: it never happens at all)
        end
    end
    if cond.soft then
        local t = campaign.table
        if not (t and ((t.veils and t.veils[cond.soft]) or (t.lines and t.lines[cond.soft]))) then
            return false
        end
    end
    return true
end

-- The DM's people remember the party (v2): who they've met, and what the party did that they'd
-- know about. st.npc[id] = { week, room, deeds = { deed = week } }.
function M.meet(campaign, id, room)
    local st = campaign.adv
    st.npc = st.npc or {}
    local n = st.npc[id]
    if not n then
        n = { week = campaign.week or 1, room = room, deeds = {} }
        st.npc[id] = n
    end
    return n
end

function M.met(campaign, id)
    local st = campaign.adv
    return st and st.npc ~= nil and st.npc[id] ~= nil
end

-- What one of the museum's people knows the party did, as short phrases ("they tidied his
-- exhibits"), from the adventure's own record: nothing anyone invented.
function M.memory(campaign, id)
    local st = campaign.adv
    local out = {}
    local mem = MODULE.memory and MODULE.memory[id] or {}
    for _, m in ipairs(mem) do
        if M.test(campaign, m.when) then
            table.insert(out, m.text)
        end
    end
    return out
end

function M.deed(campaign, id, deed)
    local n = M.meet(campaign, id)
    n.deeds[deed] = n.deeds[deed] or (campaign.week or 1)
end

-- How easy Euryale is to talk round: the marks that make her curious, minus the ones that anger her.
function M.talk_score(campaign)
    local n = 0
    for id in pairs(campaign.adv.marks) do
        n = n + (MODULE.marks[id].talk or 0)
    end
    return n
end

-- The map: where the party can go next ---------------------------------------------------------

-- Older saves (before the floors opened up, October 30) lack the roaming fields.
local function fill(st)
    st.passed = st.passed or {}
    st.took = st.took or {}
    st.seen = st.seen or {}
    st.hints = st.hints or {}
    st.rehomed = st.rehomed or {}
    st.looked = st.looked or {}
    st.hinted = st.hinted or {}
    st.floor = st.floor or 1
    -- (And before the tie-and-lock editor, October 30.)
    st.locks = st.locks or {}
    st.ties = st.ties or {}
    st.hook_room = st.hook_room or {}
    st.lock_news = st.lock_news or {}
    st.tie_seq = st.tie_seq or 0
    -- (And before the DM's people remembered them, November 2: what the DM chose on each card,
    -- who they've met, the items they carry.)
    st.chose = st.chose or {}
    st.npc = st.npc or {}
    return st
end
M.fill = fill

-- The DM's locks (game/model/ties.lua sets, checks and opens them; the walking here only reads
-- them). A lock: { id, kind = "door" | "room" | "moment" | "person", a, b | room | moment | person,
-- cond, open }. A door, room or person stays shut until its condition has happened once (`open`
-- then stays set); a moment plays only while its condition holds, and never if it's cut.
-- cond: { kind = "room", room } | { kind = "flag", flag } | { kind = "mark", mark } |
--       { kind = "francs", n } | { kind = "session", n } | { kind = "never" }.
function M.cond_true(campaign, cond)
    local st = campaign.adv
    if not cond then
        return true
    end
    local k = cond.kind
    if k == "room" then
        return st.done[cond.room] ~= nil
    elseif k == "flag" then
        return st.flags[cond.flag] ~= nil and st.flags[cond.flag] ~= false
    elseif k == "mark" then
        return st.marks[cond.mark] ~= nil
    elseif k == "francs" then
        return (st.francs or 0) >= (cond.n or 0)
    elseif k == "session" then
        return (campaign.week or 0) >= (cond.n or 0)
    end
    return false
end

local function locks_of(campaign)
    local st = campaign and campaign.adv
    return st and st.locks or {}
end

-- Is the room locked shut?
function M.room_closed(campaign, id)
    for _, l in ipairs(locks_of(campaign)) do
        if l.kind == "room" and l.room == id and not l.open then
            return true
        end
    end
    return false
end

-- Is the way from room a into room b shut (the door between them, or b itself)?
function M.way_closed(campaign, a, b)
    for _, l in ipairs(locks_of(campaign)) do
        if not l.open and ((l.kind == "room" and l.room == b)
            or (l.kind == "door" and ((l.a == a and l.b == b) or (l.a == b and l.b == a)))) then
            return true
        end
    end
    return false
end

-- Is the person keeping out of sight?
function M.person_hidden(campaign, pid)
    for _, l in ipairs(locks_of(campaign)) do
        if l.kind == "person" and l.person == pid and not l.open then
            return true
        end
    end
    return false
end

-- Who a moment belongs to: its own `who` (an id or a list), else the person its room is about
-- (the room's cast, when that's one of MODULE.people).
local PEOPLE
function M.moment_people(m)
    if not PEOPLE then
        PEOPLE = {}
        for _, p in ipairs(MODULE.people or {}) do
            PEOPLE[p.id] = true
        end
    end
    if m.who then
        return type(m.who) == "table" and m.who or { m.who }
    end
    local r = MODULE.rooms[m.room]
    local cast = r and r.comps and r.comps.cast
    if cast and PEOPLE[cast] then
        return { cast }
    end
    return {}
end

-- Does the DM let this moment play right now (not cut, its condition holds, its people about)?
function M.moment_open(campaign, m)
    local locks = locks_of(campaign)
    if #locks == 0 then
        return true
    end
    for _, l in ipairs(locks) do
        if l.kind == "moment" and l.moment == m.id and not M.cond_true(campaign, l.cond) then
            return false
        end
    end
    for _, pid in ipairs(M.moment_people(m)) do
        if M.person_hidden(campaign, pid) then
            return false
        end
    end
    return true
end

-- The rooms one door away (MODULE.links, both ways). With a campaign, only the ways the DM
-- hasn't locked shut.
function M.neighbors(id, campaign)
    local out = {}
    local locked = campaign and #locks_of(campaign) > 0
    for _, l in ipairs(MODULE.links or {}) do
        local n
        if l[1] == id then
            n = l[2]
        elseif l[2] == id then
            n = l[1]
        end
        if n and not (locked and M.way_closed(campaign, id, n)) then
            table.insert(out, n)
        end
    end
    return out
end

-- Where the party can walk from `from` without a fight on the way: through rooms already cleared.
-- Returns the rooms they'd arrive in, not cleared yet ({ [id] = doors walked }), and the cleared
-- rooms on the way ({ [id] = doors walked }). Locked ways are shut (all: as if nothing were locked).
function M.reachable(campaign, from, all)
    local st = fill(campaign.adv)
    local dist, fresh, cleared = { [from] = 0 }, {}, {}
    local queue = { from }
    while #queue > 0 do
        local id = table.remove(queue, 1)
        for _, n in ipairs(M.neighbors(id, (not all) and campaign or nil)) do
            if dist[n] == nil and not (MODULE.no_return or {})[n] and MODULE.rooms[n] then
                dist[n] = dist[id] + 1
                if st.done[n] then
                    cleared[n] = dist[n]
                    table.insert(queue, n)
                else
                    fresh[n] = dist[n]
                end
            end
        end
    end
    return fresh, cleared
end

-- From a room just played, the new rooms the party would head for: reachable, not seen yet, not
-- walked past (a room on a floor they've left needs a reason: museum_night's second looks).
function M.options_after(campaign, from, all)
    local st = fill(campaign.adv)
    local fresh = M.reachable(campaign, from, all)
    local out = {}
    for _, id in ipairs(MODULE.order) do
        if fresh[id] and not st.skipped[id] and not st.passed[id] and not MODULE.rooms[id].boss then
            table.insert(out, id)
        end
    end
    return out
end

-- Does a cleared room still hold something worth a second look? (MODULE.second_look: a moment
-- that hands something out, never played or passed up.) Returns the moment ids.
function M.missed(campaign, room)
    local st = fill(campaign.adv)
    local out = {}
    if not st.done[room] or (st.looked or {})[room] then
        return out
    end
    for _, mid in ipairs((MODULE.second_look or {})[room] or {}) do
        if not st.took[mid] then
            for _, m in ipairs(MODULE.moments) do
                if m.id == mid and M.test(campaign, m.when, {}) and M.moment_open(campaign, m) then
                    table.insert(out, mid)
                end
            end
        end
    end
    return out
end

-- What the party can reach next from where they stand (the rooms of the fork they're at).
function M.frontier(campaign)
    local st = campaign.adv
    if st.ending then
        return {}
    end
    if st.choices and #st.choices > 0 then
        return util.copy(st.choices)
    end
    return st.at and { st.at } or {}
end

-- The rooms tonight might reach, in the order they'd likely come, up to the next natural stop:
-- what the DM preps. Both sides of a fork are listed.
function M.ahead(campaign)
    local st = campaign.adv
    local out, seen, last = {}, {}, {}
    local queue = M.frontier(campaign)
    local stopped = false
    local guard = 0
    while #queue > 0 and guard < 30 do
        guard = guard + 1
        local id = table.remove(queue, 1)
        if not seen[id] and not st.done[id] and not st.skipped[id] and not (st.passed or {})[id] then
            seen[id] = true
            local r = MODULE.rooms[id]
            table.insert(out, id)
            if r.boss then
                break
            end
            -- A stop ends the night only once a few rooms have played (museum_night.run): one the
            -- party reaches first thing (the gift shop, after a night that ran out of time short of
            -- it) lets them catch their breath and go on, so the rooms past it are tonight's too.
            -- The stairs always end it.
            if not r.stop or (id ~= "stairs" and #out < 3) then
                for _, nid in ipairs(M.neighbors(id, campaign)) do
                    local nr = MODULE.rooms[nid]
                    if not seen[nid] and nr and not nr.boss and not (MODULE.no_return or {})[nid] then
                        table.insert(queue, nid)
                    end
                end
            else
                stopped = true
                last[id] = true
            end
        end
    end
    -- A stop that isn't the last thing listed (the other wing after the gift shop): keep the order
    -- of the map, the night's last stop last.
    table.sort(out, function(a, b)
        local ea, eb = last[a] or MODULE.rooms[a].boss or false, last[b] or MODULE.rooms[b].boss or false
        if ea ~= eb then
            return not ea
        end
        return util.index_of(MODULE.order, a) < util.index_of(MODULE.order, b)
    end)
    return out, stopped
end

-- Boss night: the party is at the lair, or only the stairs stand between them and it (the stairs
-- then play as the night's way in, so a session is never just the stairs).
function M.boss_week(campaign)
    local st = campaign.adv
    return not st.ending and (st.at == "lair" or (st.at == "stairs" and not st.done.stairs))
        and not (st.choices and #st.choices > 0) and not M.room_closed(campaign, st.at)
        and not (st.at == "stairs" and M.way_closed(campaign, "stairs", "lair"))   -- (the DM locked her door)
end

function M.over(campaign)
    return campaign.adv and campaign.adv.ending ~= nil
end

-- Moving through the museum ---------------------------------------------------------------------

-- The party goes into a room. Going up a floor walks past whatever they didn't see below (still
-- there if someone wants to go back); going into the lair leaves anything unseen behind for good
-- (returned, so the night can mark Euryale's card: MODULE.left_behind).
-- What going up to her leaves behind for good, on her card: each unplayed room's left_behind mark,
-- unless a loose end already said where that room's thing went (the DM's answer stands).
-- defer: leave out a room whose loose end hasn't been answered yet (it's about to be asked).
function M.left_behind(campaign, defer)
    local st = campaign.adv
    local out = {}
    for _, oid in ipairs(MODULE.order) do
        local o = MODULE.rooms[oid]
        local lb = MODULE.left_behind and MODULE.left_behind[oid]
        if lb and lb.mark and not o.boss and not o.virtual and not st.done[oid] then
            local settled = false
            for _, le in ipairs(MODULE.loose_ends or {}) do
                settled = settled or (le.when.skipped == oid and (st.answered[le.id] ~= nil or defer))
            end
            if not settled then
                table.insert(out, { room = oid, mark = lb.mark })
            end
        end
    end
    return out
end

function M.enter_room(campaign, id, week)
    local st = fill(campaign.adv)
    local r = MODULE.rooms[id]
    st.choices = nil
    st.at = id
    st.came_from = st.pos       -- (where they walked in from: a room's read can say so, cond.from)
    st.pos = id
    local left = {}
    local part = r.part or 1
    if part > st.floor then
        for _, oid in ipairs(MODULE.order) do
            local o = MODULE.rooms[oid]
            if (o.part or 1) < part and not st.done[oid] and not o.virtual and oid ~= MODULE.start then
                st.passed[oid] = st.passed[oid] or week or true
            end
        end
        st.floor = part
    end
    if r.boss then
        for _, oid in ipairs(MODULE.order) do
            local o = MODULE.rooms[oid]
            if oid ~= id and not st.done[oid] and not st.skipped[oid] and not o.virtual then
                st.skipped[oid] = week or true
                st.passed[oid] = nil
                table.insert(left, oid)
            end
        end
    end
    -- Back for a room they'd walked past: whatever a loose end moved out of it is here after all.
    if st.passed[id] then
        st.passed[id] = nil
        for _, m in ipairs(st.rehomed[id] or {}) do
            M.remove_mark(campaign, m)
        end
        st.rehomed[id] = nil
    end
    return left
end

-- Where the party heads next from a room it's just done (or stands in, done).
local function set_frontier(campaign, id)
    local st = campaign.adv
    local opts = M.options_after(campaign, id)
    -- At the top of the stairs there's only one way on: her (unless the DM locked her door).
    local r = MODULE.rooms[id]
    for _, nid in ipairs(r and r.next or {}) do
        if MODULE.rooms[nid] and MODULE.rooms[nid].boss and not st.done[nid] and not M.way_closed(campaign, id, nid) then
            st.at, st.choices = nid, nil
            return { nid }
        end
    end
    if #opts == 1 then
        st.at, st.choices = opts[1], nil
    elseif #opts > 1 then
        st.at, st.choices = nil, opts
    else
        st.at, st.choices = nil, nil
    end
    return opts
end

-- The room is done: where the party can go from here.
-- fought: the room's fight happened (the recaps say so: F20).
function M.leave_room(campaign, id, outcome, week, fought)
    local st = campaign.adv
    st.done[id] = outcome or "win"
    table.insert(st.path, { room = id, week = week, outcome = outcome or "win", fought = fought or nil })
    return set_frontier(campaign, id)
end

-- What a room came to, as a clause for "Last time, they ..." (MODULE.recap): the fight if there
-- was one, who went where when it wasn't everyone.
function M.recap_clause(campaign, step)
    local rc = MODULE.recap and MODULE.recap[step.room]
    if not rc then
        return nil
    end
    local st = campaign.adv
    local a = rc.alone
    if a and st.chose and util.contains(a.options or {}, st.chose[a.moment]) then
        local p = campaign:player(a.who)
        return util.fill(a.text, { char = p and p.char or "one of them" })
    end
    local lose = step.outcome == "lose"
    if step.fought and rc.fought then
        return lose and rc.fought.lose or rc.fought.win
    end
    return lose and rc.lose or rc.win
end

-- The DM locked or opened something (game/model/ties.lua): where the party can go next, worked
-- out again from where it stands. Nothing changes before the start, mid-room, or once it's over.
-- The boss is next as soon as the room before her is done and her way is open, wherever they are.
function M.refresh_frontier(campaign)
    local st = fill(campaign.adv)
    local pos = st.pos
    if st.ending or not pos or not st.done[pos] then
        return
    end
    local _, cleared = M.reachable(campaign, pos)
    for _, gid in ipairs(MODULE.order) do
        local g = MODULE.rooms[gid]
        if st.done[gid] and (gid == pos or cleared[gid]) then
            for _, nid in ipairs(g.next or {}) do
                local n = MODULE.rooms[nid]
                if n and n.boss and not st.done[nid] and not M.way_closed(campaign, gid, nid) then
                    st.at, st.choices = nid, nil
                    return
                end
            end
        end
    end
    set_frontier(campaign, pos)
end

-- Marks, flags, Francs, favors --------------------------------------------------------------

function M.add_mark(campaign, id, room)
    local st = campaign.adv
    if not MODULE.marks[id] or st.marks[id] then
        return false
    end
    st.marks[id] = { week = campaign.week, room = room }
    table.insert(st.mark_list, id)
    -- (A mark that's something in their packs, the Lecturer's notes, is in someone's: items.lua.
    -- M.apply has already given it to whoever's choice it was; any other way it lands, a holder.)
    local items = require "game.model.items"
    local thing = items.thing_for({ mark = id })
    if thing and not thing.magic and not items.owned(campaign, thing.id) then
        items.give(campaign, thing.id, nil, room == "loose" and "given" or "found")
    end
    return true
end

function M.remove_mark(campaign, id)
    local st = campaign.adv
    if not st.marks[id] then
        return
    end
    st.marks[id] = nil
    for i, m in ipairs(st.mark_list) do
        if m == id then
            table.remove(st.mark_list, i)
            break
        end
    end
end

-- Apply an option's `mus` table (game/data/museum/module.lua). Returns the marks it added.
-- The night handles risk, warn, harsh, fight and the ending itself (it needs the table).
-- holder: the player key of the hero whose choice it was (who bought it, found it, asked for it):
-- a thing it hands over goes in their pack (items.lua, the one inventory).
function M.apply(campaign, mus, room, holder)
    local st = campaign.adv
    local added = {}
    if not mus then
        return added
    end
    local items = require "game.model.items"
    local thing = items.thing_for(mus)
    if thing and not thing.magic then
        items.give(campaign, thing.id, holder, mus.spend and "bought" or (room == "loose" and "given") or (room and "found") or "given")
    end
    if mus.use then
        -- (Out of the pack of whoever used it, else whoever was carrying it for the party.)
        if not items.use(campaign, mus.use, holder) then
            items.use(campaign, mus.use)
        end
    end
    if mus.mark and M.add_mark(campaign, mus.mark, room) then
        table.insert(added, mus.mark)
    end
    if mus.unmark then
        M.remove_mark(campaign, mus.unmark)
    end
    if mus.flag then
        st.flags[mus.flag] = true
    end
    -- (The Witness, named out loud: it whispered their name, or a line about it in the notebook.)
    if mus.flag == "whispered" or mus.flag == "studied" then
        st.flags.witness_named = true
    end
    if mus.francs then
        st.francs = st.francs + mus.francs
    end
    if mus.spend then
        st.francs = math.max(0, st.francs - mus.spend)
    end
    if mus.careful then
        st.careful = st.careful + mus.careful
        if st.careful >= MODULE.CAREFUL_AT and M.add_mark(campaign, "careful", room) then
            table.insert(added, "careful")
        end
    end
    if mus.favor then
        st.favors[mus.favor.who] = (st.favors[mus.favor.who] or 0) + mus.favor.n
    end
    if mus.gold then
        st.gold = mus.gold          -- (the reward, as bargained: what the thanks pays out)
    end
    return added
end

-- Why a mark is on her card, in words that match how it got there: the DM's own tie says so; a
-- mark's why_if picks the reason that happened ("got away" for a knight who ran, not "never
-- woken"); else its plain why.
function M.mark_why(campaign, id)
    local st = campaign.adv
    local m = MODULE.marks[id]
    local rec = st.marks[id]
    if type(rec) == "table" and rec.tied then
        return "You tied it to happen"
    end
    for _, alt in ipairs(m.why_if or {}) do
        if M.test(campaign, alt.when) then
            return alt.text
        end
    end
    return m.why
end

-- What she thinks as it lands, the same way (thought_if, else her thought).
function M.mark_thought(campaign, id)
    local m = MODULE.marks[id]
    for _, alt in ipairs(m.thought_if or {}) do
        if M.test(campaign, alt.when) then
            return alt.text
        end
    end
    return m.thought
end

-- Euryale's card: her base, and every mark with why it's there and what it does on boss night.
function M.boss_card(campaign)
    local st = campaign.adv
    local marks = {}
    for _, id in ipairs(st.mark_list) do
        local m = MODULE.marks[id]
        table.insert(marks, { id = id, name = m.name, why = M.mark_why(campaign, id), showdown = m.showdown, thought = M.mark_thought(campaign, id),
                              week = st.marks[id].week, room = st.marks[id].room })
    end
    return { name = MODULE.base.name, line = MODULE.base.line, marks = marks, talk = M.talk_score(campaign) }
end

-- The boss fight: Euryale plus whoever the marks bring, the party's allies, and the battle options.
function M.boss_encounter(campaign)
    local st = campaign.adv
    local ids, allies, opts = { "euryale" }, {}, {}
    for _, id in ipairs(MODULE.mark_order) do
        if st.marks[id] then
            local m = MODULE.marks[id]
            if m.foe then
                local n = (id == "pack") and math.max(1, math.min(3, st.pack or 1)) or 1
                for _ = 1, n do
                    table.insert(ids, m.foe)
                end
            end
            if m.ally then
                -- (The Mech answers to whoever woke it: Euryale goes for them, and it stops if they drop.)
                -- (false: nobody at the table, when Flitwidget woke it himself.)
                local cmd
                if id == "mech" then
                    cmd = st.mech_commander
                end
                table.insert(allies, { id = m.ally, name = (id == "mech") and st.mech_name or nil, commander = cmd })
            end
            if m.opt then
                opts[m.opt] = true
            end
        end
    end
    if st.flags.paint_dagger then
        opts.paint = true          -- (the loose end: Telpur sold them a paint-touched dagger)
    end
    return { ids = ids, allies = allies, opts = opts, boss_name = "Euryale" }
end

-- The fair-warning bank (Straps: a harsh call feels earned when they took a chance knowingly) -----

-- How many harsh calls this table takes in its stride before it needs a chance in the bank: a
-- Dark and dangerous table takes the first one each night on the chin.
function M.free_harsh(campaign)
    local tbl = campaign.table
    return (tbl and tbl.tone == "grim") and 1 or 0
end

-- Hooks ------------------------------------------------------------------------------------

function M.hook(campaign, key)
    local id = campaign.adv.hooks[key]
    for _, h in ipairs(MODULE.hooks[key] or {}) do
        if h.id == id then
            -- A tie moved where it pays off (game/model/ties.lua): the same hook, in that room.
            local moved = campaign.adv.hook_room and campaign.adv.hook_room[key]
            if moved and moved ~= h.room then
                local copy = {}
                for k, v in pairs(h) do
                    copy[k] = v
                end
                copy.room = moved
                copy.moved_from = h.room
                return copy
            end
            return h
        end
    end
end

function M.set_hook(campaign, key, id)
    campaign.adv.hooks[key] = id
end

-- Who a room is for: the heroes whose hook pays off there.
function M.hooked(campaign, room)
    local out = {}
    for _, p in ipairs(campaign.players) do
        local h = M.hook(campaign, p.key)
        if h and h.room == room then
            table.insert(out, p)
        end
    end
    return out
end

-- Between sessions: requests, loose ends, favors --------------------------------------------

-- The questions waiting this week, in the order to ask them.
function M.prompts(campaign)
    local st = campaign.adv
    local out = {}
    if st.ending then
        return out
    end
    for _, le in ipairs(MODULE.loose_ends) do
        local gone = le.when.skipped
        if not st.answered[le.id] and gone and (st.skipped[gone] or (st.passed or {})[gone]) and not st.done[gone] then
            table.insert(out, { kind = "loose", def = le, id = le.id })
        end
    end
    for who, def in util.sorted_pairs(MODULE.favors) do
        if not st.favor_done[who] and (st.favors[who] or 0) >= MODULE.FAVOR_AT then
            table.insert(out, { kind = "favor", def = def, id = who })
        end
    end
    local asked = 0
    for _, rq in ipairs(MODULE.requests) do
        local ask = asked < 2 and not st.answered[rq.id] and st.done[rq.after] and (not rq.needs_flag or st.flags[rq.needs_flag])
            and campaign:player(rq.who) and campaign:player(rq.who).present ~= false and M.request_ask(campaign, rq)
        if ask then
            table.insert(out, { kind = "request", def = rq, id = rq.id, ask = ask })
            asked = asked + 1
        end
    end
    -- A ruling the DM promised to look up after last session ("Quick call now, look it up
    -- after"): the group chat is where it gets posted, or not.
    local due = campaign.promises_due and campaign.promises_due.look_it_up
    if due and due.week < (campaign.week or 1) and not st.answered["ruling_" .. due.week] then
        table.insert(out, { kind = "ruling", id = "ruling_" .. due.week, def = { topic = due.topic or "that rule" } })
    end
    -- (A stable order: the same week asks the same questions in the same order every run.)
    for i, pr in ipairs(out) do
        pr.n = i
    end
    table.sort(out, function(a, b)
        local order = { ruling = 0, request = 1, loose = 2, favor = 3 }
        if order[a.kind] ~= order[b.kind] then
            return order[a.kind] < order[b.kind]
        end
        return a.n < b.n
    end)
    return out
end

-- How a hero stands between sessions (what the last night left them with), or nil if they've
-- rested since.
local function worn(campaign, key)
    local ps = campaign.party_state
    local s = ps and not ps.rested and ps.pcs and ps.pcs[key]
    if not s then
        return nil
    end
    local slots, casts = 0, false
    for _, n in pairs((s.res and s.res.slots) or {}) do
        casts = true
        slots = slots + n
    end
    return { hp = (s.hp or 1) / math.max(1, s.hp_max or 1), out_of_spells = casts and slots == 0 }
end

-- What a request says, from how things stand: the asker's hero by name (whoever they play now),
-- and the first ask_if that holds: a `state` of their hero after last night (spells: out of
-- spells; hurt: under 60% HP; party: the party under 70%; down: went down last night; last_hit:
-- landed a killing blow last night) or a `when` (M.test). only_if: no reason, no request (the
-- playtest, Nov 2: "oswin is out of spells" with every slot full). Nil: nothing to ask.
function M.request_ask(campaign, rq)
    local p = campaign:player(rq.who)
    local vars = { char = string.lower(p and p.char or "") }
    local state = {}
    local w = worn(campaign, rq.who)
    if w then
        state.spells = w.out_of_spells
        state.hurt = w.hp < 0.6
    end
    local ps = campaign.party_state
    local hp, n = 0, 0
    for _, s in util.sorted_pairs((ps and not ps.rested and ps.pcs) or {}) do
        hp = hp + (s.hp or 1) / math.max(1, s.hp_max or 1)
        n = n + 1
    end
    state.party = n > 0 and hp / n < 0.7
    for _, e in ipairs((campaign.night and campaign.night.ledger) or {}) do
        if e.who == rq.who and e.ev == "down" then
            state.down = true
        elseif e.who == rq.who and e.ev == "killing_blow" then
            state.last_hit = true
        end
    end
    for _, alt in ipairs(rq.ask_if or {}) do
        if (alt.state and state[alt.state]) or (alt.when and M.test(campaign, alt.when)) then
            return util.fill(alt.text, vars)
        end
    end
    if rq.only_if then
        return nil
    end
    return util.fill(rq.ask, vars)
end

-- A request's answer, in the words for whoever asked (their hero by name).
function M.request_reply(campaign, rq, a)
    local p = campaign:player(rq.who)
    return util.fill(a.reply or "", { char = p and p.char or "" })
end

-- The ruling, posted in the chat (keep) or left (it breaks when the night ends, social.lua).
function M.answer_ruling(campaign, id, keep)
    local st = campaign.adv
    if st.answered[id] then
        return
    end
    st.answered[id] = keep and "posted" or "left"
    if keep then
        campaign.promises_due.look_it_up = nil
        local social = require "game.model.social"
        social.push(campaign, "rules", -6)
        local sam = campaign:player("sam")
        if sam then
            score.add(sam, "trust", 2)
        end
    end
end

local function like_for(p, likes)
    local n = 0
    for arch, v in util.sorted_pairs(likes or {}) do
        n = n + v * score.arch(p, arch)
    end
    return n
end

-- Marks added between sessions wait for the next night, where Euryale gets her line as they land
-- (museum_night.intro): the table never hears a mark go on her card in silence.
local function hold_marks(campaign, added)
    local st = campaign.adv
    st.unannounced = st.unannounced or {}
    for _, m in ipairs(added or {}) do
        if not util.contains(st.unannounced, m) then
            table.insert(st.unannounced, m)
        end
    end
end

-- The Steam Mech woken some other way than the code (a loose end): it still has a name, and it
-- answers to nobody at the table (Flitwidget woke it), so nothing powers it down mid-fight.
local function mech_woken(campaign, added)
    local st = campaign.adv
    if util.contains(added or {}, "mech") then
        st.mech_name = st.mech_name or MODULE.mech_names[((campaign.week or 1) % #MODULE.mech_names) + 1]
        if st.mech_commander == nil then
            st.mech_commander = false
        end
    end
end

-- A request answered: the asker, then everyone by type. Returns what each friend thinks.
function M.answer_request(campaign, id, answer)
    local st = campaign.adv
    local rq
    for _, r in ipairs(MODULE.requests) do
        if r.id == id then
            rq = r
        end
    end
    if not rq or st.answered[id] then
        return nil
    end
    local a = rq.answers[answer]
    st.answered[id] = answer
    local reactions = {}
    for _, p in ipairs(campaign.players) do
        local d = like_for(p, MODULE.answer_like[answer]) * 0.5
        if p.key == rq.who then
            d = d + (a.asker or 0)
        end
        if d ~= 0 then
            score.add(p, "investment", d * 1.5)
            score.add(p, "trust", d * 0.5)
        end
        reactions[p.key] = d
    end
    hold_marks(campaign, M.apply(campaign, a.mus, nil, rq.who))
    if a.mus and a.mus.warn then
        -- (They asked, and you told them straight: they know now.)
        local asker = campaign:player(rq.who)
        local what = util.fill(a.reply or "a danger", { char = asker and asker.char or "they" })
        require("game.model.warnings").note(campaign, type(a.mus.warn) == "string" and a.mus.warn or id, what, "told")
    end
    return reactions, a
end

function M.answer_loose(campaign, id, i)
    local st = campaign.adv
    for _, le in ipairs(MODULE.loose_ends) do
        if le.id == id and not st.answered[id] then
            local o = le.options[i]
            st.answered[id] = i
            local added = M.apply(campaign, o.mus, "loose")
            hold_marks(campaign, added)
            mech_woken(campaign, added)
            -- (If they go back for the room after all, the mark it moved goes back with it.)
            if o.mus and o.mus.mark and le.when.skipped then
                fill(st)
                st.rehomed[le.when.skipped] = st.rehomed[le.when.skipped] or {}
                table.insert(st.rehomed[le.when.skipped], o.mus.mark)
            end
            for _, p in ipairs(campaign.players) do
                score.add(p, "investment", ((o.like or {})[p.key] or 0) * 1.5)
            end
            return o
        end
    end
end

function M.answer_favor(campaign, who, help_i, hurt_i)
    local st = campaign.adv
    local def = MODULE.favors[who]
    if not def or st.favor_done[who] then
        return
    end
    st.favor_done[who] = { help = help_i, hurt = hurt_i }
    local h, u = def.helps[help_i], def.hurts[hurt_i]
    hold_marks(campaign, M.apply(campaign, h and h.mus))
    hold_marks(campaign, M.apply(campaign, u and u.mus))
    for _, o in ipairs({ h or false, u or false }) do
        if o and o.mus and o.mus.warn then
            require("game.model.warnings").note(campaign, type(o.mus.warn) == "string" and o.mus.warn or ("favor_" .. who),
                o.label, "told")
        end
    end
    return h, u
end

-- The story so far, in a few lines: what each room left behind (for prep and the night's recap).
function M.story_so_far(campaign)
    local st = campaign.adv
    local lines = {}
    for _, step in ipairs(st.path) do
        local r = MODULE.rooms[step.room]
        if not r.virtual then
            local goal = r.comps and r.comps.goal and content.components[r.comps.goal]
            local how = goal and (step.outcome == "win" and (step.got or goal.got) or nil)
            table.insert(lines, { room = step.room, name = r.name, week = step.week, outcome = step.outcome,
                                  text = r.name .. (how and (": " .. how) or (step.outcome == "lose" and ": a rough one" or "")) })
        end
    end
    return lines
end

-- Where they are, in a sentence.
function M.where(campaign)
    local st = campaign.adv
    if st.ending then
        return "The museum is Flitwidget's again."
    end
    if st.choices and #st.choices > 0 then
        local names = {}
        for _, id in ipairs(st.choices) do
            table.insert(names, MODULE.rooms[id].name)
        end
        return "At a fork: " .. util.join_names(names) .. "."
    end
    local r = st.at and MODULE.rooms[st.at]
    if r and r.boss then
        return "At the top of the stairs. Euryale is waiting."
    end
    return r and ("Next: " .. r.name .. ".") or "Somewhere in the museum."
end

-- The journey recap at the end: the route, what each room left behind, Euryale's final card.
function M.journey(campaign)
    local st = campaign.adv
    local rooms = {}
    for _, step in ipairs(st.path) do
        local r = MODULE.rooms[step.room]
        if not r.virtual then
            local marks = {}
            for _, id in ipairs(st.mark_list) do
                if st.marks[id].room == step.room then
                    table.insert(marks, MODULE.marks[id].name)
                end
            end
            table.insert(rooms, { id = step.room, name = r.name, week = step.week, outcome = step.outcome, marks = marks,
                                  at = r.at, fought = (step.fought and r.optional_fight) and r.boss_name or nil })
        end
    end
    local skipped = {}
    for _, id in ipairs(MODULE.order) do
        if st.skipped[id] and not MODULE.rooms[id].virtual then
            table.insert(skipped, MODULE.rooms[id].name)
        end
    end
    local ending = st.ending and MODULE.endings[st.ending]
    return { rooms = rooms, skipped = skipped, card = M.boss_card(campaign), ending = ending, ending_id = st.ending,
             francs = st.francs, weeks = st.weeks or 0, harsh = st.harsh, mech = st.mech_name }
end

return M
