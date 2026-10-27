-- What your friends say while you set up and prep (October 26: "give them some sort of thought
-- bubble or dialogue to help the player steer decisions"). Data only: tune freely. Shown in
-- bubbles over their heads by game/ui/steps.lua; setting up reads the first half
-- (game/ui/setup_view.lua), the week's prep the second (game/ui/prep_view.lua). (Not the table
-- talk on game night: that's game/data/dialogue/.)
--
-- Placeholders: {style} {front} {type} {card} {week} {char}.
-- like: how they feel about it, -2..2 (the bubble's edge, and the pose they strike).
--
-- Mara (Thessaly, wizard): mysteries, big reveals, takes notes; her sister Ilsa.
-- Dev (Brannoc, fighter): fights and cool weapons; Kessrick burned his village.
-- Jess (Pip, rogue): voices, chaos, every NPC; owes the Velvet Hand.
-- Sam (Oswin, cleric): friends and snacks, fair clever fights, not the spotlight; the relic.

return {
    -- Setting up: out of character, around the table -----------------------------------------------

    -- Who's at the table: playing from session 1, or joining later.
    table = {
        start = {
            mara = "Thursday's blocked out. I've already started a notebook.",
            dev = "I'm in. When do we fight something?",
            jess = "Pip is READY. I've been practising the voice in the car.",
            sam = "Count me in. I'll bring the good crisps.",
        },
        later = {
            mara = "I'll catch up from session {week}. Send me the notes?",
            dev = "Start without me, I'll jump in at session {week}.",
            jess = "Can't make the first one! Session {week}, I promise. Save Pip a seat.",
            sam = "I'll join in session {week}. Easier to learn it when I'm watching first, honestly.",
        },
    },

    -- Where most nights happen: how each of them feels about the style (styles.fit).
    style = {
        keen = {
            mara = "{style}? Somewhere with secrets. Yes.",
            dev = "{style} sounds like it's got stuff to fight. Good.",
            jess = "Ooh, {style}. Pip already has three contacts there.",
            sam = "{style}'s nice. I like knowing where home is.",
        },
        meh = {
            mara = "{style} could work, if the story's good.",
            dev = "Sure, {style}. As long as there are fights.",
            jess = "{style}! Fine! Pip can be anywhere.",
            sam = "{style} is fine with me.",
        },
        unsure = {
            mara = "Hmm. {style} doesn't sound like many mysteries.",
            dev = "{style}? Sounds like a lot of walking and talking.",
            jess = "{style}... is there anyone to talk to?",
            sam = "{style} sounds a bit stressful, to be honest.",
        },
    },

    -- Three truths about the world: what each of them hopes it has.
    truths = {
        mara = "Give me a world with old secrets in it. Things people have forgotten on purpose.",
        dev = "Wolves. Graves. Anything with teeth.",
        jess = "Thieves! Debts! A town where everybody owes somebody.",
        sam = "Somewhere that feels lived in. Markets and weather and people.",
    },

    -- The second threat: each of them, on each front.
    fronts = {
        velvet_hand = {
            like = { mara = 1, dev = 0, jess = 2, sam = -1 },
            mara = "A guild of polite thieves. They'll know things.",
            dev = "Thieves. Can I punch a thief?",
            jess = "Oh no. Oh NO. Pip owes them SO much money.",
            sam = "Debt collectors in a nice coat. That's scarier than wolves.",
        },
        under_chapel = {
            like = { mara = 2, dev = 2, jess = -1, sam = 1 },
            mara = "Something under the chapel. That's a mystery with a door on it.",
            dev = "Restless dead? Undead fights are the best fights.",
            jess = "Ghosts! Pip is NOT going in first.",
            sam = "Oswin knows a thing or two about the dead. I'm in.",
        },
        other = {
            like = { mara = 1, dev = 1, jess = 1, sam = 0 },
            mara = "{front}. I want to know why.",
            dev = "{front}? Good. Something to stop.",
            jess = "{front}! Pip has opinions.",
            sam = "{front}. Sounds like we'll need a plan.",
        },
    },

    -- Your dice.
    dice = {
        like = { mara = 1, dev = 1, jess = 2, sam = 1 },
        mara = "Pretty. Do the DM's dice ever roll in our favour?",
        dev = "Those look like they roll high. For the monsters. Great.",
        jess = "Can I touch them? I won't touch them. Can I touch them?",
        sam = "Nice dice. Ours are grey, for the record.",
    },

    -- Whose stories come first: each of them, making their case.
    featured = {
        mara = "Ilsa's been missing two months. Thessaly can't wait much longer.",
        dev = "Kessrick's out there. Brannoc wants him found.",
        jess = "The Velvet Hand will come for Pip anyway. Might as well be soon.",
        sam = "Honestly, someone else can go first. Oswin's relic is safe for now.",
    },

    -- On the summary, ready to start.
    ready = {
        mara = "I've got a page of notes already. Let's go.",
        dev = "Roll initiative?",
        jess = "Pip is going to steal SO many things.",
        sam = "Snacks are out. Ready when you are.",
    },

    -- Waiting for you to choose (no option picked yet).
    waiting = {
        mara = "Take your time. This is the important part.",
        dev = "Whatever's quickest to a fight.",
        jess = "Ooh, choices.",
        sam = "No rush.",
    },

    -- The week's prep: in character, what's on each hero's mind ------------------------------------

    -- Their own story, by how warm it is (game/model/storylines.lua's heat).
    mind = {
        unopened = {
            mara = "Ilsa's out there somewhere. Nobody's started looking yet.",
            dev = "Kessrick's trail. We haven't even found it.",
            jess = "The Velvet Hand hasn't come knocking. Yet.",
            sam = "The relic's safe. Quiet. That's how I like it.",
        },
        warm = {
            mara = "Ilsa's trail is warm. I can feel it.",
            dev = "We're getting closer to Kessrick. Good.",
            jess = "The Hand knows I'm here. Things are moving.",
            sam = "The relic's story is moving. I'm paying attention.",
        },
        cooling = {
            mara = "We haven't looked for Ilsa in a while.",
            dev = "Kessrick's trail is going cold.",
            jess = "Quiet from the Hand. Too quiet.",
            sam = "Haven't thought about the relic in a bit. That's fine. Probably.",
        },
        cold = {
            mara = "Is anyone still looking for my sister?",
            dev = "Does anyone else remember Kessrick burned my village?",
            jess = "Did everyone forget Pip has a debt? Pip didn't.",
            sam = "I keep waiting for the relic to matter.",
        },
        loose = {
            mara = "We left Ilsa's story hanging. It's bothering me.",
            dev = "We let Kessrick's trail drop. I hate that.",
            jess = "That thing with the Hand is still out there, unfinished.",
            sam = "We never finished what we started with the relic.",
        },
        resolved = {
            mara = "Ilsa's story is told. I'm still thinking about it.",
            dev = "Kessrick's done. What's next?",
            jess = "Pip's debt is settled. Pip is free! Mostly.",
            sam = "The relic's at rest. Good.",
        },
    },

    -- What they say about a kind of scene (their loves and bores, prep:forecast's leans).
    types = {
        love = {
            mara = "A {type}? That's my favourite kind of night.",
            dev = "{type}! Yes. Now we're talking.",
            jess = "A {type}! Pip lives for this.",
            sam = "A {type}. Oh, that sounds fun.",
        },
        like = {
            mara = "A {type} could be good.",
            dev = "A {type}'s alright.",
            jess = "Ooh, a {type}.",
            sam = "A {type}, sure.",
        },
        meh = {
            mara = "A {type}. Okay.",
            dev = "A {type}. Fine.",
            jess = "A {type}? I'll find something to do.",
            sam = "A {type} works.",
        },
        bored = {
            mara = "Another {type}? I'll bring a book.",
            dev = "A {type}. I'll be on my phone.",
            jess = "A {type}... can Pip at least talk to someone?",
            sam = "A {type}. I'll be quiet for that one.",
        },
    },

    -- What they say about a card on a stop (who'd love it, who'd be bored).
    cards = {
        love = {
            mara = "{card}? I need to know more.",
            dev = "{card}. Good.",
            jess = "{card}! Pip is SO into this.",
            sam = "{card}. Nice.",
        },
        bored = {
            mara = "{card}. Not really my thing.",
            dev = "{card}? Where's the fight?",
            jess = "{card}. Hmm.",
            sam = "{card}. Eh.",
        },
        -- Before you pick: the card in your hand they're hoping for (a thought).
        hope = {
            mara = "Ooh, {card}. Please.",
            dev = "{card}. Pick that one.",
            jess = "Pip votes {card}!",
            sam = "{card} would be nice.",
        },
    },

    -- Who this session is for.
    spotlight = {
        mine = {
            mara = "Tonight's about Ilsa? Thank you.",
            dev = "Brannoc's night. Kessrick, here we come.",
            jess = "A Pip episode! I've been WAITING.",
            sam = "Oh, it's about Oswin? Okay. Okay. I can do this.",
        },
        other = {
            mara = "Fair. It's {char}'s turn.",
            dev = "{char}'s night. I'll hit things in the background.",
            jess = "{char}'s night! Pip will help. Loudly.",
            sam = "Good, {char} can have the spotlight.",
        },
    },

    -- On the last step, by the forecast for Thursday (score.tier): what they expect, in character.
    forecast = {
        loved = {
            mara = "Thursday's going to be something. I can feel it.",
            dev = "Big night. I'm sharpening the greatsword.",
            jess = "Pip has a FEELING about Thursday.",
            sam = "This one sounds fun. I'll bring extra snacks.",
        },
        fun = {
            mara = "A good night ahead, I think.",
            dev = "Should be a decent night.",
            jess = "Ooh, a fun one.",
            sam = "Sounds nice.",
        },
        fine = {
            mara = "It'll be fine. I hope there's something for Thessaly.",
            dev = "Fine. As long as something gets hit.",
            jess = "It's... fine? Pip will make it fun.",
            sam = "Should be fine.",
        },
        bored = {
            mara = "Not much for me this time. I'll take notes anyway.",
            dev = "Hmm. Not much for Brannoc to do.",
            jess = "Is there anyone for Pip to talk to?",
            sam = "I might be a bit quiet on Thursday.",
        },
        out = {
            mara = "Honestly? I'm not feeling this one.",
            dev = "I might be on my phone for this one.",
            jess = "Pip is... not excited.",
            sam = "I don't know about this week.",
        },
    },

    -- Levelling up.
    levelup = {
        mara = "A new spell! I've had my eye on one for weeks.",
        dev = "More hit points means more hitting.",
        jess = "Pip gets sneakier? Pip gets SNEAKIER.",
        sam = "Ooh, does Oswin heal more now?",
    },

    -- A seed you might plant, for whoever it's aimed at (its fans).
    seed = {
        mara = "A mystery for later? Yes please.",
        dev = "Something to come back and fight later. Good.",
        jess = "Ooh, a secret. Pip loves a secret.",
        sam = "A slow one. I like those.",
    },
}
