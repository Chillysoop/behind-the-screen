-- Handouts (from the earlier concepts, brought into the slice with the storylines): in prep you
-- can spend an hour making a real thing for a card on the board, a letter from that person, a
-- sketch of that place, a hand-drawn map, a note. When its scene plays it lands in front of a
-- player and stays at their seat, and the story it belongs to sticks: the table keeps looking at
-- it, so that storyline stays warm a week longer, and its clue leads next week's recap.
-- Data only: the model is game/model/handouts.lua, the paper on the table tools/gen_keepsakes.py.

return {
    COST = 1,            -- prep hours for one
    PER_WEEK = 2,        -- you only have so many evenings
    PER_SEAT = 3,        -- handouts that stay in front of one player (the oldest go in their bag)

    -- What a card's handout is.
    KIND = { location = "sketch", cast = "letter", goal = "note", complication = "note", reward = "letter" },
    MAPS = { hidden_map = true, torn_map = true, torn_map_goal = true, bell_paths = true, lost_road = true, find_tobin = true },
    WHAT = {
        sketch = "a sketch of {short}",
        letter = "a letter from {short}",
        note = "a handwritten clue",
        map = "a hand-drawn map",
    },
    -- When it lands. {what}, {name} (the player), {char}.
    LAND = {
        "You slide {what} across the table to {name}.",
        "{name} gets {what}, and reads it twice.",
        "You hand {name} {what}. The whole table leans over to look.",
    },
    -- What the player says, holding it.
    REACT = {
        "Wait, this is real? You MADE this? I'm keeping it forever.",
        "Okay, I'm putting this in a frame.",
        "Everyone shush, I'm reading. Out loud. In a voice.",
        "This changes everything. Probably. Let me read it again.",
    },
    HOLDER = { spotlight = 5, fun = 3 },
    ALL = { story = 3 },
    FANS = { storyteller = 2, explorer = 2, method_actor = 2 },   -- extra Fun for who loves this
}
