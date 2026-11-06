-- The hand-off (adventure.handoff; Conner, November 6: two adventures tied together keep their items, lore, people,
-- history and open threads, so later hooks can connect). A museum campaign with some of its story done is handed to
-- the Sheep Chase, and the checks: the party and what they carry are as they were, the log goes on, what the table
-- learned is lore, the museum's own state is the past, its open thread is carried and the Sheep Chase's rumour that
-- picks it up can play, the new adventure's flags are its own, the levels it needs are due, and it all saves and
-- loads. Then the Sheep Chase on its own, with a fresh party: none of it.
--     lua tools/tests/handoff_check.lua
package.path = "./?.lua;" .. package.path

local adventure = require "game.model.adventure"
local campaign_mod = require "game.model.campaign"
local events = require "game.model.events"
local secrets = require "game.model.secrets"
local save = require "game.model.save"

local fails, n = {}, 0
local function check(ok, what)
    n = n + 1
    if not ok then table.insert(fails, what) end
end

-- A museum campaign, partway through its story.
adventure.use("museum")
adventure.enter()
local c = campaign_mod.new(41)
adventure.enter(c)
c.level = 2
c.adv.flags.truth = true
c.adv.francs = 3
secrets.learn(c, "gorgon", "known", { heroes = { "mara" } })
events.add(c, { kind = "met", thing = "mus_flitwidget", where = false })
local items_before = c.items
local players_before = #c.players
local log_before = #c.events

local past = adventure.handoff(c, "sheep")

check(adventure.current() == "sheep" and adventure.data.id == "sheep" and c.module == "sheep", "the Sheep Chase is the adventure now")
check(past and c.past.museum == past and past.title == "The Museum of Nightmares", "the museum is kept as the past")
check(past.adv.flags.truth == true and getmetatable(past.adv.flags) == nil, "the museum's flags are in the past, a plain table")
check(past.adv.francs == 3, "the museum's Francs are in the past with the rest of it")
check(c.lore["museum:gorgon"] == "known", "what the table learned in the museum is lore")
check(c.items == items_before and #c.players == players_before, "the heroes and what they carry are as they were")
check(#c.events > log_before and c.events[1].kind ~= nil, "the event log goes on from the museum's")
local kinds = {}
for _, ev in ipairs(c.events) do kinds[ev.kind] = ev end
check(kinds.adventure_end and kinds.adventure_end.thing == "museum", "the log says the museum ended")
check(kinds.adventure_start and kinds.adventure_start.thing == "sheep" and kinds.adventure_start.value == "a week or two later",
      "the log says the Sheep Chase began, a week or two later")
check(adventure.open_thread(c, "mountain_road") and adventure.open_thread(c, "murder"), "the museum's open thread is carried, by id and by tag")
check(adventure.test(c, { past = "museum" }) and adventure.test(c, { thread = "mountain_road" }) and adventure.test(c, { knew = "museum:gorgon" }),
      "the conditions on what came before hold")
local mountains
for _, r in ipairs(adventure.data.rumours) do
    if r.id == "mountains" then mountains = r end
end
check(mountains and adventure.test(c, mountains.only_if), "Teddy's rumour about the mountains can play")
check(string.find(adventure.say(c, adventure.data.handoff.say), "after the museum", 1, true), "the opening says they came from the museum")
check(c.adv.flags.truth == nil and c.adv.at == "inn_common", "the Sheep Chase starts clean, in the common room")
c.adv.flags.understood = true
local last = c.events[#c.events]
check(last.kind == "flag" and last.thing == "understood" and last.adventure == "sheep", "a flag set now is the Sheep Chase's, in the log")
check(c.level_due == 4, "a level-2 party is due level 4 at the seam")

-- Saved and loaded, all of it comes back.
local src = save.dump(c)
local loaded = save.load(src)
check(loaded and loaded.past and loaded.past.museum and loaded.past.museum.adv.flags.truth == true, "the past saves and loads")
check(loaded and loaded.lore and loaded.lore["museum:gorgon"] == "known", "the lore saves and loads")
check(loaded and loaded.threads and loaded.threads[1].id == "mountain_road", "the open threads save and load")

-- The Sheep Chase on its own: a fresh party, no past.
local f = campaign_mod.new(42)
adventure.enter(f)
check(f.module == "sheep" and not f.past, "a fresh party starts the Sheep Chase with no past")
check(not adventure.test(f, { past = "museum" }) and not adventure.test(f, mountains.only_if), "nothing from the museum holds")
check(not string.find(adventure.say(f, adventure.data.handoff.say), "museum", 1, true), "the opening doesn't mention the museum")

print(string.format("HANDOFF  any adventure to any other   checks %d%s", n, #fails > 0 and ("  FAIL x" .. #fails) or ""))
for _, f in ipairs(fails) do print("         FAIL: " .. f) end
print(#fails == 0 and "handoff check: all clear" or ("handoff check: " .. #fails .. " failures"))
os.exit(#fails == 0 and 0 or 1)
