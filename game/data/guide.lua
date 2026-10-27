-- The first-session tips (tester-ready pass, after M7): one short tip at a time that walks
-- someone who has never seen the game through their first game night and the report. (Setting
-- up and prep explain themselves a step at a time, October 26.) Tips never block:
-- the game carries on around them, and doing the thing a tip asks for moves it along.
--
-- Each step:
--   id       unique; seen steps are kept in the campaign (and its save)
--   screen   the screen it belongs to ("lore", "night", "report")
--   when     function(app, c) -> true when it should show (optional)
--   done     function(app, c) -> true once the player has done what it asks (optional)
--   timeout  seconds on screen (in total) before it quietly goes (optional)
--   leave    true: counts as seen once the player leaves the screen while it shows
--   anchor   { x, y, w, h } to outline on screen (top-left coordinates, 1600x900), optional; or
--            function(app) -> that, for something that moves
--   at       { x, y } where the tip panel goes, or function(app) -> that
--   seq      a run of tips that belong together: the panel says which one of how many
--   title, text
-- Data only: tune freely. The view is game/ui/guide_view.lua.

local function week(c, n)
    return c.week == n
end

local function pending(app, kind)
    return app.pending ~= nil and app.pending.kind == kind
end

local NIGHT = { 608, 330 }        -- game night: between the left and right decision cards, above the narration
local NIGHT_WATCH = { 1236, 110 } -- game night, before any card: top right, clear of the table

return {
    WIDTH = 340,

    steps = {
        -- Setting up the campaign and the week's prep have no tips (October 26): each step asks one
        -- thing and says what it's for, and your friends say the rest.

        -- The first game night ------------------------------------------------------------------
        {
            id = "night_watch", screen = "night", at = NIGHT_WATCH, timeout = 30, leave = true,
            when = function(app, c) return week(c, 1) and not app.pending end,
            done = function(app) return app.night_done end,
            anchor = { 10, 772, 1580, 126 },
            title = "It plays itself",
            text = "Your players along the bottom: their faces, their characters and their dice. Click one for their sheet. The keys for skipping and speed are top right.",
        },
        {
            id = "night_decision", screen = "night", at = NIGHT,
            when = function(app) return pending(app, "decision") end,
            done = function(app) return not pending(app, "decision") end,
            title = "Your call",
            text = "Only the DM can make this one. There's no right answer: pick what fits your table, and watch how they take it.",
        },
        -- Two kinds of improvising (the newcomer playtest, October 16: "Off the map" came up for a
        -- slot left empty in a planned scene, and read as the players wandering off).
        {
            id = "night_improv_slot", screen = "night", at = { 1236, 100 },   -- the improv hand fills the middle
            when = function(app) return pending(app, "improv") and not app.pending.drift end,
            done = function(app) return not pending(app, "improv") end,
            title = "Make it up",
            text = "You left this slot empty in prep, so now you invent it on the spot. Pick cards that fit this scene "
                .. "(green), then Play. Two that fit beat three that don't.",
        },
        {
            id = "night_improv", screen = "night", at = { 1236, 100 },
            when = function(app) return pending(app, "improv") and app.pending.drift end,
            done = function(app) return not pending(app, "improv") end,
            title = "Off the map",
            text = "They went somewhere you didn't plan. Pick cards from your improv hand that fit the moment, then Play.",
        },
        {
            id = "night_roll_where", screen = "night", at = NIGHT,
            when = function(app) return pending(app, "roll_where") end,
            done = function(app) return not pending(app, "roll_where") end,
            title = "Where the die lands",
            text = "In the open, everyone sees the result. Behind the screen, you could change it later, if you dare.",
        },
        {
            id = "night_cook", screen = "night", at = NIGHT,
            when = function(app) return pending(app, "ruling") and app.pending.cook ~= nil end,
            done = function(app) return not pending(app, "ruling") end,
            title = "Cooking the dice",
            text = "Behind the screen, the last button changes a roll nobody saw. It might save the night, but if they catch you, trust takes a real hit.",
        },
        {
            id = "night_ruling", screen = "night", at = NIGHT,
            when = function(app) return pending(app, "ruling") end,
            done = function(app) return not pending(app, "ruling") end,
            title = "How does it land?",
            text = "The die says how well it went. You decide how generous to be: a yes with strings, or a no that still gives them something.",
        },

        -- The lore screen (October 16): what tonight can change, before the table sits down.
        {
            id = "lore_first", screen = "lore", at = { 798, 610 }, leave = true, timeout = 60,
            anchor = { 24, 108, 1128, 412 },
            title = "What tonight can change",
            text = "Each scene's clues, and what a win (green) or a loss (orange) puts in next session's hand. "
                .. "Point at a line for more. Want a different night? Back to prep.",
        },

        -- The first report ------------------------------------------------------------------------
        {
            id = "report_read", screen = "report", at = { 412, 660 },
            when = function(app, c) return week(c, 1) end,
            anchor = { 776, 84, 800, 556 },
            title = "How it landed",
            text = "Each player's night, the least happy first, and the bars that carry over. Weeks of low Commitment and someone takes a break.",
        },
    },
}
