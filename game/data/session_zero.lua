-- Session Zero (M6): the talk before week 1. The DM pitches a tone, hears each
-- player's ask (a line, a veil or a promise) and sets the table rules. Data only:
-- tune freely. The model is game/model/social.lua.
--
-- like:   how each player feels about an option, -2..2. It moves their Trust and
--         Investment when the table settles, and it's shown at the table: at
--         Session Zero people tell you what they think.
-- says:   what they say when the option comes up (shown on the Session Zero screen).
-- pressure: starting pressure on a table conflict (game/data/conflicts.lua).

local S0 = {
    -- The pitch: what the campaign should feel like.
    tones = {
        order = { "mixed", "heroic", "grim", "silly" },
        mixed = {
            name = "Serious story, silly downtime",
            blurb = "The big arcs land hard. The tavern nights stay goofy.",
            like = { mara = 1, dev = 0, jess = 1, sam = 1 },
            says = {
                mara = "As long as Ilsa's story gets taken seriously, I'm in.",
                dev = "Sure. Do we fight in both halves?",
                jess = "Goofy tavern nights? Pip is thriving already.",
                sam = "Best of both. Snacks in the silly parts.",
            },
            pressure = { tone = 10 },
        },
        heroic = {
            name = "Warm and heroic",
            blurb = "Found family, big damn heroes, and the good guys win in the end.",
            like = { mara = 0, dev = 1, jess = 1, sam = 2 },
            says = {
                mara = "Fine, but I want real stakes for Ilsa.",
                dev = "Heroes win. I like heroes winning.",
                jess = "Found family! Pip adopts everyone.",
                sam = "Yes. This is exactly what I want on a Thursday.",
            },
            pressure = { tone = 18 },
        },
        grim = {
            name = "Dark and dangerous",
            blurb = "Real stakes. Not everyone makes it home.",
            like = { mara = 2, dev = 1, jess = -1, sam = -2 },
            says = {
                mara = "Yes. Ilsa's story should hurt a little.",
                dev = "Dangerous fights? I'm listening.",
                jess = "Can Pip at least be funny while everyone's sad?",
                sam = "I come here to unwind, not to get stressed out.",
            },
            pressure = { tone = 34 },
        },
        silly = {
            name = "Loose and silly",
            blurb = "Pratfalls, puns, and goblins in hats.",
            like = { mara = -2, dev = 0, jess = 2, sam = 1 },
            says = {
                mara = "Then nobody's going to care what happened to Ilsa.",
                dev = "Goblins in hats still count as fights, right?",
                jess = "GOBLINS IN HATS.",
                sam = "Low stress. I can do low stress.",
            },
            pressure = { tone = 34 },
        },
    },

    -- What each player asks for. kind: "line" (it never happens), "veil" (it happens off
    -- screen) or "promise" (how you'll run something). content: the card tag it covers.
    asks = {
        order = { "mara", "sam", "dev", "jess" },
        mara = {
            kind = "line", content = "kids",
            text = "Nothing bad happens to kids. Not on screen, not off it.",
            agree = { label = "Agreed. That's a line.", reply = "Thank you. That one matters to me.", like = 2 },
            push = { label = "Can it happen off screen?", reply = "I'd really rather it didn't. But okay.", like = -2 },
        },
        sam = {
            kind = "veil", content = "spiders",
            text = "Spiders can exist. I just don't want them described. Fade to black?",
            agree = { label = "Spiders stay off screen.", reply = "Amazing. I'll stop worrying about every cave.", like = 2 },
            push = { label = "Let's see how it goes.", reply = "Oh. Okay. I'll just brace myself, I guess.", like = -2 },
        },
        dev = {
            kind = "promise", promise = "open_death",
            text = "If Brannoc is going to die, roll it where I can see it. Don't save me behind the screen.",
            agree = { label = "Deal. Deaths happen in the open.", reply = "Good. If he goes, he goes out swinging.", like = 1 },
            push = { label = "I'd like to keep that option.", reply = "Then I'll never know if I really made it.", like = -1 },
        },
        jess = {
            kind = "promise", promise = "no_cut",
            text = "Let Pip talk to people. Don't cut my NPC chats short just to get to the fight.",
            agree = { label = "I won't cut your scenes short.", reply = "YES. Pip has so many questions for every innkeeper.", like = 2,
                      pressure = { spotlight = 12 } },
            push = { label = "I'll keep scenes moving, but you'll get yours.", reply = "Fair. As long as I get some.", like = 0 },
        },
    },

    -- The table rules.
    rules = {
        order = { "xcard", "dice", "rulings", "length", "death" },
        xcard = {
            name = "The X-card",
            about = "Anyone can tap it to skip something, no questions asked.",
            order = { "on", "off" },
            on = { name = "Use it", like = { mara = 1, dev = -1, jess = 0, sam = 2 },
                   says = { sam = "Love that. I probably won't need it, but still.", dev = "We're not going to use that, but okay." } },
            off = { name = "Skip it", like = { mara = 0, dev = 0, jess = 0, sam = -1 },
                    says = { sam = "Oh. Okay. I'll just say something if I need to." } },
        },
        dice = {
            name = "Your screen",
            about = "Behind your screen: your rolls, and the DCs (the number to beat).",
            order = { "big_open", "open", "screen" },
            big_open = { name = "Big moments in the open", like = { mara = 1, dev = 1, jess = 0, sam = 1 },
                         says = { dev = "Crits and deaths where I can see them. Good." } },
            open = { name = "Everything in the open", like = { mara = -1, dev = 1, jess = 0, sam = 2 },
                     says = { sam = "No secrets. I like it.", mara = "Doesn't that kill the suspense?" } },
            screen = { name = "Behind the screen, trust me", like = { mara = 2, dev = -1, jess = 1, sam = -1 },
                       says = { mara = "Keep the mystery. I trust you.", dev = "So you could just... decide things?" } },
        },
        rulings = {
            name = "Rules calls",
            about = "What happens when nobody's sure how a rule works.",
            order = { "quick", "book", "cool" },
            quick = { name = "Quick call now, look it up after", like = { mara = 1, dev = 0, jess = 0, sam = 1 },
                      says = { sam = "As long as you actually look it up after.", dev = "Fine by me." },
                      pressure = { rules = 12 } },
            book = { name = "By the book", like = { mara = 0, dev = -2, jess = -1, sam = 2 },
                     says = { sam = "Same rules every time. Perfect.", dev = "So no suplexes. Great." },
                     pressure = { rules = 24 } },
            cool = { name = "Rule of cool", like = { mara = 0, dev = 2, jess = 1, sam = -2 },
                     says = { dev = "RULE OF COOL.", sam = "So the rules are... whatever's cool? Okay." },
                     pressure = { rules = 26 } },
        },
        -- How long a night runs (A14): the table clock's planned end. Encounters still run long or short.
        length = {
            name = "How long we play",
            about = "When Thursday ends. Fights and talks can still run long or short.",
            order = { "three", "half", "four" },
            three = { name = "7 to 10", hours = 3, like = { mara = 0, dev = -1, jess = 0, sam = 2 },
                      says = { sam = "Perfect. I've got work on Friday.", dev = "Three hours? That's one fight." } },
            half = { name = "7 to 10:30", hours = 3.5, like = { mara = 1, dev = 0, jess = 1, sam = 0 },
                     says = { mara = "Room for a proper scene or three." } },
            four = { name = "7 to 11", hours = 4, like = { mara = 1, dev = 2, jess = 1, sam = -2 },
                     says = { dev = "Now we're talking.", sam = "I'll be useless after ten. Just saying." } },
        },
    },

    -- When Session Zero is skipped (headless runs): the middle of the road on everything.
    -- (rules.death is filled in from game/data/death.lua below.)
    defaults = {
        tone = "mixed",
        asks = { mara = "agree", sam = "agree", dev = "agree", jess = "push" },
        rules = { xcard = "on", dice = "big_open", rulings = "quick", length = "half", death = "meaningful" },
    },
}

-- When a hero dies (M8, B3): the table's default, from game/data/death.lua.
do
    local death = require "game.data.death"
    local r = { name = death.RULE.name, about = "Each player can still ask for their own.",
                order = death.MODES, compact = true }
    for _, m in ipairs(death.MODES) do
        r[m] = { name = death.MODE[m].button or death.MODE[m].short, about = death.MODE[m].about, like = death.RULE[m].like,
                 says = death.RULE[m].says }
    end
    S0.rules.death = r
end

return S0
