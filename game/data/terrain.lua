-- Which terrain set goes on the table for each scene. Data only: tune freely.
-- The sets themselves (and the squares their scenery covers) are generated:
-- see tools/terrain_layout.py and game/data/terrain_layout.lua.

return {
    by_location = {
        old_bridge = "bridge",
        tavern = "tavern",
        chapel = "ruins",
        forest_road = "forest",
        archive = "ruins",
        goblin_camp = "camp",
        market = "market",
        bell_tower = "ruins",
        hales_crossing = "market",
        velvet_den = "tavern",
        webbed_cellar = "ruins",
        lighthouse = "ruins",
        masquerade = "market",
        sunken_temple = "ruins",
        lost_road = "forest",
        rooftops = "market",
        field_hospital = "tavern",
        -- The slice rework's new places.
        ilsa_room = "tavern",
        bell_paths = "forest",
        millbrook_walls = "market",
        shrine = "ruins",
        barrow = "ruins",
        crypt = "ruins",
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
    intro = "camp",
}
