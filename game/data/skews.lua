-- Pulls and skews (the rebuild's second milestone, October 18): now and then a player pulls toward
-- something they care about, always a card, a place or a storyline in play, and the DM answers with
-- one of four calls. Data only: tune freely. The model is game/model/pulls.lua.
--
-- Placeholders: {name} the player, {Name} the same at the start of a sentence, {char} their hero,
-- {target} what they pull toward (lower case), {Target} the same capitalised, {story} the
-- storyline's short name, {tie} what ties it to this stop, {due} the session it's owed by.

return {
    -- How often a stop has a pull, and when not to.
    CHANCE_FIRST = 0.35,      -- the night's first stop (everyone's still settling in)
    CHANCE = 0.6,             -- any later stop
    ROOM = 13,                -- no pull once the night has had this many calls (a pull takes the stop's card's place)
    -- Who pulls: how readily each kind of player goes off the plan (a Casual rarely does).
    PROPENSITY = { instigator = 1.4, explorer = 1.3, method_actor = 1.15, storyteller = 1.1, butt_kicker = 0.8,
                   tactician = 0.75, power_gamer = 0.8, casual = 0.35 },
    -- How strongly each kind of target pulls.
    WEIGHT = { own = 3, theory = 2.6, story = 2.2, taste = 1.2, offmap = 0.7 },
    -- The answers' numbers.
    SLIP = 2,                 -- Follow it: this stop's final roll gets this much harder
    OWED_SESSIONS = 2,        -- Park it: play it within this many sessions
    RAILROAD_AT = 2,          -- Steer back this many times in a night and the table calls it railroading
    -- Who moved the story (the hidden share): what each counts.
    SHARE = { follow = 2, weave = 2, paid = 2, final_roll = 1, own_card = 1 },

    -- Why they pull, said on the card.
    WHY = {
        own = "It's {char}'s own story.",
        story = "{Story} has gone quiet, and {name} cares about it.",
        theory = "{Name} is sure of it: {claim}",
        taste = "It's what {name} comes to the table for: {taste}.",
        offmap = "Nobody's prepped it. {Name} just wants to see what's there.",
    },
    -- What they say at the table when they pull (out of character, to you and the table).
    SAY = {
        own = {
            "Wait. {Target}? That's {char}'s. We're going.",
            "Sorry, I can't let {target} go. Not this one.",
            "Can {char} slip off to {target}? It's kind of their whole thing.",
        },
        story = {
            "Hang on. What happened with {story}? Can we look at {target}?",
            "We never went back to {story}. {Target} is right there.",
            "I keep thinking about {story}. Can we check {target}?",
        },
        theory = {
            "I'm telling you, {target} is the key. Let me prove it.",
            "Can {char} test my theory? {Target}. Just a quick look.",
        },
        taste = {
            "Okay but {target} sounds amazing. Can we go?",
            "What if we went to {target} instead? I'm just saying.",
            "Is there a version of tonight with {target} in it?",
        },
        offmap = {
            "What's over there? Past the edge of the map. {Target}?",
            "Random idea: {target}. Is that a thing? Can it be a thing?",
        },
    },
    -- The card's four answers: the label, what it costs and what it gives.
    ANSWERS = {
        follow = { label = "Follow it", cost = "This stop's plan slips: its final roll gets 2 harder.",
                   cost_fight = "The plan slips: they're late to the fight, and the other side sees them first.",
                   gives = "{Name} shapes the story tonight." },
        weave = { label = "Weave it in", cost = "Ties in through {tie}.",
                  gives = "Both move: the plan holds, and {name} gets their moment too.",
                  none = "Nothing on this stop ties to it." },
        park = { label = "Park it", cost = "You owe {name}: play {target} by session {due}, or it sours.",
                 gives = "Nothing lost tonight." },
        steer = { label = "Steer back", cost = "A small dent in {name}'s buy-in. Twice tonight and the table calls it railroading.",
                  gives = "The plan holds." },
    },
    -- What happens at the table after each answer.
    AFTER = {
        follow = {
            "You go with it. {Char} leads the way to {target}, and the table leans in.",
            "You follow {name}'s lead. {Target} it is, for a while.",
        },
        weave = {
            "You fold it in: {target} turns out to be part of this, through {tie}.",
            "You tie it together. {Target} and the plan turn out to be the same story: {tie}.",
        },
        park = {
            "'Hold that thought. We'll get there,' you tell {name}. They write it down.",
            "You promise {name} {target}, just not tonight. They hold you to it.",
        },
        steer = {
            "You steer them back to the plan. {Name} lets it go, a little quieter.",
            "'Maybe later,' you say, and move on. {Name} shrugs.",
        },
    },
    -- Twice steered in one night.
    RAILROAD = {
        "{Name} sets down their dice. 'Are we on rails tonight?' Nobody laughs.",
        "'Is anything we do going to matter?' {name} asks. The table goes quiet.",
    },
    -- A parked pull played within its sessions: they remember you remembered.
    PAID = {
        "{Name} lights up. 'You remembered {target}!'",
        "'{Target}! You actually came back to it.' {Name} is grinning.",
    },
    -- Between sessions, in the group chat.
    REMIND = {
        "Still thinking about {target}. Just saying.",
        "Are we getting to {target} this week? Asking for {char}.",
    },
    SOUR = {
        "Guess we're never going back to {target}. Cool cool.",
        "So {target} was a dead end, huh.",
    },
    -- What a pull's answer does to the player and the table (meters, as elsewhere).
    EFFECTS = {
        follow = { { "actor", fun = 8, investment = 4, spotlight = 8 }, { "all", story = 2 } },
        weave = { { "actor", fun = 8, investment = 5, spotlight = 6 }, { "all", story = 5, fun = 2 } },
        park = { { "actor", fun = -1 } },
        steer = { { "actor", fun = -3, investment = -3, trust = -1 } },
        railroad = { { "all", trust = -2, fun = -2, story = -2 } },
        paid = { { "actor", fun = 8, investment = 4, trust = 3, spotlight = 6 } },
        sour = { trust = -4, investment = -6 },
    },
}
