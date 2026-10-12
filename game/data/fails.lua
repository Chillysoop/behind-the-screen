-- The fail fan (M8, B2: "When a roll fails" in the GDD). A big roll that misses no longer asks
-- "how bad?": it deals three fail cards fitted to the scene, and you pick how the failure
-- lands. A flat fail ("it just doesn't work") is always there too. Data only: tune freely.
-- Lines are drafts in the game's voice; review them like the dialogue.
--
-- Kinds:
--   pratfall      it goes wrong, and it's funny. Instigators and Casual players love it; a
--                 Tactician hates it on their own big move; at a solemn moment it costs Trust
--   forward       fail forward: it doesn't work, but the story moves anyway
--   costly        costly success: it works, and the line names what it costs
--   dramatic      dramatic fail: it goes wrong in a way that raises the stakes
--   near          near miss: so close that their next try gets a bonus
-- Action types (from the skill rolled): talk, move, know.
-- Fill-ins: {char} the hero who rolled, {other_char} another hero, {Cast}/{cast} the scene's
-- person (only lines marked cast = true), {place} where they are, {prop} something at that kind
-- of place (PROPS below).

local M = {}

M.KINDS = { "pratfall", "forward", "costly", "dramatic", "near" }
M.NAMES = { pratfall = "Pratfall", forward = "Fail forward", costly = "Costly success", dramatic = "Dramatic fail",
            near = "Near miss", flat = "Flat fail", framed = "Their idea" }
M.ABOUT = {
    pratfall = "It goes wrong, and it's funny.",
    forward = "It doesn't work, but the story moves on.",
    costly = "It works, at a price.",
    dramatic = "It goes wrong and the stakes go up.",
    near = "So close. Their next try gets a bonus.",
    flat = "It just doesn't work.",
    framed = "They describe their own failure.",
}

-- What each kind does. success: which branch of the roll plays. Effects use the decision-card
-- targets ("actor", "all", "arch:..."). comic: a pratfall (the solemn-moment rule); edge: the
-- near miss's bonus on their next check.
M.EFFECTS = {
    pratfall = { success = false, comic = true,
                 effects = { { "all", social = 5 }, { "arch:instigator", fun = 6 }, { "arch:casual", fun = 5 },
                             { "actor", spotlight = 4 } } },
    forward = { success = false, story = true,
                effects = { { "all", story = 4 }, { "arch:storyteller", fun = 3 }, { "arch:casual", fun = 2 },
                            { "actor", spotlight = 3 } } },
    costly = { success = true,
               effects = { { "all", challenge = 4, story = 3 }, { "arch:tactician", fun = 2 }, { "actor", spotlight = 4 } } },
    dramatic = { success = false,
                 effects = { { "all", challenge = 7, story = 5 }, { "arch:storyteller", fun = 6 }, { "arch:instigator", fun = 3 },
                             { "arch:butt_kicker", fun = 3 }, { "arch:casual", fun = -3 }, { "actor", spotlight = 5 } } },
    near = { success = false, edge = 2,
             effects = { { "actor", fun = 2, spotlight = 2 }, { "arch:tactician", trust = 1 }, { "all", challenge = 2 } } },
    flat = { success = false, effects = { { "arch:tactician", trust = 1 } } },
    framed = { success = false, effects = { { "actor", fun = 6, spotlight = 6, trust = 1 }, { "all", social = 3 } } },
}

-- The roller's Fun at the moment of the roll ("roll mood", B2): a flat fail is shrugged off by
-- someone having a good night and hurts someone who's already drifting.
M.MOOD = { low = 40, high = 65 }
M.FLAT_BY_MOOD = { low = { fun = -4, commitment = -1 }, mid = { fun = -1 }, high = {} }
M.FLAT_FREE = 2                -- flat fails a night that even happy players shrug off
M.SOLEMN_TRUST = -3            -- a pratfall at a solemn moment, for Storytellers and Method Actors
M.TACTICIAN_PRATFALL = -6      -- a Tactician's own big move turned into a joke
M.FRAME_TRUST = 75             -- Trust from which a player offers to frame their own fail
M.VETO_FUN = -2                -- turning their idea down
M.JAIL_SOCIAL = 2              -- a natural 1 goes to dice jail: Social for everyone

