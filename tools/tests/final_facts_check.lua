-- The final fix pass, F1: facts (the confirming playtest, four reviews of r3-int at bfa5157: truth,
-- alive, screens and the real engine). Only what happened comes back: a Steam Mech nobody at the
-- table woke is Flitwidget's, said so everywhere; and the rest of F1 below. Played: the seeds and DMs
-- the reviews named, exactly as the sim plays them, plus targeted cases. Run from the project root:
--     lua tools/tests/final_facts_check.lua [extra seeds per style]
-- Prints one line per item: what was seen, and FAIL lines where play contradicts the fix.

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"
local util = require "game.model.util"
local events_mod = require "game.model.events"

local EXTRA = tonumber(arg[1]) or 0
local ITEMS = { "run", "N1", "S", "D", "M" }
local NAMES = {
    run = "whole prologues",
    N1 = "the Mech and the notebook: only what happened",
    S = "stone after a lost boss fight: how each came back",
    D = "deaths: the wake, last words, the chat, the end, her memory, the pack, the pet",
    M = "money and memory in the recaps",
}

local fails = {}
local function fail(item, msg)
    fails[item] = fails[item] or { n = 0 }
    if #fails[item] < (tonumber(os.getenv("SHOW")) or 8) then
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

-- The sim's own play (tools/sim/museum.lua), step for step, so a seed and a style here play exactly
-- the night the reviews read. `on` gets every event with the night it came from.
local function sim_play(seed, style, on)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    local rng = require("game.model.rng").new(seed + 77)
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        local hooks = adventure.data.hooks[key]
        adventure.set_hook(c, key, hooks[rng:int(1, #hooks)].id)
    end
    local R = { c = c, tag = "seed " .. seed .. " " .. style, weeks = {}, said = {} }
    for w = 1, adventure.data.MAX_WEEKS do
        local prep = c:start_week()
        local pm = prep.museum
        for _, m in ipairs(c.chat) do
            if m.ask and not m.answered then
                museum_week.answer_chat(c, m, (style == "careful") and 1 or rng:int(1, 3))
            end
        end
        R.chats = R.chats or {}
        R.chats[w] = {}
        for _, m in ipairs(c.chat or {}) do
            table.insert(R.chats[w], { who = m.key, text = m.text or "", ask = m.ask })
        end
        if on.chat then
            on.chat(R, c, w)
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
        if on.between then
            on.between(R, c, w)
        end
        if style ~= "careless" then
            museum_week.prep_greedy(prep)
            for _, id in ipairs(pm.ahead) do
                for _, kid in ipairs(adventure.data.rooms[id].knobs or {}) do
                    local k = adventure.data.knobs[kid]
                    museum_week.set_knob(prep, kid, k.pick_hero and "mara" or (rng:chance(0.6) or nil))
                end
            end
        end
        if pm.boss then
            c.adv.boss = { opener = rng:chance(0.7) and "talk" or "ambush", style = rng:chance(0.6) and "yields" or "last" }
        end
        local night = c:start_night()
        R.night, R.week = night, w
        R.weeks[w] = { said = {} }
        if on.night then
            on.night(R, night, w)
        end
        local ev = night:advance()
        local guard = 0
        while ev.kind ~= "done" and guard < 4000 do
            guard = guard + 1
            if (ev.kind == "narrate" or ev.kind == "say" or ev.kind == "npc") and ev.text then
                table.insert(R.weeks[w].said, { ev = ev, text = ev.text, who = ev.who, style = ev.style, kind = ev.kind, farewell = ev.farewell })
            elseif ev.kind == "decision" and ev.card then
                table.insert(R.weeks[w].said, { text = "", card = ev.card.id, title = ev.card.title, kind = "card" })
            elseif ev.kind == "mark" then
                R.weeks[w].marks = R.weeks[w].marks or {}
                table.insert(R.weeks[w].marks, ev)
            end
            if on.ev then
                on.ev(R, night, ev, w)
            end
            local answer
            if ev.kind == "decision" then
                local opts = ev.card.options
                local pick = (style == "careful") and 1 or rng:int(1, #opts)
                if style == "careful" and string.find(ev.card.id or "", "^table_asks_") then
                    pick = #opts
                end
                if style == "careful" and opts[pick] and opts[pick].cost then
                    local hp, max, down = 0, 0, false
                    for _, pc in ipairs(night.pc_list or {}) do
                        hp, max = hp + math.max(0, pc.hp or 0), max + (pc.hp_max or 0)
                        down = down or ((pc.hp or 1) <= 0 and not pc.dead)
                    end
                    if not down and hp > 0.35 * max then
                        for i, o in ipairs(opts) do
                            if not o.cost and not o.disabled then
                                pick = i
                                break
                            end
                        end
                    end
                end
                if opts[pick].disabled then
                    pick = 1
                end
                if on.pick then
                    pick = on.pick(R, night, ev, pick) or pick
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
        local rep = c:finish_night()
        R.rep = rep
        R.weeks[w].rep = rep
        R.weeks[w].chain = (events_mod.chain(c, c.week))
        if on.after then
            on.after(R, night, rep, w)
        end
        c:level_up()
        if adventure.over(c) then
            break
        end
    end
    R.ending = c.adv.ending
    return R
end

-- N1: a Steam Mech nobody at the table woke ---------------------------------------------------------
-- The between-sessions loose end "Nobody woke the Steam Mech. Does it sit this one out?" answered
-- "Flitwidget wakes it himself, for the fight" (the confirming playtest: truth N1, 57 careful week 5;
-- screens N3, seed 54) put "A machine on their side (They woke the Steam Mech)" on her card, and Hans
-- clanked up the stairs to fight for a party that never went near the World of Tomorrow, with no word of
-- how. What the loose end really does is Flitwidget's doing: the table hears it before Hans comes, and
-- her card, the Story sidebar, the chain (the report and the journey) and the showdown say it was him.
-- The same week, Euryale's "Your Witness writes beautifully" to a party that never saw the notebook or
-- heard the name.

local function heard_before(week, pred, stop)
    for _, s in ipairs(week.said) do
        if stop and stop(s.text) then
            return false
        end
        if pred(s.text, s) then
            return true
        end
    end
    return false
end

local function mech_member()
    for _, side in ipairs(adventure.data.sides) do
        for _, mem in ipairs(side.members) do
            if mem.id == "mus_mech" then
                return mem
            end
        end
    end
end

local function n1_watch(R)
    local c = R.c
    local st = c.adv
    -- The week the Mech landed between sessions, by Flitwidget's hand (the loose end answered 1).
    local flit = (st.answered or {}).mech_left == 1
    local mark_ev = events_mod.last(c, { kind = "mark", thing = "mech" })
    if not mark_ev then
        return
    end
    local mech_week = flit and mark_ev.session
    -- A Mech for a party that never woke it, and no loose end gave it to them: never.
    if not st.done.tomorrow and not flit then
        fail("N1", R.tag .. ": the Steam Mech is on their side, and nobody woke it (no World of Tomorrow, no loose end)")
    end
    if not mech_week then
        add("N1", "woke_it_themselves")
        return
    end
    add("N1", "flitwidget_woke_it")
    local wk = R.weeks[mech_week]
    if not wk then
        return
    end
    local name = st.mech_name or "Hans"
    -- (a) The table hears how it woke, before it clanks up the stairs to fight.
    local told = heard_before(wk, function(t)
        return string.find(t, "Flitwidget", 1, true) and (string.find(t, "Mech", 1, true) or string.find(t, name, 1, true))
            and (string.find(t, "woke", 1, true) or string.find(t, "awake", 1, true))
    end, function(t)
        return string.find(t, "clanks up the stairs", 1, true)
    end)
    if not told then
        fail("N1", R.tag .. " week " .. mech_week .. ": " .. name .. " fights for them, and nobody said Flitwidget woke it")
    else
        add("N1", "told_at_the_table")
    end
    -- (b) Her card's reason, and what it does, say his doing (as it stood that night: the mark the table
    -- was shown as it landed).
    for _, s in ipairs(wk.marks or {}) do
        if s.id == "mech" and string.find(s.why or "", "They woke", 1, true) then
            fail("N1", R.tag .. " week " .. mech_week .. ": her card said \"" .. s.why .. "\" of Flitwidget's Mech")
        end
        if s.id == "mech" and st.mech_commander == false and string.find(s.showdown or "", "commander", 1, true) then
            fail("N1", R.tag .. " week " .. mech_week .. ": her card said \"" .. s.showdown .. "\", and nobody at the table commands it")
        end
    end
    for _, m in ipairs(adventure.boss_card(c).marks) do
        if m.id == "mech" then
            if string.find(m.why or "", "They woke", 1, true) then
                fail("N1", R.tag .. ": her card says \"" .. m.why .. "\" of Flitwidget's Mech")
            end
            if st.mech_commander == false and string.find(m.showdown or "", "commander", 1, true) then
                fail("N1", R.tag .. ": her card says \"" .. m.showdown .. "\", and nobody at the table commands it")
            end
        end
    end
    -- (c) The chain (the report's and the journey's) says it was him.
    local in_chain = false
    for _, line in ipairs(wk.chain or {}) do
        in_chain = in_chain or (string.find(line, "Flitwidget woke", 1, true) ~= nil)
    end
    if not in_chain then
        fail("N1", R.tag .. " week " .. mech_week .. ": the report's chain never says Flitwidget woke the Mech")
    else
        add("N1", "in_the_chain")
    end
    local j = adventure.journey(c)
    local on_journey = false
    for _, b in ipairs(j.between or {}) do
        on_journey = on_journey or (string.find(b.text or "", "Flitwidget", 1, true) ~= nil)
    end
    for _, r in ipairs(j.rooms) do
        for _, line in ipairs(r.chain or {}) do
            on_journey = on_journey or (string.find(line, "Flitwidget woke", 1, true) ~= nil)
        end
    end
    if not on_journey then
        fail("N1", R.tag .. ": the journey never says how the Mech woke (\"Never seen: ... the World of Tomorrow\")")
    end
    -- (d) The Story sidebar's line for the Mech, that week before the night (n1_between).
    local line = (R.mech_lines or {})[mech_week]
    if line and not string.find(line, "Flitwidget", 1, true) then
        fail("N1", R.tag .. " week " .. mech_week .. ": the Story sidebar says \"" .. tostring(line) .. "\" of Flitwidget's Mech")
    end
    -- (And at the end, once it's been lost in her lair: lost, not "never met" or "still asleep".)
    local standing = require "game.model.standing"
    local mem = mech_member()
    local now = standing.member_line(c, mem)
    if not st.marks.mech and (string.find(now, "Never met", 1, true) or string.find(now, "asleep", 1, true)) then
        fail("N1", R.tag .. ": the Mech fought for them and was lost, and the Story sidebar ends on \"" .. now .. "\"")
    end
end

-- The Story sidebar's Mech line between sessions, before each night.
local function n1_between(R, c, w)
    R.mech_lines = R.mech_lines or {}
    R.mech_lines[w] = require("game.model.standing").member_line(c, mech_member())
end

-- The Witness and the notebook: a line that names the Witness, or quotes the notebook as theirs, only once
-- the table has heard of it (the offices, or the notebook in their hands).
local function n1_witness(R)
    local c = R.c
    local st = c.adv
    local knew = st.done.offices ~= nil
    for w, wk in util.sorted_pairs(R.weeks) do
        for _, s in ipairs(wk.said) do
            if string.find(s.text, "Witness", 1, true) and not knew and not st.flags.studied then
                -- (Heard for the first time here is fine when the line explains it; "Your Witness" never is.)
                if string.find(s.text, "Your Witness", 1, true) then
                    fail("N1", R.tag .. " week " .. w .. ": \"" .. s.text .. "\" to a party that never saw the notebook")
                end
            end
            if string.find(s.text, "The archivist's notebook lies open", 1, true) and not knew then
                fail("N1", R.tag .. " week " .. w .. ": the archivist's notebook named as known, and they never searched the offices")
            end
        end
    end
    if st.flags.she_read then
        add("N1", "she_has_the_notebook")
    end
end

-- S: stone after a lost boss fight (screens N2, seed 54 week 4). Pip turned to stone, then "Brannoc, Pip
-- and Thessaly come round on the floor"; Oswin was stone when Euryale sent them home, and whole the next
-- week with no word. A hero who's stone isn't on the floor; once she lets them go the table hears how
-- each came back, and so do the report, next week's "Last time", the chat and their history.
local function s_watch(R)
    local c = R.c
    for w, wk in util.sorted_pairs(R.weeks) do
        local stone = {}
        local lost_lair = false
        for _, s in ipairs(wk.said) do
            local t = s.text
            for _, p in ipairs(c.players) do
                local ch = p.char
                if string.find(t, ch .. " turns to stone", 1, true) or string.find(t, ch .. " is stone now", 1, true) then
                    stone[ch] = true
                elseif stone[ch] and (string.find(t, "crack out of the stone", 1, true) or string.find(t, "cracks out of the stone", 1, true)
                    or string.find(t, "grey drains out of", 1, true)) and string.find(t, ch, 1, true) then
                    stone[ch] = "back"
                end
                if stone[ch] == true and string.find(t, "on the floor with 1 hit point", 1, true) and string.find(t, ch, 1, true) then
                    fail("S", R.tag .. " week " .. w .. ": " .. ch .. " is stone, and \"" .. t .. "\"")
                end
            end
            if string.find(t, "She lets them go. She wants them to come back.", 1, true) then
                lost_lair = true
                for ch, v in util.sorted_pairs(stone) do
                    if v ~= "back" then
                        fail("S", R.tag .. " week " .. w .. ": " .. ch .. " is stone as Euryale sends them home, and nobody says how " .. ch .. " came back")
                    else
                        add("S", "said_how_they_came_back")
                    end
                    if string.find(t, "as her hold on the lair breaks", 1, true) then
                        fail("S", R.tag .. ": her hold didn't break, she won")
                    end
                end
            end
            if lost_lair == false and string.find(t, "out of the stone, gasping, as her hold on the lair breaks", 1, true) then
                -- (said before "She lets them go" on a loss: her hold never broke)
                wk.hold_broke = true
            end
        end
        if lost_lair and wk.hold_broke then
            fail("S", R.tag .. " week " .. w .. ": they lost to her, and the stone \"cracks ... as her hold on the lair breaks\"")
        end
        if lost_lair and next(stone) then
            add("S", "lost_lair_with_stone")
            local nxt = R.weeks[w + 1]
            local named = false
            for _, s in ipairs((nxt and nxt.said) or {}) do
                if string.find(s.text, "^Last time,") and string.find(s.text, "stone", 1, true) then
                    named = true
                end
            end
            if nxt and not named then
                fail("S", R.tag .. " week " .. (w + 1) .. ": \"Last time\" never says they were stone, or how they came back")
            end
        end
    end
end

-- D: deaths everywhere (truth B1, B3, N2 to N4 and the special-attention list; alive 13). The wake where the
-- party is (53 careful: in a gift shop they hadn't reached, with a boot they hadn't met); real last words,
-- not "Not a bad fight. Not a bad fight at all." (53 and 56 careful); no chat question about a dead hero
-- (53 careful: "would brannoc know anything about gorgons", Brannoc dead since week one); the end names the
-- dead (53 careful: Dev's "Same heroes, bigger fights?"); Euryale knows a party she beat (56 careful: her
-- first-meeting words after the wipe); the pack picked up where it fell, not carried in by the new hero
-- through a curtain that's gone (56 careful); Exhibit B handed on, not carried on as if Pip had never been,
-- and nobody "hiding in a diorama" at the top of the stairs (56 careful); no quip from the floor as the
-- whole party goes down (56 careful: "Down. Note for later...").
local QUIPS = { "Note for later:", "is taking a little nap, courtesy of", "That was my good side!" }
local function d_watch(R)
    local c = R.c
    local found_shop = false
    local dead_names, died_week = {}, {}
    for _, rec in ipairs(c.fallen or {}) do
        dead_names[rec.char] = rec.key
        died_week[rec.char] = rec.week
    end
    local beaten_here = false        -- (she sent them back down her stairs: next time she knows them)
    for w, wk in util.sorted_pairs(R.weeks) do
        local dead_tonight, death_card = false, false
        local said = wk.said
        local rematch_night = beaten_here
        local pet_seen, handed = false, false
        for i, s in ipairs(said) do
            local t = s.text
            if string.find(t, "A quiet little shop at the foot of the stairs", 1, true) or string.find(t, "Wha? Oh! Customers", 1, true) then
                found_shop = true
            end
            if string.find(t, "They hold the wake in the gift shop", 1, true) then
                add("D", "wakes")
                if not found_shop then
                    fail("D", R.tag .. " week " .. w .. ": the wake is held in a gift shop they haven't reached: " .. t)
                end
            elseif string.find(t, "hold the wake", 1, true) then
                add("D", "wakes")
            end
            if s.kind == "card" and s.card == "hero_dies" then
                death_card = true
            end
            if s.farewell then
                add("D", "last_words")
                if t == "Not a bad fight. Not a bad fight at all." then
                    fail("D", R.tag .. " week " .. w .. ": the card promised last words, and they're \"" .. t .. "\"")
                end
            end
            -- (A hero down and dying, said any of its ways: game/data/barks.lua's told.knocked_down and knocked_down_again,
            -- never the Stable knock-out with no death saves.)
            local lt = string.lower(t)
            if string.find(lt, "death saves", 1, true) and not string.find(lt, "no death saves", 1, true) then
                for j = i + 1, math.min(#said, i + 3) do
                    for _, q in ipairs(QUIPS) do
                        if death_card and string.find(said[j].text, q, 1, true) then
                            fail("D", R.tag .. " week " .. w .. ": a hero's dead tonight, and from the floor: \"" .. said[j].text .. "\"")
                        end
                    end
                end
            end
            for _, q in ipairs(QUIPS) do
                if string.find(t, q, 1, true) then
                    -- (the whole party went down within the next few lines: no quip on the way)
                    for j = i + 1, math.min(#said, i + 30) do
                        if string.find(said[j].text, "come round on the floor with 1 hit point each, groggy, alive, and beaten", 1, true)
                            or string.find(said[j].text, "comes round on the floor with 1 hit point, groggy, alive, and beaten", 1, true) then
                            fail("D", R.tag .. " week " .. w .. ": as the whole party goes down: \"" .. t .. "\"")
                        end
                    end
                end
            end
            if string.find(t, "She lets them go. She wants them to come back.", 1, true) then
                beaten_here = true
            end
            if rematch_night and (string.find(t, "\"You burned my garden.\"", 1, true) or string.find(t, "\"Here is your choice.", 1, true)) then
                fail("D", R.tag .. " week " .. w .. ": she beat them last time, and greets them as strangers: " .. t)
            end
            if string.find(t, "hiding in a diorama", 1, true) then
                fail("D", R.tag .. " week " .. w .. ": \"" .. t .. "\" (there's no diorama where they are)")
            end
            for name in pairs(dead_names) do
                if string.find(t, "carrying " .. name .. "'s pack", 1, true) then
                    fail("D", R.tag .. " week " .. w .. ": the new hero walks in carrying " .. name .. "'s pack: " .. t)
                end
                if (died_week[name] or 99) < w and string.find(t, name .. "'s pack", 1, true)
                    and (string.find(t, "picks it up", 1, true) or string.find(t, "shoulders", 1, true) or string.find(t, "takes it now", 1, true)) then
                    add("D", "pack_picked_up")
                end
            end
            if string.find(t, "Exhibit B", 1, true) and (died_week["Pip"] or 99) < w then
                if not pet_seen and not (string.find(t, "Pip", 1, true) or string.find(t, "yours now", 1, true)) then
                    fail("D", R.tag .. " week " .. w .. ": Exhibit B carries on after Pip's death with no word of it: " .. t)
                end
                handed = handed or string.find(t, "Pip", 1, true) ~= nil
                pet_seen = true
            end
        end
        if handed then
            add("D", "pet_handed_on")
        end
        -- The chat after a death: no question for a hero who's gone.
        for _, m in ipairs(R.chats[w + 1] or {}) do
            for name, _ in pairs(dead_names) do
                if m.ask and (died_week[name] or 99) <= w and string.find(string.lower(m.text), "%f[%a]" .. string.lower(name) .. "%f[%A]") then
                    fail("D", R.tag .. " week " .. (w + 1) .. ": the chat asks about " .. name .. ", who died in week " .. died_week[name] .. ": " .. m.text)
                end
            end
        end
    end
    -- The end names the dead.
    if next(dead_names) and R.ending then
        local last = R.weeks[#R.weeks]
        local after, named, any = false, false, false
        for _, s in ipairs(last.said) do
            if string.find(s.text, "^And an invitation") then
                after = true
            elseif after and s.kind == "say" then
                any = true
                for name, key in pairs(dead_names) do
                    named = named or string.find(s.text, name, 1, true) ~= nil
                    if s.who == key and string.find(s.text, "Same heroes", 1, true) then
                        fail("D", R.tag .. ": " .. name .. " died, and " .. key .. " ends on \"" .. s.text .. "\"")
                    end
                end
            end
        end
        if any and not named then
            fail("D", R.tag .. ": the prologue ends and nobody names the dead")
        elseif named then
            add("D", "the_end_names_them")
        end
    end
end

-- M: money and memory in the recaps (truth B10, B11, B12, N6, T5; alive N4, N6, 19). Flitwidget docks
-- the reward for one reason he names, the recap gives that reason and the figure he said (52 random: "the
-- business with my donation box" to a party that dropped a coin in it; 53 random: another reason in the
-- recap; 51 careful and 56 random: "ten gold off" when the table heard five, and one breakage of three);
-- no "saw what was left of X" with nothing behind it; "her sisters back" only once they've heard it; the
-- daggers credited to who carried them, and the lock to whoever really went for it; one roll's two Francs
-- said as two; the "Along the way" tally is the night's Francs.
local REASON_WORDS = {
    break_ = { "garden", "tomb guardian", "Steam Mech", "breakages", "exhibits" },
    draught = { "draught", "waistcoat" }, caught = { "waistcoat", "pockets" }, told = { "Telpur" }, box = { "donation box" },
}
local MY_TO_HIS = { ["my garden"] = "his garden", ["my tomb guardian"] = "the Bone Construct", ["my Steam Mech"] = "the Steam Mech" }
local NUMW = { one = 1, two = 2, three = 3, four = 4, five = 5, six = 6, seven = 7, eight = 8, nine = 9, ten = 10 }
local function m_watch(R)
    local c = R.c
    local st = c.adv
    for w, wk in util.sorted_pairs(R.weeks) do
        local chain = table.concat(wk.chain or {}, " ")
        -- What Flitwidget said, docking.
        local said_dock
        for _, s in ipairs(wk.said) do
            if s.kind == "npc" and s.ev and s.ev.name == "Flitwidget" and string.find(s.text, " each", 1, true)
                and (string.find(s.text, "less", 1, true) or string.find(s.text, "taken", 1, true) or string.find(s.text, "Minus", 1, true)
                     or string.find(s.text, " off each", 1, true) or string.find(s.text, "After what Telpur", 1, true)
                     or string.find(s.text, "haven't forgotten", 1, true)) then
                said_dock = s.text
            end
        end
        local took = string.match(chain, "Flitwidget took (%a+) gold each off their reward")
        if said_dock then
            add("M", "docked")
            if not took then
                fail("M", R.tag .. " week " .. w .. ": Flitwidget docked the reward (\"" .. said_dock .. "\"), and the recap never says so")
            end
            -- (Not the donation box, from a party that gave to it and never touched its lock.)
            if string.find(said_dock, "donation box", 1, true) and not st.marks.robbed and string.find(chain .. table.concat((R.weeks[1] or {}).chain or {}, " "), "dropped a coin", 1, true) then
                fail("M", R.tag .. " week " .. w .. ": they gave to his donation box, and \"" .. said_dock .. "\"")
            end
            -- (The figure he said is the recap's figure.)
            local fig = string.match(said_dock, "^(%a+) gold less") or string.match(said_dock, "(%a+) less") or string.match(said_dock, "^(%a+) off")
                or string.match(said_dock, "less (%a+) for")
            fig = fig and NUMW[string.lower(fig)]
            if fig and took and NUMW[took] ~= fig then
                fail("M", R.tag .. " week " .. w .. ": Flitwidget said \"" .. said_dock .. "\", and the recap says he took " .. took .. " gold each")
            end
            -- (Every breakage he named is in the recap.)
            for my, his in pairs(MY_TO_HIS) do
                if string.find(said_dock, my, 1, true) and not string.find(chain, his, 1, true) then
                    fail("M", R.tag .. " week " .. w .. ": Flitwidget named " .. my .. ", and the recap leaves it out: " .. chain)
                end
            end
            -- (The reason he gave is the recap's: Telpur's word, or what the recap says he saw or took it for.)
            if took then
                local said_reason, recap_reason
                for k, words in pairs(REASON_WORDS) do
                    for _, wd in ipairs(words) do
                        if string.find(said_dock, wd, 1, true) then
                            said_reason = said_reason or k
                        end
                    end
                end
                -- (The sentence that says it: its cause is the clause before "so Flitwidget took", or its own "for".)
                local sentence
                for _, line in ipairs(wk.chain or {}) do
                    sentence = sentence or (string.find(line, "Flitwidget took", 1, true) and line) or nil
                end
                sentence = sentence or ""
                local cause = string.match(sentence, "([^%.]*), so Flitwidget took") or ""
                if said_reason == "box" and not string.find(sentence, "donation box", 1, true) then
                    fail("M", R.tag .. " week " .. w .. ": Flitwidget docked them for the donation box, and the recap says: " .. sentence)
                elseif said_reason and said_reason ~= "told" and string.find(cause, "Telpur told Flitwidget", 1, true) then
                    fail("M", R.tag .. " week " .. w .. ": Flitwidget said \"" .. said_dock .. "\", and the recap gives Telpur's word as the reason: " .. sentence)
                elseif said_reason == "told" and not string.find(cause, "Telpur", 1, true) then
                    fail("M", R.tag .. " week " .. w .. ": Flitwidget said \"" .. said_dock .. "\", and the recap says: " .. sentence)
                elseif said_reason == "break_" and not string.find(cause, "saw what was left", 1, true) then
                    fail("M", R.tag .. " week " .. w .. ": Flitwidget docked them for the breakages, and the recap says: " .. sentence)
                end
            end
        elseif took then
            fail("M", R.tag .. " week " .. w .. ": the recap says Flitwidget took " .. took .. " gold each, and he never said it")
        end
        -- (No "saw what was left" with nothing behind it.)
        for _, line in ipairs(wk.chain or {}) do
            if string.find(line, "Flitwidget saw what was left of", 1, true) and not string.find(line, "Flitwidget took", 1, true) then
                fail("M", R.tag .. " week " .. w .. ": \"" .. line .. "\" with nothing behind it")
            end
            -- (The daggers to who carries them; the lock to who went for it.)
            local giver = string.match(line, "(%a+) kept the twin daggers")
            if giver and not string.find(line, "kept the twin daggers, and gave them to", 1, true) then
                for _, it in ipairs(require("game.model.items").list(c)) do
                    local holder = it.id == "twin_daggers" and it.holder and c:player(it.holder)
                    if holder and holder.char ~= giver and not it.gone then
                        fail("M", R.tag .. " week " .. w .. ": \"" .. line .. "\", and " .. holder.char .. " carries them")
                    end
                end
            end
            if string.find(line, "went for the donation box's lock", 1, true) then
                for _, s in ipairs(wk.said) do
                    if string.find(s.text, "puts the picks away", 1, true) then
                        fail("M", R.tag .. " week " .. w .. ": the picks went away before the lock, and the recap says \"" .. line .. "\"")
                    end
                end
            end
        end
        -- (One roll, two Francs to one hero: said as two, not "a Franc" twice.)
        for i, s in ipairs(wk.said) do
            local who = string.match(s.text, "^Better than they hoped: a Flitwidget Franc pops into (%a+)'s pocket")
                or string.match(s.text, "^Better than hoped: (%a+) finds a Flitwidget Franc")
                or string.match(s.text, "^Better than they hoped: there's a crisp Flitwidget Franc in (%a+)'s hand")
                or string.match(s.text, "^Better than they hoped: a Flitwidget Franc flutters down out of nowhere into (%a+)'s palm")
            if who then
                for j = i + 1, math.min(#wk.said, i + 3) do
                    local t = wk.said[j].text
                    if string.find(t, "^A Flitwidget Franc turns up in " .. who .. "'s") or string.find(t, "^There's a Flitwidget Franc in " .. who)
                        or string.find(t, "^" .. who .. " finds a crisp Flitwidget Franc") then
                        fail("M", R.tag .. " week " .. w .. ": one roll, two Francs for " .. who .. ", said as one twice: \"" .. s.text .. "\" / \"" .. t .. "\"")
                    end
                end
            end
        end
        -- (The tally: the night's Francs found, as the log has them.)
        local found = 0
        for _, ev in ipairs(events_mod.find(c, { kind = "find", session = w, thing = "francs" })) do
            if not ev.between and not ev.pay and ev.who and ev.who ~= "party" then
                found = found + (tonumber(ev.n) or 1)
            end
        end
        local tally = 0
        for _, line in ipairs(wk.chain or {}) do
            local one = string.match(line, "^Along the way, .- found (%a+) Flitwidget Franc")  -- (a name with a space: Exhibit B)
            if one then
                tally = tally + (one == "a" and 1 or (NUMW[one] or 0))
            elseif string.find(line, "^Along the way, Flitwidget Francs turned up: ") then
                for n in string.gmatch(line, "(%a+) for ") do
                    tally = tally + (NUMW[n] or 0)
                end
            end
        end
        if found > 0 then
            add("M", "tallies")
            if tally ~= found then
                local bits = {}
                for _, ev in ipairs(events_mod.find(c, { kind = "find", session = w, thing = "francs" })) do
                    if not ev.between and not ev.pay and ev.who and ev.who ~= "party" then
                        table.insert(bits, tostring(ev.who) .. "/" .. tostring(ev.text) .. (ev.beat and "" or " (no beat)"))
                    end
                end
                fail("M", R.tag .. " week " .. w .. ": " .. found .. " Francs found tonight, and \"Along the way\" counts " .. tally
                    .. " [" .. table.concat(bits, "; ") .. "]")
            end
        end
    end
    -- (Her sisters, only once heard.)
    for w, wk in util.sorted_pairs(R.weeks) do
        for _, s in ipairs(wk.said) do
            if string.find(s.text, "only wanted her sisters back", 1, true) and R.ending ~= "bargain" then
                fail("M", R.tag .. " week " .. w .. ": \"" .. s.text .. "\", and nobody heard her talk about her sisters")
            end
        end
    end
end

-- The UI's own run of seed 54, its screens dumped (DUMP_DIR, tools/tests/museum_smoke.lua), as the
-- screens review read them: week 4 a lost boss fight with Pip and Oswin stone, week 5 Hans for a party
-- that never went to the World of Tomorrow.
local function dump_texts(dir, name)
    local f = io.open(dir .. "/" .. name)
    if not f then
        return nil
    end
    local out = {}
    for line in f:lines() do
        local kind = string.match(line, "^(%a+)\t")
        if kind == "text" then
            local t = string.match(line, "^[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t(.*)$")
            if t then
                table.insert(out, (string.gsub(t, "\\n", " ")))
            end
        end
    end
    f:close()
    return table.concat(out, "\n")
end
local function ui_54()
    local dir = os.tmpname()
    os.remove(dir)
    os.execute("mkdir -p " .. dir)
    local fh = io.popen("DUMP_DIR=" .. dir .. " lua tools/tests/museum_smoke.lua 54 2>&1")
    local said = fh:read("*a")
    fh:close()
    if not string.find(said, "museum smoke 54:", 1, true) then
        fail("S", "the seed 54 smoke run didn't finish: " .. string.sub(said, -200))
        return
    end
    local function has(name, pat)
        local t = dump_texts(dir, name)
        return t and string.find(t, pat, 1, true) ~= nil, t
    end
    -- N3: Hans on the boss board, the Story sidebar and the journey, said as Flitwidget's.
    local _, journey = has("7_journey.txt", "")
    if journey and string.find(journey, "Never seen", 1, true) and string.find(journey, "World of Tomorrow", 1, true)
        and string.find(dump_texts(dir, "6_report_w5.txt") or "", "Hans", 1, true) then
        add("N1", "ui_54_hans")
        if not string.find(journey, "Flitwidget woke", 1, true) then
            fail("N1", "seed 54 (UI): the journey says the World of Tomorrow was never seen, and never how Hans woke")
        end
        if not has("4b_showdown.txt", "woken by Flitwidget") then
            fail("N1", "seed 54 (UI): the showdown board brings \"the Steam Mech (Hans)\" with no word of who woke it")
        end
        if not has("5r_story_w5.txt", "Woken by Flitwidget") then
            fail("N1", "seed 54 (UI): the Story sidebar says Hans was woken, not who by")
        end
    end
    -- N2: week 4's lost boss fight, Pip and Oswin stone.
    local _, night4 = has("5_night_end_w4.txt", "")
    if night4 and string.find(night4, "Oswin turns to stone", 1, true) then
        add("S", "ui_54_stone")
        if string.find(night4, "Pip and Thessaly come round on the floor", 1, true) then
            fail("S", "seed 54 (UI) week 4: Pip turned to stone, and \"Brannoc, Pip and Thessaly come round on the floor\"")
        end
        local rep = dump_texts(dir, "6_report_w4.txt") or ""
        if not string.find(rep, "out of the stone", 1, true) then
            fail("S", "seed 54 (UI) week 4: the report never says how Pip and Oswin came back from stone")
        end
        if not string.find(journey or "", "stone", 1, true) then
            fail("S", "seed 54 (UI): the journey's histories never say Oswin was turned to stone")
        end
        local chat = dump_texts(dir, "3_between_w5.txt") or ""
        if not (string.find(chat, "stone", 1, true) or string.find(chat, "statue", 1, true)) then
            fail("S", "seed 54 (UI) week 5: the chat never mentions being stone")
        end
    end
    os.execute("rm -rf " .. dir)
end

-- Whole prologues --------------------------------------------------------------------------------------
-- The 24 the reviews read (seeds 51 to 58, three DMs), and more seeds on request.
local RUNS = {}
for s = 51, 58 do
    for _, style in ipairs({ "careful", "random", "careless" }) do
        table.insert(RUNS, { s, style })
    end
end
for s = 1, EXTRA do
    for _, style in ipairs({ "careful", "random", "careless" }) do
        table.insert(RUNS, { 200 + s, style })
    end
end

for _, run in ipairs(RUNS) do
    case("run", function()
        local R = sim_play(run[1], run[2], { between = n1_between })
        add("run", "prologues")
        case("N1", function()
            n1_watch(R)
            n1_witness(R)
        end)
        case("S", function()
            s_watch(R)
        end)
        case("D", function()
            d_watch(R)
        end)
        case("M", function()
            m_watch(R)
        end)
    end)
end

case("S", ui_54)

-- Targeted cases -----------------------------------------------------------------------------------

-- A fresh campaign, up the stairs without the World of Tomorrow, the offices or the chamber: the loose
-- ends as the sims answer them (the first option each).
local function skipped_campaign(seed)
    adventure.enter()
    local c = campaign_mod.new(seed or 5)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    c.week = 4
    local st = c.adv
    st.skipped.tomorrow, st.skipped.offices, st.skipped.chamber = 3, 3, 3
    return c
end

-- N1: the loose end's Mech is Flitwidget's on her card, in the log, in the chain and the sidebar; the
-- scarabs that crept up from a chamber nobody went into broke nothing, so Flitwidget has nothing to dock.
case("N1", function()
    local c = skipped_campaign(5)
    local st = c.adv
    adventure.answer_loose(c, "mech_left", 1)
    adventure.answer_loose(c, "construct_left", 1)
    adventure.answer_loose(c, "notebook_left", 1)
    for _, m in ipairs(adventure.boss_card(c).marks) do
        if m.id == "mech" and not string.find(m.why or "", "Flitwidget", 1, true) then
            fail("N1", "case: Flitwidget woke the Mech between sessions, and her card says \"" .. tostring(m.why) .. "\"")
        end
        if m.id == "mech" and string.find(m.showdown or "", "commander", 1, true) then
            fail("N1", "case: nobody at the table commands Flitwidget's Mech, and her card says \"" .. m.showdown .. "\"")
        end
        if m.id == "scarabs" and string.find(m.why or "", "They smashed", 1, true) then
            fail("N1", "case: nobody went into the chamber, and her card says \"" .. m.why .. "\"")
        end
    end
    if events_mod.any(c, { kind = "break", thing = "the Bone Construct" }) then
        fail("N1", "case: nobody went into the chamber, and the log has the party breaking the Bone Construct (Flitwidget docks for it)")
    end
    local said = false
    for _, line in ipairs((events_mod.chain(c, c.week))) do
        said = said or (string.find(line, "Flitwidget woke", 1, true) ~= nil)
    end
    if not said then
        fail("N1", "case: the week's chain never says Flitwidget woke the Mech")
    end
    add("N1", "case_loose_ends")
end)

-- N1: the Story sidebar's Mech line, only for his Mech; without one, no "Woken" at all.
case("N1", function()
    local standing = require "game.model.standing"
    local mem
    for _, side in ipairs(adventure.data.sides) do
        for _, m in ipairs(side.members) do
            if m.id == "mus_mech" then
                mem = m
            end
        end
    end
    local c = skipped_campaign(6)
    local line = standing.member_line(c, mem)
    if string.find(line or "", "Woken", 1, true) then
        fail("N1", "case: no Mech on their side, and the Story sidebar says \"" .. line .. "\"")
    end
    adventure.answer_loose(c, "mech_left", 1)
    line = standing.member_line(c, mem)
    if not string.find(line or "", "Flitwidget", 1, true) then
        fail("N1", "case: Flitwidget woke the Mech, and the Story sidebar says \"" .. tostring(line) .. "\"")
    end
    add("N1", "case_sidebar")
end)

-- N1: an old save, its Flitwidget's Mech logged as the party's, loads back as his.
case("N1", function()
    local save = require "game.model.save"
    local c = skipped_campaign(7)
    adventure.answer_loose(c, "mech_left", 1)
    local ev = events_mod.last(c, { kind = "mark", thing = "mech" })
    ev.who, ev.between, ev.beat = "party", nil, nil      -- (as bfa5157 wrote it)
    local back = assert(save.load(save.dump(c)))
    for _, m in ipairs(adventure.boss_card(back).marks) do
        if m.id == "mech" and not string.find(m.why or "", "Flitwidget", 1, true) then
            fail("N1", "case: an old save's Flitwidget Mech loads back as \"" .. tostring(m.why) .. "\"")
        end
    end
    add("N1", "case_old_save")
end)

-- D: the group chat's question for you never names a hero who died (Brannoc, dead in week one).
case("D", function()
    local c = skipped_campaign(9)
    c.week = 4
    c.fallen = { { key = "dev", char = "Brannoc", week = 1 } }
    c.adv.done.hunting = 3
    c.adv.chat_asked = {}
    for _, q in ipairs(adventure.data.chat_ask) do
        if q.id ~= "brannoc_gorgons" and q.id ~= "gorgon_strength" then
            c.adv.chat_asked[q.id] = 1
        end
    end
    for _, m in ipairs(museum_week.write_chat(c)) do
        if m.ask and string.find(string.lower(m.text or ""), "brannoc", 1, true) then
            fail("D", "case: Brannoc died in week one, and the chat asks: " .. m.text)
        end
    end
    add("D", "case_chat_ask")
end)

-- Report -------------------------------------------------------------------------------------------

local total = 0
for _, item in ipairs(ITEMS) do
    local seen = {}
    for k, n in util.sorted_pairs(E[item] or {}) do
        table.insert(seen, k .. " " .. n)
    end
    local f = fails[item]
    print(string.format("%-4s %-46s %s%s", item, NAMES[item], #seen > 0 and table.concat(seen, ", ") or "-",
        f and ("  FAIL x" .. f.n) or ""))
    for _, m in ipairs(f or {}) do
        print("     FAIL: " .. m)
    end
    total = total + (f and f.n or 0)
end
print(total == 0 and "final_facts_check: all good" or ("final_facts_check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
