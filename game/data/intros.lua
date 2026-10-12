-- First-session character intros: before the story starts, each player introduces themselves
-- and their hero, gives a little backstory, and the table reacts. Tables love a player who's all
-- in, so reactions run warm; the shy ones get a short intro and a kind word. game/model/intros.lua
-- runs it. hello is out of character (the player); story is in character (the hero, first
-- person); all_in is the extra flourish from a player who's committed.

local M = {}

M.PLAYERS = {
    mara = {
        hello = { "Okay! Hi, I'm Mara, and I'm playing Thessaly. She's a wizard.",
                  "Me first? Okay. I'm Mara. This is Thessaly, wizard, too clever for her own good." },
        story = { "My sister Ilsa copied books at the scriptorium in Millbrook. Two months ago she left her room, her ink "
                      .. "still wet, and never came back. I'm going to find out where she went.",
                  "Ilsa was always the brave one. I was the one who read about brave people. Now she's missing, and "
                      .. "I'm the one who has to go looking." },
        grim = { true, true },          -- which story lines are sad (the table answers kindly)
        all_in = { "I wrote her a whole notebook. Ilsa's handwriting is on the first page. I practised it.",
                   "And I have a list of every question I'm going to ask anyone who's seen her." },
    },
    dev = {
        hello = { "I'm Dev. This is Brannoc. Fighter. Big sword.",
                  "Dev. Playing Brannoc. Fighter. He's angry, and he has a greatsword." },
        story = { "Kessrick's warband burned my village, Hale's Crossing. I'm the only one who walked out, and only because "
                      .. "Oswin dragged me.",
                  "I was a soldier once. I went home to Hale's Crossing to stop being one. Then Kessrick came, and "
                      .. "now I'm going to find him." },
        grim = { true, true },
        all_in = { "I worked out his whole build. And the greatsword has a name. It's Ember.",
                   "Also, I drew the village. Where everyone lived. It's on the back of my sheet." },
    },
    jess = {
        hello = { "Hi! Jess. And THIS is Pip.", "I'm Jess, and I'll be doing a voice. You've been warned. This is Pip." },
        story = { "Pip. Just Pip. I may owe some people some money. Not a lot of money. A fair bit of money. Don't ask "
                      .. "Madame Sable about it.",
                  "Thessaly caught my hand in her purse at the Kettle, and instead of shouting she bought me supper. "
                      .. "Weirdest night of my life. Been following her around since." },
        all_in = { "She does a little bow. Every time. I'm going to do the bow every time.",
                   "Pip has a lucky coin. It's not lucky. She stole it. I made it a backstory." },
    },
    sam = {
        hello = { "Oh, me? I'm Sam. Oswin. He's a cleric.", "Sam. I'm playing Oswin. Cleric. That's... yeah." },
        story = { "My temple burned. I carry what was left of it. And I pulled Brannoc out of the ashes, so he's my "
                      .. "problem now.",
                  "Oswin heals people. He's not very good at talking about himself. Neither am I." },
        grim = { true, false },
        all_in = { "He makes tea for everyone at camp. That's his whole thing. I'll be describing the tea.",
                   "I looked up what clerics do. He's going to be the one who keeps everyone standing." },
    },
}

-- When their partner speaks up (A8: who knows whom), the other one chimes in, in character.
M.BOND = {
    dev = { sam = "He did drag me. Badly. I've got the scars to prove it." },
    sam = { dev = "Still mad he didn't let me finish the stitches." },
    jess = { mara = "And she bought me supper. I'm still not over it." },
    mara = { jess = "She still owes me for that supper." },
}

-- The table's reactions: warm for a player who's all in, kind for a short one.
M.REACT = {
    all_in = { "Oh, I love her already.", "Okay, that's amazing.", "You made a whole backstory! I love it.",
               "Chills. Actual chills.", "Okay, now I have to try harder." },
    warm = { "Love it.", "Ooh, I like that.", "That's great.", "Oh, that's a good one.", "Nice!" },
    -- After a sad backstory (a burned village, a missing sister): nobody says "Nice!".
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
