-- Which board goes on the table for each scene (game/data/boards.lua; the prop kit is
-- game/data/props.lua). Data only: tune freely. A place with no board of its own borrows one
-- by what it is (game/model/maps.lua BY_SETTING), then by the scene type.

return {
    by_location = {
        tavern = "kettle",
        velvet_den = "velvet_den",
        ilsa_room = "ilsa_room",
        counting_house = "counting_house",
        chapel = "chapel",
        bell_tower = "bell_tower",
        crypt = "crypt",
        barrow = "barrow",
        shrine = "shrine",
        archive = "archive",
        webbed_cellar = "cellar",
        hales_crossing = "hales_crossing",
        millbrook_walls = "millbrook_walls",
        fighting_pit = "fighting_pit",
        forest_road = "forest_road",
        bell_paths = "bell_paths",
        goblin_camp = "goblin_camp",
        old_bridge = "old_bridge",
        market = "market",
        lost_road = "road",
        field_hospital = "tavern",
        lighthouse = "ruins",
        masquerade = "tavern",
        sunken_temple = "underground",
        rooftops = "town",
    },
    -- No location written (or improvised from a stock move): pick by scene type.
    by_scene = {
        combat = "forest",
        social = "tavern",
        exploration = "ruins",
        puzzle = "ruins",
        mystery = "ruins",
        downtime = "tavern",
        set_piece = "camp",
    },
    intro = "vignette",
}
