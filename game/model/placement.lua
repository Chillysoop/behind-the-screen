-- Where minis stand on a board, for any rule set (docs/design/rule-sets.md, "Shared toolkits"): free squares near a
-- point, squares where every mini shows, and a board's walls, cover and doors. Staging puts the party down with it
-- before anything happens; 5e's grid fight (game/model/fight.lua) does the same when a fight starts. Pure Lua.

local content = require "game.model.content"
local maps = require "game.model.maps"

local M = {}


-- Free squares near (ax, ay), nearest first, spaced out when there is room.
function M.squares_near(blocked, taken, ax, ay, n, spread, W, H)
    local out = {}
    local function free(x, y)
        local k = x * 1000 + y
        return x >= 1 and y >= 1 and x <= W and y <= H and not blocked[k] and not taken[k]
    end
    local function far_enough(x, y)
        for _, s in ipairs(out) do
            if math.max(math.abs(s[1] - x), math.abs(s[2] - y)) < spread then
                return false
            end
        end
        return true
    end
    for pass = 1, 2 do
        for r = 0, math.max(W, H) do
            for dy = -r, r do
                for dx = -r, r do
                    if math.max(math.abs(dx), math.abs(dy)) == r and #out < n then
                        local x, y = ax + dx, ay + dy
                        if free(x, y) and (pass == 2 or far_enough(x, y)) then
                            table.insert(out, { x, y })
                            taken[x * 1000 + y] = true
                        end
                    end
                end
            end
            if #out >= n then
                return out
            end
        end
    end
    return out
end

-- Squares near (ax, ay) where every mini shows (round three, A1 and engine_screens 4: "Thessaly is behind
-- an interior wall, only her hat shows"; "Oswin is mostly behind Pip"). The camera looks from the south
-- (a higher y is nearer it), so a mini hides one standing in the same or the next column a row or two
-- behind it, and a wall in front hides whoever's behind it: with the board's `occ` (board.compile), every
-- piece by its height, so an office partition hides the next two rows and a plinth the next one
-- (sight.shows: the confirming playtest, three of four heroes behind the offices' partitions); without
-- it, a blocked square straight in front. First pass: none of that, against the squares already chosen
-- and `others` (minis standing there already), within `reach` (6) of the anchor; then clear of the walls
-- a little further out, where another mini may stand two rows ahead; then as squares_near would.
function M.squares_shown(blocked, taken, ax, ay, n, W, H, others, occ, reach, doors)
    local sight = require "game.model.sight"
    reach = reach or 6
    local out = {}
    -- (Only squares in the same room as the anchor: the corners outside an octagon's walls are open
    -- squares too, and nobody can stand there. With `doors`, the board's doors bound the room, open or
    -- not: Conner's playtest, C23, Pip and Thessaly set down in the study across the hall, through its
    -- open door, because the hall was behind a wall from the camera.)
    local door_at = {}
    for _, d in ipairs(doors or {}) do
        door_at[d.x * 1000 + d.y] = true
    end
    local inside = {}
    if ax >= 1 and ay >= 1 and ax <= W and ay <= H and not blocked[ax * 1000 + ay] then
        local queue, head = { { ax, ay } }, 1
        inside[ax * 1000 + ay] = true
        while head <= #queue do
            local q = queue[head]
            head = head + 1
            for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                local x, y = q[1] + d[1], q[2] + d[2]
                local k = x * 1000 + y
                if x >= 1 and y >= 1 and x <= W and y <= H and not blocked[k] and not inside[k] and not door_at[k] then
                    inside[k] = true
                    table.insert(queue, { x, y })
                end
            end
        end
    else
        inside = nil
    end
    local function free(x, y)
        local k = x * 1000 + y
        return x >= 1 and y >= 1 and x <= W and y <= H and not blocked[k] and not taken[k] and (not inside or inside[k])
    end
    local function clear_of_walls(x, y)
        if occ then
            return (sight.shows(occ, x, y))
        end
        return not blocked[x * 1000 + y + 1]        -- (a wall right in front of it)
    end
    local function shows(x, y, strict)
        if not clear_of_walls(x, y) then
            return false
        end
        for _, list in ipairs({ out, others or {} }) do
            for _, s in ipairs(list) do
                local dx, dy = math.abs(s[1] - x), math.abs(s[2] - y)
                if strict and dx <= 1 and dy <= 2 then
                    return false
                elseif not strict and dx == 0 and dy == 1 then
                    return false
                end
            end
        end
        return true
    end
    for pass = 1, 2 do
        local far = pass == 1 and reach or (reach + 4)
        for r = 0, math.max(W, H) do
            for dy = -r, r do
                for dx = -r, r do
                    if math.max(math.abs(dx), math.abs(dy)) == r and #out < n then
                        local x, y = ax + dx, ay + dy
                        if free(x, y) and shows(x, y, pass == 1) then
                            table.insert(out, { x, y })
                            taken[x * 1000 + y] = true
                        end
                    end
                end
            end
            if #out >= n or r >= far then
                break                       -- (too far from where they should be: crowd in, as before)
            end
        end
        if #out >= n then
            break
        end
    end
    if #out < n and inside and doors then
        -- (Crowd in, inside the room: nobody spills through a door.)
        for r = 0, math.max(W, H) do
            for dy = -r, r do
                for dx = -r, r do
                    local x, y = ax + dx, ay + dy
                    if math.max(math.abs(dx), math.abs(dy)) == r and #out < n and free(x, y) then
                        table.insert(out, { x, y })
                        taken[x * 1000 + y] = true
                    end
                end
            end
        end
    end
    if #out < n then
        for _, sq in ipairs(M.squares_near(blocked, taken, ax, ay, n - #out, 1, W, H)) do
            table.insert(out, sq)
        end
    end
    return out
end

function M.blocked_set(set_name, map)
    if map and map.template == set_name then
        return maps.layout(map)        -- the DM's own map (B9)
    end
    local layout = content.terrain_layout.sets[set_name] or content.terrain_layout.sets.blank
    local blocked = {}
    for _, sq in ipairs(layout.blocked) do
        blocked[sq[1] * 1000 + sq[2]] = true
    end
    -- The board's own cover (low walls, crates, tables: Half or Three-Quarters), what can't be
    -- seen through (walls), doors, rough ground (brush, rubble, webs), ice and its fires.
    local extras = { cover = {}, deg = {}, rough = {}, traps = {}, planks = layout.planks, sources = layout.sources,
                     opaque = layout.opaque or {}, doors = layout.doors or {}, slippery = layout.slippery or {},
                     lights = layout.lights or {} }
    for k, what in pairs(layout.cover or {}) do
        extras.cover[k] = what           -- true, or what the piece is called ("crate")
        extras.deg[k] = layout.deg and layout.deg[k]
    end
    for k in pairs(layout.rough or {}) do
        extras.rough[k] = true
    end
    return blocked, layout, extras
end

return M
