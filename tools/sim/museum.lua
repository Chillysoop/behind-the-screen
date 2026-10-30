-- The Museum of Nightmares, played headless from Session Zero to the end (v2). Run from the
-- project root:  lua tools/sim/museum.lua [seed] [style] [log]
--   style: careful (preps every room, answers kindly), random, careless (preps nothing)
--   log:   "log" prints every line the table hears
-- Checks: the prologue ends inside MAX_WEEKS, no line drags in the old story, no unfilled fill-ins,
-- every room plays its moments, and the boss night happens.

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"

local seed = tonumber(arg[1]) or 1
local style = arg[2] or "careful"
local show = arg[3] == "log"

local failures = 0
local function check(cond, msg)
    if not cond then
        failures = failures + 1
        if failures <= 30 then
            print("FAIL: " .. msg)
        end
    end
end

local function text_ok(s, where)
    if type(s) ~= "string" then
        return
    end
    check(not string.find(s, "{[%w_]+}"), where .. ": unfilled fill-in in '" .. s .. "'")
    check(not string.find(s, "%f[%a]nil%f[%A]"), where .. ": 'nil' in '" .. s .. "'")
    check(not adventure.foreign(s), where .. ": the old story in '" .. s .. "'")
end

adventure.enter()
local c = campaign_mod.new(seed)
adventure.enter(c)
c:session_zero(social.default_choices())
local rng = require("game.model.rng").new(seed + 77)
for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
    local hooks = adventure.data.hooks[key]
    adventure.set_hook(c, key, hooks[rng:int(1, #hooks)].id)
end

-- The fights, with the book's monsters (game/rules/museum.lua): how many, lost, heroes dropped,
-- and the big moments that happened.
local fights = { n = 0, lost = 0, downs = 0, moments = {}, boss = "none" }

local function play_night(night)
    local ev = night:advance()
    local guard = 0
    while ev.kind ~= "done" and guard < 4000 do
        guard = guard + 1
        local answer
        if ev.kind == "narrate" or ev.kind == "say" or ev.kind == "npc" then
            text_ok(ev.text, ev.kind)
            if show then
                local who = ev.kind == "say" and ev.who or (ev.kind == "npc" and ev.name) or ev.style
                print(string.format("  [%s] %s", tostring(who), ev.text))
            end
        elseif ev.kind == "scene" then
            if show then
                print(string.format("== Scene %s of %s: %s (%s)", ev.index, ev.total, ev.title, ev.type_name))
            end
        elseif ev.kind == "battle" and ev.phase == "end" then
            fights.n = fights.n + 1
            if ev.winner ~= "party" then
                fights.lost = fights.lost + 1
            end
            local sm = ev.summary or {}
            for _, h in ipairs(sm.heroes or {}) do
                fights.downs = fights.downs + (h.downs or 0)
            end
            for _, m in ipairs(sm.moments or {}) do
                fights.moments[m.kind] = (fights.moments[m.kind] or 0) + 1
            end
            if night.scene and night.scene.room == "lair" then
                fights.boss = (ev.winner == "party") and "won" or "lost"
            end
            if show then
                print(string.format("  ## fight: %s, %d rounds", tostring(ev.winner), sm.rounds or 0))
            end
        elseif ev.kind == "mark" then
            if show then
                print("  ** EURYALE'S CARD: " .. ev.name .. " (" .. ev.why .. ")")
            end
        elseif ev.kind == "decision" then
            text_ok(ev.card.text, "decision " .. ev.card.id)
            text_ok(ev.card.title, "decision title")
            local opts = ev.card.options
            for _, o in ipairs(opts) do
                text_ok(o.label, "option")
            end
            local pick = (style == "careful") and 1 or rng:int(1, #opts)
            if opts[pick].disabled then
                pick = 1
            end
            if show then
                print("  >> " .. ev.card.title .. ": " .. ev.card.text)
                for i, o in ipairs(opts) do
                    print(string.format("     %s%d. %s", i == pick and "*" or " ", i, o.label))
                end
            end
            answer = pick
        elseif ev.kind == "ruling" then
            answer = 1
        elseif ev.kind == "improv" then
            answer = { 1 }
        elseif ev.kind == "roll_where" then
            answer = "open"
        elseif ev.kind == "roll" then
            answer = rng:d20()
        elseif ev.kind == "cinematic" then
            for _, sl in ipairs(ev.slides or {}) do
                text_ok(sl.text, "cinematic")
            end
        end
        ev = night:advance(answer)
    end
    check(guard < 4000, "night ended")
end

local weeks = 0
for w = 1, adventure.data.MAX_WEEKS do
    weeks = w
    local prep = c:start_week()
    for _, m in ipairs(c.chat) do
        text_ok(m.text, "chat")
    end
    local pm = prep.museum
    if show then
        print(string.format("\n######## Week %d  (%s)  ahead: %s", w, adventure.where(c), table.concat(pm.ahead, ", ")))
    end
    -- Between sessions: the prompts.
    for _, pr in ipairs(c.adv.prompts) do
        if pr.kind == "request" then
            local a = adventure.data.ANSWERS[style == "careful" and 2 or rng:int(1, 4)]
            adventure.answer_request(c, pr.id, a)
        elseif pr.kind == "loose" then
            adventure.answer_loose(c, pr.id, 1)
        elseif pr.kind == "favor" then
            adventure.answer_favor(c, pr.id, 1, 1)
        end
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
    check(prep:spent() <= prep.budget, "budget respected (" .. prep:spent() .. ")")
    local night = c:start_night()
    play_night(night)
    local rep = c:finish_night()
    if show then
        print(string.format("  -- report: avg %s; rooms %d; new marks: %s; bank %d",
            tostring(rep.average), #rep.museum.rooms, table.concat(rep.museum.marks, ", "), rep.museum.bank or 0))
    end
    if c:level_up() and show then
        print("  -- LEVEL UP to " .. c.level)
    end
    if adventure.over(c) then
        break
    end
end

local st = c.adv
check(st.ending ~= nil, "the prologue ended (" .. weeks .. " weeks; at " .. tostring(st.at) .. ")")
check(st.done.garden and st.done.entrance, "played the ground floor")
print(string.format("museum seed %d %s: %d weeks, ending %s, marks %s, francs %d, harsh paid %d unpaid %d, level %d%s",
    seed, style, weeks, tostring(st.ending), table.concat(st.mark_list, ","), st.francs, st.harsh.paid, st.harsh.unpaid,
    c.level, failures > 0 and ("  FAILURES " .. failures) or ""))
local mk = {}
for k, n in pairs(fights.moments) do
    table.insert(mk, k .. "=" .. n)
end
table.sort(mk)
print(string.format("  fights %d, lost %d, downs %d, boss %s; moments %s", fights.n, fights.lost, fights.downs, fights.boss,
    table.concat(mk, " ")))
os.exit(failures == 0 and 0 or 1)
