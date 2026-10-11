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
-- vents: what a hurt player posts in the group chat once a rift is brewing ({doer_char}).

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
        { id = "needless_scrap", when = "social", severity = 1, tags = { "reckless" },
          doers = { butt_kicker = 3, instigator = 1 }, objects = { storyteller = 1, explorer = 1, casual = 1 },
          enjoys = { butt_kicker = 2, power_gamer = 1 },
          line = "{actor_char} starts a scrap with a farmhand who only asked them to move their horse." },
        { id = "strike_the_yielded", when = "fight", severity = 2, tags = { "cruel", "grim" },
          doers = { butt_kicker = 2, power_gamer = 1 }, objects = { storyteller = 2, casual = 2, method_actor = 1, tactician = 1 },
          line = "{actor_char} takes one more swing at the last of the crew, who has already dropped everything and put their hands up." },
        { id = "rough_questioning", when = "fight", severity = 2, tags = { "cruel" },
          doers = { instigator = 2, butt_kicker = 1 }, objects = { casual = 2, storyteller = 1 }, enjoys = { instigator = 1 },
          line = "{actor_char} dangles the captured lookout over the millrace by his boots until he squeaks." },
        { id = "bonk_them", when = "social", needs = "cast", severity = 1, tags = { "chaotic", "reckless" },
          doers = { butt_kicker = 2, instigator = 2 }, objects = { storyteller = 2, method_actor = 1, casual = 1 },
          enjoys = { instigator = 1 },
          line = "'What if I just bonk {cast}?' {actor} asks. For the third time tonight." },
        { id = "pocket_party_loot", when = "loot", severity = 2, tags = { "selfish", "sneaky" }, target = true, class = "rogue",
          doers = { instigator = 2, method_actor = 2 }, objects = { power_gamer = 2, tactician = 1 }, enjoys = { instigator = 1 },
          line = "{actor_char} quietly pockets the coin purse {target_char} won tonight." },
        { id = "skim_the_hoard", when = "loot", severity = 2, tags = { "selfish", "sneaky" },
          doers = { instigator = 2, power_gamer = 1 }, objects = { power_gamer = 1, tactician = 1, casual = 1 },
          line = "{actor_char} counts the loot alone and reports 'about thirty coppers, give or take.'" },
        { id = "dibs_again", when = "loot", severity = 1, tags = { "selfish" },
          doers = { power_gamer = 3, butt_kicker = 1 }, objects = { tactician = 1, casual = 1, method_actor = 1 },
          line = "{actor_char} claims the best of the loot 'because I hit hardest', just like last time." },
        { id = "secret_letter", when = "any", severity = 2, tags = { "sneaky" }, class = "rogue",
          doers = { method_actor = 2, instigator = 1 }, objects = { storyteller = 1, tactician = 1 },
          line = "{actor_char} tells the others the Velvet Hand's letter was 'just a pie recipe.'" },
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
        { id = "joke_in_the_sad_bit", when = "story", severity = 1, tags = { "silly" }, target = true, feeds = "tone",
          doers = { instigator = 2, casual = 1, method_actor = 1 }, objects = { storyteller = 2 },
          line = "{actor} does a squeaky goblin voice right in the middle of {target_char}'s big moment." },
        { id = "grim_in_the_cozy", when = "social", severity = 1, tags = { "grim" }, feeds = "tone",
          doers = { storyteller = 1, method_actor = 1 }, objects = { casual = 2, instigator = 1 },
          line = "{actor_char} turns a cheerful evening into a long brood about how everyone in Millbrook dies someday." },
        { id = "metagame", when = "explore", severity = 1, tags = { "meta" },
          doers = { power_gamer = 2, tactician = 1 }, objects = { storyteller = 2, method_actor = 1 },
          line = "{actor_char} 'just happens' to check exactly where the secret is hidden." },
        { id = "rules_at_a_friend", when = "any", severity = 1, tags = { "rules" }, target = true, feeds = "rules",
          doers = { tactician = 2, power_gamer = 1 }, objects = { method_actor = 2, instigator = 2 },
          line = "{actor} stops {target_char}'s daring swing from the rafters to quote the jumping rules. Again." },
        { id = "sneer_at_town", when = "social", severity = 1, tags = { "grim", "cruel" },
          doers = { butt_kicker = 1, power_gamer = 1 }, objects = { casual = 2, storyteller = 1 },
          line = "{actor_char} sneers at the orphans' bake sale and won't carry a single tray." },
        { id = "lift_the_patron", when = "social", needs = "cast", severity = 2, tags = { "sneaky", "chaotic" }, class = "rogue",
          doers = { instigator = 2, method_actor = 1 }, objects = { tactician = 2, storyteller = 1 }, enjoys = { instigator = 1 },
          line = "{actor_char} lifts {cast}'s purse right in the middle of the job offer." },
        { id = "answer_for_them", when = "social", needs = "cast", severity = 1, tags = { "selfish" }, target = true, feeds = "spotlight",
          doers = { method_actor = 2, instigator = 1 }, objects = { casual = 1, tactician = 1 },
          line = "{actor_char} answers for {target_char} when {cast} asks them a question." },
    },

    bonds = {
        { id = "shield_over", when = "fight", class = "fighter", rapport = 4,
          line = "{actor_char} plants a shield over {target_char} and won't let anything near them." },
        { id = "last_second_heal", when = "fight", class = "cleric", rapport = 5,
          line = "{actor_char}'s prayer catches {target_char} a heartbeat before they drop." },
        { id = "combo", when = "fight", rapport = 4,
          line = "{actor_char} and {target_char} pull off a move together that neither could alone. The table cheers." },
        { id = "share_the_loot", when = "loot", rapport = 4,
          line = "{actor_char} hands the new trinket to {target_char}: 'You'll get more use out of it than me.'" },
        { id = "ask_after", when = "story", rapport = 5,
          line = "The whole party spends an hour asking around for {target_char}, without being asked." },
        { id = "stand_up_for", when = "social", needs = "cast", rapport = 4,
          line = "'They're with us,' {actor_char} tells {cast}, stepping in front of {target_char}." },
        { id = "plan_and_timing", when = "explore", rapport = 3,
          line = "{actor_char}'s plan, {target_char}'s timing: it works perfectly, and they both know it." },
        { id = "inside_joke", when = "any", rapport = 3, both = true,
          line = "Someone mentions the goat, and {actor} and {target} lose it all over again." },
        { id = "make_amends", when = "any", rapport = 6, amends = true,
          line = "{actor_char} quietly gives back what they took, polished, with a bad drawing as an apology." },
    },

    responses = {
        { id = "let_it_ride", label = "Let it ride.", heat = 1.0,
          log = "You nod and keep going.",
          effects = { doer = { fun = 3, spotlight = 2 }, objectors = { trust = -1 } } },
        { id = "world_reacts", label = "Yes, but the world notices.", heat = 0.7,
          log = "It happens, and Millbrook remembers who did it.",
          effects = { doer = { challenge = 3 }, all = { story = 3 } } },
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
          log = "You make a note: something for {actor_char} to get stuck into next time.",
          effects = { doer = { investment = 2 }, objectors = { trust = 1 } } },
    },

    vents = {
        "anyway. great session. some of us had fun. some of us didn't.",
        "not to be dramatic but if {doer_char} does that one more time",
        "is it just me or is {doer_char} kind of making it hard to have fun lately",
        "fine. it's fine. it's a game. it's fine.",
        "can we talk about the {doer_char} thing at some point? not now. sometime.",
    },
    jabs = {
        "{char} gives {doer_char} a long, flat look.",
        "{char} mutters something about {doer_char} that isn't quite under their breath.",
        "{char} moves their mini a square further away from {doer_char}'s.",
    },
}
