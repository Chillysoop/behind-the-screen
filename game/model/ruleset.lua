-- The current adventure's rule set (docs/design/rule-sets.md): every adventure plays by exactly one, named by its
-- `rules` field. Nothing defaults: an adventure that doesn't say is an error, never quietly 5e (Conner, November 6:
-- "It's critical that systems never leak into another system"). The shared game asks the set what a roll is and
-- reads the tier it gives.
--     local ruleset = require "game.model.ruleset"
--     local r = ruleset.current().check(night.rng, { mod = 5, dc = 15 })     -- r.tier: great, full, partial, miss, botch

local M = {}

-- (Listed by name, so the build takes every one: require_check.py.)
M.SETS = {
    ["5e"] = require "game.rules.sets.dnd5e",
}

function M.get(id)
    return assert(id and M.SETS[id], "no rule set called " .. tostring(id))
end

function M.current()
    local adventure = package.loaded["game.model.adventure"]
    local data = assert(adventure and adventure.data, "no adventure, so no rule set")
    return assert(data.rules and M.SETS[data.rules],
        tostring(data.title) .. " doesn't name a rule set it can play by (`rules`: " .. tostring(data.rules) .. ")")
end

return M
