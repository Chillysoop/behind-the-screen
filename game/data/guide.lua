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
            -- (Gone once the second room starts, with the keys it points at: the third playtest's
            -- engine run had it in the corner from 7:07 pm to 10:08 pm.)
            done = function(app) return app.night_done or app.keys_hidden end,
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
        -- (Each kind of call has its own tip the first time it comes, R6: the first night has the
        -- story's calls, one big roll and one thought; the rest come from the second night on.)
        {
            id = "night_table_asks", screen = "night", at = NIGHT,
            when = function(app)
                local id = pending(app, "decision") and app.pending.card and app.pending.card.id or ""
                return string.find(id, "^table_asks_") ~= nil or string.find(id, "^mus_fork_") ~= nil
            end,
            done = function(app) return not pending(app, "decision") end,
            title = "They're asking you",
            text = "This one is the players' choice, and they can't agree. Nudge them if you like, or leave it to them. Most take a nudge; nudge too often and they notice.",
        },
        {
            id = "night_fight_call", screen = "night", at = NIGHT,
            when = function(app)
                local t = pending(app, "decision") and app.pending.card and app.pending.card.type
                return t == "combat" or t == "boss" or t == "pacing"
            end,
            done = function(app) return not pending(app, "decision") end,
            title = "A call in the fight",
            text = "The fight waits for you: who the monsters go for, how a big moment lands, when it's gone on long enough. The dice do the rest.",
        },
        {
            id = "night_screen", screen = "night", at = NIGHT,
            when = function(app)
                return pending(app, "decision") and app.pending.card and app.pending.card.type == "screen"
            end,
            done = function(app) return not pending(app, "decision") end,
            title = "Behind your screen",
            text = "Only you see this one. Whatever you pick, the table only sees what happens.",
        },
        {
            id = "night_rules", screen = "night", at = NIGHT,
            when = function(app)
                return pending(app, "decision") and app.pending.card and app.pending.card.type == "rules"
            end,
            done = function(app) return not pending(app, "decision") end,
            title = "A rules question",
            text = "Someone isn't sure how a rule works. Look it up, go with what's fun, or keep it moving: whichever you pick, somebody at the table will have an opinion.",
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
            -- (Over the verdict, not WHAT IT EARNED: the third playtest's engine run, 8_17, couldn't see
            -- what the first night earned until the tip was closed. A minute on screen at most.)
            id = "report_read", screen = "report", at = { 24, 652 }, timeout = 60, leave = true,
            when = function(app, c) return week(c, 1) end,
            anchor = { 916, 84, 660, 556 },
            title = "How it landed",
            text = "Each player's night, the least happy first, and the bars that carry over. Weeks of low Commitment and someone takes a break.",
        },
    },
}
