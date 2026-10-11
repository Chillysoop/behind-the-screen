-- What fights look like on game night: which monsters a cast card brings, what
-- a location throws at the party when the cast isn't the fighting kind, and how
-- tough a fight the DM's prep asks for. Data only: tune freely.
--
-- Monster ids are from game/rules/data/monsters.lua (SRD 5.2.1).
-- boss:   the stat block that plays the named villain (gets the spotlight cards).
-- name:   what the table calls the boss.
-- minion: what fills out the rest of the XP budget, in order of preference.

return {
    by_cast = {
        goblins = { boss = "goblin_boss", name = "the goblin chief in the proud hat", minion = { "goblin_warrior" } },
        rook = { boss = "bandit_captain", name = "Captain Rook", minion = { "bandit", "tough" } },
        ogre = { boss = "ogre", name = "the ogre in the bib", minion = { "goblin_warrior" } },
        wolf_lieutenant = { boss = "tough", name = "Kessrick's lieutenant", minion = { "wolf", "bandit" } },
        rivals = { boss = "tough", name = "the Silver Spurs' leader", minion = { "bandit" } },
        madame_sable = { boss = "bandit_captain", name = "Madame Sable", minion = { "tough", "bandit" } },
        verrin = { boss = "cultist", name = "Verrin", minion = { "skeleton" } },
        bone_choir = { boss = "cultist", name = "the choirmaster", minion = { "skeleton", "zombie" } },
        white_wolf = { boss = "dire_wolf", name = "the white wolf", minion = { "wolf" } },
    },

    -- When the cast doesn't fight (Gus, the hermit...), the place does.
    by_location = {
        goblin_camp = { boss = "goblin_boss", name = "the goblin chief", minion = { "goblin_warrior" } },
        chapel = { boss = "ghoul", name = "the thing in the crypt", minion = { "skeleton", "zombie" } },
        forest_road = { boss = "dire_wolf", name = "the pack leader", minion = { "wolf" } },
        old_bridge = { boss = "bandit_captain", name = "the toll-taker", minion = { "bandit" } },
        archive = { boss = "ghoul", name = "the drowned archivist", minion = { "zombie", "skeleton" } },
        market = { boss = "tough", name = "the gang boss", minion = { "bandit", "tough" } },
        tavern = { boss = "tough", name = "the biggest drunk", minion = { "bandit" } },
        bell_tower = { boss = "cultist", name = "the bell cult's leader", minion = { "cultist", "skeleton" } },
        hales_crossing = { boss = "ghoul", name = "something in the ashes", minion = { "skeleton", "zombie" } },
        velvet_den = { boss = "tough", name = "the Velvet Hand's enforcer", minion = { "bandit", "tough" } },
        webbed_cellar = { boss = "ghoul", name = "the thing in the cellar", minion = { "zombie" } },
        sunken_temple = { boss = "ghoul", name = "the drowned priest", minion = { "zombie", "skeleton" } },
        lighthouse = { boss = "cultist", name = "the lamp-keeper", minion = { "cultist" } },
        rooftops = { boss = "bandit_captain", name = "the rooftop boss", minion = { "bandit" } },
        lost_road = { boss = "dire_wolf", name = "the road's old guardian", minion = { "wolf" } },
    },

    default = { boss = "goblin_boss", name = "the goblin chief", minion = { "goblin_warrior" } },

    -- Prep difficulty (1-3, from the cast and complication) -> SRD budget band (p. 202).
    -- A set piece reaches one step higher.
    budget = { "low", "moderate", "high" },

    -- Party-sized guard rails so a fight stays readable on the mat.
    max_monsters = 7,
}
