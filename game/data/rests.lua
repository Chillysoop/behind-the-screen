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
}

return M
