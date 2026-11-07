-- Dice, for any rule set (docs/design/rule-sets.md, "Shared toolkits"; Conner, November 6: "Other systems should also
-- be able to use maps and grids and d20s and all types of dice"). Dice belong to the table, not to a system: a rule set
-- picks which it rolls. Pure Lua; rolls off any random source with :int(a, b) (game/model/rng.lua), or :d(sides)
-- (game/rules/dice.lua, whose tests can force a face).
--
--   local dice = require "game.kit.dice"
--   dice.roll(rng, "1d20")       d20               any die: d4, d6, d8, d10, d12, d20, d100 (d%), or any size
--   dice.roll(rng, "2d6+1")      a sum, plus or minus a number
--   dice.roll(rng, "4d6kh3")     keep the highest 3 (kl: the lowest): Advantage is "2d20kh1"
--   dice.roll(rng, "3d6!")       exploding: a top face rolls again and adds (up to 10 more)
--   dice.roll(rng, "4dF")        Fate dice: -1, 0 or +1 each
--   dice.roll(rng, "5d6>=6")     a pool: counts the dice at or over 6 (the result is the count)
--   dice.roll(rng, "1d20+1d4")   groups add up
-- A roll gives { total, groups = { { n, sides, faces, kept, ... } }, mod, notation, text = "2d6+1: 3, 5 +1 = 9" }.

local M = {}

local EXPLODE_MAX = 10

local function face(rng, sides)
    if rng.d then
        return rng:d(sides)
    end
    return rng:int(1, sides)
end

-- "2d6+1" into its parts: dice groups and a flat modifier. Errors on anything it can't read, so a typo in a rule
-- set fails loudly rather than rolling something else.
function M.parse(notation)
    assert(type(notation) == "string" and notation ~= "", "dice: no notation")
    local s = string.gsub(string.lower(notation), "%s+", "")
    local spec = { notation = notation, groups = {}, mod = 0 }
    local pos = 1
    while pos <= #s do
        local sign = 1
        local c = string.sub(s, pos, pos)
        if c == "+" or c == "-" then
            sign = c == "-" and -1 or 1
            pos = pos + 1
        elseif pos > 1 then
            error("dice: can't read " .. notation)
        end
        local n, sides, rest = string.match(s, "^(%d*)d(%d*[%%f]?)(.*)$", pos)
        if n then
            local g = { n = tonumber(n) or 1, sign = sign }
            if sides == "%" then
                g.sides = 100
            elseif sides == "f" then
                g.fate = true
                g.sides = 3
            else
                g.sides = assert(tonumber(sides), "dice: no size in " .. notation)
            end
            assert(g.n >= 1 and g.n <= 100 and g.sides >= 2, "dice: out of range in " .. notation)
            pos = #s - #rest + 1
            local how, k = string.match(s, "^k([hl])(%d+)", pos)
            if how then
                g.keep = { how = how, k = tonumber(k) }
                pos = pos + 2 + #k
            end
            if string.sub(s, pos, pos) == "!" then
                g.explode = true
                pos = pos + 1
            end
            local at = string.match(s, "^>=(%d+)", pos)
            if at then
                g.at_least = tonumber(at)
                pos = pos + 2 + #at
            end
            table.insert(spec.groups, g)
        else
            local num = string.match(s, "^(%d+)", pos)
            assert(num, "dice: can't read " .. notation)
            spec.mod = spec.mod + sign * tonumber(num)
            pos = pos + #num
        end
    end
    assert(#spec.groups > 0, "dice: no dice in " .. notation)
    return spec
end

local function roll_group(rng, g)
    local faces = {}
    for _ = 1, g.n do
        local v = face(rng, g.sides)
        if g.fate then
            v = v - 2
        elseif g.explode then
            local more, last = 0, v
            while last == g.sides and more < EXPLODE_MAX do
                last = face(rng, g.sides)
                v = v + last
                more = more + 1
            end
        end
        table.insert(faces, v)
    end
    local kept = {}
    if g.keep then
        local order = {}
        for i, v in ipairs(faces) do
            order[i] = { v = v, i = i }
        end
        table.sort(order, function(a, b)
            if a.v == b.v then
                return a.i < b.i
            end
            if g.keep.how == "h" then
                return a.v > b.v
            end
            return a.v < b.v
        end)
        for i = 1, math.min(g.keep.k, #order) do
            kept[order[i].i] = true
        end
    else
        for i in ipairs(faces) do
            kept[i] = true
        end
    end
    local sum = 0
    for i, v in ipairs(faces) do
        if kept[i] then
            if g.at_least then
                sum = sum + (v >= g.at_least and 1 or 0)
            else
                sum = sum + v
            end
        end
    end
    return { n = g.n, sides = g.sides, fate = g.fate, faces = faces, kept = kept, sum = g.sign * sum, pool = g.at_least ~= nil }
end

function M.roll(rng, notation)
    local spec = type(notation) == "table" and notation or M.parse(notation)
    local out = { notation = spec.notation, groups = {}, mod = spec.mod, total = spec.mod }
    local bits = {}
    for _, g in ipairs(spec.groups) do
        local r = roll_group(rng, g)
        table.insert(out.groups, r)
        out.total = out.total + r.sum
        local fs = {}
        for i, v in ipairs(r.faces) do
            local t = r.fate and ((v > 0 and "+") or (v < 0 and "-") or "0") or tostring(v)
            table.insert(fs, r.kept[i] and t or ("(" .. t .. ")"))
        end
        table.insert(bits, table.concat(fs, ", "))
    end
    local m = spec.mod ~= 0 and ((spec.mod > 0 and " +" or " -") .. tostring(math.abs(spec.mod))) or ""
    out.text = tostring(spec.notation) .. ": " .. table.concat(bits, "; ") .. m .. " = " .. tostring(out.total)
    -- (One die, alone and kept: its face, for a rule set that reads it, like a natural 20.)
    if #out.groups == 1 and out.groups[1].n == 1 then
        out.face = out.groups[1].faces[1]
    end
    return out
end

-- The lowest and highest a roll can come to (an exploding die counts as its sides: the usual top).
function M.range(notation)
    local spec = type(notation) == "table" and notation or M.parse(notation)
    local lo, hi = spec.mod, spec.mod
    for _, g in ipairs(spec.groups) do
        local k = g.keep and math.min(g.keep.k, g.n) or g.n
        local a, b
        if g.at_least then
            a, b = 0, k
        elseif g.fate then
            a, b = -k, k
        else
            a, b = k, k * g.sides
        end
        if g.sign < 0 then
            a, b = -b, -a
        end
        lo, hi = lo + a, hi + b
    end
    return lo, hi
end

return M
