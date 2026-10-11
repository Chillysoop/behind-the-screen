-- Inspiration (M6): what the DM does with an evening off, and the cards it brings.
-- Each activity costs prep time and draws extra cards into this week's hand from the
-- reserve (components.lua, reserve = "inspiration"), from a player's backstory, or
-- from something the table made up. Inspired cards play a little better: the DM
-- actually cares about them. Data only: tune freely. The model is game/model/seeds.lua.
--
-- draw:   { n, tags = cards with any of these tags first, kinds = only these kinds }
-- thread: draws n cards from the backstory of whoever's Investment is lowest
-- canon:  turns a line of last week's canon into a callback card
-- seed:   adds a seed idea to this week's offer
-- short:  the few words the button has room for

return {
    PER_WEEK = 2,            -- activities a week
    QUALITY = 0.03,          -- inspired cards add this much scene quality on top of the usual

    order = { "novel", "movie", "supplement", "backstory", "canon", "walk" },

    novel = {
        name = "Read a fantasy novel", cost = 1, short = "Lore, mystery",
        about = "Mysteries, old lore and heartache.",
        draw = { n = 2, tags = { "lore", "mystery", "heart", "puzzle" } },
    },
    movie = {
        name = "Movie night", cost = 1, short = "Heists, duels",
        about = "Heists, duels and burning bridges.",
        draw = { n = 2, tags = { "action", "chaos", "danger" } },
    },
    supplement = {
        name = "The new supplement", cost = 1, short = "Monsters, loot",
        about = "New monsters and shiny loot.",
        draw = { n = 2, kinds = { "cast", "reward" }, tags = { "danger", "loot", "action" } },
    },
    backstory = {
        name = "Reread a backstory", cost = 1, short = "{name}'s past",
        about = "Two cards from {name}'s backstory.",
        thread = 2,
    },
    canon = {
        name = "Last week's canon", cost = 1, short = "A callback",
        about = "Turn something the table made up into a callback.",
        canon = true,
    },
    walk = {
        name = "A walk in the rain", cost = 1, short = "A seed idea",
        about = "Clears your head: a new seed idea and one surprise card.",
        draw = { n = 1 },
        seed = 1,
    },
}
