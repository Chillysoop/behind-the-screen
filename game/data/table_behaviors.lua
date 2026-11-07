-- What real players do at the table, out of character (the slice rework, A12: players play
-- like people). From research into how people actually play: dice rituals, rules lookups,
-- analysis paralysis, backseat tactics, checking for traps, looting everything, naming NPCs,
-- doing the voice, theories, snacks, side chat, puns, phones. Each behavior:
--   id, archetype (who does it; "any"), when (the moment it fits: start, idle, after_crit,
--   after_fail, combat, social, rules, long_scene, late, end), mood ("engaged", "bored", "any"),
--   lines (what they say; one a night, none twice in three weeks), effect ("<meter><+|-> <group|speaker>").
--   Optional: by ("roller" says it about their own roll, "other" says it to them), class /
--   not_class, scenes, where (location settings), needs ("cast", "cliff", "not_first"), min_week,
--   hurt (only from someone whose hero is hurt).
-- The lines are drafts, like the dialogue library's: the review mode can show them later.
-- Data only: tune freely. The engine is game/model/night.lua (table_behavior, stunt).

return {
    behaviors = {
        -- dice rituals and superstitions
        { id = "dice_jail", archetype = "any", by = "roller", when = "after_fail", mood = "any", lines = { "that's it. you're going in dice jail.", "sit there and think about what you did, d20.", "getting out the backup die. the backup die is hungry." }, effect = "fun+ speaker" },
        { id = "blow_on_dice", archetype = "any", when = "combat", mood = "engaged", lines = { "everybody blow on it. come on, for luck.", "hang on, i'm warming it up first.", "it has to be the green one. trust me on this." }, effect = "fun+ group" },
        { id = "reroll_to_prove_it", archetype = "any", by = "roller", when = "after_fail", mood = "any", lines = { "watch, NOW it rolls a twenty.", "see? that's the one that should've counted.", "the die is literally mocking me right now." }, effect = "fun+ speaker" },
        { id = "lend_lucky_die", archetype = "casual", by = "other", when = "after_fail", mood = "any", lines = { "here, borrow my lucky die.", "it's never rolled under ten. well. almost never.", "careful with it, it's sensitive." }, effect = "social+ group" },
        { id = "cocked_die", archetype = "instigator", when = "combat", mood = "any", lines = { "it fell off the table, does that count?", "it's leaning on the cup. that's a twenty, right? that's a twenty.", "floor rolls don't count. that's the law." }, effect = "fun+ group" },
        { id = "dice_hoarder", archetype = "power_gamer", when = "start", mood = "any", lines = { "i got new dice. look. they're galaxy dice.", "these are my attack dice, those are my damage dice, don't mix them.", "nobody touch the purple set, they're still learning." }, effect = "fun+ speaker" },
    
        -- crits and fails (crit and fumble triggers exist; these add new beats)
        { id = "describe_the_crit", archetype = "any", by = "roller", when = "after_crit", mood = "engaged", lines = { "wait wait, can i describe it?", "okay so i spin, right, and then...", "it's in slow motion. everything's in slow motion." }, effect = "spotlight+ speaker" },
        { id = "crit_photo", archetype = "any", by = "other", when = "after_crit", mood = "engaged", lines = { "somebody get a photo of the die!", "nobody touch it, it's a historic die now.", "posting that in the group chat immediately." }, effect = "fun+ group" },
        { id = "inspiration_ask", archetype = "any", by = "roller", when = "after_crit", mood = "engaged", lines = { "does that get inspiration?", "that was very in character, i'm just saying.", "inspiration? no? okay. worth a try." }, effect = "none" },
        { id = "fail_shrug", archetype = "any", by = "roller", when = "after_fail", mood = "any", lines = { "my character is just having a day.", "honestly that's the funniest outcome.", "it's fine, it's fine, we're fine." }, effect = "fun+ group" },
        { id = "fist_bump", archetype = "any", by = "other", when = "after_crit", mood = "any", lines = { "fist bump. across the table. come on.", "you're carrying this fight, honestly.", "i'm putting that on your character sheet as a fun fact." }, effect = "social+ group" }, -- cheer_other exists
    
        -- rules and numbers
        { id = "rules_lookup", archetype = "tactician", when = "rules", mood = "engaged", lines = { "hang on, does advantage stack?", "it's in the glossary somewhere... page... page...", "okay, it's in here somewhere. give me a second." }, effect = "boredom+ group" },
        { id = "technically_actually", archetype = "power_gamer", when = "rules", mood = "engaged", lines = { "technically that should be a bonus action.", "i'm not saying you're wrong. i'm saying the book is right.", "your table, your call. but it's on page two hundred." }, effect = "boredom+ group" }, -- rules_lawyer exists
        { id = "check_dm_math", archetype = "tactician", when = "combat", mood = "engaged", lines = { "wait, did you add the cover bonus?", "so that's a nineteen, not a seventeen.", "sorry. go on. it still hits, doesn't it." }, effect = "challenge+ group" },
        { id = "spell_lookup_midturn", archetype = "any", class = { "wizard", "cleric" }, when = "combat", mood = "any", lines = { "what does this spell even do again?", "it's on my phone, one sec.", "okay it does... less than i hoped." }, effect = "boredom+ group" },
        { id = "teach_new_player", archetype = "tactician", when = "rules", mood = "any", lines = { "okay, quick explainer for everyone, because i had to look this up too.", "so you add your modifier to that one, right? right.", "don't worry, everybody forgets that one." }, effect = "social+ group" },
        { id = "theory_build", archetype = "power_gamer", when = "idle", mood = "engaged", lines = { "if i multiclass at five my damage goes way up.", "trust me, i did the math.", "nobody wants to see the spreadsheet? nobody?" }, effect = "none" },
        { id = "level_up_when", archetype = "power_gamer", when = "late", mood = "engaged", lines = { "are we leveling tonight?", "i already planned my next three levels.", "can i take the feat now, or after the fight?" }, effect = "fun+ speaker" },
    
        -- combat habits
        { id = "analysis_paralysis", archetype = "tactician", when = "combat", mood = "engaged", lines = { "okay so if i move here... no, wait.", "what's the range on that again?", "one sec. okay, two secs. okay, three." }, effect = "boredom+ group" },
        { id = "backseat_tactics", archetype = "tactician", when = "combat", mood = "engaged", lines = { "if you heal now you're wasting it.", "you should flank. no, the other flank.", "not telling you what to do. but do this." }, effect = "challenge+ group" },
        { id = "hp_fishing", archetype = "tactician", when = "combat", mood = "engaged", lines = { "does it look tired yet?", "how many hit points has it got? ballpark.", "is it at least a little bit worried?" }, effect = "challenge+ group" },
        { id = "fireball_reflex", archetype = "any", class = "wizard", when = "combat", mood = "engaged", lines = { "can i cast fireball yet? no? next level?", "what do you mean it's too small a room?", "okay. smaller fire. a modest fire." }, effect = "fun+ group" },
        { id = "heal_me_please", archetype = "any", not_class = "cleric", when = "combat", mood = "engaged", hurt = true, lines = { "i'm getting low here, just so everyone knows.", "healing word? please? i'll owe you.", "i'm fine. totally fine. please heal me." }, effect = "social+ group" },
        { id = "metagame_whisper", archetype = "power_gamer", when = "combat", mood = "engaged", lines = { "has anyone tried fire? fire solves most things.", "my character doesn't know anything. but... fire?", "i'm just saying, hypothetically, fire." }, effect = "none" },
        { id = "itchy_trigger", archetype = "butt_kicker", when = "social", mood = "bored", lines = { "can i just hit somebody?", "how long is this conversation going to be?", "i'm rolling initiative in my heart." }, effect = "boredom+ speaker" }, -- bored exists
    
        -- exploration procedures (party SOPs)
        { id = "check_for_traps", scenes = { "exploration", "puzzle", "mystery" }, archetype = "tactician", when = "long_scene", mood = "engaged", lines = { "i check the door for traps.", "i check the chair for traps.", "i check the trap for traps." }, effect = "fun+ group" },
        { id = "loot_everything", archetype = "power_gamer", when = "long_scene", mood = "engaged", lines = { "i search the room. thoroughly.", "i'm taking the candlesticks.", "does the chair count as loot? i'm taking the chair." }, effect = "fun+ speaker" },
        { id = "dont_split_party", scenes = { "exploration", "mystery" }, archetype = "tactician", when = "long_scene", mood = "any", lines = { "guys. do NOT split the party.", "i swear, if we split up again...", "fine. but i'm going with the cleric." }, effect = "none" },
        { id = "lets_split_up", scenes = { "exploration", "mystery" }, archetype = "instigator", when = "long_scene", mood = "engaged", lines = { "let's split up, we'll cover more ground.", "what's the worst that could happen?", "meet back at the tavern. nobody die." }, effect = "challenge+ group" },
        { id = "map_drawer", scenes = { "exploration", "puzzle", "mystery" }, archetype = "explorer", when = "long_scene", mood = "engaged", lines = { "wait, which way is north?", "i'm drawing this. the room is roughly a pentagon?", "hold on, this hallway doesn't fit on my map." }, effect = "story+ speaker" },
        { id = "who_has_the_rope", scenes = { "exploration", "puzzle", "mystery" }, archetype = "tactician", when = "long_scene", mood = "any", lines = { "who has the rope?", "i thought YOU had the rope.", "we're out of torches again, aren't we." }, effect = "challenge+ group" },
        { id = "bad_idea_on_purpose", scenes = { "exploration", "puzzle", "mystery" }, archetype = "instigator", when = "long_scene", mood = "engaged", lines = { "i pull the lever. what? it's a lever.", "i open the obviously cursed box.", "what if i lick it. for science." }, effect = "challenge+ group" },
        { id = "dm_smile_fear", archetype = "tactician", when = "idle", mood = "engaged", lines = { "why are you smiling like that?", "i hate it when you say 'are you sure?'", "okay, nobody touch anything." }, effect = "fun+ group" },
    
        -- social and roleplay
        { id = "doing_the_voice", archetype = "method_actor", when = "social", mood = "engaged", lines = { "okay, i'm doing the voice. ahem.", "my character would never say 'okay'.", "no no, let me say it in character." }, effect = "spotlight+ speaker" },
        { id = "in_character_spat", archetype = "method_actor", when = "social", mood = "engaged", lines = { "my character would never agree to that.", "well MY character is deeply offended.", "okay, we're doing an in-character argument now." }, effect = "spotlight+ speaker" },
        { id = "can_i_roll", archetype = "any", when = "social", mood = "engaged", lines = { "can i roll insight on him?", "can i roll to see if i know her?", "do i roll? what do i roll?" }, effect = "spotlight+ speaker" },
        { id = "adopt_it", where = { "wild", "road", "outdoor", "town" }, archetype = "casual", when = "idle", mood = "engaged", lines = { "can we keep it?", "his name is sir pickles and he's in the party now.", "he gets a share of the loot. he earned it." }, effect = "fun+ group" },
        { id = "shopping_trip", archetype = "power_gamer", when = "idle", mood = "engaged", lines = { "can we go shopping first?", "how much is a ten-foot pole?", "do they have a magic shop? any magic shop?" }, effect = "fun+ speaker" },
    
        -- story engagement
        { id = "note_taker", archetype = "storyteller", when = "long_scene", mood = "engaged", lines = { "hold on, how do you spell that name?", "writing that down. that's important.", "okay, page four of my notes says..." }, effect = "story+ group" },
        { id = "recap_volunteer", archetype = "storyteller", needs = "not_first", when = "start", mood = "engaged", lines = { "i'll do the recap!", "previously, on our show...", "last week: lots of yelling, one very good roll." }, effect = "story+ group" },
        { id = "cliffhanger_protest", archetype = "any", needs = "cliff", when = "end", mood = "engaged", lines = { "you can't end it THERE.", "a whole week?! i need to know now.", "okay, group chat theories tonight." }, effect = "story+ group" },
        { id = "loot_split", archetype = "power_gamer", when = "end", mood = "engaged", lines = { "okay, how are we splitting the gold?", "i call first pick. i called it first.", "the cleric gets the potions, that's just maths." }, effect = "fun+ speaker" },
    
        -- table life
        -- (Late only for whoever the group chat said would be, and for the reason they gave: { line, late = reason }.
        -- The second playtest review: Jess was late for "traffic", and the chat had said the bus.)
        { id = "arrival_chatter", archetype = "any", when = "start", mood = "any", lines = { { "sorry i'm late. the bus, again.", late = "bus" }, { "did i miss anything? we haven't started? great.", late = "any" }, "made it! who's got the snacks?" }, effect = "social+ group" },
        -- Only once there's a last session to have left off from.
        { id = "arrival_recap", archetype = "any", when = "start", mood = "any", min_week = 2, lines = { "wait, where did we leave off?" }, effect = "social+ group" },
        { id = "food_order", archetype = "casual", when = "start", mood = "any", lines = { "before we start: pizza or tacos?", "i'm not doing pineapple again.", "order now so it gets here before the boss fight." }, effect = "social+ group" },
        { id = "snack_share", archetype = "casual", when = "idle", mood = "any", lines = { "anyone want chips? i brought the good chips.", "pass the salsa down?", "who ate all the pretzels? i'm not mad. i'm a bit mad." }, effect = "social+ group" }, -- snack exists
        { id = "side_chat", archetype = "casual", when = "long_scene", mood = "bored", lines = { "did you see the game last night?", "wait, are you still doing that pottery class?", "sorry, what did i miss?" }, effect = "social+ speaker" },
        { id = "meme_share", archetype = "instigator", when = "idle", mood = "bored", lines = { "okay this is so relevant, look.", "it's literally us. it's our party.", "sorry, sorry, i'm back." }, effect = "boredom- speaker" }, -- phone exists
        { id = "repeat_that", archetype = "casual", when = "long_scene", mood = "bored", lines = { "sorry, can you say that last part again?", "how many doors were there?", "wait, we're in a cave now?" }, effect = "boredom- speaker" },
        { id = "doodle_party", archetype = "casual", when = "long_scene", mood = "bored", lines = { "i drew the party. that one's you.", "why am i a potato?", "it's honestly better than the map." }, effect = "boredom- speaker" },
        { id = "peek_behind_screen", archetype = "instigator", when = "idle", mood = "any", lines = { "can i see behind the screen? kidding. unless?", "you rolled a one back there. i heard it.", "is that the monster book? which page?" }, effect = "fun+ group" },
        { id = "praise_dm", archetype = "storyteller", by = "other", when = "after_crit", mood = "engaged", lines = { "that voice was amazing, do it again.", "okay, that description gave me chills.", "you're really good at this, you know that?" }, effect = "fun+ group" },
        { id = "music_request", archetype = "casual", when = "idle", mood = "any", lines = { "can we put the tavern music on?", "this playlist is so good.", "skip, skip, this one's too sad for a bar fight." }, effect = "fun+ group" },
        { id = "stretch_break", archetype = "any", when = "late", mood = "bored", lines = { "quick bathroom break?", "my leg fell asleep.", "is it ten-minute-break time yet?" }, effect = "boredom- speaker" },
        { id = "getting_late", archetype = "casual", when = "late", mood = "bored", lines = { "how late is it?", "i have work tomorrow, just saying.", "one more scene and then i'm out." }, effect = "none" },
        { id = "plan_overload", archetype = "tactician", when = "long_scene", mood = "engaged", lines = { "okay, here's the plan. step one...", "step eleven is where it gets clever.", "and if that fails, plan b is also fire." }, effect = "challenge+ group" },
    },

    -- Stunts: before a fight, a hero tries something flashy instead of waiting for initiative.
    -- A quick check; a win gives the party the first move. {boss} and {Boss} are the fight's
    -- leader; {other_char} another hero. The id keeps which ones were said lately (campaign.stunts_said).
    stunts = {
        { id = "draw_fire", skill = "intimidation", archetype = "butt_kicker", other = true, taunt = true, taunt_other = true,
          say = "Hey! Over here! Pick on someone your own size!",
          win = "{Boss} forgets everyone else and goes for {char}, back wide open to the rest of the party.",
          lose = "{Boss} looks at {char}, looks at {other_char}, and picks {other_char}. Sorry." },
        { id = "hold_the_line", skill = "athletics", archetype = "butt_kicker", say = "Get behind me! I'll hold the line!",
          win = "{char} plants {char_their} feet and holds the gap while the others get into position.",
          lose = "The press pushes back harder. {char} gives ground, one step at a time." },
    },
}
