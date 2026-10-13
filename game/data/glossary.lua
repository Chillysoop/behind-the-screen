-- The Story log's keywords (game/model/chronicle.lua): the names it lights up so you can hover
-- them. Most come from the game's own data (people, places, factions, heroes, storylines); this
-- file adds what the data doesn't say. Data only: tune freely.
--
-- aliases: other names the stories use for someone or somewhere, by person, location card or
--          faction id ("Sable" is Madame Sable). Case matters: names are proper nouns.
-- extra:   people the stories talk about who aren't in the notebook: { name, role, about,
--          thread = the hero whose story they're part of, cards = cards that are about them }.
-- terms:   words the Story log uses in its headings, with what they mean.

return {
    aliases = {
        madame_sable = { "Sable" },
        kessrick = { "Kessrick" },
        tobin = { "Tobin" },
        rook = { "Rook" },
        abbot_ghost = { "abbot" },
        merchant = { "Ottilie" },
        miller = { "Hob" },
        cutpurses = { "Cutpurses" },
        warband = { "Kessrick's wolves", "warband" },
        velvet_hand = { "the Hand" },
        spurs = { "Spurs" },
        old_faith = { "old faith" },
        tavern = { "Kettle" },
    },

    extra = {
        ilsa = { name = "Ilsa", role = "Thessaly's sister, missing", thread = "mara",
                 about = "A scribe at Millbrook's scriptorium. Two months ago she left her room above it, ink still wet, "
                     .. "and never came back.",
                 cards = { "ilsa_room", "ilsa_ring", "ilsa_journal", "corin", "follow_ilsa" } },
    },

    terms = {
        combat = "A fight on the battle mat. Initiative, attack rolls and hit points.",
        social = "Talking, scheming and bargaining: the party wants something from someone.",
        exploration = "Going somewhere and finding things out: discovery and secrets.",
        puzzle = "A riddle or a trap to outthink.",
        mystery = "Clues and suspects: something happened here, and someone knows why.",
        downtime = "Rest, shopping and banter between the big moments.",
        set_piece = "A big, flashy showdown: a fight with something going on around it.",
        won = "The scene went the party's way: its goal paid off, its fight was theirs.",
        lost = "The scene went against them. The story carries on anyway, from somewhere worse.",
        written = "What you wrote into their past at Session Zero: what they told you, what you said yes to, and what "
            .. "turns up first.",
        tonight = "Happening at the table right now. It's filed in the Story log when the night is over.",
        planned = "On your prep board for this week. It's only a plan until the table gets there.",
        moving = "The storyline moved within the last week or two. The table is following it.",
        cooling = "Two weeks without a scene. Touch it soon or it goes cold.",
        cold = "Leave it this week and the table notices it's been dropped.",
        loose = "A loose end: dropped long enough that the table noticed. It wears them down a little every week "
            .. "until it comes back, and coming back is a lovely surprise.",
        unopened = "Not started yet: it opens the first time one of its cards plays.",
        resolved = "Tied off: its ending played and was won.",
        ended = "Over: its hero has left the table.",
        lead = "A card that belongs to this storyline and is waiting in your story deck. Put it on a scene and the "
            .. "story moves.",
    },
}
