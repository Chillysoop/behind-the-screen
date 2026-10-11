-- Scene types for the beat board. Data only: tune freely.
--
-- tension: where the scene sits on the pacing curve, 1 (calm) to 5 (peak).
-- short:   what it is, on the prep board's tile (blurb: the longer version).
-- meters:  what a well-run scene gives everyone, before taste and quality.
-- shine:   classes that get the spotlight here (1 = full, 0.5 = some).
-- climax:  the big paused roll that settles a non-combat scene ({cast},
--          {location} and {goal} are filled in); the DM then rules on it.
--          skill: the check the hero makes (their best of a list); variants: the same
--          moment told differently where it fits better (where = settings, as on cards;
--          cast = only with someone to talk to).

return {
    order = { "combat", "social", "exploration", "puzzle", "mystery", "downtime", "set_piece" },

    combat = {
        name = "Combat",
        tension = 4,
        short = "A fight on the battle mat.",
        blurb = "A fight. Butt-Kickers and Tacticians light up.",
        meters = { challenge = 22, reward = 4, social = 4, story = 3 },
        shine = { fighter = 1, cleric = 0.5 },
        tags = { "action", "danger" },
    },

    social = {
        name = "Social",
        tension = 2,
        short = "Talking, scheming, bargaining.",
        blurb = "Talking, scheming, bargaining. Method Actors live here.",
        meters = { social = 20, story = 8 },
        shine = { rogue = 1, cleric = 0.5 },
        tags = { "talk" },
        climax = { text = "{actor_char} makes the big pitch to {cast}.", dc = 12, prefer = { "rogue", "cleric" },
                   skill = { "persuasion", "deception", "intimidation" }, cast = true,
                   variants = { { text = "{actor_char} stands up and makes the case to the whole room.", where = { "crowd" } },
                                { text = "{actor_char} makes the case for what they came here to do." } },
                   success = { log = "A long pause. Then a slow nod. They have a deal.",
                               effects = { { "actor", spotlight = 10 }, { "all", social = 6, story = 4 } } },
                   fail = { log = "It falls flat. The room goes cold.",
                            effects = { { "all", challenge = 6, story = 2 }, { "actor", fun = -2 } } } },
    },

    exploration = {
        name = "Exploration",
        tension = 3,
        short = "Discovery and secrets.",
        blurb = "Discovery and secrets. Explorers lean in.",
        meters = { story = 12, reward = 8, challenge = 6 },
        shine = { rogue = 1, wizard = 0.5 },
        tags = { "explore" },
        climax = { text = "{actor_char} pushes into the last, darkest part of {location}.", dc = 13, prefer = { "rogue", "wizard" },
                   skill = { "perception", "investigation", "survival", "athletics" },
                   success = { log = "Behind the last door: exactly what they came for.",
                               effects = { { "actor", spotlight = 10 }, { "arch:explorer", fun = 6, reward = 4 }, { "all", story = 4 } } },
                   fail = { log = "A wrong turn. They come out scraped, muddy and empty-handed.",
                            effects = { { "all", challenge = 6 }, { "arch:explorer", fun = -2 } } } },
    },

    puzzle = {
        name = "Puzzle",
        tension = 3,
        short = "A riddle or a trap to outthink.",
        blurb = "A riddle or a trap to outthink. Tacticians love it.",
        meters = { challenge = 16, story = 6 },
        shine = { wizard = 1, rogue = 0.5 },
        tags = { "puzzle" },
        climax = { text = "{actor_char} tries the final answer.", dc = 14, prefer = { "wizard", "rogue" },
                   skill = { "investigation", "arcana", "history" },
                   success = { log = "Click. Gears turn. The whole room seems to sigh.",
                               effects = { { "actor", spotlight = 12, fun = 4 }, { "arch:tactician", fun = 6 }, { "all", story = 3 } } },
                   fail = { log = "Wrong. Something hisses in the walls.",
                            effects = { { "all", challenge = 8 }, { "arch:tactician", challenge = 4 } } } },
    },

    mystery = {
        name = "Mystery",
        tension = 3,
        short = "Clues and suspects.",
        blurb = "Clues and suspects. Storytellers take notes.",
        meters = { story = 20, social = 4, challenge = 4 },
        shine = { wizard = 1, rogue = 0.5 },
        tags = { "mystery", "lore" },
        climax = { text = "{actor_char} lays out the whole case, finger pointed.", dc = 13, prefer = { "wizard", "cleric" },
                   skill = { "investigation", "insight" },
                   success = { log = "The culprit goes white. They got it.",
                               effects = { { "actor", spotlight = 12 }, { "arch:storyteller", story = 8, fun = 4 }, { "all", story = 4 } } },
                   fail = { log = "Wrong person. Very awkward. The real culprit slips away.",
                            effects = { { "all", story = 6, challenge = 4 }, { "actor", fun = -3 } } } },
    },

    downtime = {
        name = "Downtime",
        tension = 1,
        short = "Rest, shopping and banter.",
        blurb = "Rest, shopping, banter. Casual players unwind.",
        meters = { social = 24, story = 4, reward = 3 },
        shine = { cleric = 1 },
        tags = { "cozy", "talk" },
        climax = { text = "{actor_char} takes on the local champion at arm-wrestling.", dc = 12, prefer = { "fighter", "cleric" },
                   skill = { "athletics" }, where = { "crowd", "tavern", "town" },
                   variants = { { text = "Around the fire, {actor_char} tells the story everyone's been waiting for.",
                                  skill = { "performance", "history" } } },
                   success = { log = "Slam! The tavern goes wild. Free drinks all round.",
                               effects = { { "actor", spotlight = 10, fun = 4 }, { "all", social = 6 } } },
                   fail = { log = "Slam, the wrong way. Everyone still buys them a drink.",
                            effects = { { "all", social = 4 }, { "actor", fun = 1 } } } },
    },

    set_piece = {
        name = "Set piece",
        tension = 5,
        short = "A big, flashy showdown.",
        blurb = "A big, flashy showdown. Everyone's at the edge of their seat.",
        meters = { challenge = 18, story = 10, social = 4, reward = 3 },
        shine = { fighter = 1, rogue = 0.5, wizard = 0.5, cleric = 0.5 },
        tags = { "action", "danger" },
    },
}