M.ACTION = {
    persuasion = "talk", deception = "talk", intimidation = "talk", performance = "talk", insight = "talk",
    athletics = "move", acrobatics = "move", stealth = "move", sleight_of_hand = "move",
    investigation = "know", perception = "know", arcana = "know", history = "know", religion = "know",
    nature = "know", survival = "know", medicine = "know", animal_handling = "know",
}

M.PROPS = {
    tavern = { "a tray of tankards", "the bench by the fire", "the woodpile by the hearth", "a sleeping dog" },
    town = { "a fruit stall", "a rain barrel", "a market awning", "a cart of cabbages" },
    crowd = { "a fruit stall", "a juggler's pins", "a cart of cabbages" },
    shop = { "a shelf of jars", "a stack of ledgers", "a hat stand" },
    indoor = { "a shelf of jars", "a stack of ledgers", "a rickety chair" },
    forest = { "a low branch", "a mossy log", "a thornbush", "a very startled squirrel" },
    road = { "a milestone", "a muddy rut", "a hedge" },
    wild = { "a mossy log", "a thornbush", "a sheep with opinions" },
    camp = { "the cooking pot", "a tent line", "the firewood" },
    under = { "a loose flagstone", "a curtain of cobwebs", "a crumbling pillar" },
    ruin = { "a loose flagstone", "a crumbling pillar", "a toppled statue" },
    bells = { "the bell rope", "a narrow ledge", "a nest of pigeons" },
    high = { "a narrow ledge", "a nest of pigeons", "a loose shingle" },
    water = { "a coil of rope", "a slick plank", "a crab pot" },
    bridge = { "a slick plank", "the handrail", "a coil of rope" },
    port = { "a crab pot", "a coil of rope", "a stack of crates" },
    ship = { "the rigging", "a bucket of tar", "a coil of rope" },
    island = { "a palm frond", "a tide pool", "a coconut" },
    default = { "the nearest chair", "their own bootlaces", "a bucket nobody saw" },
}

-- Costs a costly success names (one is picked and filled in).
M.COSTS = {
    "{char}'s pack strap snaps and half of it rolls away",
    "the noise brings company",
    "it takes the last of the lamp oil",
    "{char} turns an ankle doing it",
    "{char}'s lucky charm doesn't survive it",
    "it takes an hour nobody had",
}

-- A player who trusts you offers their own fail (Trust 75+): what they ask to happen.
M.FRAMED = {
    talk = { "Can {char} just completely lose the thread and start talking about their childhood?",
             "What if {char} accidentally insults their mother? Like, really specifically.",
             "Can {char} panic and agree to something terrible?" },
    move = { "Can {char} fall off something? I really want {char} to fall off something.",
             "What if {char} gets stuck. Halfway. In front of everyone.",
             "Can {char} land in {prop}? Please?" },
    scout = { "Can {char} trip over something really loud? Like a bucket. A bucket would be good.",
              "What if {char} hides in the one bush that's already got someone in it?" },
    know = { "What if {char} is confidently, completely wrong, and tells everyone?",
             "Can {char} get distracted by {prop} at the worst moment?",
             "What if {char} finds something, but it's the wrong something?" },
}

