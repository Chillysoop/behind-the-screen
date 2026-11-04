-- First-session character intros: before the story starts, each player introduces themselves
-- and their hero, gives a little backstory, and the table reacts. Tables love a player who's all
-- in, so reactions run warm; the shy ones get a short intro and a kind word. game/model/intros.lua
-- runs it.

local M = {}

-- hello: what each player says first, out of character. Their hero's story (in character), which
-- of those lines are sad (grim, so the table answers kindly) and their all-in flourish come from
-- the adventure: its hooks' intro lines and MODULE.all_in (adventure.enter).
M.PLAYERS = {
    mara = {
        hello = { "Okay! Hi, I'm Mara, and I'm playing Thessaly. She's a wizard.",
                  "Me first? Okay. I'm Mara. This is Thessaly, wizard, too clever for her own good." },
    },
    dev = {
        hello = { "I'm Dev. This is Brannoc. Fighter. Big sword.",
                  "Dev. Playing Brannoc. Fighter. He's angry, and he has a greatsword." },
    },
    jess = {
        hello = { "Hi! Jess. And THIS is Pip.", "I'm Jess, and I'll be doing a voice. You've been warned. This is Pip." },
    },
    sam = {
        hello = { "Oh, me? I'm Sam. Oswin. He's a cleric.", "Sam. I'm playing Oswin. Cleric. That's... yeah." },
    },
}

-- When their partner speaks up (A8: who knows whom), the other one chimes in, in character:
-- BOND[partner][speaker]. Empty: the heroes meet at the adventure's start.
M.BOND = {}

-- The table's reactions: warm for a player who's all in, kind for a short one.
M.REACT = {
    all_in = { "Oh, I love her already.", "Okay, that's amazing.", "You made a whole backstory! I love it.",
               "Chills. Actual chills.", "Okay, now I have to try harder." },
    warm = { "Love it.", "Ooh, I like that.", "That's great.", "Oh, that's a good one.", "Nice!" },
    -- After a sad backstory: nobody says "Nice!".
    grim = { "Oof. That's heavy.", "Oh no. Okay, I'm invested.", "That's a good hook. Sad, but good.",
             "Okay, that hit me.", "Aw. We've got you." },
    short = { "Short and sweet. Love it.", "Hey, that's perfect.", "Tea guy! Love tea guy.", "We'll find out the rest." },
}

-- How long it takes, in table minutes (the table clock moves while they talk).
M.TABLE_MIN = 1.5
-- What it does: the one introducing gets a moment in the light; everyone warms to the table.
M.EFFECT = { spotlight = 6, investment = 2, social_all = 2, all_in_fun = 2 }
-- All in: committed enough, or the kind of player who lives for this.
M.ALL_IN_COMMITMENT = 66
M.ALL_IN_ARCHETYPES = { method_actor = true, storyteller = true }

return M
