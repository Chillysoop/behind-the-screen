-- The streamlined edition: four complete, authored Thursday nights.
-- Each episode has two prep choices, four live calls, and a closing hook.
-- Choices describe their stakes before a die is rolled. Every route reveals the
-- central clue; setbacks change the situation, never erase the next episode.
local M = {}

M.title = "The Silent Bells"
M.subtitle = "Four Thursdays. Your friends. A story worth telling."
M.agreement = "Everyone's here. Boundaries are agreed. Roll the important checks in the open. Heroes can fall, but defeat changes the story instead of ending it."
M.order = { "mara", "dev", "jess", "sam" }
M.players = {
    mara = { name = "Mara", char = "Thessaly", class = "wizard", class_name = "Wizard", thought = "I want to find out what happened to Ilsa.", subclass = "evoker", subclass_name = "Evoker" },
    dev = { name = "Dev", char = "Brannoc", class = "fighter", class_name = "Fighter", thought = "Give me something worth standing up to.", subclass = "champion", subclass_name = "Champion" },
    jess = { name = "Jess", char = "Pip", class = "rogue", class_name = "Rogue", thought = "I have a plan. It might even work.", subclass = "thief", subclass_name = "Thief" },
    sam = { name = "Sam", char = "Oswin", class = "cleric", class_name = "Cleric", thought = "Happy to help. No big speech, please.", subclass = "life", subclass_name = "Life Domain" },
}

local function reaction(key, text, pose)
    return { key = key, text = text, pose = pose or "lean" }
end
local function out(text, flags, who, words, pose)
    return { text = text, flags = flags or {}, reaction = who and reaction(who, words, pose) or nil }
end
local function option(id, title, body, success, failure, check, battle)
    return { id = id, title = title, body = body, success = success, failure = failure, check = check, battle = battle }
end
local function check(who, skill, bonus, dc)
    return { who = who, skill = skill, modifier = bonus, dc = dc }
end
local function scene(id, title, text, board, npc, options, extra)
    local s = { id = id, title = title, text = text, board = board, npc = npc, options = options }
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end

