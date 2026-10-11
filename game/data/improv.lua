-- Improvisation: stock moves you can always reach for, and the ways the
-- party wanders off your plan. Data only: tune freely.

return {
    -- Always in the improv deck. They fit anywhere they make sense (where = the settings a
    -- location needs, as on scene cards), but never perfectly.
    stock = {
        { id = "storm_move", where = { "outdoor" }, name = "A storm rolls in", tags = { "chaos" }, meters = { challenge = 4 },
          line = "Thunder rolls overhead. Everyone has to shout now." },
        { id = "messenger", name = "A messenger arrives", tags = { "lore" }, meters = { story = 5 },
          line = "A breathless messenger finds them with news nobody wanted." },
        { id = "wolf_howl", name = "Wolves howl, close by", where = { "wild", "outdoor" }, tags = { "danger" },
          meters = { challenge = 4 },
          line = "A howl, then another, closer. Kessrick's wolves are hunting tonight." },
        { id = "lamps_out", name = "The lights go out", where = { "indoor", "under" }, tags = { "danger", "mystery" },
          meters = { challenge = 3, story = 2 },
          line = "Every lamp in the room gutters out at once. Somebody breathes in the dark." },
        { id = "floor_move", where = { "indoor", "ruin", "under", "bridge", "high" }, name = "The floor gives way", tags = { "danger" }, meters = { challenge = 5 },
          line = "Crack. The floor decides it has had enough." },
        { id = "old_friend", where = { "town", "crowd" }, name = "An old friend appears", tags = { "heart" }, meters = { social = 5 },
          line = "A familiar face pushes through the crowd, grinning." },
        { id = "rival_first", name = "A rival got there first", tags = { "chaos", "funny" }, meters = { challenge = 3, social = 2 },
          line = "The Silver Spurs are already here, posing." },
        { id = "bar_fight", where = { "tavern" }, name = "Someone starts a bar fight", tags = { "action", "funny" }, meters = { challenge = 4, social = 2 },
          line = "A chair flies. Then another. Then everyone joins in." },
        { id = "strange_light", where = { "outdoor" }, name = "A strange light in the distance", tags = { "mystery", "explore" }, meters = { story = 4 },
          line = "A green light flickers on the hill. It wasn't there before." },
        { id = "wrong_map", where = { "wild", "outdoor" }, name = "The map was wrong", tags = { "explore", "chaos" }, meters = { story = 3, challenge = 2 },
          line = "The map says there should be a bridge here. There is not." },
    },

    -- What happens when an empty slot comes up at the table.
    sketched = {
        location = "You never decided where this happens. Everyone is looking at you.",
        cast = "They want to talk to someone. You haven't written anyone.",
        goal = "'So... what are we doing here?' asks {lowest}.",
        complication = "It's going too smoothly. You need a twist, now.",
        reward = "They won. What do they get? You never wrote that down.",
    },

    -- The party goes off-script.
    drift = {
        "{actor_char} ignores the hook completely and heads for the mill instead.",
        "{actor_char} decides the real adventure is following that suspicious cat.",
        "{actor_char} wants to know what's behind the door you described as boring.",
        "{actor_char} befriends the first enemy and asks for a tour of their hideout.",
        "{actor_char} asks the bartender's name, then their life story. You have neither.",
    },

    -- How an improvised bit lands. great and good are your own asides (the log only); poor
    -- is what the table sees. Each night uses each line once before repeating.
    outcomes = {
        great = { "Nice save. Nobody can tell you made that up.", "Smooth. That sounded planned.",
                  "That fit like it was in your notes all along." },
        good = { "It holds together. Mostly.", "Good enough. Nobody's asking questions.",
                 "It'll do. The table rolls with it." },
        poor = { "{critic} squints. That didn't quite fit.", "{critic} tilts their head. Hm.",
                 "{critic} opens their mouth, then decides to let it go.", "A beat of silence from {critic}. Close enough?" },
    },
}
