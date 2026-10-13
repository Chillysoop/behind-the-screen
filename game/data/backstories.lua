-- Their backstories, at Session Zero (October 13): each player brings their hero's past to the
-- table, and the DM works it into the world. Real tables do this before the first game: the
-- player pitches, the DM asks a few questions (who taught you, what are you afraid of), says yes
-- to an idea or two of the player's own, and decides which piece of that past turns up first
-- (a person, a place, a thing they carry). What you write here opens each hero's Story log, and
-- the piece you choose waits at the front of your first hand. Data only: tune freely. The view is
-- game/ui/backstory_view.lua; Session Zero settles it in game/model/social.lua.
--
-- QUESTIONS   how many questions Session Zero has time for, all told
-- per player:
--   pitch     what they tell the table about their hero, in character
--   tires     questions they enjoy; each one past it is one too many (-1)
--   questions { id, ask, answer (what they say), fact (what you write down), like }
--   idea      their own idea for the backstory: text, then yes / no = { label, reply, like, fact }
--   hooks     what turns up first: { card, text (what you write), like }. The card joins the deck
--             for week 1 and waits at the front of the hand.
-- like: how they feel about it, -2..2 (it adds to how they leave Session Zero, as the asks do).

return {
    QUESTIONS = 6,

    mara = {
        pitch = "My sister Ilsa copied books at the scriptorium in Millbrook. Two months ago she left her room, her ink "
            .. "still wet, and never came back. I'm going to find out where she went.",
        tires = 3,
        questions = {
            { id = "last_words", ask = "What was the last thing Ilsa said to you?",
              answer = "'Don't wait up.' She said it every night. I always waited up.",
              fact = "The last thing Ilsa said to Thessaly was 'Don't wait up.'", like = 1 },
            { id = "taught", ask = "Who taught Thessaly her magic?",
              answer = "Ilsa did, sort of. She copied the spellbooks, and I read them over her shoulder.",
              fact = "Thessaly learned her first spells reading over Ilsa's shoulder at the scriptorium.", like = 1 },
            { id = "afraid", ask = "What is she afraid she'll find?",
              answer = "That Ilsa left on purpose. That she didn't want to be found. By me.",
              fact = "Thessaly's real fear: that Ilsa left on purpose, and didn't want to be found by her.", like = 1 },
        },
        idea = {
            text = "Can Ilsa and Thessaly have a secret code from when they were kids? If she left a message, it'd be in that.",
            yes = { label = "Yes, and it matters", reply = "YES. I'm writing the alphabet out tonight.", like = 1,
                    fact = "Thessaly and Ilsa made up a code as children. If Ilsa left a message, it's in that." },
            no = { label = "Not yet", reply = "Okay. Maybe it comes up later.", like = -1 },
        },
        hooks = {
            { card = "ilsa_ring", text = "Something of Ilsa's turns up in Millbrook: her silver ring, still warm.", like = 1 },
            { card = "corin", text = "Someone who knew her finds Thessaly first: Corin, Ilsa's assistant, who flinches at her name.",
              like = 1 },
            { card = "ilsa_room", text = "The last place anyone saw her: her room above the scriptorium, just as she left it.",
              like = 1 },
        },
    },

    dev = {
        pitch = "Kessrick's warband burned my village, Hale's Crossing. I'm the only one who walked out, and only because "
            .. "Oswin dragged me.",
        tires = 2,
        questions = {
            { id = "plan", ask = "What does Brannoc do if he finds Kessrick tomorrow?",
              answer = "Hits him. With Ember. A lot.",
              fact = "Brannoc has one plan for Kessrick, and it's Ember.", like = 1 },
            { id = "before", ask = "What was Hale's Crossing like before the fire?",
              answer = "Small. A mill, a bell, forty people. I knew all their names. I still do.",
              fact = "Hale's Crossing was a mill, a bell and forty people. Brannoc still knows every name.", like = 0 },
            { id = "others", ask = "Did anyone else get out?",
              answer = "No. That's the point. ...Unless you want someone to have. I'd be into that.",
              fact = "Brannoc believes nobody else walked out of Hale's Crossing. He'd like to be wrong.", like = 1 },
        },
        idea = {
            text = "Can Ember have been my dad's sword? The only thing I carried out of the village?",
            yes = { label = "Yes, and it matters", reply = "Okay, that's sick. Ember gets a backstory too.", like = 1,
                    fact = "Ember was Brannoc's father's sword: the one thing he carried out of Hale's Crossing." },
            no = { label = "Not yet", reply = "Fine. It's still a cool sword.", like = -1 },
        },
        hooks = {
            { card = "kessrick_trail", text = "Kessrick's men were near Millbrook, and recently: fresh tracks and a wolf badge on the road.",
              like = 1 },
            { card = "wolves_watching", text = "Kessrick's wolves are already watching the party. They know Brannoc's face.", like = 1 },
            { card = "hales_crossing", text = "The road home: the ashes of Hale's Crossing, a day's walk from Millbrook.", like = 0 },
        },
    },

    jess = {
        pitch = "Pip. Just Pip. I may owe some people some money. Not a lot of money. A fair bit of money. Don't ask "
            .. "Madame Sable about it.",
        tires = 3,
        questions = {
            { id = "how_much", ask = "How much does Pip actually owe?",
              answer = "Forty gold. Okay, four hundred. Okay, I don't KNOW, Sable keeps adding to it.",
              fact = "Pip doesn't know how much she owes. Madame Sable does, to the copper, and keeps adding to it.", like = 1 },
            { id = "how", ask = "How did Pip end up owing the Velvet Hand?",
              answer = "A job went wrong. My crew ran, I didn't, and the Hand paid my way out of a cell. With interest.",
              fact = "A job went wrong, Pip's crew ran, and the Velvet Hand bought her out of a cell. With interest.", like = 1 },
            { id = "scared", ask = "Who in the Hand is Pip actually scared of?",
              answer = "Not Sable. Sable's polite. The two big men in velvet gloves, though.",
              fact = "Pip isn't scared of Sable. She's scared of Sable's collectors, the two big men in velvet gloves.", like = 1 },
        },
        idea = {
            text = "Can Pip's old crew be in town too? The ones who ran? I want to do a whole reunion bit.",
            yes = { label = "Yes, and it matters", reply = "Oh, this is going to be SO awkward. I love it.", like = 1,
                    fact = "Pip's old crew, the ones who ran, are somewhere in Millbrook." },
            no = { label = "Not yet", reply = "Boo. Fine. Pip forgives them. Pip forgives nobody.", like = -1 },
        },
        hooks = {
            { card = "madame_sable", text = "Madame Sable comes to collect, in person, and she's very polite about it.", like = 1 },
            { card = "collectors", text = "Sable's collectors find Pip first: two large men in velvet gloves.", like = 0 },
            { card = "velvet_den", text = "The Velvet Hand's back room, where Pip's name is in a very large ledger.", like = 1 },
        },
    },

    sam = {
        pitch = "My temple burned. I carry what was left of it. And I pulled Brannoc out of the ashes, so he's my "
            .. "problem now.",
        tires = 1,
        questions = {
            { id = "looks", ask = "What does the relic look like?",
              answer = "Heavy. Bronze. Kind of a big teardrop? He keeps it wrapped in his good shirt.",
              fact = "The relic is a heavy bronze teardrop. Oswin keeps it wrapped in his good shirt.", like = 1 },
            { id = "abbot", ask = "Who was the abbot to Oswin?",
              answer = "He raised him. Taught him to make tea. That's... yeah. That's who.",
              fact = "The old abbot raised Oswin, and taught him to make tea.", like = 0 },
            { id = "why", ask = "Why did Oswin go back into the fire for Brannoc?",
              answer = "Because he was there? I don't know. Anyone would. Can someone else go?",
              fact = "Oswin went back into the fire for a stranger, and doesn't think it was brave.", like = -1 },
        },
        idea = {
            text = "Can Oswin be the one who makes tea for everyone at camp? Like, that's his thing?",
            yes = { label = "Yes, and it matters", reply = "Okay. Good. I'll describe the tea.", like = 1,
                    fact = "Oswin makes tea for everyone at camp. It's his whole thing." },
            no = { label = "Not yet", reply = "Oh. Okay. That's fine.", like = -1 },
        },
        hooks = {
            { card = "guard_relic", text = "Someone in Millbrook wants Oswin's relic, badly.", like = 0 },
            { card = "abbot_ghost", text = "The abbot isn't quite gone. His ghost still watches over Oswin.", like = 1 },
            { card = "relic_back", text = "The relic goes missing on their first night in Millbrook.", like = -1 },
        },
    },
}
