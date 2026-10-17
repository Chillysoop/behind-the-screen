-- Do the players play the story card? (the card-led night, October 16: none of the stock moves named
-- the scene's goal, and a scene called "Find the hidden map" played as generic exploring). Plays
-- whole slices with each simulated DM and counts, in the scenes that aren't fights:
--   * hero checks that come from the scene's goal (its approaches) or are aimed at its person:
--     at least 70% (game/data/goal_play.lua, night.hero_action);
--   * scenes with a goal whose last roll is the goal's own moment;
--   * scenes with a goal where a player says what they're there to do;
--   * wandering off: every time with a way back to the goal on the hand, and a reason (a card in
--     play) whenever one's to hand;
--   * the table's chatter about the card;
--   * the simplicity pass (October 16): the scene's final roll says it's the final roll and names the
--     goal; a party splitting up can be steered back to it; a goal's answer comes at the scene's end,
--     never before its final roll; a fight never asks "so what are we doing here?";
--   * every goal card has its own entry in goal_play.lua (no card falls back to the default).
-- Run from the project root: texlua tools/tests/card_check.lua [runs]

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path
unpack = unpack or table.unpack

local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local bots = require "slice_bots"
local content = require "game.model.content"

local RUNS = tonumber(arg and arg[1]) or 4

local ok_all = true
local fails = {}
local function check(cond, what, detail)
    print(string.format("  [%s] %s  -  %s", cond and "PASS" or "FAIL", what, detail or ""))
    ok_all = ok_all and cond
end
local function fail(msg)
    if #fails < 20 then
        table.insert(fails, msg)
    end
end

-- Every goal card has its own entry.
local missing = {}
for _, c in ipairs(content.by_kind.goal) do
    if not content.goal_play[c.id] then
        table.insert(missing, c.id)
    end
end
check(#missing == 0, "Every goal card says how the heroes play it", #missing == 0 and (#content.by_kind.goal .. " goals")
    or table.concat(missing, ", "))
-- And every entry's lines are whole: approaches with a skill and all three lines.
local bad = {}
local skills = require "game.rules.skills"
for id, e in pairs(content.goal_play) do
    for _, a in ipairs(e.approaches or {}) do
        if not (a.skill and a.say and a.win and a.lose) or not skills.name(a.skill) then
            table.insert(bad, id)
        end
    end
    if e.moment and not (e.moment.text and e.moment.skill) then
        table.insert(bad, id .. " (moment)")
    end
end
check(#bad == 0, "Every approach has a skill, what they say, and how it lands", #bad == 0 and "ok" or table.concat(bad, ", "))

local T = { checks = 0, led = 0, goal_led = 0, goal_scenes = 0, intents = 0, climaxes = 0, moments = 0, drifts = 0,
            drift_back = 0, drift_reason = 0, talk = 0, scenes = 0, finals = 0, finals_named = 0, splits = 0, splits_back = 0,
            early = 0, goal_answers = 0, fight_goal_asks = 0 }
local kind_goal = content.kind_names and content.kind_names.goal or "Goal"

for _, dm_key in ipairs(bots.ORDER) do
    local dm = bots.DMS[dm_key]
    for run = 1, RUNS do
        local seed = 17000 + run * 43 + #dm_key
        local c = campaign_mod.new(seed)
        local rng = rng_mod.new(seed + 7)
        c:session_zero(dm.s0)
        for w = 1, 4 do
            local prep = c:start_week()
            bots.prep(dm, c, prep, rng)
            local night = c:start_night()
            bots.play_night(night, rng, dm, function(ev, nt)
                local sc = nt.scene
                local fight = sc and (sc.type == "combat" or sc.type == "set_piece")
                -- (A scene with neither a goal nor a person in it has no card to play.)
                local card = sc and ((sc.comps.goal and not nt:muted(sc.comps.goal)) or (sc.comps.cast and not nt:muted(sc.comps.cast)))
                if ev.kind == "check" and sc and not fight and card then
                    T.checks = T.checks + 1
                    if ev.led then
                        T.led = T.led + 1
                    end
                    if ev.led == "goal" then
                        T.goal_led = T.goal_led + 1
                    end
                elseif ev.kind == "say" and ev.card_talk then
                    T.talk = T.talk + 1
                elseif ev.kind == "roll_where" and ev.final then
                    T.finals = T.finals + 1
                    local g = sc and sc.comps.goal
                    if g and not nt:muted(g) then
                        if ev.final.goal == g.name and string.find(ev.text or "", "final roll", 1, true) then
                            T.finals_named = T.finals_named + 1
                        else
                            fail("week " .. w .. ": the final roll's card doesn't name " .. g.id)
                        end
                    else
                        T.finals_named = T.finals_named + 1
                    end
                elseif ev.kind == "decision" and ev.card and ev.card.id == "split_party" then
                    T.splits = T.splits + 1
                    for _, o in ipairs(ev.card.options or {}) do
                        if string.find(o.label or "", "Steer them back", 1, true) then
                            T.splits_back = T.splits_back + 1
                            break
                        end
                    end
                elseif ev.kind == "clue" and sc and sc.comps.goal then
                    local g = sc.comps.goal
                    if ev.id == g.id or ev.id == g.pays then
                        T.goal_answers = T.goal_answers + 1
                        if not sc.climax_ran and not sc.outcome then
                            T.early = T.early + 1
                            fail("week " .. w .. ": " .. g.id .. "'s answer came before the scene's final roll")
                        end
                    end
                elseif ev.kind == "improv" and fight and ev.slot == kind_goal then
                    T.fight_goal_asks = T.fight_goal_asks + 1
                    fail("week " .. w .. ": a fight asked what they're doing there")
                elseif ev.kind == "improv" and ev.drift and sc then
                    T.drifts = T.drifts + 1
                    local back, reason = false, false
                    for _, cd in ipairs(ev.cards or {}) do
                        back = back or cd.back
                    end
                    if back then
                        T.drift_back = T.drift_back + 1
                    else
                        fail("week " .. w .. ": the party wandered off with no way back, in scene " .. tostring(sc.index))
                    end
                    if nt.drift_reason then
                        T.drift_reason = T.drift_reason + 1
                    end
                end
            end)
            for _, sc in ipairs(night.scenes) do
                if sc.terrain then
                    T.scenes = T.scenes + 1
                    local goal = sc.comps.goal
                    if goal and not night:muted(goal) then
                        T.goal_scenes = T.goal_scenes + 1
                        if sc.intent_said then
                            T.intents = T.intents + 1
                        end
                    end
                    if sc.climax_ran and goal and not night:muted(goal) then
                        T.climaxes = T.climaxes + 1
                        T.moments = T.moments + (sc.moment_led and 1 or 0)
                    end
                end
            end
            c:finish_night()
        end
    end
end

local share = T.checks > 0 and T.led / T.checks or 0
check(share >= 0.7, "Hero checks play the card: from the goal's approaches or aimed at its person (target 70%)",
    string.format("%d of %d (%.0f%%), %d from the goal itself", T.led, T.checks, share * 100, T.goal_led))
check(T.goal_scenes > 0 and T.intents >= T.goal_scenes * 0.9, "A player says what they're there to do (target 90% of scenes with a goal)",
    string.format("%d of %d scenes", T.intents, T.goal_scenes))
check(T.climaxes > 0 and T.moments >= T.climaxes * 0.8, "The scene's last roll is the goal's own moment (target 80%)",
    string.format("%d of %d last rolls", T.moments, T.climaxes))
check(T.drifts == 0 or T.drift_back == T.drifts, "Wandering off always offers a way back (the goal, else who or where the scene is)",
    string.format("%d of %d, %d with a reason from a card in play", T.drift_back, T.drifts, T.drift_reason))
check(T.talk > 0, "The table talks about the card in front of them", T.talk .. " lines")
check(T.finals > 0 and T.finals_named == T.finals, "The scene's final roll says so, and names the goal",
    string.format("%d of %d final rolls", T.finals_named, T.finals))
check(T.splits_back == T.splits, "A party splitting up can be steered back to the goal",
    string.format("%d of %d splits", T.splits_back, T.splits))
check(T.early == 0, "A goal's answer comes at the scene's end, never before its final roll",
    string.format("%d answers, %d early", T.goal_answers, T.early))
check(T.fight_goal_asks == 0, "A fight never asks what they're doing there", T.fight_goal_asks .. " asked")

for _, f in ipairs(fails) do
    print("  problem: " .. f)
end
print(ok_all and "CARD CHECK OK" or "CARD CHECK FAILED")
os.exit(ok_all and 0 or 1)
