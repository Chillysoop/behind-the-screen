-- The friends' thoughts (v2, October 30), headless. Run from the project root:
--   lua tools/tests/thoughts_check.lua
-- Checks: every line fills in and stays out of the old story, a thought carries its answers, an
-- answer moves the right numbers and lands in the log at the next beat, the wrong answer for the shy
-- friend backfires, Empathy sets how many you catch and grows once a night from a good read, a
-- thought passes with its scene, catching Pip's eye keeps her off the stairs, and whole prologues
-- with a careful DM answering them still play to the end.

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local thoughts = require "game.model.thoughts"
local night_mod = require "game.model.night"
local score = require "game.model.score"
local util = require "game.model.util"
local rng_mod = require "game.model.rng"

local fails, checks = 0, 0
local function check(cond, msg)
    checks = checks + 1
    if not cond then
        fails = fails + 1
        print("FAIL: " .. msg)
    end
end

local function new_campaign(seed)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        adventure.set_hook(c, key, adventure.data.hooks[key][1].id)
    end
    return c
end

-- A stand-in night: the real players and helpers, with beats collected instead of yielded.
local function fake_night(c, seed)
    local evs = {}
    local n = { campaign = c, players = c:present(), rng = rng_mod.new(seed or 1), scene = { index = 1 }, table_min = 0 }
    n.fresh = night_mod.fresh
    n.decision_count = function()
        return 0
    end
    n.emit = function(self, ev)
        local q = thoughts.take_queue(self)
        for _, e in ipairs(q or {}) do
            table.insert(evs, e)
        end
        table.insert(evs, ev)
    end
    return n, evs
end

local function find(players, key)
    for _, p in ipairs(players) do
        if p.key == key then
            return p
        end
    end
end

