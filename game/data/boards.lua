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

-- The Crooked Kettle --------------------------------------------------------------------------
B.kettle = {
    title = "The Crooked Kettle", light = "hearth",
    party = { 3, 8 }, npc = { 12, 2 }, foes = { 16, 8 },
    -- Gus behind the bar; anyone else at a table (the stranger in the corner).
    npc_at = { stranger = { 18, 10 }, wren = { 18, 10 }, rivals = { 16, 6 }, holt = { 13, 11 }, madame_sable = { 11, 7 },
               corin = { 5, 6 }, brother_tumble = { 9, 9 }, grey_coat = { 19, 4 }, market_friend = { 6, 5 } },
    features = {
        { id = "floor", kind = "floor_boards", at = { { 1, 1 } }, base = true },
        { id = "walls", parts = { { kind = "wall_room", at = run_but(1, 20, 1, { 2, 3, 5, 10, 11, 12, 13, 14, 16, 20 }) },
                                  { kind = "wall_door", at = { { 20, 1 } } } }, base = true },
        { id = "windows", kind = "wall_window", at = { { 5, 1 }, { 16, 1 } }, words = { "rain" }, say = "rain on the shutters" },
        { id = "hearth", parts = { { kind = "hearth", at = { { 2, 1 } } }, { kind = "rug", at = { { 2, 2 } } } },
          say = "a fire that needs feeding" },
        { id = "bar", parts = { { kind = "bar", at = run(10, 14, 3) }, { kind = "wall_shelf", at = run(10, 14, 1) } },
          words = { "gus", "mugs" }, say = "the bar, mugs lined up" },
        { id = "tables", kind = "table_round", at = { { 5, 5 }, { 8, 9 }, { 4, 11 }, { 15, 6 }, { 17, 10 }, { 12, 11 }, { 10, 6 } },
          words = { "sticky", "usual table" }, say = "sticky tables" },
        { id = "barrels", kind = "barrel", at = { { 18, 2 }, { 19, 2 }, { 19, 3 } }, say = "barrels by the back door" },
        { id = "long_table", kind = "table_long", at = { { 8, 12 } }, words = { "ballad", "bard" }, say = "a long table where the bard is murdering a ballad" },
        { id = "benches", kind = "bench", at = { { 15, 12 } }, words = { "regulars" }, say = "benches for the regulars" },
    },
}

-- The Velvet Hand's back room -------------------------------------------------------------------
B.velvet_den = {
    title = "The Velvet Hand's back room", light = "candle",
    party = { 3, 8 }, npc = { 12, 2 }, foes = { 16, 8 },
    features = {
        { id = "floor", kind = "floor_boards", at = { { 1, 1 } }, base = true },
        { id = "walls", parts = { { kind = "wall_room", at = run_but(1, 20, 1, { 3, 4, 8, 9, 20 }) },
                                  { kind = "wall_door", at = { { 20, 1 } } } }, base = true },
        { id = "curtains", kind = "curtain", at = { { 3, 1 }, { 4, 1 }, { 8, 1 }, { 9, 1 } }, say = "velvet curtains" },
        { id = "desk", kind = "desk", at = { { 11, 3 } }, words = { "ledger", "sable" }, say = "a desk with a very large ledger" },
        { id = "candles", kind = "candelabra", at = { { 9, 3 }, { 14, 3 } } },
        { id = "rug", kind = "rug", at = { { 10, 5 } } },
        { id = "strongbox", kind = "strongbox", at = { { 15, 2 } }, words = { "debt", "money" } },
        { id = "ledgers", kind = "bookshelf", at = { { 17, 2 } }, words = { "ledgers" }, say = "shelves of ledgers" },
        { id = "card_table", kind = "table_round", at = { { 6, 10 }, { 6, 6 } }, words = { "cards", "smiles" },
          say = "card tables" },
        { id = "goods", kind = "crate", at = { { 2, 11 }, { 3, 12 }, { 18, 11 } }, words = { "stolen", "goods" },
          say = "crates of stolen goods" },
    },
}

