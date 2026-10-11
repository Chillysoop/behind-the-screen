-- Player archetypes, adapted from Robin D. Laws' player types plus two
-- common table types. Data only: tune freely.
--
-- weights:    how much each session meter counts toward this player's Fun.
-- taste:      how they feel about each scene type, -1 (bored) to 2 (love it).
-- likes:      component tags that add enjoyment; negative values annoy them.
-- difficulty: the challenge level they enjoy most, 1 (easy) to 3 (hard).
-- perception: how quickly they notice a cooked roll.
-- want:       what they ask for when they aren't getting it.

return {
    power_gamer = {
        name = "Power Gamer",
        weights = { reward = 0.40, challenge = 0.30, spotlight = 0.20, story = 0.05, social = 0.05 },
        taste = { combat = 1, social = 0, exploration = 1, puzzle = 0, mystery = 0, downtime = -1, set_piece = 2 },
        likes = { loot = 2, danger = 1, cozy = -1 },
        difficulty = 3,
        perception = 1.3,
        want = "find some better loot",
    },
    butt_kicker = {
        name = "Butt-Kicker",
        weights = { challenge = 0.45, spotlight = 0.25, reward = 0.15, social = 0.10, story = 0.05 },
        taste = { combat = 2, social = -1, exploration = 0, puzzle = -1, mystery = -1, downtime = -1, set_piece = 2 },
        likes = { action = 2, chaos = 1, talk = -1 },
        difficulty = 2,
        perception = 1.0,
        want = "hit something",
    },
    tactician = {
        name = "Tactician",
        weights = { challenge = 0.50, story = 0.15, reward = 0.15, spotlight = 0.10, social = 0.10 },
        taste = { combat = 2, social = 0, exploration = 0, puzzle = 2, mystery = 1, downtime = -1, set_piece = 1 },
        likes = { puzzle = 2, danger = 1, chaos = -1 },
        difficulty = 3,
        perception = 1.4,
        want = "have a fight that's actually hard",
    },
    method_actor = {
        name = "Method Actor",
        weights = { spotlight = 0.45, social = 0.25, story = 0.25, challenge = 0.05, reward = 0.0 },
        taste = { combat = 0, social = 2, exploration = 0, puzzle = 0, mystery = 1, downtime = 1, set_piece = 0 },
        likes = { talk = 2, heart = 2, funny = 1 },
        difficulty = 1,
        perception = 0.9,
        want = "talk to more NPCs",
    },
    storyteller = {
        name = "Storyteller",
        weights = { story = 0.50, spotlight = 0.20, social = 0.15, challenge = 0.10, reward = 0.05 },
        taste = { combat = -1, social = 1, exploration = 1, puzzle = 0, mystery = 2, downtime = 0, set_piece = 1 },
        likes = { lore = 2, mystery = 2, heart = 1, chaos = -1 },
        difficulty = 2,
        perception = 1.1,
        want = "get some answers about the plot",
    },
    explorer = {
        name = "Explorer",
        weights = { story = 0.35, challenge = 0.20, reward = 0.20, spotlight = 0.15, social = 0.10 },
        taste = { combat = 0, social = 0, exploration = 2, puzzle = 1, mystery = 1, downtime = 0, set_piece = 1 },
        likes = { explore = 2, lore = 1, loot = 1 },
        difficulty = 2,
        perception = 1.2,
        want = "explore somewhere new",
    },
    casual = {
        name = "Casual",
        weights = { social = 0.55, story = 0.15, reward = 0.15, challenge = 0.10, spotlight = 0.05 },
        taste = { combat = 0, social = 1, exploration = 0, puzzle = -1, mystery = 0, downtime = 2, set_piece = 0 },
        likes = { cozy = 2, funny = 2, danger = -1 },
        difficulty = 1,
        perception = 0.7,
        want = "just hang out at the tavern for a bit",
        shy = true, -- forced spotlight backfires
    },
    instigator = {
        name = "Instigator",
        weights = { spotlight = 0.30, challenge = 0.20, social = 0.20, story = 0.15, reward = 0.15 },
        taste = { combat = 1, social = 1, exploration = 1, puzzle = -1, mystery = 0, downtime = 0, set_piece = 1 },
        likes = { chaos = 2, funny = 1 },
        difficulty = 2,
        perception = 1.0,
        want = "do something chaotic",
    },
}
