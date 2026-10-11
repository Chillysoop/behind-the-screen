-- The boards (game/data/boards.lua) are laid out right: every piece on the mat, nothing standing
-- in anything else, everyone's start square free with room around it, the party can reach the
-- monsters, and every feature has words the DM can mention it by. Every place in the game has a
-- board to use. Run from the project root: lua tools/tests/board_check.lua
-- With an argument, prints a board as text: lua tools/tests/board_check.lua kettle

package.path = "./?.lua;" .. package.path

local board = require "game.model.board"
local boards = require "game.data.boards"
local props = require "game.data.props"

local fails = 0
local function fail(msg)
    fails = fails + 1
    if fails <= 40 then
        print("  " .. msg)
    end
end

-- Pieces that lie flat on the ground: other pieces may stand on them.
local GROUND = { floor_boards = true, floor_flags = true, floor_cobbles = true, floor_grass = true, floor_dirt = true,
                 floor_ash = true, floor_sand = true, road_ew = true, path_ns = true,
                 path_patch = true, ash = true, sand_ring = true, puddle = true, stream_ns = true, water_strip = true,
                 frost = true, tracks = true, rug = true, tall_grass = true, flowers = true, pit_ring = true,
                 pier = true, rope_bridge = true }

local function draw(id)
    local c = board.compile(id)
    local grid = {}
    for y = 1, board.H do
        grid[y] = {}
        for x = 1, board.W do
            grid[y][x] = "."
        end
    end
    for _, pc in ipairs(c.pieces) do
        for _, sq in ipairs(board.squares(pc.kind, pc.x, pc.y, pc.r)) do
            local ch = GROUND[pc.kind] and "," or string.sub(pc.kind, 1, 1)
            if grid[sq[2]][sq[1]] == "." or grid[sq[2]][sq[1]] == "," then
                grid[sq[2]][sq[1]] = sq[3] and string.upper(ch) or ch
            end
        end
    end
    grid[c.party[2]][c.party[1]] = "P"
    grid[c.foes[2]][c.foes[1]] = "F"
    grid[c.npc[2]][c.npc[1]] = "N"
    print(id .. ": " .. c.title)
    for y = 1, board.H do
        print("  " .. table.concat(grid[y], " "))
    end
end

if arg and arg[1] then
    draw(arg[1])
    os.exit(0)
end

local ids = {}
for id in pairs(boards) do
    table.insert(ids, id)
end
table.sort(ids)
local pieces_total = 0
for _, id in ipairs(ids) do
    local c = board.compile(id)
    local b = boards[id]
    local taken = {}
    for _, pc in ipairs(c.pieces) do
        pieces_total = pieces_total + 1
        local k = props[pc.kind]
        local sqs = board.squares(pc.kind, pc.x, pc.y, pc.r)
        if #sqs ~= k.fw * k.fh then
            fail(id .. ": " .. pc.kind .. " at " .. pc.x .. "," .. pc.y .. " runs off the mat")
        end
        if not GROUND[pc.kind] then
            for _, sq in ipairs(sqs) do
                local kk = sq[1] .. "," .. sq[2]
                if taken[kk] then
                    fail(id .. ": " .. pc.kind .. " and " .. taken[kk] .. " both at " .. kk)
                end
                taken[kk] = pc.kind
            end
        end
    end
    local block = c.block_set
    local free = board.W * board.H
    for _ in pairs(block) do
        free = free - 1
    end
    if free < (b.tight and 0.35 or 0.6) * board.W * board.H then
        fail(id .. ": only " .. free .. " free squares")
    end
    for _, who in ipairs({ "party", "npc", "foes" }) do
        local s = c[who]
        if not s then
            fail(id .. ": no " .. who .. " start")
        elseif block[s[1] .. "," .. s[2]] or taken[s[1] .. "," .. s[2]] then
            fail(id .. ": the " .. who .. " start " .. s[1] .. "," .. s[2] .. " is under scenery")
        else
            local room = 0
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local x, y = s[1] + dx, s[2] + dy
                    if x >= 1 and y >= 1 and x <= board.W and y <= board.H and not block[x .. "," .. y] then
                        room = room + 1
                    end
                end
            end
            if who ~= "npc" and room < 5 then
                fail(id .. ": the " .. who .. " start is boxed in (" .. room .. " free squares around it)")
            end
        end
    end
    for who, at in pairs(b.npc_at or {}) do
        if block[at[1] .. "," .. at[2]] or taken[at[1] .. "," .. at[2]] then
            fail(id .. ": " .. who .. "'s spot " .. at[1] .. "," .. at[2] .. " is under scenery")
        end
    end
    -- The party can walk to the monsters.
    local seen, queue = { [c.party[1] .. "," .. c.party[2]] = true }, { c.party }
    local reached = false
    while #queue > 0 do
        local s = table.remove(queue, 1)
        if s[1] == c.foes[1] and s[2] == c.foes[2] then
            reached = true
            break
        end
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
            local x, y = s[1] + d[1], s[2] + d[2]
            local kk = x .. "," .. y
            if x >= 1 and y >= 1 and x <= board.W and y <= board.H and not block[kk] and not seen[kk] then
                seen[kk] = true
                table.insert(queue, { x, y })
            end
        end
    end
    if not reached then
        fail(id .. ": the party can't reach the monsters")
    end
    for _, f in ipairs(c.features) do
        if #f.words == 0 then
            fail(id .. ": feature " .. f.id .. " has no words")
        end
    end
    if #board.base_ids(id) == 0 then
        fail(id .. ": nothing goes down with the place (no base feature)")
    end
end

-- Every place resolves to a board that exists.
local content = require "game.model.content"
local missing = 0
for _, c in pairs(content.components) do
    if type(c) == "table" and c.kind == "location" then
        local t = content.terrain.by_location[c.id]
        if t and not boards[t] then
            fail("location " .. c.id .. " points at a board that doesn't exist: " .. t)
            missing = missing + 1
        end
    end
end
for k, v in pairs(content.terrain.by_scene) do
    if not boards[v] then
        fail("scene type " .. k .. " points at a missing board " .. v)
    end
end

print(string.format("%d boards, %d pieces", #ids, pieces_total))
if fails > 0 then
    print("  [FAIL] The boards are laid out right  -  " .. fails .. " problems")
    os.exit(1)
end
print("  [PASS] The boards are laid out right: on the mat, nothing overlapping, starts free, the way through open")
