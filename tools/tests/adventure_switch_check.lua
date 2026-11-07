-- Switching adventures the way the title screen does (start on the museum, then pick another): each adventure's
-- creatures go into its own rule set's roster, never into the one that was on before (November 7: picking Welcome to
-- the Ring after the museum filed its foes under 5e's, and its fights had nobody real to fight).
--     lua tools/tests/adventure_switch_check.lua

package.path = "./?.lua;" .. package.path
local adventure = require "game.model.adventure"
local ruleset = require "game.model.ruleset"
local adventures = require "game.data.adventures"

local fails = 0
local function ok(cond, what)
    if not cond then
        fails = fails + 1
        print("  FAIL " .. what)
    end
end

local first = adventure.current()
for _, id in ipairs(adventures.order) do
    if id ~= first then
        adventure.use(id)
        local mod = adventures.part(id, "module")
        local set = ruleset.current()
        ok(set.id == mod.rules, id .. " plays by its own rule set after the switch (" .. tostring(set.id) .. ")")
        local mine = set.engine["data.monsters"]
        for cid in pairs(mod.creatures or {}) do
            local key = id .. "_" .. cid
            local found = mine[key] or mine[cid]
            ok(found ~= nil, id .. "'s " .. cid .. " is in its own set's roster")
            for other_id, other in pairs(ruleset.SETS) do
                if other_id ~= set.id and other.engine and other.engine["data.monsters"] then
                    ok(other.engine["data.monsters"][key] == nil, id .. "'s " .. cid .. " stays out of " .. other_id .. "'s roster")
                end
            end
        end
    end
end

print(fails == 0 and "adventure switch: all clear" or ("adventure switch: " .. fails .. " failures"))
os.exit(fails == 0 and 0 or 1)
