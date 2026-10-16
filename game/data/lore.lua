-- The world's iconography and the opening of session 1 (October 15). Every storyline, faction,
-- front and truth has one icon (drawn by tools/gen_ui.py, "icon_<name>" in the UI atlas), used
-- the same way everywhere: the opening, the story cards, the prep board, the Story log. The
-- opening is the DM setting up the world before the players introduce their heroes; the
-- briefing comes after, and says what matters, where the heroes are and what to do first.
-- Data only: tune freely. The model is game/model/lore.lua.

return {
    icons = {
        storylines = { bells = "bell", velvet = "hand", dead = "skull", tobin = "trail", wool_roads = "wheel",
                       traitor = "mask", spurs = "spur" },
        factions = { warband = "wolf", velvet_hand = "hand", millbrook = "house", old_faith = "candle", spurs = "spur" },
        fronts = { kessrick = "wolf", velvet_hand = "hand", under_chapel = "skull" },
        truths = { wolves = "paw", old_faith = "candle", trade = "wheel", thieves = "coin", weather = "cloud",
                   barrows = "grave" },
    },
    -- Why anyone would be here (October 15: "You're in Ilsa's room" with no reason given), said
    -- after "You're at <place>, ...". Scene 1's goal comes first when it has one ("..., to find the
    -- map"); this is for when it doesn't.
    place_why = {
        archive = "where Millbrook kept its records, before the water came in",
        barrow = "where the hill folk say the old dead sleep",
        bell_paths = "where the bell-ringers used to walk",
        bell_tower = "where the silence started",
        chapel = "on the road north out of town",
        counting_house = "where the Velvet Hand keeps its ledgers",
        crypt = "where the candles have been burning",
        dn_flooded_hall = "the first deep level, where the water never drains",
        dn_lamp_ladder = "the tavern over the hole, where every delver starts",
        dn_mouth = "where every delve starts",
        dn_mushroom_market = "where the deep folk trade by glowcap light",
        dn_portal_hall = "where the arches lead somewhere they shouldn't",
        dn_safe_room = "the one room down there everyone agrees is safe",
        field_hospital = "where the wounded from the hills end up",
        fighting_pit = "where Lowmarket settles its arguments",
        forest_road = "the north road out of town, into the pines",
        fr_harvest_fair = "where the whole valley turns up once a year",
        fr_millpond = "where the mill keeps Millbrook fed",
        fr_old_mine = "where somebody's been digging again",
        fr_tinkers_road = "the road the carts take to Coppergate",
        fr_west_road = "where Millbrook stops",
        goblin_camp = "where the goblins have dug in",
        gz_bell_foundry = "where the valley's bells were cast",
        gz_causeway = "the only dry way across the marsh",
        gz_clocktower = "the one clock in Coppergate nobody can fix",
        gz_waystation = "where every traveller stops",
        hales_crossing = "Brannoc's old village, the one Kessrick burned",
        ilsa_room = "where Ilsa lived before she vanished",
        lighthouse = "where the coast's last light still burns",
        lost_road = "where the map runs out",
        market = "where all of Millbrook comes to haggle",
        masquerade = "where the Duke's guests hide behind masks",
        millbrook_walls = "the last line between the town and the hills",
        mod_bell_crypt = "where the old bell-ringers were buried",
        mod_bridge_span = "the only bridge for miles, and its troll",
        old_bridge = "the only way across the gorge",
        rooftops = "where Lowmarket's thieves walk",
        sea_brinehollow = "the harbour every ship comes home to",
        sea_customs_house = "where every cargo is weighed and taxed",
        sea_lantern_isles = "the islands with lights nobody tends",
        sea_maelstrom = "the whirlpool the sailors sing about",
        sea_marigold_deck = "the ship you've signed on with",
        sea_wreck = "just uncovered by the tide",
        shrine = "where the old faith still lingers",
        sunken_temple = "swallowed by the lake long ago",
        tavern = "where all of Millbrook's news ends up",
        ur_brass_lantern = "Coppergate's busiest tavern",
        ur_canal_market = "where Coppergate buys and sells everything",
        ur_chimney_road = "the road over the rooftops of Coppergate",
        ur_lamplighters = "where the lamplighters keep the city lit",
        ur_north_gate = "where every cart in Coppergate comes and goes",
        ur_sewers = "where the old water runs",
        velvet_den = "where Madame Sable does her business",
        wd_ferny_cross = "where the wild roads cross",
        wd_footprint_lake = "the lake shaped like a giant's footprint",
        wd_high_pass = "the only way over the ridge",
        wd_otter_ford = "the only ford for miles",
        wd_standing_stones = "the nine standing stones, older than anyone",
        wd_sunken_road = "the old road worn deep into the hill",
        webbed_cellar = "shut up for years",
    },
    -- Where a place's full name needs its own words after "You're ..." ("at market square").
    place_here = {
        market = "in the market square", sea_marigold_deck = "on the deck of the Marigold",
        wd_ferny_cross = "at Ferny Cross waystation", wd_otter_ford = "at Otterbank Ford",
        gz_waystation = "at the Hollow Oak waystation", ur_north_gate = "in the North Gate carters' yard",
        wd_sunken_road = "on the Sunken Road", rooftops = "on the rooftops of Lowmarket",
        dn_mouth = "at the mouth of the Deep Stair", gz_clocktower = "under Coppergate's broken clocktower",
        ur_chimney_road = "on the Chimney Road", sea_lantern_isles = "on the Lantern Isles",
        gz_causeway = "on the Saltmarsh causeway",
    },
    -- Goals named as a deed ("Find the map") read "..., to find the map" after where they are.
    deed_verbs = { "break", "bring", "carry", "celebrate", "chart", "clear", "do", "escape", "fill", "find", "follow",
                   "get", "keep", "lay", "negotiate", "relight", "rescue", "save", "silence", "solve", "steal", "survive",
                   "unmask", "warn", "win", "catch", "stop", "protect", "track", "deliver", "defend", "free", "return" },
    -- Behind the screen (October 15: the villain's plan lived only in the notebook): each front's
    -- storyline, so a small table shows a front only once its story is in play.
    front_story = { velvet_hand = "velvet", under_chapel = "dead" },
    -- Clues that belong to someone other than their card's storyline, for the recap's icons: a
    -- storyline id, or "front:<id>" for a front's own mark (the wolves at the edge of town are
    -- Kessrick's, not the bells').
    clue_marks = { tavern = "front:kessrick", forest_road = "front:kessrick", wolf_lieutenant = "front:kessrick",
                   chapel = "tobin" },
    -- Factions have no storyline color of their own: these, on the notebook's Factions page and
    -- the opening.
    faction_colors = { warband = "#c0663e", velvet_hand = "#b0506a", millbrook = "#8aa060", old_faith = "#7a8ab0",
                       spurs = "#9a9aa8" },

    -- Session 1 opens with these, one card at a time, before the introductions.
    opening = {
        town = { icon = "house", color = "#8aa060", kicker = "SESSION 1  -  THE WORLD", title = "The Vale of Millbrook",
                 text = "A market town in the hills, where the wool roads meet. Everyone knows everyone, everyone drinks at "
                     .. "the Crooked Kettle, and every hour the whole town stops to listen for the bells." },
        bells = { icon = "bell", color = "#c8a24a", kicker = "THE STORY", title = "The Silent Bells",
                  text = "For forty years Old Tobin rang the hours from the bell tower. Nine days ago the bells stopped, "
                      .. "and nobody in Millbrook has seen Tobin since. Somebody here knows more." },
        kessrick = { icon = "wolf", color = "#c0663e", kicker = "THE DANGER", title = "Kessrick's warband",
                     text = "A warlord and his wolves, somewhere up in the hills. Last spring they burned Hale's Crossing "
                         .. "to the ground. The bells were how the valley knew they were coming." },
        fronts = {
            velvet_hand = { icon = "hand", color = "#b0506a", kicker = "ALSO IN TOWN", title = "The Velvet Hand",
                            text = "Madame Sable's guild of very polite thieves. They've been buying up Millbrook's "
                                .. "debts, one shop at a time, and nobody says no to Sable." },
            under_chapel = { icon = "skull", color = "#7a8ab0", kicker = "ALSO ON THE ROAD", title = "The roadside chapel",
                             text = "Built over something much older. Lately there are candles in its windows at "
                                 .. "night, and nobody lit them." },
        },
        truths = { kicker = "WHAT EVERYONE KNOWS", title = "Life in the Vale" },
        last = "Now: who's at the table?",
    },

    -- After the introductions: the short version, then where they are and what to do first.
    briefing = {
        kicker = "SO, HERE'S WHERE WE ARE",
        rows = {
            bells = "The bells have been silent for nine days, and Old Tobin is missing.",
            kessrick = "Kessrick's wolves are out in the hills.",
            velvet_hand = "The Velvet Hand is buying up the town.",
            under_chapel = "Something isn't right at the roadside chapel.",
        },
        -- After the first session (October 15: "nine days" read stale three weeks on).
        rows_later = {
            bells = "The bells are still silent, and Old Tobin is still missing.",
        },
        joining = "Joins the party tonight.",
        -- The heroes' card after session 1: how each one's own story stands.
        heroes = "THE HEROES, AND WHERE THEIR STORIES STAND",
        hero_moved = "Last time, %s",
        hero_moved_above = "%s story moved last session: it's in what you found out.",
        hero_back_quest = "Came back from the dead last session: the way back was found.",
        subject = { Thessaly = "she", Brannoc = "he", Pip = "she", Oswin = "he" },
        hero_came_up = "It came up last session.",
        hero_quiet = "It hasn't moved since session %d.",
        hero_unstarted = "%s own story hasn't come up yet.",
        hero_quest = "%s fell in session %d, and the party's looking for the way back. %s plays on in the meantime.",
        hero_scarred = "Came back from the dead last session, at a cost.",
        hero_new = "%s, new to the party since %s fell.",
        -- Whose story: "Her own story hasn't come up yet" (a new hero's is "Their").
        possessive = { Thessaly = "Her", Brannoc = "His", Pip = "Her", Oswin = "His" },
        where = "WHERE YOU ARE",
        -- Every session after the first opens on the DM's recap: what they found, where, what's next.
        previously = "LAST TIME, IN SESSION %d",
        found = "What happened, and what you found out:",
        found_short = "Last time:",
        -- Someone joins a small table: catching them up, over two cards.
        catch_up = "CATCHING %s UP: THE STORY SO FAR",
        party = "WHO YOU'RE TRAVELLING WITH",
        -- What they're out to do this week, on the prep board's story box and the night's header,
        -- under the main story's icon.
        next = "THIS WEEK",
        next_story = "bells",
        where_town = "You're in Millbrook, in the shadow of the silent bell tower.",
        first = "WHAT'S FIRST",
    },
}
