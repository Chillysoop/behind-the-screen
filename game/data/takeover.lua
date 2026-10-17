-- Taking over (M8, B8): the numbers and the table's reactions. The NPC's own lines are in the
-- dialogue library (talk_open, talk_ask, talk_reply); see game/model/takeover.lua.

local M = {}

-- Talk as the NPC: how often a night's first key person gets it, and the liar's Deception DC.
M.TALK_CHANCE = 0.7
M.LIE_DC = 12

-- If the library ever runs dry for someone.
M.FALLBACK = {
    talk_open = { warm = "Good to see you. Sit down.", guarded = "What do you want?", lie = "Nothing's wrong here. Nothing at all." },
    talk_ask = { warm = "Alright. Here's what I know.", guarded = "I can't tell you that.", lie = "Never heard of it." },
}

-- What each stance does for the table (who likes it), per turn.
M.EFFECTS = {
    talk_open = {
        warm = { { "actor", social = 4, fun = 2 }, { "arch:method_actor", fun = 2 }, { "arch:casual", fun = 1 } },
        guarded = { { "arch:explorer", challenge = 3 }, { "arch:tactician", challenge = 2 } },
        lie = { { "arch:instigator", fun = 3 }, { "arch:method_actor", fun = 2 }, { "arch:explorer", challenge = 2 } },
    },
    -- Whoever's doing the talking has the table's attention, whatever the answer.
    talk_ask = {
        warm = { { "all", story = 5 }, { "arch:storyteller", fun = 4 }, { "arch:explorer", fun = 3 }, { "actor", social = 3, spotlight = 6 } },
        guarded = { { "arch:storyteller", story = -2 }, { "arch:explorer", challenge = 4 }, { "arch:butt_kicker", fun = -1 },
                    { "actor", spotlight = 5 } },
        lie = { { "arch:instigator", fun = 3 }, { "arch:explorer", challenge = 3 }, { "arch:storyteller", story = 2 },
                { "actor", spotlight = 5 } },
    },
}
-- Lines that fit who they are (a villain who lies, a friend who's warm) read as a real person.
M.IN_CHARACTER = { { "arch:storyteller", story = 2 }, { "arch:method_actor", fun = 2 } }
-- A lie seen through, or swallowed.
M.CAUGHT = { { "all", story = 4 }, { "arch:explorer", fun = 4 }, { "arch:instigator", fun = 2 } }
M.BELIEVED = { { "arch:storyteller", story = 1 } }

-- Run the boss's turn: how often its first turn is handed over (always when a hero is down).
M.BOSS_FIRST_CHANCE = 0.6
M.BOSS = {
    clever = { { "arch:tactician", fun = 5, challenge = 4 }, { "arch:butt_kicker", challenge = 3 }, { "arch:power_gamer", challenge = 2 } },
    cruel = { { "arch:butt_kicker", challenge = 4 }, { "arch:tactician", challenge = 3 }, { "arch:casual", fun = -2 } },
    finish = { { "all", challenge = 5 }, { "arch:casual", fun = -4 }, { "arch:butt_kicker", challenge = 3 }, { "arch:storyteller", story = 2 } },
    closest = { { "all", challenge = 2 } },
    gloat = { { "arch:storyteller", story = 4 }, { "arch:method_actor", fun = 3 }, { "arch:butt_kicker", challenge = -3 },
              { "arch:tactician", trust = -1, challenge = -2 } },
}
-- Going after the same player again within a few weeks: they notice, and so does everyone else.
M.PILE_WEEKS = 3
M.PILED_FUN = -6
M.PILED_LINES = {
    "Why is it always {char}? Does the monster have a list?",
    "Okay, the monsters really have it in for {char}.",
    "{char} again? Somebody owes the monsters money.",
    "Is there a reason nothing ever attacks anyone but {char}?",
}

-- What the table says about the boss's turn.
M.REACT = {
    clever = { "Oh, that's smart. I hate that that's smart.", "It's going for the damage. This thing has read the rules.",
               "Okay, that boss knows what it's doing.", "Smart monster. Very rude, but smart." },
    cruel = { "Oof. Right for the weak spot.", "That's cold. Effective, but cold.", "No mercy tonight, huh?",
              "Okay, the gloves are off." },
    finish = { "You're hitting someone who's DOWN?", "Wow. Okay. That's a statement.", "That's brutal. Are we sure about this?",
               "Death saves just got very real." },
    gloat = { "A villain speech! Finally.", "Oh, it's monologuing. Let it talk.", "Everyone shush, the boss is talking.",
              "Okay, I love a villain who likes the sound of their own voice." },
    closest = { "It's just swinging at whatever's near. Fair.", "Angry and close. Classic.", "Fine, it picked the nearest snack." },
}
-- The notebook's line for the boss's turn.
M.BOSS_LOG = {
    clever = "{boss} went for {char}, the one hurting it most.",
    cruel = "{boss} went after {char} when they were weakest.",
    gloat = "{boss} stopped to gloat.",
    closest = "{boss} swung at whoever was closest.",
}

-- The speech, for a boss with no lines of their own.
M.GLOAT_LINES = {
    "Is that all? I was told you were dangerous.",
    "Look at you. Tired already, and I've barely started.",
    "Go home. Tell them who beat you. Tell them slowly.",
    "Every step you took to get here, I knew about.",
}

return M
