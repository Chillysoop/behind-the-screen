-- The round-two playtest findings Conner said yes to (the roadmap's "Fix before more testers", the
-- items about truth: F1, F3, F4, F5, F10, F11, F12, F13, F14, F18, F19, F20, F23, F27), played:
-- whole prologues headless over several seeds and three kinds of DM, each fix seen in play, plus
-- targeted cases for the moments a run can't be counted on to reach. Run from the project root:
--     lua tools/tests/roadmap_truth_check.lua [runs per style]
-- Prints one line per item: what was seen, and FAIL lines where play contradicts the fix.

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"

local RUNS = tonumber(arg[1]) or 3
local STYLES = { "careful", "random", "careless" }
local ITEMS = { "run", "F1", "F3", "F4", "F5", "F10", "F11", "F12", "F13", "F14", "F18", "F19", "F20", "F23", "F27" }
local NAMES = { run = "whole prologues",
    F1 = "boss night keeps its break", F3 = "flee lines count who's standing", F4 = "an ally's fall, and the Mech's rule",
    F5 = "companions introduced once", F10 = "one inventory, real purchases", F11 = "no split with danger near",
    F12 = "promises kept", F13 = "lines tied to what happened", F14 = "rules talk about what happened",
    F18 = "credit and votes add up", F19 = "fight turns keep the rules", F20 = "the recap tells what happened",
    F23 = "the level-up says the refill", F27 = "the test logs show every roll",
}

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
-- A targeted case: an error inside it is a failure of its item, not of the whole check.
local function case(item, fn)
    local ok, err = pcall(fn)
    if not ok then
        fail(item, "error: " .. tostring(err))
    end
end

