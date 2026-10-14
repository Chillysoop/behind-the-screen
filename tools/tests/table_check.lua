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
local keepsakes = require "game.model.keepsakes"
local K = { gifts = 0, bad = 0, fits = 0, used = 0, notices = 0, expect = 0, campaigns = 0, dupes = 0, landed = {} }
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
                elseif ev.kind == "keepsake" then
                    K.notices = K.notices + 1
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
        -- A full heart brings the DM a gift: it suits the giver, their heart starts over, and how
        -- the DM takes it lands differently with different people.
        local g = c.report.keepsake
        if g then
            K.gifts = K.gifts + 1
            local giver = c:player(g.from)
            local def = keepsakes.def(g.id)
            if def.from[giver.primary] or def.from[giver.secondary] then
                K.fits = K.fits + 1
            end
            if keepsakes.goodwill(c, g.from) ~= 0 or not giver.present or keepsakes.waiting(c) ~= g then
                K.bad = K.bad + 1
            end
            local how = ({ "gush", "use", "cool" })[(w + ci) % 3 + 1]
            local said, landed = keepsakes.react(c, how)
            if not said or not landed or string.find(said .. landed, "{", 1, true) or keepsakes.waiting(c) then
                K.bad = K.bad + 1
            else
                K.landed[g.landed] = true
            end
            if how == "use" then
                K.used = K.used + 1
                if w < 4 then
                    K.expect = K.expect + 1
                end
            end
        end
        -- A gift for whoever loved it most, now and then.
        if w % 2 == 1 then
            dice_sets.gift(c, c.players[(w % #c.players) + 1].key)
        end
    end
    K.campaigns = K.campaigns + 1
    local had = {}
    for _, id in ipairs(keepsakes.on_table(c)) do
        if had[id] then
            K.dupes = K.dupes + 1
        end
        had[id] = true
    end
    -- The table awards at the end of the first act: one each, all different, all filled in.
    local awarded = require("game.model.awards").pick(c)
    local seen = {}
    for _, p in ipairs(c.players) do
        local a = awarded[p.key]
        if not a or seen[a.title] or string.find(a.reason or "{", "{", 1, true) then
            T.award_bad = (T.award_bad or 0) + 1
        else
            seen[a.title] = true
            T.award_titles = T.award_titles or {}
            T.award_titles[a.title] = true
            if a.id ~= "fallback" then
                T.award_earned = (T.award_earned or 0) + 1
            end
        end
        T.award_n = (T.award_n or 0) + 1
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
local kinds = 0
for _ in pairs(T.award_titles or {}) do
    kinds = kinds + 1
end
check((T.award_bad or 0) == 0 and kinds >= 6 and (T.award_earned or 0) >= 0.6 * (T.award_n or 1),
    "Table awards: one each, all different, mostly earned at the table, and plenty of kinds",
    string.format("%d of %d earned, %d different awards", T.award_earned or 0, T.award_n or 0, kinds))
local spread = 0
for _ in pairs(K.landed) do
    spread = spread + 1
end
check(K.gifts >= 3 and K.bad == 0 and K.dupes == 0 and K.fits == K.gifts,
    "Gifts from the table: a full heart brings one, picked for the giver, never the same thing twice",
    string.format("%d gifts over %d campaigns (%d suit the giver)", K.gifts, K.campaigns, K.fits))
check(spread >= 2 and K.notices <= K.expect and (K.expect == 0 or K.notices >= 1),
    "How the DM takes a gift lands differently, and a gift put to work is noticed next session",
    string.format("%d different landings; %d noticed of %d put to work", spread, K.notices, K.expect))
-- The October 13 playtest pass. The verdict reads the night as the table saw it: a player who
-- drifted most of the night can't have loved it, and one who never did keeps their score.
do
    local report = require "game.model.report"
    local p = { key = "dev" }
    local drifted = { lived = { time = 100, sum = { dev = 38 }, low = { dev = 80 } } }
    local fine = { lived = { time = 100, sum = { dev = 55 }, low = { dev = 0 } } }
    local f1, why1 = report.felt(drifted, p, 85)
    local f2, why2 = report.felt(fine, p, 85)
    local f3 = report.felt({}, p, 85)
    check(f1 < 55 and why1 ~= nil and f2 == 85 and why2 == nil and f3 == 85,
        "The verdict follows the tells: drifting all night caps it, a good night keeps its score",
        string.format("drifted 85 -> %.0f (%s), engaged 85 -> %.0f", f1, tostring(why1), f2))
end
-- "Turn to them": the next roll and the next card go to the player you turned to.
do
    local night_mod = require "game.model.night"
    local players = { { key = "mara", m = { spotlight = 50 } }, { key = "sam", m = { spotlight = 10 } } }
    local n = setmetatable({ players = players, scene = { index = 2 }, owed = { key = "sam", rolls = 1, cards = 1, scene = 2 } },
        { __index = night_mod })
    local r = n:take_owed("rolls")
    local c = n:take_owed("cards")
    local again = n:take_owed("rolls")
    local m = setmetatable({ players = players, scene = { index = 5 }, owed = { key = "sam", rolls = 1, cards = 1, scene = 2 } },
        { __index = night_mod })
    check(r == players[2] and c == players[2] and again == nil and n.owed == nil and m:take_owed("rolls") == nil,
        "A spotlight handed over: Sam gets the next roll and card, once, and it lapses after the next scene", "")
end
-- "Previously on": last session a line a scene, at the top of the prep board.
do
    local chronicle = require "game.model.chronicle"
    local c = campaign_mod.new(41)
    local style = styles.balanced
    local rng = rng_mod.new(41)
    local lines_ok, weeks = true, 0
    for w = 1, 3 do
        local prep = c:start_week()
        local pv = chronicle.previously(c)
        if w >= 2 then
            weeks = weeks + 1
            if not (pv and #pv.lines >= 1 and pv.title == "LAST TIME") then
                lines_ok = false
            end
            for _, l in ipairs(pv and pv.lines or {}) do
                if not string.find(l.text, "^S%d ") or #l.text > 170 then
                    lines_ok = false
                end
            end
        end
        style.prep(prep, rng, c)
        local night = c:start_night()
        local ev = night:advance()
        while ev.kind ~= "done" do
            ev = night:advance(answer(ev, rng, style))
        end
        c:finish_night()
    end
    check(lines_ok and weeks == 2, "Previously on: a short line for every scene last session", "")
end
os.exit(ok_all and 0 or 1)
