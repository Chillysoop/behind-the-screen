-- Pulls and skews (October 18): the players' pulls keep to what's in play, and every call sticks.
-- Plays whole slices with each simulated DM, with pulls on and (same seeds) with the old night, and
-- checks:
--   * every pull is toward something in play: a place on the map, a card in the hand, a storyline
--     there, a theory pinned to the board, or a place off the map; never tonight's route or a card
--     already on the board
--   * at most one pull a stop, and nights stay within the call budget
--   * Weave it in is offered only when something ties the pull to the stop
--   * every answer sticks: Follow slips the plan and moves the story, Weave moves it and links the
--     threads, Park is owed and is paid off or sours on time, Steer back twice is railroading
--   * the quiet player gets pulled in: pulls lean toward whoever has had the least say
--   * with pulls on, the old wander-off and split-the-party cards never come up
-- Run from the project root: texlua tools/tests/pull_check.lua [runs]

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path
unpack = unpack or table.unpack

local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local bots = require "slice_bots"
local content = require "game.model.content"
local pulls = require "game.model.pulls"
local valley = require "game.model.valley"
local places = require "game.model.places"
local seeds = require "game.model.seeds"

local RUNS = tonumber(arg and arg[1]) or 8

local ok_all = true
local fails = {}
local function check(cond, what, detail)
    print(string.format("  [%s] %s  -  %s", cond and "PASS" or "FAIL", what, detail or ""))
    ok_all = ok_all and cond
end
local function fail(msg)
    if #fails < 25 then
        table.insert(fails, msg)
    end
end

-- Watch every pull as it's made: what it's toward, at that moment.
local T = { pulls = 0, kinds = {}, answers = {}, out_of_play = 0, per_stop = 0, weave_offered = 0, weave_no_tie = 0,
            follow = 0, follow_slipped = 0, moved = 0, moved_ok = 0, woven = 0, linked = 0, parked = 0, paid = 0, soured = 0,
            late = 0, steer2 = 0, railroad = 0, low_pullers = 0, old_cards_on = 0, old_cards_off = 0, nights = 0,
            over = { on = 0, off = 0 }, calls = { on = 0, off = 0 } }