-- A campaign at Session Zero, ready for its first week.
local function new_campaign(seed, style)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    local s0 = social.default_choices()
    c:session_zero(s0)
    local rng = require("game.model.rng").new(seed * 7 + #(style or ""))
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        local hooks = adventure.data.hooks[key]
        adventure.set_hook(c, key, hooks[rng:int(1, #hooks)].id)
    end
    return c, rng
end

-- F27: the sim's log names every attacker and shows every roll ------------------------------------

case("F27", function()
    local fh = io.popen("lua tools/sim/museum.lua 22 random log")
    local out = fh:read("*a")
    fh:close()
    local turns, attacks = 0, 0
    for line in string.gmatch(out, "[^\n]+") do
        if string.match(line, "^    %. ") then
            turns = turns + 1
            if string.match(line, "^    %. nil:") then
                fail("F27", "a turn with no actor: " .. line)
            end
            for att in string.gmatch(line, "attack[^,]*") do
                attacks = attacks + 1
                if not string.find(att, "->", 1, true) then
                    fail("F27", "an attack without its attacker and target: " .. att)
                elseif not string.find(att, "d20 %d+") and not string.find(att, "%[") then
                    fail("F27", "an attack without its roll: " .. att)
                end
            end
        end
    end
    add("F27", "turn_lines", turns)
    add("F27", "attacks_with_both_sides", attacks)
    if not string.find(out, "(big roll)", 1, true) then
        fail("F27", "the big rolls aren't in the log")
    end
end)

-- Whole prologues ---------------------------------------------------------------------------------
-- One loop plays every week; each item watches what it's about (`watch`, per event, and `after`, per
-- night). The DM answers like the sims do, except that a thought that could bring the break sooner
-- always does (F1), and a tired friend is at the table every week so that thought comes up.

local thoughts = require "game.model.thoughts"
local watchers, night_end, run_end = {}, {}, {}

local function play(seed, style)
    local c, rng = new_campaign(seed, style)
    local tag = "seed " .. seed .. " " .. style
    local R = { tag = tag, c = c }
    for w = 1, adventure.data.MAX_WEEKS do
        local prep = c:start_week()
        for _, m in ipairs(c.chat or {}) do
            if m.ask and not m.answered then
                local pick = ({ careful = 1, random = rng:int(1, 3), careless = 3 })[style]
                if m.ask == "pip_pet" then
                    pick = ({ careful = 1, random = 2, careless = 2 })[style]     -- (found in the museum: F5)
                end
                museum_week.answer_chat(c, m, pick)
            end
        end
        for _, pr in ipairs(c.adv.prompts) do
            if pr.kind == "request" and pr.id == "keep_boot" then
                -- (Telpur comes along for two of the three DMs, and the third gets his shoelace: F4, F5.)
                adventure.answer_request(c, pr.id, ({ careful = "laugh", random = "yes", careless = "danger" })[style])
            elseif pr.kind == "request" then
                adventure.answer_request(c, pr.id, adventure.data.ANSWERS[style == "careful" and 2 or rng:int(1, 4)])
            elseif pr.kind == "loose" then
                adventure.answer_loose(c, pr.id, rng:int(1, #pr.def.options))
            elseif pr.kind == "ruling" then
                adventure.answer_ruling(c, pr.id, style ~= "careless")
            elseif pr.kind == "favor" then
                adventure.answer_favor(c, pr.id, rng:int(1, 2), rng:int(1, 2))
            end
        end
        if style ~= "careless" then
            museum_week.prep_greedy(prep)
            -- (The knobs as the sim sets them: a painting picked for one hero, F18.)
            for _, id in ipairs(prep.museum.ahead or {}) do
                for _, kid in ipairs(adventure.data.rooms[id].knobs or {}) do
                    local k = adventure.data.knobs[kid]
                    museum_week.set_knob(prep, kid, k.pick_hero and ({ "mara", "dev", "jess", "sam" })[(seed + w) % 4 + 1]
                        or (rng:chance(0.6) or nil))
                end
            end
        end
        if prep.museum.boss then
            c.adv.boss = { opener = rng:chance(0.7) and "talk" or "ambush", style = rng:chance(0.6) and "yields" or "last" }
        end
        -- (Somebody's tired every week: the thought that asks for an early break comes up.)
        local present = c:present()
        if #present > 0 then
            present[(w % #present) + 1].mood = "tired"
        end
        local night = c:start_night()
        local N = { w = w, night = night, tag = tag .. " week " .. w, scenes = 0 }
        R.N = N
        local ev = night:advance()
        local guard = 0
        while ev.kind ~= "done" and guard < 6000 do
            guard = guard + 1
            if ev.kind == "scene" then
                N.scenes = N.scenes + 1
            end
            for _, fn in ipairs(watchers) do
                fn(R, N, ev)
            end
            local answer
            if ev.kind == "decision" then
                local opts = ev.card.options
                local pick = (style == "careful") and 1 or rng:int(1, #opts)
                if ev.card.id == "table_break" then
                    pick = ({ careful = 2, random = rng:int(1, 4), careless = 1 })[style]
                end
                -- (A fork where they've already agreed: the careful DM nudges them where they're all
                -- going anyway, the random one hints at a room they missed. F18.)
                if string.find(ev.card.id or "", "^mus_fork_") and string.find(ev.card.text or "", "more or less decided", 1, true) then
                    for i, o in ipairs(opts) do
                        if style == "careful" and string.find(o.sub or "", "Mara, Dev, Jess and Sam want this", 1, true) then
                            pick = i
                        elseif style ~= "careful" and string.find(o.label or "", "^Hint they missed") then
                            pick = i
                        end
                    end
                end
                if not opts[pick] or opts[pick].disabled then
                    pick = 1
                end
                answer = N.force_pick or pick
                N.force_pick = nil
            elseif ev.kind == "thought" then
                local brought = false
                if not ev.glow then
                    local r = thoughts.read(night, ev.id)
                    if r and r.result == "miss" then
                        thoughts.ask(night, ev.id)
                    end
                    for _, a in ipairs(thoughts.answers_for(night, ev.id)) do
                        if not brought and (a.id == "early_break" or a.id == "snack") then
                            brought = thoughts.respond(night, ev.id, a.id)
                            if brought then
                                N.break_promised = N.break_promised or N.scenes
                                add("F1", "break_brought_forward")
                            end
                        end
                    end
                end
                if not brought then
                    thoughts.bot_play(night, ev, style, rng)
                end
            elseif ev.kind == "ruling" then
                answer = 1
            elseif ev.kind == "improv" then
                answer = { 1 }
            elseif ev.kind == "roll_where" then
                answer = (style == "careless") and "hidden" or "open"
            elseif ev.kind == "roll" then
                answer = rng:d20()
            end
            ev = night:advance(answer)
        end
        if guard >= 6000 then
            fail("run", N.tag .. ": the night never ended")
        end
        for _, fn in ipairs(night_end) do
            fn(R, N)
        end
        N.report = c:finish_night()
        N.level = c:level_up()
        for _, fn in ipairs(R.after_level or {}) do
            fn(R, N)
        end
        if adventure.over(c) then
            break
        end
    end
    for _, fn in ipairs(run_end) do
        fn(R)
    end
end

-- F1: every night takes its one break; a thought's answer brings it sooner, never stands in for it.
table.insert(watchers, function(R, N, ev)
    if ev.kind == "decision" and ev.card.id == "table_break" then
        N.breaks = (N.breaks or 0) + 1
        add("F1", "breaks")
        if N.break_promised then
            add("F1", "promised_breaks_kept")
            -- (After the room it was promised in: no more than one room later.)
            if N.scenes > N.break_promised + 1 then
                fail("F1", N.tag .. ": a break promised in scene " .. N.break_promised .. " came in scene " .. N.scenes)
            end
            N.break_promised = nil
        end
    end
end)
table.insert(night_end, function(R, N)
    add("F1", "nights")
    if (N.breaks or 0) == 0 and not N.night.end_early then
        fail("F1", N.tag .. ": no break card all night" .. (N.break_promised and " (one was promised)" or ""))
    elseif (N.breaks or 0) > 1 then
        fail("F1", N.tag .. ": " .. N.breaks .. " break cards")
    end
    for _, sc in ipairs(N.night.scenes or {}) do
        if sc.room == "lair" then
            add("F1", "boss_nights")
        end
    end
end)

-- F3 (and F13's "sees the fight turning"): a call to run for it counts who's still standing.
local WORDS = { one = 1, two = 2, three = 3, four = 4, five = 5, six = 6 }
local function standing(night)
    local alive, minions, boss = 0, 0, nil
    for _, c in ipairs((night.battle and night.battle.creatures) or {}) do
        if c.side == "foes" and not c.dead and not c.removed then
            alive = alive + 1
            if c.boss then
                boss = c
            else
                minions = minions + 1
            end
        end
    end
    return alive, minions, boss
end
table.insert(watchers, function(R, N, ev)
    local night = N.night
    if ev.kind == "decision" and ev.card.id == "dragging_fight" then
        local alive, minions, boss = standing(night)
        add("F3", "run_for_it_calls")
        for _, o in ipairs(ev.card.options or {}) do
            local said = (o.label or "")
            if string.find(said, "Everyone left on her side", 1, true) or string.find(said, "Everyone on her side", 1, true) then
                add("F3", "her_side_runs")
                if minions == 0 then
                    fail("F3", N.tag .. ": '" .. said .. "' with nobody left on her side")
                end
            end
            if string.find(said, "runs for it", 1, true) and minions > 0 then
                fail("F3", N.tag .. ": '" .. said .. "' with " .. minions .. " still beside her")
            end
        end
        N.flee_call = { alive = alive, minions = minions, boss = boss }
    end
    local text = ev.text
    if text and (ev.kind == "narrate" or ev.kind == "say") then
        local fc = N.flee_call
        if fc and string.find(text, "goes with her", 1, true) and fc.minions ~= 1 then
            fail("F3", N.tag .. ": '" .. text .. "' with " .. fc.minions .. " beside her")
        end
        if fc and string.find(text, "go with her", 1, true) and fc.minions < 2 then
            fail("F3", N.tag .. ": '" .. text .. "' with " .. fc.minions .. " beside her")
        end
        local n = string.match(text, "^The last (%a+) turn tail")
        if fc and n then
            add("F3", "last_few_counted")
            if WORDS[n] ~= fc.alive then
                fail("F3", N.tag .. ": '" .. text .. "' with " .. fc.alive .. " standing")
            end
        end
        if string.find(text, "The last few turn tail", 1, true) then
            fail("F3", N.tag .. ": '" .. text .. "' (who's standing isn't counted)")
        end
        if fc and string.find(text, "The last one turns tail", 1, true) and fc.alive ~= 1 then
            fail("F3", N.tag .. ": '" .. text .. "' with " .. fc.alive .. " standing")
        end
        if string.find(text, "sees the fight turning", 1, true) or string.find(text, "takes one look at the fight turning", 1, true) then
            add("F13", "she_runs_when_losing")
            local b = fc and fc.boss
            if not b or (b.hp or 0) > (b.hp_max or 1) * 0.5 then
                fail("F13", N.tag .. ": '" .. text .. "' with her at " .. tostring(b and b.hp) .. " of " .. tostring(b and b.hp_max))
            end
        end
        if string.find(text, "The rest scatter", 1, true) then
            add("F3", "rest_scatter")
            local ran = #((night.scene and night.scene.foes_ran) or {})
            if ran < 2 then
                fail("F3", N.tag .. ": '" .. text .. "' when " .. ran .. " ran")
            end
        end
        if string.find(text, "the rest might break", 1, true) then
            local alive = standing(night)
            add("F3", "morale_hint")
            if alive < 2 then
                fail("F3", N.tag .. ": '" .. text .. "' about the last one standing")
            end
        end
    end
    if ev.kind == "battle" and ev.phase == "end" then
        N.flee_call = nil
    end
end)
case("F3", function()
    local fight = require "game.model.fight"
    local boss = { name = "Euryale", hp = 80, hp_max = 104, boss = true }
    local w = fight.flee_words({ boss = boss, boss_name = "Euryale" }, 0, 1)
    if string.find(w.boss_label, "Everyone", 1, true) or string.find(w.boss_log, "rest", 1, true) then
        fail("F3", "alone, she still has a side that runs: " .. w.boss_label .. " / " .. w.boss_log)
    end
    if string.find(w.boss_log, "turning", 1, true) then
        fail("F13", "at 80 of 104 she 'sees the fight turning': " .. w.boss_log)
    end
    boss.hp = 30
    w = fight.flee_words({ boss = boss, boss_name = "Euryale" }, 2, 3)
    if not string.find(w.boss_log, "turning", 1, true) or not string.find(w.boss_log, "two", 1, true) then
        fail("F3", "at 30 with two beside her: " .. w.boss_log)
    end
    w = fight.flee_words({}, 0, 1)
    if w.log ~= "The last one turns tail and runs." then
        fail("F3", "one left: " .. w.log)
    end
    add("F3", "unit_cases")
    add("F13", "unit_cases")
end)

-- F4: an ally's fall is said and answered; only the Mech powers down; the wrap-up remembers Telpur.
table.insert(watchers, function(R, N, ev)
    if ev.kind == "battle" and ev.phase == "start" then
        N.allies = {}
        for _, a in ipairs(ev.allies or {}) do
            N.allies[a.id] = a
        end
    elseif ev.kind == "turn" then
        if N.ally_fell then
            fail("F4", N.tag .. ": " .. N.ally_fell.name .. " fell, and nobody said a word")
            N.ally_fell = nil
        end
        for _, st in ipairs(ev.steps or {}) do
            local a = N.allies and N.allies[st.id]
            if st.kind == "death" and a then
                add("F4", "allies_fell")
                N.ally_fell = { name = a.name, said = false, answered = false }
            end

            -- (The Mech venting itself to a stop: its caption on the mat says it.)
            if st.kind == "feature" and st.name == "Overheats and shuts down" then
                N.vented = true
            end
            if st.kind == "feature" and st.name == "Powers down" then
                add("F4", "power_downs")
                if not (a and a.monster == "steam_mech") then
                    fail("F4", N.tag .. ": " .. tostring(a and a.name or st.id) .. " powered down, and it isn't the Mech")
                end
            end
        end
        if N.ally_fell and N.vented then
            N.ally_fell.said = true
        end
        N.vented = nil
    elseif N.ally_fell and (ev.kind == "narrate" or ev.kind == "say") then
        local af = N.ally_fell
        if ev.kind == "narrate" and ev.text and string.find(ev.text, af.name, 1, true) then
            af.said = true
        elseif ev.kind == "say" and af.said then
            af.answered = true
        end
        if af.said and af.answered then
            add("F4", "falls_said_and_answered")
            N.ally_fell = nil
        end
    end
    if ev.kind == "scene" and N.night.scene and N.night.scene.room == "thanks" then
        N.in_thanks = true
    end
    if N.in_thanks and ev.kind == "narrate" and ev.text and string.find(ev.text, "Telpur", 1, true) then
        N.thanks_telpur = true
    end
end)
table.insert(night_end, function(R, N)
    if N.ally_fell then
        fail("F4", N.tag .. ": " .. N.ally_fell.name .. " fell, and nobody said a word")
    end
    local f = R.c.adv.flags
    if N.in_thanks and (f.telpur_along or f.telpur_fell) then
        add("F4", "wrap_ups_with_telpur_along")
        if not N.thanks_telpur then
            fail("F4", N.tag .. ": Telpur came along, and the thanks scene in his own shop never mentions him")
        end
    end
end)

-- F5: a companion is introduced once: found, or joined, or given between sessions.
table.insert(watchers, function(R, N, ev)
    local text = ev.text
    if not text or (ev.kind ~= "narrate" and ev.kind ~= "say") then
        if ev.kind == "battle" and ev.phase == "start" then
            for _, a in ipairs(ev.allies or {}) do
                if a.monster == "steam_mech" then
                    add("F5", "mech_fights")
                    if not N.mech_named or N.mech_named == "no" then
                        fail("F5", N.tag .. ": " .. tostring(a.name) .. " joins the fight with no word that it's there"
                            .. (N.mech_first and (" (first heard: '" .. N.mech_first .. "')") or ""))
                    end
                end
            end
        end
        return
    end
    -- (The first word of the Mech tonight says it's there: not its red switch, as if it always was.)
    local mech = R.c.adv.mech_name
    if mech and not N.mech_named and string.find(text, mech, 1, true) then
        N.mech_named = string.find(text, "clanks up", 1, true) or string.find(text, "My name is", 1, true)
            or string.find(text, "looks down at them", 1, true) or false
        if not N.mech_named then
            N.mech_named = "no"
            N.mech_first = text
        end
    end
    if string.find(text, "names him Exhibit B", 1, true) then
        add("F5", "exhibit_b_found")
        R.exhibit_b_met = (R.exhibit_b_met or 0) + 1
    elseif string.find(text, "new friend tonight", 1, true) then
        add("F5", "exhibit_b_joined")
        R.exhibit_b_met = (R.exhibit_b_met or 0) + 1
    end
    if (R.exhibit_b_met or 0) > 1 and not R.exhibit_b_twice then
        R.exhibit_b_twice = true
        fail("F5", N.tag .. ": Exhibit B is introduced a second time: '" .. text .. "'")
    end
    if string.find(text, "new shoelace tonight", 1, true) then
        add("F5", "shoelace_introduced")
        R.shoelace_met = true
    elseif string.find(text, "talking shoelace", 1, true) then
        add("F5", "shoelace_lines")
        if not R.shoelace_met then
            fail("F5", N.tag .. ": the talking shoelace speaks up before anyone said Pip has it")
            R.shoelace_met = true
        end
    end
end)

-- F18: credit for a nudge only when the table was split; a hint against an agreed table gets a
-- grumble; the hero who acts on a party call backs it; a card's lead votes for what it says they
-- want; a hero's portrait is theirs.
local MODULE = adventure.data
table.insert(watchers, function(R, N, ev)
    local night = N.night
    if ev.kind == "decision" and string.find(ev.card.id or "", "^mus_fork_") then
        N.fork_split = not string.find(ev.card.text or "", "more or less decided", 1, true)
        N.fork_card = true
        N.fork_pick = nil
    end
    if ev.kind == "decision" and ev.card.id == "mus_reach" then
        for key, port in pairs(MODULE.portraits or {}) do
            if string.find(ev.card.text or "", port.painting, 1, true) then
                add("F18", "portraits")
                if not (night.actor and night.actor.key == key) then
                    fail("F18", N.tag .. ": " .. key .. "'s painting, and " .. tostring(night.actor and night.actor.char) .. " reaches for it")
                end
            end
        end
    end
    local text = ev.text
    if not text then
        return
    end
    if ev.kind == "narrate" and N.fork_card and string.find(text, "^The table decides: ") then
        if string.find(text, "(on your nudge)", 1, true) then
            add("F18", "nudges_credited")
            if not N.fork_split then
                fail("F18", N.tag .. ": '" .. text .. "' when they'd already agreed")
            end
        end
        if not N.fork_split and N.hinted and not N.grumbled then
            fail("F18", N.tag .. ": a hint turned an agreed table round without a word")
        end
        N.fork_card, N.hinted, N.grumbled = nil, nil, nil
    end
    if ev.kind == "narrate" and N.fork_card and string.find(text, "never did look properly at", 1, true) then
        N.hinted = true
        if not N.fork_split then
            add("F18", "hints_against_an_agreed_table")
        end
    end
    if ev.kind == "say" and N.hinted and string.find(text, "We'd all just agreed", 1, true) then
        N.grumbled = true
        add("F18", "grumbles")
    end
    if ev.kind == "scene" or (ev.kind == "narrate" and N.hinted and string.find(text, "go on anyway", 1, true)) then
        if N.fork_card and N.hinted and not N.fork_split and not N.grumbled then
            fail("F18", N.tag .. ": a hint turned an agreed table round without a word")
        end
        N.fork_card, N.hinted, N.grumbled = nil, nil, nil
    end
    -- A party card: the lead says what the card says they want, and whoever acts backs the call.
    if N.party_key and N.party_key ~= night.moment_key then
        N.party_card, N.proposal, N.backers, N.party_key = nil, nil, nil, nil
    end
    if ev.kind == "narrate" and night.party_choice and night.moment_key and not N.party_card then
        N.party_key = night.moment_key
        for _, m in ipairs(MODULE.moments) do
            if m.id == night.moment_key and m.party then
                N.party_card = m
                N.lead = night.actor and night.actor.key
                N.proposal = m.proposes and m.options[m.proposes].want or nil
            end
        end
    end
    if ev.kind == "say" and N.proposal and ev.who == N.lead and string.find(text, "^Let's ") then
        add("F18", "proposals_voiced")
        if not string.find(string.lower(text), string.lower(N.proposal), 1, true) then
            fail("F18", N.tag .. ": the card says " .. N.lead .. "'s hero wants to " .. N.proposal .. ", and they say '" .. text .. "'")
        end
    end
    if ev.kind == "narrate" and N.party_card and string.find(text, "^The table decides: ") then
        -- (Who backed it, from what was said: "(Mara and Sam's idea)", or everyone.)
        local want, who = string.match(text, "^The table decides: (.-) %((.-)'s idea%)%.$")
        want = want or string.match(text, "^The table decides: (.-)%.$")
        local chosen
        for _, o in ipairs(N.party_card.options) do
            if o.want and want and string.find(want, o.want, 1, true) == 1 then
                chosen = o
            end
        end
        if not string.find(text, "(on your nudge)", 1, true) and not (chosen and chosen.roll and chosen.roll.best) then
            N.backers = {}
            for _, p in ipairs(night.players) do
                if not who or string.find(who, p.name, 1, true) then
                    table.insert(N.backers, p)
                end
            end
        end
        N.party_card, N.proposal = nil, nil
    elseif N.backers and night.actor and (ev.kind == "narrate" or ev.kind == "roll_where" or ev.kind == "roll") then
        local ok = false
        for _, p in ipairs(N.backers) do
            ok = ok or p == night.actor
        end
        add("F18", "party_calls_acted_on")
        if not ok then
            fail("F18", N.tag .. ": " .. tostring(night.actor and night.actor.char) .. " acts on a call their player voted against")
        end
        N.backers = nil
    end
end)

-- F10: one inventory. The shelf sells only what nobody owns, the buyer pays and carries it, a line
-- that says someone has something reads their pack, used up is gone, and the boss-night lore check
-- remembers the book and the tapestry.
local items_ok, items = pcall(require, "game.model.items")
local function char_key(c, char)
    for _, p in ipairs(c.players) do
        if p.char == char then
            return p.key
        end
    end
end
local function holds(c, key, id)
    if not (items_ok and items.held_by) then
        return false
    end
    for _, it in ipairs(items.held_by(c, key)) do
        if (it.thing == id or it.id == id) and not it.gone then
            return true
        end
    end
    return false
end
local HAS_LINES = {
    { "^(%a+) fights with the twin daggers", "daggers", "twin_daggers" },
    { "^(%a+) has the polished cupboard door ready", "mirror" },
    { "^(%a+) has the Mech manual open", "manual" },
    { "^(%a+) has the vorpal sword out", "vorpal_sword", "vorpal_sword" },
    { "(%a+) has Telpur's paint%-touched dagger", "paint_dagger" },
}
table.insert(watchers, function(R, N, ev)
    local c = R.c
    local text = ev.text
    if ev.kind == "battle" and ev.phase == "start" then
        N.potions_before = {}
        for _, p in ipairs(c.players) do
            N.potions_before[p.key] = items_ok and items.count and items.count(c, p.key, "potion_healing") or nil
        end
        N.drank = {}
    elseif ev.kind == "turn" and N.drank then
        for _, st in ipairs(ev.steps or {}) do
            if st.kind == "feature" and st.name == "Potion of Healing" and st.id then
                N.drank[st.id] = (N.drank[st.id] or 0) + 1
                add("F10", "potions_drunk")
                if N.potions_before and N.potions_before[st.id] and N.potions_before[st.id] < N.drank[st.id] then
                    fail("F10", N.tag .. ": " .. st.id .. " drinks a potion they don't have in their pack")
                end
            end
        end
    elseif ev.kind == "battle" and ev.phase == "end" and N.drank then
        for key, n in pairs(N.drank) do
            local before = N.potions_before and N.potions_before[key]
            local now = items_ok and items.count and items.count(c, key, "potion_healing") or nil
            if before and now and now ~= before - n then
                fail("F10", N.tag .. ": " .. key .. " drank " .. n .. " potion(s), and their pack went from " .. tostring(before) .. " to " .. tostring(now))
            else
                add("F10", "potions_left_the_pack")
            end
        end
        N.drank = nil
    end
    if not text or (ev.kind ~= "narrate" and ev.kind ~= "say") then
        return
    end
    -- The shelf: what the table buys is something nobody owns, and it costs what it says.
    local want = string.match(text, "^The table decides: buy the (.-)[%.%(]")
    if want and ev.kind == "narrate" then
        want = string.gsub(want, "%s+$", "")
        add("F10", "purchases")
        if want == "book on gorgon-worshippers" then
            for _, p in ipairs(c.players) do
                if holds(c, p.key, "gorgon_book") then
                    fail("F10", N.tag .. ": the gorgon book is sold again, and " .. p.char .. " already has it")
                end
            end
            -- (A second purchase of one book with no inventory at all is still the same book twice.)
            if R.book_bought then
                fail("F10", N.tag .. ": the gorgon book is sold a second time")
            end
            R.book_bought = true
        end
        N.francs_at_purchase = c.adv.francs
    end
    local reader = string.match(text, "^The Tenets of the Rotting Temple%. (%a+) starts reading")
    if reader then
        N.book_reader = char_key(c, reader)
        add("F10", "book_read")
    end
    for _, h in ipairs(HAS_LINES) do
        local who = string.match(text, h[1])
        if who then
            add("F10", "has_lines")
            local key = char_key(c, who)
            if not (key and (holds(c, key, h[2]) or (h[3] and holds(c, key, h[3])))) then
                fail("F10", N.tag .. ": '" .. text .. "' and " .. who .. "'s pack doesn't have it")
            end
        end
    end
    if string.find(text, "Out come Telpur's fire arrows", 1, true) then
        add("F10", "arrows_used")
        if R.arrows_used_up then
            fail("F10", N.tag .. ": the fire arrows come out again after they were used up")
        end
        R.arrows_used_up = true
    end
    if string.find(text, "can't remember a single story about Gorgon sisters", 1, true) then
        add("F10", "lore_misses")
        local here = false
        for _, p in ipairs(N.night.players) do
            here = here or holds(c, p.key, "gorgon_book")
        end
        if here or c.adv.flags.tapestry then
            fail("F10", N.tag .. ": '" .. text .. "' with " .. (here and "the gorgon book at the table" or "the tapestry seen"))
        end
    end
end)
table.insert(night_end, function(R, N)
    local c = R.c
    if N.book_reader then
        if holds(c, N.book_reader, "gorgon_book") then
            add("F10", "the_reader_has_the_book")
        else
            fail("F10", N.tag .. ": " .. N.book_reader .. " started reading the book, and it isn't in their pack")
        end
    end
    -- The sheet shows what's in the pack.
    if items_ok and items.held_by and items.count and items.about then
        local sheet = require "game.model.sheet"
        for _, p in ipairs(c.players) do
            local sh = sheet.build(c, p.key)
            local gear = table.concat(sh.gear or {}, ", ")
            local n = items.count(c, p.key, "potion_healing")
            if (n > 0) ~= (string.find(gear, "healing potion", 1, true) ~= nil) then
                fail("F10", N.tag .. ": " .. p.key .. " has " .. n .. " potions, and their sheet says '" .. gear .. "'")
            end
            for _, it in ipairs(items.held_by(c, p.key)) do
                local name = items.about(it).name
                if it.id ~= "potion_healing" and not string.find(gear, name, 1, true) then
                    fail("F10", N.tag .. ": " .. p.key .. " carries " .. name .. ", and it isn't on their sheet")
                else
                    add("F10", "sheet_lines")
                end
            end
        end
    end
end)
-- An old save's things move into the inventory (and save_check covers the round trip).
case("F10", function()
    local c = new_campaign(77, "careful")
    c.items, c.items_started = nil, nil
    local st = c.adv
    st.flags.daggers, st.flags.arrows, st.flags.shoelace = true, true, true
    st.marks.mirror = { week = 2, room = "hunting" }
    st.holders = { mirror = "sam", arrows = "dev" }
    st.items_used = { arrows = 3 }
    c.items = { { id = "twin_daggers", holder = "jess", week = 1 } }
    c.party_state = { pcs = { mara = { res = { potions = 0 } } } }
    items.start(c)
    local function who(id)
        local it, k = items.holding(c, id)
        return k, it
    end
    local k = who("mirror")
    if k ~= "sam" then
        fail("F10", "migration: the cupboard door should be Sam's, is " .. tostring(k))
    end
    if items.owned(c, "arrows") then
        fail("F10", "migration: the fire arrows were used up, and they're back")
    end
    if who("shoelace") ~= "jess" then
        fail("F10", "migration: the shoelace should be Jess's")
    end
    local _, d = who("twin_daggers")
    if not (d and d.thing == "daggers") then
        fail("F10", "migration: the twin daggers don't know they're the chamber's daggers")
    end
    if items.count(c, "mara", "potion_healing") ~= 0 or items.count(c, "dev", "potion_healing") ~= 1 then
        fail("F10", "migration: potions in the packs " .. items.count(c, "mara", "potion_healing") .. "/" .. items.count(c, "dev", "potion_healing"))
    end
    -- Buying: Francs leave, the thing leaves the shelf, it's the buyer's.
    st.francs = 10
    adventure.apply(c, { mark = "know", spend = 4 }, "gift_shop", "mara")
    if st.francs ~= 6 or select(2, items.holding(c, "gorgon_book")) ~= "mara" then
        fail("F10", "buying the book: " .. st.francs .. " Francs left, holder " .. tostring(select(2, items.holding(c, "gorgon_book"))))
    end
    add("F10", "unit_cases")
end)

-- F11: the party splits only when nothing's dangerous in the room, not in the wrap-up, not twice in
-- two sessions, and a hero who wandered off doesn't act in the scene they left.
table.insert(watchers, function(R, N, ev)
    local night = N.night
    local sc = night.scene
    if ev.kind == "scene" then
        N.away = nil
    end
    if ev.kind == "decision" and ev.card.id == "split_party" then
        add("F11", "split_cards")
        if sc and (sc.boss or sc.epilogue or sc.showdown or (sc.encounter and not sc.no_fight and not sc.resolved and not sc.result)) then
            fail("F11", N.tag .. ": the party splits in " .. tostring(sc.room) .. ", with " .. ((sc.epilogue and "the wrap-up going on")
                or "danger in the room"))
        end
        if R.last_split and N.w - R.last_split < 2 then
            fail("F11", N.tag .. ": a split card in week " .. N.w .. " after one in week " .. R.last_split)
        end
        R.last_split = N.w
        N.split_card = true
    end
    if N.split_card and sc and sc.split and not N.away then
        N.away = sc.split.away
        add("F11", "splits")
    end
    if N.away and sc and not sc.split then
        N.away = nil
    end
    if N.away then
        local who = (ev.kind == "check" or ev.kind == "roll" or ev.kind == "roll_where") and (ev.actor)
            or (ev.kind == "say" and ev.ic and ev.who) or nil
        if who and N.away[who] then
            fail("F11", N.tag .. ": " .. who .. "'s hero wandered off, and acts in the scene they left (" .. ev.kind
                .. (ev.text and (": '" .. ev.text .. "'") or "") .. ")")
        elseif who then
            add("F11", "acts_by_heroes_still_here")
        end
    end
end)

for _, style in ipairs(STYLES) do
    for run = 1, RUNS do
        local seed = 500 + run * 31
        local ok, err = pcall(play, seed, style)
        if not ok then
            fail("run", "seed " .. seed .. " " .. style .. ": " .. tostring(err))
        else
            add("run", "prologues")
        end
    end
end

-- The report -----------------------------------------------------------------------------------

local total = 0
for _, item in ipairs(ITEMS) do
    if not E[item] and not fails[item] then
        fail(item, "nothing seen: no run or case reached this item")
    end
    local parts = {}
    for k, v in pairs(E[item] or {}) do
        table.insert(parts, k .. " " .. v)
    end
    table.sort(parts)
    local f = fails[item]
    print(string.format("%-4s %-36s %s%s", item, NAMES[item], #parts > 0 and table.concat(parts, ", ") or "(nothing seen)",
        f and ("  FAILS " .. f.n) or ""))
    for _, m in ipairs(f or {}) do
        print("     FAIL " .. m)
    end
    total = total + (f and f.n or 0)
end
print(total == 0 and "roadmap truth check: every item holds" or ("roadmap truth check: " .. total .. " failures"))
os.exit(total == 0 and 0 or 1)
