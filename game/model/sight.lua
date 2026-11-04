-- What the heroes can see, and how they get there, outside a fight (the playtest, November 3:
-- "players should not see through walls, so they need to move through doors to see the full
-- room and NPCs inside it"). The scene's board as the rules see it: walls and shut doors block
-- sight (the same line as the fight's, game/rules/battle.lua), pieces block walking, and a door
-- opens as a hero walks through it. A person on the board stays off it until a hero can see their
-- square; minis walk round walls and through doors, not through them. Pure Lua.

local board = require "game.model.board"

local M = {}

local function key(x, y)
    return x .. "," .. y
end

-- The scene's stage: { W, H, opaque, block, doors = { ["x,y"] = { state, fid } } }. Doors the
-- party already walked through tonight stay open (night.doors_open).
function M.stage(night, sc)
    local id = sc and night:board_for(sc)
    if not id then
        return nil
    end
    local ok, c = pcall(board.compile, id)
    if not ok or not c then
        return nil
    end
    local st = { W = board.W, H = board.H, opaque = c.opaque or {}, block = c.block_set or {}, doors = {}, id = id }
    local open = night.doors_open and night.doors_open[id] or {}
    for _, d in ipairs(c.doors or {}) do
        st.doors[key(d.x, d.y)] = { state = open[key(d.x, d.y)] and "open" or d.state, fid = d.fid }
    end
    return st
end

local function opaque_at(st, x, y)
    local d = st.doors[key(x, y)]
    if d then
        return d.state ~= "open"
    end
    return st.opaque[key(x, y)] == true
end

-- The squares a straight line between two squares' middles crosses (neither end), as the fight
-- draws it: a line through a corner passes between the two squares there.
local function line(x1, y1, x2, y2)
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

function M.los(st, a, b)
    if not st or (a[1] == b[1] and a[2] == b[2]) then
        return true
    end
    for _, s in ipairs(line(a[1], a[2], b[1], b[2])) do
        if s.corner then
            if opaque_at(st, s.corner[1][1], s.corner[1][2]) and opaque_at(st, s.corner[2][1], s.corner[2][2]) then
                return false
            end
        elseif opaque_at(st, s[1], s[2]) then
            return false
        end
    end
    return true
end

-- Can a hero walk onto this square? Anything blocking but a door that isn't locked.
local function walkable(st, x, y)
    if x < 1 or y < 1 or x > st.W or y > st.H then
        return false
    end
    local d = st.doors[key(x, y)]
    if d then
        return d.state ~= "locked"
    end
    return not st.block[key(x, y)]
end
M.walkable = walkable

-- The shortest walk from one square to another (or to the first square `goal(x, y)` accepts), as
-- squares after the start. Eight ways, no cutting a corner past two blocked squares. nil: no way.
function M.path(st, from, to, goal)
    if not st then
        return nil
    end
    goal = goal or function(x, y)
        return x == to[1] and y == to[2]
    end
    local sk = key(from[1], from[2])
    local prev = { [sk] = false }
    local q, head = { from }, 1
    local found
    if goal(from[1], from[2]) then
        return {}
    end
    while head <= #q and not found do
        local cur = q[head]
        head = head + 1
        for dy = -1, 1 do
            for dx = -1, 1 do
                if (dx ~= 0 or dy ~= 0) and not found then
                    local x, y = cur[1] + dx, cur[2] + dy
                    local k = key(x, y)
                    local diag_ok = dx == 0 or dy == 0 or (walkable(st, cur[1] + dx, cur[2]) or walkable(st, cur[1], cur[2] + dy))
                    -- (The destination itself may be a piece: they walk up to it.)
                    local is_goal = goal(x, y)
                    if prev[k] == nil and diag_ok and (walkable(st, x, y) or (is_goal and to)) then
                        prev[k] = cur
                        if is_goal then
                            found = { x, y }
                        else
                            table.insert(q, { x, y })
                        end
                    end
                end
            end
        end
    end
    if not found then
        return nil
    end
    local out = {}
    local cur = found
    while cur do
        local k = key(cur[1], cur[2])
        if k == sk then
            break
        end
        table.insert(out, 1, cur)
        cur = prev[k]
    end
    return out
end

-- A path's turning points only (the mini walks straight between them).
function M.corners(path)
    local out = {}
    for i, sq in ipairs(path) do
        local nxt = path[i + 1]
        local prv = path[i - 1]
        if not nxt or not prv or (nxt[1] - sq[1] ~= sq[1] - prv[1]) or (nxt[2] - sq[2] ~= sq[2] - prv[2]) then
            table.insert(out, sq)
        end
    end
    return out
end

-- The doors a path goes through: they open (night.doors_open, and the board shows it).
function M.doors_on(st, path)
    local out = {}
    for _, sq in ipairs(path or {}) do
        local d = st.doors[key(sq[1], sq[2])]
        if d and d.state ~= "open" then
            d.state = "open"
            table.insert(out, { x = sq[1], y = sq[2], fid = d.fid })
        end
    end
    return out
end

-- Can any of these squares see that one?
function M.seen(st, from_list, target)
    for _, a in ipairs(from_list) do
        if M.los(st, a, target) then
            return true
        end
    end
    return false
end

return M
