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
                 text = "A market town in the hills, where the wool roads meet. Everyone knows everyone, and every hour "
                     .. "the whole town stops to listen for the bells." },
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
