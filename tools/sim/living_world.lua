-- The slice rework's gates for the story deck, the planner, the notebook, bringing them in
-- and the world turns (update prompt S1 to S7). Plays many campaigns past the slice with the
-- simulated DMs (tools/sim/slice_bots.lua) plus one who makes random calls on the world's
-- moves, and checks what each part promises. Run from the project root:
--   texlua tools/sim/living_world.lua [campaigns per DM] [weeks]
-- Exit code 1 if a check fails.

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path

local content = require "game.model.content"
local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local deck = require "game.model.deck"
local ledger = require "game.model.ledger"
local world = require "game.model.world"
local planner = require "game.model.planner"
local save = require "game.model.save"
local bots = require "slice_bots"

local RUNS = tonumber(arg and arg[1]) or 50
local WEEKS = tonumber(arg and arg[2]) or 10
local t0 = os.clock()

local fails = {}
local function fail(msg)
    if #fails < 30 then
        table.insert(fails, msg)
    end
end

-- Tallies across every campaign.
local T = {
    results = {},          -- "faction:move:result" -> count
    projects_done = {}, pushed = {},
    att_up = 0, att_down = 0, standing_moved = {},
    rumours = 0, held = 0, held_back = 0,
    agenda = { warm = 0, cold = 0, back = 0, wrong = 0 },
    pins_missing = 0, pins = 0, shelved_dealt = 0, shelves = 0,
    spent_repeat = 0, opened = 0, thread_steps = { pin = {}, nopin = {} },
    cast_scenes = 0, cast_logged = 0,
    dead_cards = 0, truth_cards = {}, front_cards = {},
    save_ok = 0, save_bad = 0,
}

local function bump(t, k, n)
    t[k] = (t[k] or 0) + (n or 1)
end

-- A DM who makes random calls on the world's moves (to reach every branch).
local function random_world(c, rng)
    local w = world.get(c)
    for i, m in ipairs(w.moves) do
        if m.state == "pending" then
            local r = rng:next()
            if r < 0.2 then
                world.decide(c, i, "hold")
            elseif r < 0.45 then
                if not world.decide(c, i, "screen") then
                    world.decide(c, i, "let")
                end
            else
                world.decide(c, i, "let")
            end
        end
    end
end

