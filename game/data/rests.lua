-- The little scenes a rest plays (A16): a pair of heroes at the fire, a dream, someone mending
-- things with a friend. Data only: tune freely. The rules of resting are game/rules/rest.lua; the
-- night plays a beat in night.lua (rest_beat) when a storyteller or a method actor is at the table.
--
-- beats: { id, where, pair, tags, mend, says, line, effects }.
--   says    each hero's part, in their own player's words: { who = player key, text, ic (default in character) }
--   where   the kinds of place it plays in ("any"; the museum rests in "town", museum_night.lua)
--   pair    who has to be there ("pc:<player>")
--   mend    a beat that patches things up between two friends: twice as likely to come up
--   thread  (optional) the player whose story it touches

local M = {}

M.beats = {
    -- (Players announce, the DM answers: each hero's part is their own player's line (`says`: who, and what they say
    -- in character), and `line` is only what happens. The playtest, November 6: "[dev] I'll teach Pip a proper sword
    -- grip; Pip teaches me to palm a coin", then "Both laugh.")
    { id = "bluebell", where = { "any" }, pair = { "pc:jess", "pc:mara" }, tags = { "mend" }, mend = true,
      says = { { who = "jess", text = "I slip a pressed flower into Thessaly's notebook, on the page she was stuck on." } },
      line = "It's still there in the morning, flat and blue.",
      effects = { { "all", social = 6 }, { "arch:method_actor", fun = 4 } } },
    { id = "grip_and_palm", where = { "any" }, pair = { "pc:dev", "pc:jess" }, tags = { "bond", "mend" }, mend = true,
      says = { { who = "dev", text = "Pip. Come here. I'm showing you a proper sword grip." },
               { who = "jess", text = "Fine. Then I'm showing Brannoc how to palm a coin." } },
      line = "Neither lesson takes. The coin ends up in the fire twice.",
      effects = { { "all", social = 6 }, { "arch:butt_kicker", fun = 2 }, { "arch:instigator", fun = 2 } } },
    -- (More of them, the third playtest: 28 of 44 rests showed one of the two above.)
    { id = "glyphs_and_prayers", where = { "any" }, pair = { "pc:mara", "pc:sam" }, tags = { "bond" },
      says = { { who = "mara", text = "I'll show Oswin how I copy glyphs." },
               { who = "sam", text = "And I'll show Thessaly the prayer that goes with each one." } },
      line = "By the end there's a page of glyphs with a prayer pencilled under every one.",
      effects = { { "all", social = 5 }, { "arch:storyteller", fun = 3 } } },
    { id = "bootlace_strap", where = { "any" }, pair = { "pc:dev", "pc:sam" }, tags = { "bond", "mend" }, mend = true,
      says = { { who = "sam", text = "Brannoc, your armour strap's snapped. Hold still. I'll mend it with a bootlace and a prayer." } },
      line = "It holds, better than Brannoc's own stitching ever did.",
      effects = { { "all", social = 5 }, { "arch:butt_kicker", fun = 2 }, { "arch:casual", fun = 2 } } },
    { id = "map_from_memory", where = { "any" }, pair = { "pc:dev", "pc:mara" }, tags = { "bond" },
      says = { { who = "mara", text = "I'll draw the road so far from memory." },
               { who = "dev", text = "The first turn was on the left. Brannoc's sure of it." } },
      line = "It wasn't.",
      effects = { { "all", social = 5 }, { "arch:storyteller", fun = 2 }, { "arch:butt_kicker", fun = 2 } } },
    { id = "franc_trick", where = { "any" }, pair = { "pc:jess", "pc:sam" }, tags = { "bond", "mend" }, mend = true,
      says = { { who = "jess", text = "I make a coin vanish, and find it behind Oswin's ear." },
               { who = "sam", ic = false, text = "How did you DO that?" } },
      line = "Nobody at the table can work out how it's done.",
      effects = { { "all", social = 6 }, { "arch:instigator", fun = 2 }, { "arch:casual", fun = 2 } } },
    { id = "margin_moustache", where = { "any" }, pair = { "pc:jess", "pc:mara" }, tags = { "bond" },
      says = { { who = "mara", text = "Thessaly goes over her notes by the fire until she nods off." },
               { who = "jess", text = "I draw a small, very neat moustache in her margin." } },
      line = "Nobody mentions it until morning.",
      effects = { { "all", social = 5 }, { "arch:method_actor", fun = 3 } } },
    { id = "first_watch", where = { "any" }, pair = { "pc:dev", "pc:mara" }, tags = { "bond" },
      says = { { who = "dev", text = "I'll take first watch." },
               { who = "mara", text = "I'll keep Brannoc company. I'll read him my notes." } },
      line = "The watch passes quietly, apart from the notes.",
      effects = { { "all", social = 5 }, { "arch:storyteller", fun = 2 } } },
}

return M