-- Ilsa's room above the scriptorium -------------------------------------------------------------
B.ilsa_room = {
    title = "Ilsa's room", light = "day",
    party = { 4, 9 }, npc = { 14, 4 }, foes = { 16, 8 },
    features = {
        { id = "floor", kind = "floor_boards", at = { { 1, 1 } }, base = true },
        { id = "walls", kind = "wall_room", at = run_but(1, 20, 1, { 4, 5, 6, 7, 10, 15, 16, 17, 18 }), base = true },
        { id = "window", kind = "wall_window", at = { { 10, 1 } }, words = { "open" }, say = "a window left open" },
        { id = "drawings", kind = "wall_notes", at = { { 4, 1 }, { 5, 1 }, { 6, 1 }, { 7, 1 }, { 15, 1 }, { 16, 1 }, { 17, 1 }, { 18, 1 } },
          words = { "bell tower", "drawings" }, say = "drawings of the bell tower pinned to every wall" },
        { id = "bed", kind = "bed", at = { { 3, 3 } }, say = "a narrow bed" },
        { id = "desk", kind = "desk", at = { { 12, 3 } }, words = { "page", "hand", "corin" }, say = "a writing desk" },
        { id = "books", kind = "bookshelf", at = { { 7, 2 } } },
        { id = "chest", kind = "chest", at = { { 5, 4 } } },
        { id = "rug", kind = "rug", at = { { 8, 6 } }, words = { "dust" }, say = "a dusty rug" },
        { id = "candle", kind = "candelabra", at = { { 17, 3 } } },
        { id = "work_table", kind = "table_long", at = { { 12, 9 } }, words = { "notes", "maps", "work" },
          say = "a work table buried in her notes" },
        { id = "book_crates", kind = "crate", at = { { 16, 10 }, { 17, 10 }, { 3, 11 } }, words = { "packed", "books" },
          say = "crates of books she never unpacked" },
        { id = "wardrobe", kind = "wardrobe", at = { { 2, 6 } } },
    },
}

-- The counting house --------------------------------------------------------------------------
B.counting_house = {
    title = "The counting house", light = "candle",
    party = { 4, 9 }, npc = { 9, 3 }, foes = { 16, 8 },
    features = {
        { id = "floor", kind = "floor_flags", at = { { 1, 1 } }, base = true },
        { id = "walls", kind = "stone_wall", at = run_but(1, 20, 1, { 13, 14 }), base = true },
        { id = "vault", kind = "vault_door", at = { { 13, 1 } }, words = { "cart" }, say = "a vault door the size of a cart" },
        { id = "counter", kind = "counter", at = run(6, 12, 4), words = { "scales", "brass", "clerk", "counts" },
          say = "a long counter with brass scales" },
        { id = "strongboxes", kind = "strongbox", at = { { 15, 3 }, { 16, 3 }, { 18, 2 } } },
        { id = "records", kind = "scroll_rack", at = { { 2, 2 } }, words = { "ledgers", "accounts" }, say = "racks of accounts" },
        { id = "candles", kind = "candelabra", at = { { 5, 2 }, { 11, 2 } } },
        { id = "benches", kind = "bench", at = { { 3, 11 }, { 15, 11 } }, words = { "wait", "queue" }, say = "benches for waiting" },
        { id = "rope_line", kind = "fence", at = { { 7, 7 }, { 8, 7 }, { 10, 7 }, { 11, 7 } }, words = { "line", "queue" },
          say = "a rope line for the queue" },
        { id = "guard_table", kind = "table_round", at = { { 17, 7 } }, words = { "guard", "guards" }, say = "the guards' table" },
        { id = "coin_chests", kind = "chest", at = { { 18, 3 }, { 19, 4 } }, words = { "coin", "chests" }, say = "chests of coin" },
    },
}

