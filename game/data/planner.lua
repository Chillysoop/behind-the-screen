-- The campaign planner (the slice rework): what the DM sketches before Session Zero, the way
-- a real DM does (the 2024 DMG's campaign steps, setting truths from the one-page campaign
-- guide, fronts from Dungeon World, the three clue rule). In the slice the premise and
-- Kessrick's front are fixed; the DM picks three truths, a second front and two featured
-- threads. The plan decides what goes into the story deck. Data only: tune freely. The
-- model is game/model/planner.lua.
--
-- truths:  things the characters know about the world. Each adds its cards to the deck and
--          tilts the hand toward cards that suit its places (suits).
-- fronts:  dangers that move whether or not the party deals with them (impulse, grim portents,
--          impending doom). Each week a front isn't pushed back (none of its cards played and
--          won), its next portent happens and adds its cards. Past the last portent, the doom.
--          cards: the front's cards; playing one and winning pushes it back for a week.

return {
    PICK_TRUTHS = 3,
    PICK_THREADS = 2,

    premise = {
        name = "The Silent Bells",
        text = "The bells that warn the Vale of Millbrook have gone quiet, and something is gathering in the hills.",
    },

    truths = {
        { id = "wolves", name = "Wolves rule the hills", short = "Wolves",
          about = "Nobody walks the high roads alone. The packs are bigger every winter.",
          suits = { "forest", "wild" }, cards = { "wolf_pack", "howls", "wolf_pelt" } },
        { id = "old_faith", name = "The old faith is fading", short = "Old faith",
          about = "Shrines stand empty, and the dead don't always stay where they're put.",
          suits = { "ruin", "bells" }, cards = { "restless_dead", "shrine", "lay_to_rest" } },
        { id = "trade", name = "Millbrook lives on trade", short = "Trade",
          about = "Wool comes down from the hills and coin comes up the river. Everyone owes someone.",
          suits = { "town", "crowd", "road" }, cards = { "merchant", "caravan", "fair", "trade_writ" } },
        { id = "thieves", name = "Lowmarket belongs to thieves", short = "Thieves",
          about = "The Velvet Hand runs the alleys, and half the town pays it for the privilege.",
          suits = { "town", "crowd", "shop" }, cards = { "cutpurses", "steal_ledger", "purse_lifted" } },
        { id = "weather", name = "The weather turns fast up here", short = "Weather",
          about = "Fog off the peaks, floods in spring, and storms that come out of a clear sky.",
          suits = { "outdoor", "wild", "water" }, cards = { "fog", "flood", "shelter", "toll" } },
        { id = "barrows", name = "The hills are full of old graves", short = "Old graves",
          about = "Barrows older than the bells, and people who dig in them at night.",
          suits = { "under", "ruin" }, cards = { "barrow", "explore_barrow", "old_coin" } },
    },

    fronts = {
        kessrick = {
            fixed = true, name = "Kessrick's warband",
            impulse = "Burn the valley the way he burned Hale's Crossing.",
            doom = "Kessrick's warband comes down from the hills, and Millbrook burns.",
            -- The arc's own beats are this front's portents (arc.lua); shown, not dealt.
            portents = { "The bells fall silent.", "Wolves on the north road.", "Vask holds the tower.",
                         "The horns sound in the hills." },
        },
        velvet_hand = {
            name = "The Velvet Hand calls in its debts",
            about = "Pip's old crew, and the people who own half of Lowmarket.",
            impulse = "Own everything in Millbrook worth owning.",
            doom = "The Velvet Hand owns Millbrook, bells and all.",
            portents = {
                { text = "Sable's collectors start asking after Pip.", cards = { "collectors" } },
                { text = "The Hand buys up the Kettle's debts.", cards = { "save_kettle" } },
                { text = "The Hand puts the tower's second key up for sale.", cards = { "key_for_sale" } },
            },
            cards = { "madame_sable", "velvet_den", "collectors", "save_kettle", "key_for_sale", "sable_job", "steal_ledger", "cutpurses" },
        },
        under_chapel = {
            name = "Something stirs under the chapel",
            about = "The roadside chapel was built over something older.",
            impulse = "The dead want their bell rung.",
            doom = "The dead of the valley rise, and walk toward the bell tower.",
            portents = {
                { text = "Candles burn in the chapel at night.", cards = { "crypt" } },
                { text = "Graves stand open on the north road.", cards = { "restless_dead", "dead_walk" } },
                { text = "The crypt bell rings by itself.", cards = { "silence_crypt" } },
            },
            cards = { "chapel", "crypt", "restless_dead", "dead_walk", "silence_crypt", "lay_to_rest" },
        },
    },
    second_fronts = { "velvet_hand", "under_chapel" },

    -- What a fresh plan starts on (and what saves from before the planner get).
    default = { truths = { "wolves", "old_faith", "trade" }, front = "velvet_hand", threads = { "mara", "dev" } },
}
