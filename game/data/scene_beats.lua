-- The beats of a non-combat scene on game night: how each quick check lands
-- (a small step forward or a setback on the scene's progress track), and the DM's
-- captions in fights. What the heroes say lives in the dialogue library
-- (game/data/dialogue/). Data only: tune freely.
--
-- Fill-ins: {char} the acting hero, {other_char} another hero, {cast}, {location}, {goal}.

return {
    -- Progress track: successes needed before the scene's big moment, and how many
    -- setbacks the table can take before it gets harder.
    track = { social = 4, exploration = 4, puzzle = 4, mystery = 4, downtime = 3 },
    setbacks = 3,

    win = {
        social = { "{Cast} {leans|lean} in. That landed.", "A laugh from {cast}. The ice is breaking.",
                   "{Cast} {lets|let} something slip: {lead}. Useful.", "Nods around the room. People are listening now." },
        exploration = { "A way forward opens up.", "They find a dry passage nobody's used in years.",
                        "Footprints. Fresh ones. This is the right way.", "A hidden ledge, just wide enough." },
        puzzle = { "One piece clicks into place.", "Something in the walls shifts. Good sign.",
                   "A symbol lights up. Then another.", "They're onto something. Everyone can feel it." },
        mystery = { "A clue that doesn't fit. Which means it does.", "Somebody's story just fell apart.",
                    "The timeline is starting to make sense.", "A name keeps coming up. Interesting." },
        downtime = { "The whole room is enjoying this.", "A round of applause from the next table.",
                     "Someone buys them a drink.", "Gus actually smiles. Briefly." },
    },
    lose = {
        social = { "{Cast} {narrows|narrow} their eyes.", "Wrong thing to say. The room goes chilly.",
                   "{Cast} {changes|change} the subject. Fast.", "A guard by the door starts paying attention." },
        exploration = { "Dead end. Back the way they came.", "The floor creaks ominously. Everyone freezes.",
                        "They get turned around in the dark.", "Something skitters away in the shadows." },
        puzzle = { "A grinding noise. That wasn't good.", "Wrong lever. Dust falls from the ceiling.",
                   "The symbols go dark again.", "Back to square one on that bit." },
        mystery = { "A red herring. A very convincing one.", "{Witness} clams up.",
                    "The evidence points somewhere awkward.", "Somebody saw them snooping." },
        downtime = { "That went sideways. Hilariously.", "Gus sighs the sigh of a tired man.",
                     "A chair breaks. Not their fault. Mostly.", "Someone is now banned from the dartboard." },
    },

    -- Halfway through a scene, one moment worth a paused roll ({complication} when one is written).
    moment = {
        social = { text = "{actor_char} has to win over the room before it turns.", dc = 12,
                   skill = { "persuasion", "performance", "intimidation" },
                   success = { log = "The room relaxes. Someone even laughs.", effects = { { "actor", spotlight = 8 }, { "all", social = 4 } } },
                   fail = { log = "Arms fold across the room. This just got harder.", effects = { { "all", challenge = 5 } } } },
        exploration = { text = "{actor_char} has to get everyone across the worst stretch.", dc = 12,
                        skill = { "athletics", "survival", "acrobatics" },
                        success = { log = "Hand over hand, everyone makes it.", effects = { { "actor", spotlight = 8 }, { "arch:explorer", fun = 3 } } },
                        fail = { log = "Someone slips. Scrapes, bruises, a lost torch.", effects = { { "all", challenge = 6 } } } },
        puzzle = { text = "{actor_char} spots a pattern and has to test it, fast.", dc = 13,
                   skill = { "investigation", "arcana" },
                   success = { log = "The pattern holds. Half the riddle falls away.", effects = { { "actor", spotlight = 8 }, { "arch:tactician", fun = 4 } } },
                   fail = { log = "The pattern breaks. Something clicks ominously.", effects = { { "all", challenge = 6 } } } },
        mystery = { text = "{actor_char} catches {witness} in a lie and pushes.", dc = 12,
                    skill = { "insight", "intimidation", "investigation" },
                    success = { log = "The story from {witness} falls apart. A name comes out: {lead}.", effects = { { "actor", spotlight = 8 }, { "arch:storyteller", story = 4 } } },
                    fail = { log = "The lie holds, and the trail goes cold with {witness}.", effects = { { "all", story = 3, challenge = 3 } } } },
        downtime = { text = "{actor_char} gets dared into something very silly.", dc = 11,
                     skill = { "performance", "acrobatics", "athletics" },
                     success = { log = "They pull it off. Legendary.", effects = { { "actor", spotlight = 8, fun = 3 }, { "all", social = 4 } } },
                     fail = { log = "It goes wrong in the funniest possible way.", effects = { { "all", social = 4 }, { "actor", fun = 1 } } } },
        complication = { text = "{actor_char} tries to handle it: {complication}.", dc = 13,
                         skill = { "athletics", "acrobatics", "insight" },   -- unless the complication names its own
                         success = { log = "Handled. Barely, but handled.", big = "Handled, and handsomely.", effects = { { "actor", spotlight = 8 }, { "all", challenge = 3 } } },
                         fail = { log = "It gets away from them. The scene just got harder.", effects = { { "all", challenge = 7, story = 2 } } } },
    },

    -- The bridge at the end of every scene but the last (A2): what they got, and where they
    -- go next. {got}/{Got} what they won, {next} the next scene's place (or its goal), {here}.
    -- Between scenes. got: a reward they carry off; goal: what they did ("the relic, still safe");
    -- won/lost: neither. The _here sets are for when the next place isn't settled yet (the DM
    -- will make it up), so the line doesn't promise somewhere it can't name.
    bridge = {
        got = { "They walk away with {got}. Next: {next}.", "With {got} in hand, they make for {next}." },
        goal = { "They come away with {got}, and on to {next}.", "{Got}. Next stop: {next}." },
        won = { "Done at {here}. Next: {next}.", "That's {here} settled. On to {next}.",
                "They leave {here} better than they found it. Next: {next}." },
        lost = { "They come away from {here} with nothing but bruises. Next: {next}.", "Empty-handed, they head for {next}.",
                 "Not their night at {here}. On to {next}." },
        got_here = { "They walk away from {here} with {got}.", "With {got} in hand, they leave {here} behind." },
        goal_here = { "They come away from {here} with {got}.", "They leave {here} behind with {got}." },
        won_here = { "That's {here} settled.", "They leave {here} better than they found it." },
        lost_here = { "They come away from {here} with nothing but bruises.", "Not their night at {here}." },
    },

    -- The heroes talking to each other, in character, between checks.
    -- The DM narrating fights (captions, not character dialogue). {tgt}, {round}.
    fight_captions = {
        start = { "Roll initiative!", "Weapons out. Here we go.", "Everyone grab a d20." },
        round = { "Round {round}.", "Top of round {round}." },
        flee = { "{tgt} breaks and runs.", "{tgt} bolts for the trees." },
        party_win = { "The last one falls. Silence, then cheering.", "It's over. Everyone breathes out." },
        party_win_fled = { "The rest scatter and don't look back. The fight is theirs.",
                           "And they're gone, running hard. Nobody's chasing them. It's over." },
        party_win_surrender = { "Weapons down, hands up. It's over, and nobody else gets hurt.",
                                "They give up. The fight is theirs, and everyone's still breathing." },
        party_lose = { "The party falls, one by one.", "Everything goes dark." },
    },
}
