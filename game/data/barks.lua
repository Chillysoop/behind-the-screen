-- Fight barks that fit the moment (November 3). Two halves, read by game/model/barks.lua:
--
-- fits: a word or phrase in a library line (game/data/dialogue/lines.json) and what the moment
--   has to hold for the line to be true. "NATURAL TWENTY!" on a 19, "Who's next?" after the last
--   foe, "That's half my hit points!" for a scratch: each was a line ignoring the moment.
--   Patterns are Lua patterns on the lowercased line; the test names a fact in barks.lua.
--
-- made: lines built from the moment itself, in each friend's voice, so a fight says what
--   happened in it: who fell, to what, with what, how many are left. {foe}/{Foe} the foe
--   (lowercase "the" / sentence start), {weapon}, {spell}, {left} (a number word), {dmg}, {hp},
--   {char} the speaker's hero, {healer}, {ally}, {ally_hp}, {round}. A line plays only when the
--   moment has every fill it names, and its `when` (a fact) holds.

local M = {}

M.fits = {
    { "twenty", "nat20" }, { "natural", "nat20" }, { "%f[%d]20%f[%D]", "nat20" },
    { "who's next", "more_left" }, { "next%.", "more_left" }, { "next!", "more_left" }, { "another one", "more_left" },
    { "one down", "more_left" }, { "one fewer", "more_left" }, { "that's one%.", "more_left" }, { "anyone counting", "more_left" },
    { "little guy", "small_foe" },
    { "half my hit points", "big_hit" }, { "a lot of damage", "big_hit" }, { "that was very big", "big_hit" },
    { "barely", "low_hp" },
    { "i was winning", "was_winning" },
    { "concentrating", "concentrating" },
    { "let me check", "round3" }, { "feels like an hour", "long_fight" },
    { "action surge", "surge_ready" },
    { "who needs healing", "party_hurt" }, { "anyone need healing", "party_hurt" },
    { "focus the big one", "more_left" },
    { "stay down", "target_down" },
    { "a lot of fire", "fire" }, { "nineteen", "dmg19" }, { "eleven damage", "dmg19" }, { "max damage", "never" },
    { "fire bolt", "spell_fire_bolt" }, { "sacred flame", "spell_sacred_flame" }, { "bless you all", "spell_bless" },
    { "survivors", "survivors" },
    { "out of spells", "no_slots" },
}

