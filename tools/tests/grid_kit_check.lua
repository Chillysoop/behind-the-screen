-- The shared grid (game/kit/grid.lua) on a board that isn't 5e's battle: any rule set's fight can stand on it with its own
-- rules (docs/design/rule-sets.md, "Shared toolkits"). Distances by the board's own measure, sight past walls and
-- doors, light and dark, who stands where.
--     lua tools/tests/grid_kit_check.lua

package.path = "./?.lua;" .. package.path
local grid = require "game.kit.grid"

local fails = 0
local function ok(cond, what)
    if not cond then
        fails = fails + 1
        print("  FAIL " .. what)
    end
end

-- A board of another set's: 10-foot squares, every second diagonal counting double, no 5e anywhere.
local Board = {}
Board.__index = Board
grid.mix(Board)
local function board(opts)
    return setmetatable({ W = 10, H = 8, creatures = {}, opaque = opts.opaque, doors = opts.doors, light = opts.light,
                          square_feet = opts.square_feet, diagonals = opts.diagonals, said = {} }, Board)
end
function Board:emit(ev)
    table.insert(self.said, ev)
end

do
    local b = board({})
    ok(b:dist_xy(1, 1, 4, 5) == 20, "5-foot squares, diagonals as one: 4 squares is 20 feet (got " .. b:dist_xy(1, 1, 4, 5) .. ")")
    b = board({ square_feet = 10, diagonals = "alternate" })
    ok(b:dist_xy(1, 1, 4, 4) == 40, "three diagonals, every second double: 4 squares of 10 feet (got " .. b:dist_xy(1, 1, 4, 4) .. ")")
    ok(b:dist_xy(1, 1, 1, 6) == 50, "five straight squares of 10 feet is 50 (got " .. b:dist_xy(1, 1, 1, 6) .. ")")
    ok(b:in_bounds(10, 8) and not b:in_bounds(11, 8) and not b:in_bounds(0, 1), "the board's edges")
    local hero = { x = 3, y = 3 }
    table.insert(b.creatures, hero)
    ok(b:occupant(3, 3) == hero and b:occupant(4, 3) == nil, "who stands where")
end

do
    -- A wall down column 5, with a door at (5, 4).
    local opaque, doors = {}, {}
    for y = 1, 8 do
        if y ~= 4 then
            opaque[grid.key(5, y)] = true
        end
    end
    doors[grid.key(5, 4)] = { state = "closed", x = 5, y = 4, fid = "door" }
    local b = board({ opaque = opaque, doors = doors })
    ok(b:los_xy(2, 4, 8, 4) == false, "a shut door blocks the view")
    b:set_door(5, 4, "open", "someone")
    ok(b:los_xy(2, 4, 8, 4) == true, "an open door doesn't")
    ok(#b.said == 1 and b.said[1].kind == "door" and b.said[1].state == "open", "the door says it opened")
    ok(b:los_xy(2, 2, 8, 2) == false, "the wall blocks the view")
    ok(b:los_xy(2, 2, 2, 7) == true, "nothing between two squares on the same side")
end

do
    local b = board({ light = { ambient = "dark", sources = { { x = 2, y = 2, bright = 10, dim = 10 } } } })
    ok(b:light_at(2, 3) == "bright", "next to the lamp is bright")
    ok(b:light_at(5, 2) == "dim", "three squares off is dim")
    ok(b:light_at(9, 8) == "dark", "the far corner is dark")
    function b:light_extra(from)          -- a rule set's own light: a glowing sword at (9, 8)
        from(9, 8, 5, 0)
    end
    ok(b:light_at(9, 8) == "bright", "a set's own light source lights its square")
end

print(fails == 0 and "grid kit: all clear" or ("grid kit: " .. fails .. " failures"))
os.exit(fails == 0 and 0 or 1)
