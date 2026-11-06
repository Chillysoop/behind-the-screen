-- The museum's secrets: what the DM knows and the table doesn't, and the ways each can come out
-- (game/model/secrets.lua; docs/design/2026-11-05-secrets-and-knowledge.md). Page numbers are the reader's own
-- PDF of *The Museum of Nightmares* (Luke Russell, DMs Guild); every word here is ours, never the book's.
--
-- Each secret:
--   name       a few words for the DM's lists
--   what       the whole secret, in the DM's words (the person sheet, the prep board)
--   page       where the book has it
--   type       what holds it: person, document, place, body, item or creature (game/model/secrets.lua's DEFAULTS
--              give each kind its usual ways out besides the book's)
--   held_by    the people who know it (their sheets list it); on = { room, spot } a place on a board, or
--              { item } a thing someone carries
--   room       where it can come out, for the prep board
--   hint, tell what the DM says when a hint comes out, and when the whole of it does (each said as the DM)
--   theory     what a friend with only the hint says as they go digging (their player, out loud)
--   paths      the ways out the book gives (book = true), and the module's own: kind (check, ask, read, see,
--              spell, perform, trade, steal, event), skill and dc, gives (hint or known), needs = "hint" (only
--              once the table has a hint), opinion (the least that person must think of the party), says /
--              hint_says (the DM's words that way), tells (more keys told with it), flag (a flag it sets)
--   parts      a secret that comes out a piece at a time (each success, one more); needs: the pieces that
--              make it known
--   say_at     "hint": lines that name it can be said once the table has a hint (default: once it's known)
--   with       keys told along with it

local M = {}

M.gorgon = {
    name = "What's really upstairs", page = 6, type = "person", room = "street",
    what = "A Gorgon called Euryale has taken the museum over. Flitwidget bought her sealed in a clay jar; she broke free, twisted his exhibits and killed visitors. Telpur is still inside.",
    held_by = { "mus_flitwidget", "mus_telpur" },
    hint = { "Flitwidget's bluster has a crack in it. Whatever's wrong in there is a lot worse than \"incidents\".",
             "He smiles too wide, and his eyes keep going to the curtains. He's scared of something inside.",
             "Every time someone says \"upstairs\", the gnome's moustache twitches." },
    tell = { "He cracks. Her name is Euryale, a Gorgon he bought sealed in a clay jar. The jar broke, she's twisted his exhibits, and visitors who went in never came out.",
             "It comes out in a rush: a Gorgon called Euryale, a clay jar that broke, exhibits that turned, and visitors who didn't come back." },
    theory = { "Something's wrong in this place, and somebody here knows what.",
               "I don't buy \"incidents\". Somebody got hurt in here.",
               "Whatever's really running this place, people are scared of it." },
    paths = {
        { kind = "check", on = "mus_flitwidget", skill = { "persuasion" }, dc = 12, gives = "known", book = true, page = 6,
          tells = { "euryale" }, flag = "truth" },
        { kind = "check", on = "mus_flitwidget", skill = { "intimidation" }, dc = 16, gives = "known", book = true, page = 6,
          tells = { "euryale" }, flag = "truth" },
        { kind = "check", on = "mus_flitwidget", skill = { "insight" }, dc = 12, gives = "hint", book = true, page = 6 },
        { kind = "perform", on = "mus_flitwidget", skill = { "performance" }, dc = 13, gives = "known", tells = { "euryale" }, flag = "truth",
          says = { "Flitwidget laughs so hard his hat falls off, and then it all comes out: a Gorgon called Euryale, a clay jar that broke, and visitors who never came out." } },
        { kind = "ask", on = "mus_telpur", opinion = "neutral", gives = "hint", page = 16,
          hint_says = { "Telpur lowers his voice. \"Horrible lady upstairs. Threw the boss out. Don't tell him I said.\"",
                        "\"Her,\" says Telpur, rolling his eyes at the ceiling. \"Took over. Kicked the boss out. Horrible.\"" } },
        { kind = "ask", on = "mus_telpur", opinion = "warm", needs = "hint", gives = "known", page = 16,
          says = { "Telpur sighs. \"A Gorgon. Came out of a jar the boss bought. She runs the place now, and the visitors who went up are statues.\"" } },
        { kind = "event", event = "hood_off", gives = "known", book = true, page = 26 },
    },
}

M.sisters = {
    name = "Her sisters", page = 27, type = "person", room = "lair", say_at = "known",
    what = "An ancient hero sealed Euryale and her two sisters in three clay pots. She smashed the lair's pottery looking for them, and deep down she wants them found and freed: the way to bargain with her.",
    held_by = { "mus_euryale" },
    hint = { "Three sisters on the tapestry, and every pot in the room smashed. She's been looking for something.",
             "She keeps glancing at the broken pottery, as if she's still hoping one of the pots was the right one." },
    tell = { "She doesn't hide it now. \"My sisters. Sealed in clay, like I was. Two jars, somewhere out there.\"",
             "Her hood dips. \"There were three of us, and three jars. I've only found mine.\"" },
    theory = { "Three sisters on that tapestry. I want to know where the other two are.",
               "She smashed every pot in here looking for something. Or someone.",
               "That tapestry means something to her. Look how she keeps her back to it." },
    paths = {
        { kind = "see", on = { room = "lair", spot = "mosaics" }, gives = "hint", book = true, page = 27 },
        { kind = "check", on = { room = "lair", spot = "pedestals" }, skill = { "investigation" }, dc = 12, gives = "hint", page = 25 },
        { kind = "check", on = "mus_euryale", skill = { "insight" }, dc = 13, needs = "hint", gives = "known", page = 27 },
        { kind = "ask", on = "mus_euryale", needs = "hint", gives = "known", page = 25 },
        { kind = "check", on = { room = "lair", spot = "mosaics" }, skill = { "history", "religion" }, dc = 13, needs = "hint", gives = "known", page = 27,
          says = { "Old stories about gorgons always come in threes: three sisters, and three jars for three souls. Two of them are still sealed somewhere." } },
    },
}

M.ritual = {
    name = "The water ritual", page = 12, type = "document", room = "chamber", say_at = "hint",
    on = { room = "chamber", spot = "3E" },
    what = "The tablet's seven lines tell how to still the bone guardian: fill the falcon jar with exactly four gallons, using only the jackal jug and the crocodile's water, and set it on the pedestal. A discontented falcon on the pedestal is deadly.",
    parts = {
        "The full belly of the falcon holds five gallons.",
        "The full belly of the jackal holds three.",
        "The goddess will be content when the falcon drinks exactly four.",
        "Only the crocodile's water may feed the falcon and the jackal.",
        "The crocodile can feed them both until the end of time.",
        "Once the falcon is content, set it on the goddess's pedestal and call her.",
        "Woe to whoever sets a discontented falcon on the pedestal: it costs a life.",
    },
    needs = { 1, 2, 3, 4, 6 },
    hint = { "One line of the tablet comes clear." },
    tell = { "Enough of the tablet comes clear to work it out: five, three, and four is the number the goddess wants." },
    theory = { "It's a set of instructions. There's more on that tablet.",
               "The notebook's for the tablet. Give me another go at it.",
               "Every one of those jars is in the instructions. Keep reading." },
    paths = {
        { kind = "read", skill = { "history" }, dc = 12, gives = "part", book = true, page = 12, with_item = "the notebook" },
        { kind = "read", skill = { "investigation", "religion", "arcana" }, dc = 14, gives = "part", page = 12 },
        { kind = "spell", spell = { "comprehend_languages" }, gives = "known", page = 12 },
    },
    defaults = false,
}

M.knight_weak = {
    name = "What hurts the knight", page = 15, type = "creature", room = "paintings",
    on = { room = "paintings", spot = "4K" },
    what = "The Knight of Shades shrugs off most weapons. Fire, water and anything made of the paintings' paint hurt it properly.",
    hint = { "The black knight's brushstrokes are still wet. Whatever it is, it's paint all the way through." },
    tell = { "Paint cuts paint: whatever came out of a picture bites into the knight. Fire and water too." },
    theory = { "It's a painting. What hurts a painting?", "Paint, water, fire. Something in here has to work on it." },
    paths = {
        { kind = "check", skill = { "arcana" }, dc = 13, gives = "known", page = 15 },
        { kind = "check", skill = { "investigation", "perception" }, dc = 12, gives = "hint", page = 15 },
        { kind = "event", event = "paint_hit", gives = "known", page = 15 },
    },
    defaults = false,
}

M.kruthik = {
    name = "What the hunters are", page = 20, type = "creature", room = "hunting", with = { "huntlings" },
    what = "The armoured hunters are Kruthik Huntlings: pack creatures that hide, dodge and slip away, strike in pairs, and run if they expect to lose.",
    hint = { "Whatever they are, they hunt in a pack, and they want you to chase one." },
    tell = { "They're kruthik huntlings: pack hunters that hide, dodge and strike in pairs, and run when they're losing.",
             "Kruthik huntlings. They never fight fair: one draws you in, the rest come out of hiding." },
    paths = {
        { kind = "read", item = "guide", skill = { "survival", "nature" }, dc = 14, gives = "known", book = true, page = 20 },
        { kind = "check", skill = { "nature", "survival" }, dc = 15, gives = "hint", page = 20 },
        { kind = "event", event = "kruthik_fight", gives = "hint", page = 20 },
    },
    defaults = false,
}

M.pack_hides = {
    name = "Where the pack hides", page = 20, type = "place", room = "hunting",
    on = { room = "hunting", spot = "stairs" },
    what = "Two hunters hide in the jungle, two in the cave model, and one stands still as a statue behind the big bird. All five are rarely seen at once.",
    hint = { "Something in the dioramas is holding very still. Not stuffed, either.",
             "The polished cupboard doors in the kitchen show a shape behind the big bird that isn't on the floor plan." },
    tell = { "Now they can see them: two in the jungle, two in the cave model, and one pretending to be a statue behind the big bird." },
    paths = {
        { kind = "check", skill = { "perception" }, dc = 14, gives = "hint", page = 20 },
        { kind = "see", on = { room = "hunting", spot = "6J" }, gives = "hint", page = 20 },
        { kind = "check", on = { room = "hunting", spot = "6J" }, skill = { "perception", "investigation" }, dc = 12, gives = "known", page = 20 },
    },
    defaults = false,
}

M.tracks = {
    name = "The scratch marks", page = 20, type = "place", room = "hunting",
    on = { room = "hunting", spot = "stairs" },
    what = "The scratch marks are a lure: the hunters left an easy trail to draw prey to the pack.",
    hint = { "The marks are very easy to follow. Almost too easy." },
    tell = { "Too clean, too obvious: those marks were left to be followed. It's bait." },
    paths = {
        { kind = "check", skill = { "survival" }, dc = 12, gives = "known", book = true, page = 20 },
        { kind = "check", skill = { "investigation", "nature" }, dc = 14, gives = "hint", page = 20 },
    },
    defaults = false,
}

M.witness = {
    name = "The Witness", page = 21, type = "document", room = "offices",
    on = { room = "offices", spot = "7B" },
    what = "The archivist was researching something old called the Witness. It reached him through his notes; it whispers to anyone close to his body. He thought a vast city once sank under the sea.",
    hint = { "Every page has the same eye on it. Whatever he was studying, it was studying him back.",
             "There's a word in the margins, underlined until the nib went through: Witness." },
    tell = { "The notes come together: the archivist was studying something he called the Witness, and a great city that sank under the sea. And it noticed him." },
    paths = {
        { kind = "read", skill = { "investigation" }, dc = 14, gives = "known", book = true, page = 22 },
        { kind = "read", skill = { "arcana" }, dc = 14, gives = "hint", book = true, page = 22 },
        { kind = "check", on = { room = "offices", spot = "7B" }, skill = { "medicine" }, dc = 12, gives = "hint", page = 21,
          hint_says = { "No wounds that would kill him. He carved every one of those eyes himself, with his own quill." } },
        { kind = "spell", on = { room = "offices", spot = "7B" }, spell = { "speak_with_dead" }, gives = "known", page = 21 },
        { kind = "event", event = "whisper", gives = "hint", private = true, book = true, page = 21 },
    },
    defaults = false,
}

M.archivist = {
    name = "Why the archivist locked himself in", page = 21, type = "body", room = "offices",
    on = { room = "offices", spot = "7B" },
    what = "The archivist went mad studying the Witness and locked himself in, from the inside, to keep it from spreading through the museum.",
    hint = { "The door was locked from the inside. He wasn't keeping anyone out. He was keeping something in." },
    tell = { "He locked himself in on purpose: whatever he was studying, he wasn't going to let it out into the museum." },
    paths = {
        { kind = "see", on = { room = "offices", spot = "door" }, gives = "hint", book = true, page = 21 },
        { kind = "check", skill = { "investigation", "medicine" }, dc = 13, gives = "known", page = 21 },
    },
}

M.bird = {
    name = "The little bird", page = 21, type = "creature", room = "offices", with = { "bird_named" },
    on = { room = "offices", spot = "7A" },
    what = "The bird under the dome is a Celestia canary, a \"mythril singer\": miners keep them because they sing when magic is near.",
    tell = { "It's a Celestia canary. Miners call them mythril singers: they sing when there's magic about." },
    hint = { "The drawings on the wall are all of this bird's insides, with notes about mines." },
    paths = {
        { kind = "check", skill = { "investigation", "nature" }, dc = 10, gives = "known", book = true, page = 21 },
        { kind = "read", on = { room = "offices", spot = "drawings" }, skill = { "investigation" }, dc = 10, gives = "known", book = true, page = 21 },
        { kind = "check", skill = { "history" }, dc = 10, gives = "hint", book = true, page = 21 },
    },
    unlocks = { flag = "bird_named" },
    defaults = false,
}

M.mythril = {
    name = "Mythril poisoning", page = 21, type = "document", room = "offices",
    on = { room = "offices", spot = "drawings" },
    what = "The mythril from the Curna Mountains turns to a poisonous gas near magic: breathe it and you see things, rage, and die.",
    hint = { "Half the notes are about masks, and staying away from magic." },
    tell = { "Curna mythril turns to gas near magic, and the gas drives people mad before it kills them." },
    paths = {
        { kind = "read", skill = { "arcana", "medicine" }, dc = 10, gives = "known", book = true, page = 21 },
        { kind = "read", skill = { "history" }, dc = 14, gives = "hint", book = true, page = 21 },
    },
    defaults = false,
}

M.living_hedges = {
    name = "The hedges are alive", page = 10, type = "creature", room = "garden",
    on = { room = "garden", spot = "1B" },
    what = "Three of the clipped beasts are Briar Guardians: they wake and attack when someone comes close. The cat on the right terrace is only ever a hedge.",
    hint = { "A leaf on the big horned hedge turns, very slowly, to follow whoever's nearest.",
             "There's no wind in here, and the hedges are rustling." },
    tell = { "Those aren't topiary. They're alive, and they're waiting for someone to get close." },
    paths = {
        { kind = "check", skill = { "perception" }, dc = 13, gives = "hint", page = 10 },
        { kind = "check", skill = { "nature" }, dc = 13, gives = "known", page = 10 },
        { kind = "event", event = "briars_wake", gives = "known", book = true, page = 10 },
    },
    defaults = false,
}

M.pond = {
    name = "What's in the pond", page = 10, type = "place", room = "garden",
    on = { room = "garden", spot = "pond" },
    what = "Something with tentacles lives in the pond and lashes at anyone within five feet of the water.",
    hint = { "The pond's surface shivers when nobody's touched it." },
    tell = { "There's something in the pond, a lot of something, with tentacles. It reaches for anyone close to the edge." },
    paths = {
        { kind = "check", skill = { "perception" }, dc = 12, gives = "hint", page = 10 },
        { kind = "check", skill = { "nature", "investigation" }, dc = 14, gives = "known", page = 10 },
        { kind = "event", event = "tentacles", gives = "known", book = true, page = 10 },
    },
    defaults = false,
}

M.sentinel_wakes = {
    name = "What the statue does", page = 11, type = "creature", room = "entrance",
    on = { room = "entrance", spot = "2A" },
    what = "The metal statue is the Sentinel. It wakes only for a serious break-in at the donation case, punches to subdue, doesn't chase anyone who backs off, and calms down at a donation.",
    hint = { "There are scuff marks on the floor in front of the case, as if something heavy stepped down off that plinth once." },
    tell = { "That's no statue. It's a guardian for the case, and it'll come down off its plinth for anyone who tries to break in." },
    paths = {
        { kind = "check", skill = { "arcana" }, dc = 13, gives = "known", page = 11 },
        { kind = "check", skill = { "investigation", "perception" }, dc = 12, gives = "hint", page = 11 },
        { kind = "event", event = "sentinel_wakes", gives = "known", book = true, page = 12 },
    },
    defaults = false,
}

M.scarabs = {
    name = "The guardian's scarabs", page = 12, type = "creature", room = "chamber",
    on = { room = "chamber", spot = "3B" },
    what = "Once the bone guardian is down to half its strength, it belches out a swarm of scarabs that joins the fight.",
    hint = { "Little scarabs keep scuttling out of the cracks wherever the guardian steps." },
    tell = { "Its ribs are full of beetles. Hurt it enough and they'll all come out at once." },
    paths = {
        { kind = "check", skill = { "religion", "arcana" }, dc = 13, gives = "known", page = 12 },
        { kind = "see", gives = "hint", book = true, page = 13 },
        { kind = "event", event = "scarabs", gives = "known", book = true, page = 12 },
    },
    defaults = false,
}

M.lecturer_ears = {
    name = "How to beat the drone", page = 24, type = "creature", room = "lecture",
    on = { room = "lecture", spot = "9A" },
    what = "The Lecturer's drone works through the ears: anyone who can't hear him has advantage against it. He was a guest lecturer who died mid-talk and kept going, and Euryale made him stronger.",
    hint = { "The dead on the benches all have their heads tipped toward the lectern, as if they were listening to the end." },
    tell = { "It's his voice that does it. Whoever can't hear him won't be bored to death." },
    paths = {
        { kind = "check", skill = { "arcana", "religion" }, dc = 13, gives = "known", page = 24 },
        { kind = "check", skill = { "insight", "perception" }, dc = 12, gives = "hint", page = 24 },
        { kind = "event", event = "deafened", gives = "known", book = true, page = 24 },
    },
    defaults = false,
}

M.hyper = {
    name = "The red switch", page = 38, type = "item", room = "tomorrow",
    on = { room = "tomorrow", spot = "8A" },
    what = "Hyper Destroyer Mode makes the Mech terrifying, but every turn it can overheat: then it shuts down for good and burns whoever's next to it.",
    hint = { "The red switch has a little glass flap, and someone has scratched NO under it." },
    tell = { "Chapter nine of the manual is all warnings: the red switch overheats it, and when it goes, it goes with a bang." },
    paths = {
        { kind = "read", item = "manual", gives = "known", book = true, page = 38 },
        { kind = "check", skill = { "arcana", "investigation" }, dc = 13, gives = "hint", page = 23 },
    },
    defaults = false,
}

M.gorgon_lore = {
    name = "What the scholar's book says", page = 27, type = "document", room = "gift_shop",
    on = { item = "gorgon_book" },
    what = "The Tenets of the Rotting Temple can give one fact about gorgons for each good read: they're shape-shifters who pass for people; their stone gaze lives in the snakes on their heads, and may not work while the snakes are hidden; they poison their weapons, and their claws drip with it.",
    parts = {
        "Gorgons are shape-shifters. They often pass for ordinary people.",
        "A gorgon's stone gaze lives in the snakes on its head. Keep the snakes hidden, and the gaze may not work.",
        "Gorgons poison their weapons, and their claws drip with it.",
    },
    needs = { 1 },
    hint = { "One page of the scholar's book comes clear." },
    tell = { "The scholar's book is clear enough: gorgons pass for people, and their gaze lives in the snakes on their heads." },
    paths = {
        { kind = "read", item = "gorgon_book", skill = { "history", "religion" }, dc = 13, gives = "part", book = true, page = 27 },
    },
    defaults = false,
}

return M