local current
local orig_skew = pulls.skew
pulls.skew = function(night, sc)
    local p, t = pulls.choose(night, sc)
    if not p then
        return nil
    end
    -- What's in play right now.
    local vis = valley.visible(night.campaign, night.prep)
    local route, placed = {}, {}
    for _, s in ipairs(night.scenes) do
        for _, c in pairs(s.comps or {}) do
            placed[c.id] = true
            if c.kind == "location" then
                route[c.id] = true
            end
        end
    end
    local in_hand = {}
    for _, kind in ipairs(content.kinds) do
        for _, c in ipairs(night.prep.hand[kind] or {}) do
            in_hand[c.id] = true
        end
    end
    local ok
    if t.kind == "theory" then
        ok = t.theory and seeds.can_steal(night.campaign, t.theory)
    elseif t.kind == "offmap" then
        ok = t.place and not vis[t.place.id] and not route[t.place.id]
    elseif t.card then
        ok = in_hand[t.card.id] and not placed[t.card.id]
    elseif t.place then
        ok = vis[t.place.id] and not route[t.place.id]
    end
    if not ok then
        T.out_of_play = T.out_of_play + 1
        fail(current .. ": a pull toward " .. tostring(t.id) .. " (" .. t.kind .. "), which isn't in play")
    end
    -- Leaning toward the quiet player: was this player's share at or below the table's middle?
    local shares = {}
    for _, q in ipairs(night.players) do
        table.insert(shares, (pulls.share(night.campaign, q.key)))
    end
    table.sort(shares)
    local mid = shares[math.ceil(#shares / 2)]
    if pulls.share(night.campaign, p.key) <= mid then
        T.low_pullers = T.low_pullers + 1
    end
    if sc.skewed then
        T.per_stop = T.per_stop + 1
        fail(current .. ": two pulls at one stop")
    end
    -- The same pull, played for real.
    return orig_skew(night, sc, p, t)
end

local function play(dm_key, run, old)
    local dm = bots.DMS[dm_key]
    local seed = 18000 + run * 53 + #dm_key
    local c = campaign_mod.new(seed)
    c.old_night = old or nil
    local rng = rng_mod.new(seed + 7)
    c:session_zero(dm.s0)
    local spreads = {}
    for w = 1, 4 do
        current = string.format("%s run %d week %d%s", dm_key, run, w, old and " (old night)" or "")
        local prep = c:start_week()
        bots.prep(dm, c, prep, rng)
        local night = c:start_night()
        local old_cards = 0
        bots.play_night(night, rng, dm, function(ev)
            if ev.kind == "decision" and ev.card then
                if ev.card.id == "split_party" then
                    old_cards = old_cards + 1
                end
                if ev.card.type == "skew" then
                    for _, o in ipairs(ev.card.options) do
                        if o.answer == "weave" and not o.disabled then
                            T.weave_offered = T.weave_offered + 1
                        end
                    end
                end
            elseif ev.kind == "improv" and ev.drift then
                old_cards = old_cards + 1
            end
        end)
        local mode = old and "off" or "on"
        T.calls[mode] = T.calls[mode] + night:decision_count()
        if night:decision_count() > 15 then
            T.over[mode] = T.over[mode] + 1
        end
        if old then
            T.old_cards_off = T.old_cards_off + old_cards
        else
            T.old_cards_on = T.old_cards_on + old_cards
            T.nights = T.nights + 1
        end
        -- Every answer stuck.
        if not old then
            local steers = 0
            for _, e in ipairs(night.pull_log or {}) do
                T.pulls = T.pulls + 1
                T.kinds[e.kind] = (T.kinds[e.kind] or 0) + 1
                T.answers[e.answer] = (T.answers[e.answer] or 0) + 1
                local sc = night.scenes[e.stop]
                if e.answer == "follow" then
                    T.follow = T.follow + 1
                    if sc and sc.slip then
                        T.follow_slipped = T.follow_slipped + 1
                    else
                        fail(current .. ": followed " .. e.name .. ", but the plan didn't slip")
                    end
                end
                if e.answer == "weave" and not e.tie then
                    T.weave_no_tie = T.weave_no_tie + 1
                    fail(current .. ": wove in " .. e.name .. " with nothing tying it to the stop")
                end
                if e.answer == "follow" or e.answer == "weave" then
                    for _, id in ipairs(e.moved or {}) do
                        T.moved = T.moved + 1
                        if (night.story_moved or {})[id] then
                            T.moved_ok = T.moved_ok + 1
                        else
                            fail(current .. ": " .. e.name .. " was to move " .. id .. ", and it didn't")
                        end
                    end
                end
                if e.answer == "weave" then
                    T.woven = T.woven + 1
                    local linked = false
                    for _, id in ipairs(e.moved or {}) do
                        if id == e.link then
                            linked = true      -- (the same storyline as the stop's: one thread already)
                        end
                        for _, l in ipairs(night.story_links or {}) do
                            if l[2] == id and l[1] == e.link then
                                linked = true
                            end
                        end
                    end
                    -- (A stop that moves no storyline has nothing to link to.)
                    if linked or #(e.moved or {}) == 0 or not e.link then
                        T.linked = T.linked + 1
                    end
                end
                if e.answer == "park" then
                    T.parked = T.parked + 1
                end
                if e.answer == "steer" then
                    steers = steers + 1
                end
            end
            if steers >= pulls.data.RAILROAD_AT then
                T.steer2 = T.steer2 + 1
                if night.railroaded then
                    T.railroad = T.railroad + 1
                else
                    fail(current .. ": steered back " .. steers .. " times and nobody called it railroading")
                end
            end
        end
        c:finish_night()
        -- Nothing owed stays owed past its sessions.
        for _, o in ipairs(pulls.get(c).owed) do
            if o.state == "owed" and (c.week or 1) > o.due + 1 then
                T.late = T.late + 1
                fail(current .. ": " .. o.name .. " is still owed past session " .. o.due)
            end
        end
        local lo, hi, sum = math.huge, 0, 0
        for _, p in ipairs(c.players) do
            local s = pulls.share(c, p.key)
            lo, hi, sum = math.min(lo, s), math.max(hi, s), sum + s
        end
        spreads[w] = sum > 0 and (hi - lo) / (sum / #c.players) or 0
    end
    -- The start of the next week sours what wasn't paid.
    c:start_week()
    for _, o in ipairs(pulls.get(c).owed) do
        if not old then
            if o.state == "paid" then
                T.paid = T.paid + 1
            elseif o.state == "sour" then
                T.soured = T.soured + 1
            end
        end
    end
    return spreads[4]
end

local spread_on, spread_off, n = 0, 0, 0
local by_dm = {}
for _, dm_key in ipairs(bots.ORDER) do
    local on, off = 0, 0
    for run = 1, RUNS do
        on = on + play(dm_key, run, false)
        off = off + play(dm_key, run, true)
        n = n + 1
    end
    by_dm[dm_key] = { on = on / RUNS, off = off / RUNS }
    spread_on, spread_off = spread_on + on, spread_off + off
end
spread_on, spread_off = spread_on / n, spread_off / n

local function list(t)
    local out = {}
    for k, v in pairs(t) do
        table.insert(out, k .. " " .. v)
    end
    table.sort(out)
    return table.concat(out, ", ")
end
print(string.format("  %d nights, %d pulls (%.1f a night). Toward: %s. Answers: %s.", T.nights, T.pulls,
    T.pulls / math.max(1, T.nights), list(T.kinds), list(T.answers)))
print(string.format("  Calls a night: %.1f with pulls, %.1f with the old night; over 15: %d and %d nights.",
    T.calls.on / math.max(1, T.nights), T.calls.off / math.max(1, T.nights), T.over.on, T.over.off))
print(string.format("  Parked %d: %d paid off, %d soured. Share spread at the slice's end: %.2f with pulls, %.2f without.",
    T.parked, T.paid, T.soured, spread_on, spread_off))
check(T.out_of_play == 0 and T.pulls > 0, "Every pull is toward something in play", T.pulls .. " pulls, " .. T.out_of_play .. " not in play")
check(T.pulls >= T.nights * 0.8, "Pulls come up most nights", string.format("%.1f a night", T.pulls / math.max(1, T.nights)))
check(T.per_stop == 0, "At most one pull a stop", T.per_stop .. " stops with two")
check(T.over.on <= T.over.off + math.ceil(T.nights * 0.05), "Pulls keep the night within its calls",
    T.over.on .. " nights over 15 with pulls, " .. T.over.off .. " without")
check(T.weave_no_tie == 0 and T.weave_offered > 0, "Weave it in only when something ties it to the stop",
    T.weave_offered .. " offered, " .. T.weave_no_tie .. " woven without a tie")
check(T.follow_slipped == T.follow and T.follow > 0, "Follow it slips the plan", T.follow_slipped .. " of " .. T.follow)
check(T.moved_ok == T.moved and T.moved > 0, "Follow and weave move the story", T.moved_ok .. " of " .. T.moved .. " storylines")
check(T.linked == T.woven, "A woven pull links its thread to the stop's", T.linked .. " of " .. T.woven)
check(T.late == 0 and T.parked > 0, "A parked pull is paid off or sours on time", T.parked .. " parked, " .. T.late .. " overdue")
check(T.railroad == T.steer2, "Steering back twice in a night is railroading", T.railroad .. " of " .. T.steer2 .. " nights")
check(T.low_pullers >= T.pulls * 0.55, "Pulls lean toward whoever has had the least say",
    string.format("%d of %d pulls by a player at or below the table's middle", T.low_pullers, T.pulls))
for _, dm_key in ipairs(bots.ORDER) do
    print(string.format("    %-9s share spread %.2f with pulls, %.2f without", dm_key, by_dm[dm_key].on, by_dm[dm_key].off))
end
-- (A DM who answers pulls evens the share out; one who steers every pull back doesn't, and shouldn't.)
check(by_dm.careful.on < by_dm.careful.off and by_dm.plain.on < by_dm.plain.off,
    "Answering pulls evens out who moves the story", string.format("careful %.2f vs %.2f, plain %.2f vs %.2f",
        by_dm.careful.on, by_dm.careful.off, by_dm.plain.on, by_dm.plain.off))
check(T.old_cards_on == 0 and T.old_cards_off > 0, "Pulls replace the old wander-off and split-the-party cards",
    T.old_cards_on .. " with pulls, " .. T.old_cards_off .. " with the old night")
for _, f in ipairs(fails) do
    print("    " .. f)
end
print(ok_all and "PULL CHECK PASSED" or "PULL CHECK FAILED")
os.exit(ok_all and 0 or 1)
