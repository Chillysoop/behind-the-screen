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
        -- The slice rework's new casts.
        wolf_pack = { boss = "dire_wolf", name = "the pack leader", minion = { "wolf" } },
        restless_dead = { boss = "ghoul", name = "the oldest of the dead", minion = { "skeleton", "zombie" } },
        cutpurses = { boss = "bandit_captain", name = "the cutpurses' boss", minion = { "bandit" } },
        grey_coat = { boss = "tough", name = "the man in the grey coat", minion = { "bandit" } },
        turncoat_guide = { boss = "bandit_captain", name = "the turncoat guide", minion = { "bandit", "tough" } },
        -- Campaign styles (A18).
        sea_grey_moll = { boss = "bandit_captain", name = "Captain Grey Moll", minion = { "bandit" } },
        fr_goblin_chief = { boss = "goblin_boss", name = "Chief Nettle", minion = { "goblin_warrior" } },
        dn_lantern_company = { boss = "tough", name = "the Lantern Company's captain", minion = { "bandit", "tough" } },
    },

    -- When the cast doesn't fight (Gus, the hermit...), the place does.
    by_location = {
        goblin_camp = { boss = "goblin_boss", name = "the goblin chief", minion = { "goblin_warrior" } },
        chapel = { boss = "ghoul", name = "the thing in the crypt", minion = { "skeleton", "zombie" } },
        forest_road = { boss = "dire_wolf", name = "the pack leader", minion = { "wolf" } },
        old_bridge = { boss = "bandit_captain", name = "the toll-taker", minion = { "bandit" } },
        archive = { boss = "ghoul", name = "the drowned archivist", minion = { "zombie", "skeleton" } },
        market = { boss = "tough", name = "the gang boss", minion = { "bandit", "tough" } },
        fighting_pit = { boss = "tough", name = "the pit champion", minion = { "bandit" } },
        counting_house = { boss = "bandit_captain", name = "the vault guard captain", minion = { "tough", "bandit" } },
        tavern = { boss = "tough", name = "the biggest drunk", minion = { "bandit" } },
        bell_tower = { boss = "cultist", name = "the bell cult's leader", minion = { "cultist", "skeleton" } },
        hales_crossing = { boss = "ghoul", name = "something in the ashes", minion = { "skeleton", "zombie" } },
        velvet_den = { boss = "tough", name = "the Velvet Hand's enforcer", minion = { "bandit", "tough" } },
        webbed_cellar = { boss = "ghoul", name = "the thing in the cellar", minion = { "zombie" } },
        sunken_temple = { boss = "ghoul", name = "the drowned priest", minion = { "zombie", "skeleton" } },
        lighthouse = { boss = "cultist", name = "the lamp-keeper", minion = { "cultist" } },
        rooftops = { boss = "bandit_captain", name = "the rooftop boss", minion = { "bandit" } },
        lost_road = { boss = "dire_wolf", name = "the road's old guardian", minion = { "wolf" } },
        crypt = { boss = "ghoul", name = "the thing by the crypt bell", minion = { "skeleton", "zombie" } },
        barrow = { boss = "ghoul", name = "the barrow's old king", minion = { "skeleton" } },
        shrine = { boss = "skeleton", name = "the shrine's last guardian", minion = { "skeleton" } },
        bell_paths = { boss = "dire_wolf", name = "the pack leader", minion = { "wolf" } },
        millbrook_walls = { boss = "bandit_captain", name = "Kessrick's outrider", minion = { "bandit", "wolf" } },
        ilsa_room = { boss = "tough", name = "the man waiting in Ilsa's room", minion = { "bandit" } },
        -- Campaign styles (A18): what each style's places throw at the party.
        fr_old_mine = { boss = "goblin_boss", name = "the mine's goblin boss", minion = { "goblin_warrior" } },
        fr_millpond = { boss = "tough", name = "the miller's hired muscle", minion = { "bandit" } },
        fr_west_road = { boss = "dire_wolf", name = "the pack leader", minion = { "wolf" } },
        fr_tinkers_road = { boss = "bandit_captain", name = "the road's bandit chief", minion = { "bandit" } },
        fr_harvest_fair = { boss = "tough", name = "the pie-table brawlers' champion", minion = { "bandit" } },
        sea_marigold_deck = { boss = "bandit_captain", name = "the boarders' captain", minion = { "bandit" } },
        sea_brinehollow = { boss = "tough", name = "the dockside bruiser", minion = { "bandit" } },
        sea_customs_house = { boss = "tough", name = "the customs sergeant", minion = { "tough", "bandit" } },
        sea_wreck = { boss = "ghoul", name = "the drowned bosun", minion = { "zombie", "skeleton" } },
        sea_lantern_isles = { boss = "dire_wolf", name = "the island's old wolf", minion = { "wolf" } },
        sea_maelstrom = { boss = "skeleton", name = "the maelstrom's dead crew", minion = { "skeleton", "zombie" } },
        ur_brass_lantern = { boss = "tough", name = "the biggest drunk", minion = { "bandit" } },
        ur_canal_market = { boss = "bandit_captain", name = "the pickpockets' boss", minion = { "bandit" } },
        ur_chimney_road = { boss = "bandit_captain", name = "the rooftop crew's boss", minion = { "bandit" } },
        ur_lamplighters = { boss = "tough", name = "the Boatmen's enforcer", minion = { "tough", "bandit" } },
        ur_sewers = { boss = "ghoul", name = "the thing in the outflow", minion = { "zombie" } },
        ur_north_gate = { boss = "bandit_captain", name = "the carters' yard boss", minion = { "bandit" } },
        dn_lamp_ladder = { boss = "tough", name = "a delver who lost at dice", minion = { "bandit" } },
        dn_mouth = { boss = "goblin_boss", name = "the goblins' gatekeeper", minion = { "goblin_warrior" } },
        dn_flooded_hall = { boss = "ghoul", name = "the thing under the water", minion = { "zombie" } },
        dn_mushroom_market = { boss = "tough", name = "a deal gone wrong", minion = { "bandit", "goblin_warrior" } },
        dn_portal_hall = { boss = "cultist", name = "the doorkeeper", minion = { "skeleton", "cultist" } },
        dn_safe_room = { boss = "skeleton", name = "a patrol of old bones", minion = { "skeleton" } },
        wd_ferny_cross = { boss = "dire_wolf", name = "the pack leader", minion = { "wolf" } },
        wd_footprint_lake = { boss = "ogre", name = "whatever left the footprints", minion = { "wolf" } },
        wd_high_pass = { boss = "dire_wolf", name = "the pass's old wolf", minion = { "wolf" } },
        wd_otter_ford = { boss = "bandit_captain", name = "the ford's toll-taker", minion = { "bandit" } },
        wd_standing_stones = { boss = "cultist", name = "the stone-singer", minion = { "cultist" } },
        wd_sunken_road = { boss = "ghoul", name = "the road's last traveller", minion = { "skeleton", "zombie" } },
    },

    default = { boss = "goblin_boss", name = "the goblin chief", minion = { "goblin_warrior" } },

    -- Prep difficulty (1-3, from the cast and complication) -> SRD budget band (p. 202).
    -- A set piece reaches one step higher.
    budget = { "low", "moderate", "high" },

    -- Party-sized guard rails so a fight stays readable on the mat.
    max_monsters = 7,
}