-- The ruined chapel ---------------------------------------------------------------------------
B.chapel = {
    title = "The ruined chapel", light = "candle",
    party = { 3, 7 }, npc = { 16, 6 }, foes = { 15, 8 },
    features = {
        { id = "floor", kind = "floor_flags", at = { { 1, 1 } }, base = true },
        { id = "walls", parts = { { kind = "ruin_wall", at = { { 4, 1 }, { 5, 1 }, { 6, 1 }, { 9, 1 }, { 13, 1 }, { 14, 1 }, { 17, 1 }, { 18, 1 } } },
                                  { kind = "ruin_wall_low", at = { { 7, 1 }, { 10, 1 }, { 15, 1 }, { 19, 1 } } } },
          words = { "half fallen", "chapel" }, say = "walls half fallen in", base = true },
        { id = "altar", kind = "altar", at = { { 17, 6 } }, words = { "lantern", "glints", "cracked" },
          say = "a cracked altar" },
        { id = "pews", kind = "pew", at = { { 8, 4 }, { 8, 9 }, { 12, 4 }, { 12, 9 } }, words = { "moss" }, say = "broken pews" },
        { id = "pillars", kind = "broken_pillar", at = { { 6, 3 }, { 6, 11 }, { 15, 3 }, { 15, 11 } } },
        { id = "bell", kind = "bell_fallen", at = { { 18, 10 } }, words = { "rope" }, say = "a little bell, cut from its rope" },
        { id = "rubble", kind = "rubble", at = { { 10, 2 }, { 11, 12 }, { 4, 5 }, { 13, 7 } } },
        { id = "moss", kind = "tall_grass", at = { { 3, 3 }, { 4, 12 }, { 19, 4 } }, words = { "moss" }, say = "moss over the flagstones" },
    },
}

-- The bell tower ------------------------------------------------------------------------------
B.bell_tower = {
    title = "The bell tower", light = "candle",
    party = { 4, 7 }, npc = { 12, 6 }, foes = { 14, 8 },
    features = {
        { id = "floor", kind = "floor_flags", at = { { 1, 1 } }, base = true },
        { id = "walls", kind = "stone_wall", at = run(1, 20, 1), base = true },
        { id = "stairs", kind = "stairs_spiral", at = { { 2, 2 } }, words = { "hundred and twelve", "scratched" },
          say = "the stairs" },
        { id = "great_bell", kind = "great_bell", at = { { 10, 3 } }, words = { "dead still" }, say = "the great bell" },
        { id = "bells", kind = "bell", at = { { 6, 3 }, { 15, 3 }, { 18, 5 }, { 6, 10 }, { 14, 10 }, { 18, 10 } },
          words = { "seven" }, say = "six more bells, hanging dead still" },
        { id = "frost", kind = "frost", at = { { 4, 5 }, { 8, 11 }, { 12, 8 }, { 17, 7 }, { 3, 11 } },
          say = "frost on the stones" },
        { id = "banner", kind = "banner", at = { { 19, 2 } }, words = { "kessrick", "wolf" }, say = "a wolf banner" },
        { id = "supplies", kind = "crate", at = { { 17, 12 }, { 18, 12 } }, words = { "supplies" }, say = "someone's supplies" },
    },
}

-- The crypt under the chapel ------------------------------------------------------------------
B.crypt = {
    title = "The crypt", light = "candle",
    party = { 4, 7 }, npc = { 16, 8 }, foes = { 15, 7 },
    features = {
        { id = "floor", kind = "floor_flags", at = { { 1, 1 } }, base = true },
        { id = "walls", kind = "stone_wall", at = run(1, 20, 1), base = true },
        { id = "steps", kind = "stairs_spiral", at = { { 2, 2 } }, words = { "steps", "altar" }, say = "steps down from the altar" },
        { id = "tombs", kind = "sarcophagus", at = { { 7, 3 }, { 10, 3 }, { 13, 3 }, { 7, 9 }, { 13, 9 } },
          words = { "century" }, say = "old tombs" },
        { id = "bell", kind = "bell", at = { { 18, 3 } }, words = { "crypt bell", "warm" }, say = "a tiny crypt bell" },
        { id = "candles", kind = "candelabra", at = { { 5, 6 }, { 17, 6 } } },
        { id = "pillars", kind = "pillar", at = { { 10, 7 } } },
        { id = "bones", kind = "bones", at = { { 9, 11 }, { 16, 11 }, { 4, 10 } } },
        { id = "graves", kind = "open_grave", at = { { 11, 9 } }, words = { "empty" }, say = "a grave someone dug open" },
        { id = "webs", kind = "web", at = { { 18, 11 } }, say = "old cobwebs" },
    },
}

