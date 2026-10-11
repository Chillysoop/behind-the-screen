-- DM conversations (M6): private messages with one player, and posts to the
-- whole group chat. Data only: tune freely. The model is game/model/convo.lua;
-- game/model/social.lua decides which ones are open each week.
--
-- with:     a player key, or "group" for a post to the group chat.
-- opener:   "player" (they messaged you; replying is free) or "dm" (you start it;
--           it costs prep time, like any other prep).
-- says:     their first message, for player-opened chats.
-- title, about: how a conversation you start shows in your messages ({topic} works).
-- options:  what you can send. Each has:
--   label     your message
--   reply     their answer (a player chat), or replies = { { who, text }, ... } (group:
--             only people who are around reply)
--   effects   { key | "all" = { bar = change } } on Commitment, Investment, Trust, Suspicion
--   pressure  change to this conversation's conflict
--   resolve   settles the conflict this way (see conflicts.lua fixes)
--   unlock    opens another conversation (a group post you offered)
--   promise   "look_it_up": you owe the table a ruling next week
--   tone      re-sets the campaign's tone (Session Zero, revisited)
--   check     { who, bar, at }: the reply depends on how they feel about you;
--             below `at` the `fail` table (reply, effects, next...) plays instead
--   next      a node in `nodes` to continue with
-- {topic} is the rules question everyone's arguing about.

