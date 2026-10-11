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
        id = "bribe", type = "story", scenes = { "social", "mystery", "downtime" },
        actor = { "instigator", "method_actor" },
        title = "Off the script",
        text = "{actor_char} slides a fat purse across the table to the person you wrote as completely unbribable.",
        options = {
            { label = "Yes, and... it works. They spill a secret.",
              log = "The purse vanishes. 'You didn't hear this from me...'",
              effects = { { "actor", spotlight = 14 }, { "arch:instigator", fun = 6 }, { "arch:method_actor", fun = 4 },
                          { "arch:storyteller", fun = -4 }, { "all", story = 4 } } },
            { label = "Yes, but... they take it and tip off the enemy.",
              log = "They take the coin, smile, and send a runner the moment the party leaves.",
              effects = { { "actor", spotlight = 8 }, { "all", challenge = 6, story = 3 }, { "arch:instigator", fun = 8 },
                          { "arch:tactician", fun = 3 } } },
            { label = "No, and... they're insulted. Roll to talk out of it.",
              roll = { dc = 13, convenient = "success", skill = { "persuasion", "deception" },
                       success = { log = "{actor_char} turns it into a joke. Somehow it lands.",
                                   effects = { { "actor", spotlight = 12 }, { "all", social = 6 }, { "arch:method_actor", fun = 6 } } },
                       fail = { log = "Steel comes out. Nobody is laughing now.",
                                effects = { { "actor", spotlight = 4 }, { "all", challenge = 8 }, { "arch:storyteller", story = 4 },
                                            { "arch:butt_kicker", fun = 5 } } } } },
        },
    },

    {
        id = "befriend_villain", type = "story", scenes = { "social", "mystery" },
        actor = { "method_actor", "storyteller", "casual" },
        needs_cast = "hostile",   -- A11: only when the scene's person is against the party (their data says so)
        title = "Hold on, let's talk",
        text = "{actor_char} stops everything and asks {cast} what {they_want}.",
        options = {
            { label = "Let it work. There's a sad story behind it.",
              log = "{Cast} {hesitates|hesitate}, then {starts|start} talking about how it all began.",
              effects = { { "arch:method_actor", fun = 8 }, { "arch:storyteller", story = 10 }, { "arch:butt_kicker", fun = -8 },
                          { "all", social = 6 }, { "actor", spotlight = 10 } } },
            { label = "They talk, then it turns ugly anyway.",
              log = "A tense, honest exchange. Then {cast} {sighs and reaches|sigh and reach} for a blade.",
              effects = { { "all", story = 4, social = 4, challenge = 6 }, { "actor", spotlight = 6 } } },
            { label = "{Cast} {laughs and attacks|laugh and attack}.",
              log = "'Cute.' {Cast} {lunges|lunge}.",
              effects = { { "arch:butt_kicker", fun = 8 }, { "arch:method_actor", fun = -6 }, { "all", challenge = 10 } } },
        },
    },

    {
        id = "wild_theory", type = "story", scenes = { "mystery", "exploration", "social", "puzzle" },
        actor = { "storyteller", "explorer" },
        title = "Their theory is better", once = true,
        retired = true,   -- B5: Steal the theory (the chat's theories, pinned to the prep board) replaces it
        text = "{actor_char} lays out a wild theory about who is behind it all. Honestly, it's better than what you wrote.",
        options = {
            { label = "Steal it. Their theory is now true.",
              log = "You keep a straight face and quietly rewrite your notes.",
              canon = "{actor}'s theory became the truth",
              effects = { { "actor", spotlight = 12 }, { "arch:storyteller", story = 10, fun = 6 }, { "all", investment = 4 } } },
            { label = "Keep your plot, but let them know they're close.",
              log = "A knowing look from the NPC. The table erupts.",
              effects = { { "arch:storyteller", story = 6 }, { "arch:tactician", fun = 3 }, { "all", story = 4 } } },
            { label = "Shut it down. They're wrong.",
              log = "'Interesting theory,' says the NPC, in a way that means no.",
              effects = { { "actor", fun = -5 }, { "arch:storyteller", story = -2 } } },
        },
    },

    {
        -- The killing blow (M8, B4): a boss or a villain is about to fall. Who describes it?
        -- kb: who gets it ("actor", "other": whoever's waited longest, "dm": you, briefly).
        id = "killing_blow", type = "combat", trigger = "killing_blow",
        actor = { "butt_kicker", "power_gamer" },
        title = "The killing blow",
        text = "{boss} is about to fall to {actor_char}. Who gets to describe the final hit?",
        options = {
            { label = "{actor_char} landed it. {actor}, how do you do this?", kb = "actor",
              log = "You hand it over: '{actor}, how do you want to do this?'",
              effects = { { "arch:butt_kicker", fun = 2 } } },
            { label = "Hand it to {other_char}. {other} hasn't had one in a while.", kb = "other",
              log = "'{other}, you've been waiting all night. Take it.'",
              effects = { { "all", social = 3 }, { "actor", fun = -1 } } },
            { label = "Describe it yourself, quickly.", kb = "dm",
              log = "{boss} falls. You keep it short; the night moves on.",
              effects = { { "arch:storyteller", fun = -1 }, { "arch:butt_kicker", fun = -2 } } },
        },
    },

    {
        -- The villain who gets away (M8, B6). Earned: the story set it up (they've met before,
        -- or the scene has a complication to slip away through). Cheap: out of nowhere.
        id = "escape_earned", type = "combat", trigger = "escape_earned",
        actor = { "storyteller", "tactician" },
        title = "A way out",
        text = "{boss} is beaten, bleeding, and edging toward the way out they came in by. They planned for this.",
        options = {
            { label = "Let them go. They'll be back, and they'll remember.", battle = "escape",
              log = "{boss} is gone before anyone can stop them. A last look back: this isn't over.",
              effects = { { "arch:storyteller", fun = 8, story = 6 }, { "arch:method_actor", fun = 4 }, { "arch:butt_kicker", fun = -3 },
                          { "arch:tactician", fun = 1 } } },
            { label = "No way out. Finish it.", battle = "let",
              log = "Brannoc gets to the door first. {boss} isn't leaving.",
              effects = { { "arch:butt_kicker", fun = 4 }, { "arch:tactician", fun = 3 } } },
        },
    },
    {
        id = "escape_cheap", type = "combat", trigger = "escape_cheap",
        actor = { "storyteller", "tactician" },
        title = "Out of nowhere",
        text = "{boss} is nearly done. You could have them vanish, but nothing in the story has set up a way out.",
        options = {
            { label = "A puff of smoke, and they're gone.", battle = "escape",
              log = "Smoke. Coughing. {boss} is gone. Someone says 'oh, come ON'.",
              effects = { { "arch:storyteller", fun = 3, story = 3 }, { "arch:tactician", fun = -6, trust = -3 },
                          { "arch:power_gamer", fun = -3 } } },
            { label = "No way out. Finish it.", battle = "let",
              log = "There's nowhere for {boss} to run.",
              effects = { { "arch:butt_kicker", fun = 3 }, { "arch:tactician", fun = 3, trust = 1 } } },
        },
    },

    {
        id = "boss_crit", type = "combat", trigger = "boss_crit",
        actor = { "butt_kicker", "power_gamer" },
        title = "An early knockout",
        text = "{actor_char} is about to drop {boss} in round {round}. That's the villain you spent all week on.",
        options = {
            { label = "Let it drop. They earned it.", battle = "let",
              log = "{boss} crumples. {actor} stands on their chair.",
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
              log = "You pick up the dice. {actor} covers their eyes.",
              effects = { { "all", challenge = 6 }, { "arch:tactician", fun = 3, trust = 2 } } },
            { label = "They get distracted by something shiny.", battle = "distract",
              log = "Something glitters on the floor. Every one of them dives for it.",
              effects = { { "arch:instigator", fun = 4 }, { "arch:tactician", fun = -6, challenge = -6 }, { "perceptive", suspicion = 3, why = "monsters diving for something shiny" },
                          { "arch:casual", fun = 2 }, { "actor", fun = 2 } } },
            { label = "A friend dives in to save them.", battle = "rescue",
              log = "{other_char} barrels in like a runaway cart.",
              effects = { { "all", social = 4, challenge = 4 }, { "other", spotlight = 10, fun = 4 } } },
        },
    },

    {
        id = "death_roll", type = "screen", trigger = "death_roll",
        actor = { "butt_kicker", "method_actor", "explorer", "instigator", "storyteller", "casual" },
        title = "A roll that could drop them",
        text = "Behind your screen, {target} hits {actor_char} for {damage}. That's enough to knock them out cold. Nobody saw the die.",
        options = {
            { label = "Let it ride. Call the hit.", battle = "let",
              log = "You read out the damage. {actor} groans.",
              effects = { { "all", challenge = 6, trust = 1 }, { "arch:tactician", fun = 3 } } },
            { label = "Fudge it. The blow glances off.", battle = "fudge_miss", cooked = true, convenient = true,
              log = "'It... misses. Barely.'",
              effects = { { "actor", fun = 3 }, { "all", challenge = -4 }, { "arch:tactician", fun = -2 } } },
            { label = "Offer a deal: stay up, but with a scar.", battle = "deal",
              log = "{actor_char} stays on their feet. The scar will be part of every story from now on.",
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
              log = "The table goes very quiet. {actor} puts down their dice.",
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
        id = "parley", type = "story", trigger = "parley",
        actor = { "method_actor", "storyteller", "casual" },
        title = "Hold on, let's talk",
        text = "{boss} is bleeding and backed into a corner. {actor_char} lowers their weapon and asks what {boss} actually wants.",
        options = {
            { label = "Let it work. {boss} surrenders.", battle = "surrender",
              log = "{boss} hesitates, then drops their weapon and starts talking.",
              canon = "{boss} owes the party their life",
              effects = { { "arch:method_actor", fun = 8 }, { "arch:storyteller", story = 10 }, { "arch:butt_kicker", fun = -6 },
                          { "all", social = 6 }, { "actor", spotlight = 10 } } },
            { label = "They talk, then it turns ugly anyway.", battle = "let",
              log = "A tense, honest exchange. Then {boss} sighs and raises a blade.",
              effects = { { "all", story = 4, social = 4, challenge = 6 }, { "actor", spotlight = 6 } } },
            { label = "{boss} laughs and attacks.", battle = "let",
              log = "'Cute.' {boss} lunges.",
              effects = { { "arch:butt_kicker", fun = 8 }, { "arch:method_actor", fun = -6 }, { "all", challenge = 10 } } },
        },
    },

    {
        id = "running_late", type = "pacing", trigger = "late",
        actor = { "casual", "tactician" },
        title = "It's getting late",
        text = "It's past ten. {lowest} has work tomorrow and keeps glancing at the clock. You still have a whole scene.",
        options = {
            { label = "End early, on a cliffhanger.", cliffhanger = true,
              log = "'And that's where we'll stop for tonight.' A chorus of groans.",
              effects = { { "all", story = 6, boredom = -6 }, { "arch:storyteller", fun = 4 }, { "arch:butt_kicker", fun = -3 } } },
            { label = "Speed through the last scene.", cut = true,
              log = "You skip ahead to the good part.",
              effects = { { "all", boredom = -4 }, { "arch:method_actor", fun = -3 } } },
            { label = "Push through. It's worth it.",
              log = "Someone makes coffee. You keep going.",
              effects = { { "lowest", commitment = -3, fun = -3 }, { "arch:butt_kicker", fun = 3 } } },
        },
    },

    {
        id = "grapple", type = "rules", scenes = { "combat", "set_piece", "exploration" },
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
        id = "stacking", type = "rules", scenes = { "combat", "set_piece" }, needs_class = "cleric",
        actor = { "power_gamer", "tactician" },
        title = "Do those stack?",
        text = "{actor} asks if Oswin's Bless stacks with their other bonus. Then: does a second Bless, from a scroll, stack on top?",
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
        id = "secret_door", type = "screen", scenes = { "exploration", "puzzle", "mystery" },
        where = { "indoor", "ruin", "under" },
        actor = { "explorer", "tactician", "storyteller" },
        title = "They're walking past it",
        text = "The party is about to walk right past the secret door you spent an hour designing.",
        options = {
            { label = "Let them miss it.",
              log = "The party moves on. The door stays a secret, for now.",
              effects = { { "arch:explorer", fun = -3 }, { "all", story = -2, trust = 1 } } },
            { label = "Have the torchlight flicker toward it.",
              log = "The flame bends toward the wall. {actor} notices.",
              effects = { { "arch:explorer", fun = 6, reward = 6 }, { "perceptive", suspicion = 2, why = "the torchlight pointing the way" }, { "all", story = 4 } } },
            { label = "Roll a secret Perception check for them.",
              roll = { dc = 14, convenient = "success", skill = "perception", secret = true,
                       success = { log = "{actor_char} stops. 'Wait. This wall is hollow.'",
                                   effects = { { "arch:explorer", fun = 8, reward = 8 }, { "all", story = 6 }, { "actor", spotlight = 8 } } },
                       fail = { log = "Nobody notices a thing. You quietly turn the page.",
                                effects = { { "all", story = -1 } } } } },
        },
    },

    {
        id = "shopping", type = "pacing", scenes = { "downtime", "social", "exploration" },
        where = { "town" },
        -- A headache (B4): only once they've actually been shopping (a market or downtime tonight).
        headache = true, needs = { been = { "town", "crowd", "shop" }, or_type = { "downtime" } },
        actor = { "method_actor", "casual" },
        title = "Fifteen minutes of shopping",
        text = "The shopping trip is entering its fifteenth minute. {lowest} is building a tower out of dice.",
        options = {
            { label = "Cut to the next scene.",
              log = "'Later that evening...' You move things along.",
              cut = true,
              effects = { { "arch:butt_kicker", fun = 5 }, { "arch:casual", fun = -3 }, { "arch:method_actor", spotlight = -4 } } },
            { label = "Let it breathe.",
              log = "The haggling continues. Someone buys a hat shaped like a duck.",
              effects = { { "arch:casual", social = 8, fun = 4 }, { "arch:method_actor", fun = 4 }, { "arch:butt_kicker", boredom = 8 } } },
            -- Every call shows (A11): the trouble is real, and it's rolled for on the table.
            { label = "Trouble at the door: a debt collector and two friends.",
              roll = { dc = 12, skill = { "intimidation", "athletics", "persuasion" },
                       success = { log = "{actor_char} meets them at the door. They think better of it, and leave a name: whoever sent them.",
                                   effects = { { "all", challenge = 6 }, { "arch:instigator", fun = 6 }, { "arch:butt_kicker", fun = 6 },
                                               { "actor", spotlight = 8 }, { "arch:casual", fun = -2 } } },
                       fail = { log = "A scuffle among the hats. Nobody's badly hurt, but the shopkeeper adds the damage to the bill.",
                                effects = { { "all", challenge = 8 }, { "arch:butt_kicker", fun = 6 }, { "arch:casual", fun = -4 } } } } },
        },
    },

    {
        id = "one_slot", type = "rules", scenes = { "combat", "set_piece" }, actor_class = "cleric",
        actor = { "power_gamer", "tactician" },
        title = "Two spells, one turn",
        text = "{actor} wants {actor_char} to cast Healing Word and Guiding Bolt on the same turn. 'One's a bonus action!'",
        options = {
            { label = "Rules as written: one spell slot per turn.", leans = "book",
              log = "You point at the rule. Only one spell slot a turn, whatever the action.",
              effects = { { "arch:tactician", fun = 4, trust = 4 }, { "arch:power_gamer", fun = -3 }, { "all", challenge = 2 } } },
            { label = "Sure, go for it.", leans = "cool",
              log = "Two spells, one turn. The goblins look offended.",
              effects = { { "arch:power_gamer", fun = 5 }, { "all", challenge = -4 }, { "arch:tactician", trust = -3 } } },
            { label = "Look it up together.", leans = "book", looked = true,
              log = "Three phones come out. The rule is found, eventually.",
              effects = { { "arch:tactician", fun = 3, trust = 3 }, { "arch:butt_kicker", boredom = 6 }, { "all", social = 2 } } },
        },
    },

    {
        -- Only when someone actually drinks one (A7): the fight deals it.
        id = "potion_action", type = "rules", trigger = "potion",
        actor = { "power_gamer", "tactician", "casual" },
        title = "How long does a potion take?",
        text = "{actor} drinks a healing potion and asks if that's their whole turn.",
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
        id = "flanking", type = "rules", scenes = { "combat", "set_piece" }, actor_class = "fighter",
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
        id = "bartender_name", type = "story", scenes = { "social", "downtime", "mystery" },
        where = { "tavern" },
        actor = { "method_actor", "explorer", "instigator" },
        title = "What's the bartender's name?",
        text = "{actor} asks the bartender's name. Then where he grew up. Then his greatest regret. You wrote none of this.",
        options = {
            { label = "Make it up on the spot: Gus Jr., who hates elves.",
              log = "'Name's Gus. Junior. And I don't serve elves.' The elf at the table gasps.",
              canon = "Gus Jr., who hates elves",
              effects = { { "actor", spotlight = 10, fun = 5 }, { "arch:method_actor", fun = 4 }, { "all", social = 6 } } },
            { label = "Deflect: 'Just a bartender.'",
              log = "'Just a bartender.' {actor} looks a little crushed.",
              effects = { { "actor", fun = -4 }, { "arch:butt_kicker", fun = 2 } } },
            { label = "He has a secret, and he's scared.",
              log = "He goes pale. 'Not here. Meet me out back.'",
              canon = "the bartender's secret",
              effects = { { "actor", spotlight = 8 }, { "arch:storyteller", story = 8 }, { "arch:explorer", fun = 4 }, { "all", story = 4 } } },
        },
    },

    {
        id = "adopt_pet", type = "story", scenes = { "exploration", "downtime", "social" },
        actor = { "method_actor", "casual", "instigator" },
        title = "Can we keep it?",
        text = "{actor_char} finds a scruffy creature in a crate and wants to adopt it. Immediately.",
        options = {
            { label = "Yes. It's the party's pet now.",
              log = "The creature is named before you can blink. It has a tiny hat by the end of the scene.",
              canon = "the party pet",
              effects = { { "actor", fun = 6 }, { "arch:casual", fun = 4 }, { "all", social = 6 } } },
            { label = "It bites them and runs off.",
              log = "Chomp. Gone. {actor_char} is heartbroken.",
              effects = { { "actor", fun = -3 }, { "arch:instigator", fun = 3 } } },
            { label = "Roll to see if it trusts them.",
              roll = { dc = 12, convenient = "success", skill = "animal_handling",
                       success = { log = "It sniffs {actor_char}'s hand, then climbs into their hood.",
                                   effects = { { "actor", fun = 6, spotlight = 6 }, { "all", social = 4 } } },
                       fail = { log = "It hisses and vanishes into the dark.",
                                effects = { { "actor", fun = -2 }, { "all", story = 2 } } } } },
        },
    },

    {
        id = "split_party", type = "pacing", scenes = { "exploration", "mystery", "social" },
        headache = true, needs = { players = 3, archetype = { "explorer", "instigator" } },
        actor = { "explorer", "instigator", "storyteller" },
        other = { "butt_kicker", "tactician", "casual" },
        title = "Splitting the party",
        text = "{actor_char} wants to look around on their own. {other_char} heads off the other way. Both are already walking.",
        options = {
            { label = "Let them split and cut between them.",
              log = "You cut back and forth like a heist movie.",
              effects = { { "arch:explorer", fun = 5 }, { "arch:method_actor", fun = 3 }, { "all", boredom = 3 } } },
            { label = "Something makes them regroup.",
              log = "A scream from up ahead. Everyone runs the same way.",
              effects = { { "all", challenge = 4 }, { "arch:tactician", fun = 2 }, { "arch:explorer", fun = -2 } } },
            { label = "Call a vote at the table.",
              log = "Hands go up. {actor_char}'s way wins, narrowly.",
              effects = { { "all", social = 4 }, { "arch:casual", fun = 3 } } },
        },
    },

    {
        id = "stuck_puzzle", type = "pacing", scenes = { "puzzle", "mystery" },
        headache = true, needs = { setbacks = 1 },   -- they really are stuck
        actor = { "tactician", "storyteller" },
        title = "Twenty minutes on one riddle",
        text = "They've been stuck on the riddle for twenty minutes. {lowest} has started guessing random words.",
        options = {
            { label = "Give them a hint through an NPC.",
              log = "A voice from the dark: 'Have you tried reading it backwards?'",
              effects = { { "all", boredom = -6 }, { "arch:tactician", fun = -2 }, { "arch:casual", fun = 4 } } },
            { label = "Let them struggle. They'll get it.",
              roll = { dc = 13, convenient = "success", skill = { "investigation", "arcana", "history" },
                       success = { log = "{actor_char} gasps. 'It's a MAP!' The table erupts.",
                                   effects = { { "actor", spotlight = 14, fun = 6 }, { "arch:tactician", fun = 6 }, { "all", challenge = 4 } } },
                       fail = { log = "Silence. Someone suggests they just break the door.",
                                effects = { { "all", boredom = 8 }, { "arch:tactician", challenge = 4 } } } } },
            { label = "The door just opens. Move on.",
              log = "Click. It was never locked. Groans all round.",
              cut = true,
              effects = { { "arch:butt_kicker", fun = 3 }, { "arch:tactician", fun = -4, trust = -2 } } },
        },
    },

    {
        id = "pizza", type = "table", table_only = true,
        actor = { "casual", "butt_kicker" },
        title = "The pizza's here",
        text = "The doorbell. Pizza. {lowest} is already halfway out of their chair, and the scene is just getting going.",
        options = {
            { label = "Break now. Pizza waits for no one.", table_min = 20,
              log = "Twenty minutes of pizza and gossip. Everyone comes back happy and a bit sleepy.",
              effects = { { "all", social = 8, fun = 3, boredom = -8 }, { "arch:butt_kicker", challenge = -3 } } },
            { label = "Eat at the table and keep playing.",
              log = "Greasy fingers on character sheets. The game goes on.",
              effects = { { "all", fun = 2 }, { "arch:tactician", fun = -2 }, { "arch:casual", fun = 3 } } },
            { label = "Finish the scene first.",
              log = "'Five more minutes!' The pizza goes cold on the counter.",
              effects = { { "arch:storyteller", fun = 2 }, { "lowest", fun = -3, boredom = 4 } } },
        },
    },

    {
        id = "phone", type = "table", table_only = true,
        actor = { "power_gamer" },
        title = "Losing the table",
        text = "{lowest} is on their phone, and two others are side-chatting about work.",
        options = {
            { label = "Give {lowest_char} the spotlight.",
              log = "An NPC turns to {lowest_char}: 'You. What do you think?'",
              spotlight_lowest = true,
              effects = { { "lowest", spotlight = 14 } } },
            { label = "Snack break!", table_min = 10,
              log = "Chips are refilled. Somebody puts on the good playlist.",
              effects = { { "all", social = 8, fun = 3, boredom = -8 } } },
            { label = "Let it go.",
              log = "You keep going. Some of the table is still with you.",
              effects = { { "lowest", commitment = -3, boredom = 4 } } },
        },
    },

    {
        id = "voices", type = "table", table_only = true,
        actor = { "method_actor", "instigator", "storyteller" },
        other = { "method_actor", "storyteller", "instigator", "casual" },
        title = "The two-person show",
        text = "{actor} and {other} have been arguing in character for ten minutes. Everyone else is watching.",
        options = {
            { label = "Let them have it.",
              log = "It ends with {actor_char} and {other_char} sworn enemies, or best friends. Unclear.",
              effects = { { "actor", spotlight = 10, social = 6 }, { "other", spotlight = 10, social = 6 }, { "arch:butt_kicker", boredom = 6 } } },
            { label = "Pull everyone in with an NPC.",
              log = "Gus wanders over: 'What are we arguing about?' Now everyone has an opinion.",
              effects = { { "all", social = 6, spotlight = 3 } } },
            { label = "Cut it with a monster.",
              log = "A crossbow bolt thunks into the table between them.",
              effects = { { "arch:butt_kicker", fun = 6 }, { "actor", fun = -4 }, { "all", challenge = 4 } } },
        },
    },

    -- Headaches (M8, B4): classic table problems. Each plays only when its situation actually
    -- happened (needs, checked in game/model/night.lua headache_ok), and comes back on later
    -- nights instead of being spent.
    {
        id = "plan_40", type = "pacing", scenes = { "combat", "set_piece" }, headache = true,
        needs = { archetype = { "tactician" }, before_fight = true },
        actor = { "tactician" },
        title = "The forty-minute plan",
        text = "{actor} has a plan. It has phases. It has a diagram. It is now forty minutes old, and the goblins are still waiting.",
        options = {
            { label = "Let the plan play out. It's their moment.", table_min = 10,
              log = "The plan unfolds. Parts of it even work. {actor_char} is radiant.",
              effects = { { "arch:tactician", fun = 8 }, { "actor", spotlight = 10 }, { "arch:butt_kicker", boredom = 8 },
                          { "arch:casual", boredom = 5 } } },
            { label = "The goblins get bored and attack first.",
              log = "A spear sails out of the dark mid-sentence. Plan B it is.",
              effects = { { "arch:butt_kicker", fun = 6 }, { "all", challenge = 5 }, { "arch:tactician", fun = -4 } } },
            { label = "Give them one minute, out loud. Then go.", table_min = 1,
              log = "'Sixty seconds.' The plan gets a lot simpler, fast.",
              effects = { { "all", fun = 2, boredom = -4 }, { "arch:tactician", fun = -1 } } },
        },
    },
    {
        id = "forgot_sheet", type = "table", table_only = true, headache = true,
        needs = { first_scene = true, archetype = { "casual", "instigator" } },
        actor = { "casual", "instigator" },
        title = "Who has my character sheet?",
        text = "{actor} has forgotten their character sheet. Again. They're fairly sure {actor_char} has about this many hit points.",
        options = {
            { label = "Rebuild it together from memory.", table_min = 10,
              log = "The whole table helps. Somehow {actor_char} ends up with a better sword than before.",
              effects = { { "all", social = 6 }, { "actor", fun = 3 }, { "arch:tactician", trust = -1 } } },
            { label = "Use your copy behind the screen.",
              log = "You slide over the backup copy. You always keep a backup copy.",
              effects = { { "all", trust = 1 }, { "arch:tactician", fun = 2 } } },
            { label = "Wing it. Whatever they say goes.",
              log = "'Twenty-six hit points?' 'Yep.' Nobody believes it. Nobody minds.",
              effects = { { "arch:casual", fun = 4 }, { "arch:tactician", fun = -3, trust = -1 }, { "arch:power_gamer", fun = -2 } } },
        },
    },
    {
        id = "food_coma", type = "table", table_only = true, headache = true,
        needs = { after_break = true },
        actor = { "casual", "butt_kicker" },
        title = "The food coma",
        text = "After the break, the energy's gone. {lowest} is slumped, {actor} is drawing on a napkin, and nobody remembers where they were.",
        options = {
            { label = "A quick recap, out loud, with feeling.",
              log = "You recap with sound effects. It works better than it should.",
              effects = { { "all", story = 4, boredom = -6 }, { "arch:storyteller", fun = 3 } } },
            { label = "Kick the door in: start with a fight.",
              log = "'Initiative!' Everyone sits up.",
              effects = { { "arch:butt_kicker", fun = 6 }, { "all", challenge = 4, boredom = -8 } } },
            { label = "Let it be a slow scene.",
              log = "A quiet, talky scene. Half the table loves it; half drifts.",
              effects = { { "arch:method_actor", fun = 4 }, { "arch:butt_kicker", boredom = 6 }, { "lowest", boredom = 4 } } },
        },
    },
    {
        id = "rules_lookup", type = "pacing", scenes = { "combat", "set_piece", "puzzle" }, headache = true,
        needs = { archetype = { "power_gamer", "tactician" } },
        actor = { "power_gamer", "tactician" },
        title = "Looking it up",
        text = "{actor} is sure there's a rule for this. The book is out. Pages are turning. Everyone else is watching the pages turn.",
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

    {
        id = "joke_moment", type = "table", trigger = "conflict_tone", conflict = "tone",
        actor = { "storyteller" },
        other = { "method_actor" },
        title = "A joke in Ilsa's moment",
        text = "This is it: {actor_char} is finally holding a piece of Ilsa's story. Then Pip pipes up: 'Does it have pictures?' {actor} doesn't laugh.",
        options = {
            { label = "Laugh along and keep going.",
              log = "Everyone laughs. Almost everyone.",
              conflict = { pressure = 10 },
              effects = { { "other", fun = 3, social = 3 }, { "actor", story = -6, fun = -3 } } },
            { label = "Hold the quiet: 'The ink is still wet in places...'",
              log = "The table goes still. You let the moment breathe.",
              conflict = { pressure = -8, progress = 1 },
              effects = { { "actor", story = 8, fun = 3 }, { "all", story = 3 }, { "other", fun = -1 } } },
            { label = "Let the joke land, then turn it: someone in the scene laughs too long.",
              log = "A laugh from the back of the room goes on too long, then cracks. Nobody saw that coming.",
              conflict = { pressure = -6, progress = 1 },
              effects = { { "all", story = 5 }, { "other", spotlight = 3 }, { "actor", story = 4 } } },
        },
    },
}