-- The old barrow ------------------------------------------------------------------------------
B.barrow = {
    title = "The old barrow", light = "day",
    party = { 4, 8 }, npc = { 12, 6 }, foes = { 15, 7 },
    features = {
        { id = "grass", kind = "tall_grass", at = { { 3, 5 }, { 17, 8 }, { 12, 11 }, { 6, 11 } }, base = true },
        { id = "mound", kind = "mound", at = { { 9, 1 } }, words = { "grassy", "stone door", "door" },
          say = "a grassy mound with a stone door" },
        { id = "stones", kind = "standing_stone", at = { { 5, 3 }, { 15, 3 }, { 3, 10 }, { 17, 11 } },
          words = { "older" }, say = "standing stones" },
        { id = "path", kind = "path_patch", at = { { 9, 5 } }, say = "a trampled path to the door" },
        { id = "graves", kind = "gravestone", at = { { 7, 6 }, { 14, 6 } }, say = "worn grave markers" },
        { id = "tree", kind = "dead_tree", at = { { 19, 2 }, { 2, 2 } }, say = "dead trees" },
        { id = "rocks", kind = "rock", at = { { 8, 10 } } },
        { id = "barrow_stones", kind = "ruin_wall_low", at = { { 7, 4 }, { 13, 4 } }, words = { "kerb", "ring" },
          say = "a ring of old kerbstones" },
        { id = "bones", kind = "bones", at = { { 12, 9 }, { 16, 5 } }, words = { "older than" }, say = "old bones in the grass" },
    },
}

-- A forgotten shrine --------------------------------------------------------------------------
B.shrine = {
    title = "A forgotten shrine", light = "day",
    party = { 4, 8 }, npc = { 12, 5 }, foes = { 16, 7 },
    features = {
        { id = "path", kind = "path_ns", at = { { 9, 1 } }, words = { "step" }, base = true },
        { id = "shrine", kind = "statue", at = { { 10, 2 } }, words = { "shrine", "tends" }, say = "a weathered shrine" },
        { id = "bell", kind = "bell", at = { { 11, 2 } }, words = { "green with age" }, say = "a little bell, green with age" },
        { id = "flowers", kind = "flowers", at = { { 10, 3 }, { 11, 3 } }, words = { "fresh" }, say = "fresh flowers" },
        { id = "walls", kind = "ruin_wall_low", at = { { 7, 3 }, { 8, 3 }, { 13, 3 }, { 14, 3 } }, say = "a low wall" },
        { id = "trees", kind = "pine", at = { { 2, 2 }, { 4, 1 }, { 18, 2 }, { 16, 1 }, { 3, 12 }, { 19, 11 } } },
        { id = "grass", kind = "tall_grass", at = { { 6, 8 }, { 15, 9 }, { 13, 6 } } },
        { id = "rock", kind = "rock", at = { { 17, 6 } } },
    },
}

-- The flooded archive -------------------------------------------------------------------------
B.archive = {
    title = "The flooded archive", light = "candle",
    party = { 3, 8 }, npc = { 12, 9 }, foes = { 16, 7 },
    features = {
        { id = "floor", kind = "floor_flags", at = { { 1, 1 } }, base = true },
        { id = "walls", kind = "stone_wall", at = run(1, 20, 1), base = true },
        { id = "water", kind = "puddle", at = { { 4, 4 }, { 10, 7 }, { 15, 3 }, { 6, 10 } }, words = { "knee-deep", "flooded" },
          say = "knee-deep water" },
        { id = "shelves", parts = { { kind = "scroll_rack", at = { { 3, 2 }, { 13, 2 } } }, { kind = "bookshelf", at = { { 7, 2 }, { 17, 2 } } } },
          words = { "ledgers", "floating" }, say = "shelves of sodden ledgers" },
        { id = "lantern", kind = "candelabra", at = { { 12, 5 } }, words = { "lantern", "still lit" }, say = "a lantern, somehow still lit" },
        { id = "pillars", kind = "broken_pillar", at = { { 9, 4 }, { 14, 9 } } },
        { id = "crates", kind = "crate", at = { { 18, 11 } } },
        { id = "rubble", kind = "rubble", at = { { 17, 7 }, { 3, 12 } } },
    },
}

