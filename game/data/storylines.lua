-- Storylines (the story playtest, Oct 12): the campaign runs several stories at once, and the
-- DM has to juggle them. Three major ones (Kessrick and the silent bells, the Velvet Hand's
-- debts, the restless dead under the chapel), a few minor ones, and every player's backstory.
-- A storyline opens the first time one of its cards plays at the table. Each night that a
-- scene plays one of its cards, it moves. Leave an open one alone too long and the table
-- notices: it's a loose end, and the players who cared lose a little Investment and Trust every
-- week it stays loose, down to a floor. Bring it back and they're surprised and glad, and what
-- they lost comes back. Touch too many in one night and the table loses the thread.
-- Data only: tune freely. The model is game/model/storylines.lua.
--
-- Each storyline:
--   name, short    what the DM's notes and the prep board call it
--   kind           "major", "minor" or (made for each player) "backstory"
--   about, gist    what it's about; gist is the same in a few words (the Story log at a glance;
--                  a backstory's gist is the player's, in game/data/players.lua)
--   cards          the story deck cards that move it (a card can move more than one: the
--                  Velvet Hand's back room is the bells' story, the Hand's, and Pip's)
--   people         people whose agenda cards (game/model/ledger.lua) move it
--   open           "start": open from the first session (the premise); nil: when a card plays
--   ends           cards that close it when their scene is won (a minor story resolved)
--   cold           weeks without moving before the table notices it's been dropped
--   color          its color on the prep board and in the notes
--   small_from     a small table (October 15): the session it comes into play. Before that its
--                  cards stay out of the hand and it stays out of the Story log, unless it opens
--                  anyway (one of its cards played). A hero's own story is in play while
--                  they're at the table.
--   noticed        what someone at the table says when they notice it's been dropped
--   back           what they say when it comes back after being dropped

