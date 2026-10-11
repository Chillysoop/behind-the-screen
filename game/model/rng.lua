-- Seeded random numbers (Park-Miller), identical in LuaJIT and Lua 5.3,
-- so a week can be replayed exactly from its seed.

local M = {}
M.__index = M

function M.new(seed)
    seed = math.floor(seed or os.time()) % 2147483646
    if seed < 1 then
        seed = seed + 2147483646
    end
    return setmetatable({ s = seed }, M)
end

-- A float in [0, 1).
function M:next()
    self.s = (self.s * 16807) % 2147483647
    return (self.s - 1) / 2147483646
end

-- An integer in [a, b], or [1, a] when b is omitted.
function M:int(a, b)
    if not b then
        a, b = 1, a
    end
    if b < a then
        return a
    end
    return a + math.floor(self:next() * (b - a + 1))
end

-- A float in [a, b).
function M:range(a, b)
    return a + (b - a) * self:next()
end

function M:chance(p)
    return self:next() < p
end

function M:d20()
    return self:int(1, 20)
end

function M:pick(list)
    if #list == 0 then
        return nil
    end
    return list[self:int(1, #list)]
end

-- Pick by weight; weights is a parallel list of non-negative numbers.
function M:weighted(list, weights)
    local total = 0
    for i = 1, #list do
        total = total + math.max(weights[i] or 0, 0)
    end
    if total <= 0 then
        return self:pick(list)
    end
    local r = self:next() * total
    for i = 1, #list do
        r = r - math.max(weights[i] or 0, 0)
        if r <= 0 then
            return list[i]
        end
    end
    return list[#list]
end

function M:shuffle(list)
    for i = #list, 2, -1 do
        local j = self:int(1, i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

return M
