-- The friends finding things out their own way (game/model/ideas.lua's "find" idea; game/model/secrets.lua).
-- Shared by any adventure: each way of digging, by what holds the secret (a person, a document, a place, a
-- body, an item, a creature), who it suits, and what's said. A way that's one of the secret's paths uses the
-- path's DC and gives what it gives; a way that isn't (`improvised`, or a path nobody wrote) is the DM's to
-- rule, on a card, and makes up the reveal on the spot.
--
-- Each way:
--   kind      the path kind it is (check, read, perform, trade, ask, spell, steal)
--   skill     the skills it rolls (the hero's best of them); spell: a spell the hero must have
--   class     a class bonus to wanting it (cleric's booming voice, a rogue listening in)
--   likes     who loves doing it, by kind of player (primary counts in full, secondary half)
--   say       what the friend says to the table, out of character ({who}, {char}, {thing})
--   ic        the same in their hero's voice, in character
--   want      what they want to do, for the DM's card ("lean on {who}")
--   go        what the hero does, told by the DM ({char}, {who}, {thing})
--   miss      a miss, told by the DM
--   adv       rolled with Advantage (Thaumaturgy's booming voice on an Intimidation)
--   dc        the DC when no path gives one (the DM's card offers it)

local M = {}

-- (The ways are 5e's: its skills, its spells, its classes. Another set brings its own: docs/design/rule-sets.md.)
M.ways = {
    rules = "5e",
    person = {
        { id = "talk", want = "talk {who} round", kind = "check", skill = { "persuasion" }, likes = { storyteller = 1.5, casual = 1.2, method_actor = 1, tactician = 0.6 },
          say = { "Can {char} just talk to {who}? Nicely. See what comes out.", "I want to talk {who} round. Kindly. Persuasion?",
                  "Let me have a proper chat with {who}. I think {who} wants to tell someone." },
          ic = { "Come on, {who}. You can tell us. What's really going on?", "We're on your side, {who}. Help us help you.",
                 "Whatever it is, {who}, it'll be easier said out loud." },
          go = { "{char} sits down with {who} and just listens for a while.", "{char} keeps it gentle, and keeps {who} talking." },
          miss = { "{who} smiles, and changes the subject.", "{who} pats {char}'s arm and says nothing useful at all." } },
        { id = "lean", want = "lean on {who}", kind = "check", skill = { "intimidation" }, likes = { instigator = 2, butt_kicker = 1.5, power_gamer = 0.6 },
          say = { "Can {char} lean on {who} a bit? Intimidation.", "I'm done being polite. {char} gets in {who}'s face.",
                  "Okay, {char} looms. Properly looms. Does {who} crack?" },
          ic = { "{who}. Tell us what you're not telling us. Now.", "Last chance to be straight with us, {who}.",
                 "I'm asking nicely one more time, {who}." },
          go = { "{char} steps right up close to {who}, and doesn't step back.", "{char} plants both hands on the nearest surface and leans in." },
          miss = { "{who} goes very stiff and very quiet, and stays that way.", "{who} glares back. Not a word." } },
        { id = "boom", want = "boom at {who} with Thaumaturgy", kind = "check", skill = { "intimidation" }, spell = "thaumaturgy", adv = true, likes = { instigator = 1, casual = 0.5, method_actor = 1 },
          class = { cleric = 1 }, improvised = true,
          say = { "Can {char} do the booming god-voice at {who}? Thaumaturgy. For effect.", "Oswin's voice goes three times louder. Thaumaturgy. Does {who} talk?",
                  "I want the floor to shake a little when {char} asks. Thaumaturgy!" },
          ic = { "SPEAK, {who}. THE GODS ARE LISTENING.", "{who}. THE TRUTH. NOW.", "TELL US, {who}." },
          go = { "{char}'s voice rolls out three times too loud, and the lamps flicker.", "The ground trembles a little as {char} speaks." },
          miss = { "{who} jumps a foot in the air, and then just looks cross.", "{who} covers {who_their} ears and refuses to say a word." } },
        { id = "bluff", want = "bluff {who}", kind = "check", skill = { "deception" }, likes = { method_actor = 1.5, instigator = 1.2, power_gamer = 0.5 },
          say = { "What if {char} pretends we already know? Deception.", "I'll bluff. {char} acts like we've heard it all already.",
                  "Can I trick {who} into saying it? Deception." },
          ic = { "We already know, {who}. Everyone does. Might as well tell us the rest.", "Oh, we heard. We just want your side of it.",
                 "Funny, that's not what the others said, {who}." },
          go = { "{char} puts on a knowing look and waits.", "{char} plays along as if this is all old news." },
          miss = { "{who} narrows {who_their} eyes. \"Heard what, exactly?\"", "{who} doesn't fall for it for a second." } },
        { id = "read", want = "read {who}'s face", kind = "check", skill = { "insight" }, likes = { tactician = 1.5, storyteller = 1, explorer = 0.6 },
          say = { "Is {who} lying? Can I roll Insight?", "I want to watch {who}'s face while they talk. Insight?",
                  "Something's off about {who}. Insight check?" },
          go = { "{char} watches {who} closely: the hands, the eyes, what doesn't get said.", "{char} keeps quiet and watches {who}." },
          miss = { "If {who} is hiding anything, {char} can't tell.", "{who} gives nothing away." } },
        { id = "sing", want = "sing for {who}", kind = "perform", skill = { "performance" }, likes = { method_actor = 2.5, storyteller = 1, casual = 0.5 },
          say = { "Can {char} do a little performance for {who}? A song, a story. Butter {who_them} up.", "I want to sing for {who}. Seriously. Performance.",
                  "What if {char} puts on a show? Charm it out of {who}." },
          ic = { "A song for the house, {who}! And then a story from you, yes?", "Allow me to entertain. And then you can return the favour.",
                 "Gather round, gather round. This one's for {who}." },
          go = { "{char} clears {char_their} throat and launches into a song.", "{char} puts on a whole little show, voices and all." },
          miss = { "{who} claps politely, and that's all {char} gets.", "{who} is entertained. Not any more talkative, though." } },
        { id = "pay", want = "pay {who} for it", kind = "trade", francs = 1, likes = { power_gamer = 2, casual = 0.6, instigator = 0.5 },
          say = { "What if we just pay {who} for it? A Franc or two.", "Everyone's got a price. What's {who}'s?",
                  "I'll put a Franc on the counter. Does that help {who} remember?" },
          ic = { "For your trouble, {who}. Now, about upstairs.", "Here. Consider it a tip. What do you know?" },
          go = { "{char} slides a Flitwidget Franc across.", "A Franc changes hands." },
          miss = { "{who} pockets the Franc and shrugs.", "{who} takes the Franc. That's the only thing that happens." } },
        { id = "listen", want = "listen in on {who}", kind = "check", skill = { "stealth" }, class = { rogue = 1.5 }, likes = { explorer = 1, instigator = 1, method_actor = 0.5 },
          eavesdrop = true,
          say = { "Can {char} hang back and listen in on {who}? Stealth.", "I want {char} somewhere {who} won't notice, just listening.",
                  "What does {who} say when nobody's listening?" },
          go = { "{char} drifts out of sight, and listens.", "{char} slips into a corner within earshot of {who}." },
          miss = { "{char} hears a lot of humming. Nothing else.", "{who} doesn't say anything worth hearing." } },
        { id = "ask", want = "ask {who} straight out", kind = "ask", likes = { casual = 1.5, storyteller = 1, explorer = 0.5 },
          say = { "Can we just ask {who}? We get on all right.", "{who} likes us. Let's just ask.", "Why don't we ask {who}, straight out?" },
          ic = { "{who}, you can trust us. What's going on in here?", "We'd really like to know what we're walking into, {who}." },
          go = { "{char} asks {who} straight out.", "{char} just asks." },
          miss = { "{who} looks at the floor. \"Better you don't know.\"", "{who} won't say. Not yet." } },
        { id = "thoughts", want = "read {who}'s mind with Detect Thoughts", kind = "spell", spell = "detect_thoughts", likes = { storyteller = 1, tactician = 1, explorer = 1 },
          say = { "Can {char} cast Detect Thoughts on {who}?", "I want to read {who}'s mind. Detect Thoughts." },
          go = { "{char} murmurs a spell and listens past {who}'s words.", "{char} reaches quietly into {who}'s thoughts." },
          miss = { "{who}'s thoughts are a whirl of nothing much.", "{who} feels it, frowns, and thinks very hard about lunch." } },
    },
    document = {
        { id = "study", want = "study {thing}", kind = "read", skill = { "history", "arcana", "religion", "investigation" }, likes = { storyteller = 2, explorer = 1.2, tactician = 0.8 },
          class = { wizard = 1, cleric = 0.5 },
          say = { "Can {char} have a proper go at {thing}?", "Give me a minute with {thing}. I want to know what it says.",
                  "I'm reading {thing}. All of it." },
          ic = { "Quiet a moment. Let me read.", "Hold on. This bit here." },
          go = { "{char} bends over {thing}, reading.", "{char} works through {thing}, line by line." },
          miss = { "The words swim. {char} gets nothing out of it this time.", "{char} squints, and gives up for now." } },
        { id = "comprehend", want = "cast Comprehend Languages on {thing}", kind = "spell", spell = "comprehend_languages", likes = { storyteller = 1.5, explorer = 1 }, class = { wizard = 1 },
          say = { "Comprehend Languages on {thing}. As a ritual: ten minutes.", "Can {char} just cast Comprehend Languages and read it?" },
          go = { "{char} spends ten quiet minutes on the ritual, and the writing on {thing} untangles.", "The ritual takes ten minutes. Then {thing} reads like plain words." },
          miss = { "Even with the spell, it's mostly nonsense.", "The spell gives words. They don't add up to much." } },
    },
    place = {
        { id = "search", want = "search {thing}", kind = "check", skill = { "investigation" }, likes = { explorer = 2, tactician = 1, storyteller = 0.6 },
          say = { "I want to search {thing}. Properly.", "Can {char} go over {thing} inch by inch? Investigation.",
                  "There's something about {thing}. I'm searching it." },
          go = { "{char} goes over {thing} carefully.", "{char} searches {thing}, corner by corner." },
          miss = { "Dust, and more dust.", "Nothing {char} can find." } },
        { id = "look", want = "look closely at {thing}", kind = "check", skill = { "perception" }, likes = { explorer = 1.2, tactician = 1.2, casual = 0.5 },
          say = { "Does {char} notice anything about {thing}?", "I'm just looking. Really looking. Perception?", "Anything odd about {thing}?" },
          go = { "{char} stands still and takes in {thing}.", "{char} has a good long look at {thing}." },
          miss = { "Nothing jumps out.", "If there's anything there, {char} doesn't see it." } },
        { id = "magic", want = "cast Detect Magic on {thing}", kind = "spell", spell = "detect_magic", likes = { storyteller = 1, explorer = 1.2, tactician = 0.6 }, class = { wizard = 1 },
          say = { "Detect Magic. As a ritual. What's glowing?", "Can {char} cast Detect Magic here?" },
          go = { "{char} finishes the ritual and looks around for the glow of magic.", "Ten minutes of ritual, then {char}'s eyes go to {thing}." },
          miss = { "Nothing glows that shouldn't.", "Faint magic everywhere, and nothing that stands out." } },
    },
    body = {
        { id = "examine", want = "examine {thing}", kind = "check", skill = { "medicine", "investigation" }, likes = { explorer = 1.5, tactician = 1, storyteller = 1 },
          class = { cleric = 1 },
          say = { "Can {char} look at the body? Medicine. How did they die?", "I want to know what killed them. {char} examines the body.",
                  "{char} checks the body. Gently." },
          go = { "{char} kneels and examines the body.", "{char} looks the body over, carefully." },
          miss = { "Whatever happened, the body doesn't say.", "{char} can't tell much more than \"dead, a while\"." } },
        { id = "speak", want = "cast Speak with Dead on {thing}", kind = "spell", spell = "speak_with_dead", likes = { storyteller = 1.5, explorer = 1 }, class = { cleric = 1 },
          say = { "Speak with Dead. Let's ask {thing} ourselves.", "Can {char} cast Speak with Dead?" },
          go = { "{char} speaks the old words, and the body's jaw moves.", "{char} casts the spell. The dead mouth answers." },
          miss = { "The dead answer in riddles, and not useful ones.", "The answers are short, and say nothing." } },
    },
    item = {
        { id = "study", want = "work out what {thing} does", kind = "check", skill = { "arcana" }, likes = { storyteller = 1.2, explorer = 1.2, power_gamer = 1.2 }, class = { wizard = 1 },
          say = { "What is {thing}, really? Arcana?", "Can {char} work out what {thing} does?", "I want to know about {thing}." },
          go = { "{char} turns {thing} over, thinking.", "{char} studies {thing}." },
          miss = { "{char} can't make head or tail of it.", "Whatever it does, it's not saying." } },
        { id = "identify", want = "cast Identify on {thing}", kind = "spell", spell = "identify", likes = { power_gamer = 1.5, storyteller = 1 }, class = { wizard = 1 },
          say = { "Identify, as a ritual. What does {thing} do?", "Can {char} cast Identify on {thing}?" },
          go = { "{char} spends ten minutes on the ritual over {thing}.", "Identify: {char}'s hand over {thing}, ten quiet minutes." },
          miss = { "The spell comes back muddled.", "Nothing clear." } },
    },
    creature = {
        { id = "recall", want = "think back to anything ever written about {thing}", kind = "check", skill = { "arcana", "nature", "religion", "history", "survival" }, likes = { storyteller = 1.5, tactician = 1.5, explorer = 1 },
          class = { wizard = 1 },
          say = { "Does {char} know anything about {thing}?", "Have I read about {thing}? Can I roll for it?",
                  "What do we know about {thing}? Anything?" },
          ic = { "I've read about something like this. Give me a second.", "Wait. I know this. I think." },
          go = { "{char} digs back through everything {char_they} ever read.", "{char} searches {char_their} memory for anything on it." },
          miss = { "Nothing comes to mind.", "{char} has nothing. Not a story, not a footnote." } },
        { id = "watch", want = "watch {thing} for a while", kind = "check", skill = { "perception", "insight" }, likes = { tactician = 1.5, explorer = 1, casual = 0.5 },
          say = { "I want to watch {thing} for a bit before anyone does anything.", "Can {char} study {thing} from here? Perception.",
                  "Let's just watch {thing} a moment." },
          go = { "{char} hangs back and watches {thing}.", "{char} keeps very still and watches." },
          miss = { "{char} watches. Nothing new.", "Nothing {char} didn't already know." } },
    },
}

-- What a friend says when a hunch pays off, or turns out to be only part of it (out of character).
M.cheer = { "I knew it. I knew it!", "Called it.", "That's what I thought. Okay.", "There it is." }
M.half = { "Okay, that's something.", "Not all of it, but it's a start.", "There's more to this. I can feel it." }
M.found = { "Huh. Good to know.", "Okay. Somebody write that down.", "Well. That's useful." }
-- A friend at the table going in a direction that isn't in the DM's notes: the card says so.
M.improvised = "It isn't in your notes. Make it up: what happens?"

return M