-- 1. Every line, label and want fills in and stays out of the old story.
local D = thoughts.DATA
local c = new_campaign(3)
for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
    local p = find(c.players, key)
    local v = thoughts.vars(p)
    local function ok(s, where)
        local t = util.fill(s, v)
        check(not t:find("{[%w_]+}"), where .. ": unfilled in '" .. t .. "'")
        check(not adventure.foreign(t), where .. ": the old story in '" .. t .. "'")
        check(#t <= 110, where .. ": too long for a bubble: '" .. t .. "'")
    end
    for need, list in pairs(D.lines[key] or {}) do
        for _, l in ipairs(list) do
            ok(l, key .. " " .. need)
        end
    end
    for need, list in pairs(D.generic) do
        for _, l in ipairs(list) do
            ok(l, "generic " .. need)
        end
    end
    for id, a in pairs(D.answers) do
        ok(a.label, "answer " .. id)
        ok(a.log, "answer log " .. id)
        check(thoughts.EFFECTS[id] ~= nil, "answer " .. id .. " does something")
    end
    for id, nd in pairs(D.needs) do
        ok(nd.want, "want " .. id)
        for _, aid in ipairs(nd.answers) do
            check(D.answers[aid] ~= nil, "need " .. id .. " answers with " .. aid)
        end
    end
end
for _, mood in ipairs({ "tired", "stressed", "distracted", "celebrating", "chatty" }) do
    check(D.needs[mood] ~= nil and D.generic[mood] ~= nil, "a thought for the " .. mood .. " mood")
end

-- 2. A thought, answered: the right numbers move, and the log hears it at the next beat.
local night, evs = fake_night(c, 4)
local mara = find(night.players, "mara")
local story0 = mara.m.story
local t = thoughts.think(night, mara, "story")
check(t ~= nil and evs[#evs].kind == "thought", "Mara has a thought")
local ev = evs[#evs]
check(ev.who == "mara" and #ev.answers == 2 and ev.want:find("^Mara "), "it says whose, what she wants, and two answers")
local ok, good = thoughts.respond(night, ev.id, "detail")
check(ok and good, "letting her notice something lands")
check(mara.m.story > story0, "her Story meter moved (" .. story0 .. " to " .. mara.m.story .. ")")
night:emit({ kind = "narrate", text = "next beat" })
local logged = false
for _, e in ipairs(evs) do
    if e.kind == "narrate" and e.style == "dm" and e.text:find("Mara") then
        logged = true
    end
end
check(logged, "what you did is in the log at the next beat")
check(not thoughts.respond(night, ev.id, "next_moment"), "a thought is answered once")

-- 3. The wrong answer for the friend who hates the spotlight backfires; the right one doesn't.
night.scene = { index = 2 }
local sam = find(night.players, "sam")
check(sam.shy, "Sam hates being put on the spot")
local fun0 = score.fun(sam)
local ts = thoughts.think(night, sam, "spotlight")
if ts then
    local ok2, good2 = thoughts.respond(night, ts.id, "next_moment")
    check(ok2 and good2 == false, "handing Sam the spotlight backfires")
    check(score.fun(sam) < fun0, "and it shows on his Fun")
end
night.scene = { index = 3 }
local to = thoughts.think(night, sam, "off_spot")
check(to ~= nil, "Sam can think he'd rather not be on the spot")
if to then
    local ok3, good3 = thoughts.respond(night, to.id, "spare")
    check(ok3 and good3 and night.spare == "sam", "giving the next one to someone else is remembered")
end

-- 4. Empathy sets how many a night; a good read grows it, once a night.
local c2 = new_campaign(5)
local n2 = fake_night(c2, 6)
local level = c2:empathy()
local cap = thoughts.CAP[level]
local shown = 0
for i = 1, 10 do
    n2.scene = { index = i }
    local p = n2.players[(i % #n2.players) + 1]
    if thoughts.think(n2, p, "social") then
        shown = shown + 1
    end
end
check(shown == cap, "Empathy " .. level .. " catches " .. cap .. " a night (caught " .. shown .. ")")
check(not thoughts.think(n2, n2.players[1], "glow") == false, "a happy thought doesn't count against them")
local xp0 = c2.empathy_xp
local done_good = 0
for id in pairs(n2.th.list) do
    local tt = n2.th.list[id]
    if not tt.glow then
        n2.scene = { index = tt.scene }
        local okk, gd = thoughts.respond(n2, id, "talk")
        if okk and gd then
            done_good = done_good + 1
        end
    end
end
check(done_good >= 1, "some answered well")
check(c2.empathy_xp == xp0 + 1, "a good read grows Empathy once a night (" .. xp0 .. " to " .. c2.empathy_xp .. ")")
local n2b = fake_night(c2, 7)
for _ = 1, 3 do
    c2:gain_empathy("talk")
end
check(thoughts.cap(n2b) > cap, "more Empathy, more thoughts caught (" .. thoughts.cap(n2b) .. ")")

-- 5. A thought passes with its scene; a happy one has nothing to answer.
local n3, ev3 = fake_night(new_campaign(8), 9)
local t3 = thoughts.think(n3, n3.players[1], "spotlight")
n3.scene = { index = 2 }
check(t3 and not thoughts.is_open(n3, t3.id), "a thought passes when the scene moves on")
check(t3 and not thoughts.respond(n3, t3.id, "ask"), "and can't be answered after")
local tg = thoughts.think(n3, n3.players[2], "glow")
check(tg and #ev3[#ev3].answers == 0 and ev3[#ev3].glow, "a happy thought is just for you")

-- 6. Pip, about to go off alone: catch her eye and she stays.
local c4 = new_campaign(10)
c4.adv.flags.pip_alone = true
local n4 = fake_night(c4, 11)
local jess = find(n4.players, "jess")
local tp = thoughts.plan(n4, jess)
check(tp ~= nil and thoughts.is_open(n4, tp.id), "Jess's plan is open until it happens")
n4.scene = { index = 5 }
check(thoughts.is_open(n4, tp.id), "...even into the next scene")
check(thoughts.respond(n4, tp.id, "catch_eye"), "you catch her eye")
check(c4.adv.flags.pip_alone == nil, "and Pip doesn't go up the stairs alone")
c4.adv.flags.pip_alone = true
local tp2 = thoughts.plan(n4, jess)
c4.adv.flags.pip_alone = nil       -- (it happened)
check(tp2 and not thoughts.is_open(n4, tp2.id), "once she's gone, the moment has passed")

-- 7. Whole prologues, a careful DM answering what they catch: they still end, and thoughts show.
local museum_week = require "game.model.museum_week"
local total, answered = 0, 0
for seed = 21, 24 do
    local cc = new_campaign(seed)
    local brng = rng_mod.new(seed)
    for _ = 1, 8 do
        if cc.adv.ending then
            break
        end
        local prep = cc:start_week()
        museum_week.prep_greedy(prep)
        local nn = cc:start_night()
        local e = nn:advance()
        local g = 0
        while e.kind ~= "done" and g < 5000 do
            g = g + 1
            local a
            if e.kind == "thought" then
                total = total + 1
                local aid = thoughts.bot_answer(nn, e, "careful", brng)
                if aid and thoughts.respond(nn, e.id, aid) and aid ~= "let_be" then
                    answered = answered + 1
                end
            elseif e.kind == "decision" or e.kind == "ruling" then
                a = 1
            elseif e.kind == "improv" then
                a = { 1 }
            elseif e.kind == "roll_where" then
                a = "open"
            elseif e.kind == "roll" then
                a = 15
            end
            e = nn:advance(a)
        end
        check(g < 5000, "a night finished (seed " .. seed .. ")")
        cc:finish_night()
        check(cc.report and cc.report.thoughts ~= nil, "the report counts the thoughts")
    end
    check(cc.adv.ending ~= nil, "the prologue ended with thoughts answered (seed " .. seed .. ")")
end
check(total >= 8, "thoughts show up across four prologues (" .. total .. ")")
check(answered >= 3, "a careful DM answers some (" .. answered .. ")")

print(string.format("the friends' thoughts: %d checks, %d failed (prologues: %d thoughts, %d answered)", checks, fails,
    total, answered))
os.exit(fails == 0 and 0 or 1)
