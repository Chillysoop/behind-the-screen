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
            { "{Foe}, finished. Who wants to check its pockets?", when = "last" },
            { "Bye, {foe}! {Left} more to annoy.", when = "more_left" },
            { "{char} takes a bow over {foe}." },
        },
        sam = {
            { "That's all of them, right? Please say that's all of them.", when = "last" },
            { "{Foe}'s down. {Left} left. We can do this.", when = "more_left" },
            { "Sorry, {foe}. You were very scary." },
        },
    },
    ouch = {
        dev = {
            { "{Foe} hits like a truck." },
            { "{Dmg} damage?! From {foe}?!" },
            { "{Hp} hit points left. I'm fine. {char}'s fine." },
        },
        mara = {
            { "That's {dmg} hit points. I had plans for those." },
            { "{Hp} left. Could someone please do something about {foe}?" },
        },
        jess = {
            { "Ow! {Foe}, we are no longer friends." },
            { "{Dmg}! I'm writing that down so I can complain about it later." },
        },
        sam = {
            { "{Foe} hits hard. Can we not stand next to {foe}?" },
            { "{Hp} hit points. {char} is fine. {char} is very fine." },
        },
    },
    down_self = {
        dev = {
            { "Down to {foe}?! Of all things!" },
            { "{char} falls. {Foe} is going to pay for that." },
        },
        mara = {
            { "{Foe} got me. I knew I should have stood further back." },
            { "Down. Note for later: {foe} hits harder than it looks." },
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
        jess = { { "{Healer}, you're a saint. An actual saint." } },
        sam = { { "Thanks, {healer}. Back to work." } },
    },
    fight_chat = {
        dev = {
            { "Round {round}. How many hit points does {foe} even have?" },
            { "{Left} of them left. Come and get it.", when = "more_left" },
        },
        mara = {
            { "Round {round}. I'm keeping count, don't worry." },
            { "If {foe} goes down, the rest might break. Just a thought.", when = "more_left" },
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
    "{char} lowers their weapon. {Charmer} is a friend now, as far as {char} knows.",
    "{char} is charmed: {charmer} seems far too nice to hurt.",
    "{char} hesitates. Whatever {charmer} did, {char} won't raise a hand against them.",
}

return M
