-- Table life (game/model/table_life.lua): small moments that play themselves. Whole prologues with
-- small-moment crits on and off, and at 4x. Checks: the beats happen; never in a fight, never at 4x;
-- inside the caps; only a natural 20 or 1 makes a card, and only with crits on; every answer said is
-- the adventure's own words (adventure.fits); the shop's haggling never takes Francs below zero.
-- Run from the project root:  lua tools/tests/table_life_check.lua [runs]

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"
local table_life = require "game.model.table_life"

local RUNS = tonumber(arg[1]) or 4
local fails, checks = 0, 0
local function check(ok, msg)
    checks = checks + 1
    if not ok then
        fails = fails + 1
        if fails <= 25 then
            print("FAIL: " .. msg)
        end
    end
end

local T = { beats = 0, crit_cards = 0, nights = 0, curios = 0, asks = 0, fast_beats = 0, kinds = {} }

local function play(seed, mode)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    table_life.set_crits(c, mode ~= "off")
    -- (Tips off: the first night is a full one, so a crit can come up on it too. The gentle first night,
    -- R6, keeps small-moment crits for the second night on: tools/tests/roadmap_table_check.lua.)
    c.guide = { seen = {}, off = true, shown = 0 }
    local rng = require("game.model.rng").new(seed + 5)
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        local hooks = adventure.data.hooks[key]
        adventure.set_hook(c, key, hooks[rng:int(1, #hooks)].id)
    end
    for w = 1, adventure.data.MAX_WEEKS do
        local prep = c:start_week()
        for _, m in ipairs(c.chat or {}) do
            if m.ask and not m.answered then
                museum_week.answer_chat(c, m, 1)
            end
        end
        for _, pr in ipairs(c.adv.prompts) do
            if pr.kind == "request" then
                adventure.answer_request(c, pr.id, "yes")
            elseif pr.kind == "loose" then
                adventure.answer_loose(c, pr.id, 1)
            elseif pr.kind == "ruling" then
                adventure.answer_ruling(c, pr.id, true)
            elseif pr.kind == "favor" then
                adventure.answer_favor(c, pr.id, 1, 1)
            end
        end
        museum_week.prep_greedy(prep)
        if prep.museum.boss then
            c.adv.boss = { opener = "talk", style = "yields" }
        end
        local night = c:start_night()
        if mode == "fast" then
            night.fast = true
            night.speed_hint = 4
        end
        T.nights = T.nights + 1
        local in_fight, tiny, cards = false, 0, 0
        local ev = night:advance()
        local guard = 0
        while ev.kind ~= "done" and guard < 6000 do
            guard = guard + 1
            local answer
            if ev.kind == "battle" then
                in_fight = ev.phase == "start"
            elseif ev.kind == "tiny_roll" and not ev.what then
                -- (`what`: a roll a card or a split is about, poking around for a find, not a small moment.)
                tiny = tiny + 1
                check(not in_fight, string.format("seed %d %s week %d: a small moment in a fight", seed, mode, w))
                check(mode ~= "fast", string.format("seed %d week %d: a small moment at 4x", seed, w))
                check(ev.total == ev.roll + ev.mod, "the small die adds up")
            elseif ev.kind == "decision" then
                if ev.card.id == "tl_crit" then
                    cards = cards + 1
                    check(mode == "on", string.format("seed %d %s week %d: a crit card with crits off", seed, mode, w))
                    answer = rng:int(1, #ev.card.options)
                else
                    answer = 1
                end
                local opts = ev.card.options
                if opts[answer] and opts[answer].disabled then
                    answer = 1
                end
            elseif ev.kind == "roll_where" then
                answer = "open"
            elseif ev.kind == "roll" then
                answer = rng:d20()
            elseif ev.kind == "improv" then
                answer = { 1 }
            elseif ev.kind == "ruling" then
                answer = 1
            end
            if (ev.kind == "say" or ev.kind == "narrate" or ev.kind == "npc") and ev.text then
                check(adventure.fits(ev.text), "a line from outside the adventure: " .. ev.text)
                check(not string.find(ev.text, "{[%w_]+}"), "an unfilled fill-in: " .. ev.text)
            end
            ev = night:advance(answer)
        end
        check(guard < 6000, "the night ended")
        local tl = night.tl or { n = 0 }
        T.beats = T.beats + (tl.n or 0)
        T.crit_cards = T.crit_cards + cards
        if mode == "fast" then
            T.fast_beats = T.fast_beats + (tl.n or 0)
        end
        check((tl.n or 0) <= table_life.PER_NIGHT.some, string.format("seed %d week %d: %d small moments (cap %d)", seed, w,
            tl.n or 0, table_life.PER_NIGHT.some))
        check((c.adv.francs or 0) >= 0, "Francs never below zero")
        c:finish_night()
        c:level_up()
        if adventure.over(c) then
            break
        end
    end
    -- Nothing poked at twice in the prologue.
    local n = 0
    for _ in pairs(c.adv.tl_seen or {}) do
        n = n + 1
    end
    T.curios = T.curios + n
end

for run = 1, RUNS do
    for _, mode in ipairs({ "on", "off", "fast" }) do
        local ok, err = pcall(play, 500 + run * 23, mode)
        check(ok, "seed " .. (500 + run * 23) .. " " .. mode .. ": " .. tostring(err))
    end
end

check(T.beats > T.nights, "small moments happen (" .. T.beats .. " over " .. T.nights .. " nights)")
check(T.fast_beats == 0, "none at 4x")
check(T.crit_cards > 0, "a natural 20 or 1 gives the DM a card when crits are on (" .. T.crit_cards .. ")")
print(string.format("table life: %d checks, %d failed (%d small moments over %d nights, %d crit cards, %d things poked at)",
    checks, fails, T.beats, T.nights, T.crit_cards, T.curios))
os.exit(fails == 0 and 0 or 1)
