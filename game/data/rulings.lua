-- Rulings after a big roll: the die sets the tier, the DM picks how generous to be.
-- A high roll opens generous choices; a low roll offers costly or complicated ones.
-- Data only: tune freely.
--
-- Tiers (by the reported result against the DC):
--   triumph  natural 20, or beat the DC by 5 or more
--   success  met the DC
--   near     missed by 1 to 4
--   flop     missed by 5 or more, or a natural 1
-- success = true means the roll's success branch plays; false plays the fail branch.
-- Effects use the same targets as decision cards ("actor", "all", "arch:...").

return {
    triumph = {
        prompt = "How good does it get?",
        options = {
            { label = "Yes, and... something extra goes their way.", success = true, tone = "good",
              log = "Better than they hoped. Something extra falls into their lap.",
              effects = { { "actor", spotlight = 8, fun = 4, reward = 4 }, { "all", story = 2 } } },
            { label = "Yes. Clean and simple.", success = true,
              log = "It works, cleanly.",
              effects = { { "actor", spotlight = 4 } } },
        },
    },
    success = {
        prompt = "Any strings attached?",
        options = {
            { label = "Yes. It works.", success = true,
              log = "It works.",
              effects = { { "actor", spotlight = 4 } } },
            { label = "Yes, but... it costs them something.", success = true, tone = "twist",
              log = "It works, but not for free. Something slips, breaks or gets noticed.",
              effects = { { "all", challenge = 4, story = 4 }, { "arch:storyteller", fun = 3 }, { "arch:casual", fun = -2 } } },
        },
    },
    near = {
        prompt = "How do you call it?",
        options = {
            { label = "No, but... they get something out of it.", success = false, tone = "good",
              log = "Not quite, but they learn something useful on the way down.",
              effects = { { "actor", fun = 3 }, { "all", story = 3 }, { "arch:casual", fun = 2 } } },
            { label = "Yes, at a cost. Close enough.", success = true, tone = "twist",
              log = "Close enough, if they're willing to pay for it. They are.",
              effects = { { "actor", spotlight = 4, fun = 2 }, { "all", challenge = 4 }, { "perceptive", suspicion = 1, why = "a miss that became a yes" } } },
            { label = "No. A miss is a miss.", success = false,
              log = "It doesn't happen.",
              effects = { { "arch:tactician", trust = 2 } } },
        },
    },
    flop = {
        prompt = "How bad does it get?",
        options = {
            { label = "No. It just doesn't work.", success = false,
              log = "It doesn't work.",
              effects = { { "arch:tactician", trust = 1 } } },
            { label = "No, and... things get worse.", success = false, tone = "bad",
              log = "It goes wrong, loudly. Now there's a new problem.",
              effects = { { "all", challenge = 8, story = 4 }, { "arch:butt_kicker", fun = 3 }, { "arch:instigator", fun = 4 },
                          { "arch:casual", fun = -3 } } },
        },
    },
}
