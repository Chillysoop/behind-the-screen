-- Which board goes on the table for each scene (game/data/boards.lua; the prop kit is
-- game/data/props.lua). Data only: tune freely. A place with no board of its own borrows one
-- by what it is (game/model/maps.lua BY_SETTING), then by the scene type.

return {
    by_location = {
        -- The Museum of Nightmares (v2): its rooms as the book's maps draw them (the map library,
        -- game/data/maps/museum_*.map). The street outside isn't on the book's maps.
        mus_street = "market",
        mus_garden = "museum_garden",
        mus_entrance = "museum_entrance",
        mus_chamber = "museum_chamber",
        mus_paintings = "museum_paintings",
        mus_gift_shop = "museum_gift_shop",
        mus_hunting = "museum_hunting",
        mus_offices = "museum_offices",
        mus_tomorrow = "museum_tomorrow",
        mus_lecture = "museum_lecture",
        mus_lair = "museum_lair",
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
