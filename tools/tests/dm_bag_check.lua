-- The DM's bag, its books, people's pockets and lore tips (Conner, November 6), for any adventure:
--   BAG    thirty things, every magic one the rules', every bit one a hero can carry; what's in it from the start.
--   BOOKS  an hour of prep reads a book, in order, and its things join the bag; no hours, no reading.
--   POCKETS a thing from the bag put on someone comes out of the bag, goes back if taken off them, and reaches a pack.
--   TIPS   each adventure's tips: in their room, not twice, and a tip given counts as its secret's hint.
-- (The poke card itself, played in whole prologues: tools/tests/table_life_check.lua.)
--     lua tools/tests/dm_bag_check.lua            ADVENTURE=sheep lua tools/tests/dm_bag_check.lua
package.path = "./?.lua;" .. package.path

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local dm_bag = require "game.model.dm_bag"
local bagd = require "game.data.dm_bag"
local items = require "game.model.items"
local npcs = require "game.model.npcs"
local tips = require "game.model.lore_tips"
local secrets = require "game.model.secrets"

local fails, n = {}, 0
local function check(ok, what)
    n = n + 1
    if not ok then table.insert(fails, what) end
end

adventure.enter()
local c = campaign_mod.new(77)
adventure.enter(c)

-- BAG
check(#bagd.list == 30, "the bag has thirty things (" .. #bagd.list .. ")")
for _, e in ipairs(bagd.list) do
    if e.kind == "magic" then
        check(items.def(e.magic) ~= nil, "a magic thing the rules don't have: " .. e.id)
    else
        check(items.thing(e.thing or e.id) ~= nil, "a thing nobody can carry: " .. e.id)
    end
    check(e.name and e.rarity and e.text, "a thing without its name, rarity or words: " .. e.id)
    check(not e.book or bagd.book_by_id[e.book], "a thing in a book that isn't there: " .. e.id)
end
local start = #dm_bag.stock(c)
check(start > 0 and start < 30, "some of the bag from the start, the rest in the books (" .. start .. ")")

-- BOOKS
c:session_zero(require("game.model.social").default_choices())
for _, key in ipairs({ "mara", "dev", "jess", "sam" }) do
    adventure.set_hook(c, key, adventure.data.hooks[key][1].id)
end
local prep = c:start_week()
local hours = prep:left()
check(not dm_bag.can_read(c, prep, "wonders"), "the second book can't be read before the first")
local added = dm_bag.read(c, prep, "armourer")
check(added and #added > 0 and #dm_bag.stock(c) == start + #added, "reading a book puts its things in the bag")
check(prep:left() == hours - bagd.READ_COST, "reading a book takes an hour of prep")
check(not dm_bag.can_read(c, prep, "armourer"), "a book is read once")
prep.extra = prep.extra + prep:left()
check(not dm_bag.can_read(c, prep, "wonders"), "no hours left, no reading")

-- POCKETS
local who = npcs.all()[1]
check(who ~= nil, "someone has a sheet to put things on")
if who then
    local choices = npcs.item_choices(c)
    check(#choices == #dm_bag.stock(c), "what can go in a pocket is what's in the bag")
    local e = bagd.by_id[choices[1]]
    local left = dm_bag.left(c, e)
    local d = npcs.add_drop(c, who.id, e.id)
    check(d and d.bag and dm_bag.left(c, e) == left - 1, "a thing put on someone comes out of the bag")
    check(npcs.drop_def(e.id) and npcs.drop_def(e.id).name, "a pocketed thing has its name for the sheet")
    npcs.remove_drop(c, who.id, #npcs.drops(c, who.id))
    check(dm_bag.left(c, e) == left, "a thing taken off them goes back in the bag")
    -- (And one reaches the party: into a pack.)
    local magic
    for _, x in ipairs(dm_bag.stock(c)) do
        if x.kind == "magic" and not magic then magic = x end
    end
    local before = #items.list(c)
    local it = dm_bag.hand_over(c, c.players[1], magic)
    check(it and #items.list(c) == before + 1 and it.holder, "a magic thing from the bag reaches a hero's pack")
    local bit = bagd.list[1]
    local it2 = dm_bag.hand_over(c, c.players[2], bit)
    check(it2 and it2.holder == c.players[2].key, "a bit from the bag reaches the hero it was for")
end

-- TIPS
local list = tips.list()
check(#list >= 10, "the adventure has its lore tips (" .. #list .. ")")
local seen = {}
for _, t in ipairs(list) do
    check(t.id and t.name and t.text, "a tip without its id, name or words")
    check(not seen[t.id], "two tips share an id: " .. tostring(t.id))
    seen[t.id] = true
    check(not t.room or adventure.data.rooms[t.room], "a tip for a room the adventure doesn't have: " .. tostring(t.id))
    check(not t.hints or secrets.def(t.hints), "a tip hinting a secret the adventure doesn't have: " .. tostring(t.id))
end
local first = adventure.data.start
local here = tips.for_room(c, first)
if #here > 0 then
    local t = here[1]
    local said = {}
    local night = { campaign = c, say = function(_, text) table.insert(said, text) end }
    tips.give(night, t, c.players[1])
    check(#said == 1 and tips.given(c, t.id), "a tip given is said and kept")
    check(not tips.useful(c, t), "a tip isn't given twice")
    check(not t.hints or secrets.hinted(c, t.hints), "a tip given counts as its secret's hint")
end

print(string.format("DM BAG  %s: bag, books, pockets, tips   checks %d%s", adventure.current(), n,
    #fails > 0 and ("  FAIL x" .. #fails) or ""))
for _, f in ipairs(fails) do print("         FAIL: " .. f) end
print(#fails == 0 and "dm bag check: all clear" or ("dm bag check: " .. #fails .. " failures"))
os.exit(#fails == 0 and 0 or 1)
