-- The little scenes a rest plays (A16): a pair of heroes at the fire, a dream, someone mending
-- things with a friend. Data only: tune freely. The rules of resting are game/rules/rest.lua; the
-- night plays a beat in night.lua (rest_beat) when a storyteller or a method actor is at the table.
--
-- beats: { id, where, pair, tags, mend, line, effects }.
--   where   the kinds of place it plays in ("any"; the museum rests in "town", museum_night.lua)
--   pair    who has to be there ("pc:<player>")
--   mend    a beat that patches things up between two friends: twice as likely to come up
--   thread  (optional) the player whose story it touches

local M = {}

M.beats = {
    { id = "bluebell", where = { "any" }, pair = { "pc:jess", "pc:mara" }, tags = { "mend" }, mend = true,
      line = "Pip slips a pressed flower into Thessaly's notebook, marking the page she was stuck on.",
      effects = { { "all", social = 6 }, { "arch:method_actor", fun = 4 } } },
    { id = "grip_and_palm", where = { "any" }, pair = { "pc:dev", "pc:jess" }, tags = { "bond", "mend" }, mend = true,
      line = "Brannoc teaches Pip a proper sword grip; Pip teaches Brannoc to palm a coin. Both are terrible. Both laugh.",
      effects = { { "all", social = 6 }, { "arch:butt_kicker", fun = 2 }, { "arch:instigator", fun = 2 } } },
    -- (More of them, the third playtest: 28 of 44 rests showed one of the two above.)
    { id = "glyphs_and_prayers", where = { "any" }, pair = { "pc:mara", "pc:sam" }, tags = { "bond" },
      line = "Thessaly shows Oswin how she copies glyphs; Oswin shows her the prayer that goes with each one.",
      effects = { { "all", social = 5 }, { "arch:storyteller", fun = 3 } } },
    { id = "bootlace_strap", where = { "any" }, pair = { "pc:dev", "pc:sam" }, tags = { "bond", "mend" }, mend = true,
      line = "Oswin mends a snapped strap on Brannoc's armour with a bootlace and a quiet prayer. It holds, better than Brannoc's own stitching ever did.",
      effects = { { "all", social = 5 }, { "arch:butt_kicker", fun = 2 }, { "arch:casual", fun = 2 } } },
    { id = "map_from_memory", where = { "any" }, pair = { "pc:dev", "pc:mara" }, tags = { "bond" },
      line = "Thessaly draws the museum from memory. Brannoc insists the garden was on the left. It wasn't.",
      effects = { { "all", social = 5 }, { "arch:storyteller", fun = 2 }, { "arch:butt_kicker", fun = 2 } } },
    { id = "franc_trick", where = { "any" }, pair = { "pc:jess", "pc:sam" }, tags = { "bond", "mend" }, mend = true,
      line = "Pip makes a Franc vanish and finds it behind Oswin's ear. \"How did you do that?\" Sam says.",
      effects = { { "all", social = 6 }, { "arch:instigator", fun = 2 }, { "arch:casual", fun = 2 } } },
    { id = "margin_moustache", where = { "any" }, pair = { "pc:jess", "pc:mara" }, tags = { "bond" },
      line = "Thessaly dozes off over her notes. Pip draws a small, very neat moustache in the margin, and says nothing.",
      effects = { { "all", social = 5 }, { "arch:method_actor", fun = 3 } } },
    { id = "first_watch", where = { "any" }, pair = { "pc:dev", "pc:mara" }, tags = { "bond" },
      line = "Brannoc takes first watch, and Thessaly keeps him company, reading her notes aloud until he begs her to stop.",
      effects = { { "all", social = 5 }, { "arch:storyteller", fun = 2 } } },
}

return M
