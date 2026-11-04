-- Wave 2's world items, played (the roadmap's R7, R11, R12, R13, R14, at museum scale): whole prologues
-- headless over several seeds and three kinds of DM, each item seen in play, plus targeted cases for
-- the moments a run can't be counted on to reach (a theft that goes wrong, Telpur's prices after it, the
-- Lecturer's report, Flitwidget counting the breakages). Run from the project root:
--     lua tools/tests/roadmap_world_check.lua [runs per style]
-- Prints one line per item: what was seen, and FAIL lines where play contradicts it; then the
-- "therefore or but" baseline (R14): per session, the share of beats linked by so or but, the longest
-- run of unlinked beats, and the rooms and moments that most often start one.

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local util = require "game.model.util"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"

local RUNS = tonumber(arg[1]) or 3
local STYLES = { "careful", "random", "careless" }
local ITEMS = { "run", "R7", "R11", "R12", "R13", "R14" }
local NAMES = { run = "whole prologues", R7 = "one event log, the source of truth", R11 = "people who remember",
                R12 = "the friends' own ideas", R13 = "the pickpocket slice", R14 = "therefore or but" }

local fails = {}
local function fail(item, msg)
    fails[item] = fails[item] or { n = 0 }
    if #fails[item] < 6 then
        table.insert(fails[item], msg)
    end
    fails[item].n = fails[item].n + 1
end
local E = {}
local function add(item, key, n)
    E[item] = E[item] or {}
    E[item][key] = (E[item][key] or 0) + (n or 1)
end
local function case(item, fn)
    local ok, err = pcall(fn)
    if not ok then
        fail(item, "error: " .. tostring(err))
    end
end

