-- A rule set for the tests only (docs/design/rule-sets.md, step 4): "Skirmish", nothing like 5e. Rolls 2d6 plus a stat:
-- 12 or more a triumph, 10 a success, 7 to 9 near (a hit with a cost), 6 or less a flop. Its fights stand on the
-- table's grid (game/kit/grid.lua) with rules of its own: each fighter steps toward the nearest foe it can see, and
-- one next to a foe strikes: 2d6 + its edge, 7 or more is one harm, 10 or more two; three harm and it's out. It
-- names none of 5e's things and reaches none of 5e's engine. Registered by the checks that need a second set.

local dice = require "game.kit.dice"
local grid = require "game.kit.grid"

local M = {}

M.id = "skirmish"
M.title = "Skirmish (test set)"
M.dice = { notation = "2d6", sides = 6, name = "2d6", icon = "d6" }
M.who_rolls = "players"
M.fight = "grid"
M.difficulty_word = "target"
M.scene_dc = { 7, 8, 9 }       -- (a stat roll's own target: not used for the tiers, which are fixed)
M.story_approaches = { "fight", "move", "wits" }
M.owns = { "%f[%w]weak hit%f[%W]", "%f[%w]Skirmish%f[%W]" }
M.words = { dc = "target", inspiration = "edge token", advantage = "an edge", crit = "boxcars", fumble = "snake eyes" }

local STATS = { fight = "Fight", move = "Move", wits = "Wits" }
function M.name(approach)
    return STATS[approach] or tostring(approach)
end
function M.signed(n)
    return (n >= 0 and "+" or "") .. tostring(n)
end
function M.mod(class, approach)
    local by = { fighter = { fight = 2, move = 0, wits = -1 }, rogue = { fight = 0, move = 2, wits = 1 },
                 wizard = { fight = -1, move = 0, wits = 2 }, cleric = { fight = 1, move = -1, wits = 1 } }
    return ((by[class] or {})[approach]) or 0
end
function M.tier(total)
    return (total >= 12 and "triumph") or (total >= 10 and "success") or (total >= 7 and "near") or "flop"
end
function M.check(rng, opts)
    local r = dice.roll(rng, "2d6")
    local mod = opts.mod or 0
    local total = r.total + mod
    local tier = M.tier(total)
    return { roll = r.total, mod = mod, total = total, dc = 10, success = tier == "triumph" or tier == "success", tier = tier,
             faces = r.groups[1].faces, crit = r.total == 12, fumble = r.total == 2 }
end
local WORD = { triumph = "a strong hit", success = "a hit", near = "a hit with a cost", flop = "a miss" }
function M.line(who, approach, r)
    return who .. ": " .. M.name(approach) .. " " .. r.faces[1] .. "+" .. r.faces[2] .. M.signed(r.mod) .. " = " .. r.total
        .. ", " .. WORD[r.tier]
end

-- Its grid fight. sides: { a = { fighters }, b = { fighters } }, each fighter { name, x, y, edge }. On a board with
-- walls (opaque) and doors, on the shared grid. Returns the winning side, the rounds and what was said.
local Board = {}
Board.__index = Board
grid.mix(Board)
function M.grid_fight(opts, rng)
    local b = setmetatable({ W = opts.W or 12, H = opts.H or 8, opaque = opts.opaque, doors = opts.doors, creatures = {},
                             square_feet = 10, diagonals = "alternate" }, Board)
    for side, list in pairs(opts.sides) do
        for _, f in ipairs(list) do
            f.side, f.harm = side, 0
            table.insert(b.creatures, f)
        end
    end
    table.sort(b.creatures, function(p, q) return p.name < q.name end)
    local said, rounds = {}, 0
    local function alive(side)
        local n = 0
        for _, c in ipairs(b.creatures) do
            if c.side == side and not c.dead then
                n = n + 1
            end
        end
        return n
    end
    while alive("a") > 0 and alive("b") > 0 and rounds < 30 do
        rounds = rounds + 1
        for _, c in ipairs(b.creatures) do
            if not c.dead and alive(c.side == "a" and "b" or "a") > 0 then
                -- (The nearest foe by the way there, round the walls: the shared grid's path.)
                local best, bpath
                for _, o in ipairs(b.creatures) do
                    if o.side ~= c.side and not o.dead then
                        local path = b:path(c.x, c.y, o.x, o.y)
                        if path and (not bpath or #path < #bpath) then
                            best, bpath = o, path
                        end
                    end
                end
                if best and #bpath <= 1 and b:los_xy(c.x, c.y, best.x, best.y) then
                    local r = dice.roll(rng, "2d6")
                    local total = r.total + (c.edge or 0)
                    local hit = total >= 10 and 2 or (total >= 7 and 1 or 0)
                    best.harm = best.harm + hit
                    table.insert(said, c.name .. " strikes at " .. best.name .. ": " .. total .. (hit > 0 and (", " .. hit .. " harm") or ", nothing"))
                    if best.harm >= 3 then
                        best.dead = true
                        table.insert(said, best.name .. " is out.")
                    end
                elseif best and #bpath > 1 then
                    c.x, c.y = bpath[1][1], bpath[1][2]
                end
            end
        end
    end
    local winner = alive("a") > 0 and alive("b") == 0 and "a" or (alive("b") > 0 and alive("a") == 0 and "b" or nil)
    return { winner = winner, rounds = rounds, said = said, board = b }
end

return M
