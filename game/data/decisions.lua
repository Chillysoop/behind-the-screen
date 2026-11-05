-- Decision cards that slide across the DM screen during game night.
-- Data only: tune freely.
--
-- type:      story, combat, rules, screen (behind the screen), pacing, table.
-- scenes:    scene types where the card can come up (nil = any).
-- actor:     archetypes to pick the acting player from, in order of preference.
-- text:      {actor}, {actor_char}, {other}, {other_char}, {cast}, {location}
--            and {lowest}, {lowest_char} (the least engaged player) are filled in.
--
-- Each option has effects: { "who", meter = change, ... } where who is
-- "all", "actor", "other", "others" (everyone but the actor), "lowest",
-- "arch:<archetype>" (full for primary, half for secondary) or "perceptive"
-- (scaled by how observant each player is).
-- Meters: spotlight, challenge, story, social, reward (tonight), fun,
-- boredom, and the long-term trust, suspicion, investment, commitment.
--
-- An option with a roll asks the DM to roll the d20, in the open or behind
-- the screen. "convenient" is the result a DM would be tempted to cook toward;
-- cooking toward it looks more suspicious. After the roll the DM rules on it
-- (game/data/rulings.lua).
--
-- where:     the card only comes up at a location with one of these settings (see
--            components.lua); a secret door needs walls.
-- actor_class: the card is about this class's player (Oswin's spells are Sam's call); it
--            only comes up when they're at the table.
-- roll.skill: the check the acting character makes (skills from game/rules/skills.lua; a
--            list means their best of those). roll.secret: the DM rolls it for them behind
--            the screen (a secret Perception check) instead of the player rolling it.
--
-- trigger:   cards with a trigger never come up at random; game night deals them
--            when the moment happens (a crit on the boss, a hidden roll that would
--            drop someone, a fight that drags on...). Their options can carry a
--            battle = "..." action that changes the fight, and cooked = true when
--            choosing it means overruling a hidden die.

