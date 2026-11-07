-- The current adventure's rule set (docs/design/rule-sets.md): every adventure plays by exactly one, named by its
-- `rules` field. Nothing defaults: an adventure that doesn't say is an error, never quietly 5e (Conner, November 6:
-- "It's critical that systems never leak into another system"). The shared game asks the set what a roll is and
-- reads the tier it gives.
--     local ruleset = require "game.model.ruleset"
--     local r = ruleset.current().check(night.rng, { mod = 5, dc = 15 })     -- r.tier: great, full, partial, miss, botch

local util = require "game.model.util"

local M = {}

-- (Listed by name, so the build takes every one: require_check.py.)
M.SETS = {
    ["5e"] = require "game.rules.sets.dnd5e",
    ["dis"] = require "game.rules.sets.dis",
}

function M.get(id)
    local set = id and M.SETS[id]
    if not set then
        error("no rule set called " .. tostring(id), 2)
    end
    return set
end

function M.current()
    local adventure = util.lazy("game.model.adventure")     -- (at use time: it requires the standard, which asks here)
    local data = assert(adventure and adventure.data, "no adventure, so no rule set")
    local set = data.rules and M.SETS[data.rules]
    if not set then
        error(tostring(data.title) .. " doesn't name a rule set it can play by (`rules`: " .. tostring(data.rules) .. ")", 2)
    end
    return set
end

-- Whether a shared record (a decision card, a bag's thing, a way of finding out) belongs in this adventure: it's the
-- table's own (no `rules`), or the current set's (`rules = "5e"`). Another set's never is (no leaks).
function M.fits(record)
    local r = type(record) == "table" and record.rules or nil
    return r == nil or r == M.current().id
end

-- A part of the current set's engine ("battle", "data.monsters"...), looked up when it's used, never kept: a shared
-- module that touches 5e's battle while another set's adventure is on gets an error, not 5e (no leaks).
function M.engine(name)
    local set = M.current()
    local part = set.engine and set.engine[name]
    if not part then
        error(tostring(set.title or set.id) .. " has no " .. tostring(name) .. " (docs/design/rule-sets.md: no leaks between sets)", 2)
    end
    return part
end

-- The same, as a stand-in a module can hold from load time (`local battle = ruleset.part("battle")`): every field
-- read or written goes to the current set's part at that moment.
function M.part(name)
    return setmetatable({}, {
        __index = function(_, k)
            return M.engine(name)[k]
        end,
        __newindex = function(_, k, v)
            M.engine(name)[k] = v
        end,
    })
end

return M
