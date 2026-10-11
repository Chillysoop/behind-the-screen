-- Around the table before the story starts: the dice (the DM picks one of three sets, the players
-- start on grey and get better ones as gifts or show them off), the first session's character
-- intros, the "Last session... And here we are today" recap, and the table clock that only
-- moves while the session is being played. Run from the project root: lua tools/tests/table_check.lua

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path
unpack = unpack or table.unpack

local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local styles = require "tools.sim.dm_styles"
local dice_sets = require "game.model.dice_sets"
local pacing = require "game.model.pacing"

local ok_all = true
local function check(cond, what, detail)
    print(string.format("  [%s] %s  -  %s", cond and "PASS" or "FAIL", what, detail or ""))
    ok_all = ok_all and cond
end

local function answer(ev, rng, style)
    local k = ev.kind
    if k == "decision" then
        return rng:int(1, #ev.card.options)
    elseif k == "improv" then
        return { 1 }
    elseif k == "roll_where" then
        return style.roll_where(ev, rng)
    elseif k == "roll" then
        return rng:d20()
    elseif k == "ruling" then
        return rng:int(1, #ev.options)
    end
end

-- Dice --------------------------------------------------------------------------------------
do
    local c = campaign_mod.new(77)
    local offer = dice_sets.offer(c)
    local distinct, fancy = {}, true
    for _, id in ipairs(offer) do
        distinct[id] = true
        fancy = fancy and dice_sets.data.SETS[id].tier >= 2
    end
    local n = 0
    for _ in pairs(distinct) do
        n = n + 1
    end
    local again = dice_sets.offer(c)
    check(#offer == 3 and n == 3 and fancy and again[1] == offer[1],
        "The DM picks from three different nice sets, the same three each time", table.concat(offer, ", "))
    dice_sets.pick_dm(c, offer[2])
    local trays = dice_sets.by_tray(c)
    local grey = true
    for _, p in ipairs(c.players) do
        grey = grey and trays[p.key] == "grey"
    end
    check(trays.dm_open == offer[2] and trays.dm_hidden == offer[2] and grey,
        "The DM's set rolls behind the screen; every player starts on plain grey", "dm " .. tostring(trays.dm_open))
    c.week = 1
    local id1 = dice_sets.gift(c, "jess")
    local id2 = dice_sets.gift(c, "dev")
    c.week = 2
    local id3 = dice_sets.gift(c, "jess")
    c.week = 4
    local id4 = dice_sets.gift(c, "jess")
    check(id1 ~= nil and dice_sets.data.SETS[id1].tier >= 2 and id2 == nil and id3 == nil and id4 ~= nil
        and dice_sets.data.SETS[id4].tier == 3 and id4 ~= offer[2],
        "Gifts: one a week, not the same player again for three weeks, each one a step up, never the DM's own",
        tostring(id1) .. " then " .. tostring(id4))
end

-- Nights: intros, recap, show-offs, the clock -------------------------------------------------
local T = { intros = 0, intro_nights = 0, story_lines = 0, reacts = 0, recaps = 0, here = 0, later_nights = 0,
            shows = 0, show_bad = 0, clock_bad = 0, prompts = 0, cut_kept = 0, cut_tests = 0 }
for ci = 1, 6 do
    local style = styles.balanced
    local seed = 5300 + ci * 17
    local c = campaign_mod.new(seed)
    local rng = rng_mod.new(seed)
    for w = 1, 4 do
        local prep = c:start_week()
        style.prep(prep, rng, c)
        -- Cut a beat on last week's recap: the DM's cut keeps it out of tonight's opening.
        local cut_text
        local log = c.session_log or {}
        local last = log[#log]
        if last and last.recap and last.recap.spoken and #last.recap.spoken > 0 then
            local sp = last.recap.spoken[1]
            local found = false
            for _, b in ipairs(last.recap.beats) do
                if b.order == sp.order then
                    b.cut = true
                    found = true
                end
            end
            if found then
                cut_text = sp.text
            end
        end
        local committed = {}
        for _, p in ipairs(c.players) do
            committed[p.key] = (p.commitment or 0) >= dice_sets.data.SHOW_OFF.commitment
                and (p.last_tier == "loved" or p.last_tier == "fun")
        end
        local night = c:start_night()
        local ev = night:advance()
        local started = false
        local opening = {}
        while ev.kind ~= "done" do
            if ev.kind == "scene" then
                started = true
            end
            if not started then
                if ev.kind == "intro" then
                    T.intros = T.intros + 1
                elseif ev.kind == "say" and ev.ic then
                    T.story_lines = T.story_lines + 1
                elseif ev.kind == "dice" and ev.show then
                    T.shows = T.shows + 1
                    if not committed[ev.who] then
                        T.show_bad = T.show_bad + 1
                    end
                elseif ev.kind == "narrate" and ev.style == "recap" then
                    table.insert(opening, ev.text)
                end
            end
            -- The table clock doesn't move while a choice waits for the DM.
            if pacing.DECISION_KINDS[ev.kind] or ev.kind == "roll_where" then
                T.prompts = T.prompts + 1
                local before = night.table_min
                local nxt = night:advance(answer(ev, rng, style))
                -- the minutes land once it's answered; while it waited, nothing moved
                if before == nil or night.table_min < before then
                    T.clock_bad = T.clock_bad + 1
                end
                ev = nxt
            else
                ev = night:advance(answer(ev, rng, style))
            end
        end
        if w == 1 then
            T.intro_nights = T.intro_nights + 1
        else
            T.later_nights = T.later_nights + 1
            local all = table.concat(opening, " | ")
            if string.find(all, "^Last session: ") then
                T.recaps = T.recaps + 1
            end
            if string.find(all, "And here we are today: you're") then
                T.here = T.here + 1
            end
            if cut_text then
                T.cut_tests = T.cut_tests + 1
                if not string.find(all, cut_text, 1, true) then
                    T.cut_kept = T.cut_kept + 1
                end
            end
        end
        c:finish_night()
        -- A gift for whoever loved it most, now and then.
        if w % 2 == 1 then
            dice_sets.gift(c, c.players[(w % #c.players) + 1].key)
        end
    end
end
check(T.intros == 4 * T.intro_nights and T.story_lines >= 4 * T.intro_nights,
    "Session one: everyone introduces themselves and their hero, with a bit of backstory in character",
    string.format("%d intros over %d first nights, %d lines in character", T.intros, T.intro_nights, T.story_lines))
check(T.recaps == T.later_nights and T.here == T.later_nights,
    "Every later session opens with \"Last session: ...\" and \"And here we are today: you're ...\"",
    string.format("%d recaps, %d here-we-ares over %d nights", T.recaps, T.here, T.later_nights))
check(T.cut_tests > 0 and T.cut_kept == T.cut_tests, "A beat the DM cut from the report stays out of the recap",
    string.format("%d of %d", T.cut_kept, T.cut_tests))
check(T.show_bad == 0, "Only a player who's all in and loved last session shows off new dice",
    string.format("%d show-offs", T.shows))
check(T.prompts > 0 and T.clock_bad == 0, "The table clock never moves while a choice waits",
    string.format("%d choices", T.prompts))
os.exit(ok_all and 0 or 1)
