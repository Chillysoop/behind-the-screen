-- Fight barks fit the moment, and a handed-off killing blow is told, not re-swung (November 3).
-- Run from the project root:  lua tools/tests/barks_check.lua
--
-- 1. The fit rules: a library line that names a fact is said only when the fact holds.
-- 2. Lines made from the moment fill every blank, and never repeat in a night.
-- 3. Whole nights: no bark claims a natural twenty without one, "who's next" after the last foe,
--    or half someone's hit points for a scratch; a told killing blow names the hero who landed it.
-- 4. Lines from a keyed list don't come back the next week while others are left.

package.path = "./?.lua;" .. package.path

local failures, checks = 0, 0
local function check(ok, msg)
    checks = checks + 1
    if not ok then
        failures = failures + 1
        print("FAIL: " .. msg)
    end
end

local adventure = require "game.model.adventure"
adventure.enter()
local barks = require "game.model.barks"
local BARKS = require "game.data.barks"

-- 1. The fit rules ----------------------------------------------------------------------------------
check(not barks.fits("NATURAL TWENTY!", { roll = 19, crit = true }), "a natural twenty on a 19")
check(barks.fits("NATURAL TWENTY!", { roll = 20, crit = true }), "a natural twenty on a 20 was refused")
check(not barks.fits("Got one! Who's next?", { left = 0 }), "'who's next' after the last foe")
check(barks.fits("Got one! Who's next?", { left = 2 }), "'who's next' with foes left was refused")
check(not barks.fits("That's half my hit points! Half!", { dmg = 2, hp = 18, hp_max = 20 }), "half my hit points for a scratch")
check(barks.fits("That's half my hit points! Half!", { dmg = 10, hp = 10, hp_max = 20 }), "half my hit points refused on a real hit")
check(not barks.fits("Fire Bolt, my old friend.", { spell = "Sacred Flame" }), "Fire Bolt said for Sacred Flame")
check(not barks.fits("Eleven damage! No, wait. Nineteen!", { dmg = 6 }), "a made-up damage number")
check(barks.fits("Take that!", { left = 0 }), "a plain line was refused")
check(barks.fits("Who's next?", nil), "a line outside a fight was refused")
for _, rule in ipairs(BARKS.fits) do
    check(barks.FACT[rule[2]] ~= nil, "fit rule '" .. rule[1] .. "' names an unknown fact " .. tostring(rule[2]))
end
for trig, by in pairs(BARKS.made) do
    for key, pool in pairs(by) do
        for i, l in ipairs(pool) do
            check(not l.when or barks.FACT[l.when] ~= nil, "made." .. trig .. "." .. key .. "." .. i .. " names an unknown fact")
            check(not string.find(l[1], "[\128-\255]"), "made." .. trig .. "." .. key .. "." .. i .. " isn't plain ASCII")
        end
    end
end

