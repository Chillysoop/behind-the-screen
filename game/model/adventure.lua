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
M.FOREIGN = { "Ilsa", "Kessrick", "Velvet Hand", "Millbrook", "Sable", "relic", "abbot", "Tobin", "Kettle", "Gus",
              "bells", "Bells", "bell tower", "bell%-ringer", "bell paths", "Vask", "Hale's", "Wren", "Corin",
              "warband", "scriptorium", "Lowmarket", "Silver Spurs", "Lamplighters", "Vale" }

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

local function deep_foreign(t, seen)
    if type(t) == "string" then
        return M.foreign(t)
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
        if k ~= "where" and k ~= "suits" and deep_foreign(v, seen) then
            return true
        end
    end
    return false
end
M.deep_foreign = deep_foreign

-- Drop the list entries (lines, stock moves) that would drag the old story in.
local function strip_list(list)
    if type(list) ~= "table" then
        return
    end
    for i = #list, 1, -1 do
        if deep_foreign(list[i]) then
            table.remove(list, i)
        end
    end
end

-- Every list in a data table, all the way down: entries that mention the old story go.
local function scrub(t, seen)
    if type(t) ~= "table" or seen[t] then
        return
    end
    seen[t] = true
    if #t > 0 then
        for i = #t, 1, -1 do
            if deep_foreign(t[i]) then
                table.remove(t, i)
            end
        end
    end
    for _, v in pairs(t) do
        scrub(v, seen)
    end
end
M.scrub = scrub

-- The prologue's own arc, in the shape the rest of the game reads (content.arc): its premise and
-- people for the notebook, and no beats (the module is the story).
local function module_arc()
    local people = {}
    for _, p in ipairs(MODULE.people) do
        table.insert(people, { id = p.id, name = p.name, role = p.role, about = p.about, known = p.known })
    end
    return {
        name = MODULE.title, pitch = MODULE.pitch, SESSIONS = MODULE.MAX_WEEKS,
        questions = {}, premise = MODULE.premise, people = people, beats = {},
        STORY_INVESTMENT = 2, finale = {}, module = true,
    }
end

-- Switch the game's shared content over to the prologue (once per run; the v2 build only ever
-- runs the module). Old-story lines are filtered out, the heroes are who the book needs.
function M.enter(campaign)
    if not M.entered then
        M.entered = true
        M.bells_arc = M.bells_arc or content.arc
        content.arc = module_arc()
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
        -- What the friends and the scenes say: nothing from the old story.
        for _, list in pairs(content.actions or {}) do
            strip_list(list)
        end
        for _, v in pairs(content.scene_beats or {}) do
            if type(v) == "table" then
                for _, list in pairs(v) do
                    strip_list(list)
                end
            end
        end
        if content.improv then
            strip_list(content.improv.stock)
        end
        local seen = {}
        scrub(content.curveballs, seen)
        scrub(content.decisions, seen)
        scrub(content.table_behaviors, seen)
        scrub(content.stunts, seen)
        for _, name in ipairs({ "friction", "rests", "table_behaviors", "scene_beats", "fails", "improv", "table_talk",
                                "keepsakes", "inspiration", "convos", "chat", "actions", "actions_more",
                                "killing_blows", "handouts", "awards", "dice", "moods", "takeover" }) do
            local ok, data = pcall(require, "game.data." .. name)
            if ok then
                scrub(data, seen)
            end
        end
        scrub(require("game.model.recap"), seen)
        M.museum_death()
        local bc = content.triggered and content.triggered.boss_crit
        if bc then
            bc.text = "{actor_char} is about to drop {boss} in round {round}. The whole table can see it coming."
        end
        if content.conflicts and content.conflicts.tone then
            content.conflicts.tone.about = "Mara wants the museum's mysteries taken seriously. Jess can't resist a joke."
        end
        local lib = content.dialogue
        if lib then
            lib.exclude = function(l)
                return M.foreign(l.text) or M.foreign(l.reply)
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
        -- The first session's introductions: the book's hooks, not the old backstories.
        local intros = require "game.data.intros"
        for key, p in pairs(intros.PLAYERS or {}) do
            local h = MODULE.hooks[key]
            if h then
                p.story = { h[1].intro, h[2].intro }
                p.grim = { false, false }
                p.all_in = MODULE.all_in[key] or p.all_in
            end
            for _, list in pairs(p) do
                if type(list) == "table" then
                    strip_list(list)
                end
            end
        end
        intros.BOND = {}      -- how the old heroes met: a story for the full campaign
        for _, list in pairs(intros.REACT or {}) do
            strip_list(list)
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
    d.WAKE = "They hold the wake in the gift shop. Telpur leaves a candle burning on the counter for {char} all night."
    d.QUEST = { name = "The way back", line = "There's a way to bring {char} back: Flitwidget swears one of his exhibits can do it, for a price.",
                win = "{char} opens their eyes on the gift shop floor. They're back, and they remember the dark.",
                lose = "The exhibit stays silent. {char} isn't coming back. The table says goodbye properly." }
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
            pg.seed = nil
        end
    end
end

