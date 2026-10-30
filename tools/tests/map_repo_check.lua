-- The map repository and the open floors (v2, October 30), headless. Run from the project root:
--   lua tools/tests/map_repo_check.lua
-- Checks: the repository lists maps (none from the old valley), the DM's own maps make, copy and
-- delete, a room set to another map plays on it, a side room plays, the floors join as the book's
-- doors do, rooms walked past raise their loose ends, and going back for one brings its mark home.

package.path = "./?.lua;" .. package.path
unpack = unpack or table.unpack

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local social = require "game.model.social"
local map_repo = require "game.model.map_repo"
local museum_night = require "game.model.museum_night"
local board = require "game.model.board"

local fails, checks = 0, 0
local function check(cond, msg)
    checks = checks + 1
    if not cond then
        fails = fails + 1
        print("FAIL: " .. msg)
    end
end

local function new_campaign(seed)
    adventure.enter()
    local c = campaign_mod.new(seed)
    adventure.enter(c)
    c:session_zero(social.default_choices())
    for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
        adventure.set_hook(c, key, adventure.data.hooks[key][1].id)
    end
    return c
end

-- Play a night to the end, answering every card with its first option; returns the scenes' boards.
local function play(c, night)
    local boards_seen = {}
    local ev = night:advance()
    local guard = 0
    while ev.kind ~= "done" and guard < 4000 do
        guard = guard + 1
        local answer
        if ev.kind == "scene" then
            table.insert(boards_seen, { title = ev.title, board = ev.board })
        elseif ev.kind == "decision" then
            answer = 1
        elseif ev.kind == "ruling" then
            answer = 1
        elseif ev.kind == "improv" then
            answer = { 1 }
        elseif ev.kind == "roll_where" then
            answer = "open"
        elseif ev.kind == "roll" then
            answer = 15
        end
        ev = night:advance(answer)
    end
    check(guard < 4000, "a night finished")
    return boards_seen
end

-- 1. The repository.
local c = new_campaign(11)
local entries = map_repo.entries(c)
check(#entries >= 5, "the repository lists maps (" .. #entries .. ")")
local groups = {}
for _, e in ipairs(entries) do
    groups[e.group] = (groups[e.group] or 0) + 1
    check(not adventure.foreign(e.title), "no old-valley map in the museum's repository: " .. e.title)
    check(map_repo.board_of(c, e.ref) ~= nil, "every map has a board: " .. e.ref)
    check(map_repo.preview(c, e.ref) ~= nil, "every map previews: " .. e.ref)
end
check((groups.basics or 0) >= 5, "boards to start from")
if (groups.adventure or 0) > 0 then
    check(groups.adventure >= 10, "the museum's own rooms are in the repository (" .. groups.adventure .. ")")
end

-- 2. The DM's own maps.
local id = map_repo.new_map(c, "blank", "Test map")
check(c.my_maps[id] and c.my_maps[id].name == "Test map", "a new map has its name")
local m = map_repo.pieces_of(c, id)
check(m and m.template == "blank", "a new map stands on open ground")
local maps = require "game.model.maps"
local ok = maps.place(m, "pillar", 5, 5, 0)
check(ok, "a piece goes down on your own map")
local bid = map_repo.board_of(c, "mine:" .. id)
check(bid and board.registered(bid), "your map registers as a board")
local cp = map_repo.copy(c, "board:ruins")
check(cp and map_repo.pieces_of(c, cp).template == "ruins", "a copy of a built-in board stands on it")
local cp2 = map_repo.copy(c, "mine:" .. id)
check(cp2 and #map_repo.pieces_of(c, cp2).props == 1, "a copy of your map keeps its pieces")
map_repo.delete(c, cp2)
check(not c.my_maps[cp2] and not map_repo.pieces_of(c, cp2), "a deleted map is gone")

-- 3. A room set to another map plays on it, and a side room plays.
map_repo.set_room_map(c, "garden", "mine:" .. id)
map_repo.add_side_room(c, "board:camp", "entrance", "A tent in the hall")
local prep = c:start_week()
require("game.model.museum_week").prep_greedy(prep)
local night = c:start_night()
local seen = play(c, night)
c:finish_night()
local garden_on = nil
for _, s in ipairs(seen) do
    if s.title and s.title:find("garden") then
        garden_on = s.board
    end
end
check(garden_on == bid, "the garden played on the DM's map (" .. tostring(garden_on) .. ")")
-- The side room: offered off the entrance, and it plays when picked.
local st = c.adv
local sid = map_repo.side_rooms_off(c, "entrance")[1]
check(sid ~= nil, "the side room is off the entrance")
if not (st.side_done and st.side_done[sid]) then
    -- (The table didn't choose it tonight: walk in by hand.)
    local n2 = c:start_night()
    n2.mus = n2.mus or { added = {}, pending = {}, rooms = {}, harsh_log = {} }
    st.pos = "entrance"
    local opts = museum_night.side_options(n2)
    check(#opts == 1, "the side room is an option from the entrance (" .. #opts .. ")")
end

-- 4. The floors, as the book's doors join them.
local c2 = new_campaign(12)
local st2 = c2.adv
for _, rid in ipairs({ "street", "garden", "entrance", "chamber" }) do
    adventure.enter_room(c2, rid, 1)
    adventure.leave_room(c2, rid, "win", 1)
end
local after = adventure.options_after(c2, "chamber")
local function has(t, v)
    for _, x in ipairs(t) do
        if x == v then
            return true
        end
    end
    return false
end
check(has(after, "paintings") and has(after, "gift_shop"), "after one wing: the other wing and the gift shop")
adventure.enter_room(c2, "gift_shop", 1)
adventure.leave_room(c2, "gift_shop", "win", 1)
after = adventure.options_after(c2, "gift_shop")
check(has(after, "paintings") and has(after, "hunting"), "from the gift shop: back for the other wing, or upstairs")
adventure.enter_room(c2, "hunting", 2)
check(st2.passed.paintings, "going upstairs walks past the wing they didn't see")
after = adventure.options_after(c2, "hunting")
check(not has(after, "paintings"), "a room walked past isn't on the way on")
local prompts = adventure.prompts(c2)
local loose
for _, p in ipairs(prompts) do
    if p.id == "knight_left" then
        loose = p
    end
end
check(loose ~= nil, "a room walked past raises its loose end")
adventure.answer_loose(c2, "knight_left", 1)
check(st2.marks.knight ~= nil, "the loose end moved the knight to her lair")
adventure.enter_room(c2, "paintings", 2)
check(st2.marks.knight == nil, "going back for the hall brings the knight home")
check(not st2.passed.paintings, "a room gone back for isn't walked past any more")
-- The stairs: only her after them.
for _, rid in ipairs({ "paintings", "hunting" }) do
    adventure.leave_room(c2, rid, "win", 2)
end
adventure.enter_room(c2, "stairs", 2)
adventure.leave_room(c2, "stairs", "win", 2)
check(st2.at == "lair" and not st2.choices, "at the top of the stairs there's only her")
check(adventure.boss_week(c2), "boss night follows the stairs")
local left = adventure.enter_room(c2, "lair", 3)
check(has(left, "offices") and st2.skipped.offices, "into the lair, the rooms unseen are left behind")

print(string.format("map repository and open floors: %d checks, %d failed", checks, fails))
os.exit(fails == 0 and 0 or 1)