return {
    -- The Pip show ---------------------------------------------------------------------

    spotlight_sam = {
        with = "sam", conflict = "spotlight", opener = "player", stage = "brewing",
        title = "Sam",
        says = "hey, quick q. is it just me or did jess kind of run the whole night again",
        options = {
            { label = "Not just you. I'm on it.",
              reply = "ok good. didn't want to make it a thing",
              effects = { sam = { trust = 3 } } },
            { label = "What would help you get more in?",
              reply = "maybe just ask what oswin's doing sometimes? i never know when to jump in",
              effects = { sam = { trust = 4, investment = 2 } } },
            { label = "She's just having fun!",
              reply = "yeah. sure. ok",
              effects = { sam = { trust = -3, commitment = -1 } }, pressure = 6 },
        },
    },

    spotlight_mara = {
        with = "mara", conflict = "spotlight", opener = "player", stage = "brewing",
        title = "Mara",
        says = "Can I mention something? I love Pip, but I had a theory ready all night and never found a gap to say it.",
        options = {
            { label = "I'm sorry. I'll make room for it next week.",
              reply = "Thank you. It's a good theory. You'll see.",
              effects = { mara = { trust = 3 } } },
            { label = "Want me to hand you a clue scene?",
              reply = "Yes! Something I can actually chew on. I'll bring my notes.",
              effects = { mara = { trust = 3, investment = 3 } } },
            { label = "Jump in, nobody's stopping you!",
              reply = "Right. I'll try to be louder, I suppose.",
              effects = { mara = { trust = -3, commitment = -1 } }, pressure = 6 },
        },
    },

    spotlight_dev = {
        with = "dev", conflict = "spotlight", opener = "player", stage = "brewing",
        title = "Dev",
        says = "real talk. how many innkeepers does pip need to interview. I just want to hit something",
        options = {
            { label = "Fair. I'll keep the talky bits tighter.",
              reply = "LEGEND",
              effects = { dev = { trust = 3 } } },
            { label = "Next week Brannoc gets his own moment.",
              reply = "oh it's ON. sharpening the sword",
              effects = { dev = { trust = 2, investment = 3 } } },
            { label = "Pip's scenes are part of the game, man.",
              reply = "yeah ok. I'll bring a book",
              effects = { dev = { trust = -2, commitment = -1 } }, pressure = 6 },
        },
    },

    spotlight_jess = {
        with = "jess", conflict = "spotlight", opener = "dm", stage = "brewing", cost = 1,
        title = "Talk to Jess", about = "About the Pip show. Just between you two.",
        options = {
            { label = "Can I ask a favor? You're the best at NPC scenes. Could you help me pull the quiet ones in?",
              check = { who = "jess", bar = "trust", at = 45 },
              reply = "omg yes. pip is adopting oswin as her sidekick and he doesn't get a say *cracks knuckles*",
              effects = { jess = { investment = 4, trust = 2 } }, resolve = "ally",
              fail = { reply = "...wait. is this a nice way of saying I talk too much", next = "defensive" } },
            { label = "Real talk: you had most of the spotlight last week. Can you leave some room for the others?",
              reply = "oh. oof. ok, I didn't clock that at all. I'll dial pip back a bit",
              effects = { jess = { trust = -2, commitment = -1 } }, resolve = "talk" },
            { label = "Never mind, it's nothing.",
              reply = "?? ok darling, very mysterious of you",
              pressure = 2 },
        },
        nodes = {
            defensive = {
                options = {
                    { label = "A little, yeah. But I love that you're all in, and I want everyone to be.",
                      reply = "ok. fair. I'll try to set people up instead of hogging the innkeeper",
                      effects = { jess = { trust = 1 } }, resolve = "talk" },
                    { label = "No, no! Forget I said anything.",
                      reply = "...ok",
                      effects = { jess = { trust = -1 } }, pressure = 4 },
                },
            },
        },
    },

    -- Rules lawyering -------------------------------------------------------------------

    rules_sam = {
        with = "sam", conflict = "rules", opener = "player", stage = "brewing",
        title = "Sam",
        says = "can we talk about the {topic} thing? feels like the rules change depending on who's asking",
        options = {
            { label = "Fair. Let's make it a house rule.",
              reply = "yes please. I'll even make the index card",
              effects = { sam = { trust = 2 } }, unlock = "rules_house" },
            { label = "I'll look it up before next week and post it.",
              reply = "ok cool, thanks. that's all I wanted",
              effects = { sam = { trust = 2 } }, promise = "look_it_up" },
            { label = "It's just a game, don't sweat it.",
              reply = "...ok",
              effects = { sam = { trust = -3, commitment = -1 } }, pressure = 8 },
        },
    },

    rules_dev = {
        with = "dev", conflict = "rules", opener = "player", stage = "brewing",
        title = "Dev",
        says = "ok but WHY can't brannoc do cool stuff. it's a GAME",
        options = {
            { label = "Let's settle it with the table. We'll vote on it.",
              reply = "fine but I'm campaigning. VOTE BRANNOC",
              effects = { dev = { trust = 1 } }, unlock = "rules_vote" },
            { label = "I'll make a house rule so it's the same every time.",
              reply = "as long as it's a COOL house rule",
              effects = { dev = { trust = 1 } }, unlock = "rules_house" },
            { label = "Rules are rules, man.",
              reply = "booo",
              effects = { dev = { trust = -2, commitment = -1 } }, pressure = 6 },
        },
    },

    rules_house = {
        with = "group", conflict = "rules", opener = "dm", stage = "brewing", cost = 1,
        title = "Post a house rule", about = "Settle {topic} for good, in writing.",
        options = {
            { label = "HOUSE RULE on {topic}: we use the book, but I can give a +2 for a really good idea.",
              replies = { { "dev", "a +2 is still a +2. I'll allow it" }, { "sam", "ok that's actually fair" },
                          { "mara", "Writing it in the rules section of my notes." } },
              effects = { dev = { trust = 2 }, sam = { trust = 2 }, all = { investment = 1 } }, resolve = "house_rule" },
            { label = "HOUSE RULE on {topic}: rule of cool, once per fight, and you have to describe it.",
              replies = { { "dev", "SAY LESS" }, { "sam", "once per fight. ok. I can live with that" },
                          { "jess", "*Pip clears her throat and prepares a description*" } },
              effects = { dev = { trust = 3 }, sam = { trust = -1 } }, resolve = "house_rule" },
            { label = "HOUSE RULE on {topic}: rules as written, no exceptions.",
              replies = { { "sam", "thank you" }, { "dev", "rip suplex" } },
              effects = { sam = { trust = 3 }, dev = { commitment = -2 } }, resolve = "house_rule" },
        },
    },

    rules_vote = {
        with = "group", conflict = "rules", opener = "dm", stage = "brewing", cost = 1,
        title = "Call a vote", about = "Let the table decide {topic}.",
        options = {
            { label = "Vote time: on {topic}, do we go by the book or by rule of cool? Majority wins and it goes on the wall.",
              vote = true,
              replies = { { "dev", "COOL. obviously" }, { "sam", "book, please" },
                          { "mara", "Book, but I'm open to a really good argument." }, { "jess", "cool!! *throws confetti*" } },
              effects = { all = { trust = 1 } }, resolve = "vote" },
        },
    },

    rules_followup = {
        with = "group", conflict = "rules", opener = "dm", stage = "any", cost = 0,
        title = "Post the ruling", about = "You promised to look up {topic}.",
        options = {
            { label = "Looked it up like I said: here's the real rule on {topic}, and that's how we'll play it.",
              replies = { { "sam", "thank you!! that's all I wanted" }, { "dev", "fine. FINE. it's fair" } },
              effects = { sam = { trust = 4 }, dev = { trust = 1 } }, resolve = "look_it_up", kept = true },
        },
    },

    -- Tone clash ------------------------------------------------------------------------

    tone_mara = {
        with = "mara", conflict = "tone", opener = "player", stage = "brewing",
        title = "Mara",
        says = "Can I say something without it being weird? Ilsa's story matters to me, and it keeps turning into a bit.",
        options = {
            { label = "It matters to me too. I'll protect those moments.",
              reply = "Thank you. Really.",
              effects = { mara = { trust = 3, investment = 2 } }, pressure = -8 },
            { label = "Want to bring it up with everyone?",
              reply = "Yes, okay. Maybe a quick tone check, like Session Zero?",
              effects = { mara = { trust = 2 } }, unlock = "tone_check" },
            { label = "Jess is just being Jess.",
              reply = "Right. Of course.",
              effects = { mara = { trust = -3, commitment = -2 } }, pressure = 8 },
        },
    },

    tone_jess = {
        with = "jess", conflict = "tone", opener = "player", stage = "brewing",
        title = "Jess",
        says = "is it bad that I'm scared to make jokes now?? mara gave me THE look last week",
        options = {
            { label = "Jokes are great! Maybe just not in Ilsa's big scenes?",
              reply = "ohhh. ok yeah that's fair. tavern = joke zone. ilsa = no joke zone",
              effects = { jess = { trust = 2 } }, pressure = -8 },
            { label = "Want to do a quick tone check with everyone?",
              reply = "yes!! clear the air. *opens a bag of chips dramatically*",
              effects = { jess = { trust = 2 } }, unlock = "tone_check" },
            { label = "Mara's just stressed. Ignore it.",
              reply = "ok... if you say so",
              effects = { jess = { trust = -1 } }, pressure = 6 },
        },
    },

    tone_check = {
        with = "group", conflict = "tone", opener = "dm", stage = "brewing", cost = 1,
        title = "Tone check", about = "Revisit Session Zero with everyone.",
        options = {
            { label = "Quick tone check: serious story, silly downtime. Ilsa's scenes stay serious; the tavern stays goofy.",
              tone = "mixed",
              replies = { { "mara", "Yes. That. Thank you." }, { "jess", "tavern = joke zone, got it *salutes*" },
                          { "sam", "works for me" } },
              effects = { mara = { trust = 2 }, jess = { trust = 2 } }, resolve = "revisit" },
            { label = "Quick tone check: let's keep it warm and heroic, with real stakes for Ilsa.",
              tone = "heroic",
              replies = { { "sam", "yes" }, { "mara", "Real stakes. I can work with that." }, { "jess", "found family!!" } },
              effects = { mara = { commitment = -1 }, sam = { trust = 1 } }, resolve = "revisit" },
            { label = "Quick tone check: from now on it's dark and dangerous. Jokes stay out of the game.",
              tone = "grim",
              replies = { { "mara", "Thank you." }, { "jess", "oh. ok. pip will be... quiet" } },
              effects = { mara = { trust = 2 }, jess = { commitment = -3, trust = -2 } }, resolve = "revisit" },
            { label = "Quick tone check: it's a silly game. Let's lean into it.",
              tone = "silly",
              replies = { { "jess", "YES" }, { "mara", "I see. Okay." } },
              effects = { jess = { trust = 2 }, mara = { commitment = -4, trust = -2 } }, resolve = "revisit" },
        },
    },
}