-- The museum's people get their lines in game night's dialogue.
function M.add_npc_lines(lib)
    if lib.museum_lines then
        return
    end
    lib.museum_lines = true
    for speaker, triggers in pairs(MODULE.npc_lines) do
        for trigger, list in pairs(triggers) do
            for i, text in ipairs(list) do
                table.insert(lib.lines, { id = trigger .. "." .. speaker .. "." .. i, trigger = trigger, speaker = speaker,
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
        skipped = {},               -- rooms left behind for good
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
    }
end

function M.on(campaign)
    return campaign and campaign.module ~= nil and campaign.adv ~= nil
end

function M.room(id)
    return MODULE.rooms[id]
end

function M.state(campaign)
    return campaign.adv
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
    return true
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

local function needs_met(st, room)
    if not room.needs then
        return true
    end
    for _, id in ipairs(room.needs) do
        if st.done[id] then
            return true
        end
    end
    return false
end

-- From a room just played, the rooms the party can go to now (unplayed, not left behind, ready).
function M.options_after(campaign, from)
    local st = campaign.adv
    local r = MODULE.rooms[from]
    local out = {}
    for _, id in ipairs(r and r.next or {}) do
        local nr = MODULE.rooms[id]
        if nr and not st.done[id] and not st.skipped[id] and needs_met(st, nr) then
            table.insert(out, id)
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
        if not seen[id] and not st.done[id] and not st.skipped[id] then
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
                for _, nid in ipairs(r.next or {}) do
                    if not seen[nid] then
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

function M.boss_week(campaign)
    local st = campaign.adv
    return not st.ending and st.at == "lair" and not (st.choices and #st.choices > 0)
end

function M.over(campaign)
    return campaign.adv and campaign.adv.ending ~= nil
end

-- Moving through the museum ---------------------------------------------------------------------

-- The party goes into a room: anything it closes off is left behind for good.
function M.enter_room(campaign, id, week)
    local st = campaign.adv
    local r = MODULE.rooms[id]
    st.choices = nil
    st.at = id
    local left = {}
    for _, cid in ipairs(r.closes or {}) do
        if not st.done[cid] and not st.skipped[cid] then
            st.skipped[cid] = week or true
            table.insert(left, cid)
        end
    end
    return left
end

-- The room is done: where the party can go from here.
function M.leave_room(campaign, id, outcome, week)
    local st = campaign.adv
    st.done[id] = outcome or "win"
    table.insert(st.path, { room = id, week = week, outcome = outcome or "win" })
    local opts = M.options_after(campaign, id)
    if #opts == 1 then
        st.at, st.choices = opts[1], nil
    elseif #opts > 1 then
        st.at, st.choices = nil, opts
    else
        st.at, st.choices = nil, nil
    end
    return opts
end

-- Marks, flags, Francs, favors --------------------------------------------------------------

function M.add_mark(campaign, id, room)
    local st = campaign.adv
    if not MODULE.marks[id] or st.marks[id] then
        return false
    end
    st.marks[id] = { week = campaign.week, room = room }
    table.insert(st.mark_list, id)
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
function M.apply(campaign, mus, room)
    local st = campaign.adv
    local added = {}
    if not mus then
        return added
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
    return added
end

-- Euryale's card: her base, and every mark with why it's there and what it does on boss night.
function M.boss_card(campaign)
    local st = campaign.adv
    local marks = {}
    for _, id in ipairs(st.mark_list) do
        local m = MODULE.marks[id]
        table.insert(marks, { id = id, name = m.name, why = m.why, showdown = m.showdown, thought = m.thought,
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
                table.insert(allies, { id = m.ally, name = (id == "mech") and st.mech_name or nil,
                                       commander = (id == "mech") and st.mech_commander or nil })
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
        if not st.answered[le.id] and le.when.skipped and st.skipped[le.when.skipped] then
            table.insert(out, { kind = "loose", def = le, id = le.id })
        end
    end
    for who, def in pairs(MODULE.favors) do
        if not st.favor_done[who] and (st.favors[who] or 0) >= MODULE.FAVOR_AT then
            table.insert(out, { kind = "favor", def = def, id = who })
        end
    end
    local asked = 0
    for _, rq in ipairs(MODULE.requests) do
        if asked < 2 and not st.answered[rq.id] and st.done[rq.after] and (not rq.needs_flag or st.flags[rq.needs_flag])
            and campaign:player(rq.who) and campaign:player(rq.who).present ~= false then
            table.insert(out, { kind = "request", def = rq, id = rq.id })
            asked = asked + 1
        end
    end
    table.sort(out, function(a, b)
        local order = { request = 1, loose = 2, favor = 3 }
        return order[a.kind] < order[b.kind]
    end)
    return out
end

local function like_for(p, likes)
    local n = 0
    for arch, v in pairs(likes or {}) do
        n = n + v * score.arch(p, arch)
    end
    return n
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
    M.apply(campaign, a.mus)
    if a.mus and a.mus.warn then
        st.bank = st.bank + 1
    end
    return reactions, a
end

function M.answer_loose(campaign, id, i)
    local st = campaign.adv
    for _, le in ipairs(MODULE.loose_ends) do
        if le.id == id and not st.answered[id] then
            local o = le.options[i]
            st.answered[id] = i
            M.apply(campaign, o.mus, "loose")
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
    M.apply(campaign, h and h.mus)
    M.apply(campaign, u and u.mus)
    if (h and h.mus and h.mus.warn) or (u and u.mus and u.mus.warn) then
        st.bank = st.bank + 1
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
            local how = goal and (step.outcome == "win" and goal.got or nil)
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
                                  at = r.at })
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