-- The webbed cellar ---------------------------------------------------------------------------
B.cellar = {
    title = "The webbed cellar", light = "candle",
    party = { 3, 7 }, npc = { 12, 8 }, foes = { 15, 7 },
    features = {
        { id = "floor", kind = "floor_flags", at = { { 1, 1 } }, base = true },
        { id = "walls", kind = "stone_wall", at = run(1, 20, 1), base = true },
        { id = "webs", kind = "web", at = { { 3, 3 }, { 9, 2 }, { 15, 4 }, { 6, 9 }, { 13, 10 }, { 17, 8 } },
          words = { "grey", "wall to wall" }, say = "thick grey webs" },
        { id = "eggs", kind = "spider_eggs", at = { { 11, 6 }, { 17, 2 } }, words = { "shifts", "dark" } },
        { id = "barrels", kind = "barrel", at = { { 19, 2 }, { 19, 3 }, { 18, 2 } } },
        { id = "crates", kind = "crate", at = { { 2, 12 }, { 3, 12 } } },
        { id = "bones", kind = "bones", at = { { 8, 6 }, { 14, 12 } } },
    },
}

-- The ashes of Hale's Crossing ----------------------------------------------------------------
B.hales_crossing = {
    title = "The ashes of Hale's Crossing", light = "day",
    party = { 3, 8 }, npc = { 12, 9 }, foes = { 16, 7 },
    features = {
        { id = "ash", kind = "ash", at = { { 10, 5 }, { 4, 10 }, { 15, 10 } }, words = { "what's left" }, base = true },
        { id = "houses", kind = "house_burned", at = { { 2, 1 }, { 7, 1 }, { 15, 1 } }, words = { "village", "old village" },
          say = "burned-out houses" },
        { id = "bell", kind = "bell_fallen", at = { { 11, 6 } }, words = { "tongue", "little bell" },
          say = "the village bell, lying in the ash" },
        { id = "fence", kind = "fence", at = { { 3, 5 }, { 4, 5 }, { 5, 5 }, { 16, 9 }, { 17, 9 } }, words = { "fencepost", "burnt" },
          say = "burnt fenceposts" },
        { id = "well", kind = "well", at = { { 8, 9 } }, words = { "rebuilding" }, say = "the old well" },
        { id = "trees", kind = "dead_tree", at = { { 19, 6 }, { 13, 12 }, { 11, 2 } }, say = "dead trees" },
        { id = "rubble", kind = "rubble", at = { { 6, 7 }, { 14, 5 }, { 18, 12 } } },
    },
}

-- Millbrook's old walls -----------------------------------------------------------------------
B.millbrook_walls = {
    title = "Millbrook's old walls", light = "day",
    party = { 5, 10 }, npc = { 10, 7 }, foes = { 16, 1 },
    features = {
        { id = "walls", kind = "town_wall", at = run_but(1, 20, 3, { 6, 7, 12, 13, 14 }), words = { "half fallen", "old town" },
          say = "the old town walls", base = true },
        { id = "gate", kind = "gate", at = { { 12, 3 } }, say = "the gate" },
        { id = "gaps", kind = "rubble", at = { { 6, 3 }, { 7, 3 }, { 6, 4 } }, words = { "gaps", "fallen" }, say = "gaps full of rubble" },
        { id = "tower", kind = "watchtower", at = { { 18, 4 } }, say = "a watchtower" },
        { id = "stones", parts = { { kind = "cart", at = { { 3, 7 } } }, { kind = "crate", at = { { 9, 9 }, { 13, 11 } } } },
          words = { "carrying stones", "stones", "able body" }, say = "carts of stones" },
        { id = "hay", kind = "hay_bale", at = { { 15, 8 }, { 16, 8 } } },
        { id = "lamp", kind = "lamp_post", at = { { 11, 6 } } },
    },
}

