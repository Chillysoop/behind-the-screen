-- Table conflicts (M6): the three slice scenarios. Each one builds pressure from
-- what happens at the table and has several valid fixes. Data only: tune freely.
-- The model is game/model/social.lua.
--
-- pressure: 0..100. At BREWING people start noticing (its card can come up on game
--           night). At ACTIVE it costs the people involved Commitment every week
--           until it's settled.
-- side:     who's on each side; hurt: who loses Commitment while it's active.
-- fixes:    every way it can be settled, with the line the report shows.

return {
    order = { "spotlight", "rules", "tone" },
    BREWING = 40,
    ACTIVE = 70,
    ESCALATE = 3,          -- Commitment lost per week while active, by each hurt player
    PROGRESS_TO_FIX = 2,   -- table moves (night card picks) that settle a conflict at the table
    RECUR_RATE = 0.4,      -- pressure builds this much slower once a conflict has been settled
    FADE = 2,              -- pressure a calm conflict loses each week

    spotlight = {
        name = "The Pip show",
        about = "Jess fills every scene. The quieter players are fading into the background.",
        side = { "jess" },
        hurt = { "sam", "mara", "dev" },
        start = 14,
        brewing = "Jess is taking up most of the spotlight.",
        active = "The others are getting tired of the Pip show.",
        fixes = {
            table = "You kept passing the spotlight at the table until it stuck.",
        },
    },

    rules = {
        name = "Rules lawyering",
        about = "Dev wants rule of cool, Sam wants the same rules every time, and every call starts an argument.",
        side = { "dev", "sam" },
        hurt = { "dev", "sam" },
        start = 6,
        brewing = "Dev and Sam keep arguing about your rules calls.",
        active = "Every rules call turns into Dev against Sam.",
        fixes = {
            vote = "The table voted on it. Fair's fair, even for the loser.",
        },
    },

    tone = {
        name = "Tone clash",
        about = "Mara wants the story taken seriously. Jess can't resist a joke.",
        side = { "mara", "jess" },
        hurt = { "mara", "jess" },
        start = 0,
        brewing = "Jess's jokes keep landing in Mara's serious moments.",
        active = "Mara and Jess want two different games.",
        fixes = {
            table = "You protected the quiet moments at the table until it stuck.",
            split = "One week, two scenes: Mara got her serious beat and Jess got her goofy one.",
        },
    },

    -- What the rules cards are about, for house rules and votes.
    rules_topics = {
        grapple = "grappling", stacking = "stacking bonuses", potion_action = "potions", flanking = "flanking",
    },
}
