-- The four friends at the table. Data only: tune freely.
--
-- archetypes: primary counts double, secondary once (see game/data/archetypes.lua).
-- notes: what the DM learned at Session Zero; shown on the prep board.
-- thread: the character's backstory hook; components tagged with this
--         player's key advance it and give them the spotlight.

return {
    order = { "mara", "dev", "jess", "sam" },

    mara = {
        name = "Mara",
        char = "Thessaly",
        class = "wizard",
        class_name = "Wizard",
        primary = "storyteller",
        secondary = "explorer",
        notes = "Loves a mystery and a big reveal. Takes notes. Long fights lose her.",
        short = "Mysteries and big reveals. Long fights lose her.",
        hours = 3.75,      -- her ideal night at the table (A14: the table clock)
        thread = "her missing sister, Ilsa",
        -- How Session Zero introduces the character (A8): who they are, their hook, how they know the others.
        intro = "Hunting for her sister Ilsa, who vanished from the scriptorium. Pip picked her pocket at the Kettle; they've been friends since.",
        sprite = "mara",
    },

    dev = {
        name = "Dev",
        char = "Brannoc",
        class = "fighter",
        class_name = "Fighter",
        primary = "butt_kicker",
        secondary = "power_gamer",
        notes = "Wants to hit things and find cool weapons. Long talky scenes lose him.",
        short = "Fights and cool weapons. Long talks lose him.",
        hours = 4.5,       -- would play until two
        thread = "the warlord Kessrick, who burned his village",
        intro = "Kessrick's warband burned his village, Hale's Crossing. Oswin pulled him out of the ashes and he's never left his side.",
        sprite = "dev",
    },

    jess = {
        name = "Jess",
        char = "Pip",
        class = "rogue",
        class_name = "Rogue",
        primary = "method_actor",
        secondary = "instigator",
        notes = "Does voices, talks to every NPC, and will pickpocket the quest giver.",
        short = "Does voices, talks to everyone, pickpockets.",
        hours = 3.5,
        thread = "her debt to the Velvet Hand",
        intro = "Owes the Velvet Hand more than she'll admit. Thessaly caught her picking a pocket and bought her supper instead.",
        sprite = "jess",
    },

    sam = {
        name = "Sam",
        char = "Oswin",
        class = "cleric",
        class_name = "Cleric",
        primary = "casual",
        secondary = "tactician",
        notes = "Here for friends and snacks. Likes a fair, clever fight. Hates being put on the spot.",
        short = "Friends, snacks, fair fights. Not the spotlight.",
        hours = 3,         -- work on Friday
        thread = "the relic from his burned temple",
        intro = "Carries the last relic of his burned temple. Found Brannoc in the ashes of Hale's Crossing and patched him up.",
        sprite = "sam",
    },
}