M.episodes = {
    {
        title = "Strangers at the Kettle", objective = "Give the party a reason to care about the missing bell-ringer.",
        intro = "Rain taps the windows of the Crooked Kettle. Every hour, Millbrook falls quiet to listen for bells that no longer ring. Gus brings four mugs. Your friends pull up their chairs.",
        board = "kettle", focus = {
            { id = "mara", title = "Mara's missing sister", body = "Ilsa's handwriting turns up in Wren's notebook. Give Thessaly a personal reason to follow the mystery." },
            { id = "jess", title = "Jess's old connections", body = "Wren recognizes Pip from the Velvet Hand. Let Jess decide what her old name means now." },
        },
        twists = {
            { id = "storm", title = "The lamps go out", body = "A thunderclap cuts the lights just as Wren starts talking. Someone moves in the dark." },
            { id = "festival", title = "A very bad song", body = "Gus insists the party perform at the harvest supper. Jess will absolutely try something." },
            { id = "stray", title = "An unexpected witness", body = "A muddy dog arrives carrying Tobin's scarf. The whole table wants to keep it." },
        },
        scenes = {
            scene("kettle_open", "Give the silence a voice", "Gus says the bells stopped nine days ago. Dev reaches for his sword. Jess asks if she can steal the stranger's soup. Wren, the apprentice, is trying to work up the courage to speak. How do you play her?", "kettle", "npc_stranger", {
                option("warm", "Let Wren ask for help", "Play her openly worried. The party gets her trust; her story stays public.", out("Wren asks the whole room to help find Tobin. Gus promises the party a warm bed when they return.", { wren_trust = true, gus_bed = true }, "sam", "I slide her my untouched soup. Oswin can help.")),
                option("guarded", "Make it a private confidence", "Wren wants discretion. Thessaly can reassure her: Persuasion +2, DC 12. A miss draws a spy's attention.", out("Wren trusts Thessaly with the north-road lead in private. The room never learns where they are headed.", { quiet_trail = true }, "mara", "Okay. I shut my notebook so she knows I'm listening."), out("Thessaly fumbles the reassurance. Wren still names the north road, but a stranger slips out to warn his employer.", { spy_warned = true }, "jess", "That guy definitely heard us. I'm remembering his coat."), check("mara", "Persuasion", 2, 12)),
                option("soup", "Follow Pip's soup gambit", "Let the joke open the conversation. Wren laughs; the party makes a very public entrance.", out("Pip offers an elaborate soup inspection. Wren laughs, relaxes, and tells them where Tobin went. Gus names a soup after Pip.", { soup_joke = true }, "jess", "Inspector Pip. Official soup business.", "cheer")),
            }),
            { id = "personal", by_focus = {
                mara = scene("ilsa_note", "A familiar hand", "Wren opens her notebook. A correction in the margin is unmistakably Ilsa's handwriting. Mara goes quiet. Jess starts a joke, then catches herself. What do you give this moment?", "kettle", "npc_stranger", {
                    option("letter", "Give Mara the handwritten page", "An honest clue: Ilsa was studying the bells. Let Mara say what Thessaly recognizes.", out("Thessaly recognizes Ilsa's cramped handwriting. Mara adds that her sister always underlined promises twice. You keep that detail.", { ilsa_promise = true }, "mara", "She wrote 'bring them home' twice. That sounds like her.")),
                    option("voice", "Ask Wren to remember Ilsa", "Speak as Wren. Reveal how Ilsa treated people, while keeping her whereabouts uncertain.", out("Wren remembers Ilsa teaching her the bell song, patiently, one note at a time. Thessaly carries a person with her, not just a clue.", { ilsa_song = true }, "mara", "Can I ask Wren to teach me that song?")),
                }),
                jess = scene("pip_name", "The name Pip left behind", "Wren calls Pip by an old Velvet Hand nickname. Jess grins, then asks, 'Do I get to decide why she knows me?' You have a useful NPC in your notes and a player offering you something better.", "kettle", "npc_stranger", {
                    option("friend", "Yes. You once helped her escape", "Make a shared kindness canon. Wren becomes a friend, and Pip's old crew may hear about it.", out("Jess says Pip smuggled Wren out of a bad job in a flour cart. Wren has trusted her ever since. Flour Cart becomes a table joke.", { pip_friend = true, flour_joke = true }, "jess", "I was very heroic. And extremely breaded.", "cheer")),
                    option("debt", "Yes. She covered for you once", "Give Pip a debt to repay through this adventure. Wren knows the honest version of her.", out("Jess decides Wren once hid Pip from Madame Sable. Finding Tobin is Pip's chance to repay a kindness.", { pip_owes_wren = true }, "jess", "Pip stops joking. 'Your turn to be looked after.'")),
                }),
            } },
            { id = "surprise", by_twist = {
                storm = scene("dark_kettle", "Someone moves in the dark", "The lamps go out. A chair scrapes beside Wren's bag. Sam says Oswin could make his holy symbol glow; Jess wants Pip to tackle the shape. Both plans would work differently.", "kettle", "npc_stranger", {
                    option("light", "Let the light reveal a face", "Oswin illuminates the room. The thief escapes, but everyone sees the wolf badge.", out("Oswin's light catches a wolf badge. The thief runs empty-handed. Wren knows someone is afraid of Tobin being found.", { wolf_badge = true }, "sam", "We saw his face. That's enough for tonight.")),
                    option("tackle", "Give Pip a chance to catch them", "Acrobatics +5, DC 13. Catch the thief for a clue; a miss leaves the bag torn but the lead intact.", out("Pip pins the thief under a bench. He gives up a chapel token before Gus throws him out.", { chapel_token = true }, "jess", "Inspector Pip has expanded her jurisdiction."), out("Pip slides into the bench. The thief tears the bag and flees, leaving his wolf badge caught on a strap.", { wolf_badge = true, spy_warned = true }, "dev", "I help Pip up. We got something."), check("jess", "Acrobatics", 5, 13)),
                }),
                festival = scene("harvest_song", "The song that went off script", "Gus hands Pip a spoon and announces tonight's entertainment. Jess invents a song about the missing bells. Dev wants to pound the table in time. Wren starts humming a verse neither of them knows.", "kettle", "npc_gus", {
                    option("chorus", "Let the room join the chorus", "Turn the joke into a shared memory. The whole town learns the party is helping.", out("The room joins in. Wren's forgotten verse names the north-road chapel. Gus promises to teach the town the next verse when they return.", { town_chorus = true }, "jess", "I'm writing down the stupid lyrics. They're canon now.", "cheer")),
                    option("quiet_verse", "Give Wren the last verse alone", "Let the laughter settle into a clue. Keep her memory gentle and personal.", out("You lower your voice for Wren's last verse. It names a chapel where the bell paths meet. For a moment, everyone listens.", { wren_song = true }, "mara", "That went from silly to lovely really fast.")),
                }),
                stray = scene("muddy_witness", "The table adopts a witness", "A soaked dog pushes through the door with Tobin's scarf. All four friends lean forward. Jess asks, 'Can we keep him?' Sam has already offered a piece of pizza to the miniature.", "kettle", "npc_stranger", {
                    option("keep", "Of course. Name the dog", "The dog joins the journey and will find a safe path later. Give the naming to the whole table.", out("They name him Biscuit. Wren recognizes Tobin's scarf, and Biscuit settles at Oswin's feet, ready to lead them north.", { biscuit = true }, "sam", "Biscuit gets the little shield token. For protection.", "cheer")),
                    option("home", "Give him a home at the Kettle", "Keep the journey focused. Gus adopts the dog and the party gains a reason to come back.", out("Gus promises Biscuit a bed by the fire. Wren recognizes the scarf and marks the place Tobin used to walk him: the north-road chapel.", { biscuit_home = true, gus_bed = true }, "dev", "First thing when we're back, we check on that dog.")),
                }),
            } },
            scene("north_gate", "A wolf at the gate", "Two of Kessrick's scouts wait outside Millbrook. They demand Wren's notebook. The party wants to protect her. You choose what kind of confrontation gives this first night its ending.", "forest_road", "tough", {
                option("stand", "Let the party stand their ground", "A short battle against two scouts. Victory keeps the notebook; defeat costs it, but Wren remembers the way.", out("The scouts retreat. Wren keeps her notebook and marks Tobin's last known stop: the north-road chapel.", { notebook_safe = true }, "dev", "That is how Brannoc says welcome to the party.", "cheer"), out("The scouts take the notebook. Wren leads the bruised party away and draws the chapel from memory. They still have a way forward.", { notebook_taken = true }, "mara", "They can take the book. They can't take what she remembers."), nil, { foes = { "bandit", "bandit" }, names = { "Wolf scout", "Wolf scout" }, sprites = { "tough", "tough" } }),
                option("decoy", "Let Pip offer a convincing fake", "Deception +3, DC 13. A success buys secrecy; a miss forces a hurried escape with Wren.", out("The scouts leave with Gus's soup accounts. Wren keeps the notebook. No one is chasing the party yet.", { notebook_safe = true, quiet_trail = true }, "jess", "The inventory is extremely confidential."), out("A scout spots the fake. The party escapes through the market while Wren keeps the notebook under her coat. The scouts know their faces.", { notebook_safe = true, spy_warned = true }, "sam", "We got everyone out. Good enough."), check("jess", "Deception", 3, 13)),
                option("bargain", "Trade the book for safe passage", "No roll. Wren keeps a copied map; Kessrick's scouts learn the party's names.", out("Wren quietly tears out the map before handing over the notebook. The scouts let them pass, carrying their names to Kessrick.", { notebook_taken = true, spy_warned = true }, "mara", "I write our names on the last page myself. He should know.")),
            }, { clue = { id = "north_road", text = "Tobin went to the north-road chapel after someone silenced the bells." } }),
        },
        hooks = {
            { id = "lantern", title = "Open on Tobin's lantern", body = "Next Thursday begins with a warm light in the chapel. Give them a person to rescue.", callback = "The lantern you chose for the opening glows in the ruined chapel. Tobin is hiding underneath the altar.", flag = "tobin_first" },
            { id = "scout", title = "Open on a scout's trail", body = "Next Thursday begins with a wolf badge in the mud. Give them someone to follow.", callback = "The wolf-badge trail you chose leads to the chapel. A scout drops a brass chapel token when the party follows him.", flag = "trail_token" },
        },
        keepsake = { id = "kettle_mug", name = "The Kettle mug", from = "sam", text = "Sam brings a spare mug next week. 'For the person doing all the voices.'" },
    },
    {
        title = "The road out", objective = "Find Tobin and learn how the bells were silenced.",
        intro = "The north road climbs into the pines. The party has a lead, and the bells remain silent. Tonight's story takes them to the little chapel where Tobin disappeared.", board = "forest_road",
        focus = {
            { id = "dev", title = "Dev's old enemy", body = "A wolf banner recalls Hale's Crossing. Let Brannoc decide what kind of protector he wants to be." },
            { id = "sam", title = "Sam's quiet discovery", body = "Oswin's relic begins to hum near the chapel. Give him a useful discovery without demanding a speech." },
        },
        twists = {
            { id = "flood", title = "The river has risen", body = "A broken bridge turns the road into a rescue. The party must decide who goes first." },
            { id = "deserter", title = "A scout wants out", body = "One of Kessrick's young scouts asks for help. His information comes with a human problem." },
            { id = "echo", title = "A bell no one else hears", body = "Only the party hears a bell inside the ruined chapel. Let curiosity change the scene." },
        },
        scenes = {
            scene("chapel_entry", "A face under the altar", "Tobin emerges from beneath the chapel altar. He knows why the bells fell silent, but he thinks every stranger is working for Kessrick. The party wants answers. How do you play his fear?", "chapel", "npc_hermit", {
                option("patience", "Let them help before asking", "No roll. Oswin treats his scraped hands. They gain Tobin's trust, while the pursuing scouts catch up.", out("Oswin tends Tobin's hands. The bell-ringer trusts the party and promises to guide them, though scouts can now be heard outside.", { tobin_ally = true, scouts_close = true }, "sam", "He doesn't have to earn a bandage.")),
                option("proof", "Let their evidence reassure him", "Persuasion +3, DC 12. A clear connection earns his help; a miss gets the facts but not his company.", out("The party lays out what they learned. Tobin sees that Wren sent real help and agrees to guide them.", { tobin_ally = true }, "mara", "I like that last week's details mattered."), out("Tobin gives them his map, then slips away through a gap in the wall. He wants them to succeed; he cannot stay.", { tobin_gone = true }, "sam", "Let him go. He's had a rough enough week."), check("sam", "Persuasion", 3, 12)),
            }),
            { id = "personal", by_focus = {
                dev = scene("village_banner", "The banner in the ashes", "A wolf banner hangs in the chapel. Dev recognizes the mark that flew over Brannoc's burned village. He asks if he can tear it down. Jess is ready with a joke, then looks to you.", "chapel", "npc_hermit", {
                    option("memory", "Give Dev a quiet minute", "Ask what Brannoc remembers protecting. His answer becomes a promise he can keep at the tower.", out("Dev says Brannoc remembers carrying a neighbor across the burning bridge. He folds the banner away: this time, everyone gets out.", { brannoc_protector = true }, "dev", "I'm not keeping a trophy. I'm keeping a promise.")),
                    option("defiance", "Let the whole party tear it down", "Make the moment shared defiance. Kessrick's people will hear what happened here.", out("The party tears the banner into strips and binds their gear with them. Brannoc does not have to carry his anger alone.", { wolf_defiance = true }, "dev", "Okay. That's our party now.", "cheer")),
                }),
                sam = scene("humming_relic", "A small, useful miracle", "Oswin's old relic hums beside the broken chapel bell. Sam notices it before anyone else. He says, 'Can I just try touching them together?' The others wait to see what you do.", "chapel", "npc_ghost", {
                    option("yes", "Let the sensible experiment work", "No roll for a good connection. Oswin learns the relic can restore a bell's voice.", out("The broken bell gives one clear note. Oswin's relic is part of the old ward. Sam draws a tiny bell on his sheet.", { relic_voice = true }, "sam", "Oh. That's actually useful. I put it somewhere safe.")),
                    option("echo", "Let the relic answer with a memory", "Give Oswin a personal clue: his old abbot left him something deliberately.", out("For a moment, Oswin hears his abbot: 'A voice can be carried through silence.' Sam realizes the relic was entrusted to him, not merely rescued.", { abbot_memory = true, relic_voice = true }, "sam", "He knew I'd need it. I wasn't just the last one out.")),
                }),
            } },
            { id = "surprise", by_twist = {
                flood = scene("river_rescue", "The rope in the current", "Outside the chapel, a flooded stream cuts off the escape path. Wren tests the bridge and is stranded on a broken support. Dev wants to jump; Sam proposes a rope anchored around a tree. Who gets the scene's defining moment?", "old_bridge", "npc_stranger", {
                    option("rope", "Let the careful plan work", "No roll. The rope rescue takes time, so the scouts will see where the party went.", out("The party anchors a rope and brings Wren across safely. Their careful work leaves an obvious trail, but nobody falls.", { wren_safe = true, scouts_close = true }, "sam", "Sometimes the rope on the character sheet gets its day.")),
                    option("leap", "Give Brannoc the heroic leap", "Athletics +5, DC 14. Success is swift; a miss costs his pack, while the rope saves both people.", out("Brannoc clears the gap and brings Wren back. She knots a blue ribbon around his wrist in thanks.", { wren_safe = true, blue_ribbon = true }, "dev", "Yes! That was worth rolling for.", "cheer"), out("Brannoc catches the edge. The rope holds, and the party hauls both people up. His pack washes away; Wren is safe.", { wren_safe = true, lost_pack = true }, "dev", "The pack can go. We got her."), check("dev", "Athletics", 5, 14)),
                }),
                deserter = scene("young_scout", "A scout without a badge", "A young scout sets down his crossbow. 'My name is Ren. I didn't sign up to burn towns.' Dev watches him closely. Ren knows a way into the tower, but giving him shelter is a choice.", "forest_road", "tough", {
                    option("shelter", "Give the deserter a chance", "Ren guides them to a side entrance. The party accepts responsibility for getting him somewhere safe.", out("Ren draws the tower's side entrance in the mud. Brannoc offers him a place behind the party, away from Kessrick.", { ren_ally = true, side_entrance = true }, "dev", "Brannoc knows what his boss does. Ren can walk with us.")),
                    option("release", "Take his warning and let him go", "The party learns about the tower guard. Ren leaves alone; no new person to protect.", out("Ren warns them that Vask commands the tower guard, then vanishes into the trees. They know whom they are facing.", { vask_warning = true }, "sam", "We can wish him luck without making him a prisoner.")),
                }),
                echo = scene("unheard_bell", "The bell in the silence", "A bell rings inside the ruined chapel, although its rope lies cut. Thessaly hears three notes. Pip hears only two. Mara wants to investigate; Dev asks whether this is a trap.", "chapel", "npc_ghost", {
                    option("listen", "Let them follow the missing note", "Arcana +5, DC 13. Success reveals a ward phrase; a miss reveals the same route with a warning flare.", out("Thessaly finds the missing note in an inscription: 'A borrowed voice can break the hush.' The party copies the ward phrase.", { ward_phrase = true }, "mara", "It's a lock that expects a song. I love that."), out("Thessaly sounds the wrong note. The chapel flashes blue, warning the tower, but the revealed inscription gives them the ward phrase.", { ward_phrase = true, tower_alert = true }, "mara", "We learned something. They learned we're here."), check("mara", "Arcana", 5, 13)),
                    option("mark", "Let them mark it and move on", "Keep the night moving. Tobin's notes identify the ward later; the party avoids sounding an alarm.", out("The party marks the bell and takes a rubbing. Tobin's notes explain the phrase later, without waking the tower's sentries.", { ward_phrase = true }, "dev", "Thank you. Creepy bells noted. Onward.")),
                }),
            } },
            scene("chapel_exit", "The map leaves the chapel", "Kessrick's scouts close around the chapel. Tobin's map shows the hush was placed from inside Millbrook's tower, using a copied key. The party has the answer; now it needs a way out.", "chapel", "tough", {
                option("hold", "Run a stand at the doorway", "A brief fight: three scouts against the party. Victory secures a captured badge; defeat means a narrow escape.", out("The party holds the doorway. A captured scout's badge bears the name Vask. They leave with Tobin's map and a clear next lead.", { captured_badge = true }, "dev", "That doorway was ours.", "cheer"), out("The scouts force the party out through the ruined wall. They keep Tobin's map, but Vask now knows someone is coming.", { tower_alert = true }, "sam", "Map, friends, exit. We got the important things."), nil, { foes = { "bandit", "bandit", "bandit" }, names = { "Wolf scout", "Wolf scout", "Wolf scout" }, sprites = { "tough", "tough", "tough" } }),
                option("smoke", "Let a clever distraction carry it", "Pip starts a noisy argument while Thessaly makes a smoke screen. Deception +3, DC 12; a miss alerts the tower.", out("Pip's argument is so convincing that the scouts watch the wrong doorway. The party slips out with the map.", { quiet_escape = true }, "jess", "Pip has strong opinions about chapel maintenance."), out("A scout sees through the distraction. The party escapes with the map, but the warning reaches Vask first.", { tower_alert = true }, "mara", "We still know where to go."), check("jess", "Deception", 3, 12)),
                option("exchange", "Offer the scouts an honest deal", "No roll. Give them their stolen supplies back; they allow the party through and report the meeting.", out("The party returns the scouts' supplies and walks away with the map. Vask will hear about the deal, but nobody is hurt.", { scouts_deal = true, tower_alert = true }, "sam", "I'll take an ending where everyone gets to go home.")),
            }, { clue = { id = "inside_key", text = "The hush was laid from inside the tower; someone copied Tobin's key." } }),
        },
        hooks = {
            { id = "market", title = "Madame Sable has the receipt", body = "Begin next week in Pip's old world. Sable knows who bought the copied key.", callback = "You open where you promised: Madame Sable's back room. A receipt for Vask's copied key waits on her desk.", flag = "sable_receipt" },
            { id = "scriptorium", title = "Ilsa left an annotated map", body = "Begin next week with Corin. Her handwriting connects the mystery to the tower's ward.", callback = "You open where you promised: Corin has Ilsa's annotated map. Her notes connect the copied key to the tower's ward.", flag = "ilsa_annotations" },
        },
        keepsake = { id = "little_map", name = "The folded map", from = "mara", text = "Mara brings a hand-drawn map of the road. 'So we remember how we got here.'" },
    },
    {
        title = "Old debts", objective = "Learn who holds the tower and carry a personal promise into the finale.",
        intro = "The copied key leads back to Millbrook. Madame Sable knows who bought it; Corin has Ilsa's notes about the hush. Tonight, the party's past becomes the way forward.", board = "velvet_den",
        focus = {
            { id = "jess", title = "Jess's debt comes due", body = "Madame Sable offers Pip a clean slate at a cost. Let Jess show who Pip has become." },
            { id = "mara", title = "Mara finds Ilsa's message", body = "Corin has kept one letter back. Give Thessaly an honest moment with her sister's choices." },
        },
        twists = {
            { id = "theory", title = "Make their theory matter", body = "The table guessed that a bell song opens the ward. You can build tonight's reveal around that idea." },
            { id = "chase", title = "A roll behind the screen", body = "A courier chase brings a genuine tempting miss. Make one clear ruling, then live with it." },
            { id = "dinner", title = "An awkward invitation", body = "Sable insists on dinner before business. Give the table room for a memorable voice." },
        },
        scenes = {
            scene("two_witnesses", "Two people with something to lose", "Sable has the buyer's name. Corin has the ward notes. Each fears the other will use the information badly. The party proposes bringing them together. How do you frame the meeting?", "velvet_den", "npc_sable", {
                option("honesty", "Put both accounts on the table", "No roll. They cooperate openly, and everyone learns the party is preparing to take the tower.", out("Corin and Sable compare their records. Vask bought the key to disable the valley's protective bells. The party's intention is now public.", { public_plan = true }, "mara", "Two people telling half the truth. That's a nice way to make a whole clue.")),
                option("discretion", "Offer each a private assurance", "Persuasion +3, DC 13. Keep the plan quiet on success; a miss leaves Sable expecting a favor.", out("The party wins both witnesses' confidence. Vask's name and the ward notes leave the room quietly.", { discreet_allies = true }, "sam", "Good. They can both be safe when we leave."), out("Sable agrees to share what she knows, but expects the party to speak for her when the town asks questions. They accept the favor.", { sable_favor = true }, "jess", "That woman can invoice a conversation."), check("sam", "Persuasion", 3, 13)),
            }, { clue = { id = "vask", text = "Vask bought the copied key and holds the tower for Kessrick." } }),
            { id = "personal", by_focus = {
                jess = scene("pip_debt", "The price of a clean slate", "Sable lays Pip's debt ledger on the table. 'Bring me Vask's signet, and this page burns.' Jess asks if Pip can refuse the bargain without losing the clue. You can make the choice about her character.", "velvet_den", "npc_sable", {
                    option("accept", "Let Pip take the bargain", "The clue is already theirs. This promise makes Vask's signet matter in the finale.", out("Pip accepts Sable's offer on her own terms. Vask's signet can clear her debt; the party agrees to help her get it.", { pip_signet = true }, "jess", "This time I'm making a deal with friends behind me.")),
                    option("refuse", "Let Pip leave the ledger behind", "Pip keeps the debt but refuses to let it direct the adventure. Sable still honors the information already given.", out("Pip leaves the ledger on Sable's desk. 'Keep the number. You don't get to keep me.' The clue stays with the party.", { pip_independent = true }, "jess", "That's the first time she's walked away from that desk.", "cheer")),
                }),
                mara = scene("ilsa_letter", "The letter Corin couldn't deliver", "Corin admits he hid Ilsa's last letter because it says she entered the tower willingly. Mara asks, 'Did she choose the ward over coming home?' You know the answer, and the table is listening.", "ilsa_room", "npc_corin", {
                    option("truth", "Give Mara the difficult truth", "Ilsa chose to protect the valley. Thessaly can decide how she feels about that.", out("Ilsa's letter says she stayed to hold the ward together. Mara lets Thessaly be proud and angry at once. Corin promises to help find her.", { ilsa_truth = true, corin_ally = true }, "mara", "She could have told me. I'm going to tell her that.")),
                    option("promise", "Let the letter ask for help", "Keep Ilsa active in the story: she left a task only her sister could finish.", out("Ilsa asks Thessaly to complete the bell song if she cannot. Mara writes the final line in her own words. It will be part of the finale.", { ilsa_last_line = true }, "mara", "Then I know exactly what I'm saying at the bell.")),
                }),
            } },
            { id = "surprise", by_twist = {
                theory = scene("their_theory", "They guessed the lock", "Jess says, 'What if the hush is a song sung backward?' Mara points to the repeated notes on the map. You had a stone puzzle prepared, but their theory fits what they've learned.", "ilsa_room", "npc_corin", {
                    option("true", "Make their theory the answer", "Preserve the clues already found. The song becomes the way to open the ward.", out("Corin turns Ilsa's page upside down: the pattern matches. Their song theory becomes true, and the party carries the missing verse to the tower.", { theory_true = true, ward_song = true }, "jess", "WE CALLED IT. Write that down.", "cheer")),
                    option("part", "Make it a useful part of the answer", "The song opens the outer lock; Oswin's relic breaks the final hush. Both discoveries will matter.", out("The repeated notes open the outer lock. Ilsa's margin says the last seal needs a living voice carried by the old relic. The theory gives them half the answer.", { theory_partial = true, ward_song = true, relic_needed = true }, "sam", "So the weird little relic gets a job. Nice.")),
                }),
                chase = scene("hidden_roll", "A miss you could soften", "A courier carrying Ilsa's ward page jumps a roof gap. You rolled Pip's pursuit behind the screen. Before changing anything, decide what a miss should mean: the clue can survive while the situation changes.", "market", "tough", {
                    option("honor", "Keep the roll and its stakes", "On a miss, the courier drops the page but escapes to warn Vask. On success, Pip catches him.", out("You keep the roll. Pip catches the courier and the ward page stays secret. Sam nods at the consistent ruling.", { ward_page = true, fair_roll = true }, "sam", "We knew what the roll meant. I like that."), out("You keep the miss. The courier drops the ward page as he escapes, taking a warning to Vask. The story moves with a new complication.", { ward_page = true, fair_roll = true, tower_alert = true }, "jess", "Okay. He's going on the list.")),
                    option("offer_cost", "Offer success with a clear cost", "Ask Jess: catch the courier, but break Pip's favorite lockpick. She accepts; the cost becomes part of the story.", out("Jess accepts the trade. Pip catches the courier, but her favorite lockpick snaps. Sam accepts the openly agreed cost; nobody changes the die.", { ward_page = true, broken_pick = true }, "jess", "That was her lucky pick. I'm keeping the pieces.")),
                    option("cook", "Quietly call the roll a success", "The courier is caught. Sam cannot see the die, but the conveniently clean result makes him ask about future rolls.", out("You soften the hidden roll without explaining. Pip catches the courier. Sam asks quietly whether the next important die can stay in the open; you agree.", { ward_page = true, cooked_once = true }, "sam", "Could we keep the next big one where everyone can see it?", "crossed")),
                }, { preview_check = check("jess", "Acrobatics", 5, 15), preview_policy = true }),
                dinner = scene("sable_dinner", "Business over soup", "Sable serves an aggressively formal dinner. Jess launches into Pip's finest fake accent. Mara is ready to get back to Ilsa. Both are engaged, in different ways. How do you pace the scene?", "velvet_den", "npc_sable", {
                    option("one_toast", "Give Pip one glorious toast", "Let Jess finish the bit, then have Sable's answer reveal the ward page.", out("Pip delivers a magnificent, terrible toast. Sable replies in the same accent and slides the ward page under her bowl. The joke delivers the clue.", { sable_toast = true, ward_page = true }, "jess", "I can't believe you did the accent back.", "cheer")),
                    option("invite", "Let Pip bring Thessaly into it", "Ask Jess to make the toast about Ilsa. Share the spotlight through the fiction.", out("Pip raises a glass to the sister who kept trying. Mara adds the last line. Sable gives them the ward page without another demand.", { shared_toast = true, ward_page = true }, "mara", "That was a good way to include me. Thessaly raises her glass.")),
                }),
            } },
            scene("ready_for_tower", "A key, a song, a promise", "The party knows Vask holds the tower. They have the ward notes and a copied key. A wolf courier comes to collect Sable's records. You can give the night a sharp ending without building another encounter.", "market", "tough", {
                option("intercept", "Let the party intercept him", "A fight against a scout and a tough escort. Win: take Vask's orders. Lose: keep the key, but the tower is warned.", out("The party takes Vask's orders from the courier. He intends to flee through the bell loft if the ward breaks. They can plan for it.", { vask_escape_known = true }, "dev", "He's not slipping past us next week."), out("The courier pushes through. The party keeps the key and ward notes, but Vask hears that they are coming.", { tower_alert = true }, "mara", "Then our opening next week is already tense."), nil, { foes = { "tough", "bandit" }, names = { "Wolf escort", "Wolf courier" }, sprites = { "tough", "tough" } }),
                option("tail", "Let Pip follow him home", "Stealth +5, DC 14. Success finds the side entrance; a miss warns the tower without losing the key.", out("Pip follows the courier to the tower's side entrance and sketches the route. The copied key fits that door.", { side_entrance = true }, "jess", "Pip puts a tiny, very flattering self-portrait on the map."), out("The courier spots Pip and bolts. She learns the tower route, but Vask will be waiting.", { tower_alert = true }, "dev", "Good. Saves us introductions."), check("jess", "Stealth", 5, 14)),
                option("warn_town", "End on the town coming together", "No roll. Warn Millbrook and let its people prepare. Vask hears the warning too.", out("The party warns Millbrook. Gus arranges shelter, Wren readies signal lanterns, and townsfolk prepare to help when the bells wake.", { town_ready = true, tower_alert = true }, "sam", "That's who we're doing this for.")),
            }, { clue = { id = "ward", text = "The copied key opens the tower; the bell song and Oswin's relic can break the hush." } }),
        },
        hooks = {
            { id = "side_door", title = "Begin at the side door", body = "The party approaches quietly through the bell-keeper's passage. Use the key and what they learned.", callback = "You open on the side door, as promised. The copied key turns in the lock; the party enters beneath the silent bells.", flag = "quiet_entry" },
            { id = "front_steps", title = "Begin on the front steps", body = "The party arrives where Millbrook can see them. Let the town witness the stand they make.", callback = "You open on the front steps, as promised. Millbrook watches the party climb together; Wren raises a lantern behind them.", flag = "public_entry" },
        },
        keepsake = { id = "pip_coin", name = "Pip's lucky coin", from = "jess", text = "Jess leaves a battered coin by your screen. 'For bribing the universe. Allegedly.'" },
    },
    {
        title = "Up the bell tower", objective = "Wake the bells and give this chapter an ending your friends will remember.",
        intro = "A hundred and twelve steps rise above Millbrook. Vask waits under seven silent bells. Tonight the party brings a key, a song, and everything they chose to care about.", board = "bell_tower",
        focus = {
            { id = "sam", title = "Sam's relic finds its purpose", body = "Oswin can carry the last note through the hush. Offer a quiet, useful kind of heroism." },
            { id = "dev", title = "Dev keeps his promise", body = "Brannoc can choose what victory means when the man serving Kessrick stands in front of him." },
        },
        twists = {
            { id = "bargain", title = "Vask wants to talk", body = "Give the villain something to lose. His surrender could save time, but demands a promise." },
            { id = "rescue", title = "Someone is still inside", body = "A trapped bell-keeper turns the climb into a rescue. The villain gets time to prepare." },
            { id = "chorus", title = "The town answers", body = "Millbrook has learned the bell song. Let an ordinary chorus reach the heroes at the top." },
        },
        scenes = {
            scene("tower_threshold", "The first locked door", "The copied key opens the lower door. Above it, the ward drinks every sound. A guard lowers his spear. The party can force a path, risk a bluff, or offer him a way to leave.", "bell_tower", "tough", {
                option("guard_mercy", "Give the guard a way out", "No roll. He leaves his spear and goes home. Vask gains time, but the guard tells the party where he waits.", out("The guard sets down his spear. He tells the party Vask is in the bell loft, then goes home to Millbrook.", { guard_spared = true }, "sam", "I like that we asked him before we fought him.")),
                option("guard_bluff", "Let Pip bluff an inspection", "Deception +3, DC 13. Success gets the guard's help; a miss sends him running upstairs.", out("Pip's official inspection is so specific that the guard gives up his keys and agrees to keep the stairs clear.", { guard_ally = true }, "jess", "I have been preparing this inspection for three Thursdays."), out("The guard hears the tremor in Pip's story and runs upstairs. The party keeps its route, but Vask has another warning.", { tower_alert = true }, "dev", "Inspection concluded. Very poor marks."), check("jess", "Deception", 3, 13)),
                option("guard_fight", "Let the dice settle the doorway", "A short fight with the tower guard. Victory clears the stairs; defeat sends the party through a broken side passage.", out("The party wins the doorway and carries the guard to safety. The stairs to Vask are clear.", { stairs_clear = true }, "dev", "Up we go.", "cheer"), out("The party is forced into the side passage. They find another way up, leaving Vask time to ready his escape.", { vask_ready = true }, "sam", "Another staircase is still a staircase."), nil, { foes = { "tough", "bandit" }, names = { "Tower guard", "Tower sentry" }, sprites = { "tough", "tough" } }),
            }),
            { id = "personal", by_focus = {
                sam = scene("oswin_voice", "The voice he carried", "Oswin's relic hums against the final seal. Sam says, 'I think I know what to do, but I don't have a speech.' The table looks to him. You can make this moment his without making it a performance.", "bell_tower", "npc_ghost", {
                    option("quiet", "Let one simple sentence be enough", "Ask Sam what Oswin would say to his old abbot. The relic carries the answer through the hush.", out("Sam says, 'I brought it home.' The relic rings. Oswin opens the seal with five quiet words, and the whole table hears them.", { oswin_home = true, seal_open = true }, "sam", "Yeah. That's what he'd say.", "lean")),
                    option("together", "Let his friends lend their voices", "Sam starts the note. The others join when he wants them to. Oswin still makes the first connection.", out("Oswin sounds the first note. One by one the others join, until the seal opens. Sam gives the tiniest triumphant nod.", { oswin_chorus = true, seal_open = true }, "sam", "I can do the first note. You lot do the singing.", "cheer")),
                }),
                dev = scene("brannoc_choice", "What the village taught him", "Through the seal, Brannoc sees Vask's wolf badge. Oswin kneels with his relic as the ward lashes at his hands. Dev has waited for this confrontation, but asks whether Brannoc can shield Oswin first.", "bell_tower", "tough", {
                    option("rescue_first", "Give him someone to protect", "No roll for choosing who to protect. Brannoc shields Oswin while the relic opens the seal.", out("Brannoc stands between Oswin and the lashing ward. The relic opens the seal. This time, his first act is protecting a friend, and the burning village does not get the last word.", { brannoc_protector = true, seal_open = true }, "dev", "That's what he needed. The fight can wait ten seconds.")),
                    option("friends", "Let Brannoc trust the party", "Oswin works the relic while Brannoc steadies him, Pip braces the door and Thessaly reads the last note.", out("Brannoc holds Oswin steady while Pip braces the door and Thessaly reads the ward note. The seal opens. Dev realizes he doesn't have to save everyone alone.", { brannoc_trust = true, seal_open = true }, "dev", "Sam, you've got the note? Good. I've got you.")),
                }),
            } },
            { id = "surprise", by_twist = {
                bargain = scene("vask_bargain", "The villain lowers his sword", "Vask offers the last bell key for safe passage out of the valley. 'Kessrick will kill me for losing this place.' Dev wants answers. Jess points out that a surrender could be interesting too.", "bell_tower", "tough", {
                    option("safe_passage", "Honor a surrender with conditions", "Vask gives up his key and signet and leaves under guard. The bells can be restored without another fight.", out("Vask surrenders his key and signet. The party promises a guarded departure from the valley. They gain a living witness against Kessrick.", { vask_surrender = true, signet = true }, "sam", "We said safe passage. We should mean it.")),
                    option("answer", "Let the party demand an answer first", "Persuasion +4, DC 14. Success wins his surrender; a miss gives him time to flee before the final note.", out("Vask admits Kessrick needed the ward silent before his warband arrived. He gives up the key and signet rather than serve him again.", { vask_surrender = true, signet = true }, "mara", "Now we know what the bells were protecting."), out("Vask stalls, drops the key, and escapes onto the outer stair. The party can restore the bells, but he will carry the story back to Kessrick.", { vask_escaped = true }, "dev", "Let him tell Kessrick what happened here."), check("sam", "Persuasion", 4, 14)),
                }),
                rescue = scene("gears_rescue", "A hand between the gears", "A bell-keeper is trapped beneath the great wheel. Vask backs toward the outer stair. Jess wants to jam the gears; Dev wants to hold them apart. You can keep both ideas in one clear rescue.", "bell_tower", "tough", {
                    option("together", "Let their plans work together", "No roll. They rescue the bell-keeper while Vask escapes. A person saved is the cost of a villain lost.", out("Brannoc lifts; Pip jams the gear. The bell-keeper crawls free. Vask escapes, but he leaves the bell key and his torn signet glove behind.", { bellkeeper_safe = true, vask_escaped = true, signet = true }, "jess", "We got the person. We can chase the awful man later.")),
                    option("fast", "Give the rescue a daring roll", "Athletics +5, DC 14. Success saves the keeper and traps Vask; a miss saves the keeper while Vask escapes.", out("Brannoc wrenches the wheel back into place. The keeper is free, and the falling counterweight blocks Vask's escape. He surrenders his signet.", { bellkeeper_safe = true, vask_captured = true, signet = true }, "dev", "YES. That was the roll.", "cheer"), out("Brannoc holds the wheel just long enough for the rescue. Vask slips away, leaving his key in the lock. The keeper is safe.", { bellkeeper_safe = true, vask_escaped = true }, "sam", "We told him we'd get him out. We did."), check("dev", "Athletics", 5, 14)),
                }),
                chorus = scene("town_chorus", "A song from below", "Through the narrow windows comes a ragged chorus. Wren and the people of Millbrook are singing the bell song. Vask orders them silent, but nobody below can hear him. What do you do with the moment?", "bell_tower", "tough", {
                    option("join", "Let the party join the town", "No roll. The chorus breaks Vask's nerve. He surrenders, and Millbrook helps finish its own rescue.", out("The party joins the chorus. Vask looks down at a whole town that has stopped being afraid of him. He gives up the key and signet.", { town_chorus_final = true, vask_surrender = true, signet = true }, "mara", "The town gets to be part of its own ending.")),
                    option("stand", "Give Vask one last defiant stand", "A battle with Vask and two guards. Win: capture him. Lose: the chorus holds the ward while the party escapes his grasp.", out("The party defeats Vask beneath the ringing chorus. He gives up his signet and the bell key. The people below hear the victory.", { vask_captured = true, signet = true, town_chorus_final = true }, "dev", "A boss fight with the town singing us on? Absolutely.", "cheer"), out("Vask drives the party to the stair, but the chorus keeps the ward open. They circle through the loft and reach the bell as he flees the town.", { vask_escaped = true, town_chorus_final = true }, "sam", "The town helped us back up. I like that."), nil, { foes = { "tough", "bandit", "bandit" }, names = { "Vask", "Wolf guard", "Wolf guard" }, sprites = { "tough", "tough", "tough" } }),
                }),
            } },
            scene("last_note", "Let the last note land", "The hush breaks. Seven bells wait above Millbrook, and wolf-horns answer from the distant hills. The party has earned this ending. What do you give the final moment?", "bell_tower", nil, {
                option("home", "Give them the home they protected", "Close on Millbrook answering the bells. Kessrick remains beyond the hills, but tonight belongs to the people they saved.", out("The bells ring across Millbrook. Lanterns bloom in every window. The party returns to the Kettle, and Gus has kept their table. Tonight ends with a home worth returning to.", { ending = "home", bells_awake = true }, "sam", "Same time next Thursday?", "cheer")),
                option("promise", "Let each hero make one promise", "Ask for one sentence each. Their personal stories become the beginning of the next chapter.", out("The bells ring. Thessaly promises to find Ilsa; Brannoc to protect the road; Pip to choose her own people; Oswin to carry a voice where it is needed. Everyone gets the last word.", { ending = "promise", bells_awake = true }, "mara", "I'm already thinking about what happens next.", "cheer")),
                option("horns", "End on the answering horns", "Give the victory room to breathe, then reveal Kessrick's banners on the ridge. A clean cliffhanger after a real success.", out("The bells ring, and the valley is protected again. Then a hundred wolf-horns answer from the ridge. Brannoc smiles. You close your notebook at exactly the right moment.", { ending = "horns", bells_awake = true }, "dev", "You cannot stop there. Okay. You absolutely can.", "cheer")),
            }, { clue = { id = "bells_awake", text = "The party broke the hush and restored Millbrook's bells." } }),
        },
        hooks = {},
        keepsake = { id = "little_bell", name = "The little brass bell", from = "dev", text = "Dev puts a tiny brass bell beside your screen. 'For whenever you need us to stop talking.'" },
    },
}

return M
