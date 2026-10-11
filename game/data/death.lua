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
                  about = "A character who dies stays dead. A new one joins next week." },
    meaningful = { name = "Rare and meaningful", short = "Rare, meaningful",
                   about = "Death only at the big moments, and it means something when it comes." },
    cost = { name = "Back, at a cost", short = "Back, at a cost",
             about = "The dead can come back, and it always costs them: a scar, a debt, a quest." },
    choice = { name = "The player's choice", short = "Their choice",
               about = "When a character dies, their player decides what happens next." },
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
    rogue = { "Check my left boot. There's money in it. For the wake.", "Well. That's one way to get out of paying the Velvet Hand.",
              "Don't let them say I tripped." },
    cleric = { "It's all right. I know where I'm going.", "Look after each other. That's the whole job.",
               "Light a candle for me. A big one." },
    wizard = { "Finish my notes. Page forty. You'll see.", "Fascinating. So that's what it's like.",
               "Find Ilsa. Promise me." },
}
M.WAKE = "They hold the wake at the Crooked Kettle. Gus pours one for {char} and leaves it on the bar all night."

-- Coming back at a cost: a scar in canon (it stays), a debt (a seed), or a quest (next week).
M.SCARS = {
    "{char} came back with one eye gone pale. It sees things, sometimes.",
    "{char} came back without a shadow. Nobody mentions it.",
    "{char} came back, and the dead talk to {char} now, a little, at night.",
    "{char} came back owing the thing that sent them back. It will ask, one day.",
}
M.QUEST = { name = "The way back", line = "There's a way to bring {char} back: a shrine in the hills, and a price at the end of it.",
            win = "{char} opens their eyes. They're back, and they remember the dark.",
            lose = "The shrine is silent. {char} isn't coming back. The table says goodbye properly." }

-- New characters: two for each class the rules engine supports. Same class as the fallen, so
-- the party still works; the player keeps their own voice. intro: how they join.
M.PREGENS = {
    fighter = {
        { id = "bryn", name = "Bryn", hook = "Brannoc's younger sister, who followed him out of Hale's Crossing and never told him.",
          intro = "sibling", mini = "pregen_bryn" },
        { id = "hesk", name = "Hesk Marrow", hook = "A hired sword with a scar for every town Kessrick burned, and a grudge for each.",
          intro = "hired", mini = "pregen_hesk" },
    },
    rogue = {
        { id = "tam", name = "Tam Quickley", hook = "A prisoner of the Velvet Hand the party sets loose. Owes them, and hates owing anyone.",
          intro = "rescued", mini = "pregen_tam" },
        { id = "lark", name = "Lark", hook = "Pip's old partner from Lowmarket, who heard the news and came anyway.",
          intro = "sibling", mini = "pregen_lark" },
    },
    cleric = {
        { id = "aldith", name = "Sister Aldith", hook = "A healer from the field hospital that never closes. She's seen worse than this.",
          intro = "hired", seed = "healers_vigil", mini = "pregen_aldith" },
        { id = "rufus", name = "Brother Rufus", hook = "A friar of the Laughing Saint who leaves pies at shrines and blessings everywhere.",
          intro = "rescued", seed = "laughing_shrine", mini = "pregen_rufus" },
    },
    wizard = {
        { id = "corwin", name = "Corwin Vell", hook = "An archive scholar who's read every map of the Vale, including the ones that lie.",
          intro = "hired", seed = "old_roads", mini = "pregen_corwin" },
        { id = "ysolde", name = "Ysolde", hook = "Ilsa's apprentice, who has her teacher's handwriting and none of her patience.",
          intro = "sibling", seed = "mirror_letters", mini = "pregen_ysolde" },
    },
}
M.INTRO = {
    sibling = "{new} walks into the Crooked Kettle carrying {old}'s pack. 'I heard. I'm coming with you. Don't argue.'",
    hired = "{new} has been waiting by the door all evening. 'Your friend paid me in advance,' {new} says. 'I'd like to earn it.'",
    rescued = "The party cuts {new} loose from a cart bound for the hills. {new} rubs their wrists and asks where they're headed.",
}
M.INTRO_SPOTLIGHT = 14

return M
