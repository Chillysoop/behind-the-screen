-- Makes pretend playtest logs, so the analyzer can be tried before real testers send
-- theirs. Each "tester" is a simulated DM who plays Session Zero and the four sessions,
-- answers the quick questions and the end survey the way their nights went, and
-- sometimes quits early. The lines are exactly what the game writes.
--   texlua tools/playtest/sample_logs.lua [testers]     -> tools/playtest/samples/*.jsonl

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path

local content = require "game.model.content"
local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local telemetry = require "game.model.telemetry"
local styles = require "dm_styles"

local TESTERS = tonumber(arg and arg[1]) or 6
local OUT = "tools/playtest/samples/"
os.execute("mkdir -p " .. OUT)

local STYLE = { "balanced", "story_threads", "random", "combat_only", "balanced", "no_prep" }

for t = 1, TESTERS do
    local rng = rng_mod.new(t * 7919 + 13)
    for _ = 1, 7 do
        rng:next() -- nearby seeds start out alike; shake them apart
    end
    local c = campaign_mod.new(5000 + t * 11)
    local style = styles[STYLE[(t - 1) % #STYLE + 1]]
    c:session_zero()
    local f = assert(io.open(OUT .. string.format("tester_%02d.jsonl", t), "w"))
    local quit_after = (t == 3) and 2 or (rng:chance(0.15) and rng:int(1, 3) or nil) -- one always stops early
    local fun_total = 0
    for w = 1, content.arc.SESSIONS do
        local prep = c:start_week()
        style.prep(prep, rng, c)
        local night = c:start_night()
        local ev = night:advance()
        while ev.kind ~= "done" do
            local a
            if ev.kind == "decision" then
                a = rng:int(1, #ev.card.options)
            elseif ev.kind == "improv" then
                a = 1
            elseif ev.kind == "roll_where" then
                a = rng:chance(0.7) and "open" or "hidden"
            elseif ev.kind == "roll" then
                a = rng:d20()
            elseif ev.kind == "ruling" then
                a = (ev.cook and rng:chance(0.2)) and "cook" or nil
            end
            ev = night:advance(a)
        end
        local rep = c:finish_night()
        local prep_seconds = 120 + rng:int(0, 480)
        f:write(telemetry.week_record(c, prep_seconds, night.clock * (0.55 + 0.3 * rng:next())), "\n")
        fun_total = fun_total + rep.average
        -- The quick questions, leaning on how the night went.
        local good = rep.average + rng:int(-15, 15)
        local prep_feel = prep_seconds > 480 and "Like homework" or (good > 60 and "Satisfying" or "Okay")
        local watch = good > 66 and "Paid off" or (good > 45 and "Was okay" or "Dragged")
        f:write(telemetry.week_survey(c, c.week, { prep = prep_feel, watch = watch, skipped = rng:chance(0.1) or nil }), "\n")
        if rep.level.ready then
            c:level_up()
        end
        if quit_after and w >= quit_after then
            break
        end
    end
    if not quit_after then
        local avg = fun_total / content.arc.SESSIONS
        local function scale(bias)
            return math.max(1, math.min(5, math.floor(avg / 20 + bias + rng:int(-1, 1) + 0.5)))
        end
        f:write(telemetry.slice_survey(c, {
            satisfying = scale(0.3), payoff = scale(0), homework = math.max(1, 6 - scale(0.5)), gut = scale(-0.3),
            next = avg > 62 and "Yes" or (avg > 48 and "Maybe" or "No"),
            text = {
                drag = rng:pick({ "", "Prep in week 3 took a while to figure out.", "The second fight went on too long.",
                                  "I wasn't sure what the quick questions wanted." }),
                favourite = rng:pick({ "", "Pip talking her way past the toll-taker.", "The bell tower cliffhanger.",
                                       "Sam's character finally getting a moment." }),
            },
        }), "\n")
    end
    f:close()
end
print("wrote " .. TESTERS .. " pretend logs to " .. OUT)
