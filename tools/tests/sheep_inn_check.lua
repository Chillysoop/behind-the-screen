-- The Sheep Chase's inn, upstairs and down (Conner, November 6: "the inn upstairs and cellar as fun exploration, with a
-- mini side quest", "maybe connect it to the loose end at the end of the museum"). Played whole, with the table's picks
-- forced where a case needs a branch: the fork after the common room, Sir Luenn's ring in each order, the rats' fight
-- and what comes after it, Teddy's bottle as a real potion, the road out leaving the inn's rooms behind, Teddy's
-- rumours only at the bar, Sam's spiders veil, and the drover's token for a party carrying the museum's mountain road.
--     lua tools/tests/sheep_inn_check.lua

package.path = "./?.lua;./tools/tests/?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
adventure.use("sheep")
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local museum_week = require "game.model.museum_week"
local museum_night = require "game.model.museum_night"
local items = require "game.model.items"
local events = require "game.model.events"

local fails, seen = {}, {}
local function check(ok, what)
    if not ok then
        table.insert(fails, what)
        print("  FAIL " .. what)
    end
end

-- The table's picks, forced by card id (an option's number), and the fork's, by the order of rooms to try.
local FORCE, ROUTE = {}, nil
local table_pick, fork = museum_night.table_pick, museum_night.fork
museum_night.table_pick = function(night, copy, vars)
    local f = FORCE[copy.id]
    if f and copy.options[f] and not copy.options[f].disabled then
        return f
    end
    return table_pick(night, copy, vars)
end
museum_night.fork = function(night, options, backs, sides)
    for _, want in ipairs(ROUTE or {}) do
        for _, id in ipairs(options) do
            if id == want then
                return { id = id }
            end
        end
    end
    return fork(night, options, backs, sides)
end

