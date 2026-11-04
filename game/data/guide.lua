-- The first-session tips (tester-ready pass, after M7): one short tip at a time that walks
-- someone who has never seen the game through their first game night and its report. Tips never
-- block: the game carries on around them, and doing the thing a tip asks for moves it along.
-- (Session Zero, the prep board and the hooks page explain themselves on screen.)
--
-- Each step:
--   id       unique; seen steps are kept in the campaign (and its save)
--   screen   the screen it belongs to ("night", "report")
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
        -- The first game night ------------------------------------------------------------------
        {
            id = "night_watch", screen = "night", at = NIGHT_WATCH, timeout = 30, leave = true,
            when = function(app, c) return week(c, 1) and not app.pending end,
            done = function(app) return app.night_done end,
            anchor = { 10, 772, 1580, 126 },
            title = "It plays itself",
            text = "Your players along the bottom: their faces, their characters and their dice. Click one for their sheet. The keys for skipping and speed are top right.",
        },
        -- v2: what a friend is thinking and not saying (game/model/thoughts.lua).
        {
            id = "night_thought", screen = "night", at = NIGHT_WATCH, timeout = 25, leave = true,
            when = function(app) return app.thinking ~= nil and next(app.thinking) ~= nil and not app.thought_card end,
            done = function(app) return app.thought_card ~= nil or app.thought_answered end,
            title = "What they're thinking",
            text = "A cloud over a player's panel is something they're thinking and not saying. Click it to read it "
                .. "and answer, or let it be. The more Empathy you have, the more of these you catch.",
        },
        {
            id = "night_decision", screen = "night", at = NIGHT,
            when = function(app) return pending(app, "decision") end,
            done = function(app) return not pending(app, "decision") end,
            title = "Your call",
            text = "Only the DM can make this one. There's no right answer: pick what fits your table, and watch how they take it.",
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
