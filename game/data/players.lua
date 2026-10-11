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
        thread = "her missing sister, Ilsa",
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
        thread = "the warlord Kessrick, who burned his village",
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
        thread = "her debt to the Velvet Hand",
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
        thread = "the relic from his burned temple",
        sprite = "sam",
    },
}
