-- Rests (A16): who asks for one and when, how the DM rules it, what can interrupt it where,
-- and the little scenes a rest plays. From research into SRD 5.2.1 and real tables (Sly
-- Flourish, The Angry GM, The Alexandrian, EN World, the 2025 Starter Set). Data only: tune
-- freely. The rules are game/rules/rest.lua; the night is game/model/night.lua (rest_request).
--
-- requests: { id, archetype, kind ("short"|"long"), weight, when = { conditions }, lines }.
--   Conditions: after_fight, own_hp_below, party_hp_below, any_down, own_spent = { resource },
--   own_slots_below, hit_dice_left, fights_since_long, next_is (scene type), late, where
--   (settings), scene_types, exhausted.
-- profiles: how each player type asks, and how they take each ruling (effects by ruling id).
-- card: the "Can we rest?" decision; offer: which rulings a kind of place allows.
-- places: interruption chances by place kind and what turns up (line, kind, interrupts).
-- beats: one-line scenes a rest plays; mend beats come first when two players are at odds.

local M = {}

M.requests = {
    -- power_gamer: asks the moment a recharge is "free"; plans long rests before the boss.
    { id = "pg_free_recharge", archetype = "power_gamer", kind = "short", weight = 3,
      when = { after_fight = true, own_spent = { "action_surge" }, hit_dice_left = 1 },
      lines = { "short rest? i want action surge back. it's literally free.",
                "one hour. we spend hit dice, we're full. math says rest." } },
    { id = "pg_before_boss", archetype = "power_gamer", kind = "long", weight = 3,
      when = { next_is = "set_piece", fights_since_long = 1 },
      lines = { "we are NOT walking into the tower without slots.", "long rest first. i'm not dying to a lieutenant." } },

    -- butt_kicker: hates waiting; asks only when about to fall over; groans at other people's rests.
    { id = "bk_last_legs", archetype = "butt_kicker", kind = "short", weight = 1,
      when = { own_hp_below = 0.25, after_fight = true },
      lines = { "okay. okay. i need a nap. a violent nap.", "fine. one hour. then we hit them." } },

    -- tactician: counts Hit Dice, makes a rota, rests before the big fight, never after an easy one.
    { id = "tac_hd_math", archetype = "tactician", kind = "short", weight = 3,
      when = { after_fight = true, party_hp_below = 0.6, hit_dice_left = 1 },
      lines = { "we've got hit dice. short rest, then go.", "if we rest now we walk in at three-quarters. worth it." } },
    { id = "tac_rota", archetype = "tactician", kind = "long", weight = 2,
      when = { fights_since_long = 2, own_slots_below = 0.34 },
      lines = { "long rest. i'll make a watch rota. two hours each.", "I'm out of slots and we've had two fights. We camp." } },

    -- method_actor: asks for the scene, not the numbers.
    { id = "ma_cook", archetype = "method_actor", kind = "long", weight = 2,
      when = { where = { "forest", "road", "camp", "outdoor" } },
      lines = { "can we camp? Pip's been saving a rabbit for a stew.", "Pip takes first watch. Pip also takes everyone's boots. For safekeeping." } },

    -- storyteller: rests to make room for a beat (reading notes, a dream, a talk).
    { id = "st_read_notes", archetype = "storyteller", kind = "short", weight = 2,
      when = { scene_types = { "mystery", "exploration" } },
      lines = { "can we stop for an hour? Thessaly wants to read Ilsa's notes properly.",
                "maybe she dreams about it tonight?" } },

    -- explorer: rarely asks; would rather scout. Volunteers for watch.
    { id = "ex_scout_watch", archetype = "explorer", kind = "long", weight = 1,
      when = { fights_since_long = 3 },
      lines = { "fine, rest. but i take the watch and have a look around.", "rest later, there's a door we haven't opened." } },

    -- casual: asks when they (the real person) are tired; often really a snack break.
    { id = "cas_tired", archetype = "casual", kind = "short", weight = 2,
      when = { late = true },
      lines = { "can we rest? i mean my character. also me. snacks?", "is it late? it feels late in there." } },
    { id = "cas_hurt", archetype = "casual", kind = "short", weight = 2,
      when = { any_down = true },
      lines = { "that was scary. can we just... sit for a bit?", "everybody okay? can we rest?" } },

    -- instigator: proposes resting somewhere outrageous, or uses the rest to cause trouble.
    { id = "ins_altar_nap", archetype = "instigator", kind = "long", weight = 2,
      when = { where = { "underground", "ruins", "crypt" } },
      lines = { "we long rest. here. on the altar.", "while everyone's asleep, Pip goes through Brannoc's pack." } },

    -- Anyone: Exhaustion makes everyone ask for a long rest.
    { id = "any_exhausted", archetype = "any", kind = "long", weight = 4,
      when = { exhausted = 1 },
      lines = { "we're running on fumes. we need a real night's sleep." } },
}