-- context: the same for lines said outside a fight's turns (a room starting, a boss showing up): a
-- phrase and what the room has to hold (barks.lua CONTEXT). The second playtest review: "Hm. Nobody to
-- talk to." with Euryale right there, "I'll just be over here with the chips." as the danger's
-- announced, "Big guy. Big sword." of a Gorgon with a bow.
M.context = {
    { "nobody to talk to", "nobody_here" }, { "talk to everyone here", "someone_here" }, { "who's in charge here", "someone_here" },
    { "talk to them first", "someone_here" }, { "insult them while we fight", "fight_here" }, { "another fight", "fight_here" },
    { "here with the chips", "calm" }, { "clue from earlier", "clue_found" }, { "wake me up when something needs hitting", "no_fight_here" },
    { "that's a big one", "big_foe" }, { "big guy", "big_foe" }, { "focus fire on the boss", "several_foes" },
    { "dibs on the big one", "several_foes" }, { "that boss knows what it's doing", "boss_is_a_thing" },
    -- (Round three, A8 and A1: not after a night run long or past midnight, nor a night a hero died.)
    { "same time next week", "on_time" }, { "by midnight", "before_midnight" }, { "that was fun", "nobody_died" },
    { "hooray", "nobody_died" }, { "how close that was", "nobody_died" }, { "count off", "nobody_died" },
    { "are we... alive", "nobody_died" }, { "dead-dead", "nobody_died" }, { "everyone alive", "nobody_died" },
    -- (The third playtest: "Nobody tell my character how close that was" after someone else's hero
    -- nearly died; "Finally. A real fight." after the night's third.)
    { "nobody tell my character", "self_close" }, { "needs a very long nap", "self_close" }, { "finally. a real fight", "first_fight" },
    { "finally. hitting time", "first_fight" },
    -- (Lines about things the room doesn't have, the third playtest: a lock in the Hall of Paintings, a
    -- roof, a puzzle in a fight room, "talk to them first" in the reward scene, "can I look around first"
    -- after looking, "that ending" after a banister, a statue where there's none.)
    { "lock was rude", "lock_here" }, { "magic that lock", "lock_here" }, { "door's stronger than it looks", "lock_here" },
    { "off the roof", "never" }, { "a puzzle?", "puzzle_here" }, { "talk to them first", "fight_here" },
    { "more talking?", "no_fight_here" }, { "look around", "not_looked" }, { "that ending", "big_ending" },
    { "talking to the statue", "statue_here" },
}

M.NUMBERS = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten" }

M.made = {
    crit = {
        dev = {
            { "Crit with the {weapon}! Double the dice!" },
            { "A crit on {foe}! Roll everything!" },
            { "Natural twenty on {foe}. Somebody write that down.", when = "nat20" },
            { "Nineteen counts! That's a crit!", when = "crit19" },
        },
        mara = {
            { "A critical {spell}. I'd like that on the record." },
            { "Twenty! {Foe} did not see that coming.", when = "nat20" },
            { "That's a crit on {foe}. Describe it properly, please." },
        },
        jess = {
            { "{Foe} just got {char}'d. Critically." },
            { "Twenty! I'm not even going to pretend I aimed.", when = "nat20" },
            { "Crit with the {weapon}! {char} makes it look easy." },
        },
        sam = {
            { "Oh! A crit! On {foe}!" },
            { "A critical {spell}. The light really came through." },
            { "Twenty. On {foe}. Huh.", when = "nat20" },
        },
    },
    kill = {
        dev = {
            { "That's the last of them!", when = "last" },
            { "{Foe} down. {Left} to go!", when = "more_left" },
            { "{Foe}, done. Next!", when = "more_left" },
            { "The {weapon} says goodnight to {foe}." },
        },
        mara = {
            { "And that's {foe}. Is that everyone? I think that's everyone.", when = "last" },
            { "{Foe} is down. {Left} left. Let's keep it tidy.", when = "more_left" },
            { "{Spell} for {foe}. Exactly as I planned. Roughly." },
        },
        jess = {
            { "{Foe}, finished. Who wants to check {foe_their} pockets?", when = "last" },
            { "That's {foe} done! {Left} more to annoy.", when = "more_left" },
            { "{char} takes a bow over {foe}." },
        },
        sam = {
            { "That's all of them, right? Please say that's all of them.", when = "last" },
            { "{Foe}'s down. {Left} left. We can do this.", when = "more_left" },
            { "Sorry about that. You were very scary." },
        },
    },
    ouch = {
        dev = {
            { "{Foe} hits like a truck." },
            { "{Dmg} damage?! From {foe}?!" },
            { "{Hp} hit points left. I'm fine. {char}'s fine.", rules = "5e" },
        },
        mara = {
            { "That's {dmg} hit points. I had plans for those.", rules = "5e" },
            { "{Hp} left. Could someone please do something about {foe}?" },
        },
        jess = {
            { "Ow! {Foe}, we are no longer friends." },
            { "{Dmg}! I'm writing that down so I can complain about it later." },
        },
        sam = {
            { "{Foe} hits hard. Can we not stand next to {foe}?" },
            { "{Hp} hit points. {char} is fine. {char} is very fine.", rules = "5e" },
        },
    },
    down_self = {
        dev = {
            { "Down to {foe}?! Of all things!" },
            { "{char} falls. {Foe} is going to pay for that." },
        },
        mara = {
            { "{Foe} got me. I knew I should have stood further back." },
            { "Down. Note for later: {foe} hits harder than {foe_they} looks." },
        },
        jess = {
            { "{char} is taking a little nap, courtesy of {foe}." },
            { "{Foe}! That was my good side!" },
        },
        sam = {
            { "I'm down. {Foe} got me. Somebody?" },
            { "Okay, {foe} dropped the healer. That's a problem." },
        },
    },
    ally_down = {
        dev = { { "{Ally}! {Foe}, you're mine!" } },
        mara = { { "{Ally} is down! {Foe} first, or {ally} first?" } },
        jess = { { "{Ally}! Hey, {foe}! Over here, ugly!" } },
        sam = {
            { "{Ally} is down. I'm coming, I'm coming." },
            { "Hold on, {ally}. Healing on the way." },
        },
    },
    up_again = {
        dev = { { "I'm BACK. Thanks, {healer}. {Foe}, round two." } },
        mara = { { "Back up. Thank you, {healer}. Where was I?" } },
        jess = { { "{char} lives! {Healer}, you're my favourite." } },
        sam = { { "Back on my feet. Thanks, {healer}." } },
    },
    thanks = {
        dev = { { "Thanks, {healer}! Now watch this." } },
        mara = { { "Thank you, {healer}. That was too close." } },
        jess = { { "{Healer}, you're a lifesaver. An actual lifesaver." } },
        sam = { { "Thanks, {healer}. Back to work." } },
    },
    fight_chat = {
        dev = {
            { "Round {round}. How many hit points does {foe} even have?", rules = "5e" },
            { "{Left} of them left. Come and get it.", when = "more_left" },
        },
        mara = {
            { "Round {round}. I'm keeping count, don't worry." },
            { "If {foe} goes down, the rest might break. Just a thought.", when = "rest_left" },
        },
        jess = {
            { "Is it weird that I kind of like {foe}?" },
            { "{Ally} is on {ally_hp}. Somebody hug them." },
        },
        sam = {
            { "{Ally}, you're on {ally_hp}. Maybe stay back a bit?" },
            { "Round {round} and we're doing okay. Right? We're doing okay." },
        },
    },
    hit = {
        dev = { { "The {weapon} into {foe}. Feels good." } },
        mara = { { "Hit. {Foe} is looking a bit worse." } },
        jess = { { "Got {foe}! A little bit." } },
        sam = { { "It hit! Did it hit? It hit {foe}." } },
    },
    miss = {
        dev = { { "Missed {foe}. The dice hate me." } },
        mara = { { "Missed. {Foe} has better armour than I thought." } },
        jess = { { "I meant to do that. I totally meant to miss {foe}." } },
        sam = { { "Oh, I missed {foe}. Sorry, everyone." } },
    },
    big_hit = {
        dev = { { "{Dmg} damage on {foe}!" } },
        mara = { { "{Dmg} damage. A respectable number." } },
        jess = { { "{Dmg}! {Foe} felt that one." } },
        sam = { { "{Dmg} damage! Is that a lot? That feels like a lot." } },
    },
    spell = {
        mara = { { "{Spell} at {foe}. Stand back." } },
        sam = { { "{Spell}. The light provides." } },
    },
    walk = {
        dev = { { "Charging! Well. Walking quickly. It's a big room." }, { "{Foe}, I'm coming for you. Slowly." } },
        mara = { { "Moving up. Carefully. {char} does not run." }, { "Closing on {foe}. Keep the line." } },
        jess = { { "{char} sneaks closer to {foe}. Very sneakily." } },
        sam = { { "Moving up behind everyone. Like a good cleric.", when = "cleric" }, { "Still walking. Is {foe} getting further away?" } },
    },
}

-- The DM's word when a whole round was only walking (the playtest, Nov 2: "several rounds pass
-- with heroes walking and nothing said").
M.walk_captions = {
    "Round {round}: everyone closes in. {Foe} is {dist} squares off.",
    "Round {round}. Minis slide across the {room}; {foe} is still {dist} squares away.",
    "Round {round}: a lot of walking. {Foe} waits {dist} squares off.",
}

-- A charmed hero with no one they're willing to hit (the playtest: one who looks idle).
M.charmed_captions = {
    "{char}'s weapon comes down. The charm has {char_them}: {Charmer} looks like a friend now.",
    "{char} is charmed: {charmer} seems far too nice to hurt.",
    "{char} hesitates. Whatever {charmer} did, {char} won't fight back.",
}

-- What the table hears when a fight turns in a way nobody can miss (round three, A2 and A4: Shatter hit
-- allies twelve times and nobody said so; the mirror, Hyper Destroyer Mode and a natural-20 death save
-- happened only on the mat). Said by game/model/fight.lua (tell_moments, friendly_fire), each three ways.
-- {char}: the hero it's about (or who did it); {Name}/{name}: the friend at the table; {spell}; {hit}:
-- the heroes caught; {is}: "is" or "are" for them; {downed}; {mech}; {holder}: who holds the mirror;
-- {charmer}; {caught}: the heroes her stare caught; {start}: "starts" or "start" for them.
M.told = {
    -- Friendly fire: a hero's own spell catches the party.
    friendly_fire = {
        "{Spell} catches {hit} too.",
        "{char}'s {spell} doesn't pick sides: {hit} {is} caught in it.",
        "{hit} {is} right in the middle of {char}'s {spell}.",
    },
    friendly_down = {
        "{char}'s {spell} catches {hit}, and drops {downed}.",
        "{Spell} goes off, and {downed} {is} on the floor. That was {char}'s.",
        "{char}'s {spell} hits the party too. {downed} {goes} down.",
    },
    -- The friend whose hero was hit, to the one who cast it (out of character).
    friendly_hit = { "{Caster}! That was me!", "Ow. Friendly fire, {caster}. Very friendly.", "Did you just hit me with that, {caster}?" },
    -- And the one who cast it.
    friendly_sorry = { "Sorry! Sorry. I'll aim better.", "Okay. That one's on me.", "In my defence, it was a very good spell." },
    friendly_sorry_down = { "Oh no. That was me. That was me, wasn't it?", "I did that. I'm so sorry.", "Nobody say anything. I know." },
    -- The bone guardian's swarm, as it bursts out (never crawling on anyone: Sam's veil at Session Zero).
    scarabs = { "Something bursts out of {name}'s ribs: a swarm of scarabs, spreading across the sand.",
                "{name} cracks open, and a swarm of scarabs pours out onto the floor.",
                "A swarm of scarabs boils out of {name}'s chest and joins the fight." },
    -- Euryale's big moments, and the Mech's.
    -- (The hood off is when the table learns what she is, as the book has it, p26: each says so.)
    veil = { "Euryale pulls back her white hood. The snakes uncoil, hissing. She's a Gorgon.",
             "Off comes the hood. A crown of snakes rears up and hisses at the room: she's a Gorgon.",
             "Euryale throws back her hood, and every snake on her head turns to look at them. A Gorgon." },
    petrify = { "Euryale fixes them with her bronze eyes. {caught} {start} to go grey from the feet up.",
                "Her eyes catch the light, and {caught} {start} to turn to stone, slowly, from the ground up.",
                "One look from Euryale, and {caught} {start} to stiffen. The grey is climbing." },
    petrify_missed = { "Euryale fixes them with her bronze eyes, and every one of them looks away in time.",
                       "Her eyes flash, but nobody meets them. Not one.",
                       "Euryale glares round the room. Everyone's staring at their boots." },
    mirror = { "The cupboard door swings up in {holder}'s hands, and Euryale is looking straight into her own eyes.",
               "Up comes the mirror-bright door in {holder}'s hands. Euryale catches her own reflection.",
               "Up goes the polished door in {holder}'s hands. For a heartbeat, Euryale meets her own stare." },
    mirror_caught = { "The grey starts at her feet. Euryale is turning to stone in her own reflection.",
                      "Her own eyes do it: the stone creeps up Euryale's legs.",
                      "She can't look away in time. The grey begins to climb her robe." },
    mirror_missed = { "She jerks her head away just in time. Close.", "Euryale flinches and looks away. Nearly.",
                      "She tears her eyes from the door, hissing. It nearly worked." },
    self_stone = { "Euryale goes still. The grey reaches her eyes, and the Gorgon is a statue in her own lair.",
                   "The stone closes over her. Euryale stands there, caught in her own reflection, for good.",
                   "One last hiss, and then nothing. Euryale has turned to stone." },
    stone = { "{char} is stone now, mid-step. Until her hold breaks, {char_they} {stays} that way.",
              "The grey reaches {char}'s eyes. {char} is stone now, until her hold on the lair breaks.",
              "{char} is stone now, a statue among her statues, until her hold breaks." },
    stone_other = { "{char} is caught in her stare too, and turns to stone mid-step.",
                    "Her stare doesn't care whose side anyone's on: {char} is stone now.",
                    "{char} goes grey and still, caught in her eyes." },
    freed = { "The stone cracks, and {char} steps out of it, gasping.",
              "{char} cracks out of the stone in a shower of grey dust.",
              "A crack, a gasp, and {char} is flesh again." },
    charmed = { "{char}'s weapon comes down. {Charmer}'s voice is the nicest thing in the room.",
                "{char}'s face goes soft. The charm has {char_them}: {Charmer} looks like a friend now.",
                "The charm takes {char}: {charmer} is an old friend now." },
    -- (The mode itself; flipping the switch has its own line, fight.saved_switch, when it was saved for her.)
    hyper = { "{mech}'s plates slam open and the steam turns red: HYPER DESTROYER MODE. The floor shakes.",
              "{mech} goes rigid, then unfolds into something much bigger and much louder.",
              "{mech} lets out a shriek of steam and goes into Hyper Destroyer Mode. Everyone steps back." },
    overheat = { "{mech} shrieks, vents a cloud of scalding steam, and goes still. It isn't getting up again.",
                 "Too hot, too long: {mech} burns out in a hiss of steam and smoke.",
                 "{mech} shudders, vents, and stops. The green glow behind its helmet goes out." },
    power_down = { "{mech} grinds to a halt: {target} is down, and nobody's giving it orders.",
                   "With {target} on the floor, {mech} stops dead and waits for an order that doesn't come.",
                   "{mech} goes still the moment {target} drops." },
    -- A natural 20 on a death save: back up with 1 hit point (SRD 5.2.1).
    nat20_save = { rules = "5e", "Natural 20 on the death save: {char}'s eyes snap open, and {char_they're} back on {char_their} feet.",
                   "A twenty! {char} gasps awake on the floor and gets up, swaying.",
                   "The die says twenty. {char} sits bolt upright, alive, and grabs a weapon." },
    -- A lost fight with every hero on the floor (round three, A6), and the friend who says something.
    wipe = { "Everyone's on the floor. For a long moment, the only thing moving is them.",
             "One by one, they all go down. Then it's very quiet.",
             "The last of them hits the floor. Nobody at the table says anything for a second." },
    wipe_react = { "Did we... all just go down?", "Okay. That's everyone. That's all of us.", "Well. That went about as badly as it could." },
    -- A hero at 0 hit points (the fourth playtest: "Pip goes down, and doesn't get up. Death saves." five times in one
    -- fight, up again each time; the same line for all 18 knockouts in the Sheep Chase). Said by fight.lua's react,
    -- fresh, and never "doesn't get up": a heal, a potion or a natural 20 can have them up again. {char}: the hero.
    knocked_down = { rules = "5e", "{char} goes down. Death saves.",
                     "{char} hits the floor at 0 hit points. Death saves.",
                     "That drops {char}: 0 hit points, and death saves from here.",
                     "{char} is out cold, and rolling death saves." },
    -- (Knocked out and Stable, not dying: the Sentinel's fists. No death saves to roll.)
    knocked_out = { rules = "5e", "{char} is knocked out cold. Stable: no death saves.",
                    "That knocks {char} out, breathing but out of it. No death saves for this one.",
                    "{char} drops, knocked out. Stable, so no death saves." },
    -- (Down a second time in the same fight.)
    knocked_down_again = { rules = "5e", "{char} is down again. Back to death saves.",
                           "And {char} drops again. Death saves.",
                           "{char} is back on the floor. Death saves again." },
    -- A hero back on their feet while the table grieves ({lost}: who they lost).
    up_quiet = { "{char} is up. Nobody cheers.", "{char} gets back up and looks at {lost}. Nobody says anything.",
                 "{char} is on {char_their} feet again. It doesn't feel like winning." },
}

return M
