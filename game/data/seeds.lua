-- Seeds (M6): little mysteries the DM plants in one week and pays off in a later
-- one. Data only: tune freely. The model is game/model/seeds.lua.
--
-- Planting one costs prep time; it's mentioned at the start of game night. From the
-- next week its payoff card turns up in your hand for PAYOFF_WEEKS weeks. Put it on
-- the board and the seed pays off: a big story moment. Leave it too long and it goes
-- stale, and the people who were theorizing about it notice.
--
-- plant:   what gets narrated the night it's planted.
-- theory:  what the group chat calls it when they theorize ({seed} in their lines).
-- payoff:  the component that pays it off (components.lua, reserve = "payoff").
-- nudge:   subclasses it makes more tempting at level 3 (game/data/progression.lua).
-- fans:    archetypes that get most excited about it.

return {
    PAYOFF_WEEKS = 3,      -- the payoff card is in your hand for this many weeks after planting
    PER_WEEK = 1,          -- seeds you can plant a week
    COST = 1,              -- prep hours to plant one
    OFFERED = 3,           -- seed ideas on offer each week

    order = { "retired_captain", "sigil_door", "mirror_letters", "old_roads", "laughing_shrine",
              "cold_hearths", "rooftop_signs", "watching_eyes", "healers_vigil" },

    retired_captain = {
        name = "The retired captain",
        plant = "An old soldier drinks alone at the Kettle, a folded banner on her table. She won't say whose it was.",
        theory = "the old soldier at the Kettle",
        payoff = "holt",
        nudge = { banner_captain = 1.4 },  -- aimed at Dev: the one story that might pull him off Champion
        fans = { "storyteller", "tactician", "butt_kicker" },
    },
    sigil_door = {
        name = "Spell-drinking sigils",
        plant = "Someone has scratched sigils into the chapel door. A light spell gutters out the moment it touches them.",
        theory = "the sigils on the chapel door",
        payoff = "sigil_ward",
        nudge = { spellguard = 1, evoker = 0.6 },
        fans = { "explorer", "power_gamer", "storyteller" },
    },
    mirror_letters = {
        name = "Ilsa's backwards letters",
        plant = "A letter in Ilsa's handwriting turns up at the archive. Every word is written backwards.",
        theory = "Ilsa's backwards letters",
        payoff = "ilsa_mirror",
        nudge = { mirror_mage = 1 },
        fans = { "storyteller", "method_actor" },
    },
    old_roads = {
        name = "The map of roads that aren't there",
        plant = "A peddler sells the party an old map for two coppers. Half the roads on it don't exist.",
        theory = "the map with the roads that don't exist",
        payoff = "lost_road",
        nudge = { wayfinder = 1, thief = 0.4 },
        fans = { "explorer", "storyteller" },
    },
    laughing_shrine = {
        name = "The Laughing Saint's shrine",
        plant = "There's a tiny roadside shrine to a laughing saint. Someone keeps leaving fresh pies on it.",
        theory = "whoever keeps leaving pies at the shrine",
        payoff = "brother_tumble",
        nudge = { mischief = 1 },
        fans = { "instigator", "casual", "method_actor" },
    },
    cold_hearths = {
        name = "The cold hearths",
        plant = "Travellers mutter about Millbrook, where every hearth in town went cold on the same night.",
        theory = "the cold hearths in Millbrook",
        payoff = "relight_hearths",
        nudge = { hearth = 1 },
        fans = { "casual", "storyteller" },
    },
    rooftop_signs = {
        name = "Chalk on the rooftops",
        plant = "Chalk marks on a chimney: thieves' signs. One of them is a mark only the Velvet Hand uses.",
        theory = "the chalk marks on the rooftops",
        payoff = "rooftops",
        nudge = { thief = 1 },
        fans = { "explorer", "instigator", "method_actor" },
    },
    watching_eyes = {
        name = "Eyes in the treeline",
        plant = "For three days now, something small has been following the party from the treeline.",
        theory = "whatever's been following us",
        payoff = "goblin_scout",
        nudge = { ambusher = 1, champion = 0.3 },
        fans = { "explorer", "tactician", "instigator" },
    },
    healers_vigil = {
        name = "The healers' vigil",
        plant = "A wagon of wounded rattles past, headed for a field hospital that never closes its doors.",
        theory = "the field hospital that never closes",
        payoff = "field_hospital",
        nudge = { life = 1 },
        fans = { "casual", "tactician", "storyteller" },
    },
}
