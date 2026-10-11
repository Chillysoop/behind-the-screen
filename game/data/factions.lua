-- The living world (the slice rework, S5 to S7): the people of the Vale, the factions they
-- belong to, and what each faction does off screen between sessions. Real DMs keep this in a
-- campaign status document (The Alexandrian), ask what each villain is doing right now (Sly
-- Flourish), and tick faction clocks in downtime (Blades in the Dark). Data only: tune freely.
-- The models are game/model/ledger.lua (the notebook) and game/model/world.lua (the turn).
--
-- people: everyone the notebook keeps a card for, by person id (a cast card's id, or an
--   arc.lua person's). Names, roles and blurbs come from arc.lua's people where they're there.
--   faction  who they belong to (nil: nobody but themselves)
--   att      where they start with the party: -3 Hostile ... 0 Indifferent ... +3 Friendly
--   warm     where they start with one hero: { player key = -3 .. 3 }
--   status   "around" (the default), "missing", "away", "got away", "beaten"
--   hidden   their faction is a secret until the party exposes them
--   cards    the cast cards that are this person (Wren is the hooded stranger first)
--   sprite   their mini in the notebook
--   wants    what they bring when the DM brings them in (S6): warm, a favour or a job for a
--            party they like (a goal: win and lose say how it pays off); cold, trouble for a
--            party they don't (a complication); back, a villain who got away coming back.
--
-- factions: order, then by id:
--   tier     how strong it is off screen: d6s rolled for its moves, keep the highest
--   start    its standing with the party: -3 at war ... +3 allies (members move it too)
--   front    the planner front it is, if any (its portents are then its project)
--   project  { name, size, done = { text, know, fx } }: a clock that fills off screen
--   cards    its doing: winning a scene with one crosses it and takes a segment off its project
--   helps    goals that help it: winning one adds a segment and warms it
--   moves    what it does off screen: { id, name, when, weight, screen, project, results }
--     when     conditions, all must hold: crossed (the party crossed it lately), min_standing,
--              max_standing, week (from this week on), present (a player at the table this
--              week), needs (a card in the deck), lacks (a card that can still join),
--              member (a person still around), not_front (only when it isn't the front),
--              once (once a campaign)
--     screen   the card it becomes when the DM brings it on screen (S6); the scene's outcome
--              stands in for the roll: the party wins, the move goes badly; loses, it works
--     project  true: a move that works on the project (skipped while it's the planner front)
--     results  full (a 6), half (4 or 5), bad (1 to 3): { text, know, rumour, fx }
--       know     "secret" (the DM's alone), "rumour" (the group chat hears it), "public"
--       fx       clock = n; add = { card ids that join the deck }; att = { person = delta };
--                status = { person = status }; place = { location = state }; join = { person
--                = faction }; standing = delta; spend_goal = true (a rival gets to an open job
--                first: one open goal, not a story or backstory card, leaves the deck)
--
-- places: a location's states once the world changes it: { label, line }.
-- reactions: what a player says in the group chat when the DM posts a rumour, by faction
--   (their own thread's faction first) and then any.

return {
    -- Attitude labels (SRD 5.2.1's Friendly, Indifferent and Hostile, with a shade either side).
    ATT_MIN = -3, ATT_MAX = 3,
    LABELS = { [-3] = "Hostile", [-2] = "Hostile", [-1] = "Wary", [0] = "Indifferent", [1] = "Warm", [2] = "Friendly",
               [3] = "Friendly" },
    INFLUENCE = { persuasion = true, deception = true, intimidation = true, performance = true },
    HOLDS = 1,          -- off-screen moves the DM can hold each week
    GUESTS = 2,         -- people or places to bring in each week
    STATUS = { around = "Around", missing = "Missing", away = "Left town", ["got away"] = "Got away",
               beaten = "Beaten" },

    people = {
        gus = { faction = "millbrook", att = 1, sprite = "npc_gus",
            wants = {
                warm = { name = "Gus needs a hand",
                    line = "Goal: Gus's ale delivery went missing on the north road, and the Kettle is nearly dry. He asks them to find it.",
                    win = "The ale cart's back, dented but full. Gus says their drinks are free until midsummer.",
                    lose = "The ale's gone. Gus waters the last barrel and says it's fine. It isn't." },
                cold = { name = "Gus has had enough",
                    line = "Gus won't serve them. 'Not after last time.' The whole Kettle goes quiet." },
            } },
        stranger = { faction = "millbrook", att = 0, sprite = "npc_stranger", cards = { "stranger", "wren" },
            wants = {
                warm = { name = "Wren asks for an escort",
                    line = "Goal: Wren wants to climb to the bell paths and look for Tobin's marks. She's not going alone.",
                    win = "Wren finds one of Tobin's chalk marks, fresh, and laughs for the first time since he left.",
                    lose = "The path's washed out. Wren goes quiet the whole way back." },
                cold = { name = "Wren won't talk to them",
                    line = "Wren sees them coming and slips away through the crowd." },
            } },
        tobin = { faction = "millbrook", att = 1, status = "missing" },
        corin = { faction = "millbrook", att = 0, warm = { mara = 1 }, sprite = "npc_corin",
            wants = {
                warm = { name = "Corin found something",
                    line = "Goal: Corin has found a page in Ilsa's hand, in a code he can't read. He asks Thessaly to help him break it.",
                    win = "The code breaks: a list of the seven bells, and beside the fourth, 'the hush starts here'.",
                    lose = "The code won't give. Corin keeps the page, and won't let it out of his sight." },
                cold = { name = "Corin hides from them",
                    line = "Corin has locked the scriptorium and won't open the door. 'Go away. Please.'" },
            } },
        madame_sable = { faction = "velvet_hand", att = -1, warm = { jess = -1 }, sprite = "npc_sable",
            wants = {
                warm = { name = "Sable offers a job",
                    line = "Goal: Madame Sable has a job that pays: a ledger to fetch from a rival's strongbox, no questions asked.",
                    win = "The ledger's delivered. Sable strikes a line through one of Pip's debts, and smiles.",
                    lose = "The job goes wrong. Sable adds the cost to Pip's tab, plus interest." },
                cold = { name = "Sable wants payback",
                    line = "Madame Sable's people are waiting for them outside the Kettle, and Sable is with them." },
            } },
        abbot_ghost = { faction = "old_faith", att = 1, warm = { sam = 2 }, sprite = "npc_ghost",
            wants = {
                warm = { name = "The abbot's last wish",
                    line = "Goal: the abbot's ghost asks Oswin to light a candle in every niche of the old chapel, the way they used to.",
                    win = "Every candle lit. The abbot's voice, warm: 'Thank you, my boy.' The chapel feels lighter.",
                    lose = "The candles keep guttering out. The abbot says nothing, and that's worse." },
                cold = { name = "The abbot is troubled",
                    line = "Cold air where the abbot should be. Oswin's prayers come back unanswered." },
            } },
        hermit = { faction = "old_faith", att = 0, sprite = "npc_hermit",
            wants = {
                warm = { name = "The hermit's kettle is missing",
                    line = "Goal: someone stole the hermit's kettle. He's distraught. He says it knows things.",
                    win = "The kettle's back on the fire. The hermit pours tea, and tells them what the kettle heard.",
                    lose = "No kettle. The hermit sulks, and won't talk about the bells at all." },
                cold = { name = "The hermit sends them away",
                    line = "The hermit's door is barred. A note on it says 'NOT TODAY' in very large letters." },
            } },
        wolf_lieutenant = { faction = "warband", att = -3, warm = { dev = -1 }, sprite = "tough",
            wants = {
                back = { name = "Vask comes back for them",
                    line = "Vask got away last time. He's had all week to plan this, and he's brought the whole gate watch." },
                cold = { name = "Vask sends a message",
                    line = "A wolf badge nailed to the door of their lodgings, and a note: 'The tower is mine. Stay away.'" },
            } },
        kessrick = { faction = "warband", att = -3 },
        grey_coat = { faction = "warband", att = -2, sprite = "tough",
            wants = {
                back = { name = "The grey coat strikes",
                    line = "The man in the grey coat got away. Now he's in the crowd again, and he isn't watching anymore. He's hunting." },
                cold = { name = "Someone is following them",
                    line = "A grey coat at the edge of the crowd, every time they look back." },
            } },
        turncoat_guide = { faction = "velvet_hand", att = -2, hidden = true, sprite = "bandit_captain",
            wants = {
                back = { name = "The guide's ambush",
                    line = "The turncoat guide got away, and knows every road they'll take. This time the ambush is ready." },
                cold = { name = "The guide sells their route",
                    line = "Somebody knew exactly which road they'd take today." },
            } },
        miller = { faction = "millbrook", att = 2, sprite = "npc_gus",
            wants = {
                warm = { name = "Hob's mill wheel is stuck",
                    line = "Goal: something is jammed under Old Hob's mill wheel, and the whole town's flour is waiting on it.",
                    win = "Out comes a rusted strongbox, and the wheel turns again. Hob bakes them a loaf each, and the box is theirs.",
                    lose = "The wheel stays stuck. Hob's sons are going to dive for it tomorrow. Hob is worried." },
                cold = { name = "Hob is disappointed in them",
                    line = "Old Hob shakes his head. No bread today." },
            } },
        market_friend = { faction = "millbrook", att = 1, sprite = "npc_sable",
            wants = {
                warm = { name = "Tilly has a lead",
                    line = "Goal: Tilly's heard a rumor worth following: a stranger paying in wolf-badge silver at the stables.",
                    win = "The stranger's saddlebags hold a letter with Kessrick's seal. Tilly is insufferable about it.",
                    lose = "The stranger's gone by the time they get there. Tilly swears it was true." },
                cold = { name = "Tilly tells everyone",
                    line = "Tilly has told the whole market what the party did. The whole market." },
            } },
        merchant = { faction = "millbrook", att = 0, sprite = "npc_sable",
            wants = {
                warm = { name = "Ottilie needs guards",
                    line = "Goal: Ottilie Vane's wool cart leaves at dawn, and she'll pay well for guards who can count.",
                    win = "The cart gets through. Ottilie pays, and writes the party into her ledger under 'reliable'.",
                    lose = "Half the wool's lost. Ottilie pays half, and writes 'expensive' in her ledger." },
                cold = { name = "Ottilie raises her prices",
                    line = "Ottilie Vane has doubled every price for the party. 'Risk,' she says." },
            } },
        cutpurses = { faction = "velvet_hand", att = 0, sprite = "bandit",
            wants = {
                warm = { name = "The Cutpurses owe them one",
                    line = "Goal: the Lowmarket Cutpurses offer a favour: anything lifted from anyone in town, by morning.",
                    win = "By morning there's a stolen letter on their table, and a bow from a very polite stranger.",
                    lose = "The Cutpurses got caught. They're not blaming the party. Out loud." },
                cold = { name = "The Cutpurses come for their purses",
                    line = "Everybody checks their purse. Everybody's purse is gone." },
            } },
        rook = { att = -1, sprite = "bandit_captain",
            wants = {
                warm = { name = "Rook calls in a favour",
                    line = "Goal: Captain Rook needs help: one of her people is in the town lock-up, and she can't go in herself.",
                    win = "Rook's man walks free. 'I owe you,' says Rook, and somehow it sounds like a threat.",
                    lose = "Rook's man stays locked up. Rook isn't angry. She's thinking." },
                cold = { name = "Rook's toll",
                    line = "Captain Rook's bandits have closed the bridge road. The toll is whatever the party has." },
            } },
        rivals = { faction = "spurs", att = -1, sprite = "npc_rival",
            wants = {
                warm = { name = "The Spurs want to team up",
                    line = "Goal: the Silver Spurs propose a joint job, split down the middle. They've written a song about it already.",
                    win = "It works. The Spurs sing about it all night, and mention the party twice.",
                    lose = "It goes wrong. The Spurs blame the party in the second verse." },
                cold = { name = "The Spurs get there first",
                    line = "The Silver Spurs are already here, posing, and they've told everyone this was their idea." },
            } },
    },

    -- Who's a person in the notebook (beasts and the dead aren't).
    names = {
        rook = { name = "Captain Rook", role = "Bandit captain on the bridge road",
            about = "Grins like she's already won. Her people are paid in good silver, and nobody knows whose." },
        rivals = { name = "The Silver Spurs", role = "Rival adventurers, with a theme song",
            about = "Matching capes, a theme song, and very strong opinions about who the heroes of this valley are." },
        grey_coat = { name = "The man in the grey coat", role = "A watcher in the crowd",
            about = "At the edge of every crowd this week. There's a wolf badge under his lapel." },
        miller = { name = "Old Hob", role = "The miller",
            about = "Thanks them every time they pass. There's always bread." },
        turncoat_guide = { name = "The turncoat guide", role = "A guide who switched sides",
            about = "Drew a knife on them on the road. Knows every path in the hills." },
        market_friend = { name = "Tilly", role = "Knows everyone at the market",
            about = "Knows everyone's business, and shares it freely." },
        merchant = { name = "Ottilie Vane", role = "Wool merchant",
            about = "Counts everything twice, including the party." },
        cutpurses = { name = "The Lowmarket Cutpurses", role = "Very polite thieves",
            about = "Very fast hands. They returned Brannoc's purse once, just to prove a point." },
    },

    order = { "warband", "velvet_hand", "millbrook", "old_faith", "spurs" },

    warband = {
        name = "Kessrick's warband", short = "the warband", tier = 3, start = -3, front = "kessrick",
        goal = "Hush the valley's bells, then come down from the hills.",
        cards = { "wolf_lieutenant", "grey_coat", "wolves_watching", "vask_key" },
        moves = {
            { id = "scouts", name = "Send scouts down the valley roads", weight = 3, screen = "wolves_watching",
              results = {
                  full = { text = "Kessrick's scouts mapped every road out of Millbrook. He knows the party's names now.",
                           know = "secret", fx = { add = { "howls" } } },
                  half = { text = "Riders with wolf badges were seen on the north road at dusk.", know = "rumour",
                           rumour = "Word in Millbrook: riders with wolf badges on the north road, two nights running." },
                  bad = { text = "A scout got careless at the ford. Tilly saw the badge, and told everyone.", know = "rumour",
                          rumour = "Word in Millbrook: Tilly swears she saw one of Kessrick's men at the ford. Washing his socks." },
              } },
            { id = "watcher", name = "Put a watcher on the party", weight = 2, screen = "grey_coat",
              when = { lacks = "grey_coat", week = 2 },
              results = {
                  full = { text = "A man in a grey coat has taken a room across from the Kettle. He watches the party's door.",
                           know = "secret", fx = { add = { "grey_coat" } } },
                  half = { text = "Someone's been asking Gus which room the party sleeps in.", know = "rumour",
                           rumour = "Word in Millbrook: Gus says a stranger was asking which room you lot sleep in.",
                           fx = { add = { "grey_coat" } } },
                  bad = { text = "The watcher picked the wrong inn, and spent the week watching a goat.", know = "secret" },
              } },
            { id = "strike", name = "Strike back at the party", weight = 4, screen = "reinforcements",
              when = { crossed = true },
              results = {
                  full = { text = "Vask's men caught Old Hob on the mill road and broke his cart, as a message.",
                           know = "public", rumour = "Word in Millbrook: Old Hob's cart was smashed on the mill road. A wolf badge was left on the seat.",
                           fx = { att = { miller = -1 }, add = { "ransom" } } },
                  half = { text = "A wolf badge was nailed to the Kettle's door overnight.", know = "rumour",
                           rumour = "Word in Millbrook: somebody nailed a wolf badge to the Kettle's door last night. Gus is furious." },
                  bad = { text = "The raiders sent after the party got lost in the fog and went home.", know = "secret" },
              } },
            { id = "buy_rook", name = "Buy Captain Rook's bandits", weight = 2, screen = "rook",
              when = { once = true, member = "rook", week = 2 },
              results = {
                  full = { text = "Captain Rook took Kessrick's silver. Her bandits ride for the warband now.", know = "secret",
                           fx = { join = { rook = "warband" }, att = { rook = -1 } } },
                  half = { text = "Rook took the silver, and is still deciding what it bought.", know = "secret" },
                  bad = { text = "Rook threw Kessrick's silver in the river. She doesn't like being bought.", know = "rumour",
                          rumour = "Word in Millbrook: Captain Rook threw a bag of silver off the bridge, and laughed about it.",
                          fx = { att = { rook = 1 } } },
              } },
        },
    },

    velvet_hand = {
        name = "The Velvet Hand", short = "the Hand", tier = 2, start = -1, front = "velvet_hand",
        goal = "Own every debt in Millbrook.",
        project = { name = "Buy up Millbrook's debts", size = 5,
            done = { text = "The Velvet Hand owns the Crooked Kettle's debts. Gus works for them now.", know = "public",
                     rumour = "Word in Millbrook: the Kettle's got new owners. There's a velvet curtain over Gus's notice board.",
                     fx = { place = { tavern = "hand" }, att = { gus = -1 }, add = { "save_kettle" } } } },
        cards = { "madame_sable", "collectors", "owe_more", "key_for_sale", "purse_lifted", "cutpurses", "turncoat_guide" },
        against = { "steal_ledger", "debt_cleared", "save_kettle" },
        helps = { "sable_job" },
        moves = {
            { id = "collect", name = "Collect on Millbrook's debts", weight = 5, project = true,
              results = {
                  full = { text = "The Hand bought three more shops' debts on Mill Street.", know = "rumour",
                           rumour = "Word in Millbrook: three shops on Mill Street are paying the Velvet Hand now.",
                           fx = { clock = 2 } },
                  half = { text = "The Hand's collectors made their rounds. One more shop pays.", know = "secret", fx = { clock = 1 } },
                  bad = { text = "A debtor skipped town with the Hand's money. Sable is not pleased.", know = "rumour",
                          rumour = "Word in Millbrook: the baker did a runner owing the Velvet Hand a fortune. Good for him." },
              } },
            { id = "squeeze", name = "Lean on Pip's debt", weight = 3, screen = "collectors",
              when = { present = "jess" },
              results = {
                  full = { text = "Sable doubled Pip's debt, and made sure everyone in Lowmarket heard about it.", know = "public",
                           rumour = "Word in Lowmarket: Pip's debt to the Velvet Hand has doubled. Sable's telling everyone.",
                           fx = { add = { "owe_more" } } },
                  half = { text = "Sable's collectors were asking after Pip at the Kettle.", know = "rumour",
                           rumour = "Word in Millbrook: two very polite people in velvet gloves were asking for Pip at the Kettle.",
                           fx = { add = { "collectors" } } },
                  bad = { text = "Sable's collectors went to the wrong Pip. That Pip was a blacksmith.", know = "secret" },
              } },
            { id = "strike", name = "Send the Cutpurses after the party", weight = 4, screen = "purse_lifted",
              when = { crossed = true },
              results = {
                  full = { text = "The Cutpurses lifted the party's purses at the market, every one, as a warning.", know = "public",
                           rumour = "Word in Millbrook: half the market had their purses lifted today. Somebody's sending a message.",
                           fx = { add = { "purse_lifted" } } },
                  half = { text = "Sable raised the party's prices all over Lowmarket.", know = "rumour",
                           rumour = "Word in Lowmarket: nobody will sell to the party at a fair price this week. Wonder why.",
                           fx = { att = { merchant = -1 } } },
                  bad = { text = "The Cutpurses didn't want the job. They like the party.", know = "secret",
                          fx = { att = { cutpurses = 1 } } },
              } },
            { id = "sell_key", name = "Sell the tower's second key", weight = 2, screen = "key_for_sale",
              when = { week = 2, lacks = "key_for_sale", not_front = true },
              results = {
                  full = { text = "The Hand sold a copy of the tower key. The buyer wore a wolf badge.", know = "secret",
                           fx = { add = { "key_for_sale" } } },
                  half = { text = "The Hand put a tower key up for sale, and the bidding's open.", know = "rumour",
                           rumour = "Word in Lowmarket: somebody's selling a key to the bell tower. Highest bidder.",
                           fx = { add = { "key_for_sale" } } },
                  bad = { text = "The key the Hand meant to sell turned out to be for the wrong door.", know = "secret" },
              } },
            { id = "favour", name = "Offer the party work", weight = 3, screen = "sable_job",
              when = { min_standing = 0 },
              results = {
                  full = { text = "Sable sent word: she has work, and it pays in Pip's debts.", know = "rumour",
                           rumour = "Word in Lowmarket: Madame Sable sends her regards, and a job. Ask Pip.",
                           fx = { add = { "debt_deal" }, standing = 1 } },
                  half = { text = "Sable mentioned the party to a client. Kindly.", know = "secret", fx = { standing = 1 } },
                  bad = { text = "Sable thought better of offering the party anything.", know = "secret" },
              } },
        },
    },

    millbrook = {
        name = "The folk of Millbrook", short = "Millbrook", tier = 1, start = 1,
        goal = "Keep the town safe and the Kettle open.",
        project = { name = "Mend the old walls", size = 6,
            done = { text = "Millbrook's old walls stand again, every gap filled with stones the whole town carried.",
                     know = "public", rumour = "Word in Millbrook: the walls are done! Hob's hosting a party. Everyone's invited.",
                     fx = { place = { millbrook_walls = "mended" }, add = { "millbrook_walls", "celebrate" }, standing = 1 } } },
        cards = {},
        helps = { "caravan", "sheep", "flood", "save_kettle", "muster_valley", "shelter", "fair", "find_tobin", "find_wren" },
        moves = {
            { id = "walls", name = "Work on the old walls", weight = 3, project = true,
              results = {
                  full = { text = "The whole town turned out to carry stones. The east wall is nearly whole.", know = "rumour",
                           rumour = "Word in Millbrook: the whole town carried stones for the walls today. Hob brought bread.",
                           fx = { clock = 2 } },
                  half = { text = "A few families worked on the walls after market.", know = "secret", fx = { clock = 1 } },
                  bad = { text = "Rain washed out a week's work on the walls.", know = "rumour",
                          rumour = "Word in Millbrook: the rain took half the new wall down. Everyone's very tired." },
              } },
            { id = "ask", name = "Ask the party for help", weight = 3, when = { min_standing = 0 }, screen = "caravan",
              results = {
                  full = { text = "The town asked for the party by name: the sheep, the river and the wool roads all need them.",
                           know = "public", rumour = "Word in Millbrook: everyone's asking for you lot. The sheep, the river, the wool roads.",
                           fx = { add = { "sheep", "flood" } } },
                  half = { text = "Ottilie's wool cart needs guards.", know = "rumour",
                           rumour = "Word in Millbrook: Ottilie Vane needs guards for the wool cart, and she's asking about you.",
                           fx = { add = { "caravan" } } },
                  bad = { text = "The town decided to sort its own problems out, for now.", know = "secret" },
              } },
            { id = "fear", name = "Panic about the warband", weight = 2, screen = "muster_valley",
              when = { week = 3 },
              results = {
                  full = { text = "Families are packing carts and leaving for the lowlands.", know = "public",
                           rumour = "Word in Millbrook: the Fennick family left at dawn. Three more carts are packing.",
                           fx = { add = { "muster_valley" }, standing = -1 } },
                  half = { text = "People are locking their doors at night and watching the hills.", know = "rumour",
                           rumour = "Word in Millbrook: everyone's locking their doors now. Even Gus.",
                           fx = { add = { "muster_valley" } } },
                  bad = { text = "Gus talked the town down. Nobody's leaving.", know = "secret", fx = { att = { gus = 1 } } },
              } },
            { id = "thanks", name = "Thank the party", weight = 3, when = { min_standing = 2 },
              results = {
                  full = { text = "The town threw the party a supper at the Kettle. Hob baked.", know = "public",
                           rumour = "Word in Millbrook: supper at the Kettle on Wednesday, in your honor. Hob's baking.",
                           fx = { add = { "celebrate", "new_friend" } } },
                  half = { text = "People nod at the party in the street now.", know = "secret", fx = { standing = 1 } },
                  bad = { text = "Nobody had time to say thank you this week.", know = "secret" },
              } },
        },
    },

    old_faith = {
        name = "The old faith", short = "the old faith", tier = 1, start = 0,
        goal = "Keep the old blessings, and the bells, alive.",
        project = { name = "Bless the chapel again", size = 6,
            done = { text = "The roadside chapel is blessed again. Whatever stirs under it sleeps easier.", know = "public",
                     rumour = "Word in Millbrook: the old chapel's been blessed again. The hermit cried, apparently.",
                     fx = { place = { chapel = "blessed" }, standing = 1 } } },
        cards = {},
        helps = { "lay_to_rest", "silence_crypt", "guard_relic", "carry_relic", "relic_back", "riddle" },
        moves = {
            { id = "tend", name = "Tend the old shrines", weight = 3, project = true,
              results = {
                  full = { text = "The hermit relit the chapel's candles and said the old words. They held.", know = "secret",
                           fx = { clock = 2 } },
                  half = { text = "Someone left fresh flowers at every shrine in the valley.", know = "rumour",
                           rumour = "Word in Millbrook: fresh flowers on every shrine in the valley this morning. Nobody saw who.",
                           fx = { clock = 1 } },
                  bad = { text = "The chapel candles wouldn't stay lit.", know = "secret" },
              } },
            { id = "omen", name = "Read the omens", weight = 2, screen = "dead_walk",
              when = { week = 2 },
              results = {
                  full = { text = "The hermit read the omens in the crypt: the dead are restless, and getting worse.", know = "rumour",
                           rumour = "Word in Millbrook: the hermit came down from the hills to say the dead are restless. He was very serious.",
                           fx = { add = { "crypt", "lay_to_rest" } } },
                  half = { text = "Strange lights at the chapel at night.", know = "rumour",
                           rumour = "Word in Millbrook: lights in the old chapel at night. Nobody's brave enough to look.",
                           fx = { add = { "crypt" } } },
                  bad = { text = "The omens said nothing at all. The hermit is suspicious of that.", know = "secret" },
              } },
            { id = "blessing", name = "Bless the party", weight = 3, when = { min_standing = 2 },
              results = {
                  full = { text = "The old faith blessed the party at the shrine, and gave Oswin a page from the old rites.",
                           know = "public", fx = { add = { "temple_page", "potions" } } },
                  half = { text = "The hermit left a pot of honey on their doorstep.", know = "secret", fx = { standing = 1 } },
                  bad = { text = "Nobody remembers the words for the blessing.", know = "secret" },
              } },
        },
    },

    spurs = {
        name = "The Silver Spurs", short = "the Spurs", tier = 1, start = -1,
        goal = "Be the valley's famous heroes, whatever it takes.",
        project = { name = "Steal the party's glory", size = 4,
            done = { text = "All of Millbrook thinks the Silver Spurs are the heroes of the valley. There's a song.",
                     know = "public", rumour = "Word in Millbrook: there's a song about the Silver Spurs saving the valley. You're not in it.",
                     fx = { place = { market = "spurs" }, add = { "fair" }, standing = -1 } } },
        cards = { "rivals", "fair" },
        moves = {
            { id = "brag", name = "Brag about the party's work", weight = 3, project = true,
              results = {
                  full = { text = "The Spurs told the whole Kettle they found Tobin's trail. They didn't.", know = "rumour",
                           rumour = "Word in Millbrook: the Silver Spurs say THEY found Tobin's trail. They did not.",
                           fx = { clock = 2 } },
                  half = { text = "The Spurs added a verse to their theme song.", know = "rumour",
                           rumour = "Word in Millbrook: the Spurs have a new verse. It rhymes 'valiant' with 'Millbrook'. Somehow.",
                           fx = { clock = 1 } },
                  bad = { text = "The Spurs' bragging fell flat. Somebody asked for proof.", know = "secret" },
              } },
            { id = "race", name = "Race the party to a job", weight = 3, screen = "rivals",
              when = { week = 2 },
              results = {
                  full = { text = "The Spurs got to one of the party's jobs first, and took the credit.", know = "public",
                           rumour = "Word in Millbrook: the Spurs are taking jobs before anyone else hears about them.",
                           fx = { spend_goal = true, clock = 1 } },
                  half = { text = "The Spurs are sniffing around the same jobs as the party.", know = "rumour",
                           rumour = "Word in Millbrook: the Spurs were asking about your jobs. All of them." },
                  bad = { text = "The Spurs took a job, and botched it.", know = "rumour",
                          rumour = "Word in Millbrook: the Spurs fell in the river. All of them. In the capes." },
              } },
            { id = "team_up", name = "Offer to team up", weight = 3, when = { min_standing = 0 },
              results = {
                  full = { text = "The Spurs want to team up. They've written the party into the song.", know = "rumour",
                           rumour = "Word in Millbrook: the Spurs put you in their song! You're the 'trusty sidekicks'.",
                           fx = { standing = 1, clock = -1, add = { "safe_conduct" } } },
                  half = { text = "The Spurs nodded at the party in the street. Grudgingly.", know = "secret", fx = { standing = 1 } },
                  bad = { text = "The Spurs couldn't agree on whether to ask.", know = "secret" },
              } },
        },
    },

    -- How the world changes a place.
    places = {
        tavern = {
            hand = { label = "Owned by the Velvet Hand",
                line = "The Crooked Kettle. A velvet curtain hangs where Gus's notice board was, and Gus doesn't meet their eyes." },
        },
        millbrook_walls = {
            mended = { label = "Mended",
                line = "Millbrook's walls, whole again, every stone carried up by someone in town. Hob's name is chalked on one." },
        },
        chapel = {
            blessed = { label = "Blessed again",
                line = "The roadside chapel, blessed again. Candles in every niche, and the air under the altar is still." },
        },
        market = {
            spurs = { label = "The Spurs' crowd",
                line = "Market square. Somebody's selling Silver Spurs capes. Children are singing the song." },
        },
    },

    -- The group chat answers the DM's news. The first player whose key matches the faction
    -- speaks (it's their thread); otherwise anyone at the table, in their own voice.
    reactions = {
        warband = { dev = { "Kessrick. Finally. Thursday can't come soon enough.", "Brannoc is sharpening his sword. Just so everyone knows." } },
        velvet_hand = { jess = { "Oh no. Oh no no no. Pip is fine. Pip is FINE.", "Pip would like to file a complaint about this news." } },
        old_faith = { sam = { "Oswin says a prayer for the chapel. Also I'm bringing crisps.", "That's Oswin's lot! Kind of. He'll want to help." } },
        millbrook = { mara = { "Writing this down. Thessaly worries about these people.", "Okay that's lovely. Millbrook deserves nice things." } },
        any = {
            mara = { "Taking notes. This has to connect to something.", "Ooh. That's a clue. That's definitely a clue." },
            dev = { "Is it something I can hit?", "Cool cool cool. Can we fight it Thursday?" },
            jess = { "That's not ominous at all.", "Pip has questions. Pip has SO many questions." },
            sam = { "Uh oh. Snacks as usual Thursday?", "Oswin would like everyone to stay calm. Sam is panicking." },
        },
    },
}
