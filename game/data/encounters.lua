-- What fights look like on game night: which monsters a cast card brings, what
-- a location throws at the party when the cast isn't the fighting kind, and how
-- tough a fight the DM's prep asks for. Data only: tune freely.
--
-- Monster ids are from game/rules/data/monsters.lua (SRD 5.2.1).
-- boss:   the stat block that plays the named villain (gets the spotlight cards).
-- name:   what the table calls the boss.
-- minion: what fills out the rest of the XP budget, in order of preference.

return {
    -- The people and places that bring a fight of their own, by card id. An adventure's rooms bring
    -- their own encounters (game/data/museum/module.lua), so these are empty for now.
    by_cast = {},
    by_location = {},

    default = { boss = "goblin_boss", name = "the goblin chief", minion = { "goblin_warrior" } },

    -- Prep difficulty (1-3, from the cast and complication) -> SRD budget band (p. 202).
    -- A set piece reaches one step higher.
    budget = { "low", "moderate", "high" },

    -- Party-sized guard rails so a fight stays readable on the mat.
    max_monsters = 7,
}
