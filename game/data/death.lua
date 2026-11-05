-- Death at the table (M8, B3; the GDD's "Death at the table"). Data only: tune freely. The model
-- is game/model/death.lua.
--
-- Session Zero sets the table's default; each player has a preference of their own, and the
-- DM can honour it for them (an override, revisited any time from their character sheet).
-- Honouring a preference builds Trust; going against it costs it.

local M = {}

M.MODES = { "permanent", "meaningful", "cost", "choice" }
M.MODE = {
    permanent = { name = "Dead is dead", short = "Dead is dead",
                  about = "Dead stays dead. A new hero joins next week." },
    meaningful = { name = "Rare and meaningful", short = "Rare, meaningful", button = "Rare",
                   about = "Death only at big moments, and it means something." },
    cost = { name = "Back, at a cost", short = "Back, at a cost",
             about = "They can come back, at a cost: a scar that stays with them." },
    choice = { name = "The player's choice", short = "Their choice",
               about = "Their player decides what happens next." },
}

-- What each player wants, and what they say about the table's choice (Session Zero).
M.PREF = { mara = "meaningful", dev = "permanent", jess = "choice", sam = "cost" }
M.RULE = {
    name = "When a hero dies",
    order = M.MODES,
    permanent = { like = { mara = 0, dev = 2, jess = -2, sam = -2 },
                  says = { dev = "Good. If Brannoc goes, he goes.", jess = "Wait, forever forever?" } },
    meaningful = { like = { mara = 2, dev = 1, jess = 0, sam = 0 },
                   says = { mara = "Yes. It should matter when it happens." } },
    cost = { like = { mara = 0, dev = -1, jess = 1, sam = 2 },
             says = { sam = "A way back. I can live with that. So can Oswin.", dev = "So nobody really dies?" } },
    choice = { like = { mara = 1, dev = 0, jess = 2, sam = 1 },
               says = { jess = "If Pip dies I want a say in it.", dev = "Fine, as long as I can choose 'dead'." } },
}
M.DEFAULT = "meaningful"

-- Trust when it happens: what you did against what they wanted.
M.HONOURED = 4         -- you did what they asked for
M.IGNORED = -6         -- you went against it
M.FUDGE_STAKES = -3    -- a second fudged death: Trust from the players who want stakes
M.STAKES = { "tactician", "butt_kicker", "power_gamer" }

-- The goodbye: last words, then the table's wake. A Spotlight and Story moment for the player.
M.GOODBYE = { spotlight = 18, story = 12, social = 8, skip_fun = -4 }
M.LAST_WORDS = {
    fighter = { "Tell them I held the line.", "Not a bad fight. Not a bad fight at all.", "Someone take my sword. It's a good sword." },
    rogue = { "Check my left boot. There's money in it. For the wake.", "Don't let them say I tripped." },
    cleric = { "It's all right. I know where I'm going.", "Look after each other. That's the whole job.",
               "Light a candle for me. A big one." },
    wizard = { "Finish my notes. Page forty. You'll see.", "Fascinating. So that's what it's like." },
}
M.WAKE = "They hold a wake for {char} that night, and everyone has a story to tell."

-- Coming back at a cost: a scar in canon (it stays).
M.SCARS = {
    "{char} came back with one eye gone pale. It sees things, sometimes.",
    "{char} came back without a shadow. Nobody mentions it.",
    "{char} came back, and the dead talk to {char} now, a little, at night.",
    "{char} came back owing the thing that sent {char_them} back. It will ask, one day.",
}

-- New characters: two for each class the rules engine supports. Same class as the fallen, so
-- the party still works; the player keeps their own voice. pronouns: the new hero's own (D6). intro: how they join. An adventure
-- gives them its own hooks and introductions (adventure.museum_death).
M.PREGENS = {
    fighter = {
        { id = "bryn", name = "Bryn", pronouns = "she", hook = "Brannoc's younger sister, who followed him from home and never told him.",
          intro = "sibling", mini = "pregen_bryn" },
        { id = "hesk", name = "Hesk Marrow", pronouns = "he", hook = "A hired sword with a scar for every job, and a story for each.",
          intro = "hired", mini = "pregen_hesk" },
    },
    rogue = {
        { id = "tam", name = "Tam Quickley", pronouns = "he", hook = "A prisoner the party sets loose. Owes them, and hates owing anyone.",
          intro = "rescued", mini = "pregen_tam" },
        { id = "lark", name = "Lark", pronouns = "she", hook = "Pip's old partner, who heard the news and came anyway.",
          intro = "sibling", mini = "pregen_lark" },
    },
    cleric = {
        { id = "aldith", name = "Sister Aldith", pronouns = "she", hook = "A healer from the field hospital that never closes. She's seen worse than this.",
          intro = "hired", mini = "pregen_aldith" },
        { id = "rufus", name = "Brother Rufus", pronouns = "he", hook = "A cheerful friar who leaves blessings everywhere he goes.",
          intro = "rescued", mini = "pregen_rufus" },
    },
    wizard = {
        { id = "corwin", name = "Corwin Vell", pronouns = "he", hook = "A scholar who's read every map he could find, including the ones that lie.",
          intro = "hired", mini = "pregen_corwin" },
        { id = "ysolde", name = "Ysolde", pronouns = "she", hook = "A wizard's old apprentice, with her teacher's handwriting and none of her patience.",
          intro = "sibling", mini = "pregen_ysolde" },
    },
}
M.INTRO = {
    sibling = "{new} turns up carrying {old}'s pack. 'I heard. I'm coming with you. Don't argue.'",
    hired = "{new} has been waiting by the door all evening. 'Your friend paid me in advance,' {new} says. 'I'd like to earn it.'",
    rescued = "The party gets {new} out of a tight spot. {new} rubs {new_their} wrists and asks where the party's headed.",
}
M.INTRO_SPOTLIGHT = 14

-- What the dead hero carried, settled out loud (death.settle_pack: round three, A1). {char}: who died;
-- {gets}: "Pip takes the bracelet; Brannoc takes a healing potion".
M.PACK_SHARED = {
    "They share out what {char} carried: {gets}.",
    "Quietly, {char}'s pack is shared out: {gets}.",
    "Nobody wants to, but somebody has to: {gets}. It's what {char} would have wanted.",
}
M.PACK_LEFT = {
    "What {char} carried stays with {char_them}.",
    "Nobody touches {char}'s pack. It stays where {char_they} fell.",
    "{char}'s things stay with {char_them}.",
}

return M
