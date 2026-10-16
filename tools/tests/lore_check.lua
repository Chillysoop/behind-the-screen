-- The lore screen tells the truth (October 16): what it says before the night, the night then
-- does. Plays whole slices with each simulated DM and, every session, builds the lore screen from
-- the prepped board (game/model/lore_screen.lua), then checks it against what happened:
--   * every card the night opened from a prepped scene was on the screen, under the outcome
--     that opened it (a win's list, a loss's, or "just by playing it");
--   * a storyline the screen called cold and off the board, the table noticed when it didn't move;
--   * the clue next session hangs on: found, next session's goal is the screen's "Found" line;
--   * a scene's clue lines name only clues the party didn't have yet;
--   * the screen builds every session, and says something about every scene.
-- Run from the project root: texlua tools/tests/lore_check.lua [runs]

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path
unpack = unpack or table.unpack

local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local bots = require "slice_bots"
local content = require "game.model.content"
local story = require "game.model.story"
local lore = require "game.model.lore"
local ls = require "game.model.lore_screen"

local RUNS = tonumber(arg and arg[1]) or 4

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

local T = { views = 0, opened = 0, predicted = 0, missed_open = 0, cold_off = 0, cold_wrong = 0, hinge = 0, hinge_wrong = 0,
            clue_lines = 0, stale_clue = 0, items = 0 }

local WHY_KIND = { played = "opens", win = "opens_win", lose = "opens_lose", escaped = "opens_lose" }

for _, dm_key in ipairs(bots.ORDER) do
    local dm = bots.DMS[dm_key]
    for run = 1, RUNS do
        local seed = 16000 + run * 41 + #dm_key
        local c = campaign_mod.new(seed)
        local rng = rng_mod.new(seed + 5)
        c:session_zero(dm.s0)
        for w = 1, 4 do
            local prep = c:start_week()
            bots.prep(dm, c, prep, rng)
            local okv, view = pcall(ls.build, c, prep)
            if not okv then
                fail("week " .. w .. ": the lore screen failed to build: " .. tostring(view))
                break
            end
            T.views = T.views + 1
            -- Which scene each prepped card is on, and what the screen said about each scene.
            local scene_of, said = {}, {}
            for i, sv in ipairs(view.scenes) do
                for _, card in ipairs(sv.cards) do
                    scene_of[card.id] = scene_of[card.id] or i
                end
                said[i] = {}
                for _, it in ipairs(sv.items) do
                    T.items = T.items + 1
                    table.insert(said[i], it)
                    if it.kind == "clue" then
                        T.clue_lines = T.clue_lines + 1
                        if it.clue and story.has_clue(c, it.clue) then
                            T.stale_clue = T.stale_clue + 1
                            fail("week " .. w .. ": a clue line for a clue they already have: " .. it.clue)
                        end
                    end
                end
            end
            local cold_off = {}
            for _, r in ipairs(view.storylines) do
                if r.heat == "cold" and #r.scenes == 0 then
                    cold_off[r.id] = true
                end
            end
            local nx = view.next
            local night = c:start_night()
            bots.play_night(night, rng, dm, function() end)
            local moved = night.story_moved or {}
            local rep = c:finish_night()
            -- Every card the night opened from a prepped scene, the screen named under its outcome.
            for _, o in ipairs(rep.opened or {}) do
                local i = scene_of[o.from]
                local on_board = night.on_board and night.on_board[o.from]
                if i and on_board and WHY_KIND[o.why] then
                    T.opened = T.opened + 1
                    local words = ls.card_words(o.id)
                    local found = false
                    for _, it in ipairs(said[i]) do
                        -- (A win and a loss that open the same cards are one line: "Win or lose: ...".)
                        local either = it.kind == "opens" and string.sub(it.text, 1, 11) == "Win or lose"
                        if (it.kind == WHY_KIND[o.why] or (either and o.why ~= "played")) and string.find(it.text, words, 1, true) then
                            found = true
                        end
                    end
                    if found then
                        T.predicted = T.predicted + 1
                    else
                        T.missed_open = T.missed_open + 1
                        fail("week " .. w .. ": scene " .. i .. " (" .. o.from .. ", " .. o.why .. ") opened " .. o.id
                            .. ", and the lore screen didn't say so")
                    end
                end
            end
            -- A cold storyline nobody moved: the table noticed.
            local noticed = {}
            for _, id in ipairs(rep.storylines and rep.storylines.noticed or {}) do
                noticed[id] = true
            end
            for id in pairs(cold_off) do
                if not moved[id] then
                    T.cold_off = T.cold_off + 1
                    if not noticed[id] then
                        T.cold_wrong = T.cold_wrong + 1
                        fail("week " .. w .. ": " .. id .. " was cold and off the board, didn't move, and nobody noticed")
                    end
                end
            end
            -- The clue next session hangs on: found tonight, next session's goal is the "Found" line.
            if nx and nx.clue and not nx.found and nx.with and story.has_clue(c, nx.clue) and w < 4 then
                T.hinge = T.hinge + 1
                local obj = lore.objective(c, w + 1)
                if obj ~= nx.with then
                    T.hinge_wrong = T.hinge_wrong + 1
                    fail("week " .. w .. ": found " .. nx.clue .. ", but next session's goal is \"" .. tostring(obj)
                        .. "\", not the screen's \"" .. nx.with .. "\"")
                end
            end
        end
    end
end

check(T.views >= #bots.ORDER * RUNS * 4, "The lore screen builds every session", T.views .. " screens, " .. T.items .. " lines")
check(T.opened > 0 and T.missed_open == 0, "Everything a prepped scene opened, the lore screen said it would",
    string.format("%d of %d opened cards foretold", T.predicted, T.opened))
check(T.cold_wrong == 0, "A storyline it called cold and off the board, the table noticed when it didn't move",
    T.cold_off .. " cold storylines left alone")
check(T.hinge_wrong == 0, "Found the clue next session hangs on: next session's goal is the screen's \"Found\" line",
    T.hinge .. " clues found")
check(T.stale_clue == 0, "Clue lines only name clues the party doesn't have yet", T.clue_lines .. " clue lines")

for _, f in ipairs(fails) do
    print("  problem: " .. f)
end
print(ok_all and "LORE CHECK OK" or "LORE CHECK FAILED")
os.exit(ok_all and 0 or 1)