M.LINES = {
    pratfall = {
        { "{char} goes for it with total confidence and lands face-first in {prop}." },
        { "{char} trips over {prop}. Nobody saw, except everyone." },
        { "{char}'s big moment is undone by a hiccup. A loud one.", act = "talk" },
        { "{char} opens with a wink. It's received as a facial spasm. Somebody offers water.", act = "talk" },
        { "Mid-sentence, {char} forgets {cast}'s name and calls them 'Mum'.", act = "talk", cast = true },
        { "{char} leans on {prop} for effect. It doesn't hold.", act = "talk" },
        { "{char} vaults {prop} beautifully, then keeps going, into a second, unplanned {prop}.", act = "move" },
        { "{char}'s cloak catches on {prop}. {char} keeps running. The cloak does not.", act = "move" },
        { "{char} creeps in perfectly, then sneezes. Three times.", act = "move" },
        { "{char} reaches for the handhold and grabs {other_char}'s face instead.", act = "move" },
        { "{char} studies the clue very seriously. It is upside down.", act = "know" },
        { "{char} announces the answer, proudly, to an empty room. Everyone else went the other way.", act = "know" },
        { "{char} sniffs the strange powder to identify it. It's pepper. It's a lot of pepper.", act = "know" },
        { "A pigeon chooses this moment, and {char}, specifically." },
        { "{char} strikes a heroic pose on {prop}. {prop} has other plans." },
        { "{char} steps on the one dry stick in the whole of {place}. Crack. Every head turns.", act = "scout" },
        { "{char} waves the others forward, very confidently, into plain sight.", act = "scout" },
        { "{char} creeps up perfectly, then sneezes. Three times.", act = "scout" },
    },
    forward = {
        -- Scouting ahead before a fight (the story playtest: a riddle line on an ambush read as nonsense).
        scout = {
            { "They're seen, but {char} saw the way out first: a gap on the far side nobody's watching." },
            { "No surprise for anyone, but {char} got a good count of them before the shout went up." },
            { "Spotted, and whoever's waiting shouts a name as they come. Now the party knows who sent them." },
        },
        talk = {
            { "{Cast} won't budge, but {lets|let} slip who would: there's someone else to ask.", cast = true },
            { "No deal. But on the way out, {cast}'s assistant whispers a name and a time.", cast = true },
            { "{Cast} {shuts|shut} the door on them. A note slides under it a minute later.", cast = true },
            { "It doesn't land. But everyone in earshot now knows exactly what the party wants, and someone follows them out." },
            { "{char} talks themselves into a corner, and out of it into a different room, which is where the answer was." },
            { "The bluff falls flat, and the laugh it gets buys them a seat at the table anyway." },
            { "{Cast} {says|say} no. Loudly. The person they glance at while saying it is the real answer.", cast = true },
            { "Nobody's convinced, but the argument wakes up the one person at {place} who knows something." },
            { "It goes nowhere. Then {other_char} asks the dumb question, and it goes somewhere." },
            { "{char}'s pitch fails, but the reaction tells them exactly what {cast} {is|are} afraid of.", cast = true },
        },
        move = {
            { "{char} doesn't make the jump, but the fall lands them on the ledge below, by a door nobody mentioned." },
            { "The climb fails halfway, and from halfway {char} can see where the path really goes." },
            { "{char} is spotted, runs, and the only way to run is the way they needed to go." },
            { "The lock wins. The hinges, it turns out, were never fixed." },
            { "{char} slips, grabs {prop}, and {prop} turns out to be a lever." },
            { "They don't get past quietly. They get past loudly, and now everyone's looking the wrong way." },
            { "{char} can't force it. But the noise draws out whoever was hiding behind it." },
            { "The rope snaps, and the drop is shorter than it looked. They're in, just not the way they planned." },
            { "{char} misses the grab, but knocks {prop} loose, and it rolls exactly where it's needed." },
            { "Too slow, but the chase takes them through {place}'s back way, which is new information." },
        },
        know = {
            { "{char} can't work it out, but now they know who could." },
            { "Wrong answer. The way the mechanism reacts to it narrows the right one down." },
            { "The trail goes cold, but something on {prop} says someone else came this way too." },
            { "{char} misreads the map and walks them straight into what they were looking for, from the wrong side." },
            { "Nothing here. That's the clue: someone cleaned this place, carefully, recently." },
            { "{char} doesn't spot it. {other_char} trips on it." },
            { "The book's no help. The note someone left in it is." },
            { "{char}'s guess is wrong, but wrong in a way that rules out the scary option." },
            { "They don't find the hidden thing. They find the person who hid it, also looking for it." },
            { "{char} can't place the symbol, but they remember exactly where they've seen it before." },
        },
    },
    costly = {
        scout = {
            { "{char} spots them first, and pays for it: a crossbow bolt grazes an arm on the way back." },
            { "They get the jump, but {char} dropped something getting back, and it's gone." },
        },
        talk = {
            { "{Cast} {agrees|agree}, for a favour, to be named later. That's never good.", cast = true },
            { "It works, and {cast} now {considers|consider} {char} a close personal friend. A clingy one.", cast = true },
            { "{Cast} {believes|believe} it. So does everyone else at {place}, which will be a problem.", cast = true },
            { "It works, but {char} had to promise something on {other_char}'s behalf." },
            { "They get what they wanted, and {cost}." },
            { "It lands, but the lie is a big one now, and someone will check it." },
            { "{Cast} {talks|talk}, but only after {char} pays more than they had.", cast = true },
            { "It works. {char} also, somehow, agreed to sing at a wedding." },
            { "The threat works, and {cast} will remember it for a long time.", cast = true },
            { "They're in, and {cost}." },
        },
        move = {
            { "{char} makes it, and {cost}." },
            { "Over the wall, and the wall comes with them, loudly." },
            { "They get through. {prop} doesn't." },
            { "{char} lands the jump and leaves a boot behind on the other side." },
            { "Quiet enough to get in. Not quiet enough to get out the same way." },
            { "The lock opens, and the pick snaps off inside it. That door's not locking again." },
            { "{char} holds it shut long enough, and their shoulder will complain about it all week." },
            { "Done, but {char} is soaked, scratched and smells strongly of {prop}." },
            { "They make it across, and {cost}." },
            { "{char} catches {other_char} in time. Both of them hit the wall on the way." },
        },
        know = {
            { "{char} works it out, and {cost}." },
            { "They find it, and in finding it, set off the thing guarding it." },
            { "The answer's right, and saying it out loud tells whoever's listening what the party knows." },
            { "{char} cracks it, but it takes all night, and the night was needed for something else." },
            { "They read the inscription. The inscription was the trap." },
            { "{char} identifies the poison by tasting it. Correctly. Mostly." },
            { "The tracks are clear now, and so is the fact that whatever made them is very big." },
            { "{char} figures out the mechanism and loses a fingernail to it." },
            { "They find the hidden door, and {cost}." },
            { "{char} remembers the old story, and the part where the heroes in it don't come back." },
        },
    },
    dramatic = {
        scout = {
            { "Too late: {char} walks right into the middle of them." },
            { "Seen, and there are more of them than anyone thought." },
            { "Spotted, and someone runs to fetch help. This is going to get bigger." },
        },
        talk = {
            { "{Cast} {goes|go} white, then very calm, then {calls|call} for the guard.", cast = true },
            { "The word {char} chose was the one word nobody says at {place}. Every head turns." },
            { "{Cast} {laughs|laugh}, and it isn't a nice laugh. 'You've no idea who you're talking to.'", cast = true },
            { "It goes so badly that {cast} now {knows|know} exactly what the party is after, and who to tell.", cast = true },
            { "The bluff is called, and the person who called it was standing behind them the whole time." },
            { "{char} pushes too hard. A knife is out before anyone decides to draw it." },
            { "It falls apart, and {cast} {takes|take} it as a declaration of war. Possibly correctly.", cast = true },
            { "The silence after {char} speaks lasts long enough for someone to slip out the back." },
            { "The deal goes sour so fast that the deal is now the problem." },
            { "{char}'s threat lands on the wrong person, who happens to be the dangerous one." },
        },
        move = {
            { "{char} falls, and the noise of it wakes the whole of {place}." },
            { "The ledge goes, and {char} with it. They catch the edge. For now." },
            { "Spotted. Not by a guard, by the thing guards are afraid of." },
            { "{char} slips, and {prop} goes over with them, along with any hope of quiet." },
            { "The door bursts open on the wrong side, into a room full of the wrong people." },
            { "{char} misjudges it, and now {other_char} is on one side and everyone else on the other." },
            { "The rope holds. The beam it's tied to doesn't." },
            { "{char} tumbles out of hiding into the middle of exactly what they were hiding from." },
            { "Too slow: whatever they were chasing is gone, and it took something with it." },
            { "The floor gives way, and below it is somewhere nobody meant to be." },
        },
        know = {
            { "{char} pulls the wrong lever. Something old and heavy starts to move." },
            { "Wrong answer. The doors seal, and the air starts to thin." },
            { "{char} reads the words aloud to check them. That was a mistake." },
            { "They follow the trail confidently, straight into the camp of whoever left it." },
            { "{char} touches the strange mark. It touches back." },
            { "The ritual was not a ritual of warding. {char} realises this a little late." },
            { "{char} identifies the creature as harmless. The creature disagrees." },
            { "The trap they were sure was disarmed was the second trap." },
            { "{char} finds the secret: it's worse than anyone guessed, and now it knows they know." },
            { "The map was a fake, and the people who made it are waiting where it leads." },
        },
    },
    near = {
        scout = {
            { "Almost: {char} sees them a heartbeat before they see {char}. Nobody gets the jump." },
            { "{char} catches the glint of a blade just as the shout goes up." },
        },
        talk = {
            { "{Cast} almost {goes|go} for it. One more push might do it.", cast = true },
            { "So close: {cast} {hesitates|hesitate}, and {char} sees exactly where the crack is.", cast = true },
            { "Not quite, but {cast} {is|are} listening now, which they weren't before.", cast = true },
            { "{char} loses them on the last line. The first half was perfect." },
            { "The room's half won over. The other half is the half that matters, but it's half." },
            { "{Cast} {shakes|shake} their head, slowly, like they want to be convinced.", cast = true },
            { "It doesn't land, quite. {char} knows exactly what to try next." },
            { "A no, but a soft one. A door left open a crack." },
            { "{char} gets a smile out of {cast}. Not a yes. A smile.", cast = true },
            { "Almost. {other_char} catches {char}'s eye: one more try." },
        },
        move = {
            { "Fingertips on the ledge, and then not. Next time they'll have it." },
            { "{char} gets three steps from the door before the floorboard creaks." },
            { "Just short. {char} knows the distance now." },
            { "The lock nearly gives. {char} can feel the last pin." },
            { "{char} slips at the top, but grabs {prop} and hangs on." },
            { "Seen, almost: the guard looks right at {char}, and decides it was a cat." },
            { "The rope burns through {char}'s hands, and holds, just." },
            { "{char} trips a step from the finish. Everyone saw how close it was." },
            { "Not quite through. {char} found the gap, though." },
            { "{char} falls off {prop}, but lands well, and knows the trick of it now." },
        },
        know = {
            { "{char} is one word off. They can feel it." },
            { "Nearly: the pattern is there, just out of reach." },
            { "{char} had it, then second-guessed it. The first guess was right." },
            { "The answer is on the tip of {char}'s tongue." },
            { "{char} finds the edge of the hidden panel, but not the catch." },
            { "So close: the trail is fresh, and it goes somewhere near." },
            { "{char} rules out everything but two. One of them is right." },
            { "The symbol's familiar. {char} will place it, given a minute." },
            { "{char} spots that something's wrong, but not what." },
            { "Nearly. {other_char} has the missing piece, and doesn't know it yet." },
        },
    },
}