return {
    ACTIVE_CAP = 4,          -- storylines one night can move before the table loses the thread
    OPEN_WARN = 6,           -- open storylines before prep warns you're carrying a lot
    MOMENTUM_SCENES = 2,     -- scenes in one night on the same storyline: it's all connecting

    -- A loose end erodes, a little a week, down to a floor (per storyline, per player). `who`
    -- is whose bars it wears down: the owner of a backstory; for a major, everyone (story fans
    -- twice as fast); for a minor, the story fans only.
    ERODE = {
        backstory = { investment = 2, trust = 1, floor_investment = 8, floor_trust = 5 },
        major = { investment = 1, trust = 0.5, floor_investment = 4, floor_trust = 2 },
        minor = { investment = 1, trust = 0, floor_investment = 3, floor_trust = 0 },
    },
    -- All the loose ends together never take more than this from one player.
    ERODE_TOTAL = { investment = 12, trust = 7 },
    STORY_FANS = { storyteller = true, explorer = true, method_actor = true },
    -- It comes back: the surprise (tonight's meters) and what they lost (given back in full).
    BACK = {
        backstory = { fun = 8, spotlight = 6, story = 6 },
        major = { fun = 3, story = 5 },
        minor = { fun = 2, story = 3 },
    },
    -- Spread thin: each storyline past the cap tonight.
    THIN = { story = -4, boredom = 3, fun = -2 },
    MOMENTUM = { story = 4, investment = 1 },
    THIN_LINES = {
        "Wait, sorry. Which plot is this? The bells, the Hand, or the ghosts?",
        "I've lost track of who wants what. Can someone draw me a diagram?",
        "Okay, that's a lot of threads. I'm writing them on my hand.",
        "Hang on. Is this connected to the other thing, or a new thing?",
    },
    MOMENTUM_LINES = {
        "Oh. Oh, it's all connected, isn't it.",
        "Okay, now it's coming together. I love this.",
        "Two scenes in a row on this. We're getting somewhere.",
    },

    order = { "bells", "velvet", "dead", "tobin", "wool_roads", "traitor", "spurs" },

    bells = {
        name = "The Silent Bells", short = "The bells", kind = "major", open = "start", cold = 2, color = "#c8a24a", small_from = 1,
        about = "Who hushed Millbrook's bells, and what Kessrick's warband does when they wake.",
        gist = "Someone hushed Millbrook's bells",
        cards = { "stranger", "wren", "forest_road", "hidden_map", "hush_holds", "riddle", "bell_tower", "wolf_lieutenant",
                  "cliffhanger", "vask_key", "wolves_watching", "grey_coat", "kessrick_trail", "muster_valley", "hales_crossing",
                  "hales_bell", "carry_relic", "key_for_sale", "velvet_den", "corin", "abbot_ghost", "follow_ilsa" },
        people = { "stranger", "wolf_lieutenant", "grey_coat" },
        noticed = { "So are the bells still a thing? We haven't been near the tower in ages.",
                    "Whatever happened to Kessrick? Big scary warlord, and then... nothing?" },
        back = { "The BELLS. We're back on the bells. Yes.", "Oh, I'd forgotten about Kessrick. That's not good, is it." },
    },
    velvet = {
        name = "The Velvet Hand's debts", short = "The Velvet Hand", kind = "major", cold = 2, color = "#b0506a", small_from = 2,
        about = "Madame Sable's guild is buying up every debt in Millbrook, and the Kettle is next.",
        gist = "The Velvet Hand is buying up Millbrook's debts",
        cards = { "madame_sable", "velvet_den", "collectors", "owe_more", "key_for_sale", "purse_lifted", "cutpurses",
                  "sable_job", "steal_ledger", "save_kettle", "debt_deal", "debt_cleared", "rooftops" },
        people = { "madame_sable", "cutpurses" },
        noticed = { "Did the Velvet Hand just... give up? They were everywhere for a bit.",
                    "Weren't we going to do something about Sable?" },
        back = { "Ugh, Sable. I missed her. Is that weird?", "The Hand's back. Of course the Hand's back." },
    },
    dead = {
        name = "The restless dead", short = "The dead", kind = "major", cold = 2, color = "#7a8ab0", small_from = 3,
        about = "Something under the roadside chapel wants its bell rung, and the dead won't stay put.",
        gist = "The dead under the chapel won't stay put",
        cards = { "crypt", "restless_dead", "dead_walk", "silence_crypt", "lay_to_rest", "shrine", "bone_choir",
                  "barrow", "explore_barrow", "restless_ghost" },
        people = { "hermit" },
        noticed = { "Are we ignoring the zombies now? Because the zombies aren't ignoring us.",
                    "What about the thing under the chapel? We just left it?" },
        back = { "The chapel thing! I KNEW that was coming back.", "Oh no, the dead. I'd honestly forgotten. Oh no." },
    },
    tobin = {
        name = "Where is Old Tobin?", short = "Old Tobin", kind = "minor", cold = 3, color = "#8aa060", small_from = 2,
        about = "The bell-ringer took the north road nine days before the campaign, and never came back.",
        gist = "Old Tobin, the bell-ringer, is missing",
        cards = { "wren", "find_tobin", "find_wren", "bell_paths", "map_thief", "torn_map", "torn_map_goal" },
        people = { "stranger" },
        ends = { "find_tobin" },
        noticed = { "Whatever happened to Old Tobin? Are we just leaving him out there?" },
        back = { "Tobin! Is he alive? Tell me he's alive." },
    },
    wool_roads = {
        name = "Bandits on the wool roads", short = "The wool roads", kind = "minor", cold = 3, color = "#a0784a", small_from = 4,
        about = "Carts go missing between Millbrook and the hill farms, and Captain Rook's bandits know why.",
        gist = "Rook's bandits are taking the wool carts",
        cards = { "merchant", "caravan", "toll", "rook", "ransom", "old_bridge", "trade_writ" },
        people = { "merchant", "rook" },
        ends = { "caravan" },
        noticed = { "Did Ottilie ever get her wool through? Nobody asked." },
        back = { "Ottilie! And the wool! Okay, I'm weirdly invested in the wool." },
    },
    traitor = {
        name = "Who's selling secrets?", short = "The traitor", kind = "minor", cold = 3, color = "#6a9a9a", small_from = 4,
        about = "Somebody in Millbrook is passing the party's business to whoever pays.",
        gist = "Someone is selling the party's secrets",
        cards = { "traitor", "traitor_warned", "traitor_ledger", "turncoat_guide", "turncoat" },
        ends = { "traitor" },
        noticed = { "We never found out who the traitor was. That's going to bite us." },
        back = { "The traitor! Okay, everyone's a suspect. Everyone." },
    },
    spurs = {
        name = "The Silver Spurs", short = "The Spurs", kind = "minor", cold = 3, color = "#9a9aa8", small_from = 4,
        about = "A rival party who want to be the valley's famous heroes, whatever it takes.",
        gist = "Rival heroes want the valley's glory",
        cards = { "rivals", "fair", "safe_conduct" },
        people = { "rivals" },
        ends = { "rivals", "safe_conduct" },
        noticed = { "What happened with the Silver Spurs? Did they win? Did they get a song?" },
        back = { "The SPURS. Oh, it's on now." },
    },

    -- Every player's backstory is a storyline too (made from their thread cards). A featured
    -- thread (the campaign planner) was a promise: the table notices sooner if it's dropped.
    backstory = {
        cold = 3, cold_featured = 2, color = "#e8b04a",
        noticed = {
            mara = "Are we ever going to look for Ilsa again? Thessaly hasn't forgotten, even if everyone else has.",
            dev = "Kessrick burned Brannoc's village. And we're doing errands. Cool. Cool cool cool.",
            jess = "So Pip's debt just... went away? Nobody's coming for her? Okay.",
            sam = "Oswin's still carrying that relic everywhere. Is it ever going to matter?",
        },
        back = {
            mara = "Wait. Is this about Ilsa? I thought we'd dropped that! I'm not crying, you're crying.",
            dev = "Kessrick. FINALLY. Brannoc has been waiting for this.",
            jess = "Oh no. Oh no, it's the Hand. Pip's going to have to deal with this, isn't she.",
            sam = "Is that the relic glowing? I thought it was just a paperweight now. Oh, wow.",
        },
        other_noticed = "Whatever happened to {char}'s thing? We kind of dropped it.",
        other_back = "Oh, {char}'s story is back! About time.",
    },
}