-- The fighting pit behind the tannery ----------------------------------------------------------
B.fighting_pit = {
    title = "The fighting pit", light = "candle",
    party = { 4, 8 }, npc = { 6, 5 }, foes = { 12, 6 },
    features = {
        { id = "floor", kind = "floor_cobbles", at = { { 1, 1 } }, base = true },
        { id = "walls", kind = "wall_room", at = run(1, 20, 1), words = { "tannery" }, base = true },
        { id = "ring", kind = "pit_ring", at = { { 8, 4 } }, words = { "sawdust", "ring", "bleeding" }, say = "a sawdust ring" },
        { id = "odds", kind = "notice_board", at = { { 5, 2 } }, words = { "chalkboard", "odds" }, say = "a chalkboard of odds" },
        { id = "crowd", kind = "bench", at = { { 8, 11 }, { 12, 11 }, { 16, 5 } }, words = { "crowd", "cheers" }, say = "benches for the crowd" },
        { id = "barrels", kind = "barrel", at = { { 16, 2 }, { 17, 2 }, { 2, 11 } } },
        { id = "hay", kind = "hay_bale", at = { { 18, 10 } } },
    },
}

-- The forest road -----------------------------------------------------------------------------
B.forest_road = {
    title = "The forest road", light = "day",
    party = { 3, 7 }, npc = { 13, 7 }, foes = { 17, 7 },
    features = {
        { id = "road", kind = "road_ew", at = { { 1, 6 } }, words = { "north road" }, base = true },
        { id = "pines", kind = "pine", at = { { 2, 2 }, { 4, 1 }, { 7, 3 }, { 11, 2 }, { 14, 1 }, { 17, 3 }, { 19, 2 },
                                               { 3, 11 }, { 6, 12 }, { 10, 11 }, { 13, 12 }, { 16, 11 }, { 19, 12 } },
          words = { "close in" }, say = "pines closing in" },
        { id = "oak", kind = "oak", at = { { 9, 4 } } },
        { id = "brush", kind = "bush", at = { { 5, 4 }, { 12, 4 }, { 15, 10 }, { 8, 10 } } },
        { id = "tracks", kind = "tracks", at = { { 8, 7 }, { 11, 6 }, { 14, 8 } }, words = { "wolf tracks", "mud", "badge" },
          say = "wolf tracks across the road" },
        { id = "log", kind = "fallen_log", at = { { 15, 4 } } },
        { id = "rocks", kind = "rock", at = { { 18, 10 } } },
    },
}

-- The old bell paths ---------------------------------------------------------------------------
B.bell_paths = {
    title = "The old bell paths", light = "day",
    party = { 3, 7 }, npc = { 12, 6 }, foes = { 17, 7 },
    features = {
        { id = "path", kind = "road_ew", at = { { 1, 6 } }, words = { "footpath", "path" }, base = true },
        { id = "hillside", kind = "cliff", at = { { 1, 1 }, { 2, 1 }, { 3, 2 }, { 6, 1 }, { 7, 1 }, { 9, 2 }, { 12, 1 }, { 13, 1 },
                                                  { 16, 2 }, { 17, 1 }, { 20, 1 }, { 20, 2 } },
          words = { "hillside", "cut into" }, say = "the hillside" },
        { id = "trees", kind = "pine", at = { { 4, 4 }, { 11, 3 }, { 15, 4 }, { 5, 11 }, { 14, 11 }, { 19, 10 } },
          words = { "waymarks" }, say = "pines along the path" },
        { id = "waymark", kind = "signpost", at = { { 8, 5 } }, words = { "waymark", "waymarks" }, say = "an old waymark" },
        { id = "prints", kind = "tracks", at = { { 6, 7 }, { 10, 7 }, { 13, 7 } }, words = { "boot prints", "fresh" },
          say = "fresh boot prints, going up" },
        { id = "boulder", kind = "boulder", at = { { 9, 10 } } },
        { id = "valley", kind = "rock", at = { { 2, 12 }, { 17, 12 }, { 12, 13 } }, words = { "valley" }, say = "the drop to the valley" },
    },
}

