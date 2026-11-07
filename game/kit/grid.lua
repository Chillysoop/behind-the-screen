-- The grid, for any rule set (docs/design/rule-sets.md, "Shared toolkits"; Conner, November 6: "Other systems should also
-- be able to use maps and grids"). Squares on a board and what's on them: distance, who stands where, the board's
-- edges, straight lines between squares, line of sight past walls and shut doors, light and its sources, doors opening.
-- A rule set's fight stands on it and keeps its own rules on top: 5e's battle (game/rules/battle.lua) mixes these in
-- and adds attacks, cover, Darkvision and the rest. Pure Lua.
--
-- The methods work on any table holding the board (a battle, a test's board):
--   W, H              the board's size in squares
--   creatures         everything standing on it ({ x, y, dead, removed, torch... })
--   opaque[k]         squares nobody sees through (a wall); doors[k] = { state = "closed" | "open" | "locked", x, y, fid }
--   light             nil (everyone sees), or { ambient = "bright" | "dim" | "dark", sources = { { x, y, bright, dim } } }
--   square_feet       how far one square is (5 when it doesn't say)
--   diagonals         "same" (a diagonal step is one square, when it doesn't say) or "alternate" (every second one is two)
--   light_extra(self, from)   more light sources, each passed to from(x, y, bright, dim): a rule set's torches
-- k is grid.key(x, y), "x,y".
--
--   local grid = require "game.kit.grid"
--   grid.mix(MyBoard)       copies the methods onto a class: board:dist(a, b), board:los_xy(...), board:light_at(x, y)

local M = {}

function M.key(x, y)
    return x .. "," .. y
end
local key = M.key

local G = {}
M.methods = G

-- Distance between squares, in feet: diagonals count like straight steps unless the board says otherwise.
function G:dist_xy(x1, y1, x2, y2)
    local feet = self.square_feet or 5
    local dx, dy = math.abs(x1 - x2), math.abs(y1 - y2)
    if self.diagonals == "alternate" then
        local diag, straight = math.min(dx, dy), math.abs(dx - dy)
        return feet * (straight + diag + math.floor(diag / 2))
    end
    return feet * math.max(dx, dy)
end

function G:dist(a, b)
    return self:dist_xy(a.x, a.y, b.x, b.y)
end

function G:occupant(x, y)
    for _, o in ipairs(self.creatures) do
        if not o.dead and o.x == x and o.y == y then
            return o
        end
    end
    return nil
end

function G:in_bounds(x, y)
    return x >= 1 and y >= 1 and x <= self.W and y <= self.H
end

function G:opaque_at(x, y)
    local k = key(x, y)
    local d = self.doors and self.doors[k]
    if d then
        return d.state ~= "open"
    end
    return self.opaque ~= nil and self.opaque[k] == true
end

-- The squares a straight line from the middle of one square to the middle of another crosses,
-- neither end counted. A line exactly through a corner passes between the two squares there:
-- { corner = { a, b } }.
function G:line(x1, y1, x2, y2)
    local out = {}
    local dx, dy = x2 - x1, y2 - y1
    local sx = dx > 0 and 1 or (dx < 0 and -1 or 0)
    local sy = dy > 0 and 1 or (dy < 0 and -1 or 0)
    local adx, ady = math.abs(dx), math.abs(dy)
    local tx = adx > 0 and 0.5 / adx or math.huge
    local ty = ady > 0 and 0.5 / ady or math.huge
    local ddx = adx > 0 and 1 / adx or math.huge
    local ddy = ady > 0 and 1 / ady or math.huge
    local x, y, guard = x1, y1, 0
    while (x ~= x2 or y ~= y2) and guard < 100 do
        guard = guard + 1
        if math.abs(tx - ty) < 1e-9 then
            table.insert(out, { corner = { { x + sx, y }, { x, y + sy } } })
            x, y = x + sx, y + sy
            tx, ty = tx + ddx, ty + ddy
        elseif tx < ty then
            x, tx = x + sx, tx + ddx
        else
            y, ty = y + sy, ty + ddy
        end
        if x ~= x2 or y ~= y2 then
            table.insert(out, { x, y })
        end
    end
    return out
end

-- Line of sight between two squares: nothing opaque in the way (a corner blocks only when both
-- squares beside it do). Cached until a door opens or shuts.
function G:los_xy(x1, y1, x2, y2)
    if (not self.opaque and not self.doors) or (x1 == x2 and y1 == y2) then
        return true
    end
    local ck = self.los_cache
    if not ck or ck.v ~= (self.stage_v or 0) then
        ck = { v = self.stage_v or 0 }
        self.los_cache = ck
    end
    local k = ((x1 * 64 + y1) * 64 + x2) * 64 + y2
    local v = ck[k]
    if v ~= nil then
        return v
    end
    v = true
    for _, s in ipairs(self:line(x1, y1, x2, y2)) do
        if s.corner then
            if self:opaque_at(s.corner[1][1], s.corner[1][2]) and self:opaque_at(s.corner[2][1], s.corner[2][2]) then
                v = false
                break
            end
        elseif self:opaque_at(s[1], s[2]) then
            v = false
            break
        end
    end
    ck[k] = v
    return v
end

-- How lit a square is: "bright", "dim" or "dark" (the board's light and its sources, and any the rule set adds,
-- like 5e's torches; light doesn't go through walls).
function G:light_at(x, y)
    local L = self.light
    if not L then
        return "bright"
    end
    local best = L.ambient == "bright" and 3 or (L.ambient == "dim" and 2 or 1)
    if best == 3 then
        return "bright"
    end
    local function from(sx, sy, bright, dim)
        local d = self:dist_xy(sx, sy, x, y)
        if d <= bright + dim and self:los_xy(math.floor(sx + 0.5), math.floor(sy + 0.5), x, y) then
            best = math.max(best, d <= bright and 3 or 2)
        end
    end
    for _, src in ipairs(L.sources or {}) do
        from(src.x, src.y, src.bright, src.dim)
    end
    if self.light_extra then
        self:light_extra(from)
    end
    return best == 3 and "bright" or (best == 2 and "dim" or "dark")
end

-- A door opens (someone walked through it) or a lock gives. Says so to whoever listens (emit), if anyone does.
function G:set_door(x, y, state, who)
    local d = self.doors and self.doors[key(x, y)]
    if not d or d.state == state then
        return
    end
    d.state = state
    self.stage_v = (self.stage_v or 0) + 1
    if self.emit then
        self:emit({ kind = "door", x = x, y = y, state = state, fid = d.fid, who = who })
    end
end

-- The shortest way from one square to another, stepping to any of the eight squares around, round walls, shut doors
-- and anyone standing in the way (the goal's own square may be taken: it's who you're walking up to). The steps, not
-- counting the start; nil when there's no way. opts.max: give up past this many steps (40 when it doesn't say).
function G:path(x1, y1, x2, y2, opts)
    local max = (opts and opts.max) or 40
    if x1 == x2 and y1 == y2 then
        return {}
    end
    local from, frontier, seen = {}, { { x1, y1 } }, { [key(x1, y1)] = 0 }
    local steps = 0
    while #frontier > 0 and steps < max do
        steps = steps + 1
        local next_frontier = {}
        for _, sq in ipairs(frontier) do
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local nx, ny = sq[1] + dx, sq[2] + dy
                    local k = key(nx, ny)
                    local goal = nx == x2 and ny == y2
                    if (dx ~= 0 or dy ~= 0) and seen[k] == nil and self:in_bounds(nx, ny) and not self:opaque_at(nx, ny)
                        and (goal or not self:occupant(nx, ny)) then
                        seen[k] = steps
                        from[k] = sq
                        if goal then
                            local out, at = {}, { nx, ny }
                            while at and not (at[1] == x1 and at[2] == y1) do
                                table.insert(out, 1, at)
                                at = from[key(at[1], at[2])]
                            end
                            return out
                        end
                        table.insert(next_frontier, { nx, ny })
                    end
                end
            end
        end
        frontier = next_frontier
    end
    return nil
end

-- Put the grid's methods on a class (a rule set's battle), leaving any it already has.
function M.mix(class)
    for name, f in pairs(G) do
        if class[name] == nil then
            class[name] = f
        end
    end
    return class
end

return M
