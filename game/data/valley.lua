-- The valley map (the rebuild spec's first milestone, October 17): where the campaign's places sit
-- on the map you prep on. Data only; the model is game/model/valley.lua.
--
-- Positions are fractions of the map (x 0 left to 1 right, y 0 top to 1 bottom). The core places
-- are laid out by hand so the valley reads right: Millbrook in the middle, the north road climbing
-- into the pines and the hills, the forest to the west, the river and the road to Coppergate to the
-- east, the coast to the south-east. A place with no position here is laid out from its tags
-- (SECTORS), once, and keeps that spot for the rest of the campaign.
--
-- A hub is a pin that holds several places (a town's streets): the map shows the hub, and its panel
-- lists the places inside. label: which side of the pin its name sits ("r", "l", "t", "b").

return {
    -- Pins closer than this (in map fractions) get pushed apart when they're laid out.
    MIN_GAP = 0.085,

    hubs = {
        millbrook = { name = "Millbrook", x = 0.47, y = 0.55, label = "b",
                      about = "The town: the Kettle, the market, the bell tower and the rest." },
        coppergate = { name = "Coppergate", x = 0.92, y = 0.66, label = "l",
                       about = "The city down the Tinker's Road." },
        brinehollow = { name = "Brinehollow", x = 0.86, y = 0.90, label = "l",
                        about = "The harbor town on the coast." },
        deep = { name = "The Deep Stair", x = 0.07, y = 0.09, label = "r",
                 about = "Stairs into the mountain, and the halls below." },
    },

    -- Which hub a place belongs to. Core places tagged "town" are Millbrook's unless named here.
    members = {
        fr_harvest_fair = "millbrook", fr_millpond = "millbrook", gz_bell_foundry = "millbrook",
        ur_brass_lantern = "coppergate", ur_canal_market = "coppergate", ur_chimney_road = "coppergate",
        ur_lamplighters = "coppergate", ur_north_gate = "coppergate", ur_sewers = "coppergate",
        gz_clocktower = "coppergate", masquerade = "coppergate",
        sea_brinehollow = "brinehollow", sea_customs_house = "brinehollow",
        dn_mouth = "deep", dn_flooded_hall = "deep", dn_lamp_ladder = "deep", dn_mushroom_market = "deep",
        dn_portal_hall = "deep", dn_safe_room = "deep",
    },
    -- Town places that aren't Millbrook's (they stand on their own).
    not_millbrook = { field_hospital = true },

    places = {
        forest_road = { x = 0.42, y = 0.36, label = "r" },
        chapel = { x = 0.29, y = 0.40, label = "l" },
        crypt = { x = 0.22, y = 0.48, label = "l" },
        mod_bell_crypt = { x = 0.35, y = 0.49, label = "b" },
        bell_paths = { x = 0.39, y = 0.18, label = "r" },
        shrine = { x = 0.24, y = 0.12, label = "r" },
        hales_crossing = { x = 0.66, y = 0.22, label = "r" },
        field_hospital = { x = 0.60, y = 0.36, label = "r" },
        goblin_camp = { x = 0.14, y = 0.32, label = "r" },
        fr_old_mine = { x = 0.10, y = 0.20, label = "r" },
        lost_road = { x = 0.06, y = 0.56, label = "t" },
        fr_west_road = { x = 0.20, y = 0.60, label = "b" },
        barrow = { x = 0.24, y = 0.76, label = "r" },
        webbed_cellar = { x = 0.52, y = 0.74, label = "r" },
        old_bridge = { x = 0.70, y = 0.48, label = "r" },
        mod_bridge_span = { x = 0.79, y = 0.44, label = "t" },
        gz_waystation = { x = 0.84, y = 0.30, label = "l" },
        fr_tinkers_road = { x = 0.79, y = 0.58, label = "b" },
        gz_causeway = { x = 0.68, y = 0.84, label = "l" },
        sunken_temple = { x = 0.50, y = 0.92, label = "r" },
        lighthouse = { x = 0.95, y = 0.80, label = "l" },
    },

    -- Roads between places (or hubs). One is drawn when both ends are on the map.
    roads = {
        { "millbrook", "forest_road" }, { "forest_road", "bell_paths" }, { "forest_road", "chapel" },
        { "chapel", "crypt" }, { "chapel", "mod_bell_crypt" }, { "forest_road", "hales_crossing" },
        { "bell_paths", "shrine" }, { "millbrook", "old_bridge" }, { "old_bridge", "fr_tinkers_road" },
        { "fr_tinkers_road", "coppergate" }, { "millbrook", "fr_west_road" }, { "fr_west_road", "lost_road" },
        { "fr_west_road", "goblin_camp" }, { "goblin_camp", "fr_old_mine" }, { "millbrook", "barrow" },
        { "millbrook", "webbed_cellar" }, { "millbrook", "gz_causeway" }, { "gz_causeway", "brinehollow" },
        { "brinehollow", "lighthouse" }, { "gz_causeway", "sunken_temple" }, { "hales_crossing", "gz_waystation" },
        { "gz_waystation", "coppergate" }, { "old_bridge", "mod_bridge_span" }, { "mod_bridge_span", "gz_waystation" },
        { "millbrook", "field_hospital" }, { "field_hospital", "hales_crossing" }, { "fr_old_mine", "deep" },
        { "shrine", "deep" },
    },

    -- Where a place with no position goes, by its first matching tag: an angle around Millbrook
    -- (degrees, 0 east, 90 south) with a spread, and how far out (a fraction of the map).
    SECTORS = {
        { tag = "high", angle = -95, spread = 40, near = 0.30, far = 0.42 },
        { tag = "island", angle = 40, spread = 15, near = 0.40, far = 0.46 },
        { tag = "ship", angle = 35, spread = 15, near = 0.38, far = 0.46 },
        { tag = "port", angle = 40, spread = 20, near = 0.36, far = 0.44 },
        { tag = "water", angle = 50, spread = 35, near = 0.26, far = 0.42 },
        { tag = "forest", angle = 190, spread = 30, near = 0.26, far = 0.40 },
        { tag = "camp", angle = -40, spread = 30, near = 0.28, far = 0.40 },
        { tag = "under", angle = 140, spread = 35, near = 0.24, far = 0.40 },
        { tag = "ruin", angle = 110, spread = 40, near = 0.26, far = 0.40 },
        { tag = "road", angle = 0, spread = 180, near = 0.20, far = 0.30 },
        { tag = "town", angle = 0, spread = 180, near = 0.14, far = 0.22 },
        { tag = nil, angle = 0, spread = 180, near = 0.22, far = 0.40 },
    },

    -- What the map draws under the pins: a river from the hills to the sea, woods to the west,
    -- hills to the north. Points in map fractions.
    river = { { 0.78, 0.00 }, { 0.75, 0.20 }, { 0.70, 0.48 }, { 0.64, 0.70 }, { 0.60, 0.86 }, { 0.58, 1.00 } },
    woods = { { 0.08, 0.36 }, { 0.12, 0.42 }, { 0.17, 0.26 }, { 0.20, 0.36 }, { 0.10, 0.27 }, { 0.26, 0.28 },
              { 0.33, 0.27 }, { 0.47, 0.27 }, { 0.15, 0.48 }, { 0.05, 0.43 }, { 0.30, 0.20 }, { 0.53, 0.30 } },
    hills = { { 0.18, 0.06 }, { 0.31, 0.07 }, { 0.47, 0.08 }, { 0.56, 0.12 }, { 0.12, 0.13 } },

    -- A tag as words, for a place's card ("A wild, ruined place").
    TAG_WORDS = {
        town = "in town", wild = "out in the wild", outdoor = "outdoors", indoor = "indoors", ruin = "ruined",
        water = "by the water", under = "underground", road = "on the road", high = "up high", crowd = "busy",
        shop = "a place to trade", bells = "one of the bell places", forest = "in the woods", tavern = "a tavern",
        camp = "a camp", bridge = "a bridge", port = "a harbor", island = "an island", ship = "a ship",
        vault = "locked up tight",
    },
}
