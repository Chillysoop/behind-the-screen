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
                museum_week.answer_chat(c, m, ({ careful = 1, random = rng:int(1, 3), careless = 3 })[style])
            end
        end
        for _, pr in ipairs(c.adv.prompts) do
            if pr.kind == "request" then
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