-- One Sheep Chase, the sim's way (tools/sim/museum.lua, careful), every line said kept with the room it was said in.
local function play(seed, opts)
    opts = opts or {}
    FORCE, ROUTE = opts.force or {}, opts.route
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    if opts.veil ~= nil then
        c.table = c.table or {}
        c.table.veils = c.table.veils or {}
        c.table.veils.spiders = opts.veil or nil
    end
    if opts.threads then
        c.threads = opts.threads
    end
    local rng = require("game.model.rng").new(seed + 77)
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        local hooks = adventure.data.hooks[key]
        adventure.set_hook(c, key, hooks[rng:int(1, #hooks)].id)
    end
    local R = { c = c, lines = {}, rooms = {}, potions_before = 0 }
    for _, p in ipairs(c.players) do
        R.potions_before = R.potions_before + items.count(c, p.key, items.POTION)
    end
    for _ = 1, adventure.data.MAX_WEEKS do
        local prep = c:start_week()
        for _, m in ipairs(c.chat) do
            if m.ask and not m.answered then
                museum_week.answer_chat(c, m, 1)
            end
        end
        museum_week.prep_greedy(prep)
        local night = c:start_night()
        local ev = night:advance()
        local guard = 0
        while ev.kind ~= "done" and guard < 4000 do
            guard = guard + 1
            local room = night.scene and night.scene.room or "-"
            if ev.kind == "scene" then
                table.insert(R.rooms, room)
            end
            if type(ev.text) == "string" or ev.kind == "tiny_roll" then
                table.insert(R.lines, { room = room, kind = ev.kind, name = ev.name, text = type(ev.text) == "string" and ev.text or "" })
            end
            local answer
            if ev.kind == "decision" then
                answer = 1
                if ev.card.options[1] and ev.card.options[1].disabled then
                    answer = 2
                end
            elseif ev.kind == "thought" then
                require("game.model.thoughts").bot_play(night, ev, "careful", rng)
            elseif ev.kind == "ruling" then
                answer = 1
            elseif ev.kind == "improv" then
                answer = { 1 }
            elseif ev.kind == "roll_where" then
                answer = "open"
            elseif ev.kind == "roll" then
                answer = rng:d20()
            end
            ev = night:advance(answer)
        end
        c:finish_night()
        c:level_up()
        if adventure.over(c) then
            break
        end
    end
    R.ending = c.adv.ending
    R.flags = c.adv.flags
    local n = 0
    for _, p in ipairs(c.players) do
        n = n + items.count(c, p.key, items.POTION)
    end
    R.potions_after = n
    return R
end

local function said(R, pattern, room)
    for _, l in ipairs(R.lines) do
        if (not room or l.room == room) and string.find(l.text, pattern) then
            return l
        end
    end
end
local function played(R, room)
    for _, r in ipairs(R.rooms) do
        if r == room then
            return true
        end
    end
    return false
end
local function ok(name, cond, msg)
    seen[name] = (seen[name] or 0) + 1
    check(cond, name .. ": " .. msg)
end

-- DATA: the way the rooms join up --------------------------------------------------------------
do
    local M = adventure.data
    local nxt = M.rooms.inn_common.next
    local has = {}
    for _, id in ipairs(nxt) do
        has[id] = true
    end
    ok("DATA", has.inn_upstairs and has.inn_cellar and has.woods_path, "the common room leads up, down and out")
    ok("DATA", M.rooms.woods_path.leaves and #M.rooms.woods_path.leaves == 2, "the road out leaves the inn's two rooms behind")
    local nest_after
    for _, m in ipairs(M.moments) do
        if m.id == "nest_after_fight" then
            nest_after = m
        end
    end
    ok("DATA", nest_after and nest_after.options[1].mus and nest_after.options[1].mus.flag == "ring_found",
       "a story event's `sets` is set when it plays (the heap after the fight)")
    ok("DATA", items.thing_for({ flag = "wenna_thanked" }) and items.thing_for({ flag = "wenna_thanked" }).as == items.POTION,
       "Teddy's bottle is a healing potion")
end

-- UP FIRST: upstairs, then the cellar, the rats fought, Sir Luenn handed his ring ------------------------
for _, seed in ipairs({ 11, 12 }) do
    local R = play(seed, { route = { "inn_upstairs", "inn_cellar", "woods_path" }, force = { the_nest = 1, ring_back = 1 } })
    local tag = "UP FIRST seed " .. seed
    ok(tag, played(R, "inn_upstairs") and played(R, "inn_cellar"), "both rooms played")
    ok(tag, said(R, "Sir Luenn flings open his door", "inn_upstairs") ~= nil, "Sir Luenn shows them his room")
    ok(tag, said(R, "explodes into rats", "inn_cellar") ~= nil, "grabbing the heap wakes the rats")
    ok(tag, R.flags.rats_fought and R.flags.ring_found, "the fight, then the heap is theirs")
    ok(tag, said(R, "With the last rat gone", "inn_cellar") ~= nil, "the heap after the fight is said")
    ok(tag, R.flags.ring_back and said(R, "counts out twenty gold") ~= nil, "Sir Luenn gets his ring back, and pays")
    ok(tag, not said(R, "token", "inn_cellar"), "no drover's token without the museum's mountain road")
    ok(tag, R.ending ~= nil, "the adventure still reaches an ending (" .. tostring(R.ending) .. ")")
    -- (Order: Sir Luenn opens his door before anyone pokes about upstairs; nothing happens in the cellar once they've
    -- climbed back up with the ring.)
    local door, first_poke, ladder, after_ladder
    for i, l in ipairs(R.lines) do
        if l.room == "inn_upstairs" then
            if not door and string.find(l.text, "Sir Luenn flings open his door", 1, true) then door = i end
            if not first_poke and l.kind == "tiny_roll" then first_poke = i end
        elseif l.room == "inn_cellar" then
            if string.find(l.text, "Back up the ladder", 1, true) then ladder = i end
            if ladder and i > ladder and l.kind == "tiny_roll" then after_ladder = i end
        end
    end
    ok(tag, door and (not first_poke or door < first_poke), "Sir Luenn's door opens before anyone pokes about upstairs")
    ok(tag, ladder and not after_ladder, "no small moments in the cellar after they climb back up")
end

-- DOWN FIRST: the cellar first, the ring lifted, Wenna hands it back, Teddy's bottle -------------------
for _, seed in ipairs({ 13, 14 }) do
    local R = play(seed, { route = { "inn_cellar", "inn_upstairs", "woods_path" }, force = { the_nest = 3, ring_back = 2 } })
    local tag = "DOWN FIRST seed " .. seed
    ok(tag, played(R, "inn_cellar") and played(R, "inn_upstairs"), "both rooms played")
    ok(tag, R.flags.ring_found, "the ring's out of the heap, one way or the other")
    if R.flags.ring_back then
        ok(tag, R.flags.wenna_thanked and R.potions_after >= R.potions_before + 1 - 4 and said(R, "dusty bottle") ~= nil,
           "Wenna hands it back, and Teddy's bottle is in a pack")
        ok(tag, not said(R, "Sir Luenn flings open his door"), "with the ring back already, nobody searches his room for it")
        ok(tag, said(R, "Sir Luenn has his ring, and nobody's blaming Wenna", "inn_upstairs") ~= nil
            or said(R, "had a good look round upstairs", "inn_upstairs") ~= nil, "upstairs ends true to it")
    end
end

-- POTION: Teddy's bottle works like a healing potion ---------------------------------------------------
do
    local c = campaign_mod.new(5)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    local before = items.count(c, "sam", items.POTION)
    adventure.apply(c, { flag = "wenna_thanked", flags = { "ring_back" } }, "inn_cellar", "sam")
    ok("POTION", items.count(c, "sam", items.POTION) == before + 1, "a healing potion in Oswin's pack")
end

-- OUT: straight to the road, and the inn's rooms are behind them for good ------------------------------
for _, seed in ipairs({ 15, 16 }) do
    local R = play(seed, { route = { "woods_path" } })
    local tag = "OUT seed " .. seed
    ok(tag, not played(R, "inn_upstairs") and not played(R, "inn_cellar"), "neither inn room plays once they're on the road")
    ok(tag, R.c.adv.skipped.inn_upstairs and R.c.adv.skipped.inn_cellar, "both are left behind")
    ok(tag, R.ending ~= nil, "it still ends (" .. tostring(R.ending) .. ")")
end

-- AT THE BAR: Teddy tells his rumours in the common room, never upstairs or in the cellar ----------------
-- VEIL: Sam's spiders, kept off screen when the table agreed to it -------------------------------------
for _, seed in ipairs({ 17, 18, 19 }) do
    local R = play(seed, { route = { "inn_cellar", "inn_upstairs", "woods_path" }, veil = true })
    local tag = "BAR seed " .. seed
    for _, l in ipairs(R.lines) do
        if l.name == "Teddy" then
            ok(tag, l.room ~= "inn_upstairs" and l.room ~= "inn_cellar", "Teddy speaks in " .. l.room .. ": " .. l.text)
        end
    end
    ok("VEIL seed " .. seed, not said(R, "spiders", "inn_cellar") and not said(R, "webs, how many", "inn_cellar"),
       "no spiders described in the cellar under Sam's veil")
end

-- MOUNTAIN ROAD: a party carrying the museum's loose end finds the drover's token, and hears him out -------------
for _, seed in ipairs({ 21, 22 }) do
    local threads = { { id = "mountain_road", from = "museum", name = "A murder up the mountain road",
                        tags = { "mountain_road", "murder", "mountains" },
                        text = "Flitwidget has had strange news from the mountains.", who = "mus_flitwidget" } }
    local R = play(seed, { route = { "inn_upstairs", "inn_cellar", "woods_path" }, threads = threads,
                           force = { the_nest = 3, ring_back = 1, token_back = 1 } })
    local tag = "MOUNTAIN seed " .. seed
    ok(tag, said(R, "Travellers down from the mountains", "inn_common") ~= nil, "Teddy's mountains rumour at the bar")
    if R.flags.ring_found then
        ok(tag, said(R, "horn token", "inn_cellar") ~= nil, "the drover's token is in the heap")
        ok(tag, R.flags.drover_talked and said(R, "Somebody carried him there after") ~= nil, "Hobb says what he saw")
        local carried = false
        for _, t in ipairs(adventure.data.threads) do
            if t.id == "hobbs_word" then
                carried = t.open_at_end and adventure.test(R.c, t.when)
            end
        end
        ok(tag, carried, "what Hobb saw goes on to the next adventure as an open thread")
        ok(tag, said(R, "Hobb's word on the death up the mountain road") ~= nil, "the ending says they came away with it")
    end
end

-- THREAD: heroes carried over from the museum say why they came on this adventure, not "to the museum" (the
-- screens review, 8_73) -----------------------------------------------------------------------------------------
do
    adventure.use("museum")
    local c = campaign_mod.new(31)
    adventure.enter(c)
    local before = c.players[1].thread
    adventure.handoff(c, "sheep")
    for _, p in ipairs(c.players) do
        ok("THREAD", not tostring(p.thread):find("museum"), p.key .. "'s thread is the inn's (" .. tostring(p.thread) .. ")")
    end
    ok("THREAD", tostring(before):find("museum") ~= nil, "the museum's own words were there before")
end

local n = 0
for _ in pairs(seen) do
    n = n + 1
end
print(#fails == 0 and ("sheep inn check: all clear (" .. n .. " groups)") or ("sheep inn check: " .. #fails .. " failures"))
os.exit(#fails == 0 and 0 or 1)
