-- The four friends at the table. Data only: tune freely.
--
-- archetypes: primary counts double, secondary once (see game/data/archetypes.lua).
-- notes: what the DM learned at Session Zero; shown on the prep board.
-- thread, intro, premise, gist: what their hero is here for and who they are, in a phrase, a
--         sentence and a few words. An adventure gives its own (MODULE.heroes, adventure.enter).
-- pronouns: the hero's own ("she", "he" or "they"): lines that name one hero say {actor_their} and
--         the like (util.fill), never "they" for one hero (D6).

return {
    order = { "mara", "dev", "jess", "sam" },
    -- Where each friend sits, left to right as the DM sees the table (Conner, November 6): the tiles along the bottom
    -- and every row of the four are in this order, in every adventure (game/ui/panels.lua's seated). It follows
    -- the scene's seats (main/scene_data.lua's heads; tools/tests/agency_check.lua's SEATS holds them to it).
    seats = { "dev", "mara", "jess", "sam" },

    mara = {
        name = "Mara",
        char = "Thessaly",
        pronouns = "she",       -- (the hero's own: D6, Conner's pick, as their player's)
        class = "wizard",
        class_name = "Wizard",
        primary = "storyteller",
        secondary = "explorer",
        notes = "Loves a mystery and a big reveal. Takes notes. Long fights lose her.",
        short = "Mysteries and big reveals. Long fights lose her.",
        hours = 3.75,      -- her ideal night at the table (A14: the table clock)
        thread = "why she came",
        intro = "A wizard who wants to know everything.",
        premise = "Thessaly is a wizard who wants to know everything.",
        gist = "Thessaly, a wizard who wants to know everything",
        sprite = "mara",
    },

    dev = {
        name = "Dev",
        char = "Brannoc",
        pronouns = "he",       -- (the hero's own: D6, Conner's pick, as their player's)
        class = "fighter",
        class_name = "Fighter",
        primary = "butt_kicker",
        secondary = "power_gamer",
        notes = "Wants to hit things and find cool weapons. Long talky scenes lose him.",
        short = "Fights and cool weapons. Long talks lose him.",
        hours = 4.5,       -- would play until two
        thread = "why he came",
        intro = "A fighter who hits first.",
        premise = "Brannoc is a fighter who hits first.",
        gist = "Brannoc, a fighter who hits first",
        sprite = "dev",
    },

    jess = {
        name = "Jess",
        char = "Pip",
        pronouns = "she",       -- (the hero's own: D6, Conner's pick, as their player's)
        class = "rogue",
        class_name = "Rogue",
        primary = "method_actor",
        secondary = "instigator",
        notes = "Does voices, talks to every NPC, and will pickpocket the quest giver.",
        short = "Does voices, talks to everyone, pickpockets.",
        hours = 3.5,
        thread = "why she came",
        intro = "A rogue with sticky fingers.",
        premise = "Pip is a rogue with sticky fingers.",
        gist = "Pip, a rogue with sticky fingers",
        sprite = "jess",
    },

    sam = {
        name = "Sam",
        char = "Oswin",
        pronouns = "he",       -- (the hero's own: D6, Conner's pick, as their player's)
        class = "cleric",
        class_name = "Cleric",
        primary = "casual",
        secondary = "tactician",
        notes = "Here for friends and snacks. Likes a fair, clever fight. Hates being put on the spot.",
        short = "Friends, snacks, fair fights. Not the spotlight.",
        hours = 3,         -- work on Friday
        thread = "why he came",
        intro = "A cleric who keeps everyone standing.",
        premise = "Oswin is a cleric who keeps everyone standing.",
        gist = "Oswin, a cleric who keeps everyone standing",
        sprite = "sam",
    },
}
