-- Villain monologues (the villain who remembers): voices, the ledger's stings, the templates and
-- the numbers. game/model/villains.lua builds a villain's ledger from the event log and plays
-- the monologue, the barks, the last words and the retort. Templates only: every line here has
-- slots, filled from what happened. Slots: {char} the hero spoken to, {fallen} a hero who died,
-- {hook} a backstory hook, {place} where it happened, {count} times knocked down, {tag} a
-- reputation, {joke} a running joke, {week} the session number (Petty villains count).

local M = {}

-- Who sounds like what. Anyone not listed is a Gloater.
M.VOICE = {
    wolf_lieutenant = "gloater", kessrick = "zealot", grey_coat = "mastermind", turncoat_guide = "tragic",
    madame_sable = "mastermind", rook = "petty", rivals = "petty", verrin = "petty", goblin_scout = "petty",
}
M.VOICES = { "gloater", "mastermind", "zealot", "tragic", "petty" }

-- How much each kind of memory stings (the ledger's weight), and who it's aimed at.
M.STING = { killed = 10, backstory = 8, defeat = 6, humiliated = 5, escape = 4, knockdown = 3, tag = 2, joke = 2,
            generic = 1 }
M.KNOCKDOWN_CAP = 6

-- Backstory hooks: what a villain can press on, and whose people did it before the campaign began.
M.HOOKS = {
    dev = { hook = "the village", factions = { "warband" } },
    jess = { hook = "the debt", factions = { "velvet_hand" } },
    mara = { hook = "Ilsa", factions = {} },
    sam = { hook = "the burned temple", factions = {} },
}

-- Session Zero: how far the villain may go with each player's backstory. Their own wish; the DM
-- can change it on their sheet after a check-in.
M.BOUNDARY = { mara = "fair", dev = "fair", jess = "gently", sam = "gently" }
M.BOUNDARY_NAME = { fair = "Fair game", gently = "Gently", off = "Off limits" }
M.BOUNDARY_ABOUT = {
    fair = "The villain can hit their backstory hard. It's what they wrote it for.",
    gently = "Threats and hints are fine. Nothing more without a check-in.",
    off = "Leave their backstory out of the villain's hands.",
}
M.BOUNDARY_ORDER = { "fair", "gently", "off" }

-- Effect sizes: session meters and long-term bars move by different amounts.
M.SIZE = { session = { 0, 3, 6, 10 }, long = { 0, 1, 2, 4 } }       -- none, small, medium, large
M.LONG = { trust = true, investment = true, commitment = true }

-- What a callback that fits does, by kind: the target, everyone else, and Vendetta.
--   sizes: 1 small, 2 medium, 3 large
M.EFFECT = {
    killed = { target = { story = 3, investment = 3 }, table = { story = 2 }, vendetta = 2 },
    backstory = { target = { story = 3, spotlight = 2 }, table = { story = 1 }, vendetta = 2 },
    knockdown = { target = { spotlight = 1, investment = 1 }, vendetta_from = 3 },
    defeat = { all = { investment = 1 }, vendetta_all = 1 },
    escape = { all = { story = 1 } },
    humiliated = { target = { spotlight = 2, social = 1 }, table = { social = 1 } },
    tag = { target = { social = 1 }, table = { social = 2 } },
    joke = { target = { social = 1 }, table = { social = 2 } },
    generic = { table = { story = 1 } },
}
M.VENDETTA_MAX = 5
M.VENDETTA_FADE = 4          -- sessions without the villain before Vendetta fades by one
-- Grudge (0 to 5) sets how much the villain has to say: callbacks per monologue, and the fan.
M.CALLBACKS = { [0] = 1, 1, 2, 2, 3, 4 }
M.FAN = 3
M.FAN_HIGH = 4               -- at Grudge 4 or more
M.INTERRUPT = { investment = 60, chance = 0.33 }

-- Templates per voice and kind of memory.
M.LINES = {
    gloater = {
        killed = { "Where's {fallen}, {char}? Oh, that's right. I left them at {place}.",
                   "Remember {fallen}? I do. I remember every second of {place}.",
                   "{fallen} fell at {place}, and I didn't even break a sweat." },
        backstory = { "How's {hook}, {char}? Still smoking?",
                      "{hook}. I hear it doesn't sleep at night. Neither will you.",
                      "Ask me about {hook}, {char}. I tell it better than you do." },
        knockdown = { "Comfortable down there, {char}? You looked it at {place}.",
                      "I've had {char} on the floor before. I'll have them there again.",
                      "Still bruised from {place}, {char}? Good." },
        knockdown_repeat = { "That's {count} times, {char}. Do you even get up any more?",
                             "{count} times on your back, {char}. I've started keeping a tally.",
                             "{char}, the floor knows your name by now. {count} times." },
        defeat = { "You ran from {place}. I watched you run. It was glorious.",
                   "Last time, at {place}, you crawled away. Let's see you crawl again.",
                   "You lost at {place}. Do you want me to tell it, or will you?" },
        escape = { "You had me at {place}. You let me walk. Big mistake.",
                   "I walked out of {place} laughing. I'm still laughing.",
                   "Still sore about {place}? I slept like a baby." },
        humiliated = { "{place}. You think I've forgotten {place}, {char}? I think about it every day.",
                       "A lucky day at {place}, {char}. You won't get two.",
                       "You made a fool of me at {place}. Nobody makes a fool of me twice." },
        tag = { "Ah, {tag}. Everyone's heard about you, {char}.", "Is this the famous {tag}? I expected more falling over.",
                "Do me a favour, {char}: be {tag} today. It saves me the trouble." },
        joke = { "Oh, I've heard about {joke}. The whole valley has.", "{joke}? Really? This is who they sent?",
                 "Tell me about {joke} again. I could use a laugh before the end." },
        generic = { "So you're the ones everyone's whispering about. How disappointing.",
                    "Look at you. All of you. This is going to be fun.",
                    "Come closer. I want a good look at the people who keep getting in my way." },
        replacement = { "Another one, {char}? The last one didn't last.", "Who are you? Oh, I see. {fallen}'s replacement. Cute." },
        shelf = { "{count} of you on that shelf already. Room for more." },
    },
    mastermind = {
        killed = { "{fallen} was always going to fall at {place}. They simply stood where I needed them.",
                   "I planned {place} for weeks. {fallen} was a line in the plan.",
                   "{fallen} made one mistake at {place}. You've made several since." },
        backstory = { "{hook}, {char}. I know every detail. I arranged most of them.",
                      "Did you think {hook} was an accident? Nothing is an accident.",
                      "I keep a file on {hook}, {char}. It is very thick." },
        knockdown = { "{char} went down at {place} in the second minute. I had it at three.",
                      "You fell exactly where I expected at {place}, {char}.",
                      "I've studied how you fall, {char}. Left knee first." },
        knockdown_repeat = { "{count} times, {char}. Your pattern is very easy to read.",
                             "{count} falls, {char}. I could set a clock by you.",
                             "You've gone down {count} times, {char}. That isn't bad luck. That's a habit." },
        defeat = { "{place} went exactly as I planned. Did you think you were winning?",
                   "You retreated from {place} on schedule. I wrote the schedule.",
                   "Losing at {place} was the point, {char}. You just didn't know it." },
        escape = { "I left {place} by the door I built for that purpose.",
                   "You never had me at {place}. You had what I let you have.",
                   "My exit from {place} was planned before you arrived." },
        humiliated = { "{place} was an error. I don't make the same error twice, {char}.",
                       "You disrupted {place}, {char}. I've adjusted. You haven't.",
                       "I've thought about {place} a great deal. So should you." },
        tag = { "{tag}. Predictable. That's all I need from you, {char}.",
                "Your reputation precedes you, {char}. {tag}. It's in my notes.",
                "A {tag} on the front line. How convenient for me." },
        joke = { "{joke}. I'm told it's very funny. I don't see it.",
                 "You still joke about {joke}. Good. Distracted people are easy.",
                 "I've read about {joke}. It explains a great deal about this party." },
        generic = { "You're early. Not by much. I accounted for it.", "Every step you took to get here, I chose.",
                    "Sit, if you like. This will take as long as I decide." },
        replacement = { "A new face, {char}. {fallen}'s, I assume. I've already opened a file.",
                        "{fallen} was replaced in a week. So will you be." },
        shelf = { "{count} heroes on your shelf. I have a list of who's next." },
    },
    zealot = {
        killed = { "Your gods didn't catch {fallen} at {place}. Mine don't let go.",
                   "{fallen} was judged at {place}. The judgment was final.",
                   "{fallen} heard the hush at {place}. Soon all of you will." },
        backstory = { "{hook} burned because it had to, {char}. The fire was a mercy.",
                      "You carry {hook} like a wound. Lay it down. Join it.",
                      "{hook} was only the beginning, {char}. The rest is written." },
        knockdown = { "You fell at {place}, {char}. The earth was reaching for you.",
                      "Kneel again, {char}, the way you knelt at {place}.",
                      "The ground remembers you from {place}, {char}. It wants you back." },
        knockdown_repeat = { "{count} times you've fallen, {char}. Stop fighting what you are.",
                             "{count} times on your knees. Even you must see the sign.",
                             "{count} times, {char}. It's where you belong." },
        defeat = { "You fled {place} because you knew. You still know.",
                   "{place} was a lesson. You didn't learn it. I'll teach it again.",
                   "At {place} you saw the truth, and ran from it." },
        escape = { "I walked out of {place} because I was meant to. You can't stop what's meant.",
                   "{place} couldn't hold me. Nothing you build will.",
                   "You thought {place} was an ending. It was a test, and you failed it." },
        humiliated = { "{place} was a trial, {char}, and I'm stronger for it.",
                       "You struck a blow at {place}, {char}. It changed nothing.",
                       "I forgive you for {place}, {char}. That's what makes this sad." },
        tag = { "Even {tag} has a place in what's coming, {char}.", "They call you {tag}. I call you lost.",
                "Look at you. {tag}. The faith needs no better proof." },
        joke = { "You laugh about {joke}. Laugh while you can.", "{joke}. The hush will take that too.",
                 "Hold on to {joke}, {char}. Soon there'll be nothing to laugh at." },
        generic = { "Can you hear it? The quiet. It's coming for all of you.",
                    "You were always going to end up here. All of you.",
                    "Put down your weapons and listen. Just once, listen." },
        replacement = { "Another one sent to replace {fallen}. The hush is patient, {char}." },
        shelf = { "{count} already given to the quiet. The rest of you will follow." },
    },
    tragic = {
        killed = { "I didn't want {fallen} to die at {place}. You made me choose.",
                   "I think about {fallen} every night. Do you?",
                   "{fallen} could have walked away at {place}. Why didn't they?" },
        backstory = { "I know what {hook} means to you, {char}. I had one too, once.",
                      "I'm sorry about {hook}. I'd do it again. That's the worst part.",
                      "{hook}. We're not so different, {char}. That's what scares you." },
        knockdown = { "I didn't enjoy {place}, {char}. Please don't make me do it again.",
                      "Stay down this time, {char}. I'm asking.",
                      "You fell at {place}, and I almost reached out. Almost." },
        knockdown_repeat = { "{count} times, {char}. Why do you keep getting up?",
                             "{count} times. Please don't make it one more.",
                             "Every time you fall, {char}, I hope it's the last. {count} now." },
        defeat = { "I let you leave {place}. I hope you understood why.", "You lost at {place}. I didn't celebrate.",
                   "I could have ended it at {place}. I couldn't do it." },
        escape = { "I ran from {place}. I'm tired of running, {char}.",
                   "I left {place} because I wasn't ready to finish this. Are you?",
                   "You let me go at {place}. I'll never know why." },
        humiliated = { "You beat me at {place}, {char}. Maybe you're right about me.",
                       "{place} hurt. You meant it to. I understand.",
                       "I still dream about {place}. You were kinder than I'd have been." },
        tag = { "They call you {tag}. I know what it is to be called things.",
                "{tag}. It doesn't define you, {char}. Trust me.", "I've heard about {tag}. I'm sorry. People can be cruel." },
        joke = { "You still laugh about {joke}. I miss laughing.", "{joke}. I wish I'd been there. Before all this.",
                 "Tell me about {joke}. Just once, before we start." },
        generic = { "I hoped you wouldn't come. I really did.", "Turn around. Go home. I'm begging you.",
                    "It didn't have to be you. It never had to be you." },
        replacement = { "You took {fallen}'s place, {char}. I'm sorry. I'm so sorry." },
        shelf = { "{count} of you gone already. Isn't that enough?" },
    },
    petty = {
        killed = { "Remember {fallen}? I do. They owed me two silver.",
                   "{fallen} fell at {place} and never even apologised. Rude.",
                   "Session {week}, {place}: goodbye, {fallen}. I wrote it in my diary." },
        backstory = { "{hook}, {char}? I know all about it. I have a whole page on it. With drawings.",
                      "Oh, poor {char}, still upset about {hook}? I've cried about less.",
                      "{hook}. I'd tell you what I know, but you were rude to me." },
        knockdown = { "I saw you trip at {place}, {char}. I've told everyone.",
                      "You fell over at {place}. I laughed. I'm still laughing. Inside.",
                      "{char}, flat on your back at {place}. I had it painted." },
        knockdown_repeat = { "That's {count} times, {char}. I've been counting. I always count.",
                             "{count}! {count} times! I made a little chart.",
                             "{count} times down, {char}. I'm framing the chart." },
        defeat = { "Session {week}. {place}. You ran. I have it in writing.",
                   "I still have the boot you lost at {place}. I'm keeping it.",
                   "You lost at {place} and you didn't even say good game." },
        escape = { "You had me at {place} and I got away. Ha. Ha! Still funny.",
                   "I left {place} with your sandwich. I want you to know that.",
                   "{place}! The great escape! They'll sing about it. I'm writing the song." },
        humiliated = { "You threw a chicken at me at {place}, {char}. I have not forgotten the chicken.",
                       "{place}. You embarrassed me in front of my people, {char}. I'm still upset.",
                       "I've thought of a comeback for {place}, {char}. It's late, but here it is." },
        tag = { "Oh look, it's {tag}! Can I get an autograph? Can you write?",
                "{tag}! My favourite. Do the thing. Do the thing where you fall.",
                "Everybody look, it's {tag}. Careful, they might trip on you." },
        joke = { "Is this about {joke}? Everyone keeps telling me about {joke}.", "{joke}! Ha! I didn't get it. Explain it slower.",
                 "I made up a joke about {joke}. It's better than yours." },
        generic = { "You again! I've been waiting all week. I practised.",
                    "Oh, it's you lot. I'm not even surprised. I'm a bit surprised.",
                    "Stop right there! I have a speech. It's a good one." },
        replacement = { "New person! Hello! Did {fallen} leave a note? They owed me money." },
        shelf = { "{count} on the shelf! I've got a shelf too. Mine's for trophies." },
    },
}

-- The way in and the way out of a monologue, by how much the villain has built up.
M.OPENER = {
    gloater = { low = "So. You're the ones they keep talking about.", rising = "I've been watching you. All of you. And I remember.",
                high = "Look at you. Still standing. Let me remind you what that's cost." },
    mastermind = { low = "Good. You found me. Exactly when I expected.", rising = "I've had weeks to study you. Let me share my notes.",
                   high = "Every loss you've had, I can list in order." },
    zealot = { low = "Welcome, lost ones. Listen.", rising = "I've watched you walk toward this for weeks.",
               high = "Everything you've lost, you lost for a reason. Let me name it." },
    tragic = { low = "I hoped I'd never meet you.", rising = "I keep hearing your names. I wish I didn't.",
               high = "I've kept count of what this has cost. Have you?" },
    petty = { low = "Finally! I've been waiting. I brought snacks.", rising = "I've kept a list. A long list. With headings.",
              high = "I brought the list. All of it. Sit down, this takes a while." },
}
M.CLOSER = {
    gloater = { "Now. Shall we finish what we started?", "Come on, then. Make it worth my time." },
    mastermind = { "Proceed. You'll do exactly what I expect.", "Take your time. It won't change the outcome." },
    zealot = { "Come, then. Meet what's waiting.", "Let it begin. It already has." },
    tragic = { "Let's just get this over with.", "Forgive me. For what comes next." },
    petty = { "Right! That's the speech. Now we fight. Ready? Ready.", "And that's why you're all terrible. Get them!" },
}

-- Last words: the biggest taunt nobody has answered yet comes back one more time.
M.LAST_WORDS = {
    gloater = { killed = "Tell {fallen}... I'll see them soon...", backstory = "{hook}... still burning...",
                other = "Remember... {place}..." },
    mastermind = { killed = "{fallen}... was still... part of the plan...", backstory = "{hook}... was only... the start...",
                   other = "This... wasn't... in the plan..." },
    zealot = { killed = "The hush... took {fallen}... it will take you...", backstory = "{hook}... was meant...",
               other = "The quiet... is coming..." },
    tragic = { killed = "I'm sorry... about {fallen}...", backstory = "{hook}... I'm sorry...", other = "Thank you... for ending it..." },
    petty = { killed = "You never... paid back... {fallen}'s two silver...", backstory = "I'll haunt... {hook}... forever...",
              other = "I'm... telling... everyone..." },
}

-- Retorts: the final hit that answers the villain, by the striker's class and what was said.
M.RETORT = {
    fighter = { killed = "\"For {fallen}.\" {char} brings the sword down, and doesn't look away.",
                backstory = "\"That's for {hook}.\" One swing, with everything behind it.",
                knockdown = "\"I got up. Every time. You don't.\" The blade does the rest.",
                other = "\"You talk too much.\" One clean cut." },
    rogue = { killed = "\"{fallen} says hello.\" The knife finds the gap.",
              backstory = "\"Consider {hook} paid in full.\" A flick of the wrist.",
              knockdown = "\"Look who's on the floor now.\" {char} doesn't even wait for an answer.",
              other = "\"Darling. Shh.\" And it's over." },
    cleric = { killed = "\"{fallen} is at peace. You won't be.\" The mace comes down with all of it.",
               backstory = "\"For {hook}. Go, and don't come back.\" Light, and then nothing.",
               knockdown = "\"The light lifted me. It won't lift you.\"",
               other = "\"Enough. Be still.\"" },
    wizard = { killed = "\"This one is for {fallen}. I've been saving it.\" The spell lands like a full stop.",
               backstory = "\"{hook}. Footnote one: you lose.\"",
               knockdown = "\"I took notes every time I fell. Here is the summary.\"",
               other = "\"Your monologue was too long. Mine is one word.\"" },
}

-- The target at the table: fuel or salt.
M.FUEL = { "Mine. That one's mine.", "Oh, it is ON.", "Okay. Okay. Now it's personal.", "Write that down. I'm going to make them eat it.",
           "Nobody touch them. They're mine.", "That's it. I'm doing a voice when I finish this." }
M.SALT = { "That's not funny.", "...Can we move on?", "Wow. Okay.", "I'd rather not, actually.", "Ouch. Not cool." }
-- The interrupt: a player who's had enough of the speech.
M.INTERRUPT_LINES = { "I attack. Mid-sentence. I attack.", "Sorry, are they still talking? I'm rolling initiative.",
                      "Can I just... throw something?", "I'd like to interrupt with my sword." }
M.INTERRUPTED = { gloater = "You INTERRUPTED me?!", mastermind = "I wasn't finished.", zealot = "You dare speak over the faith?",
                  tragic = "...Fine. Fine.", petty = "RUDE! That was the best part!" }
M.SHRUG = { gloater = "As I was saying.", mastermind = "Noted. As I was saying.", zealot = "Your blade can't stop the word.",
            tragic = "Please. Let me finish.", petty = "Ow! Anyway." }

return M