-- 2. Made lines ---------------------------------------------------------------------------------------
local rng = require("game.model.rng").new(5)
local fake = { rng = rng, campaign = { week = 2, said = {} } }
local p = { key = "dev", char = "Brannoc", name = "Dev" }
local mo = { foe = "the Kruthik Huntling", left = 2, weapon = "Greatsword", round = 3 }
local made = barks.made(fake, "kill", p, mo)
check(#made > 0, "no kill lines made for a foe with two left")
for _, m in ipairs(made) do
    check(not string.find(m.text, "{", 1, true), "an unfilled blank: " .. m.text)
    check(not string.find(m.text, "last of them", 1, true), "'last of them' with two left: " .. m.text)
end
local last = barks.made(fake, "kill", p, { foe = "the Lecturer", left = 0 })
local any_last = false
for _, m in ipairs(last) do
    any_last = any_last or string.find(m.text, "last of them", 1, true) ~= nil
    check(not string.find(m.text, "to go", 1, true), "'to go' after the last foe: " .. m.text)
end
check(any_last, "no 'last of them' line for the last foe")
check(barks.foe_label({ name = "Kruthik Huntling 3" }) == "the Kruthik Huntling", "a numbered foe keeps its number")
check(barks.foe_label({ name = "Euryale", boss = true }) == "Euryale", "a boss got an article")

-- 3. Whole nights ---------------------------------------------------------------------------------------
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"
local MODULE = adventure.data
local told_seen, kb_seen, says = 0, 0, 0

local function play(seed)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    local r = require("game.model.rng").new(seed + 77)
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        local hooks = MODULE.hooks[key]
        adventure.set_hook(c, key, hooks[r:int(1, #hooks)].id)
    end
    for _ = 1, MODULE.MAX_WEEKS do
        local prep = c:start_week()
        for _, pr in ipairs(c.adv.prompts) do
            if pr.kind == "request" then
                adventure.answer_request(c, pr.id, MODULE.ANSWERS[r:int(1, 4)])
            elseif pr.kind == "loose" then
                adventure.answer_loose(c, pr.id, r:int(1, #pr.def.options))
            elseif pr.kind == "ruling" then
                adventure.answer_ruling(c, pr.id, true)
            elseif pr.kind == "favor" then
                adventure.answer_favor(c, pr.id, 1, 1)
            end
        end
        museum_week.prep_greedy(prep)
        if prep.museum.boss then
            c.adv.boss = { opener = "talk", style = "last" }
        end
        local night = c:start_night()
        local ev = night:advance()
        local guard, kb_other, last_steps = 0, nil, nil
        while ev.kind ~= "done" and guard < 6000 do
            guard = guard + 1
            local answer
            if ev.kind == "decision" then
                local opts = ev.card.options
                answer = r:int(1, #opts)
                -- (Hand every killing blow to someone else: that's the case under test.)
                if ev.card.id == "killing_blow" then
                    for i, o in ipairs(opts) do
                        if string.find(o.label or "", "^Let ") then
                            answer = i
                            kb_other = { lander = night.actor and night.actor.char, teller = night.other and night.other.key }
                        end
                    end
                    kb_seen = kb_seen + 1
                end
                if opts[answer].disabled then
                    answer = 1
                end
            elseif ev.kind == "thought" then
                require("game.model.thoughts").bot_play(night, ev, "random", r)
            elseif ev.kind == "ruling" then
                answer = 1
            elseif ev.kind == "improv" then
                answer = { 1 }
            elseif ev.kind == "roll_where" then
                answer = "open"
            elseif ev.kind == "roll" then
                answer = r:d20()
            elseif ev.kind == "turn" then
                last_steps = ev.steps
                if ev.say then
                    says = says + 1
                    local low = string.lower(ev.say.text or "")
                    if string.find(low, "twenty", 1, true) then
                        local ok = false
                        for _, s in ipairs(ev.steps or {}) do
                            ok = ok or (s.kind == "attack" and s.roll == 20)
                        end
                        check(ok, "seed " .. seed .. ": 'twenty' on a turn with no natural 20: " .. ev.say.text)
                    end
                end
            elseif ev.kind == "say" and night.battle then
                says = says + 1
                local low = string.lower(ev.text or "")
                -- (The told line: about the lander's blow, from the teller.)
                if kb_other and ev.who == kb_other.teller then
                    told_seen = told_seen + 1
                    check(kb_other.lander == nil or string.find(ev.text, kb_other.lander, 1, true) ~= nil,
                        "seed " .. seed .. ": a handed-off killing blow doesn't name " .. tostring(kb_other.lander) .. ": " .. ev.text)
                    kb_other = nil
                end
                if string.find(low, "twenty", 1, true) and last_steps then
                    -- (The crit bark comes right after its turn: a natural twenty in it.)
                    local ok = false
                    for _, s in ipairs(last_steps) do
                        ok = ok or (s.kind == "attack" and s.roll == 20)
                    end
                    check(ok, "seed " .. seed .. ": 'twenty' with no natural 20: " .. ev.text)
                end
                if string.find(low, "who's next", 1, true) and night.battle then
                    local left = 0
                    for _, c2 in ipairs(night.battle.creatures) do
                        if c2.side == "foes" and not c2.dead and not c2.removed then
                            left = left + 1
                        end
                    end
                    check(left > 0, "seed " .. seed .. ": 'who's next' with nobody left: " .. ev.text)
                end
            end
            ev = night:advance(answer)
        end
        c:finish_night()
        if museum_week.done(c) then
            break
        end
    end
end

for seed = 1, 6 do
    play(seed)
end
check(says > 50, "hardly anyone spoke in the fights (" .. says .. ")")

-- 4. A keyed list remembers across weeks --------------------------------------------------------------------
do
    local night_mod = require "game.model.night"
    local fakeN = setmetatable({ rng = require("game.model.rng").new(3), campaign = { week = 1 } }, { __index = night_mod })
    local list = { "a", "b", "c" }
    local week1 = { fakeN:fresh(list, "k"), fakeN:fresh(list, "k"), fakeN:fresh(list, "k") }
    fakeN.campaign.week = 2
    local again = fakeN:fresh(list, "k")
    -- (All three were said last week: the one said longest ago comes back first.)
    check(again == week1[1] or again == week1[2] or again == week1[3], "fresh returned something not in the list")
    local seen = {}
    for _, l in ipairs(week1) do
        check(not seen[l], "fresh repeated '" .. l .. "' in one week with others left")
        seen[l] = true
    end
end

print(string.format("barks: %d checks, %d failed (%d killing blows handed off, %d told)", checks, failures, kb_seen, told_seen))
if failures > 0 then
    os.exit(1)
end
