-- The Wild Sheep Chase's secrets: what the DM knows and the table doesn't, and the ways each can come out
-- (game/model/secrets.lua; the fields are the museum's, documented at the top of game/data/museum/secrets.lua). Pages
-- are the reader's own PDF of *The Wild Sheep Chase* (Richard Jansen-Parkes, DMs Guild); every word here is ours.
-- `book = true` on a way out the book gives; the rest are the game's. People: game/data/sheep/module.lua's M.people.
-- (Speaking to the sheep needs the scroll or the spell, and the scroll wears off after the walk (Conner, November 6): a
-- way out "on" Shinebright `when = { flag = "talking" }`. "understood" is that the table knows what he is.)

local M = {}

M.sheep_wizard = {
    major = true,
    covered_by = { { flag = "understood" } },
    name = "The sheep is a wizard", page = 2, type = "person", defaults = false, room = "inn_common",
    what = "The sheep is Finethir Shinebright, an elven transmuter. His apprentice Noke turned him into a sheep two "
        .. "years ago with Shinebright's own wand, and he's come looking for someone who can read his scroll.",
    held_by = { "sh_shinebright" },
    hint_words = { "too clever for a sheep", "that sheep understood" },
    hint = { "The sheep watches each speaker in turn, as if it's following every word.",
             "It nods when someone reads the seal aloud. Sheep don't nod.",
             "It taps the scroll with a hoof, twice, then looks up, waiting." },
    tell = { "The bleating becomes words, cultured and elven, with a bleat on the end: he is Finethir Shinebright, a "
                 .. "wizard, and he badly needs their help.",
             "Out of the sheep comes a fussy elven voice. Finethir Shinebright, wizard, at their service, and in "
                 .. "dire need of it." },
    theory = { "That's not a normal sheep. Look at its eyes.", "Somebody's done something to that animal.",
               "It wants us to read that scroll. It knows what it is." },
    paths = {
        { kind = "read", item = "speak_scroll", gives = "known", book = true, page = 2, flag = "understood" },
        { kind = "spell", spell = { "speak_with_animals" }, gives = "known", flag = "understood" },
        { kind = "check", skill = { "animal_handling", "insight" }, dc = 12, gives = "hint" },
        { kind = "spell", spell = { "detect_magic" }, gives = "hint",
          hint_says = { "Transmutation hangs on the sheep like a second fleece: strong, old magic." } },
        { kind = "check", skill = { "arcana" }, dc = 15, gives = "hint",
          hint_says = { "Nothing ordinary is this calm in a crowd. Something has changed this creature, and recently it wasn't one." } },
    },
}

M.guards_are_people = {
    name = "The beasts are people", page = 2, type = "creature", room = "inn_common",
    what = "Guz's three wolves and his cloaked bear are men Noke turned into beasts. They still think like people, "
        .. "and fight like it. The apes at the house are the same (p4).",
    held_by = { "sh_guz", { on = "sh_shinebright", when = { flag = "talking" } } },
    hint_words = { "clever eyes", "thinking like people" },
    hint = { "The wolves fan out like soldiers, not like a pack.", "One wolf watches the door while the others move. Wolves don't post a guard." },
    tell = { "These aren't animals. They're Noke's guards, people changed into beasts, and they're thinking every step.",
             "Shinebright says it flatly: guards, every one of them. People, polymorphed. Noke likes his help with teeth." },
    theory = { "Those wolves are working together like a squad.", "Since when do wolves wear collars and take orders?" },
    paths = {
        { kind = "ask", on = "sh_shinebright", when = { flag = "talking" }, gives = "known", book = true, page = 3 },
        { kind = "check", skill = { "insight", "animal_handling" }, dc = 13, gives = "hint" },
        { kind = "spell", spell = { "detect_magic" }, gives = "known" },
        { kind = "check", skill = { "nature" }, dc = 14, gives = "known" },
    },
}

M.noke_why = {
    major = true,
    covered_by = { { flag = "heard_noke" } },
    name = "Why Noke did it", page = 4, type = "person", room = "compound",
    what = "Noke served Shinebright for decades and was always treated as a boy: cooking, cleaning, reciting by rote, "
        .. "told it takes a century to learn, when a human hasn't got one. He saw the wand made half his master's name, "
        .. "took it, and set up as a master himself. Guilt and fear have him barely sleeping.",
    held_by = { "sh_noke", { on = "sh_shinebright", gives = "hint", when = { flag = "talking" },
                             hint_says = { "\"Ungrateful,\" says Shinebright. \"I gave that boy everything. Chores, mostly. "
                                               .. "It's how I was taught.\"" } } },
    hint_words = { "how I was taught", "treated him like a child" },
    hint = { "Shinebright never once calls Noke by his first name. Only \"the boy\".",
             "Every story Shinebright tells has Noke fetching, cleaning or getting it wrong." },
    tell = { "Noke's side comes out in a rush: years as a servant, never a student, while the old elf took credit "
                 .. "for what the wand did. He doesn't regret it. He can't sleep for it.",
             "Noke spits it out: decades of chores and rote lessons, a master who thought he had a century to spare, "
                 .. "and a wand doing the work Shinebright got famous for." },
    theory = { "Nobody turns their teacher into a sheep for no reason.", "I want to hear the apprentice's side of this.",
               "Shinebright's leaving something out about how he treated that boy." },
    paths = {
        { kind = "ask", on = "sh_noke", gives = "known", book = true, page = 5, flag = "heard_noke" },
        { kind = "check", on = "sh_shinebright", when = { flag = "talking" }, skill = { "insight" }, dc = 13, gives = "hint" },
        { kind = "read", on = { room = "hall", spot = "lab" }, skill = { "investigation" }, dc = 13, gives = "hint",
          hint_says = { "Among the notes, a page in a cramped hand: lists of chores, dated, years of them, and in the "
                            .. "margin, over and over, 'when?'" } },
    },
}

M.cant_pay = {
    name = "Shinebright can't pay", page = 6, type = "person", room = "hall",
    what = "Shinebright promises riches he hasn't got. Noke sold nearly everything to pay for research and guards, "
        .. "so even restored, Shinebright can offer only his services.",
    held_by = { "sh_shinebright" },
    hint = { "Every promise gets bigger the more they hesitate.", "He never says how much. Only \"great\" and \"generous\"." },
    tell = { "There's no fortune. Noke sold it all for books and guards, and Shinebright knew, or should have.",
             "The shelves are bare and the vaults are empty. Whatever he promised, there's nothing to pay it with." },
    theory = { "He's promising a lot for someone who eats grass.", "I'd like to see this reward before I bleed for it." },
    paths = {
        { kind = "check", on = "sh_shinebright", when = { flag = "talking" }, skill = { "insight" }, dc = 13, gives = "hint", page = 3 },
        { kind = "check", on = { room = "hall", spot = "library" }, skill = { "investigation" }, dc = 12, gives = "known" },
        { kind = "event", event = "the_spell", gives = "known", book = true, page = 6 },
    },
}

M.bear_outhouse = {
    name = "A bear in the outhouse", page = 4, type = "place", room = "compound",
    on = { room = "compound", spot = "outhouse" }, about = "the outhouse",
    what = "A brown bear, one of Noke's changed guards, is in the outhouse. It comes out when the fighting starts.",
    hint = { "Something big shifts inside the outhouse, and the whole thing creaks.", "Huge paw prints lead to the outhouse door, and none lead away." },
    tell = { "There's a bear in the outhouse. Of course there is.", "The outhouse is occupied, by a bear." },
    theory = { "Something's in that outhouse.", "Those tracks go in and don't come out." },
    paths = {
        { kind = "event", event = "bear_comes_out", gives = "known", book = true, page = 5 },
        { kind = "check", on = { room = "compound", spot = "outhouse" }, skill = { "perception" }, dc = 13, gives = "known" },
        { kind = "check", on = { room = "compound", spot = "lawn" }, skill = { "survival" }, dc = 12, gives = "hint" },
    },
}

M.wand_on_noke = {
    name = "The wand never leaves him", page = 3, type = "person", room = "compound",
    what = "Noke carries the wand everywhere, and only leaves the house when he must.",
    held_by = { { on = "sh_shinebright", when = { flag = "talking" } }, "sh_noke" },
    hint = { "Noke's hand keeps going to his sleeve.", "Whatever's up his sleeve, he checks it's there every few breaths." },
    tell = { "The wand is on Noke, always, and he hardly ever goes out.", "Shinebright is certain: the boy keeps it on him, day and night." },
    theory = { "If he's that scared, he's keeping it close.", "Bet you anything the wand's on him." },
    paths = {
        { kind = "ask", on = "sh_shinebright", when = { flag = "talking" }, gives = "known", book = true, page = 3 },
        { kind = "check", on = "sh_noke", skill = { "insight", "perception" }, dc = 12, gives = "known" },
    },
}

M.bed_escape = {
    name = "Noke's way out", page = 5, type = "person", room = "bedroom",
    what = "When the fight turns, Noke runs for his bedroom and turns the biggest thing there, his bed, into a dragon. "
        .. "Three rounds later he rides it out through the roof.",
    held_by = { "sh_noke" },
    hint = { "In the lab, a page of notes on making furniture walk.", "In the lab, sketches of a wooden wyrm, its wings drawn as sheets." },
    tell = { "He's going for his bed. He's going to make it into something.", "The top platform: that's where he runs, and what he makes there flies." },
    theory = { "He's got a way out. Watch where he looks.", "Nobody that scared lives without a bolt-hole." },
    paths = {
        { kind = "event", event = "bed_dragon", gives = "known", book = true, page = 5 },
        { kind = "check", on = "sh_noke", skill = { "insight" }, dc = 15, gives = "hint" },
        { kind = "read", on = { room = "hall", spot = "lab" }, skill = { "arcana", "investigation" }, dc = 14, gives = "hint" },
    },
}

M.wand_unreliable = {
    major = true,
    name = "The wand is dangerous", page = 6, type = "item", on = { item = "wand" }, room = "hall",
    what = "The wand was modified to be used more often, and overuse has made it unreliable: each use risks turning "
        .. "the target into a gibbering mouther, and a bad failure blows it apart.",
    hint = { "The wand sparks under their fingers, in a way magic shouldn't.", "The iron band is hot, and the cracks along the wood glow faintly." },
    tell = { "Someone's forced this wand to hold more than it should. It works, sometimes. When it doesn't, it makes monsters.",
             "Modified, overused, and failing: a wand like this as likely makes a horror as a wizard." },
    theory = { "I don't like how that wand looks.", "Something's wrong with it. Look at the cracks." },
    paths = {
        { kind = "check", skill = { "arcana" }, dc = 15, gives = "known", book = true, page = 6 },
        { kind = "event", event = "wand_touched", gives = "hint", book = true, page = 6 },
        { kind = "ask", on = "sh_noke", gives = "known", book = true, page = 6,
          says = { "\"Use it if you like,\" Noke says, and laughs. \"See what it makes of you. It's not the wand it was.\"" } },
        { kind = "event", event = "mouther", gives = "known", page = 5 },
    },
}

M.second_scroll = {
    name = "Another scroll", page = 6, type = "place", room = "hall", on = { room = "hall", spot = "library" },
    about = "the bookshelves",
    what = "There's a second scroll of Speak with Animals on the hall's bookshelves.",
    hint = { "The library's shelves are a mess, and some of the scrolls have the same wax seal." },
    tell = { "Among the clutter on the shelves: another scroll, the same seal as the first." },
    theory = { "Where he got one, there might be more." },
    paths = {
        { kind = "check", on = { room = "hall", spot = "library" }, skill = { "investigation" }, dc = 10, gives = "known", book = true, page = 6 },
        { kind = "ask", on = "sh_shinebright", when = { flag = "talking" }, gives = "known" },
    },
}

M.lure = {
    name = "Noke could be lured out", page = 5, type = "person", room = "hall",
    what = "Noke wants fame and power a little more than he fears losing the wand. A very good lie, a clever plan and "
        .. "luck could draw him out with a grand, well-paid contract. He'd bring every guard, and the wand.",
    held_by = { "sh_noke", { on = "sh_teddy", gives = "hint",
                             hint_says = { "\"Mad for a name, that one,\" Teddy says. \"Wants the lords to send for him like they "
                                               .. "used to send for the elf.\"" } } },
    hint = { "Noke boasts of what he'll do, and who'll come begging for it.", "He wants to be sent for, the way the old elf was." },
    tell = { "Offer him something grand enough, a lord's commission, and he might come out, guards and all.",
             "Fame is the one thing he wants more than safety. That's the way to draw him out." },
    theory = { "Could we get him out of there?", "What does a man like that want? Recognition." },
    paths = {
        { kind = "check", on = "sh_noke", skill = { "insight" }, dc = 14, gives = "known", book = true, page = 5 },
        { kind = "ask", on = "sh_teddy", gives = "hint" },
        { kind = "ask", on = "sh_shinebright", when = { flag = "talking" }, gives = "hint" },
    },
}

-- (Ours: the side quest at the inn, Sir Luenn's ring.)
M.ring_thief = {
    ours = true,
    covered_by = { { flag = "ring_found" } },
    name = "Who took the ring", type = "creature", room = "inn_upstairs", about = "the empty jewel box", defaults = false,
    what = "Nobody at the inn took Sir Luenn's ring. A pack rat from the cellar did, up through the walls in the night, and "
        .. "left a beer cork in its place, the way pack rats do. Its nest behind the cellar barrels is full of the inn's "
        .. "lost spoons and buttons.",
    held_by = { { on = "sh_wenna", gives = "hint",
                  hint_says = { "\"Things go missing here all the time,\" Wenna says. \"Spoons, buttons. The cellar's the worst for it.\"" } } },
    hint_words = { "pack rat", "in trade" },
    hint = { "In the jewel box, where the ring should be, sits a beer cork stamped with the inn's B.",
             "Under the washstand, a hole gnawed through the skirting board, grey hairs caught on its edge." },
    tell = { "Something small took the ring through the wall and left a cork from the cellar in its place. Whatever it was, "
                 .. "its nest is down there.",
             "Not Wenna. A pack rat, up through the walls from the cellar, and it left a cork in trade." },
    theory = { "Who leaves a cork where a ring was? That's not a thief, that's a swap.", "Wenna didn't do this. Something small did.",
               "Thieves don't leave things behind. Animals might." },
    paths = {
        -- (Once Sir Luenn has shown them the room: the card's own search comes first.)
        { kind = "check", on = { room = "inn_upstairs", spot = "luenn_room" }, skill = { "investigation", "perception" }, dc = 12,
          gives = "known", when = { seen = "ring_room" } },
        { kind = "ask", on = "sh_wenna", gives = "hint" },
        { kind = "check", skill = { "nature" }, dc = 12, gives = "known", needs = "hint", when = { seen = "ring_room" } },
        { kind = "event", event = "the_nest", gives = "known" },
    },
}

return M