-- Defeat scenes (B2): a lost fight ends in one of these instead of "wake up robbed". The party
-- loses without anyone dying. where: place settings it fits (nil = anywhere); story: what it
-- leaves the party (a lead, a debt, a grudge).
M.DEFEATS = {
    { id = "retreat", line = "They break and run, carrying whoever can't. Nobody's proud of it. Everyone's alive.",
      effects = { { "all", challenge = 4, story = 2 }, { "arch:butt_kicker", fun = -3 } } },
    { id = "captured", line = "They wake up in a cell, bound and stripped of their weapons. Someone wants them alive. That's worth knowing.",
      effects = { { "all", story = 6, challenge = 4 }, { "arch:storyteller", fun = 3 } } },
    { id = "left_for_dead", line = "They come to in the mud, where they were left for dead. Their purses are gone. Their grudge isn't.",
      effects = { { "all", story = 4 }, { "arch:butt_kicker", fun = 2 } } },
    { id = "rescued", line = "A stranger drags them out before the end: a debt, and a new face who now knows too much.",
      effects = { { "all", story = 5, social = 3 } } },
    { id = "ransomed", line = "They're held for ransom. Somebody pays it. Now the party owes somebody.",
      where = { "town", "crowd", "tavern", "port" }, effects = { { "all", story = 5, reward = -3 } } },
    { id = "swept_away", line = "The fight ends with the river: they're swept downstream, battered, a long way from where they started.",
      where = { "water", "bridge", "port", "ship" }, effects = { { "all", challenge = 3, story = 3 } } },
    { id = "spared", line = "The enemy stands over them, and walks away. 'Not today.' That's worse, somehow.",
      effects = { { "all", story = 6 }, { "arch:method_actor", fun = 3 } } },
    { id = "dragged_off", line = "Someone at the table goes down and the others drag them out through the back way, bleeding and furious.",
      effects = { { "all", challenge = 5, social = 2 } } },
}

return M
