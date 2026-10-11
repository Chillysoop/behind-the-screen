-- The A13 gate: new books. Plays campaigns where the DM reads each book when it comes out and
-- pulls three things in, then uses them: a pulled monster leads a fight, a pulled item is won and
-- carried (and the rules apply it), a pulled place hosts a scene, and a published adventure runs,
-- straight from the book in some campaigns and customized in others.
-- Run from the project root:   texlua tools/sim/books.lua [campaigns] [weeks]

package.path = "./?.lua;./tools/sim/?.lua;" .. package.path

local campaign_mod = require "game.model.campaign"
local rng_mod = require "game.model.rng"
local content = require "game.model.content"
local books = require "game.model.books"
local items = require "game.model.items"
local ledger = require "game.model.ledger"
local util = require "game.model.util"
local bots = require "slice_bots"

local RUNS = tonumber(arg and arg[1]) or 8
local WEEKS = tonumber(arg and arg[2]) or 5
local DM = bots.DMS.careful

local T = { arrived = {}, chat = 0, pulls = 0, readings = 0, over_limit = 0, lifted = 0,
            monster_led = 0, monster_runs = 0, item_won = 0, item_tried = 0, item_applied = 0,
            place_hosted = 0, place_tried = 0,
            module_runs = 0, module_cost_ok = 0, module_read = 0, module_lines = 0,
            straight = 0, straight_note = 0, custom = 0, custom_notebook = 0, problems = {} }

local function problem(msg)
    if #T.problems < 12 then
        table.insert(T.problems, msg)
    end
end

