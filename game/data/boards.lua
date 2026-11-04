-- The boards: what each place looks like on the battle mat, piece by piece (the prop kit:
-- game/data/props.lua, from tools/gen_props.py). The mat is 20 x 13 squares, x west to east,
-- y north to south; the DM sits south, so tall things stand along the north edge and the south
-- edge stays low. The party comes in from the west, trouble from the east.
--
-- A board: title, light, party / npc / foes (where everyone starts), and features in the order
-- the DM would set them down. A feature: id, kind, at = { {x, y, r} } (x, y: the footprint's
-- north-west square; r: quarter turns, 1 faces west, 2 north, 3 east), or parts = { {kind, at} }
-- for one feature made of several kinds. words: what the DM might call it (added to the kind's
-- own; own_words = true to use only these). say: how the DM names it when setting out the rest.
-- base: it goes down with the place itself (the floor, the walls, the road). game/model/board.lua
-- reads these; the table drops each feature in when the narration mentions it.

local function run(x0, x1, y, r)
    local t = {}
    for x = x0, x1 do
        t[#t + 1] = { x, y, r or 0 }
    end
    return t
end

local function col(x, y0, y1, r)
    local t = {}
    for y = y0, y1 do
        t[#t + 1] = { x, y, r or 0 }
    end
    return t
end

-- run(...) without some x values (doors, windows and gaps go there instead).
local function run_but(x0, x1, y, skip, r)
    local s = {}
    for _, x in ipairs(skip) do
        s[x] = true
    end
    local t = {}
    for x = x0, x1 do
        if not s[x] then
            t[#t + 1] = { x, y, r or 0 }
        end
    end
    return t
end

local B = {}

-- Market square (the street outside the museum: game/data/terrain.lua) -------------------------
B.market = {
    title = "Market square", light = "day",
    party = { 3, 7 }, npc = { 12, 7 }, foes = { 17, 7 },
    features = {
        { id = "floor", kind = "floor_cobbles", at = { { 1, 1 } }, base = true },
        { id = "buildings", parts = { { kind = "shop", at = { { 1, 1 }, { 11, 1 } } }, { kind = "house", at = { { 5, 1 }, { 16, 1 } } } },
          words = { "square" }, say = "shopfronts all round", base = true },
        { id = "stalls", kind = "stall", at = { { 4, 6 }, { 8, 9 }, { 14, 5 }, { 15, 10 } }, words = { "hawkers" }, say = "market stalls" },
        { id = "well", kind = "well", at = { { 10, 6 } } },
        { id = "cart", kind = "cart", at = { { 3, 11 } } },
        { id = "goods", parts = { { kind = "crate", at = { { 13, 11 }, { 19, 4 } } }, { kind = "barrel", at = { { 19, 8 } } } } },
        { id = "lamp", kind = "lamp_post", at = { { 8, 5 } } },
        { id = "notices", kind = "notice_board", at = { { 9, 4 } } },
    },
}

-- Generic boards: a place without its own borrows one by what it is ----------------------------

B.camp = {
    title = "A camp", light = "fire",
    party = { 4, 9 }, npc = { 11, 8 }, foes = { 16, 7 },
    features = {
        { id = "ground", kind = "floor_dirt", at = { { 1, 1 } }, base = true },
        { id = "mud", kind = "path_patch", at = { { 8, 5 } }, base = true },
        { id = "fire", kind = "campfire", at = { { 9, 6 } } },
        { id = "tents", kind = "tent", at = { { 14, 3 }, { 6, 2 } } },
        { id = "seats", kind = "log_seat", at = { { 7, 6 }, { 11, 7 } } },
        { id = "bedrolls", kind = "bedroll", at = { { 13, 9 } } },
        { id = "trees", kind = "pine", at = { { 1, 1 }, { 20, 1 }, { 2, 13 }, { 19, 12 }, { 17, 2 } } },
        { id = "rocks", kind = "rock", at = { { 6, 10 }, { 18, 9 } } },
    },
}

B.forest = {
    title = "The woods", light = "day",
    party = { 4, 7 }, npc = { 13, 7 }, foes = { 17, 7 },
    features = {
        { id = "ground", kind = "floor_grass", at = { { 1, 1 } }, base = true },
        { id = "grass", kind = "tall_grass", at = { { 7, 8 }, { 12, 5 }, { 16, 10 } }, base = true },
        { id = "trees", kind = "pine", at = { { 2, 2 }, { 5, 1 }, { 8, 3 }, { 15, 2 }, { 19, 3 }, { 3, 11 }, { 9, 12 }, { 18, 12 } } },
        { id = "oaks", kind = "oak", at = { { 11, 2 }, { 13, 11 } } },
        { id = "stream", kind = "stream_ns", at = { { 10, 1 } }, words = { "water" } },
        { id = "log", kind = "fallen_log", at = { { 5, 10 } } },
        { id = "brush", kind = "bush", at = { { 6, 4 }, { 16, 5 }, { 15, 9 } } },
        { id = "rocks", kind = "rock", at = { { 18, 7 } } },
    },
}

B.road = {
    title = "The road", light = "day",
    party = { 3, 7 }, npc = { 12, 6 }, foes = { 17, 7 },
    features = {
        { id = "ground", kind = "floor_grass", at = { { 1, 1 } }, base = true },
        { id = "road", kind = "road_ew", at = { { 1, 6 } }, base = true },
        { id = "sign", kind = "signpost", at = { { 9, 5 } } },
        { id = "cart", kind = "cart", at = { { 13, 9 } } },
        { id = "trees", kind = "pine", at = { { 2, 2 }, { 6, 1 }, { 12, 2 }, { 17, 3 }, { 4, 12 }, { 15, 12 } } },
        { id = "fence", kind = "fence", at = { { 5, 4 }, { 6, 4 }, { 7, 4 } } },
        { id = "rocks", kind = "rock", at = { { 19, 10 } } },
        { id = "brush", kind = "bush", at = { { 9, 10 }, { 18, 4 } } },
    },
}

B.ruins = {
    title = "Ruins", light = "candle",
    party = { 3, 7 }, npc = { 16, 6 }, foes = { 16, 8 },
    features = {
        { id = "floor", kind = "floor_flags", at = { { 1, 1 } }, base = true },
        { id = "walls", parts = { { kind = "ruin_wall", at = { { 5, 1 }, { 6, 1 }, { 10, 1 }, { 14, 1 }, { 15, 1 } } },
                                  { kind = "ruin_wall_low", at = { { 7, 1 }, { 11, 1 }, { 16, 1 } } } }, base = true },
        { id = "pillars", parts = { { kind = "pillar", at = { { 6, 4 }, { 14, 4 } } }, { kind = "broken_pillar", at = { { 6, 10 }, { 14, 10 } } } } },
        { id = "altar", kind = "altar", at = { { 19, 6 } } },
        { id = "rubble", kind = "rubble", at = { { 9, 3 }, { 10, 11 }, { 12, 8 } } },
        { id = "brazier", kind = "brazier", at = { { 18, 3 } } },
        { id = "low_wall", kind = "ruin_wall_low", at = { { 9, 7 }, { 9, 8 } } },
    },
}

B.tavern = {
    title = "A tavern", light = "hearth",
    party = { 4, 8 }, npc = { 8, 2 }, foes = { 16, 7 },
    features = {
        { id = "floor", kind = "floor_boards", at = { { 1, 1 } }, base = true },
        { id = "walls", parts = { { kind = "wall_room", at = run_but(1, 20, 1, { 5, 6, 7, 8, 9, 10, 11, 17, 18, 19 }) },
                                  { kind = "wall_window", at = { { 17, 1 } } } }, base = true },
        { id = "bar", parts = { { kind = "bar", at = run(5, 11, 3) }, { kind = "wall_shelf", at = run(5, 11, 1) } } },
        { id = "hearth", kind = "hearth", at = { { 18, 1 } } },
        { id = "tables", parts = { { kind = "table_round", at = { { 5, 6 }, { 12, 6 }, { 8, 10 }, { 16, 10 } } },
                                   { kind = "table_long", at = { { 14, 4 } } } } },
        { id = "barrels", kind = "barrel", at = { { 2, 2 }, { 3, 2 }, { 2, 3 } } },
    },
}

B.town = {
    title = "A street", light = "day",
    party = { 3, 8 }, npc = { 11, 7 }, foes = { 17, 8 },
    features = {
        { id = "floor", kind = "floor_cobbles", at = { { 1, 1 } }, base = true },
        { id = "houses", parts = { { kind = "house", at = { { 2, 1 }, { 13, 1 } } }, { kind = "cottage", at = { { 6, 1 }, { 17, 1 } } },
                                   { kind = "shop", at = { { 9, 1 } } } }, base = true },
        { id = "well", kind = "well", at = { { 10, 7 } } },
        { id = "lamps", kind = "lamp_post", at = { { 6, 5 }, { 15, 5 } } },
        { id = "cart", kind = "cart", at = { { 13, 10 } } },
        { id = "barrels", kind = "barrel", at = { { 5, 4 }, { 20, 5 } } },
    },
}

B.market_generic = {
    title = "A market", light = "day",
    party = { 4, 7 }, npc = { 13, 7 }, foes = { 17, 7 },
    features = {
        { id = "floor", kind = "floor_cobbles", at = { { 1, 1 } }, base = true },
        { id = "shops", kind = "shop", at = { { 2, 1 }, { 8, 1 }, { 15, 1 } }, base = true },
        { id = "stalls", kind = "stall", at = { { 5, 5 }, { 11, 5 }, { 8, 9 }, { 15, 9 } } },
        { id = "goods", kind = "crate", at = { { 3, 11 }, { 18, 5 } } },
        { id = "well", kind = "well", at = { { 14, 7 } } },
    },
}

B.bridge = {
    title = "A bridge", light = "day",
    party = { 5, 7 }, npc = { 14, 7 }, foes = { 15, 7 },
    features = {
        { id = "ground", kind = "floor_grass", at = { { 1, 1 } }, base = true },
        { id = "gorge", kind = "chasm", at = { { 9, 1 }, { 9, 9 } }, base = true },
        { id = "bridge", kind = "rope_bridge", at = { { 9, 6 } } },
        { id = "trees", kind = "pine", at = { { 3, 3 }, { 18, 2 }, { 1, 12 }, { 17, 11 } } },
        { id = "rocks", kind = "rock", at = { { 20, 1 }, { 3, 10 } } },
    },
}

B.dock = {
    title = "The waterside", light = "day",
    party = { 4, 9 }, npc = { 12, 9 }, foes = { 16, 8 },
    features = {
        { id = "ground", kind = "floor_sand", at = { { 1, 1 } }, base = true },
        { id = "water", kind = "water_strip", at = { { 1, 1 } }, base = true },
        { id = "pier", kind = "pier", at = { { 9, 1 } } },
        { id = "cargo", parts = { { kind = "crate", at = { { 5, 7 }, { 6, 7 }, { 15, 6 } } }, { kind = "barrel", at = { { 18, 7 }, { 3, 11 } } } } },
        { id = "cart", kind = "cart", at = { { 12, 11 } } },
        { id = "lamp", kind = "lamp_post", at = { { 8, 6 } } },
    },
}

B.underground = {
    title = "Underground", light = "candle",
    party = { 3, 7 }, npc = { 12, 7 }, foes = { 16, 7 },
    features = {
        { id = "floor", kind = "floor_flags", at = { { 1, 1 } }, base = true },
        { id = "walls", kind = "stone_wall", at = run(1, 20, 1), base = true },
        { id = "pillars", kind = "pillar", at = { { 6, 4 }, { 14, 4 }, { 6, 10 }, { 14, 10 } }, say = "old stone pillars" },
        { id = "water", kind = "puddle", at = { { 9, 7 } }, say = "black water pooling on the floor" },
        { id = "supplies", parts = { { kind = "crate", at = { { 10, 3 }, { 17, 11 } } }, { kind = "barrel", at = { { 11, 3 } } } },
          say = "someone's abandoned supplies" },
        { id = "rubble", kind = "rubble", at = { { 17, 3 }, { 3, 11 } } },
        { id = "bones", kind = "bones", at = { { 18, 8 } }, say = "old bones" },
    },
}

B.blank = {
    title = "Open ground", light = "day",
    party = { 4, 7 }, npc = { 12, 7 }, foes = { 16, 7 },
    features = {
        { id = "ground", kind = "floor_grass", at = { { 1, 1 } }, base = true },
        { id = "grass", kind = "tall_grass", at = { { 7, 4 }, { 13, 10 }, { 17, 3 } }, base = true },
        { id = "rocks", kind = "rock", at = { { 8, 10 }, { 15, 4 } } },
        { id = "brush", kind = "bush", at = { { 11, 8 } } },
    },
}

-- A plain museum hall (the map maker's "Museum hall"): polished marble and plaster walls, nothing
-- else yet, to build the museum's rooms on from scratch with the Museum pieces.
B.museum_hall = {
    title = "A museum hall", light = "candle",
    party = { 4, 9 }, npc = { 10, 4 }, foes = { 16, 8 },
    features = {
        { id = "floor", kind = "floor_marble", at = { { 1, 1 } }, base = true },
        { id = "walls", parts = { { kind = "wall_room", at = run(1, 20, 1) }, { kind = "wall_room", at = col(1, 2, 13, 3) },
                                  { kind = "wall_room", at = col(20, 2, 13, 1) } }, words = { "hall", "museum" }, base = true },
    },
}

-- The campfire vignette between sessions (the prep screen's view of the table).
B.vignette = {
    title = "Campfire", light = "fire",
    party = { 5, 8 }, npc = { 11, 8 }, foes = { 15, 6 },
    features = {
        { id = "ground", kind = "floor_grass", at = { { 1, 1 } }, base = true },
        { id = "trees", kind = "pine", at = { { 1, 1 }, { 17, 2 }, { 2, 12 }, { 13, 11 }, { 19, 8 }, { 7, 1 } }, base = true },
        { id = "fire", kind = "campfire", at = { { 8, 5 } } },
        { id = "tents", kind = "tent", at = { { 3, 2 }, { 12, 2 } } },
        { id = "seats", kind = "log_seat", at = { { 6, 6 }, { 10, 6 } } },
        { id = "brush", kind = "bush", at = { { 17, 6 }, { 16, 4 } } },
        { id = "rocks", kind = "rock", at = { { 11, 9 } } },
    },
}

-- The map library: boards drawn from the adventures' own maps (game/data/maps/*.map, compiled by
-- tools/maps/build_maps.py into game/data/map_library.lua).
for id, b in pairs(require("game.data.map_library").boards) do
    B[id] = b
end

return B
