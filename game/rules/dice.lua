-- Dice for the rules engine. Wraps the seeded RNG and lets tests force exact
-- rolls: queue values with dice:force(...) and the next dice of any size use
-- them in order (each forced value must fit the die being rolled).

local rng_mod = require "game.model.rng"

local M = {}
M.__index = M

function M.new(seed)
    return setmetatable({ rng = rng_mod.new(seed or 1), queue = {}, rolled = 0 }, M)
end

-- Queue forced results, e.g. dice:force(17, 4, 6) -> next d20 = 17, then 4, then 6.
function M:force(...)
    for _, v in ipairs({ ... }) do
        table.insert(self.queue, v)
    end
end

function M:pending()
    return #self.queue
end

-- One die.
function M:d(sides)
    self.rolled = self.rolled + 1
    if #self.queue > 0 then
        local v = table.remove(self.queue, 1)
        assert(v >= 1 and v <= sides, "forced roll " .. tostring(v) .. " doesn't fit a d" .. tostring(sides))
        return v
    end
    return self.rng:int(1, sides)
end

-- count dice of a size. opts.gwf: treat 1s and 2s as 3 (Great Weapon Fighting, p. 88).
-- Returns the total and the list of (adjusted) faces.
function M:roll(count, sides, opts)
    local total, faces = 0, {}
    for _ = 1, count do
        local v = self:d(sides)
        if opts and opts.gwf and v < 3 then
            v = 3
        end
        total = total + v
        table.insert(faces, v)
    end
    return total, faces
end

-- A d20 test with advantage (> 0), disadvantage (< 0) or neither (0).
-- reroll_ones: Halfling Luck (p. 85) -- reroll a 1 once and keep the new roll.
-- Returns the kept roll and both raw rolls.
function M:d20(mode, reroll_ones)
    local function one()
        local v = self:d(20)
        if reroll_ones and v == 1 then
            v = self:d(20)
        end
        return v
    end
    local a = one()
    if mode == 0 or mode == nil then
        return a, a, nil
    end
    local b = one()
    if mode > 0 then
        return math.max(a, b), a, b
    end
    return math.min(a, b), a, b
end

function M:chance(p)
    return self.rng:next() < p
end

function M:pick(list)
    return self.rng:pick(list)
end

function M:shuffle(list)
    return self.rng:shuffle(list)
end

return M
