-- A11, loose ends from the history review: a check for each bullet that the game model can show
-- (the screen ones are in gui_smoke's dumps). Plays campaigns with the three simulated DMs and
-- watches every event, plus a few checks on the card data. Run from the project root:
--   texlua tools/tests/a11_check.lua [campaigns per DM] [weeks]
-- Exit code 1 if a check fails.

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path

local content = require "game.model.content"
local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local deck = require "game.model.deck"
local night_mod = require "game.model.night"
local util = require "game.model.util"
local bots = require "slice_bots"

local RUNS = tonumber(arg and arg[1]) or 12
local WEEKS = tonumber(arg and arg[2]) or 4

local checks, fails = {}, {}
local function check(ok, name, detail)
    table.insert(checks, { ok = ok and true or false, name = name, detail = detail or "" })
end
local function fail(msg)
    if #fails < 25 then
        table.insert(fails, msg)
    end
end

local function read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

-- Every call shows (data): each option says what happens, and every fight call the cards make is
-- one the fight code acts on.
do
    local engine = read("game/model/fight.lua") .. read("game/rules/ai.lua") .. read("game/rules/battle.lua")
    local unhandled, silent, n = {}, {}, 0
    for _, d in ipairs(require "game.data.decisions") do
        for _, o in ipairs(d.options or {}) do
            n = n + 1
            if not (o.log or o.roll) then
                table.insert(silent, d.id)
            end
            -- ("let" is letting it ride: the fight goes on as it was, and the log says so.)
            if o.battle and o.battle ~= "let" and not string.find(engine, '"' .. o.battle .. '"', 1, true) then
                table.insert(unhandled, d.id .. ":" .. o.battle)
            end
            local text = (o.log or "") .. (o.label or "")
            if string.find(text, "kicks the door in", 1, true) then
                table.insert(silent, d.id .. " (the door)")
            end
        end
    end
    check(#unhandled == 0 and #silent == 0, "Every call shows: each option logs or rolls, and every fight call is acted on",
        n .. " options" .. (#unhandled > 0 and ("; unhandled " .. table.concat(unhandled, ", ")) or "")
            .. (#silent > 0 and ("; silent " .. table.concat(silent, ", ")) or ""))
end

-- The ruling prompts don't repeat the card's title ("So close..." / "So close. How...").
do
    local dup = {}
    for tier, r in pairs(content.rulings) do
        if string.find(string.lower(r.prompt), "so close", 1, true) or string.find(string.lower(r.prompt), "great roll", 1, true)
            or string.find(string.lower(r.prompt), "bad roll", 1, true) then
            table.insert(dup, tier)
        end
    end
    check(#dup == 0, "Nobody asks \"how close\" twice: ruling prompts don't repeat the card's title", #dup == 0 and "ok" or table.concat(dup, ", "))
end

-- Scrapbook moments are never a word or two ("S2 Click").
do
    local bad = {}
    for _, t in ipairs({ "Click. The lock gives way.", "Yes! You did it.", "Thunk. The bolt slides home, and the door opens." }) do
        local m = night_mod.moment_of(t)
        local words = 0
        for _ in string.gmatch(m, "%a+") do
            words = words + 1
        end
        if words < 3 then
            table.insert(bad, m)
        end
    end
    check(#bad == 0, "A scrapbook moment is a whole moment, not \"Click\"", #bad == 0 and "ok" or table.concat(bad, " | "))
end

local T = {
    callouts = 0, callouts_named = 0, sus_rows = 0, sus_named = 0,
    big_rolls = 0, rulings = 0, cooks_events = 0, hidden_rulings = 0, hidden_with_cook = 0, open_with_cook = 0, cooked = 0,
    cast_improv = 0, cast_improv_bad = 0,
    openings = 0, opening_bad = 0, opening_new_again = 0,
    befriend = 0, befriend_bad = 0,
    friction = 0, friction_named = 0,
    moments = 0, moments_short = 0,
    tactics_marked = 0, tactics_marks_seen = 0,
}

-- The beat openings that name a place, and the place lists they need.
local function beat_named(text, campaign)
    local beat = campaign:arc_beat()
    if not beat or not beat.open_place then
        return nil
    end
    if text == beat.open or (beat.open_if and text == beat.open_if.text) then
        return "named", beat
    end
    return nil, beat
end

for _, dm_key in ipairs(bots.ORDER) do
    local dm = bots.DMS[dm_key]
    for run = 1, RUNS do
        local seed = 11000 + run * 37 + #dm_key
        local c = campaign_mod.new(seed)
        local rng = rng_mod.new(seed + 3)
        c:session_zero(dm.s0)
        for w = 1, WEEKS do
            local prep = c:start_week()
            bots.prep(dm, c, prep, rng)
            local night = c:start_night()
            local rolls_where = 0
            local function watch(ev, nt)
                if ev.kind == "cook" then
                    T.cooks_events = T.cooks_events + 1
                elseif ev.kind == "roll_where" then
                    rolls_where = rolls_where + 1
                    T.big_rolls = T.big_rolls + 1
                elseif ev.kind == "ruling" then
                    T.rulings = T.rulings + 1
                    if ev.where == "hidden" then
                        T.hidden_rulings = T.hidden_rulings + 1
                        T.hidden_with_cook = T.hidden_with_cook + (ev.cook and 1 or 0)
                    elseif ev.cook then
                        T.open_with_cook = T.open_with_cook + 1
                    end
                elseif ev.kind == "narrate" and ev.style == "warn" and ev.text and string.find(ev.text, "The table goes quiet", 1, true) then
                    T.callouts = T.callouts + 1
                    if string.find(ev.text, " noticed ", 1, true) then
                        T.callouts_named = T.callouts_named + 1
                    else
                        fail("a callout with no cause: " .. ev.text)
                    end
                elseif ev.kind == "narrate" and ev.style == "opening" then
                    T.openings = T.openings + 1
                    local named, beat = beat_named(ev.text, c)
                    local loc = nt.scenes[1] and nt.scenes[1].comps.location
                    if beat and beat.open_place then
                        local places = type(beat.open_place) == "table" and beat.open_place or { beat.open_place }
                        if named and not (loc and util.contains(places, loc.id)) then
                            T.opening_bad = T.opening_bad + 1
                            fail("week " .. c.week .. ": the opening names a place scene 1 isn't at (" .. tostring(loc and loc.id) .. ")")
                        end
                        if named and loc and deck.returning(c, loc) and beat.open_again then
                            T.opening_new_again = T.opening_new_again + 1
                            fail("week " .. c.week .. ": the opening presents " .. loc.id .. " as new, but they've been there")
                        end
                    end
                elseif ev.kind == "improv" and ev.slot == content.kind_names.cast then
                    T.cast_improv = T.cast_improv + 1
                    for _, cd in ipairs(ev.cards or {}) do
                        if not (cd.comp and cd.comp.kind == "cast") then
                            T.cast_improv_bad = T.cast_improv_bad + 1
                            fail("an improv Cast slot offered " .. tostring(cd.comp and cd.comp.id or cd.name or "a stock move"))
                            break
                        end
                    end
                elseif ev.kind == "decision" and ev.card then
                    if ev.card.id == "befriend_villain" then
                        T.befriend = T.befriend + 1
                        local cast = nt.scene and nt.scene.comps.cast
                        if not night_mod.cast_is(cast, "hostile") then
                            T.befriend_bad = T.befriend_bad + 1
                            fail("\"Hold on, let's talk\" with " .. tostring(cast and cast.id))
                        end
                    elseif string.sub(ev.card.id, 1, 9) == "friction_" then
                        T.friction = T.friction + 1
                        if not string.find(ev.card.text, "Not everyone else is", 1, true) then
                            T.friction_named = T.friction_named + 1
                        end
                    end
                elseif ev.kind == "turn" then
                    for _, st in ipairs(ev.steps or {}) do
                        if st.kind == "condition" and st.name == "Targeted" then
                            T.tactics_marks_seen = T.tactics_marks_seen + 1
                        end
                    end
                end
            end
            bots.play_night(night, rng, dm, watch)
            for _, d in ipairs(night.decisions) do
                local card = d.card == "tactics" and content.triggered.tactics or nil
                local o = card and card.options[d.option]
                if card and card.id == "tactics" and o and (o.battle == "squishy" or o.battle == "big") then
                    T.tactics_marked = T.tactics_marked + 1
                end
            end
            for _, r in ipairs(night.rulings) do
                T.cooked = T.cooked + (r.cooked and 1 or 0)
            end
            for _, h in ipairs(night.highlights) do
                T.moments = T.moments + 1
                local words = 0
                for _ in string.gmatch(h.text, "%a+") do
                    words = words + 1
                end
                if words < 3 then
                    T.moments_short = T.moments_short + 1
                    fail("a scrapbook moment of " .. words .. " words: " .. h.text)
                end
            end
            -- Past the night's call budget the die decides with no card (night.auto_rulings).
            T.rulings = T.rulings + (night.auto_rulings or 0)
            if rolls_where ~= #night.rulings then
                fail("week " .. c.week .. ": " .. rolls_where .. " big rolls but " .. #night.rulings .. " rulings")
            end
            local rep = c:finish_night()
            for _, row in ipairs(rep.players) do
                if row.long and row.long.suspicion.delta > 0.5 and row.tier then
                    T.sus_rows = T.sus_rows + 1
                    if row.suspicion_why then
                        T.sus_named = T.sus_named + 1
                    else
                        fail("week " .. c.week .. ": " .. row.name .. "'s suspicion rose with no cause")
                    end
                end
            end
            if dm.level and rep.level and rep.level.ready then
                c:level_up()
            end
        end
    end
end

check(T.callouts > 0 and T.callouts_named == T.callouts, "Every callout says what they noticed",
    T.callouts_named .. " of " .. T.callouts)
check(T.sus_rows > 0 and T.sus_named == T.sus_rows, "Every rise in suspicion names its source in the report",
    T.sus_named .. " of " .. T.sus_rows)
check(T.cooks_events == 0 and T.big_rolls > 0 and T.rulings == T.big_rolls and T.hidden_with_cook == T.hidden_rulings
    and T.open_with_cook == 0 and T.cooked > 0,
    "One card per big roll: the DC, then one ruling; cooking is the ruling's last button behind the screen",
    string.format("%d big rolls, %d rulings, %d cooked, %d separate cook cards", T.big_rolls, T.rulings, T.cooked, T.cooks_events))
check(T.cast_improv_bad == 0, "An improv Cast slot offers people, never stock moves", T.cast_improv .. " cast slots")
check(T.openings > 0 and T.opening_bad == 0 and T.opening_new_again == 0,
    "Read-alouds agree with the board: a named place is scene 1's, and never new once they've been there",
    T.openings .. " openings")
check(T.befriend_bad == 0, "\"Hold on, let's talk\" only with someone set against the party (roles from the cast data)",
    T.befriend .. " played")
check(T.friction == 0 or T.friction_named == T.friction, "The friction card names who's unhappy",
    T.friction_named .. " of " .. T.friction)
check(T.moments > 0 and T.moments_short == 0, "Scrapbook moments are whole moments", T.moments .. " moments")
check(T.tactics_marked == 0 or T.tactics_marks_seen >= T.tactics_marked, "Every blade turns: the hero they go after is tagged on the mat",
    T.tactics_marks_seen .. " tags for " .. T.tactics_marked .. " calls")

for _, f in ipairs(fails) do
    print("  problem: " .. f)
end
local ok = true
for _, ch in ipairs(checks) do
    print(string.format("  [%s] %s  -  %s", ch.ok and "PASS" or "FAIL", ch.name, ch.detail))
    ok = ok and ch.ok
end
os.exit(ok and 0 or 1)