local function new_campaign(seed, style)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    local rng = require("game.model.rng").new(seed * 11 + #(style or ""))
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        local hooks = adventure.data.hooks[key]
        adventure.set_hook(c, key, hooks[rng:int(1, #hooks)].id)
    end
    return c, rng
end

-- R14: what a session's chain claims, against what really caused what. A link word ("so", "but") sits
-- right after the clause it follows from ("Pip emptied the donation box. So word reached Euryale that
-- they were thieves. So they fought the Sentinel" read as the word bringing the Sentinel down, when the
-- robbery did); a fight follows only from a choice to fight (or to walk into it knowingly), a roll that
-- turned into one, or the talk that ended her part and not her collection's, never from her card, word
-- passed on, a thing changing hands, a find or a room walked into (a room's own fight starts its own
-- sentence); her ending follows from the card that settled it, not the fight with her collection after
-- it; the archivist's notebook comes from the way into the second study, not a voice in the dark.
local FIGHT_FROM = { moment = true, setback = true }
local function card_by_id(id)
    for _, m in ipairs(adventure.data.moments) do
        if m.id == id then
            return m
        end
    end
    for _, k in ipairs({ "drink", "talk", "yield" }) do
        local sd = adventure.data.showdown[k]
        if sd and sd.id == id then
            return sd
        end
    end
end
-- What the option a moment's event names did (its own mus, and its roll's outcome): a set of keys.
local function did(ev, outcome)
    local card = ev.card and card_by_id(ev.card)
    local o = card and ev.opt and card.options[ev.opt]
    local out = {}
    if not o then
        return out
    end
    local lists = { o.mus }
    if o.roll then
        table.insert(lists, (outcome or ev.rolled) == "ok" and o.roll.success and o.roll.success.mus
            or (outcome or ev.rolled) == "fail" and o.roll.fail and o.roll.fail.mus or nil)
    end
    for _, m in ipairs(lists) do
        for k, v in pairs(m or {}) do
            out[k] = v
        end
    end
    return out
end
-- The link word each beat was told with, read off the sentences themselves (", so " or "So " right
-- before its clause), so the check doesn't take the chain's word for it.
local function told_words(lines, used)
    local text = " " .. string.lower(table.concat(lines, " "))
    local pos, words = 1, {}
    for i, b in ipairs(used) do
        local s, e = string.find(text, string.lower(b.text or ""), pos, true)
        local w = false
        if s then
            local before = string.sub(text, math.max(1, s - 6), s - 1)
            w = (string.match(before, "[ ,]so $") and "so") or (string.match(before, "[ ,]but $") and "but") or false
            pos = e + 1
        end
        words[i] = w
    end
    return words
end
local function false_causes(c, session)
    local events = require "game.model.events"
    local out = {}
    local lines, used = events.chain(c, session)
    local words = told_words(lines, used)
    for i, b in ipairs(used) do
        if words[i] and (i == 1 or used[i - 1].id ~= b.from) then
            table.insert(out, "the chain says '" .. words[i] .. " " .. tostring(b.text) .. "' after '" .. tostring(i > 1 and used[i - 1].text)
                .. "', and it follows from '" .. tostring((events.get(c, b.from) or {}).text) .. "'")
        end
    end
    for _, e in ipairs(events.find(c, { session = session })) do
        local f = e.from and events.get(c, e.from)
        if e.kind == "fight" and f then
            local m = (f.kind == "setback") and did(events.get(c, f.from) or {}, "fail") or did(f)
            if not FIGHT_FROM[f.kind] then
                table.insert(out, "a fight ('" .. tostring(e.text) .. "') follows from a " .. f.kind .. " ('" .. tostring(f.text) .. "')")
            elseif not (m.fight or m.ready or (m.ending and e.how == "but")) then
                table.insert(out, "a fight ('" .. tostring(e.text) .. "') follows from a card that didn't start one ('" .. tostring(f.text) .. "')")
            end
        elseif e.kind == "ending" then
            local settled
            for _, mv in ipairs(events.find(c, { kind = "moment", session = session, where = "lair" })) do
                if did(mv).ending == e.thing then
                    settled = mv
                end
            end
            if settled and e.from ~= settled.id then
                table.insert(out, "'" .. tostring(e.text) .. "' follows from '" .. tostring(f and f.text) .. "', not the card that settled it ('"
                    .. tostring(settled.text) .. "')")
            elseif not settled and f and f.kind ~= "fight" then
                table.insert(out, "'" .. tostring(e.text) .. "' follows from a " .. f.kind .. ", not the fight that ended it")
            end
        elseif e.kind == "get" and e.thing == "notebook" and f and f.kind ~= "fight" then
            local m = (f.kind == "moment" or f.kind == "setback") and (f.flag == "door_open" or f.flag2 == "door_open")
            if not m then
                table.insert(out, "the notebook ('" .. tostring(e.text) .. "') follows from '" .. tostring(f.text) .. "', not the way in")
            end
        end
    end
    return out
end

-- The R14 baseline, over every session of every run.
local B = { sessions = 0, beats = 0, linked = 0, longest = 0, over_two = 0, starts = {}, shares = {} }

-- Whole prologues ---------------------------------------------------------------------------------

local function play(seed, style)
    local events = require "game.model.events"
    local people = require "game.model.people"
    local items = require "game.model.items"
    local c, rng = new_campaign(seed, style)
    local tag = "seed " .. seed .. " " .. style
    for w = 1, adventure.data.MAX_WEEKS do
        local prep = c:start_week()
        for _, m in ipairs(c.chat or {}) do
            if m.ask and not m.answered then
                museum_week.answer_chat(c, m, style == "careful" and 1 or rng:int(1, 3))
            end
        end
        for _, pr in ipairs(c.adv.prompts) do
            if pr.kind == "request" then
                adventure.answer_request(c, pr.id, adventure.data.ANSWERS[style == "careful" and 2 or rng:int(1, 4)])
            elseif pr.kind == "loose" then
                adventure.answer_loose(c, pr.id, 1)
            elseif pr.kind == "ruling" then
                adventure.answer_ruling(c, pr.id, style ~= "careless")
            elseif pr.kind == "favor" then
                adventure.answer_favor(c, pr.id, 1, 1)
            end
        end
        if style ~= "careless" then
            museum_week.prep_greedy(prep)
        end
        if prep.museum.boss then
            c.adv.boss = { opener = rng:chance(0.7) and "talk" or "ambush", style = rng:chance(0.6) and "yields" or "last" }
        end
        local night = c:start_night()
        local ev = night:advance()
        local guard = 0
        local cards_left_at_take = {}
        while ev.kind ~= "done" and guard < 5000 do
            guard = guard + 1
            local answer
            -- R12: the friends' ideas come from heroes in the scene, never in a fight or the lair.
            if ev.kind == "decision" and string.find(ev.card.id or "", "^idea_take_") then
                add("R12", "idea_cards")
                if night.battle and not night.battle.over then
                    fail("R12", tag .. " week " .. w .. ": a friend's idea came up mid-fight")
                end
                if night.scene and (night.scene.boss or night.scene.showdown) then
                    fail("R12", tag .. " week " .. w .. ": a friend's idea came up in the lair")
                end
            end
            if ev.kind == "decision" then
                local opts = ev.card.options
                local pick = (style == "careful") and 1 or rng:int(1, #opts)
                if opts[pick].disabled then
                    pick = 1
                end
                answer = pick
            elseif ev.kind == "thought" then
                require("game.model.thoughts").bot_play(night, ev, style, rng)
            elseif ev.kind == "ruling" then
                answer = 1
            elseif ev.kind == "improv" then
                answer = { 1 }
            elseif ev.kind == "roll_where" then
                answer = "open"
            elseif ev.kind == "roll" then
                answer = rng:d20()
            end
            ev = night:advance(answer)
        end
        if guard >= 5000 then
            fail("run", tag .. ": a night never ended")
        end
        local rep = c:finish_night()
        -- R7: the log against the packs, her card and the fights.
        for _, e in ipairs(events.find(c, { session = c.week })) do
            add("R7", "events")
            if e.kind == "get" then
                add("R7", "things_changing_hands")
                local held = false
                for _, it in ipairs(items.list(c)) do
                    held = held or it == e.entry
                end
                if not held then
                    fail("R7", tag .. " week " .. w .. ": the log has " .. tostring(e.thing) .. " changing hands, and no pack has it")
                end
            elseif e.kind == "mark" then
                add("R7", "marks_in_the_log")
            elseif e.kind == "fight" then
                add("R7", "fights_in_the_log")
            end
        end
        for _, it in ipairs(items.list(c)) do
            if it.week == c.week and it.from ~= "start" and not events.any(c, { kind = "get", entry = it }) then
                fail("R7", tag .. " week " .. w .. ": " .. tostring(it.thing or it.id) .. " is in " .. tostring(it.holder) .. "'s pack, and the log never says how")
            end
        end
        for _, id in ipairs(c.adv.mark_list) do
            if not events.any(c, { kind = "mark", thing = id }) then
                fail("R7", tag .. " week " .. w .. ": mark " .. id .. " is on her card and not in the log")
            end
        end
        for _, sc in ipairs(night.scenes or {}) do
            if sc.result then
                local fe = sc.fight_ev and events.get(c, sc.fight_ev)
                if not fe or (fe.outcome == "won") ~= (sc.result.winner == "party") then
                    fail("R7", tag .. " week " .. w .. ": the fight in " .. tostring(sc.room) .. " and the log disagree")
                else
                    add("R7", "fights_that_agree")
                end
            end
        end
        -- (The recap's "fought" clause and the journey's fights come from the log.)
        for _, step in ipairs(c.adv.path) do
            if step.week == c.week then
                local fought = events.any(c, { kind = "fight", where = step.room, session = step.week })
                local rc = adventure.data.recap[step.room]
                if rc and rc.fought then
                    local clause = adventure.recap_clause(c, step)
                    local said_fought = clause == rc.fought.win or clause == rc.fought.lose
                    if said_fought ~= fought then
                        fail("R7", tag .. " week " .. w .. ": the recap of " .. step.room .. " says '" .. tostring(clause) .. "', and the log " .. (fought and "has" or "has no") .. " fight")
                    else
                        add("R7", "recap_clauses_from_the_log")
                    end
                end
            end
        end
        -- R11 and R13: every theft in the log, and what came of it.
        for _, e in ipairs(events.find(c, { kind = "steal", session = c.week })) do
            add("R13", "thefts_" .. e.outcome)
            if e.outcome == "got" then
                local has = false
                for _, it in ipairs(items.list(c)) do
                    has = has or ((it.thing == e.thing or it.id == e.thing) and it.holder == e.who)
                end
                if not has then
                    fail("R13", tag .. " week " .. w .. ": '" .. e.text .. "', and it isn't in their pack")
                end
                if next(e.seen or {}) ~= nil then
                    fail("R13", tag .. " week " .. w .. ": a theft that worked had a witness")
                end
            else
                if not (e.seen and e.seen[e.whom]) then
                    fail("R13", tag .. " week " .. w .. ": a theft caught, and the one robbed didn't see it")
                end
                if people.RANK[people.level(c, e.whom, e.who)] >= 0 then
                    fail("R11", tag .. " week " .. w .. ": " .. e.whom .. " caught " .. e.who .. " stealing, and doesn't mind")
                else
                    add("R11", "grudges_after_a_caught_theft")
                end
            end
        end
        for _, kind in ipairs({ "price", "refuse", "tell", "docked", "notice", "help", "says" }) do
            local n = events.count(c, { kind = kind, session = c.week })
            if n > 0 then
                add("R11", kind .. "_events", n)
            end
        end
        -- R12: what the friends reached for on their own.
        for _, e in ipairs(events.find(c, { kind = "idea", session = c.week })) do
            add("R12", "ideas_" .. e.verb)
            local p = c:player(e.who)
            if not (p and util.contains(night.players, p)) then
                fail("R12", tag .. " week " .. w .. ": an idea from someone who isn't at the table")
            end
        end
        -- R14: the report tells the night as the log's chain, and no beat is stitched on with "and then".
        local chain = (rep.museum or {}).chain or {}
        local want = events.chain(c, c.week)
        if #chain ~= #want then
            fail("R14", tag .. " week " .. w .. ": the report's chain isn't the log's")
        end
        for _, line in ipairs(chain) do
            if string.find(string.lower(line), "and then", 1, true) then
                fail("R14", tag .. " week " .. w .. ": 'and then' in the chain: " .. line)
            end
        end
        local _, used = events.chain(c, c.week)
        local shown = {}
        for _, b in ipairs(used) do
            if b.from and shown[b.from] and not events.linked(b) then
                fail("R14", tag .. " week " .. w .. ": a beat joined to the one before it with no link")
            end
            shown[b.id] = true
        end
        -- R14: the chain claims only real causes (false_causes, below).
        for _, msg in ipairs(false_causes(c, c.week)) do
            fail("R14", tag .. " week " .. w .. ": " .. msg)
        end
        add("R14", "sessions_checked_for_false_causes")
        local m = events.measure(c, c.week)
        if m.beats > 0 then
            add("R14", "sessions_measured")
            B.sessions, B.beats, B.linked = B.sessions + 1, B.beats + m.beats, B.linked + m.linked
            B.longest = math.max(B.longest, m.longest)
            B.over_two = B.over_two + (m.longest > 2 and 1 or 0)
            table.insert(B.shares, m.share)
            for _, s in ipairs(m.starts) do
                local k = tostring(s.where) .. " / " .. tostring(s.card or s.kind)
                B.starts[k] = (B.starts[k] or 0) + 1
            end
        end
        if adventure.over(c) then
            break
        end
        c:level_up()
    end
    -- R11: what each of the museum's people thinks at the end, read from the log.
    for _, id in ipairs(people.all()) do
        local _, lv = people.opinion(c, id)
        add("R11", id .. "_" .. lv)
    end
    -- R7: the log saves and loads with the campaign.
    local save = require "game.model.save"
    local back = save.load(save.dump(c))
    if not back or #events.list(back) ~= #events.list(c) then
        fail("R7", tag .. ": the log didn't come back from a save")
    else
        add("R7", "logs_saved_and_loaded")
    end
end

for _, style in ipairs(STYLES) do
    for run = 1, RUNS do
        local seed = 700 + run * 37
        local ok, err = pcall(play, seed, style)
        if not ok then
            fail("run", "seed " .. seed .. " " .. style .. ": " .. tostring(err))
        else
            add("run", "prologues")
        end
    end
end

-- Targeted cases -----------------------------------------------------------------------------------

-- A night stopped at its first room, the street (Flitwidget there), with a driver that answers what
-- comes up: decisions by `pick` (a function of the card), rolls by `die`.
local function first_room(seed)
    local c, rng = new_campaign(seed, "random")
    c:start_week()
    local night = c:start_night()
    local ev = night:advance()
    local guard = 0
    while ev.kind ~= "done" and not (ev.kind == "scene" and night.scene and night.scene.room) and guard < 2000 do
        guard = guard + 1
        local answer
        if ev.kind == "decision" then
            answer = 1
        elseif ev.kind == "ruling" then
            answer = 1
        elseif ev.kind == "improv" then
            answer = { 1 }
        elseif ev.kind == "roll_where" then
            answer = "open"
        elseif ev.kind == "roll" then
            answer = rng:d20()
        end
        ev = night:advance(answer)
    end
    -- (Played on a later night's terms: the first night keeps its optional calls for next week, R6,
    -- and a friend's idea there is settled by the dice. The R12 case below checks that.)
    night.first_gentle, night.gentle = night.gentle, nil
    return c, night, night.scene
end

local function drive(night, fn, pick, die)
    local out = {}
    local co = coroutine.create(fn)
    local answer
    while coroutine.status(co) ~= "dead" do
        local ok, e = coroutine.resume(co, answer)
        if not ok then
            error(e)
        end
        answer = nil
        if e then
            table.insert(out, e)
            if e.kind == "decision" then
                answer = pick and pick(e.card) or 1
            elseif e.kind == "roll_where" then
                answer = "open"
            elseif e.kind == "roll" then
                answer = die or 10
            elseif e.kind == "ruling" then
                answer = 1
            end
        end
    end
    return out
end

local function said(out, pat)
    for _, e in ipairs(out) do
        if e.text and string.find(e.text, pat) then
            return e
        end
    end
    return nil
end

-- R13: Pip lifts Flitwidget's draught; you let it work. It's in her pack, the log says so, and nobody saw.
case("R13", function()
    local events = require "game.model.events"
    local ideas = require "game.model.ideas"
    local items = require "game.model.items"
    local people = require "game.model.people"
    local c, night, sc = first_room(61)
    local pip = c:player("jess")
    local flit = require("game.model.npcs").get("mus_flitwidget")
    local pk = ideas.pockets(night, flit)[1]
    if not pk then
        fail("R13", "case: Flitwidget has nothing in his pockets")
        return
    end
    local before = items.count(c, "jess", items.POTION)
    local out = drive(night, function()
        ideas.take(night, sc, { p = pip, target = pk })
    end, function(card)
        return 1
    end)
    local card = nil
    for _, e in ipairs(out) do
        card = card or (e.kind == "decision" and e.card.title == "Light fingers" and e.card)
    end
    if not card or #card.options ~= 3 then
        fail("R13", "case: no 'Light fingers' card with allow, roll and no")
    end
    if not (out[2] and out[2].kind == "say" and out[2].who == "jess") then
        fail("R13", "case: Jess doesn't say what Pip's about to do, out loud, before the card")
    end
    if items.count(c, "jess", items.POTION) ~= before + 1 then
        fail("R13", "case: allowed, and the draught isn't in Pip's pack")
    end
    local st = events.last(c, { kind = "steal" })
    if not st or st.outcome ~= "got" or next(st.seen) ~= nil or not st.beat then
        fail("R13", "case: allowed, and the log doesn't have a clean theft in it")
    end
    if people.level(c, "mus_flitwidget", "jess") ~= people.level(c, "mus_flitwidget") or people.RANK[people.level(c, "mus_flitwidget", "jess")] < 0 then
        fail("R13", "case: a theft nobody saw changed what Flitwidget thinks")
    end
    add("R13", "case_allowed")
end)

-- R13 and R11: a roll that misses. Flitwidget sees it, says so, thinks less of Pip, and won't answer her
-- question afterwards. Nothing changes hands.
case("R13", function()
    local events = require "game.model.events"
    local ideas = require "game.model.ideas"
    local items = require "game.model.items"
    local people = require "game.model.people"
    local tl = require "game.model.table_life"
    local c, night, sc = first_room(62)
    local pip = c:player("jess")
    local flit = require("game.model.npcs").get("mus_flitwidget")
    local pk = ideas.pockets(night, flit)[1]
    local before = items.count(c, "jess", items.POTION)
    local out = drive(night, function()
        ideas.take(night, sc, { p = pip, target = pk })
    end, function(card)
        return card.title == "Light fingers" and 2 or 1
    end, 1)
    local st = events.last(c, { kind = "steal" })
    if not st or st.outcome ~= "caught" or not st.seen.mus_flitwidget then
        fail("R13", "case: a missed roll, and the log has no theft that Flitwidget saw")
    end
    if items.count(c, "jess", items.POTION) ~= before then
        fail("R13", "case: caught, and Pip still came away with it")
    end
    local line = false
    for _, e in ipairs(out) do
        line = line or (e.kind == "npc" and e.cast == "mus_flitwidget")
    end
    if not line then
        fail("R13", "case: caught, and Flitwidget says nothing")
    end
    if people.RANK[people.level(c, "mus_flitwidget", "jess")] >= 0 then
        fail("R11", "case: Flitwidget caught Pip at it and isn't any warier of her")
    end
    -- Later, he acts on it: her question gets a refusal, and the refusal is in the log, following from the theft.
    night.tl_people = { flitwidget = "Formicarius Flitwidget, the curator" }
    local q = tl.data_questions and nil
    for _, rq in ipairs(adventure.data.table_life.rooms.street.npc_questions) do
        q = q or rq
    end
    local out2 = drive(night, function()
        tl.ask_one(night, sc, q, nil, pip)
    end)
    local refused = events.last(c, { kind = "refuse" })
    if not refused or refused.from ~= st.id or refused.whom ~= "jess" then
        fail("R11", "case: the question after the theft wasn't refused, or the refusal doesn't follow from it")
    end
    if not said(out2, "pocket") and not said(out2, "draught") and not said(out2, "counting my pockets") then
        fail("R11", "case: Flitwidget's refusal doesn't say why, in his words")
    end
    add("R13", "case_caught")
    add("R11", "case_refusal")
end)

-- R13: you say no. Nothing taken, nothing in the log as a theft, and Jess takes it with a line.
case("R13", function()
    local events = require "game.model.events"
    local ideas = require "game.model.ideas"
    local c, night, sc = first_room(63)
    local pip = c:player("jess")
    local flit = require("game.model.npcs").get("mus_flitwidget")
    local pk = ideas.pockets(night, flit)[1]
    local out = drive(night, function()
        ideas.take(night, sc, { p = pip, target = pk })
    end, function(card)
        return card.title == "Light fingers" and 3 or 1
    end)
    if events.any(c, { kind = "steal" }) then
        fail("R13", "case: you said no, and there's a theft in the log")
    end
    local last = out[#out]
    if not (last and last.kind == "say" and last.who == "jess") then
        fail("R13", "case: you said no, and Jess doesn't take it with a word")
    end
    add("R13", "case_ruled_no")
end)

-- R12 and R13: with no call left in the night, it doesn't come to you: a small die decides, in the open.
case("R12", function()
    local ideas = require "game.model.ideas"
    local c, night, sc = first_room(64)
    local pip = c:player("jess")
    local flit = require("game.model.npcs").get("mus_flitwidget")
    local pk = ideas.pockets(night, flit)[1]
    night.counts.decision = 40
    local out = drive(night, function()
        ideas.take(night, sc, { p = pip, target = pk })
    end)
    local card, tiny = false, false
    for _, e in ipairs(out) do
        card = card or e.kind == "decision"
        tiny = tiny or e.kind == "tiny_roll"
    end
    if card or not tiny then
        fail("R12", "case: out of calls, and the idea still came to you as a card (or nothing was rolled)")
    end
    add("R12", "case_no_calls_left")
    -- (And on a gentle first night, R6: it's the dice's too.)
    local c2, night2, sc2 = first_room(72)
    night2.gentle = night2.first_gentle
    if night2.gentle then
        local pk2 = ideas.pockets(night2, require("game.model.npcs").get("mus_flitwidget"))[1]
        local out2 = drive(night2, function()
            ideas.take(night2, sc2, { p = c2:player("jess"), target = pk2 })
        end)
        for _, e in ipairs(out2) do
            if e.kind == "decision" then
                fail("R12", "case: on the gentle first night, a friend's idea came to you as a card")
            end
        end
        add("R12", "case_first_night_dice")
    end
end)

-- R12: what a friend reaches for is theirs: Pip, in the street her con brought her to, wants Flitwidget's
-- pockets most; hurt, she'd rather not; a hero who wandered off has no ideas here.
case("R12", function()
    local ideas = require "game.model.ideas"
    local c, night, sc = first_room(65)
    adventure.set_hook(c, "jess", "charlatan")
    local list = ideas.ideas(night, sc, "enter")
    local top
    for _, i in ipairs(list) do
        if i.verb == "take" and not top then
            top = i
        end
    end
    if not top or top.p.key ~= "jess" then
        fail("R12", "case: the friend keenest to lift something in the street isn't Pip")
    end
    local healthy = top and select(1, ideas.want(night, top.p, "take", top.target)) or 0
    require("game.model.fight").party(night)
    local pc = night.pcs and night.pcs.jess
    if pc then
        pc.hp = 1
    end
    local hurt = top and select(1, ideas.want(night, top.p, "take", top.target)) or 0
    if hurt >= healthy then
        fail("R12", "case: a hero on 1 hit point wants to pick a pocket as much as a healthy one")
    end
    sc.split = { away = { jess = true } }
    for _, i in ipairs(ideas.ideas(night, sc, "enter")) do
        if i.p.key == "jess" then
            fail("R12", "case: a hero who wandered off has ideas in the room she left")
            break
        end
    end
    sc.split = nil
    local verbs = {}
    for _, i in ipairs(list) do
        verbs[i.verb] = true
    end
    for _, v in ipairs({ "take", "help", "follow", "hide", "ask" }) do
        if not verbs[v] then
            fail("R12", "case: nobody in the street could " .. v .. " anything")
        end
    end
    -- (Never in a fight, the lair, or at 4x.)
    sc.showdown = true
    if ideas.room(night, sc, "enter") ~= 0 then
        fail("R12", "case: an idea played in the lair")
    end
    sc.showdown = nil
    night.fast = true
    if ideas.room(night, sc, "enter") ~= 0 then
        fail("R12", "case: an idea played at 4x")
    end
    add("R12", "case_scored")
end)

-- R11: caught at Telpur's shelf, the shop's prices go up a Franc on the shopping card, he says so, and
-- the log has the price rise following from the theft. A friend gets a Franc off instead.
case("R11", function()
    local events = require "game.model.events"
    local mn = require "game.model.museum_night"
    local c, night = first_room(66)
    local sc = mn.build_scene(night, "gift_shop")
    sc.index = #night.scenes + 1
    table.insert(night.scenes, sc)
    night.scene = sc
    c.adv.francs = 20
    local steal = events.add(c, { kind = "steal", who = "jess", whom = "mus_telpur", thing = "arrows_lifted", where = "gift_shop",
                                  outcome = "caught", seen = { mus_telpur = true }, beat = true, text = "Pip went for the arrows" })
    local card
    for _, m in ipairs(adventure.data.moments) do
        if m.id == "mus_shopping" then
            card = m
        end
    end
    local out = drive(night, function()
        mn.play_moment(night, card, sc)
    end, function(cd)
        return cd.id == "mus_shopping" and 1 or #cd.options
    end)
    local shop
    for _, e in ipairs(out) do
        if e.kind == "decision" and (e.card.id == "mus_shopping" or e.card.id == "table_asks_mus_shopping") then
            shop = shop or e.card
        end
    end
    local PRICE = adventure.data.PRICE
    local labels = {}
    for _, o in ipairs((shop or {}).options or {}) do
        table.insert(labels, o.label)
    end
    local all = table.concat(labels, " | ")
    if shop and shop.id == "mus_shopping" and not string.find(all, "(" .. (PRICE.tenets + 1) .. " Francs)", 1, true) then
        fail("R11", "case: caught at his shelf, and Telpur's prices didn't move: " .. all)
    end
    local up = events.last(c, { kind = "price" })
    if not up or up.n ~= 1 or up.from ~= steal.id then
        fail("R11", "case: the price rise isn't in the log, following from the theft")
    end
    local line = false
    for _, e in ipairs(out) do
        line = line or (e.kind == "npc" and e.cast == "mus_telpur" and (string.find(e.text, "Franc", 1, true) ~= nil))
    end
    if not line then
        fail("R11", "case: Telpur put his prices up without a word")
    end
    -- (What a purchase costs is what the card said.)
    local bought = events.last(c, { kind = "get", how_got = "bought" })
    if bought and c.adv.francs ~= 20 - (PRICE.tenets + 1) and c.adv.francs ~= 20 - (PRICE.manual + 1) and c.adv.francs ~= 20 - (PRICE.arrows + 1) then
        fail("R11", "case: the card's price and what left the pool differ (" .. c.adv.francs .. " Francs left)")
    end
    add("R11", "case_prices")
end)

-- R11: the Lecturer, still lecturing above the gift shop, hears a theft caught there and passes it on to
-- Euryale; the table hears it upstairs; on boss night her first words say what she heard. Silenced, he
-- passes on nothing.
case("R11", function()
    local events = require "game.model.events"
    local people = require "game.model.people"
    local mn = require "game.model.museum_night"
    local c, night = first_room(67)
    events.add(c, { kind = "steal", who = "jess", whom = "mus_telpur", thing = "arrows_lifted", where = "gift_shop",
                    outcome = "caught", seen = { mus_telpur = true }, beat = true, text = "Pip went for the arrows" })
    events.add(c, { kind = "steal", who = "jess", whom = "mus_telpur", thing = "arrows_lifted", where = "gift_shop",
                    outcome = "got", seen = {}, beat = true, text = "Pip lifted the arrows" })
    local out = drive(night, function()
        mn.lecturer_report(night)
    end)
    if not said(out, "^Upstairs, .*Lecturer") then
        fail("R11", "case: the Lecturer passed nothing on, out loud")
    end
    if not people.knows_of(c, "mus_euryale", "steal") then
        fail("R11", "case: Euryale wasn't told")
    end
    local quiet = events.find(c, { kind = "steal", outcome = "got" })[1]
    if quiet and events.knows(c, "mus_euryale", quiet) then
        fail("R11", "case: a theft nobody saw reached Euryale")
    end
    local line = people.line(night, "mus_euryale", "heard")
    if not line or not (string.find(line, "fingers", 1, true) or string.find(line, "helps themselves", 1, true) or string.find(line, "rob shops", 1, true)) then
        fail("R11", "case: on boss night Euryale doesn't say what the Lecturer told her: " .. tostring(line))
    end
    -- (Silenced: nothing more.)
    local c2, night2 = first_room(68)
    c2.adv.done.lecture = "win"
    events.add(c2, { kind = "break", who = "party", whom = "mus_flitwidget", thing = "his garden", where = "gift_shop" })
    drive(night2, function()
        mn.lecturer_report(night2)
    end)
    if people.knows_of(c2, "mus_euryale", "break") then
        fail("R11", "case: the Lecturer, silenced, still passed it on")
    end
    add("R11", "case_lecturer")
end)

-- R11: Flitwidget comes back to a museum with a burnt garden, and Telpur has a word about the shelf: he
-- sees it, he's told, his thanks says so, and the breakages come out of the reward. All in the log.
case("R11", function()
    local events = require "game.model.events"
    local people = require "game.model.people"
    local mn = require "game.model.museum_night"
    local c, night = first_room(69)
    events.add(c, { kind = "break", who = "dev", whom = "mus_flitwidget", thing = "his garden", where = "garden" })
    events.add(c, { kind = "steal", who = "jess", whom = "mus_telpur", thing = "arrows_lifted", where = "gift_shop",
                    outcome = "caught", seen = { mus_telpur = true }, beat = true, text = "Pip went for the arrows" })
    c.adv.gold = 30
    local sc = mn.build_scene(night, "thanks")
    night.scene = sc
    local out = drive(night, function()
        mn.thanks_word(night, sc)
    end)
    if not events.any(c, { kind = "notice", who = "mus_flitwidget" }) then
        fail("R11", "case: Flitwidget never saw his garden")
    end
    local t = events.last(c, { kind = "tell", who = "mus_telpur", whom = "mus_flitwidget" })
    if not t then
        fail("R11", "case: Telpur never had a word with Flitwidget")
    end
    local thanks = false
    for _, e in ipairs(out) do
        thanks = thanks or (e.kind == "npc" and e.cast == "mus_flitwidget" and string.find(e.text, "Telpur", 1, true) ~= nil)
    end
    if not thanks then
        fail("R11", "case: Flitwidget's thanks doesn't say what Telpur told him")
    end
    if (c.adv.gold or 30) >= 30 or not events.any(c, { kind = "docked" }) then
        fail("R11", "case: a wary Flitwidget paid in full")
    end
    -- (Exhibit B is Pip's, from the start.)
    if people.level(c, "exhibit_b", "jess") ~= "devoted" then
        fail("R11", "case: Exhibit B isn't devoted to Pip")
    end
    add("R11", "case_thanks")
end)

-- R7: the recap's fought clause and the win caption read the log, not their own copies.
case("R7", function()
    local events = require "game.model.events"
    local c = new_campaign(70, "careful")
    local step = { room = "paintings", week = 1, outcome = "win" }       -- (no `fought` of its own)
    c.week = 1
    events.add(c, { kind = "fight", who = "party", where = "paintings", session = 1, outcome = "won", foes = 1, ran = 0, boss = "the Knight of Shades" })
    if adventure.recap_clause(c, step) ~= adventure.data.recap.paintings.fought.win then
        fail("R7", "case: the recap's clause doesn't read the fight from the log")
    end
    local nolog = { room = "paintings", week = 2, outcome = "win", fought = true }
    if adventure.recap_clause(c, nolog) == adventure.data.recap.paintings.fought.win then
        fail("R7", "case: the recap says they fought when the log has no fight")
    end
    -- (A favor is a deed in the log, and the favors owed read it.)
    adventure.apply(c, { favor = { who = "telpur", n = 1 } }, "gift_shop", "sam")
    if adventure.favor(c, "telpur") ~= 1 or (c.adv.favors or {}).telpur then
        fail("R7", "case: a favor isn't kept in the log alone")
    end
    -- (A thing given is in the log with who has it now.)
    local items = require "game.model.items"
    local it = items.give(c, "notebook", "mara", "found")
    local g = events.last(c, { kind = "get", thing = "notebook" })
    if not g or g.entry ~= it or g.who ~= "mara" then
        fail("R7", "case: a thing changing hands isn't in the log")
    end
    add("R7", "case_reads_the_log")
end)

-- R14: the chain from a log built by hand: linked beats join with so and but, an unlinked one starts a
-- sentence of its own, and the measure counts them.
case("R14", function()
    local events = require "game.model.events"
    local c = new_campaign(71, "careful")
    c.week = 3
    local a = events.add(c, { kind = "moment", beat = true, text = "they set the bushes on fire", where = "garden" })
    local b = events.add(c, { kind = "mark", beat = true, text = "Euryale smelled the smoke", from = a })
    local d = events.add(c, { kind = "fight", beat = true, text = "the hedges came at them", from = a, how = "but" })
    local e = events.add(c, { kind = "enter", beat = true, text = "they went into the entrance hall", where = "entrance" })
    local f = events.add(c, { kind = "moment", beat = true, text = "they dropped a coin in", where = "entrance" })
    local lines = events.chain(c, 3)
    -- (The fight moves the story, so it's told right after its cause; her card follows on its own.)
    local want = { "They set the bushes on fire, but the hedges came at them.", "Euryale smelled the smoke.",
                   "They went into the entrance hall.", "They dropped a coin in." }
    for i, l in ipairs(want) do
        if lines[i] ~= l then
            fail("R14", "case: chain line " .. i .. " is '" .. tostring(lines[i]) .. "', not '" .. l .. "'")
        end
    end
    local m = events.measure(c, 3)
    if m.beats ~= 5 or m.linked ~= 2 or m.longest ~= 2 or #m.starts ~= 2 or m.starts[2].where ~= "entrance" then
        fail("R14", "case: the measure is wrong: " .. m.linked .. " of " .. m.beats .. ", longest " .. m.longest)
    end
    add("R14", "case_chain")
    -- The sample night: Pip goes for the donation box's lock and empties it, so word reaches Euryale and
    -- the Sentinel steps down. The fight follows from the robbery, and the chain says so right after it,
    -- never after the word reaching her.
    c.week = 4
    local lock = events.add(c, { kind = "moment", card = "mus_box", opt = 2, beat = true, text = "Pip went for the donation box's lock", where = "entrance" })
    local empt = events.add(c, { kind = "moment", card = "mus_box_lock", opt = 1, rolled = "ok", beat = true, text = "Pip emptied the donation box",
                                 where = "entrance", from = lock })
    events.add(c, { kind = "mark", beat = true, text = "word reached Euryale that they were thieves, like her", where = "entrance", from = empt })
    events.add(c, { kind = "fight", beat = true, text = "they fought the Sentinel, and they won", where = "entrance", from = empt })
    lines = events.chain(c, 4)
    want = { "Pip went for the donation box's lock, so Pip emptied the donation box.", "So they fought the Sentinel, and they won.",
             "Word reached Euryale that they were thieves, like her." }
    for i, l in ipairs(want) do
        if lines[i] ~= l then
            fail("R14", "case: the sample night's line " .. i .. " is '" .. tostring(lines[i]) .. "', not '" .. l .. "'")
        end
    end
    if #false_causes(c, 4) > 0 then
        fail("R14", "case: " .. false_causes(c, 4)[1])
    end
    -- A room's own fight, linked to walking in; a fight linked to word passed on; the notebook from a
    -- whisper; her ending from her collection's fight: each is a false cause.
    c.week = 5
    local into = events.add(c, { kind = "enter", beat = true, text = "they went into the garden", where = "garden" })
    events.add(c, { kind = "fight", beat = true, text = "the briar triceratops came at them", where = "garden", from = into, how = "but" })
    local told = events.add(c, { kind = "tell", beat = true, text = "the Lecturer told Euryale about Pip", where = "gift_shop" })
    events.add(c, { kind = "fight", beat = true, text = "they fought the Sentinel", where = "entrance", from = told })
    local wh = events.add(c, { kind = "moment", card = "mus_whispers", opt = 2, beat = true, text = "a voice whispered to Thessaly", where = "offices" })
    events.add(c, { kind = "get", thing = "notebook", beat = true, text = "Thessaly came away with the notebook", where = "offices", from = wh })
    local talk = adventure.data.showdown.talk
    local page_i
    for i, o in ipairs(talk.options) do
        if o.mus and o.mus.use == "pages" then
            page_i = i
        end
    end
    local slept = events.add(c, { kind = "moment", card = talk.id, opt = page_i, rolled = "ok", beat = true,
                                  text = "she read the Lecturer's notes and fell asleep", where = "lair" })
    local coll = events.add(c, { kind = "fight", beat = true, text = "the Knight of Shades came at them", where = "lair", from = slept, how = "but" })
    events.add(c, { kind = "ending", thing = "slept", beat = true, text = "Euryale slept", where = "lair", from = coll })
    local n = #false_causes(c, 5)
    if n ~= 4 then
        fail("R14", "case: " .. n .. " false causes found in a log built with four (a fight from walking in, one from word passed on, "
            .. "the notebook from a whisper, her ending from her collection's fight)")
    end
    add("R14", "case_false_causes")
end)

-- Report -----------------------------------------------------------------------------------------

local total = 0
for _, item in ipairs(ITEMS) do
    local parts = {}
    for k, v in pairs(E[item] or {}) do
        table.insert(parts, k .. " " .. v)
    end
    table.sort(parts)
    local f = fails[item]
    if not E[item] and not f then
        f = { n = 1, "nothing seen: no run or case reached this item" }
    end
    print(string.format("%-4s %-36s %s%s", item, NAMES[item], table.concat(parts, ", "), f and ("  FAILS " .. f.n) or ""))
    for _, msg in ipairs(f or {}) do
        print("     FAIL " .. msg)
    end
    total = total + (f and f.n or 0)
end
-- The R14 baseline.
if B.sessions > 0 then
    table.sort(B.shares)
    local under = 0
    for _, s in ipairs(B.shares) do
        under = under + (s < 0.8 and 1 or 0)
    end
    local worst = {}
    for k, n in pairs(B.starts) do
        table.insert(worst, { k = k, n = n })
    end
    table.sort(worst, function(x, y)
        if x.n ~= y.n then
            return x.n > y.n
        end
        return x.k < y.k
    end)
    local top = {}
    for i = 1, math.min(8, #worst) do
        table.insert(top, worst[i].k .. " " .. worst[i].n)
    end
    print(string.format("R14 baseline: %d sessions, %d of %d beats linked (%d%%; median session %d%%), %d sessions under 4 in 5, "
        .. "longest unlinked run %d (%d sessions over two)", B.sessions, B.linked, B.beats, math.floor(100 * B.linked / B.beats + 0.5),
        math.floor(100 * B.shares[math.ceil(#B.shares / 2)] + 0.5), under, B.longest, B.over_two))
    print("  where unlinked runs start most: " .. table.concat(top, ", "))
end
print(total == 0 and "roadmap world check: every item holds" or ("roadmap world check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