-- The goblin camp -----------------------------------------------------------------------------
B.goblin_camp = {
    title = "The goblin camp", light = "fire",
    party = { 3, 7 }, npc = { 12, 10 }, foes = { 16, 7 },
    features = {
        { id = "mud", kind = "path_patch", at = { { 9, 6 } }, base = true },
        { id = "fire", kind = "campfire", at = { { 10, 7 } }, say = "a fire with a cooking pot" },
        { id = "drums", kind = "drum", at = { { 14, 5 }, { 15, 5 } } },
        { id = "tents", kind = "tent", at = { { 13, 2 }, { 6, 3 }, { 15, 11 } } },
        { id = "totem", kind = "totem", at = { { 17, 7 } } },
        { id = "seats", kind = "log_seat", at = { { 8, 6 }, { 12, 8 }, { 9, 9 } } },
        { id = "spears", kind = "weapon_rack", at = { { 18, 4 } } },
        { id = "trees", kind = "pine", at = { { 1, 1 }, { 3, 1 }, { 20, 1 }, { 2, 13 }, { 20, 12 }, { 19, 2 } } },
        { id = "rocks", kind = "rock", at = { { 5, 10 } } },
    },
}

-- The old rope bridge -------------------------------------------------------------------------
B.old_bridge = {
    title = "The old rope bridge", light = "day",
    party = { 5, 7 }, npc = { 14, 7 }, foes = { 16, 7 },
    features = {
        { id = "gorge", kind = "chasm", at = { { 9, 1 }, { 9, 9 } }, words = { "no bottom" }, say = "a gorge with no bottom", base = true },
        { id = "bridge", kind = "rope_bridge", at = { { 9, 6 } }, words = { "rain-slick", "creak" }, say = "rain-slick planks" },
        { id = "approach", kind = "path_patch", at = { { 4, 6 }, { 14, 6 } }, say = "muddy approaches" },
        { id = "trees", kind = "pine", at = { { 3, 2 }, { 6, 1 }, { 15, 2 }, { 18, 3 }, { 2, 11 }, { 17, 11 } } },
        { id = "rocks", kind = "rock", at = { { 6, 11 }, { 14, 10 }, { 7, 3 } } },
    },
}

-- Market square --------------------------------------------------------------------------------
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
        { id = "grass", kind = "tall_grass", at = { { 7, 4 }, { 13, 10 }, { 17, 3 } }, base = true },
        { id = "rocks", kind = "rock", at = { { 8, 10 }, { 15, 4 } } },
        { id = "brush", kind = "bush", at = { { 11, 8 } } },
    },
}

-- The campfire vignette between sessions (the prep screen's view of the table).
B.vignette = {
    title = "Campfire", light = "fire",
    party = { 5, 8 }, npc = { 11, 8 }, foes = { 15, 6 },
    features = {
        { id = "trees", kind = "pine", at = { { 1, 1 }, { 17, 2 }, { 2, 12 }, { 13, 11 }, { 19, 8 }, { 7, 1 } }, base = true },
        { id = "fire", kind = "campfire", at = { { 8, 5 } } },
        { id = "tents", kind = "tent", at = { { 3, 2 }, { 12, 2 } } },
        { id = "seats", kind = "log_seat", at = { { 6, 6 }, { 10, 6 } } },
        { id = "brush", kind = "bush", at = { { 17, 6 }, { 16, 4 } } },
        { id = "rocks", kind = "rock", at = { { 11, 9 } } },
    },
}

return B
