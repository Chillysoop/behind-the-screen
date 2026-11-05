-- Roadmap wave 2, "the table": the items Conner said yes to that are about the friends at the table
-- and what the DM gets (R10 the friends choose differently from run to run, R5/D2 Euryale's escape
-- costs something, R6 a gentler first night, D6 everyone's own pronouns (the heroes, the friends at
-- the table, the museum's people), Exhibit B on the table,
-- wave 1's leftovers, and the same seed playing the same way every run). Whole prologues: the museum
-- sim (tools/sim/museum.lua, its three DMs) played in this process over several seeds, watched
-- through its events; one smoke run with DUMP_DIR for what's on screen; and targeted cases.
-- Run from the project root:
--     lua tools/tests/roadmap_table_check.lua [seeds]
-- Prints one line per item: what was seen, and FAIL lines where play contradicts the fix.

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local SEEDS = tonumber(arg[1]) or 24
local STYLES = { "careful", "random", "careless" }
local ITEMS = { "run", "R10", "R5", "R6", "D6", "EB", "LEFT", "DET" }
local NAMES = { run = "whole prologues", R10 = "the friends choose differently", R5 = "Euryale's escape costs",
    R6 = "a gentler first night", D6 = "the heroes' own pronouns", EB = "Exhibit B on the table",
    LEFT = "wave 1's leftovers", DET = "the same seed, the same night" }
NAMES.D6 = "everyone's own pronouns"

local fails = {}
local function fail(item, msg)
    fails[item] = fails[item] or { n = 0 }
    if #fails[item] < 8 then
        table.insert(fails[item], msg)
    end
    fails[item].n = fails[item].n + 1
end
local E = {}
local function add(item, key, n)
    E[item] = E[item] or {}
    E[item][key] = (E[item][key] or 0) + (n or 1)
end
local function set(item, key, v)
    E[item] = E[item] or {}
    E[item][key] = v
end
-- A targeted case: an error inside it is a failure of its item, not of the whole check.
local function case(item, fn)
    local ok, err = pcall(fn)
    if not ok then
        fail(item, "error: " .. tostring(err))
    end
end

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local util = require "game.model.util"
local mn = require "game.model.museum_night"
local night_mod = require "game.model.night"

-- A campaign at Session Zero, through to the start of its first night.
local function first_night(seed)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        adventure.set_hook(c, key, adventure.data.hooks[key][1].id)
    end
    c:start_week()
    local night = c:start_night()
    night.mus = night.mus or {}
    return c, night
end

-- Run fn inside a coroutine, as game night does, answering every call: decisions with `pick(ev)` (the
-- last option by default: "It's up to you"), rolls with a 10. Returns fn's result and the events.
local function run_beats(fn, pick)
    local evs = {}
    local co = coroutine.create(fn)
    local ok, ev = coroutine.resume(co)
    local guard = 0
    while coroutine.status(co) ~= "dead" and guard < 400 do
        guard = guard + 1
        if not ok then
            error(ev)
        end
        table.insert(evs, ev)
        local answer
        if type(ev) == "table" and ev.kind == "decision" then
            answer = (pick and pick(ev)) or #ev.card.options
        elseif type(ev) == "table" and (ev.kind == "roll" or ev.kind == "ruling") then
            answer = ev.kind == "roll" and 10 or 1
        elseif type(ev) == "table" and ev.kind == "roll_where" then
            answer = "open"
        end
        ok, ev = coroutine.resume(co, answer)
    end
    if not ok then
        error(ev)
    end
    return ev, evs
end

local function card_by_id(id)
    for _, m in ipairs(adventure.data.moments) do
        if m.id == id then
            return m
        end
    end
    local sd = adventure.data.showdown
    for _, k in ipairs({ "drink", "talk", "yield" }) do
        if sd[k] and sd[k].id == id then
            return sd[k]
        end
    end
end

-- Whole prologues ---------------------------------------------------------------------------------
-- The sim itself, played in this process with hooks on the table's picks, the night's events and the
-- endings, so what's measured is exactly what `lua tools/sim/museum.lua <seed> <style>` plays.

-- (A reason as said: its {back} filled in with when the vote before was.)
local function says_line(text, l)
    local pat = string.gsub(string.gsub(l, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"), "{back}", ".-")
    return string.find(text or "", pat) ~= nil
end
local W = { picks = {}, reasons = { picks = 0, said = 0 }, nights = {}, endings = {}, texts = {}, item_lines = {}, vote_lines = {} }
local cur              -- { seed, style, c }
local HEROES = { "Thessaly", "Brannoc", "Pip", "Oswin" }

-- R10: every pick the table makes, by card, and whether the winning side said why.
local orig_pick = mn.table_pick
mn.table_pick = function(night, copy, vars)
    local said = {}
    local own_emit = rawget(night, "emit")
    night.emit = function(self, ev, ...)
        if type(ev) == "table" and ev.kind == "say" then
            table.insert(said, ev)
        end
        return night_mod.emit(self, ev, ...)
    end
    local ok, i = pcall(orig_pick, night, copy, vars)
    night.emit = own_emit
    if not ok then
        error(i, 0)
    end
    local live = 0
    for _, o in ipairs(copy.options) do
        live = live + (o.disabled and 0 or 1)
    end
    local o = copy.options[i] or {}
    local key = tostring(o.want or o.label)
    local id = tostring(copy.id)
    local r = W.picks[id] or { n = 0, by = {} }
    W.picks[id] = r
    r.n = r.n + 1
    r.by[key] = (r.by[key] or 0) + 1
    for _, ev in ipairs(said) do
        for key, list in pairs(mn.VOTE_WHY or {}) do
            for _, l in ipairs(list) do
                if says_line(ev.text, l) then
                    W.vote_lines[key] = (W.vote_lines[key] or 0) + 1
                end
            end
        end
    end
    if live > 1 then
        -- (A reason: "Let's <what they picked>. <why>", from someone on the side that won.)
        W.reasons.picks = W.reasons.picks + 1
        local want = string.lower(o.want or "")
        local why = false
        for _, ev in ipairs(said) do
            local w, rest = string.match(ev.text or "", "^Let's (.-)%.%s+(.+)$")
            if w and string.lower(w) == want and rest and #rest > 3 then
                why = true
            end
        end
        if why then
            W.reasons.said = W.reasons.said + 1
        end
    end
    return i
end

-- R5: how it ended, and how.
local orig_after = mn.after_showdown
mn.after_showdown = function(night, sc)
    local r = orig_after(night, sc)
    local st = night.campaign.adv
    if st.ending and cur and not cur.ended then
        cur.ended = true
        local how = (sc.boss_yielded and "yield") or (sc.boss_ran and "ran") or (sc.fought and "fight") or "talk"
        -- (The DM's own way out, taken with the party in trouble, against one taken freely.)
        if how == "ran" and night.dm_way_out then
            how = "ran_" .. night.dm_way_out
        end
        W.endings[cur.style] = W.endings[cur.style] or { n = 0 }
        local e = W.endings[cur.style]
        e.n = e.n + 1
        e[st.ending] = (e[st.ending] or 0) + 1
        if st.ending == "escape" then
            e.escape_by = e.escape_by or {}
            e.escape_by[how] = (e.escape_by[how] or 0) + 1
        end
    end
    return r
end

-- Every beat the table hears (D6, R5), and every call the DM gets, by night (R6).
local orig_emit = night_mod.emit
night_mod.emit = function(self, ev)
    if cur and type(ev) == "table" then
        local w = self.campaign.week or 0
        local key = cur.style .. "#" .. cur.seed .. "#" .. w
        local N = W.nights[key]
        if not N then
            N = { week = w, style = cur.style, k = {} }
            W.nights[key] = N
        end
        local k = ev.kind
        if k == "decision" then
            local id = ev.card and ev.card.id or ""
            local kind = string.find(id, "^table_asks_") and "table_asks" or (string.find(id, "^mus_fork_") and "fork_asks")
                or ("card_" .. tostring(ev.card and ev.card.type))
            N.k[kind] = (N.k[kind] or 0) + 1
            N.calls = (N.calls or 0) + 1
            table.insert(W.texts, { text = ev.card.text, where = key })
            for _, o in ipairs(ev.card.options or {}) do
                table.insert(W.texts, { text = o.label, where = key })
                if o.cost then
                    add("R5", "options_with_a_cost")
                    if not (o.sub and string.find(o.sub, "half the reward", 1, true)) then
                        fail("R5", key .. ": '" .. tostring(o.label) .. "' costs something, and the card doesn't say what")
                    end
                end
            end
        elseif k == "ruling" or k == "roll_where" then
            N.k[k] = (N.k[k] or 0) + 1
            N.calls = (N.calls or 0) + 1
        elseif k == "thought" then
            N.k.thought = (N.k.thought or 0) + 1
            table.insert(W.texts, { text = ev.text, where = key })
        elseif (k == "narrate" or k == "say" or k == "npc") and ev.text then
            table.insert(W.texts, { text = ev.text, where = key })
            -- (Leftovers: which wording each item line had, for the three ways.)
            for _, it in ipairs(adventure.data.items or {}) do
                for _, l in ipairs(it.lines or {}) do
                    local head = string.match(l, "^{holder} ([^:%.]+)") or string.match(l, "^([^:%.]+)")
                    if head and string.find(ev.text, head, 1, true) then
                        W.item_lines[it.id] = W.item_lines[it.id] or {}
                        W.item_lines[it.id][head] = true
                    end
                end
            end
        end
    end
    return orig_emit(self, ev)
end

local real_exit, real_print = os.exit, print
local function sim(seed, style)
    cur = { seed = seed, style = style }
    arg = { [0] = "tools/sim/museum.lua", tostring(seed), style }
    local out = {}
    os.exit = function() error("__done__", 0) end
    print = function(...)
        local t = {}
        for i = 1, select("#", ...) do
            t[i] = tostring(select(i, ...))
        end
        table.insert(out, table.concat(t, " "))
    end
    local ok, err = pcall(dofile, "tools/sim/museum.lua")
    print, os.exit = real_print, real_exit
    cur = nil
    if not ok and err ~= "__done__" then
        fail("run", "seed " .. seed .. " " .. style .. ": " .. tostring(err))
        return
    end
    for _, l in ipairs(out) do
        if string.find(l, "^FAIL") then
            fail("run", "seed " .. seed .. " " .. style .. ": " .. l)
        end
    end
    add("run", "prologues")
end

for _, style in ipairs(STYLES) do
    for seed = 1, SEEDS do
        sim(seed, style)
    end
end
night_mod.emit, mn.table_pick, mn.after_showdown = orig_emit, orig_pick, orig_after

-- R10: the friends choose differently from run to run -----------------------------------------------
-- No card's commonest pick above about 60% of seeded runs (76% to 82% before), and overall well under;
-- each pick with a reason said out loud by the side that won.
do
    local CARD_MAX, OVERALL_MAX, MIN_N = 0.66, 0.57, 30      -- (a card seen fewer times is too noisy to judge)
    local tot, top_all, worst, worst_id = 0, 0, 0, nil
    for id, r in pairs(W.picks) do
        local top = 0
        for _, n in pairs(r.by) do
            top = math.max(top, n)
        end
        tot, top_all = tot + r.n, top_all + top
        local share = top / r.n
        if r.n >= MIN_N then
            add("R10", "cards_measured")
            if share > CARD_MAX then
                fail("R10", string.format("%s: the same pick in %d of %d runs (%.0f%%)", id, top, r.n, 100 * share))
            end
            if share > worst then
                worst, worst_id = share, id
            end
        end
    end
    set("R10", "picks", tot)
    set("R10", "overall_top_pick_pct", math.floor(100 * top_all / math.max(1, tot) + 0.5))
    set("R10", "worst_card_pct", math.floor(100 * worst + 0.5))
    if tot == 0 or top_all / tot > OVERALL_MAX then
        fail("R10", string.format("overall, a card's commonest pick %.0f%% of the time (want %.0f%% or under)",
            100 * top_all / math.max(1, tot), OVERALL_MAX * 100))
    end
    local r = W.reasons
    set("R10", "picks_with_a_reason_said_pct", math.floor(100 * r.said / math.max(1, r.picks) + 0.5))
    -- (What carries over, said in play: the push, the habit, the week they've had, a quiet night.)
    local vl = W.vote_lines
    set("R10", "said_in_play", string.format("pushed %d, habit %d, mood %d, quiet %d", vl.pushed or 0,
        (vl.safe_last or 0) + (vl.bold_last or 0), (vl.tired or 0) + (vl.celebrating or 0) + (vl.stressed or 0), vl.quiet or 0))
    if (vl.pushed or 0) == 0 or (vl.safe_last or 0) + (vl.bold_last or 0) == 0 then
        fail("R10", "in whole prologues nobody said they went along last time, or that the table played it safe (or charged in) last time")
    end
    if r.picks == 0 or r.said / r.picks < 0.8 then
        fail("R10", string.format("only %d of %d picks had the winning side say why", r.said, r.picks))
    end
end

-- Every party card has at least two real options: two that are some friend's favourite, as the one who
-- found it or not (the review: one option paid far more than the rest for nearly everyone).
case("R10", function()
    local _, night = first_night(5)
    local cards = {}
    for _, m in ipairs(adventure.data.moments) do
        if m.party then
            table.insert(cards, m)
        end
    end
    for _, k in ipairs({ "drink", "talk", "yield" }) do
        table.insert(cards, adventure.data.showdown[k])
    end
    for _, card in ipairs(cards) do
        local fav = {}
        for _, p in ipairs(night.players) do
            for _, lead in ipairs({ false, true }) do
                night.actor = lead and p or nil
                local best, bv, second = nil, nil, nil
                for i, o in ipairs(card.options) do
                    local v = mn.lean(night, p, o)
                    if not bv or v > bv then
                        best, second, bv = i, bv, v
                    elseif not second or v > second then
                        second = v
                    end
                end
                if best and (not second or bv - second >= 0.3) then
                    fav[best] = true
                end
            end
        end
        night.actor = nil
        local n = 0
        for _ in pairs(fav) do
            n = n + 1
        end
        if n < 2 then
            fail("R10", card.id .. ": only one option is anyone's favourite")
        else
            add("R10", "cards_with_two_real_options")
        end
    end
end)

-- The friend who went along last time holds out for theirs, and says so; the table notices its habit.
case("R10", function()
    local pushed, habit, habit_wrong = 0, 0, 0
    for trial = 1, 16 do
        local c, night = first_night(100 + trial)
        night.gentle = nil          -- (so they can ask you, as from the second night)
        local card = card_by_id("mus_lair_frame")
        local copy = { id = card.id, options = card.options }
        c.adv.votes = { lost = { sam = 1 }, last = { kind = "safe", streak = 2 } }
        night.actor = c:player("mara")
        local _, evs = run_beats(function()
            return mn.table_pick(night, copy, night.mus_vars)
        end)
        for _, ev in ipairs(evs) do
            if ev.kind == "say" and ev.text then
                for _, l in ipairs(mn.VOTE_WHY.pushed) do
                    if ev.who == "sam" and says_line(ev.text, l) then
                        pushed = pushed + 1
                    end
                end
                for _, l in ipairs(mn.VOTE_WHY.safe_last) do
                    if says_line(ev.text, l) then
                        habit = habit + 1
                        -- (Said by someone whose pick is the bold one: reaching into the frame, not swords out.)
                        if not string.find(ev.text, "reach into the frame", 1, true) then
                            habit_wrong = habit_wrong + 1
                        end
                    end
                end
            end
        end
        -- What the next vote remembers.
        local vt = c.adv.votes
        if not (vt and vt.last and vt.last.kind) then
            fail("R10", "after a pick, the table doesn't remember what kind of pick it was")
        end
    end
    set("R10", "pushes_said", pushed)
    set("R10", "habits_said", habit)
    if pushed == 0 then
        fail("R10", "Sam lost the last vote, and never said he was holding out for his this time")
    end
    if habit == 0 then
        fail("R10", "after two safe picks running, nobody said 'we played it safe last time'")
    end
    if habit_wrong > 0 then
        fail("R10", "'we played it safe last time' said for the safe option")
    end
    -- The kinds.
    local k = mn.vote_kind
    if k({ roll = {} }) ~= "bold" or k({ mus = { fight = true } }) ~= "bold" or k({ mus = { warn = true } }) ~= "safe"
        or k({ mus = { francs = 1 } }) ~= nil or k({ then_moment = "x" }) ~= "bold" then
        fail("R10", "vote_kind sorts options wrongly")
    end
    -- What carries over survives a save.
    local save = require "game.model.save"
    local c = first_night(9)
    c.adv.votes = { lost = { mara = 2 }, last = { kind = "bold", streak = 1, card = "mus_plaque" } }
    local c2 = save.load(save.dump(c))
    if not (c2.adv.votes and c2.adv.votes.lost.mara == 2 and c2.adv.votes.last.kind == "bold") then
        fail("R10", "the votes' memory doesn't survive a save")
    end
    add("R10", "unit_cases")
end)

-- The ultimatum after the world merge: with the fight and the Lecturer's page the only answers, the
-- table read her the page every time (18 of 18 over 40 seeds), since only Dev wanted the fight. What
-- they brought against her now counts for "Weapons out": a planner counts it all, whoever carries a
-- thing wants to use it, and each says so in words that name it. (Played without Dev, the fight's
-- own fan, so the others are heard: with nothing brought, nobody else ever wants it.)
case("R10", function()
    local items_mod = require "game.model.items"
    local card = card_by_id("mus_ultimatum")
    local fight_o, page_o
    for _, o in ipairs(card.options) do
        if o.edges then
            fight_o = o
        elseif o.mus and o.mus.use == "pages" then
            page_o = o
        end
    end
    if not (fight_o and page_o) then
        fail("R10", "the ultimatum's fight doesn't count what they brought against her (no `edges`)")
        return
    end
    local function trials(ready)
        local r = { fight_wins = 0, others_for_fight = 0, mine = 0, edges = 0, wrong = 0 }
        for trial = 1, 24 do
            local c, night = first_night(300 + trial)
            night.gentle = nil
            if ready then
                items_mod.give(c, "mirror", "jess", "found")
                adventure.add_mark(c, "mirror", "tomorrow")
                adventure.add_mark(c, "mech", "tomorrow")
                c.adv.mech_commander = "sam"
            end
            local without = {}
            for _, p in ipairs(night.players) do
                if p.key ~= "dev" then
                    table.insert(without, p)
                end
            end
            night.players = without
            night.actor = c:player("mara")
            local copy = { id = card.id, options = { fight_o, page_o } }
            local i, evs = run_beats(function()
                return mn.table_pick(night, copy, night.mus_vars)
            end)
            if i == 1 then
                r.fight_wins = r.fight_wins + 1
            end
            for _, ev in ipairs(evs) do
                local t = type(ev) == "table" and ev.kind == "say" and ev.text or ""
                if string.find(t, "^Let's fight her") then
                    r.others_for_fight = r.others_for_fight + 1
                end
                if string.find(t, "cupboard door", 1, true) then
                    r.mine = r.mine + 1
                    if ev.who ~= "jess" then
                        r.wrong = r.wrong + 1       -- (only the one who carries it calls it theirs)
                    end
                end
                if string.find(t, "for her stare", 1, true) or string.find(t, "my Mech", 1, true) then
                    r.edges = r.edges + 1
                end
                if string.find(t, "Mech", 1, true) and string.find(t, "my Mech", 1, true) and ev.who ~= "sam" then
                    r.wrong = r.wrong + 1
                end
            end
        end
        return r
    end
    local bare, ready = trials(false), trials(true)
    set("R10", "ultimatum_fight_wins", string.format("%d of 24 bare, %d of 24 ready for her", bare.fight_wins, ready.fight_wins))
    if bare.mine + bare.edges > 0 then
        fail("R10", "with nothing brought against her, a friend says they came ready for her")
    end
    if bare.others_for_fight > 0 then
        fail("R10", "with nothing brought against her and Dev away, someone wants the fight anyway")
    end
    if ready.others_for_fight == 0 or ready.mine + ready.edges == 0 then
        fail("R10", string.format("with a mirror and the Mech, nobody but Dev wants the fight (%d), or nobody says why (%d)",
            ready.others_for_fight, ready.mine + ready.edges))
    end
    if ready.wrong > 0 then
        fail("R10", "a friend calls something theirs that someone else carries")
    end
    if ready.fight_wins <= bare.fight_wins then
        fail("R10", "what they brought against her never turns the table to the fight")
    end
    add("R10", "unit_cases")
end)

-- R5, D2: Euryale's escape costs something you can see -----------------------------------------------
do
    local e = W.endings.careful or { n = 0 }
    local esc = e.escape or 0
    set("R5", "careful_endings", e.n)
    set("R5", "careful_escapes", esc)
    local by = {}
    for _, k in ipairs({ "yield", "ran", "ran_trouble", "ran_free", "fight", "talk" }) do
        if e.escape_by and e.escape_by[k] then
            table.insert(by, k .. " " .. e.escape_by[k])
        end
    end
    set("R5", "careful_escapes_by", table.concat(by, "/"))
    for _, st in ipairs(STYLES) do
        local x = W.endings[st] or {}
        local parts = {}
        for _, k in ipairs({ "fallen", "escape", "bargain", "slept", "ally", "timeout" }) do
            if x[k] then
                table.insert(parts, k .. " " .. x[k])
            end
        end
        set("R5", "endings_" .. st, table.concat(parts, "/"))
    end
    -- (Before: a careful DM let her go in 29 endings of 40, by taking the first option. What's counted is what
    -- the DM chose: the friends' own vote to let her go when she yields is theirs (November 3: the players'
    -- choices are the players'), and a careful DM takes the paid way out only with the party in real trouble.
    -- So a careful DM who lets her go freely fails, and so does her getting away in more than half the endings.)
    local by = e.escape_by or {}
    local free = (by.ran_free or 0) + (by.talk or 0)
    if e.n == 0 or free / e.n > 0.1 then
        fail("R5", string.format("a careful DM lets her get away freely in %d of %d endings", free, e.n))
    end
    if e.n == 0 or esc / e.n > 0.5 then
        fail("R5", string.format("she still gets away in %d of %d careful endings", esc, e.n))
    end
end
case("R5", function()
    local c = first_night(3)
    c.adv.gold = nil
    local full = adventure.reward_gold(c)
    c.adv.ending = "escape"
    local half = adventure.reward_gold(c)
    c.adv.gold = 40
    local half40 = adventure.reward_gold(c)
    if full ~= 30 or half ~= 15 or half40 ~= 20 then
        fail("R5", string.format("the reward: %s, after an escape %s, talked up to forty and escaped %s", full, half, half40))
    end
    c.adv.gold, c.adv.ending = nil, nil
    local board, sub = adventure.escape_cost(c)
    if not (board and string.find(board, "15 gold each, not 30", 1, true) and sub and string.find(sub, "half the reward", 1, true)) then
        fail("R5", "the board doesn't say what an escape costs: " .. tostring(board))
    end
    -- Every card that lets her go says it, and the table's power gamer minds it.
    local yield = adventure.data.showdown.yield.options[1]
    if not yield.escape or not (yield.mus and yield.mus.ending == "escape") then
        fail("R5", "the yield card's 'let her go' isn't marked as an escape")
    end
    local minds = false
    for _, e in ipairs(yield.effects or {}) do
        minds = minds or (e[1] == "arch:power_gamer" and (e.fun or 0) < 0)
    end
    if not minds then
        fail("R5", "letting her go costs the table nothing they feel")
    end
    add("R5", "unit_cases")
end)

-- R6: a gentler first night --------------------------------------------------------------------------
do
    local first, firsts, later, laters = 0, 0, 0, 0
    local worst = 0
    for key, N in pairs(W.nights) do
        local calls = N.calls or 0
        if N.week == 1 then
            firsts, first = firsts + 1, first + calls
            worst = math.max(worst, calls)
            local k = N.k
            if (k.roll_where or 0) > 1 or (k.ruling or 0) > 1 then
                fail("R6", key .. ": night 1 asked about " .. (k.roll_where or 0) .. " rolls and " .. (k.ruling or 0) .. " rulings")
            end
            if (k.thought or 0) > 1 then
                fail("R6", key .. ": night 1 had " .. k.thought .. " thoughts")
            end
            if (k.card_rules or 0) > 1 then
                fail("R6", key .. ": night 1 had " .. k.card_rules .. " rules questions")
            end
            for _, kk in ipairs({ "table_asks", "fork_asks", "card_combat", "card_boss" }) do
                if (k[kk] or 0) > 0 then
                    fail("R6", key .. ": night 1 had a " .. kk .. " call")
                end
            end
            if (k.ruling or 0) == 1 then
                add("R6", "first_nights_with_one_ruling")
            end
            if (k.thought or 0) == 1 then
                add("R6", "first_nights_with_one_thought")
            end
        elseif N.week == 2 then
            laters, later = laters + 1, later + calls
        end
    end
    local avg1 = first / math.max(1, firsts)
    set("R6", "night1_calls_avg", string.format("%.1f", avg1))
    set("R6", "night1_calls_max", worst)
    set("R6", "night2_calls_avg", string.format("%.1f", later / math.max(1, laters)))
    -- (Before: 17.9 calls on night 1, 14 to 22, and 1.6 thoughts.)
    if firsts == 0 or avg1 > 10.5 or worst > 13 then
        fail("R6", string.format("night 1 still has %.1f calls (up to %d)", avg1, worst))
    end
    if laters > 0 and later / laters < avg1 + 3 then
        fail("R6", "the second night is as quiet as the first: the calls never come back")
    end
end
-- Each kind of call has its own tip the first time it comes.
case("R6", function()
    local guide = require "game.data.guide"
    local function first_tip(app)
        for _, step in ipairs(guide.steps) do
            if step.screen == "night" and step.when then
                local ok, v = pcall(step.when, app, app.campaign)
                if ok and v then
                    return step.id
                end
            end
        end
    end
    local c = first_night(4)
    local cases = {
        { { kind = "decision", card = { id = "table_asks_mus_box", type = "table" } }, "night_table_asks" },
        { { kind = "decision", card = { id = "boss_turn", type = "boss" } }, "night_fight_call" },
        { { kind = "decision", card = { id = "dragging_fight", type = "pacing" } }, "night_fight_call" },
        { { kind = "decision", card = { id = "mus_whats_there", type = "screen" } }, "night_screen" },
        { { kind = "decision", card = { id = "grapple", type = "rules" } }, "night_rules" },
        { { kind = "decision", card = { id = "mus_pond", type = "story" } }, "night_decision" },
        { { kind = "roll_where" }, "night_roll_where" },
        { { kind = "ruling" }, "night_ruling" },
    }
    for _, cs in ipairs(cases) do
        local got = first_tip({ campaign = c, screen = "night", pending = cs[1] })
        if got ~= cs[2] then
            fail("R6", "a " .. tostring(cs[1].card and cs[1].card.type or cs[1].kind) .. " call gets the tip " .. tostring(got) .. ", not " .. cs[2])
        else
            add("R6", "tips_for_each_kind")
        end
    end
    c.week = 2      -- (past the first night's "it plays itself", which comes before anything)
    local thought = first_tip({ campaign = c, screen = "night", thinking = { x = true } })
    if thought ~= "night_thought" then
        fail("R6", "a thought gets the tip " .. tostring(thought))
    end
end)

-- D6: the heroes' own pronouns -------------------------------------------------------------------------
-- A heuristic over everything the table heard: someone named (a hero, a friend at the table, one of the
-- museum's people), then within the same clause "they", "their" or "them", with nobody else named and
-- no group word in between; and a line where one friend is named and the next sentence starts "They"
-- ("Mara goes quiet. They asked you about this"). The museum's people talk to and about the party, so
-- for them only what can't be the party counts: "they" or "their" right after the name ("Telpur
-- clears their throat"), and a next sentence that starts "They" or "Their" with nobody else in it.
local PRON = { they = true, their = true, them = true, themselves = true, themself = true, theirs = true,
               ["they're"] = true, ["they've"] = true, ["they'll"] = true, ["they'd"] = true }
local GROUP = { "and", "everyone", "everybody", "party", "both", "all", "others", "rest", "heroes", "table", "nobody",
                "anyone", "someone", "each", "group", "friends", "heroes'", "people", "us", "we", "you" }
local FRIENDS = { "Mara", "Dev", "Jess", "Sam" }
local PEOPLE = { "Telpur", "Flitwidget", "Euryale", "Lecturer" }
local ALL_NAMES = {}
for _, list in ipairs({ HEROES, FRIENDS, PEOPLE }) do
    for _, h in ipairs(list) do
        table.insert(ALL_NAMES, h)
    end
end
local function is_group(w)
    for _, g in ipairs(GROUP) do
        if w == g then
            return true
        end
    end
    for _, o in ipairs(ALL_NAMES) do
        if w == string.lower(o) or w == string.lower(o) .. "'s" then
            return true
        end
    end
    return false
end
-- Who's named in a sentence (own: not "Euryale's card", which is about the card).
local function names_in(sentence, own)
    local out = {}
    for _, h in ipairs(ALL_NAMES) do
        local i, j = string.find(sentence, "%f[%a]" .. h .. "%f[%A]")
        if i and not (own and string.sub(sentence, j + 1, j + 2) == "'s") then
            table.insert(out, h)
        end
    end
    return out
end
-- The clauses of a text that call one named person "they": a list of { name, clause }.
local function pron_hits(text)
    local hits = {}
    for clause in string.gmatch(text .. ".", "([^%.!%?;:\"]+)") do
        for _, h in ipairs(ALL_NAMES) do
            local person = util.contains(PEOPLE, h)
            local i, j = string.find(clause, "%f[%a]" .. h .. "%f[%A]")
            if i and not string.find(string.sub(clause, j + 1, j + 1), ",") then
                local words = {}
                for w in string.gmatch(string.lower(string.sub(clause, j + 1)), "[%a']+") do
                    table.insert(words, w)
                end
                local hit
                for k, w in ipairs(words) do
                    if PRON[w] and (not person or (k <= 2 and (w == "they" or w == "their" or w == "they're" or w == "they've"))) then
                        hit = true
                        break
                    end
                    if is_group(w) or (person and k >= 2) then
                        hit = false
                        break
                    end
                end
                if hit then
                    table.insert(hits, { h, clause })
                end
            end
        end
    end
    -- One person named, and the next sentence goes on about "they".
    local sentences = {}
    for sn in string.gmatch(text, "[^%.!%?]+[%.!%?]*") do
        table.insert(sentences, sn)
    end
    for k = 1, #sentences - 1 do
        local named = names_in(sentences[k], true)
        local nxt = sentences[k + 1]
        local first = string.match(nxt, "^%s*\"?([%a']+)")
        if #named == 1 and (first == "They" or first == "Their" or first == "They're" or first == "They've") and #names_in(nxt) == 0 then
            local group = false
            for w in string.gmatch(string.lower(sentences[k]), "[%a']+") do
                for _, g in ipairs(GROUP) do
                    group = group or w == g
                end
            end
            if not group and not string.find(sentences[k], "\"", 1, true) then
                table.insert(hits, { named[1], sentences[k] .. nxt })
            end
        end
    end
    return hits
end
do
    local seen = {}
    local n = 0
    for _, t in ipairs(W.texts) do
        local text = t.text
        if type(text) == "string" then
            if string.find(text, "{%a+_[%a']+}") then
                fail("D6", t.where .. ": an unfilled pronoun in '" .. text .. "'")
            end
            n = n + 1
            for _, hit in ipairs(pron_hits(text)) do
                if not seen[hit[2]] then
                    seen[hit[2]] = true
                    add("D6", "single_they_" .. (util.contains(HEROES, hit[1]) and "heroes" or util.contains(FRIENDS, hit[1]) and "friends" or "people"))
                    fail("D6", t.where .. ": " .. hit[1] .. " called they: '" .. text .. "'")
                    if os.getenv("D6_ALL") then
                        print("D6HIT", hit[1], text)
                    end
                end
            end
        end
    end
    set("D6", "lines_read", n)
end
case("D6", function()
    local cases = {
        { "{actor_char} cracks {actor_their} knuckles.", { actor_char = "Pip" }, "Pip cracks her knuckles." },
        { "{Actor_they} comes out cut.", { actor_char = "Brannoc" }, "He comes out cut." },
        { "{char} lowers {char_their} weapon.", { char = "Thessaly" }, "Thessaly lowers her weapon." },
        { "near {target_them}.", { target_char = "Oswin" }, "near him." },
        { "{new} rubs {new_their} wrists.", { new = "Bryn" }, "Bryn rubs her wrists." },
        { "before {actor_they've} left.", { actor_char = "Oswin" }, "before he's left." },
        { "{actor_char} and {actor_their} pack.", { actor_char = "a stranger" }, "a stranger and their pack." },
        -- (The friends at the table, and the museum's people: theirs too.)
        { "{name} goes quiet. {Name_they} asked you about this.", { name = "Mara" }, "Mara goes quiet. She asked you about this." },
        { "{actor} stands on {friend_their} chair.", { actor = "Dev", actor_char = "Bryn" }, "Dev stands on his chair." },
        { "{names} want another look. {Names_they're} sure.", { names = "Jess and Sam" }, "Jess and Sam want another look. They're sure." },
        { "{names} wants another look. {Names_they're} sure.", { names = "Jess" }, "Jess wants another look. She's sure." },
        { "{who} clears {who_their} throat.", { who = "Telpur" }, "Telpur clears his throat." },
        { "{who} lowers {who_their} bow.", { who = "Euryale" }, "Euryale lowers her bow." },
        { "{Who} clears {who_their} throat.", { Who = "The Lecturer", who = "the Lecturer" }, "The Lecturer clears his throat." },
        { "{who} sniffs {who_their} way round.", { who = "Exhibit B" }, "Exhibit B sniffs his way round." },
        { "{who} tips {who_their} hat.", { who = "Flitwidget" }, "Flitwidget tips his hat." },
    }
    for _, cs in ipairs(cases) do
        local got = util.fill(cs[1], cs[2])
        if got ~= cs[3] then
            fail("D6", "fill: '" .. cs[1] .. "' gave '" .. got .. "', not '" .. cs[3] .. "'")
        else
            add("D6", "fill_cases")
        end
    end
    -- Every hero and every new character has their own.
    local players = require "game.data.players"
    for _, key in ipairs(players.order) do
        if not util.PRONOUNS[players[key].pronouns or ""] then
            fail("D6", players[key].char .. " has no pronouns")
        end
    end
    for _, list in pairs(require("game.data.death").PREGENS) do
        for _, g in ipairs(list) do
            if not util.PRONOUNS[g.pronouns or ""] then
                fail("D6", g.name .. " has no pronouns")
            end
        end
    end
    -- The Dialogue Desk still exports.
    local out = os.tmpname()
    local fh = io.popen("lua tools/dialogue/export.lua " .. out .. " 2>&1")
    local said = fh:read("*a")
    fh:close()
    os.remove(out)
    if not string.find(said, "dialogue export:", 1, true) then
        fail("D6", "the Dialogue Desk export didn't run: " .. string.sub(said, 1, 200))
    else
        add("D6", "dialogue_desk_exports")
    end
end)

-- EB: Exhibit B on the table, and R5's board: one smoke run with DUMP_DIR -------------------------------
case("EB", function()
    local function smoke_into(dir, seed)
        os.execute("rm -rf " .. dir .. " && mkdir -p " .. dir)
        local fh = io.popen("DUMP_DIR=" .. dir .. " lua tools/tests/museum_smoke.lua " .. seed .. " 2>&1")
        local said = fh:read("*a")
        fh:close()
        if not string.find(said, "museum smoke " .. seed .. ":", 1, true) then
            fail("EB", "the smoke run didn't finish: " .. string.sub(said, -300))
        end
    end
    local function read_in(dir, name)
        local f = io.open(dir .. "/" .. name)
        if not f then
            return nil
        end
        local s = f:read("*a")
        f:close()
        return s
    end
    -- Seed 1's screens for D6 and R5; for Exhibit B, the first of a few seeds whose Pip takes him
    -- along (seed 1 did until the third playtest's screen fixes changed how its first report plays:
    -- the tip no longer sits on its Level up button, so the party levels up a week sooner).
    local dir = os.tmpname()
    os.remove(dir)
    smoke_into(dir, 1)
    local ebdir, seed = dir, 1
    if not string.find(read_in(dir, "board_minis.txt") or "", "exhibit_b", 1, true) then
        ebdir = dir .. "_eb"
        for _, s in ipairs({ 2, 3, 4 }) do
            smoke_into(ebdir, s)
            seed = s
            if string.find(read_in(ebdir, "board_minis.txt") or "", "exhibit_b", 1, true) then
                break
            end
        end
    end
    set("EB", "seed", seed)
    -- On the board: his mini at Pip's square, his owner's.
    local minis = read_in(ebdir, "board_minis.txt") or ""
    local beside, apart = 0, 0
    for line in string.gmatch(minis, "[^\n]+") do
        local jx, jy = string.match(line, "jess:[%w_]+@(%d+),(%d+)")
        local ex, ey = string.match(line, "exhibit_b:exhibit_b@(%d+),(%d+)%^jess")
        if ex then
            if ex == jx and ey == jy then
                beside = beside + 1
            else
                apart = apart + 1
            end
        end
    end
    set("EB", "boards_with_exhibit_b", beside)
    if beside == 0 then
        fail("EB", "Exhibit B came along, and he's never on the board beside Pip")
    end
    if apart > 0 then
        fail("EB", apart .. " boards with Exhibit B somewhere other than Pip's square")
    end
    -- On Pip's tile: his picture, not the paw.
    local pics = 0
    local p = io.popen("ls " .. ebdir)
    for name in p:lines() do
        if string.find(read_in(ebdir, name) or "", "mini_exhibit_b", 1, true) then
            pics = pics + 1
        end
    end
    p:close()
    p = io.popen("ls " .. dir)
    for name in p:lines() do
        local s = read_in(dir, name) or ""
        -- D6 on screen: no one person called "they" in what the screens say.
        for line in string.gmatch(s, "[^\n]+") do
            local text = string.match(line, "^text\t.*\t([^\t]*)$")
            if text and #text > 0 then
                text = string.gsub(text, "\\n", " ")
                add("D6", "screen_lines_read")
                for _, hit in ipairs(pron_hits(text)) do
                    fail("D6", name .. ": " .. hit[1] .. " called they on screen: '" .. text .. "'")
                end
            end
        end
        -- R5: the showdown board says what letting her go costs.
        if string.find(name, "showdown", 1, true) then
            if string.find(s, "IF SHE GETS AWAY", 1, true) and string.find(s, "half the reward", 1, true) then
                add("R5", "boss_boards_with_the_cost")
            else
                fail("R5", "the showdown board (" .. name .. ") doesn't say what an escape costs")
            end
        end
    end
    p:close()
    set("EB", "screens_with_his_picture", pics)
    if pics == 0 then
        fail("EB", "Pip's tile never shows Exhibit B's picture")
    end
    os.execute("rm -rf " .. dir .. " " .. dir .. "_eb")
end)

-- LEFT: wave 1's leftovers ----------------------------------------------------------------------------
case("LEFT", function()
    -- Said at every first fight, three ways each.
    for _, id in ipairs({ "daggers", "vorpal_sword", "bracelet", "know" }) do
        local it
        for _, x in ipairs(adventure.data.items) do
            if x.id == id then
                it = x
            end
        end
        if not (it and it.lines and #it.lines >= 3) then
            fail("LEFT", id .. ": said at every first fight, " .. (it and it.lines and #it.lines or 1) .. " way(s)")
        else
            add("LEFT", "item_lines_three_ways")
        end
    end
    for _, k in ipairs({ "grumble", "go_on", "own_way" }) do
        if not (mn.WEEKLY[k] and #mn.WEEKLY[k] >= 3) then
            fail("LEFT", "WEEKLY." .. k .. ": fewer than three ways")
        else
            add("LEFT", "table_lines_three_ways")
        end
    end
    local varied = 0
    for _, heads in pairs(W.item_lines) do
        local n = 0
        for _ in pairs(heads) do
            n = n + 1
        end
        if n >= 2 then
            varied = varied + 1
        end
    end
    set("LEFT", "item_lines_heard_more_than_one_way", varied)
    if varied == 0 then
        fail("LEFT", "no item line was ever heard two ways in the prologues")
    end
end)
-- The chat's promised statue is said where they wake, before they walk back up.
case("LEFT", function()
    adventure.enter()
    local c = campaign_mod.new(12)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        adventure.set_hook(c, key, adventure.data.hooks[key][1].id)
    end
    c:start_week()
    -- (A later week: they stopped in the Hunting Grounds, and the chat promised a rest, with a statue.)
    local st = c.adv
    st.weeks, c.week = 2, 2
    st.flags.rested = true
    st.answered.long_rest = "danger"
    st.pos, st.last_room = "hunting", "hunting"
    local night = c:start_night()
    local line
    local ev = night:advance()
    local guard = 0
    while ev.kind ~= "done" and guard < 300 and not line do
        guard = guard + 1
        if ev.text and string.find(ev.text, "As promised in the group chat", 1, true) then
            line = ev.text
        end
        local answer
        if ev.kind == "decision" then
            answer = 1
        elseif ev.kind == "roll" then
            answer = 10
        elseif ev.kind == "ruling" then
            answer = 1
        elseif ev.kind == "roll_where" then
            answer = "open"
        elseif ev.kind == "improv" then
            answer = { 1 }
        end
        ev = night:advance(answer)
    end
    if not line then
        fail("LEFT", "the promised rest was never said")
        return
    end
    local s = string.find(line, "a statue that wasn't there last night", 1, true)
    local w = string.find(line, "walk back up to", 1, true)
    if not (s and w and s < w) then
        fail("LEFT", "the statue isn't said before they walk back up: '" .. line .. "'")
    else
        add("LEFT", "statue_before_the_walk")
    end
end)
-- hand_off never offers a find to a hero who's away.
case("LEFT", function()
    local c, night = first_night(13)
    night.scene = { index = 1, split = { away = { jess = true } } }
    local finder = c:player("mara")
    night.actor = finder
    local who = run_beats(function()
        return mn.hand_off(night, "twin_daggers", finder)
    end)
    if who and who.key == "jess" then
        fail("LEFT", "the twin daggers were handed to Pip, who's off on her own")
    else
        add("LEFT", "hand_off_to_someone_here")
    end
end)

-- DET: the same seed plays the same way every run ------------------------------------------------------
case("DET", function()
    -- (Two favours due the same week are asked in the same order every run: the order was pairs().)
    local c = first_night(21)
    -- (Goodwill is read from the event log now: events.lua, R7.)
    local events = require "game.model.events"
    for _, who in ipairs({ "telpur", "flitwidget" }) do
        events.add(c, { kind = "help", who = "party", whom = "mus_" .. who, n = 3, favor = true,
                        seen = { ["mus_" .. who] = true } })
    end
    c.adv.favor_done = {}
    local ids = {}
    for _, pr in ipairs(adventure.prompts(c)) do
        if pr.kind == "favor" then
            table.insert(ids, pr.id)
        end
    end
    if table.concat(ids, ",") ~= "flitwidget,telpur" then
        fail("DET", "two favours came in the order " .. table.concat(ids, ","))
    else
        add("DET", "favours_in_order")
    end
    -- (Whole runs: the same seed and DM, three times over, the same log.)
    for _, run in ipairs({ { 7, "careful" }, { 14, "random" }, { 16, "careful" } }) do
        local first
        for i = 1, 3 do
            local fh = io.popen("lua tools/sim/museum.lua " .. run[1] .. " " .. run[2] .. " log 2>&1")
            local out = fh:read("*a")
            fh:close()
            if i == 1 then
                first = out
            elseif out ~= first then
                fail("DET", "seed " .. run[1] .. " " .. run[2] .. ": run " .. i .. " heard something different from run 1")
                break
            end
        end
        add("DET", "logs_compared", 3)
    end
end)

-- The report -----------------------------------------------------------------------------------------

local total = 0
for _, item in ipairs(ITEMS) do
    if not E[item] and not fails[item] then
        fail(item, "nothing seen: no run or case reached this item")
    end
    local parts = {}
    for k, v in pairs(E[item] or {}) do
        table.insert(parts, k .. " " .. tostring(v))
    end
    table.sort(parts)
    local f = fails[item]
    print(string.format("%-4s %-34s %s%s", item, NAMES[item], #parts > 0 and table.concat(parts, ", ") or "(nothing seen)",
        f and ("  FAILS " .. f.n) or ""))
    for _, m in ipairs(f or {}) do
        print("     FAIL " .. m)
    end
    total = total + (f and f.n or 0)
end
-- Per card, for the report: how often each card's commonest pick won.
local ids = {}
for id in pairs(W.picks) do
    table.insert(ids, id)
end
table.sort(ids)
for _, id in ipairs(ids) do
    local r = W.picks[id]
    local top, best = 0, ""
    for k, n in pairs(r.by) do
        if n > top or (n == top and k < best) then
            top, best = n, k
        end
    end
    print(string.format("       %-18s %3d picks, commonest %3.0f%%: %s", id, r.n, 100 * top / r.n, best))
end
print(total == 0 and "roadmap table check: every item holds" or ("roadmap table check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