-- What the DM pulls: the bestiary's first monster that suits, an item, a place; the gazetteer's
-- adventure, a place and a hook.
local function choose(campaign, reading, rng)
    local bk = books.book(reading.book)
    local want = reading.book == "vale_bestiary" and { "monster", "item", "item" } or { "module", "place", "hook" }
    local picks = {}
    for _, kind in ipairs(want) do
        local pool = {}
        for _, e in ipairs(bk.entries) do
            if e.kind == kind and not books.get(campaign).pulled[e.id] and not util.contains(picks, e.id)
                and #books.uneasy(campaign, e) == 0 then
                table.insert(pool, e.id)
            end
        end
        if #pool > 0 then
            table.insert(picks, pool[rng:int(1, #pool)])
        end
    end
    return picks
end

-- A scene a card fits, turned over to its type if need be.
local function place_on(prep, id, avoid, avoid2)
    local card = content.components[id]
    for i = 1, #prep.scenes do
        if i ~= avoid and i ~= avoid2 and not prep.scenes[i].module and util.contains(card.fits or {}, prep.scenes[i].type) then
            prep:clear(i, card.kind)
            if prep:place(i, id) then
                return i
            end
        end
    end
    for i = #prep.scenes, 1, -1 do
        if i ~= avoid and i ~= avoid2 and not prep.scenes[i].module and not prep.scenes[i].open then
            prep:set_type(i, card.fits[1])
            prep:clear(i, card.kind)
            if prep:place(i, id) then
                return i
            end
        end
    end
    return nil
end

for run = 1, RUNS do
    local seed = 9100 + run * 29
    local c = campaign_mod.new(seed)
    local rng = rng_mod.new(seed + 5)
    c:session_zero(DM.s0)
    local customize = run % 2 == 0
    local pulled_monster, pulled_items, pulled_place = nil, {}, nil
    for w = 1, WEEKS do
        local prep = c:start_week()
        for _, m in ipairs(c.chat or {}) do
            if m.book then
                T.chat = T.chat + 1
                T.arrived[m.book] = (T.arrived[m.book] or 0) + 1
                if books.book(m.book).week ~= w then
                    problem("a book arrived in week " .. w .. " (due " .. books.book(m.book).week .. ")")
                end
            end
        end
        -- Read the new book, if there is one.
        if books.newest(c) and prep:can_inspire("supplement") then
            prep:inspire("supplement")
            local r = prep.reading
            if r then
                T.readings = T.readings + 1
                for _, id in ipairs(choose(c, r, rng)) do
                    local ok, lifted = books.pull(c, prep, r, id)
                    if ok then
                        T.pulls = T.pulls + 1
                        T.lifted = T.lifted + #lifted
                        local e = books.entry(id)
                        if e.kind == "monster" then pulled_monster = pulled_monster or e end
                        if e.kind == "item" then table.insert(pulled_items, e) end
                        if e.kind == "place" then pulled_place = pulled_place or e end
                    end
                end
                -- The limit holds.
                for _, e in ipairs(books.book(r.book).entries) do
                    if not books.get(c).pulled[e.id] and books.can_pull(c, r, e.id) then
                        T.over_limit = T.over_limit + 1
                        break
                    end
                end
            end
        end
        -- Use what came in: an adventure on scene 2, a monster leading scene 1's fight, an item as a reward.
        local mod_scene
        local mods = books.modules(c)
        if #mods > 0 then
            if prep:place_module(3, mods[1]) then
                mod_scene = 3
                if customize then
                    local opts = prep:recast_options(3)
                    if opts[1] then
                        prep:swap(3, opts[1].card.id)
                    end
                end
                local expect = content.books.MODULE_COST + (next(prep.scenes[3].module.swaps) and content.books.SWAP_COST or 0)
                if prep:module_cost(3) == expect then
                    T.module_cost_ok = T.module_cost_ok + 1
                end
                T.module_runs = T.module_runs + 1
            end
        end
        bots.prep(DM, c, prep, rng)
        local fight_scene
        if pulled_monster then
            -- Its card on scene 1: the card brings its fight, with the monster leading.
            local fs = 1
            prep:set_type(fs, "combat")
            prep:clear(fs, "cast")
            prep.scenes[fs].encounter = nil
            if prep:place(fs, pulled_monster.card.id) then
                fight_scene = fs
                T.monster_runs = T.monster_runs + 1
            end
        end
        local item_scene, item_card
        for _, e in ipairs(pulled_items) do
            local card = content.components[e.card.id]
            if not (c.items_earned or {})[card.id] and not prep:placed_at(card.id) then
                item_scene = place_on(prep, card.id, mod_scene, fight_scene)
                if item_scene then
                    item_card = card
                    T.item_tried = T.item_tried + 1
                    break
                end
            end
        end
        local place_scene
        if pulled_place and not pulled_place.hosted then
            place_scene = place_on(prep, pulled_place.card.id, mod_scene, fight_scene)
            if place_scene then
                T.place_tried = T.place_tried + 1
            end
        end
        local items_before = #items.list(c)
        local night = c:start_night()
        local read, lines, noted = false, 0, false
        local led = false
        local ev = night:advance()
        local guard = 0
        while ev.kind ~= "done" and guard < 900 do
            guard = guard + 1
            local a
            if ev.kind == "narrate" and mod_scene then
                local m = books.module(night.prep.scenes[mod_scene].module.id)
                if ev.text and string.find(ev.text, string.sub(m.read_aloud, 8, 40), 1, true) then
                    read = true
                end
            elseif ev.kind == "npc" and ev.cast and (string.sub(ev.cast, 1, 4) == "mod_" or (mod_scene and night.scene
                and night.scene.index == mod_scene)) then
                lines = lines + 1
            elseif ev.kind == "say" and ev.text and string.find(ev.text, "connect to anything", 1, true) then
                noted = true
            elseif ev.kind == "battle" and ev.phase == "start" and fight_scene and night.scene and night.scene.index == fight_scene then
                if ev.foes[1] and ev.foes[1].monster == pulled_monster.monster then
                    led = true
                end
                -- The items the party carries are on their sheets.
                for _, pc in ipairs(night.pc_list or {}) do
                    if pc.items and #pc.items > 0 then
                        T.item_applied = T.item_applied + 1
                    end
                end
            elseif ev.kind == "decision" then
                a = rng:int(1, #ev.card.options)
            elseif ev.kind == "improv" then
                a = 1
            elseif ev.kind == "roll_where" then
                a = "open"
            elseif ev.kind == "roll" then
                a = rng:d20()
            elseif ev.kind == "cook" then
                a = false
            end
            ev = night:advance(a)
        end
        if fight_scene then
            T.monster_led = T.monster_led + (led and 1 or 0)
            if not led and os.getenv("BOOKS_DEBUG") then
                local sc = night.scenes[fight_scene]
                print("not led:", pulled_monster.monster, "scene type", sc.type, "cast", sc.comps.cast and sc.comps.cast.id,
                    "open", tostring(sc.open), "chosen", tostring(sc.chosen_spot), "result", sc.result and sc.result.winner, "outcome", sc.outcome, "terrain", sc.terrain, "talked", tostring(sc.talked_down or sc.skip_fight))
            end
        end
        if place_scene and night.scenes[place_scene] and night.scenes[place_scene].terrain then
            T.place_hosted = T.place_hosted + 1
            pulled_place.hosted = true
        end
        if mod_scene and night.scenes[mod_scene] and night.scenes[mod_scene].terrain then
            T.module_read = T.module_read + (read and 1 or 0)
            T.module_lines = T.module_lines + (lines > 0 and 1 or 0)
        end
        -- Straight from the book: the storyteller's note. Customized: the notebook moves.
        local week = c.week
        local custom = mod_scene and night.scenes[mod_scene].module_custom
        local person = custom and ledger.person_of(night.scenes[mod_scene].comps.cast)
        c:finish_night()
        if mod_scene and night.scenes[mod_scene].terrain then
            if custom then
                T.custom = T.custom + 1
                local hist = person and ledger.history(c, person) or {}
                if hist[1] and hist[1].w == week then
                    T.custom_notebook = T.custom_notebook + 1
                end
            else
                T.straight = T.straight + 1
                T.straight_note = T.straight_note + (noted and 1 or 0)
            end
        end
        if item_card and #items.list(c) > items_before then
            T.item_won = T.item_won + 1
        end
    end
end

local function pct(a, b)
    return b > 0 and (100 * a / b) or 0
end
print(string.format("books arrived: %s; chat posts %d; readings %d, pulls %d, lifted %d players",
    (function() local t = {} for k, v in pairs(T.arrived) do table.insert(t, k .. " x" .. v) end table.sort(t) return table.concat(t, ", ") end)(),
    T.chat, T.readings, T.pulls, T.lifted))
print(string.format("monster led its fight %d/%d; item won %d/%d (carried into fights %d times); place hosted %d/%d",
    T.monster_led, T.monster_runs, T.item_won, T.item_tried, T.item_applied, T.place_hosted, T.place_tried))
print(string.format("adventures run %d, cost right %d, read-aloud %d, lines %d; straight %d (note %d), customized %d (notebook %d)",
    T.module_runs, T.module_cost_ok, T.module_read, T.module_lines, T.straight, T.straight_note, T.custom, T.custom_notebook))
for _, p in ipairs(T.problems) do
    print("  problem: " .. p)
end
local gates = {
    { "Both books come out on their weeks, and the group chat says so",
      (T.arrived.vale_bestiary or 0) == RUNS and (T.arrived.vale_gazetteer or 0) == RUNS and #T.problems == 0 },
    { "A reading pulls in at most three, and whoever was excited gets a lift", T.over_limit == 0 and T.pulls > 0 and T.lifted > 0 },
    { "A pulled monster leads a fight", T.monster_runs > 0 and pct(T.monster_led, T.monster_runs) >= 90 },
    { "A pulled item is won, carried, and on the hero's sheet in a fight", T.item_won > 0 and T.item_applied > 0 },
    { "A pulled place hosts a scene", T.place_tried > 0 and pct(T.place_hosted, T.place_tried) >= 80 },
    { "A published adventure costs what prep says and plays its read-aloud and its person's lines",
      T.module_runs > 0 and T.module_cost_ok == T.module_runs and T.module_read > 0 and T.module_lines > 0 },
    { "Straight from the book it doesn't connect; customized, the notebook moves",
      T.straight > 0 and T.straight_note > 0 and T.custom > 0 and T.custom_notebook > 0 },
}
local ok = true
for _, g in ipairs(gates) do
    print(string.format("  [%s] %s", g[2] and "PASS" or "FAIL", g[1]))
    ok = ok and g[2]
end
os.exit(ok and 0 or 1)
