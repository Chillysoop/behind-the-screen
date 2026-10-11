-- The A15 gate: open scenes and Your places (player agency). Plays campaigns where the DM runs
-- open scenes and checks that the players choose, by type and story, and that prep compounds.
-- Run from the project root:   texlua tools/sim/agency.lua [campaigns] [weeks]

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path

local content = require "game.model.content"
local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local places = require "game.model.places"
local bots = require "slice_bots"

local RUNS = tonumber(arg and arg[1]) or 30
local WEEKS = tonumber(arg and arg[2]) or 6

local st = { open = 0, chosen = {}, pitches = 0, why = {}, thread_ok = 0, thread_n = 0, wild = 0, sketched_play = 0,
             improvised_loc = 0, modes = {}, free_reuse = 0, again = 0, known_max = 0, errors = 0 }

local dm = {}
for k, v in pairs(bots.DMS.careful) do
    dm[k] = v
end
dm.open = 1   -- every week from week 2

for run = 1, RUNS do
    local c = campaign_mod.new(9000 + run * 7)
    local rng = rng_mod.new(9100 + run)
    c:session_zero(dm.s0)
    for w = 1, WEEKS do
        local prep = c:start_week()
        bots.prep(dm, c, prep, rng)
        -- Prep compounds: a known place costs nothing.
        for _, s in ipairs(prep.scenes) do
            for _, id in ipairs(s.spots or {}) do
                if places.is_known(c, id) then
                    st.free_reuse = st.free_reuse + 1
                end
            end
        end
        local night = c:start_night()
        local ev = night:advance()
        local guard = 0
        while ev.kind ~= "done" and guard < 3000 do
            guard = guard + 1
            local a
            if ev.kind == "decision" then
                if ev.card.type == "agency" then
                    a = rng:int(1, #ev.card.options)
                else
                    a = rng:int(1, #ev.card.options)
                end
            elseif ev.kind == "improv" then a = 1
            elseif ev.kind == "roll_where" then a = "open"
            elseif ev.kind == "roll" then a = rng:d20()
            elseif ev.kind == "cook" then a = false end
            ev = night:advance(a)
        end
        if guard >= 3000 then st.errors = st.errors + 1 end
        for _, sc in ipairs(night.scenes) do
            if sc.open and sc.chosen_spot then
                st.open = st.open + 1
                st.chosen[sc.chosen_spot] = (st.chosen[sc.chosen_spot] or 0) + 1
                if util_contains and false then end
                local sketched = false
                for _, id in ipairs(sc.spots or {}) do
                    sketched = sketched or id == sc.chosen_spot
                end
                if sketched then st.sketched_play = st.sketched_play + 1 end
                for _, pt in ipairs(sc.pitches or {}) do
                    st.pitches = st.pitches + 1
                    local why = pt.why or "taste"
                    if string.sub(why, 1, 7) == "person:" then why = "person" end
                    st.why[why] = (st.why[why] or 0) + 1
                    local card = content.components[pt.id]
                    if why == "thread" then
                        st.thread_n = st.thread_n + 1
                        if card.thread == pt.who then st.thread_ok = st.thread_ok + 1 end
                    end
                    if why == "again" then st.again = st.again + 1 end
                end
            end
        end
        c:finish_night()
        st.known_max = math.max(st.known_max, #places.list(c))
    end
end

local distinct = 0
local parts = {}
for id, n in pairs(st.chosen) do
    distinct = distinct + 1
    table.insert(parts, id .. " " .. n)
end
table.sort(parts)
local whys = {}
for k, v in pairs(st.why) do table.insert(whys, k .. " " .. v) end
table.sort(whys)
print(string.format("%d open scenes, %d pitches (%s)", st.open, st.pitches, table.concat(whys, ", ")))
print("where they went: " .. table.concat(parts, ", "))
print(string.format("places known at most: %d; spots reused for free: %d", st.known_max, st.free_reuse))
local gates = {
    { "Open scenes play without errors", st.errors == 0 and st.open > 0 },
    { string.format("Players choose different places across runs (A15): %d places", distinct), distinct >= 6 },
    { string.format("Pitches follow story as well as taste: %d from threads, %d from the notebook, %d going back",
        st.thread_n, st.why.person or 0, st.again), st.thread_n > 0 and (st.why.person or 0) > 0 and st.again > 0 },
    { string.format("Thread pitches come from the thread's owner: %d of %d", st.thread_ok, st.thread_n), st.thread_ok == st.thread_n },
    { "Some ideas nobody prepped (wild pitches)", (st.why.wild or 0) > 0 },
    { string.format("Prep compounds: sketched places come back free (%d)", st.free_reuse), st.free_reuse > 0 },
}
local ok = true
for _, g in ipairs(gates) do
    print(string.format("  [%s] %s", g[2] and "PASS" or "FAIL", g[1]))
    ok = ok and g[2]
end
os.exit(ok and 0 or 1)
