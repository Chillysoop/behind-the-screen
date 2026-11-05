-- Party tension (A17): players are affected by each other's choices. At real tables the fiction
-- is the trigger but people are the target: a friend's choice takes someone's loot, scene, plan,
-- tone or safety. Consent decides a lot, a pattern hurts more than one incident, and DMs answer
-- with a ladder (the world reacts, the party reacts, a pause, a talk). From research into the
-- 2024 PHB and DMG on group play, Consent in Gaming, the TTRPG Safety Toolkit, Sly Flourish,
-- The Angry GM and The Alexandrian. Data only: tune freely. The model is game/model/rapport.lua.
--
-- tag_taste: how each type feels about a kind of act, -2..2 (blended 2:1 primary:secondary).
-- acts: friction acts a character might do.
--   doers   who tends to do it (archetype weights); class: only this class does it
--   objects / enjoys: extra on top of the tags, by archetype
--   severity 1 (a rub), 2 (sour), 3 (a breach); tags; target: lands on one hero in particular
--   when    "fight" (after a won fight), "social", "explore", "loot" (a scene with a reward),
--           "story" (a scene about someone's backstory), "any"
--   feeds   an existing table conflict it also pushes (tone, spotlight, rules)
--   needs   "cast": someone in the scene to do it to
--   line    {actor_char} does it ({actor} is their player); {target_char}/{target} receives it
-- bonds: the good side: acts that raise rapport between two players.
-- responses: how the DM answers an act (the "At the table" card); heat: multiplier on the hurt
--   it causes; effects as decision cards ("doer", "objectors", "target", "all").
-- jabs: what a hurt friend does at the table once a rift is brewing ({doer_char}).

return {
    tag_taste = {
        power_gamer  = { grim = 0, silly = 0, cruel = -1, selfish = -2, reckless = -1, chaotic = 0, sneaky = -1, rules = 1, meta = 0 },
        butt_kicker  = { grim = 0, silly = 0, cruel = 0, selfish = -1, reckless = 1, chaotic = 1, sneaky = 0, rules = -1, meta = 0 },
        tactician    = { grim = 0, silly = -1, cruel = -1, selfish = -1, reckless = -2, chaotic = -1, sneaky = -1, rules = 1, meta = 0 },
        method_actor = { grim = 1, silly = 1, cruel = -1, selfish = 0, reckless = 0, chaotic = 1, sneaky = 1, rules = -1, meta = -1 },
        storyteller  = { grim = 1, silly = -1, cruel = -2, selfish = -1, reckless = -1, chaotic = -1, sneaky = 0, rules = -1, meta = -2 },
        explorer     = { grim = 0, silly = 0, cruel = -1, selfish = -1, reckless = 0, chaotic = 0, sneaky = 0, rules = 0, meta = -1 },
        casual       = { grim = -2, silly = 2, cruel = -2, selfish = -1, reckless = -1, chaotic = 1, sneaky = -1, rules = -1, meta = 0 },
        instigator   = { grim = -1, silly = 2, cruel = -1, selfish = 0, reckless = 1, chaotic = 2, sneaky = 1, rules = -1, meta = 0 },
    },

    acts = {
        { id = "skim_the_hoard", when = "loot", severity = 2, tags = { "selfish", "sneaky" },
          doers = { instigator = 2, power_gamer = 1 }, objects = { power_gamer = 1, tactician = 1, casual = 1 },
          line = "{actor_char} counts the loot alone and reports 'about thirty coppers, give or take.'" },
        { id = "shove_a_friend", when = "social", severity = 2, tags = { "chaotic" }, target = true,
          doers = { instigator = 2, butt_kicker = 1 }, objects = { tactician = 1, casual = 1 }, enjoys = { instigator = 1, butt_kicker = 1 },
          line = "{actor_char} shoves {target_char} into the duck pond to win an argument." },
        { id = "my_guy", when = "any", severity = 2, tags = { "chaotic", "selfish" },
          doers = { method_actor = 2, instigator = 2 }, objects = { tactician = 2, storyteller = 1, casual = 1 },
          line = "'Sorry, it's just what {actor_char} would do,' {actor} shrugs, and does it anyway." },
        { id = "lone_wolf", when = "explore", severity = 1, tags = { "reckless" },
          doers = { explorer = 2, storyteller = 1 }, objects = { butt_kicker = 1, tactician = 1, casual = 1 },
          line = "{actor_char} slips off alone to look around, and everyone else waits by the road for an hour." },
        { id = "pull_the_lever", when = "explore", severity = 1, tags = { "reckless", "chaotic" },
          doers = { instigator = 3 }, objects = { tactician = 2, storyteller = 1 }, enjoys = { instigator = 1, butt_kicker = 1 },
          line = "{actor_char} pulls the obviously trapped lever 'just to see what happens.'" },
        { id = "barge_the_bargain", when = "social", severity = 2, tags = { "reckless" }, target = true,
          doers = { butt_kicker = 3 }, objects = { method_actor = 1, storyteller = 1, tactician = 1 },
          line = "{actor_char} charges in halfway through {target_char}'s careful bargain." },
        { id = "metagame", when = "explore", severity = 1, tags = { "meta" },
          doers = { power_gamer = 2, tactician = 1 }, objects = { storyteller = 2, method_actor = 1 },
          line = "{actor_char} 'just happens' to check exactly where the secret is hidden." },
        { id = "answer_for_them", when = "social", needs = "cast", severity = 1, tags = { "selfish" }, target = true, feeds = "spotlight",
          doers = { method_actor = 2, instigator = 1 }, objects = { casual = 1, tactician = 1 },
          line = "{actor_char} answers for {target_char} when {cast} asks {target_them} a question." },
    },

    bonds = {
        -- (needs_fight / needs_close: what has to have happened in the fight, game/model/fight.lua
        -- record. The second playtest review heard these lines when nothing like them had.)
        { id = "shield_over", when = "fight", class = "fighter", rapport = 4, needs_close = true,
          line = "{actor_char} plants {actor_themselves} in front of {target_char} and won't let anything near {target_them}." },
        { id = "last_second_heal", when = "fight", class = "cleric", rapport = 5, needs_fight = "saves",
          line = "{actor_char}'s prayer catches {target_char} a heartbeat before {target_they} drops." },
        { id = "combo", when = "fight", rapport = 4, needs_fight = "combos",
          line = "{actor_char} and {target_char} pulled off a move together in that fight that neither could have alone. The table's still talking about it." },
        { id = "share_the_loot", when = "loot", rapport = 4,
          line = "{actor_char} hands the new trinket to {target_char}: 'You'll get more use out of it than me.'" },
        { id = "stand_up_for", when = "social", needs = "cast", rapport = 4,
          line = "'They're with us,' {actor_char} tells {cast}, stepping in front of {target_char}." },
        -- (needs_plan: a choice the table settled on in this room, that the doer wanted and someone
        -- else carried off without a roll going wrong: round three heard "Brannoc's plan" for a
        -- ritual Dev argued against.)
        { id = "plan_and_timing", when = "explore", rapport = 3, needs_plan = true,
          line = "{actor_char}'s plan, {target_char}'s timing: it works perfectly, and they both know it." },
        { id = "make_amends", when = "any", rapport = 6, amends = true,
          line = "{actor_char} quietly gives back what {actor_they} took, polished, with a bad drawing as an apology." },
    },

    responses = {
        { id = "let_it_ride", label = "Let it ride.", heat = 1.0,
          log = "You nod and keep going.",
          effects = { doer = { fun = 3, spotlight = 2 }, objectors = { trust = -1 } } },
        { id = "party_reacts", label = "Ask {target}: what does {target_char} do?", heat = 0.6, needs_target = true,
          log = "You turn to {target}. 'Your call. What does {target_char} do?'",
          effects = { target = { spotlight = 5, investment = 2 }, all = { social = 3 } } },
        { id = "pause", label = "Pause: 'Everyone still good with this?'", heat = 0.4,
          log = "You put the dice down for a second. 'Everyone still good with where this is going?'",
          effects = { all = { trust = 1, boredom = 2 }, doer = { fun = -2 } } },
        { id = "session_zero", label = "Remind the table what you all agreed.", heat = 0.5,
          log = "'Remember what we said at Session Zero?' A couple of nods.",
          effects = { doer = { fun = -3 }, objectors = { trust = 2 } } },
        { id = "outlet", label = "Give {actor_char} a better outlet next scene.", heat = 0.8,
          log = "You make a note: something for {actor_char} to get stuck into next time.", screen = true,
          effects = { doer = { investment = 2 }, objectors = { trust = 1 } } },
    },

    jabs = {
        "{char} gives {doer_char} a long, flat look.",
        "{char} mutters something about {doer_char} that isn't quite under {char_their} breath.",
        "{char}'s mini moves a square further away from {doer_char}'s.",
    },
}