return {
    types = {
        story = "Story", combat = "Combat", rules = "Rules", screen = "Behind the screen",
        pacing = "Pacing", table = "Table",
    },

    {
        -- The killing blow (M8, B4): a boss or a villain is about to fall. Who describes it?
        -- kb: "actor" (you ask them: the players describe it, and the one who landed it may pass it
        -- to a friend: night:kb_share), or "dm" (you, briefly). Who tells it is the players' choice,
        -- never the DM's (the playtest, November 3). What it's worth: night:kb_worth.
        id = "killing_blow", type = "combat", trigger = "killing_blow",
        actor = { "butt_kicker", "power_gamer" },
        title = "The killing blow",
        text = "{boss} is about to fall to {actor_char}. Do you describe the final hit, or hand it to the table?",
        options = {
            { label = "Ask {actor}: \"How do you want to do this?\"", kb = "actor",
              log = "You sit back: '{actor}, how do you want to do this?'",
              effects = { { "arch:butt_kicker", fun = 2 } } },
            { label = "Describe it yourself, quickly.", kb = "dm",
              log = "{boss} falls. You keep it short; the night moves on.",
              effects = { { "arch:storyteller", fun = -1 }, { "arch:butt_kicker", fun = -2 } } },
        },
    },

    {
        -- A player who landed the killing blow wants a friend to tell it (night:kb_share). Their idea;
        -- the DM only says whether it works at the table.
        id = "kb_share", type = "combat", trigger = "kb_share",
        actor = { "storyteller" },
        title = "Passing it on",
        text = "{actor} looks across the table at {other}. \"You've been waiting all night. You tell it: how does {actor_char}'s blow land?\"",
        options = {
            { label = "Sure. {other}, go ahead.", share = true,
              log = "{other} sits up. Everyone leans in.",
              effects = { { "all", social = 3 } } },
            { label = "Keep it {actor}'s. It was {friend_their} hit.", share = false,
              log = "'Nice thought, but that one's yours, {actor}.'",
              effects = { { "actor", fun = 1 }, { "others", fun = -1 } } },
        },
    },

    {
        -- The villain who gets away (M8, B6), when the story set it up (they've met before, or the
        -- scene has a complication to slip away through).
        id = "escape_earned", type = "combat", trigger = "escape_earned",
        actor = { "storyteller", "tactician" },
        title = "A way out",
        text = "{boss} is beaten, bleeding, and edging toward the way out they came in by. They planned for this.",
        options = {
            { label = "Let them go. They'll be back, and they'll remember.", battle = "escape",
              log = "{boss} is gone before anyone can stop {boss_them}. A last look back: this isn't over.",
              effects = { { "arch:storyteller", fun = 8, story = 6 }, { "arch:method_actor", fun = 4 }, { "arch:butt_kicker", fun = -3 },
                          { "arch:tactician", fun = 1 } } },
            { label = "No way out. Finish it.", battle = "let",
              log = "Brannoc gets to the door first. {boss} isn't leaving.",
              effects = { { "arch:butt_kicker", fun = 4 }, { "arch:tactician", fun = 3 } } },
        },
    },

    {
        id = "boss_crit", type = "combat", trigger = "boss_crit",
        actor = { "butt_kicker", "power_gamer" },
        title = "An early knockout",
        text = "{actor_char} is about to drop {boss} in round {round}. That's the villain you spent all week on.",
        options = {
            { label = "Let it drop. They earned it.", battle = "let",
              log = "{boss} crumples. {actor} stands on {friend_their} chair.",
              effects = { { "actor", spotlight = 16, fun = 8 }, { "arch:butt_kicker", fun = 5 }, { "arch:power_gamer", fun = 4 },
                          { "arch:tactician", challenge = -6 }, { "arch:storyteller", story = -4 } } },
            { label = "Second phase! It rises, angrier.", battle = "second_phase",
              log = "{boss}'s eyes flare. 'Is that all?'",
              effects = { { "all", challenge = 10 }, { "arch:tactician", fun = 5 }, { "arch:butt_kicker", fun = 4 },
                          { "perceptive", suspicion = 4, why = "the boss getting back up out of nowhere" } } },
            { label = "It falls, but reinforcements burst in.", battle = "reinforce",
              log = "{boss} falls, and a horn answers from the dark. More of them.",
              effects = { { "actor", spotlight = 10 }, { "all", challenge = 8 }, { "arch:casual", fun = -3 },
                          { "arch:instigator", fun = 4 } } },
        },
    },

    {
        id = "tactics", type = "combat", trigger = "tactics",
        actor = { "tactician", "butt_kicker" },
        title = "Who do they go after?",
        text = "{boss}'s side regroups. You're running them. Where do they throw their weight?",
        options = {
            { label = "Go for {squishy_char} in the back.", battle = "squishy",
              log = "They shove past the front line, eyes on {squishy_char}.",
              effects = { { "arch:tactician", fun = 4, challenge = 6 }, { "all", challenge = 4 }, { "arch:casual", fun = -2 } } },
            { label = "Spread the hits around. Keep it fair.", battle = "spread",
              log = "They pick their targets one at a time, nobody singled out.",
              effects = { { "arch:casual", fun = 3 }, { "all", trust = 2 } } },
            { label = "Everyone on {big_char}.", battle = "big",
              log = "Every blade turns toward {big_char}. {big} grins.",
              effects = { { "arch:butt_kicker", fun = 5, spotlight = 4 }, { "all", challenge = 3 } } },
        },
    },

    {
        id = "cornered", type = "combat", trigger = "cornered",
        actor = { "storyteller", "casual", "explorer" },
        title = "Cornered",
        text = "{target_count} enemies have {actor_char} pinned, and {actor_char} is down to {hp} hit points.",
        options = {
            { label = "Let the dice fall where they fall.", battle = "let",
              log = "You pick up the dice. {actor} covers {friend_their} eyes.",
              effects = { { "all", challenge = 6 }, { "arch:tactician", fun = 3, trust = 2 } } },
            { label = "They get distracted by something shiny.", battle = "distract",
              log = "Something glitters on the floor. Every one of them dives for it.",
              effects = { { "arch:instigator", fun = 4 }, { "arch:tactician", fun = -6, challenge = -6 }, { "perceptive", suspicion = 3, why = "monsters diving for something shiny" },
                          { "arch:casual", fun = 2 }, { "actor", fun = 2 } } },
        },
    },

    {
        id = "death_roll", type = "screen", trigger = "death_roll",
        actor = { "butt_kicker", "method_actor", "explorer", "instigator", "storyteller", "casual" },
        title = "A roll that could drop them",
        text = "Behind your screen, {target} hits {actor_char} for {damage}. That's enough to knock {actor_them} out cold. Nobody saw the die.",
        options = {
            { label = "Let it ride. Call the hit.", battle = "let",
              log = "You read out the damage. {actor} groans.",
              effects = { { "all", challenge = 6, trust = 1 }, { "arch:tactician", fun = 3 } } },
            { label = "Fudge it. The blow glances off.", battle = "fudge_miss", cooked = true, convenient = true,
              log = "'It... misses. Barely.'",
              effects = { { "actor", fun = 3 }, { "all", challenge = -4 }, { "arch:tactician", fun = -2 } } },
            { label = "Offer a deal: stay up, but with a scar.", battle = "deal",
              log = "{actor_char} stays on {actor_their} feet. The scar will be part of every story from now on.",
              canon = "{actor_char}'s scar from {target}",
              effects = { { "actor", spotlight = 12, story = 10, investment = 6 }, { "arch:storyteller", story = 6 },
                          { "arch:method_actor", fun = 6 } } },
        },
    },

    {
        id = "last_save", type = "screen", trigger = "last_save",
        actor = { "butt_kicker", "method_actor", "explorer", "instigator", "storyteller", "casual" },
        title = "The last death save",
        text = "{actor_char} just failed a third death save. By the rules, {actor_char} is dead. {actor} is staring at you.",
        options = {
            { label = "The rules stand. {actor_char} dies.", battle = "let",
              log = "The table goes very quiet. {actor} puts down {friend_their} dice.",
              canon = "{actor_char} died at {location}",
              effects = { { "actor", fun = -12, investment = 8 }, { "all", story = 14, challenge = 10, trust = 3 },
                          { "arch:tactician", fun = 4 } } },
            { label = "Fudge it. Call it a success.", battle = "fudge_save", cooked = true, convenient = true,
              log = "'Actually... that's a ten. You're stable.'",
              effects = { { "actor", fun = 6 }, { "perceptive", suspicion = 6, why = "the death save you fudged" }, { "arch:tactician", trust = -2 } } },
            { label = "A divine spark: Oswin's god answers.", battle = "miracle",
              log = "Light pours through the clouds. {actor_char} gasps awake.",
              canon = "the night Oswin's god answered",
              effects = { { "actor", fun = 8, story = 8 }, { "all", story = 8 }, { "arch:tactician", trust = -2 },
                          { "arch:storyteller", fun = 4 } } },
        },
    },

    {
        id = "dragging_fight", type = "pacing", trigger = "dragging",
        actor = { "tactician", "butt_kicker" },
        title = "Round {round}",
        text = "This fight is on round {round}. Everyone is tracking hit points on napkins, and {lowest} is checking the time.",
        options = {
            { label = "The enemies break and flee.", battle = "flee",
              log = "The last few turn tail and run.",
              effects = { { "arch:casual", fun = 4 }, { "arch:tactician", fun = -4 }, { "all", boredom = -6 } } },
            { label = "Speed it up: minions drop in one hit.", battle = "minions",
              log = "Minions now go down in one hit. The pace picks up.",
              effects = { { "all", boredom = -4 }, { "arch:tactician", trust = -2 }, { "arch:butt_kicker", fun = 2 } } },
            { label = "Push on. It's the climax.", battle = "let",
              log = "Nobody blinks. It ends when it ends.",
              effects = { { "arch:tactician", fun = 5, challenge = 6 }, { "arch:casual", boredom = 8 }, { "arch:method_actor", boredom = 6 } } },
        },
    },

    {
        id = "grapple", type = "rules", scenes = { "combat", "set_piece" }, fight_needs = "grapple",
        actor = { "tactician", "power_gamer" },
        title = "That's not how grappling works",
        text = "{actor} insists grappling doesn't work like that. The table goes quiet.",
        options = {
            { label = "Look it up. It takes a few minutes.", leans = "book", looked = true,
              log = "Pages rustle. Someone gets more chips.",
              effects = { { "arch:tactician", fun = 6, trust = 4 }, { "arch:butt_kicker", fun = -3, boredom = 6 },
                          { "all", challenge = 2 } } },
            { label = "Rule of cool. It works.", leans = "cool",
              log = "'Sure! Why not!' The grapple becomes a suplex.",
              effects = { { "arch:butt_kicker", fun = 5 }, { "arch:method_actor", fun = 3 }, { "arch:tactician", fun = -6, trust = -3 } } },
            { label = "Rules as written. Move on.", leans = "book",
              log = "You read the rule out loud and keep it moving.",
              effects = { { "arch:tactician", fun = 3, trust = 3 }, { "all", challenge = 2 }, { "arch:instigator", fun = -2 } } },
        },
    },

    {
        id = "stacking", type = "rules", scenes = { "combat", "set_piece" }, needs_class = "cleric", fight_needs = "bless",
        actor = { "power_gamer", "tactician" },
        title = "Do those stack?",
        text = "{actor} asks if Oswin's Bless stacks with his other bonus. Then: would a second Bless stack on top?",
        options = {
            -- SRD 5.2.1: different effects add together; the same spell's effects don't (p. 108).
            { label = "Different effects stack. The same spell twice doesn't.", leans = "book",
              log = "Bless and the bonus, yes. Bless twice, no. {actor} takes the win and the loss.",
              effects = { { "arch:tactician", trust = 4, fun = 2 }, { "actor", fun = 1 } } },
            { label = "Let both Blesses count, just this once.", leans = "cool",
              log = "The numbers get very large. {actor} is delighted.",
              effects = { { "actor", reward = 8, fun = 4 }, { "arch:tactician", trust = -3 }, { "all", challenge = -4 } } },
            { label = "Nothing stacks. Keep the numbers small.", leans = "strict",
              log = "'Nope. Pick one.' A dramatic sigh from {actor}. Someone mutters that the book says otherwise.",
              effects = { { "actor", fun = -4 }, { "arch:tactician", trust = -3 }, { "all", challenge = 2 } } },
        },
    },

    {
        -- Only when someone actually drinks one (A7): the fight deals it.
        id = "potion_action", type = "rules", trigger = "potion",
        actor = { "power_gamer", "tactician", "casual" },
        title = "How long does a potion take?",
        text = "{actor} drank a healing potion last turn, and wants to know: was that {actor_their} whole turn?",
        -- (When the potion went down someone else's throat: the one who gave it asks. Round three heard
        -- "Jess drank a healing potion" when Pip had fed it to Brannoc.)
        text_given = "{actor} gave {other_char} a healing potion last turn, and wants to know: was that {actor_their} whole turn?",
        options = {
            { label = "A Bonus Action, like the current rules say.", leans = "book",
              log = "Glug, then they still get to swing. Everyone approves.",
              effects = { { "arch:tactician", trust = 3 }, { "actor", fun = 3 } } },
            { label = "A full action. Old school.", leans = "strict",
              log = "'In MY day, potions took an action.' Some grumbling.",
              effects = { { "actor", fun = -3 }, { "all", challenge = 3 }, { "arch:tactician", trust = -2 } } },
            { label = "Bonus Action, but they have to roll for the heal.",
              log = "A compromise. The dice decide how much it helps.",
              effects = { { "all", challenge = 2 }, { "arch:power_gamer", fun = 2 } } },
        },
    },

    {
        id = "flanking", type = "rules", scenes = { "combat", "set_piece" }, actor_class = "fighter", fight_needs = "melee",
        actor = { "tactician", "power_gamer" },
        title = "Flanking",
        text = "{actor} moves {actor_char} round behind {boss}. 'That's flanking. I get Advantage, right?'",
        options = {
            { label = "No flanking in these rules.", leans = "book",
              log = "'Not in the core rules. Nice positioning, though.'",
              effects = { { "arch:tactician", trust = 3 }, { "actor", fun = -2 } } },
            { label = "House rule: flanking gives Advantage.", leans = "house",
              log = "A new index card goes on the wall: HOUSE RULE: FLANKING.",
              canon = "house rule: flanking gives Advantage",
              effects = { { "arch:tactician", fun = 5 }, { "arch:power_gamer", fun = 4 }, { "all", challenge = -3 } } },
            { label = "Give them a +1 for being clever.", leans = "cool",
              log = "'A +1. For style.' {actor} pumps a fist.",
              effects = { { "actor", fun = 4, spotlight = 4 }, { "arch:tactician", trust = -1 } } },
        },
    },

    {
        id = "split_party", type = "pacing", scenes = { "exploration", "mystery", "social" },
        -- (Never with danger in the room, never twice in two sessions: the second playtest review.)
        headache = true, needs = { players = 3, archetype = { "explorer", "instigator" }, calm = true, every = 2, every_key = "split_party" },
        actor = { "explorer", "instigator", "storyteller" },
        other = { "butt_kicker", "tactician", "casual" },
        title = "Splitting the party",
        text = "{actor_char} wants to look around on {actor_their} own. {other_char} heads off the other way. Both are already walking.",
        options = {
            { label = "Let them split and cut between them.", split = true,
              sub = "Until this scene's done they're apart: a fight here starts without them, and they come running.",
              log = "You cut back and forth like a heist movie.",
              effects = { { "arch:explorer", fun = 5 }, { "arch:method_actor", fun = 3 }, { "all", boredom = 3 } } },
            -- The way back to the card (the card-led playtest, October 16: none of the three named it).
            { label = "Steer them back: {goal}.",
              log = "You give it a minute, then remind them why they're here. They regroup.",
              effects = { { "all", story = 3 }, { "arch:tactician", fun = 2 }, { "arch:explorer", fun = -2 } } },
            { label = "Call a vote at the table.",
              log = "Hands go up. {actor_char}'s way wins, narrowly.",
              effects = { { "all", social = 4 }, { "arch:casual", fun = 3 } } },
        },
    },

    {
        id = "stuck_puzzle", type = "pacing", scenes = { "puzzle" },
        headache = true, needs = { setbacks = 1 },   -- they really are stuck
        actor = { "tactician", "storyteller" },
        title = "Twenty minutes stuck",
        text = "They've been stuck on this one for twenty minutes. {lowest} has started guessing at random.",
        options = {
            { label = "Give them a hint through an NPC.",
              log = "You drop a hint through the nearest voice in the room. Faces light up.",
              effects = { { "all", boredom = -6 }, { "arch:tactician", fun = -2 }, { "arch:casual", fun = 4 } } },
            { label = "Let them struggle. They'll get it.",
              roll = { dc = 13, convenient = "success", skill = { "investigation", "arcana", "history" },
                       success = { log = "{actor_char} gasps. 'Oh. OH.' The table erupts.",
                                   effects = { { "actor", spotlight = 14, fun = 6 }, { "arch:tactician", fun = 6 }, { "all", challenge = 4 } } },
                       fail = { log = "Silence. Someone suggests just hitting it.",
                                effects = { { "all", boredom = 8 }, { "arch:tactician", challenge = 4 } } } } },
            { label = "It works out on its own. Move on.",
              log = "It just clicks into place. Groans all round.",
              cut = true,
              effects = { { "arch:butt_kicker", fun = 3 }, { "arch:tactician", fun = -4, trust = -2 } } },
        },
    },

    -- Headaches (M8, B4): classic table problems. Each plays only when its situation actually
    -- happened (needs, checked in game/model/night.lua headache_ok), and comes back on later
    -- nights instead of being spent.
    {
        -- (Only once something's come up worth looking up: a condition from a fight earlier tonight.
        -- F14: "Looking it up..." with no question asked.)
        id = "rules_lookup", type = "pacing", scenes = { "combat", "set_piece" }, headache = true,
        needs = { archetype = { "power_gamer", "tactician" }, question = true },
        actor = { "power_gamer", "tactician" },
        title = "Looking it up",
        text = "{actor} is sure there's a rule for {question}, after the last fight. The book is out. Pages are turning. Everyone else is watching the pages turn.",
        options = {
            { label = "Let them find it.", table_min = 6, looked = true,
              log = "Six minutes later: they were right. Mostly.",
              effects = { { "arch:power_gamer", fun = 5 }, { "arch:tactician", trust = 2 }, { "arch:butt_kicker", boredom = 6 } } },
            { label = "Make a call and look it up after.",
              log = "'For tonight it works like this. I'll check by Thursday.' Fair enough.",
              effects = { { "all", trust = 1, boredom = -2 }, { "arch:power_gamer", fun = -1 } } },
            { label = "Rule of cool.",
              log = "It works because it's awesome. The book closes.",
              effects = { { "arch:instigator", fun = 4 }, { "arch:butt_kicker", fun = 3 }, { "arch:power_gamer", fun = -3, trust = -1 } } },
        },
    },

    -- Table conflicts (M6) -------------------------------------------------------------
    -- Dealt by game night when a conflict is brewing (game/model/social.lua). An option's
    -- conflict field moves it: pressure up or down, progress toward settling it at the
    -- table, or a fix right there (resolve), or a promise to look it up (promise).

    {
        id = "pip_show", type = "table", trigger = "conflict_spotlight", conflict = "spotlight",
        actor = { "method_actor" },
        title = "The Pip show",
        text = "{actor} has been doing Pip's voice at {cast} for ten minutes straight. {lowest} hasn't said a word since the snacks came out.",
        options = {
            { label = "Let Pip run with it.",
              log = "Pip charms, wheedles and juggles. It's a great show. Most of the table is watching it.",
              conflict = { pressure = 8 },
              effects = { { "actor", spotlight = 10, social = 4, fun = 3 }, { "others", boredom = 5 } } },
            { label = "Turn to {lowest_char}: 'What are you doing while this happens?'",
              log = "Every head turns to {lowest_char}.",
              spotlight_lowest = true,
              conflict = { pressure = -10, progress = 1 },
              effects = { { "lowest", spotlight = 12 }, { "actor", fun = -2 } } },
            { label = "Have {cast} ask Pip to vouch for a friend.",
              log = "'And who are YOUR friends, little one?' Pip has to bring the others in.",
              conflict = { pressure = -8, progress = 1 },
              effects = { { "all", spotlight = 4, social = 4 }, { "actor", fun = 2 } } },
        },
    },

    {
        id = "rules_spat", type = "table", trigger = "conflict_rules", conflict = "rules",
        actor = { "butt_kicker" },
        other = { "tactician" },
        title = "Dev and Sam are at it again",
        text = "{actor} and {other} have been arguing about {topic} since the last fight started. The monsters are politely waiting.",
        options = {
            { label = "Make a call and move on.",
              log = "You make the call. Somebody at the table sighs very loudly.",
              conflict = { pressure = 6 },
              effects = { { "all", boredom = -2 }, { "actor", fun = -1 }, { "other", fun = -1 } } },
            { label = "Table vote, right now. Majority rules, and it goes on the wall.",
              log = "Hands go up. It's settled, and nobody can say it wasn't fair.",
              conflict = { resolve = "vote" },
              effects = { { "all", trust = 2, social = 3 }, { "all", boredom = 2 } } },
            { label = "Quick call now. I'll look it up before next week.",
              log = "'Quick call now, and I'll check the book before next Thursday.' {other} writes it down.",
              conflict = { promise = "look_it_up", pressure = -4 },
              effects = { { "other", trust = 2 }, { "all", boredom = -2 } } },
        },
    },

}
