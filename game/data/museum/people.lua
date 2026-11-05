-- The museum's people who remember, and the friends' own ideas (roadmap R11, R12, R13), for The Museum
-- of Nightmares. Adapted from "The Museum of Nightmares" by Luke Russell (DMs Guild): the book gives us
-- the people; what they carry, what they say about what the party did, and the friends' small ideas
-- are our own words.
--
-- memory: who remembers (game/model/people.lua). sees: the rooms they're in, where they see what
--   happens; hears: rooms they hear through the floor (the Lecturer, droning above the gift shop);
--   start: how they feel about someone before anything happens (score; party: the whole party);
--   weights: their own exceptions to the general rules (a rat doesn't mind a bit of thieving).
-- lines: what each of them says, by moment, the first entry whose `when` holds (most specific first;
--   adventure.test conditions, plus opinion = { who, of = "actor" | hero | nil, at_least, at_most } and
--   knows = { who, kind, by = "actor", to = true }). text: one line, or three or more to pick from.
--   {char}: the hero it's about; {what}: the thing; {who}: the person.
-- ideas: what the friends reach for in a room on their own (game/model/ideas.lua): the verbs, who's
--   drawn to each, and the words for each verb, by the person it's aimed at.

return {
  memory = {
    order = { "mus_flitwidget", "mus_telpur", "mus_lecturer", "mus_euryale", "exhibit_b" },
    mus_flitwidget = { sees = { "street", "thanks" } },
    mus_telpur = { sees = { "gift_shop", "thanks" } },
    mus_lecturer = { sees = { "lecture" }, hears = { "gift_shop", "hunting", "offices", "tomorrow", "stairs" } },
    mus_euryale = { sees = { "lair" } },
    -- (Pip's rat: hers from the start, and he doesn't mind a bit of thieving.)
    exhibit_b = { companion = true, start = { jess = 6 }, weights = { steal = { to = -6, other = 0 } } },
  },

  lines = {
    mus_telpur = {
      -- Seeing them again, by how he feels about them now.
      again = {
        { when = { knows = { who = "mus_telpur", kind = "steal", to = true } },
          text = { "You. Hands on the counter where I can see them.", "Back, are we? I've counted every shelf twice, mind.",
                   "Oh, it's you lot. The shelf remembers you. So do I." } },
        { when = { opinion = { who = "mus_telpur", at_least = "warm" } },
          text = { "My favourite customers! Mind the marbles.", "Back again! I kept the good stuff behind the counter for you.",
                   "Oh, lovely. Come in, come in. Wipe your feet. I'm a boot, I notice." } },
      },
      -- His prices, when what they did has moved them (people.price).
      price_up = {
        { when = { opinion = { who = "mus_telpur", at_most = "hostile" } },
          text = { "Prices are up two Francs today. Thief tax. Don't look at me like that.",
                   "Two Francs on everything. For the shelf. You know what you did.",
                   "New prices. Two more, all round. Blame your light-fingered friend." } },
        { when = { opinion = { who = "mus_telpur", at_most = "wary" } },
          text = { "Prices have gone up a Franc since you came in. Funny, that.", "Everything's a Franc more today. Shop's had a rough week.",
                   "A Franc on everything. Call it insurance." } },
      },
      price_down = {
        { text = { "For you? A Franc off. Don't tell the boss.", "Friends' discount. One Franc. I'm feeling generous.",
                   "Take a Franc off, go on. You've been good to the shop." } },
      },
      -- Asked a question by someone he's wary of.
      refuse = {
        { when = { knows = { who = "mus_telpur", kind = "steal", by = "actor", to = true } },
          text = { "Put my stock back, {char}, then we'll talk.", "I don't answer questions from shoplifters. Shelf first.",
                   "Ask me nicely, {char}. Better still, don't ask me." } },
        { text = { "Not in the mood, {char}. Buy something.", "A boot hears things. A boot keeps them, today.",
                   "Ask someone else. I'm busy. Being a boot." } },
      },
      caught = { { text = { "Oi! That's stock! Back on the shelf, {char}.", "I'm a boot, not blind. Shelf. Now.",
                            "You pinch it, you pay double. Put it back." } } },
      -- (His own stock in a hero's hands, lifted when he wasn't looking: he knows it when he sees it.
      -- Round three: he sold the same quiver back, and rode along while it was handed round.)
      spots = { { text = { "Hang on. That quiver on {char}'s back. I priced that quiver. That's my stock!",
                           "Those arrows. Those are MY arrows. Off MY bottom shelf. {char}!",
                           "I know my own stock when I see it, {char}. Those fire arrows never went through the till." } } },
      helped = { { text = { "Careful with the snow globes. Ta.", "Oh. That's... actually that's very kind. Mind the marbles.",
                            "Left a bit. Bit more. Lovely. You can come again." } } },
    },
    mus_flitwidget = {
      caught = { { text = { "My draught! That's for emergencies! You're meant to be the heroes!", "I felt that. Gnomes always feel that, {char}.",
                            "Put it back, and we'll say no more about it. Well. A little more." } } },
      refuse = {
        { when = { knows = { who = "mus_flitwidget", kind = "steal", by = "actor", to = true } },
          text = { "I'd rather not, {char}. Not after the pocket business.", "Ask me again when my draught's back where it belongs.",
                   "Hmm? Sorry, I was counting my pockets." } },
        { text = { "Not now, {char}. Not now.", "Some other time, perhaps.", "I'd rather not say. To you." } },
      },
      helped = { { text = { "Thank you! Splendid! Mind the hat.", "Oh, you're a natural. Do you want a job? You have a job.",
                            "Marvellous. Nobody ever helps with the crowd." } } },
      -- His thanks, when it's over: what he knows comes first, then how he feels about them.
      thanks = {
        -- (The draught that really went: he saw it go, or he's found his waistcoat pocket empty. One he
        -- caught being lifted went straight back, so he doesn't say it's gone. Round three.)
        { when = { knows = { who = "mus_flitwidget", kind = "steal", to = true, outcome = "got" } },
          text = { "Before the biscuits: my healing draught, if you please. I know where it went.",
                   "Thank you, all of you. And whoever has my draught: I'll be counting my pockets after tea.",
                   "My museum's back. My draught isn't. We'll call it even. Nearly." } },
        { when = { event = { kind = "steal", whom = "mus_flitwidget", outcome = "got" } },
          text = { "Thank you, all of you. Oh, and if anyone sees a little healing draught, it's mine. It's gone missing. Funny, that.",
                   "My museum's back! Now, has anyone seen my healing draught? It was in this pocket. It isn't now.",
                   "Splendid, splendid. Though I seem to have lost my healing draught somewhere in all the excitement." } },
        { when = { knows = { who = "mus_flitwidget", kind = "steal", to = true, outcome = "caught" } },
          text = { "Thank you, all of you. Even the one with the quick hands. My draught and I have forgiven you.",
                   "My heroes! Every one of them. Yes, even you, {char}. Hands where I can see them, mind.",
                   "Thank you. And I've quite forgotten the pocket business. Almost." } },
        { when = { knows = { who = "mus_flitwidget", kind = "steal", whom = "mus_telpur" } },
          text = { "Telpur's had a word with me about the shelf. I'll keep one hand on my cash box, if it's all the same.",
                   "Thank you, all of you. Mostly. Telpur tells me some of my stock went for a walk.",
                   "My museum's back. Some of my stock isn't, Telpur says. We'll call it even. Nearly." } },
        -- ({broke}: what he knows they broke, in his words, from the log: "my garden", "my tomb guardian".)
        { when = { knows = { who = "mus_flitwidget", kind = "break" }, opinion = { who = "mus_flitwidget", at_most = "wary" } },
          text = { "Thank you. I think. I'll be sweeping up for a month.", "My museum! What's left of it. No, no, thank you. Really.",
                   "You saved it. You also broke {broke}. Biscuit?" } },
        { when = { chose = { "mus_tidy", 1 }, opinion = { who = "mus_flitwidget", at_least = "warm" } },
          text = { "You put my exhibits back! Nobody ever puts my exhibits back.", "Every jar back on its plinth! I could weep. I might.",
                   "You tidied up after yourselves. In my museum. I'm going to tell everyone." } },
        { when = { opinion = { who = "mus_flitwidget", at_least = "warm" }, not_knows = { who = "mus_flitwidget", kind = "break" } },
          text = { "The best help I've ever had, and I've had a great deal of help.", "My heroes! I'll tell every town on the road about you.",
                   "I knew you had the look. I always know." } },
      },
      -- His reward, when he's docked it: for what he really holds against them (what they broke, his
      -- donation box, his draught), and the number it comes to ({gold_word}: the reward now, in words).
      -- Round three: "Minus a garden. And a guardian." when the hedges were doused and the guardian calmed.
      docked = {
        { when = { knows = { who = "mus_flitwidget", kind = "break" } },
          text = { "I've taken the breakages out of it: {broke}. {Gold_word} gold each, then. Only fair.",
                   "Minus {broke}. Call it {gold_word} gold each. Roughly.",
                   "Ten gold less each, for {broke}. {Gold_word} each. I've been very reasonable." } },
        { when = { knows = { who = "mus_flitwidget", kind = "steal", to = true, outcome = "got" } },
          text = { "Ten gold less each, for my draught. {Gold_word} gold each. Call it the price of a pocket.",
                   "I've taken my healing draught out of it. {Gold_word} gold each, then.",
                   "{Gold_word} each. Ten less, for what went missing from my waistcoat." } },
        { text = { "Ten gold less each, for my donation box. {Gold_word} each. You know what you did.",
                   "I've taken the donation box out of it. {Gold_word} gold each. Only fair.",
                   "{Gold_word} gold each. Ten less, for the business with my donation box." } },
      },
      -- The reward, said before anyone haggles over it (round three: "thirty gold each seems low" with
      -- no number ever said), when he hasn't docked it (docked says the number itself).
      reward = {
        { when = { ending = "escape" },
          text = { "{Gold_word} gold each, then, and a pick from the shop.",
                   "So: {gold_word} gold each. And a pick from the shop. And a biscuit.",
                   "{Gold_word} gold each, for a Gorgon who's gone, not beaten. And anything from the shop you like." } },
        { text = { "Now. Your reward: {gold_word} gold each, as promised, and a pick from the shop.",
                   "{Gold_word} gold each, as I said, and anything from the gift shop you like. Within reason.",
                   "The reward! {Gold_word} gold each and a pick from the gift shop. I always pay my heroes." } },
      },
    },
    mus_euryale = {
      -- On boss night, what the Lecturer told her (people.pass_on), most specific first.
      heard = {
        { when = { knows = { who = "mus_euryale", kind = "steal" } },
          text = { "My lecturer tells me one of you has quick fingers. Keep them where I can see them.",
                   "I hear one of you helps themselves to other people's things. So do I. We'll get on, or we won't.",
                   "The bore downstairs says you rob shops. How refreshing." } },
        { when = { knows = { who = "mus_euryale", kind = "break" } },
          text = { "He tells me you broke half the gnome's toys on the way up. I don't mind. They were his.",
                   "I hear you've been smashing exhibits. Mine are sturdier.",
                   "The Lecturer says you leave a mess. So do I." } },
        { when = { knows = { who = "mus_euryale", kind = "help" } },
          text = { "He says you tidy up after yourselves. How very odd.", "I'm told you're kind to the gnome's things. Be kind to mine.",
                   "Polite guests, he says. We'll see." } },
      },
    },
    mus_lecturer = {
      -- When he passes it on, upstairs (the table hears it as Euryale's cut).
      pass_on = { { text = { "Upstairs, the Lecturer drones on to Euryale about {what}.",
                             "Through the floor, the Lecturer is telling Euryale all about {what}. At length.",
                             "Upstairs, Euryale sits through the Lecturer's report on {what}. It has footnotes." } } },
    },
  },

  -- What the Lecturer's report is about, by what happened ({char}: who did it).
  about = { steal = "{char}'s quick fingers", ["break"] = "the exhibits they broke", help = "how helpful they've been",
            harm = "what they did on the way up" },

  ideas = {
    -- Who's drawn to each verb (their kind of player), and the classes that lean to it.
    likes = {
      take = { instigator = 3, power_gamer = 1.5, method_actor = 1, explorer = 0.5 },
      ask = { storyteller = 2, method_actor = 2, explorer = 1, casual = 1, instigator = 1 },
      help = { casual = 2, tactician = 1.5, method_actor = 1, storyteller = 1 },
      follow = { explorer = 2.5, instigator = 1.5, storyteller = 1.5 },
      hide = { casual = 2, tactician = 1 },
      poke = { explorer = 2.5, storyteller = 1, casual = 1, butt_kicker = 0.5 },
    },
    class = { take = { rogue = 2 }, help = { cleric = 1.5, fighter = 0.5 }, poke = { wizard = 0.5 }, ask = { wizard = 0.5 },
              hide = { rogue = 0.5 } },

    -- Lifting something (R13): what each person carries, nobody planted (the DM's own drops, `pocket`,
    -- are on their sheet too). thing: what it is in the hero's pack (MODULE.items, or a healing potion).
    pockets = {
      mus_flitwidget = { { id = "flit_draught", thing = "potion_healing", what = "the little healing draught in Flitwidget's waistcoat",
                           short = "Flitwidget's healing draught", dc = 13 } },
      mus_telpur = { { id = "shelf_arrows", thing = "arrows_lifted", what = "a quiver of fire arrows on the bottom shelf",
                       short = "a quiver of Telpur's fire arrows", dc = 14, shelf = true } },
    },
    take = {
      notice = { "{char}'s eyes land on {what}.", "{char} has spotted {what}, and {who} hasn't noticed.",
                 "{char} edges a little closer to {what}." },
      say = { "I'm having that. {char}'s a professional.", "Sleight of Hand, on {who}. Don't look at me like that.",
              "Nobody's watching {who}. {char} is.", "Can {char} lift it? Asking for {char}." },
      object = { "{char}. No. Your own pockets.", "If we get caught, I'm saying I don't know you.",
                 "Do we really have to rob everyone we meet?" },
      join = { "Go on. I'll keep them talking.", "Quick, while nobody's looking.", "I'll stand in the way. Go." },
      ok = { "{char} comes away with {thing}. {who} never feels a thing.", "A brush past, a smile, and {thing} has changed hands.",
             "Gone, and nobody the wiser: {thing} is in {char}'s pocket now." },
      no = { "Fine. FINE. Hands in my own pockets.", "Spoilsport. Okay.", "Okay, okay. Another time." },
      fail = { "{who} turns round at exactly the wrong moment.", "{who} looks down, straight at {char}'s hand.",
               "{char}'s fingers close on it just as {who} turns." },
    },
    help = {
      mus_telpur = { skill = "athletics", lines = { "{char} helps Telpur straighten the souvenirs a customer knocked flat.",
                                                     "{char} hands Telpur the marbles that rolled under the counter.",
                                                     "{char} rights the postcard stand for Telpur, who can't reach." } },
      mus_flitwidget = { skill = "persuasion", lines = { "{char} helps Flitwidget shoo the crowd back from the caravan.",
                                                          "{char} holds the ladder while Flitwidget climbs back onto the roof.",
                                                          "{char} hands round Flitwidget's leaflets for him." } },
    },
    follow = {
      mus_flitwidget = { skill = "stealth", go = "{char} slips round the back of the caravan after Flitwidget.",
                         dull = "He's polishing a sign that says CLOSED. He polishes it twice.",
                         detail = "He's talking to the caravan, quietly. It seems to be answering." },
      mus_telpur = { skill = "stealth", go = "{char} follows Telpur's hopping into the stockroom.",
                     dull = "Boxes. Boxes of rubber snakes.",
                     detail = "On a high shelf: a pair of tiny boots, polished, labelled 'For best'." },
    },
    hide = {
      gift_shop = { skill = "stealth", go = "{char} ducks behind the postcard stand until Telpur stops talking about laces.",
                    dull = "It takes a while. Telpur has a lot to say about laces.", detail = "From back here you can see the till. It's empty. It's a boot." },
      street = { skill = "stealth", go = "{char} ducks behind a cart while Flitwidget hands out leaflets.",
                 dull = "The cart smells of turnips.", detail = "Under the cart: a gnome-sized boot print, going the other way." },
      thanks = { skill = "stealth", go = "{char} hides behind the tea urn to get out of Flitwidget's speech.",
                 dull = "The speech is long. The urn is warm.", detail = "Behind the urn, a little brass plaque: 'Telpur, Employee of the Month'. Every month." },
    },
  },
}