local function run(dm_key, seed, plan)
    local dm = bots.DMS[dm_key] or bots.DMS.plain
    local c = campaign_mod.new(seed)
    local rng = rng_mod.new(seed + 3)
    if plan then
        planner.apply(c, plan)
    end
    c:session_zero(dm.s0)
    local spent_seen = {}
    local held_last = {}
    local pinned_any = false
    for w = 1, WEEKS do
        local prep = c:start_week()
        local wd = world.get(c)
        -- Held moves come back.
        for fid, mid in pairs(held_last) do
            -- (a held move whose condition no longer holds, say its player is away, doesn't come back)
            local still = world.allowed(c, fid, world.move_def(fid, mid))
            T.held = T.held + (still and 1 or 0)
            for _, m in ipairs(still and wd.moves or {}) do
                if m.faction == fid and m.move == mid then
                    T.held_back = T.held_back + 1
                end
            end
        end
        held_last = {}
        -- Rumours this week.
        for _, m in ipairs(c.chat or {}) do
            if m.key == "dm" and m.world then
                T.rumours = T.rumours + 1
            end
        end
        if dm_key == "random" then
            random_world(c, rng)
            -- Random pins too.
            local ps = c:present()
            if #ps > 0 and rng:chance(0.5) then
                prep:spotlight(rng:pick(ps).key)
            end
            local opts = prep:guest_options()
            for _ = 1, 2 do
                if #opts.people > 0 and rng:chance(0.6) then
                    prep:bring_in(rng:pick(opts.people))
                elseif #opts.places > 0 and rng:chance(0.3) then
                    prep:bring_in(rng:pick(opts.places).id)
                end
            end
            -- Shelve a random plain card now and then.
            if rng:chance(0.4) then
                local kind = rng:pick(content.kinds)
                local cand = prep.hand[kind][#prep.hand[kind]]
                if cand and prep:shelve(cand.id) then
                    T.shelves = T.shelves + 1
                end
            end
            bots.prep(bots.DMS.plain, c, prep, rng)
        else
            bots.prep(dm, c, prep, rng)
        end
        for _, m in ipairs(wd.moves) do
            if m.state == "held" then
                held_last[m.faction] = m.move
            end
        end
        -- Pins reach the hand; agenda cards match attitudes; shelved cards stay out.
        for id, p in pairs(prep.pins) do
            T.pins = T.pins + 1
            pinned_any = true
            local cd = content.components[id]
            local found = false
            for _, h in ipairs(cd and prep.hand[cd.kind] or {}) do
                found = found or h.id == id
            end
            if not found and not prep:placed_at(id) then
                T.pins_missing = T.pins_missing + 1
                fail("week " .. w .. ": pin " .. id .. " isn't in the hand")
            end
            if cd and cd.agenda then
                local k = cd.agenda_kind
                T.agenda[k] = T.agenda[k] + 1
                local a = ledger.att(c, cd.agenda)
                local ok = (k == "warm" and a >= 1) or (k == "cold" and a <= -1) or (k == "back")
                if not ok then
                    T.agenda.wrong = T.agenda.wrong + 1
                    fail(id .. " is " .. k .. " but " .. cd.agenda .. " is at " .. a)
                end
            end
        end
        for _, kind in ipairs(content.kinds) do
            for _, h in ipairs(prep.hand[kind]) do
                local st = deck.state(c, h.id)
                if st == "shelved" then
                    T.shelved_dealt = T.shelved_dealt + 1
                    fail("shelved card dealt: " .. h.id)
                end
                if st == "spent" or spent_seen[h.id] then
                    T.spent_repeat = T.spent_repeat + 1
                    fail("spent card back in the hand: " .. h.id)
                end
                -- Off-screen and pinned cards never bring back someone who's gone.
                if h.kind == "cast" then
                    local pid = ledger.person_of(h)
                    if pid and not ledger.around(c, pid) then
                        T.dead_cards = T.dead_cards + 1
                        fail("week " .. w .. ": " .. h.id .. " dealt while " .. ledger.person(c, pid).status)
                    end
                end
            end
        end
        -- Every third week, save at "Run game night" (the board, the world's moves, the notebook
        -- and agenda cards) and play the night from the reloaded campaign, the way a player who
        -- quit there would.
        if w % 3 == 0 then
            c.at_night = true
            local back = save.load(save.dump(c))
            local npins = 0
            for _ in pairs(back and back.prep and back.prep.pins or {}) do
                npins = npins + 1
            end
            local mpins = 0
            for _ in pairs(prep.pins) do
                mpins = mpins + 1
            end
            if back and back.world and #back.world.moves == #c.world.moves and back.notebook
                and #back.notebook.log == #c.notebook.log and npins == mpins then
                T.save_ok = T.save_ok + 1
                c = back
                prep = c.prep
            else
                T.save_bad = T.save_bad + 1
                fail("save round trip lost the world, the notebook or the pins (week " .. w .. ")")
            end
        end
        local night = c:start_night()
        bots.play_night(night, rng, dm)
        -- Every scene with a person in it is in the ledger.
        for _, sc in ipairs(night.scenes) do
            local pid = sc.terrain and night:cast_person(sc)
            if pid then
                T.cast_scenes = T.cast_scenes + 1
                local logged = false
                for _, e in ipairs(night.ledger) do
                    logged = logged or (e.to == pid and e.s == sc.index)
                end
                if logged then
                    T.cast_logged = T.cast_logged + 1
                else
                    fail("scene " .. sc.index .. " with " .. pid .. " isn't in the ledger")
                end
            end
        end
        local rep = c:finish_night()
        T.opened = T.opened + #(rep.opened or {})
        for _, ch in ipairs(rep.moved or {}) do
            if ch.kind == "att" then
                local order = { Hostile = -2, Wary = -1, Indifferent = 0, Warm = 1, Friendly = 2 }
                if (order[ch.to] or 0) > (order[ch.from] or 0) then
                    T.att_up = T.att_up + 1
                else
                    T.att_down = T.att_down + 1
                end
            elseif ch.kind == "standing" then
                bump(T.standing_moved, ch.id)
            end
        end
        for id, e in pairs(deck.get(c).cards) do
            if e.state == "spent" then
                spent_seen[id] = true
            end
        end
        if dm.level and rep.level and rep.level.ready then
            c:level_up()
        end
    end
    -- Thread progress, for pins against no pins.
    local steps = 0
    for _, list in pairs(deck.threads(c)) do
        for _, st in ipairs(list) do
            if st.state == "done" then
                steps = steps + 1
            end
        end
    end
    table.insert(pinned_any and T.thread_steps.pin or T.thread_steps.nopin, steps)
    -- World results and projects.
    for _, t in ipairs(world.get(c).timeline) do
        if t.via ~= "project" and t.via ~= "scene" then
            bump(T.results, t.faction .. ":" .. t.move .. ":" .. t.result)
        elseif t.via == "project" then
            bump(T.projects_done, t.faction)
        elseif t.result == "pushed" then
            bump(T.pushed, t.faction)
        end
    end
    -- Truths and fronts change what's in the deck.
    for _, id in ipairs(c.plan.truths) do
        local def = planner.truth_def(id)
        for _, cid in ipairs(def.cards) do
            if deck.state(c, cid) then
                T.truth_cards[id] = true
            end
        end
    end
    T.front_cards[c.plan.front] = (T.front_cards[c.plan.front] or 0) + 1
end

local dms = { "careful", "plain", "careless", "random" }
local plans = {
    nil,
    { truths = { "thieves", "weather", "barrows" }, front = "under_chapel", threads = { "jess", "sam" } },
}
local n = 0
for _, k in ipairs(dms) do
    for i = 1, RUNS do
        n = n + 1
        run(k, 9000 + i * 17 + #k, plans[(i % 2) + 1])
    end
end

-- The report ---------------------------------------------------------------------------------
local checks = {}
local function check(ok, name, detail)
    table.insert(checks, { ok = ok, name = name, detail = detail })
end

local function mean(list)
    local t = 0
    for _, v in ipairs(list) do
        t = t + v
    end
    return #list > 0 and t / #list or 0
end

check(T.spent_repeat == 0, "No spent card comes back (S1)", T.spent_repeat .. " repeats")
check(T.opened > n, "Played cards open follow-ups (S1)", T.opened .. " cards opened across " .. n .. " campaigns")
local truths = 0
for _ in pairs(T.truth_cards) do
    truths = truths + 1
end
check(truths >= 6, "Every truth puts its cards in the deck (S4)", truths .. " of 6 truths seen")
check(T.cast_scenes > 0 and T.cast_logged == T.cast_scenes, "Every scene with a person is in the ledger (S5)",
    T.cast_logged .. " of " .. T.cast_scenes)
check(T.att_up > 0 and T.att_down > 0, "Attitudes move both ways (S5)", T.att_up .. " warmer, " .. T.att_down .. " colder")
local moved = 0
for _ in pairs(T.standing_moved) do
    moved = moved + 1
end
local mlist = {}
for fid in pairs(T.standing_moved) do
    table.insert(mlist, fid)
end
table.sort(mlist)
check(moved >= 4, "Faction standing follows what the party does (S5)", moved .. " of 5 factions moved: " .. table.concat(mlist, ", "))
check(T.save_bad == 0 and T.save_ok > 0, "Saves keep the world and the notebook (S5, S7)", T.save_ok .. " round trips")
check(T.pins > 0 and T.pins_missing == 0, "Pins always reach the hand (S6)", T.pins .. " pins, " .. T.pins_missing .. " missing")
check(T.agenda.wrong == 0 and T.agenda.warm > 0 and T.agenda.cold > 0,
    "Agenda cards match attitudes (S6)",
    string.format("%d warm, %d cold, %d back, %d wrong", T.agenda.warm, T.agenda.cold, T.agenda.back, T.agenda.wrong))
check(T.shelves > 0 and T.shelved_dealt == 0, "Shelved cards are never dealt (S6)", T.shelves .. " shelved")
local mp, mn = mean(T.thread_steps.pin), mean(T.thread_steps.nopin)
check(mp > mn, "Pinning advances threads faster (S6)", string.format("%.1f steps with pins, %.1f without", mp, mn))
-- Every move's results reachable.
local missing = {}
for _, fid in ipairs(ledger.data.order) do
    for _, mv in ipairs(ledger.data[fid].moves) do
        for _, r in ipairs({ "full", "half", "bad" }) do
            if not T.results[fid .. ":" .. mv.id .. ":" .. r] then
                table.insert(missing, fid .. ":" .. mv.id .. ":" .. r)
            end
        end
    end
end
check(#missing == 0, "Every off-screen move's results happen (S7)",
    #missing == 0 and "all reached" or (#missing .. " never: " .. table.concat(missing, ", ")))
local filled, pushed = {}, {}
for _, fid in ipairs(ledger.data.order) do
    if ledger.data[fid].project then
        if T.projects_done[fid] then
            table.insert(filled, fid)
        end
        if T.pushed[fid] then
            table.insert(pushed, fid)
        end
    end
end
check(#filled >= 4, "Faction projects can fill (S7)", table.concat(filled, ", "))
check(#pushed >= 2, "The party can push projects back (S7)", table.concat(pushed, ", "))
check(T.rumours > 0, "Rumours reach the group chat (S7)", T.rumours .. " rumours")
check(T.held > 0 and T.held_back == T.held, "Held moves come back the next week (S7)", T.held_back .. " of " .. T.held)
check(T.dead_cards == 0, "Nobody gone comes back as a card (S7)", T.dead_cards .. " cards")

print(string.format("%d campaigns of %d weeks (%d per DM style)", n, WEEKS, RUNS))
local passed = 0
for _, ch in ipairs(checks) do
    print(string.format("  [%s] %s  -  %s", ch.ok and "PASS" or "FAIL", ch.name, ch.detail))
    if ch.ok then
        passed = passed + 1
    end
end
for i, f in ipairs(fails) do
    if i <= 12 then
        print("    " .. f)
    end
end
print(string.format("%d of %d checks pass  (%.0fs)", passed, #checks, os.clock() - t0))
os.exit(passed == #checks and 0 or 1)