M.profiles = {
    power_gamer  = { asks = 1.4, bias = "long",  scene = -1,
        on = { allow = { fun = 4, reward = 3 }, risky = { fun = 1 }, short_only = { fun = 1 },
               deny_reason = { fun = -3 }, deny_clock = { fun = -1, challenge = 4 },
               interrupt = { fun = -2, challenge = 5 }, haven = { fun = 2 } } },
    butt_kicker  = { asks = 0.4, bias = "short", scene = -1,
        on = { allow = { boredom = 2 }, allow_scene = { boredom = 5 }, risky = { fun = 2 },
               deny_reason = { fun = 1 }, deny_clock = { fun = 2 },
               interrupt = { fun = 6, challenge = 6 }, haven = { boredom = 3 } } },
    tactician    = { asks = 1.2, bias = "short", scene = 0,
        on = { allow = { fun = 2 }, risky = { fun = 3, challenge = 3 }, short_only = { fun = 2 },
               deny_reason = { fun = -1, challenge = 4 }, deny_clock = { fun = 3, challenge = 5 },
               interrupt = { fun = -1, challenge = 4 }, haven = { fun = 1 } } },
    method_actor = { asks = 0.8, bias = "long",  scene = 2,
        on = { allow_scene = { fun = 6, spotlight = 6 }, allow = { fun = 1 },
               deny_reason = { fun = -1 }, interrupt = { fun = 2 }, haven = { fun = 3, social = 3 } } },
    storyteller  = { asks = 0.9, bias = "long",  scene = 2,
        on = { allow_scene = { fun = 6, story = 5 }, deny_clock = { fun = 3, story = 4 },
               interrupt = { story = 2 }, deny_reason = { fun = -1 } } },
    explorer     = { asks = 0.5, bias = "short", scene = 1,
        on = { allow_scene = { fun = 2 }, deny_reason = { fun = 0 }, haven = { fun = -1 },
               interrupt = { fun = 2, story = 2 } } },
    casual       = { asks = 1.0, bias = "short", scene = 1,
        on = { allow = { fun = 3 }, allow_scene = { fun = 3, social = 3 },
               deny_reason = { fun = -2 }, interrupt = { fun = -3 }, deny_clock = { fun = -1 } } },
    instigator   = { asks = 0.7, bias = "long",  scene = 1,
        on = { allow_scene = { fun = 3 }, risky = { fun = 4 }, interrupt = { fun = 4 },
               deny_reason = { fun = -2 } } },
}

