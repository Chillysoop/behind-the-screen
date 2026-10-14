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
-- lines: what the table hears, one picked at random (else log). Playtest, October 13: "Yes, and"
-- and "Yes, but" read as doing nothing, because the extra and the cost were never named.

return {
    triumph = {
        prompt = "How good does it get?",
        options = {
            { label = "Yes, and... something extra goes their way.", success = true, tone = "good",
              log = "Better than they hoped. Something extra falls into their lap.",
              lines = { "Better than they hoped: a few silver coins, tucked where nobody looked.",
                        "Better than they hoped: they spot a shortcut, and save themselves an hour.",
                        "Better than they hoped: they overhear a name that matters later.",
                        "Better than they hoped: whoever was watching is impressed, and says so.",
                        "Better than they hoped: a spare healing potion, forgotten on a shelf." },
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
              lines = { "It works, but it costs them: the noise carries, and someone is coming to look.",
                        "It works, but it costs them: a strap snaps, and half a pack of supplies goes with it.",
                        "It works, but it costs them: a nasty scrape that'll ache for the rest of the night.",
                        "It works, but it costs them: they leave a trail anyone could follow.",
                        "It works, but it costs them: the torch goes out, and the dark gets closer." },
              effects = { { "all", challenge = 4, story = 4 }, { "arch:storyteller", fun = 3 }, { "arch:casual", fun = -2 } } },
        },
    },
    near = {
        prompt = "How do you call it?",
        options = {
            { label = "No, but... they get something out of it.", success = false, tone = "good",
              log = "Not quite, but they learn something useful on the way down.",
              lines = { "Not quite, but on the way down they learn which way not to go.",
                        "Not quite, but they see enough to know what they're up against.",
                        "Not quite, but the failure tells them something: this was meant to be hard." },
              effects = { { "actor", fun = 3 }, { "all", story = 3 }, { "arch:casual", fun = 2 } } },
            { label = "Yes, at a cost. Close enough.", success = true, tone = "twist",
              log = "Close enough, if they're willing to pay for it. They are.",
              lines = { "Close enough, and they pay for it: a bruise, a bent buckle, and a lot of noise.",
                        "Close enough, and they pay for it: it takes everything they had left for the scene.",
                        "Close enough, and they pay for it: they make it, but somebody saw." },
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
              lines = { "It goes wrong, loudly: a shout from somewhere close. Now there's a new problem.",
                        "It goes wrong, loudly: something gives way under them. Now there's a new problem.",
                        "It goes wrong, loudly: whatever they were trying to keep quiet isn't any more." },
              effects = { { "all", challenge = 8, story = 4 }, { "arch:butt_kicker", fun = 3 }, { "arch:instigator", fun = 4 },
                          { "arch:casual", fun = -3 } } },
        },
    },
}