M.card = {
    id = "rest_request", type = "pacing", trigger = "rest_request",
    title = "Can we rest?",
    text = "{actor} asks for a {kind} rest. You're at {location}.",
    options = {
        { id = "allow", label = "Sure. You rest.",
          rest = "full", log = "The night passes quietly.",
          effects = { { "actor", spotlight = 2 }, { "all", challenge = -3 }, { "all", trust = 1 } } },

        { id = "allow_scene", label = "You rest. Let's play the campfire.",
          rest = "full", beat = true, log = "The fire crackles. Someone starts talking.",
          effects = { { "all", social = 6, story = 2, challenge = -3 }, { "arch:storyteller", investment = 2 },
                      { "arch:method_actor", investment = 2 } } },

        { id = "risky", label = "You can try. Roll for the night.",
          rest = "roll", log = "They bed down and hope.",                 -- rolls on M.places (E5)
          effects = { { "all", challenge = 2 }, { "perceptive", trust = 2 } } },  -- an open roll builds trust

        { id = "short_only", label = "An hour, not a night.",
          rest = "short", log = "An hour against the wall, bandaging and catching breath.",
          effects = { { "all", challenge = 1 } } },

        { id = "deny_reason", label = "You can't rest here.",
          rest = "none", say_reason = true,                               -- reason comes from the place
          log = "Nobody's sleeping here. Not with that sound in the walls.",
          effects = { { "all", challenge = 5 }, { "actor", fun = -2 } } },

        { id = "deny_clock", label = "You could. The clock won't wait.",
          rest = "player_choice", ticks = 2,                              -- they may still rest; a visible clock advances
          log = "Every hour here is an hour Kessrick's wolves are walking.",
          effects = { { "all", story = 4, challenge = 3 } } },

        { id = "interrupt", label = "They rest... until.",
          rest = "interrupt", planned = true, log = "Somewhere past midnight, a twig snaps.",
          effects = { { "all", challenge = 6 }, { "arch:butt_kicker", spotlight = 4 } } },

        { id = "haven", label = "Not here. The Kettle's an hour back.",
          rest = "travel", travel_hours = 1, ticks = 1,
          log = "They trudge back to Millbrook. Gus already has the kettle on.",
          effects = { { "all", social = 3, challenge = -2 } } },
    },
    -- Which options a place offers (the rest are hidden, as a real DM wouldn't say them).
    offer = {
        inn        = { "allow", "allow_scene", "interrupt" },
        town       = { "allow", "allow_scene", "risky", "interrupt" },
        camp       = { "allow_scene", "risky", "short_only", "interrupt" },
        wilderness = { "allow_scene", "risky", "short_only", "deny_clock", "haven" },
        ship       = { "allow", "risky", "short_only", "interrupt" },
        dungeon    = { "risky", "short_only", "deny_reason", "deny_clock", "haven" },
    },
}

M.context = {
    -- The party really needed it (avg HP < 40% or casters out of slots): saying yes feels kind,
    -- saying no stings more.
    needy = { allow = { { "all", fun = 3, trust = 1 } }, allow_scene = { { "all", fun = 3 } },
              deny_reason = { { "all", fun = -3 } }, interrupt = { { "all", fun = -2 } } },
    -- They're nearly full: a long rest now is the 15-minute day. Fights will feel easy.
    fresh = { allow = { { "arch:tactician", fun = -2, challenge = -3 }, { "arch:power_gamer", challenge = -2 } },
              deny_reason = { { "all", fun = 1 } } },
    -- The boss is next and they know it: a rest is what a good DM gives.
    before_set_piece = { allow = { { "all", trust = 2 } }, interrupt = { { "all", trust = -3, suspicion = 3, why = "the rest you cut short before the big fight" } } },
    -- Out-of-character tiredness (casual's "late" request): a snack break counts as a yes.
    late = { allow = { { "arch:casual", fun = 3, commitment = 1 } } },
}

M.fairness = {
    -- A "no" is deny_reason, an unrolled interrupt, or a risky roll the DM cooked toward interruption.
    streak_warn = 2,          -- after 2 no's in a row, someone says "do we ever get to sleep?"
    streak_hurt = 3,          -- 3rd no and each one after it:
    streak_effects = { { "all", fun = -3, trust = -3 }, { "perceptive", suspicion = 4, why = "another rest refused" } },
    telegraph_softens = 0.5,  -- effects x0.5 when the danger was shown first (tracks, alarm clock, warning)
    planned_per_arc = 2,      -- more planned interrupts than this per arc reads as "the DM hates rests"
    planned_over_effects = { { "all", trust = -2 }, { "perceptive", suspicion = 5, why = "rests that always get interrupted" } },
    -- The other extreme: a full long rest after every fight.
    pushover_after = 3,       -- 3 fights in a row each followed by a long rest
    pushover_effects = { { "arch:tactician", fun = -3, challenge = -6 }, { "arch:power_gamer", challenge = -4 },
                         { "arch:butt_kicker", boredom = 3 } },
    -- Cooking a hidden interruption roll counts like any cooked roll (decisions.lua "convenient").
}

M.table_lines = {   -- out of character, said when fairness thresholds trip
    streak_warn = { "do we ever get to sleep in this campaign?", "every time we close our eyes...",
                    "i'm starting to think the DM has a thing about naps." },
    pushover    = { "we're kind of steamrolling, huh.", "that was easy. was that supposed to be easy?" },
    telegraphed = { "okay, fair, we did see those tracks.", "yeah, resting next to the wolf den was a choice." },
}

M.places = {
    inn = { long = 0.03, short = 0.00,
        reason = "Nobody rests at the Kettle on a night like this?",   -- rarely used: inns are havens
        events = {
            { id = "gus_knock", w = 4, kind = "visit", interrupts = false, light_hours = 0.5,
              line = "A soft knock: Gus, with a lamp and a worried face. 'Someone's asking for you downstairs.'" },
            { id = "wren_news", w = 3, kind = "visit", interrupts = false, light_hours = 1, story = true,
              line = "Wren slips in, soaked. 'The tower door was open tonight. Just for a minute.'" },
            { id = "brawl", w = 2, kind = "fight", interrupts = true, fight = "tavern",
              line = "Crash of a table below, then shouting. The biggest drunk in the Vale wants a word." },
            { id = "sable_note", w = 2, kind = "omen", interrupts = false,
              line = "Morning: a calling card under the door. Velvet. Pip's name, underlined twice." },
        } },
    town = { long = 0.10, short = 0.03,
        reason = "The watch doesn't let strangers sleep in the square.",
        events = {
            { id = "watch_patrol", w = 4, kind = "visit", interrupts = false, light_hours = 0.5,
              line = "The town watch, lanterns up: 'You lot again. Move along, or come explain yourselves.'" },
            { id = "cutpurses", w = 3, kind = "fight", interrupts = true, fight = "market",
              line = "Footsteps in the alley stop right at the party's packs." },
            { id = "fire_bell", w = 1, kind = "hazard", interrupts = true, exertion = true,
              line = "A hand bell clangs, the only bell left in Millbrook: a barn's on fire." },
            { id = "baker", w = 2, kind = "false_alarm", interrupts = false,
              line = "Something at the door at dawn. Just the baker, with a basket of rolls." },
        } },
    camp = { long = 0.08, short = 0.03,           -- an established camp: a muster, an ally's farm
        reason = "The camp's packing up tonight. Nobody's sleeping.",
        events = {
            { id = "refugees", w = 3, kind = "visit", interrupts = false, light_hours = 1, story = true,
              line = "A cart of refugees from the hill farms, asking for the heroes by name." },
            { id = "deserter", w = 2, kind = "visit", interrupts = false, light_hours = 0.5, story = true,
              line = "A boy in a wolf-pelt cloak walks in with his hands up. He wants to talk, not fight." },
            { id = "false_alarm", w = 3, kind = "false_alarm", interrupts = false,
              line = "A sentry shouts, everyone grabs a weapon. A deer. It's a deer." },
            { id = "raid", w = 1, kind = "fight", interrupts = true, fight = "wolf_lieutenant",
              line = "Torches on the ridge. Vask's riders, testing the line." },
        } },
    wilderness = { long = 0.30, short = 0.10,
        reason = "The wolves have your scent. Stop here and they'll find you asleep.",
        events = {
            { id = "wolves", w = 4, kind = "fight", interrupts = true, fight = "wolf_pack",
              line = "Eyes at the edge of the firelight. Then more eyes." },
            { id = "scouts", w = 2, kind = "fight", interrupts = true, fight = "wolf_lieutenant",
              line = "Two of Kessrick's scouts stumble on the camp, as surprised as anyone." },
            { id = "storm", w = 3, kind = "hazard", interrupts = false, poor_rest = true,
              line = "The rain turns to sleet. Nobody sleeps well." },        -- Alexandrian "poor rest" option
            { id = "hermit", w = 2, kind = "visit", interrupts = false, light_hours = 1, story = true,
              line = "The hermit wanders into the firelight with a kettle and a story about the last time the bells failed." },
            { id = "howl", w = 3, kind = "omen", interrupts = false,
              line = "Far off, a howl. Then the answering ones, closer." },
        } },
    ship = { long = 0.15, short = 0.05,            -- a river barge on the Mill
        reason = "Nobody sleeps through the rapids.",
        events = {
            { id = "snag", w = 3, kind = "hazard", interrupts = true, exertion = true,
              line = "The barge lurches onto a snag. All hands to the poles." },
            { id = "river_bandits", w = 2, kind = "fight", interrupts = true, fight = "old_bridge",
              line = "A rope across the river, and men on the bank with crossbows." },
            { id = "fog", w = 3, kind = "omen", interrupts = false,
              line = "Fog so thick the lantern looks like a moon. Something splashes, once." },
            { id = "bargee_song", w = 2, kind = "false_alarm", interrupts = false,
              line = "Just the bargee, singing to keep himself awake. Badly." },
        } },
    dungeon = { long = 0.55, short = 0.20,         -- barrow, crypt, bell tower; scales with the alert clock
        reason = "Nobody's sleeping here. Not with that sound in the walls.",
        alert_step = 0.10,
        events = {
            { id = "patrol", w = 4, kind = "fight", interrupts = true, fight = "bell_tower",
              line = "Boots on the stairs. The patrol's early." },
            { id = "restless_dead", w = 3, kind = "fight", interrupts = true, fight = "restless_dead",
              line = "Scraping, from behind the sealed door. Then it isn't sealed." },
            { id = "collapse", w = 2, kind = "hazard", interrupts = true, damage = "1d6",
              line = "Dust, then stone. The ceiling gives a little." },
            { id = "whispers", w = 2, kind = "omen", interrupts = false, poor_rest = true,
              line = "Whispering in the dark that stops whenever anyone sits up." },
        } },
}

M.beats = {
    { id = "stew", where = { "camp", "wilderness" }, pair = { "pc:dev", "pc:sam" }, tags = { "cook", "bond" },
      line = "Brannoc burns the stew again. Oswin quietly adds something from his pack and calls it 'an old temple recipe.'",
      effects = { { "all", social = 4 }, { "arch:casual", fun = 3 } } },
    { id = "bluebell", where = { "any" }, pair = { "pc:jess", "pc:mara" }, tags = { "mend" }, mend = true,
      line = "Pip slips Thessaly's 'borrowed' notebook back into her pack, a pressed bluebell marking the page she was stuck on.",
      effects = { { "all", social = 6 }, { "arch:method_actor", fun = 4 } } },
    { id = "wooden_horse", where = { "camp", "wilderness" }, pair = { "pc:dev" }, tags = { "watch", "hook" },
      thread = "dev",
      line = "On watch, Brannoc carves a little wooden horse, the kind they sold at the fair in Hale's Crossing, and doesn't say who it's for.",
      effects = { { "actor", spotlight = 6 }, { "all", story = 3 } } },
    { id = "ink_dream", where = { "any" }, pair = { "pc:mara" }, tags = { "dream", "hook" }, thread = "mara",
      line = "Thessaly dreams Ilsa's handwriting is crawling around the inside of a bell, and wakes with ink on her fingers.",
      effects = { { "actor", spotlight = 6 }, { "all", story = 5 }, { "arch:storyteller", fun = 4 } } },
    { id = "relic_glow", where = { "any" }, pair = { "pc:sam" }, tags = { "watch", "hook" }, thread = "sam",
      line = "Oswin's relic glows faintly at the turn of the second watch, exactly when a bell should have rung.",
      effects = { { "actor", spotlight = 5 }, { "all", story = 4 } } },
    { id = "on_the_house", where = { "inn" }, pair = { "npc:gus" }, tags = { "cozy" },
      line = "Gus brings up four mugs of something hot, 'on the house, don't tell anyone,' and polishes the same mug by the fire.",
      effects = { { "all", social = 5 }, { "arch:casual", fun = 3 } } },
    { id = "grip_and_palm", where = { "any" }, pair = { "pc:dev", "pc:jess" }, tags = { "bond", "mend" }, mend = true,
      line = "Brannoc teaches Pip a proper sword grip; Pip teaches Brannoc to palm a coin. Both are terrible. Both laugh.",
      effects = { { "all", social = 6 }, { "arch:butt_kicker", fun = 2 }, { "arch:instigator", fun = 2 } } },
    { id = "sable_stack", where = { "any" }, pair = { "pc:jess" }, tags = { "hook" }, thread = "jess",
      line = "Pip counts her coins twice by the fire, sets a stack aside for Sable, then quietly moves two coins back.",
      effects = { { "actor", spotlight = 5 }, { "all", story = 3 } } },
    { id = "if_the_bells_rang", where = { "camp", "wilderness", "inn" }, pair = { "pc:mara" }, tags = { "talk" },
      line = "Thessaly asks what they'd do if the bells rang right now. 'Pray.' 'Run at it.' 'Run away from it.' They argue happily until the embers.",
      effects = { { "all", social = 5, story = 2 } } },
    { id = "stitches", where = { "any" }, pair = { "pc:sam", "pc:dev" }, tags = { "patch_up", "bond" },
      line = "Oswin stitches the cut on Brannoc's arm by lantern light, humming a hymn Brannoc almost remembers.",
      effects = { { "all", social = 4 }, { "arch:casual", fun = 2 } } },
    { id = "hermit_tea", where = { "wilderness" }, pair = { "npc:hermit" }, tags = { "cozy", "hook" },
      line = "The hermit pours everyone tea from the kettle he talks to: 'Bells failed once before. The winter the wolves came.'",
      effects = { { "all", story = 4, social = 3 } } },
    { id = "abbot_sweeps", where = { "any" }, pair = { "pc:sam", "npc:abbot_ghost" }, tags = { "dream", "hook" },
      thread = "sam",
      line = "Oswin dreams of the abbot sweeping ash from the temple steps. The old man doesn't look up. 'You kept it safe. Good.'",
      effects = { { "actor", spotlight = 6, fun = 3 }, { "all", story = 3 } } },
    { id = "perhaps", where = { "any" }, pair = { "pc:mara", "pc:dev" }, tags = { "mend" }, mend = true,
      line = "Thessaly admits her plan last time was 'perhaps aggressive.' Brannoc admits his charge was 'perhaps also.' They shake on 'perhaps.'",
      effects = { { "all", social = 6 } } },
    { id = "two_skies", where = { "ship" }, pair = { "pc:jess", "pc:sam" }, tags = { "bond" },
      line = "On the barge, Pip and Oswin name the stars: he knows the holy ones, she knows the ones thieves steer by.",
      effects = { { "all", social = 5 } } },
    { id = "short_straw", where = { "camp", "wilderness" }, pair = { "pc:dev", "pc:sam" }, tags = { "watch", "bond" },
      line = "Brannoc swaps his long straw for Oswin's short one without a word, so the cleric can sleep the whole night.",
      effects = { { "all", social = 4 }, { "arch:casual", fun = 3 } } },
    { id = "rolls_on_step", where = { "inn", "town" }, pair = { "npc:gus" }, tags = { "cozy" },
      line = "A basket of hot rolls on the Kettle's step at dawn: 'for whoever's going to fix the bells.'",
      effects = { { "all", social = 3, reward = 2 } } },
    { id = "shoulders", where = { "camp", "wilderness" }, pair = { "pc:dev", "pc:jess" }, tags = { "watch", "mend" },
      mend = true, thread = "dev",
      line = "Brannoc wakes shouting a name from Hale's Crossing. Pip, on watch, doesn't ask; she just sits close until he sleeps.",
      effects = { { "all", social = 6, story = 2 } } },
    { id = "drinking_song", where = { "inn", "camp" }, pair = {}, tags = { "cozy", "song" },
      line = "Someone starts the Millbrook drinking song. By the third verse even the horses are keeping time.",
      effects = { { "all", social = 6 }, { "arch:butt_kicker", boredom = -2 } } },
}

M.campfire_prompts = {
    "Who did you leave behind?", "What villain is still out there?", "What was your favorite meal?",
    "What scares you about where this road is going?", "What would you do if the bells rang right now?",
}

return M
