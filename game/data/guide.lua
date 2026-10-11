-- The first-session tips (tester-ready pass, after M7): one short tip at a time that walks
-- someone who has never seen the game through Session Zero, their first prep, game night and
-- the report, then points out each later feature the first time it matters. Tips never block:
-- the game carries on around them, and doing the thing a tip asks for moves it along.
--
-- Each step:
--   id       unique; seen steps are kept in the campaign (and its save)
--   screen   the screen it belongs to ("session_zero", "prep", "night", "report")
--   when     function(app, c) -> true when it should show (optional)
--   done     function(app, c) -> true once the player has done what it asks (optional)
--   timeout  seconds on screen (in total) before it quietly goes (optional)
--   leave    true: counts as seen once the player leaves the screen while it shows
--   anchor   { x, y, w, h } to outline on screen (top-left coordinates, 1600x900), optional
--   at       { x, y } where the tip panel goes
--   title, text
-- Data only: tune freely. The view is game/ui/guide_view.lua.

local function week(c, n)
    return c.week == n
end

local function pending(app, kind)
    return app.pending ~= nil and app.pending.kind == kind
end

local function filled_slots(c)
    local n = 0
    for _, s in ipairs(c.prep and c.prep.scenes or {}) do
        for _ in pairs(s.slots or {}) do
            n = n + 1
        end
    end
    return n
end

local LEFT = { 24, 540 }          -- prep: bottom of the chat column
local MIDDLE = { 364, 572 }       -- prep: over the pacing panel
local S0 = { 40, 600 }            -- Session Zero: under the pitch
local NIGHT = { 608, 330 }        -- game night: between the left and right decision cards, above the narration
local NIGHT_WATCH = { 1236, 110 } -- game night, before any card: top right, clear of the table

return {
    WIDTH = 340,

    steps = {
        -- The campaign planner (the slice rework) ------------------------------------------------
        {
            id = "plan_intro", screen = "planner", at = { 24, 626 }, leave = true,
            title = "Plan the campaign",
            text = "Real DMs sketch a campaign before the first game. Pick three truths about the world, a second front and two players' stories to feature. The defaults are fine too.",
        },
        -- Session Zero ------------------------------------------------------------------------
        {
            id = "s0_pitch", screen = "session_zero", at = S0,
            anchor = { 16, 84, 516, 318 },
            title = "Session Zero",
            text = "Before the first game, the table talks it through. Start with the tone: each option shows who likes it.",
            done = function(app)
                return app.s0 ~= nil and app.s0.tone ~= nil
            end,
        },
        {
            id = "s0_asks", screen = "session_zero", at = S0,
            anchor = { 540, 84, 516, 724 },
            title = "Their asks",
            text = "Each player asks for one thing. Agree and it holds all campaign; push back and they'll remember. Either is fine.",
            done = function(app)
                local n = 0
                for _ in pairs(app.s0 and app.s0.asks or {}) do
                    n = n + 1
                end
                return n >= 4
            end,
        },
        {
            id = "s0_rules", screen = "session_zero", at = S0,
            anchor = { 1062, 84, 520, 594 },
            title = "Table rules",
            text = "Three house rules, and everyone has an opinion. When you've answered everything, start week 1 (bottom right).",
            done = function(app)
                local r = app.s0 and app.s0.rules or {}
                return r.xcard ~= nil and r.dice ~= nil and r.rulings ~= nil
            end,
        },

        -- The first prep ----------------------------------------------------------------------
        {
            id = "prep_story", screen = "prep", at = LEFT, leave = true,
            when = function(app, c) return week(c, 1) end,
            done = function(app, c)
                for _, s in ipairs(c.prep and c.prep.scenes or {}) do
                    if s.type then
                        return true
                    end
                end
                return false
            end,
            anchor = { 292, 4, 524, 58 },
            title = "Your first session",
            text = "This week's story beat. Click it (or press N) for your notes: what tonight is for and what to read out. Its story cards are in your hand.",
        },
        {
            id = "prep_types", screen = "prep", at = LEFT,
            when = function(app, c) return week(c, 1) end,
            anchor = { 360, 80, 820, 82 },
            title = "Three scenes",
            text = "Pick a type for each scene. Every player loves some types and gets bored in others; the table on the right forecasts it.",
            done = function(app, c)
                for _, s in ipairs(c.prep and c.prep.scenes or {}) do
                    if not s.type then
                        return false
                    end
                end
                return true
            end,
        },
        {
            id = "prep_slots", screen = "prep", at = LEFT,
            when = function(app, c) return week(c, 1) end,
            anchor = { 360, 160, 820, 400 },
            title = "Fill the slots",
            text = "Click a slot, then pick a card below. The faces show who'd love it (green) or not (red); point at a card for the details. Empty slots get improvised.",
            done = function(app, c) return filled_slots(c) >= 2 end,
        },
        {
            id = "prep_table", screen = "prep", at = LEFT, leave = true, timeout = 25,
            when = function(app, c) return week(c, 1) and filled_slots(c) >= 2 end,
            anchor = { 1192, 76, 388, 812 },
            title = "Your players",
            text = "What each one wants, how they feel, and the forecast for Thursday. The bars at the bottom of each card decide whether they keep coming.",
        },
        {
            id = "prep_run", screen = "prep", at = LEFT, leave = true,
            when = function(app, c) return week(c, 1) and filled_slots(c) >= 2 end,
            anchor = { 1352, 8, 228, 50 },
            title = "Game night",
            text = "When you're happy, or out of prep time, run game night. You can always come back to this board next week.",
        },

        {
            id = "prep_fight", screen = "prep", at = { 840, 572 },
            when = function(app, c)
                for i, s in ipairs(c.prep and c.prep.scenes or {}) do
                    if s.type == "combat" or s.type == "set_piece" then
                        return true
                    end
                end
                return false
            end,
            done = function(app) return app.overlay == "encounter" end,
            timeout = 20,
            title = "Build the fight",
            text = "A fight scene brings its own monsters. Open The fight to change them, see how hard it is, and how it matches your party.",
        },

        -- The first game night ------------------------------------------------------------------
        {
            id = "night_watch", screen = "night", at = NIGHT_WATCH, timeout = 30, leave = true,
            when = function(app, c) return week(c, 1) and not app.pending end,
            done = function(app) return app.night_done end,
            anchor = { 10, 772, 1580, 126 },
            title = "It plays itself",
            text = "Your players along the bottom: their faces, their characters and their dice. Click one for their sheet. Space skips ahead, F speeds it up.",
        },
        {
            id = "night_decision", screen = "night", at = NIGHT,
            when = function(app) return pending(app, "decision") end,
            done = function(app) return not pending(app, "decision") end,
            title = "Your call",
            text = "Only the DM can make this one. There's no right answer: pick what fits your table, and watch how they take it.",
        },
        {
            id = "night_improv", screen = "night", at = { 1236, 100 },   -- the improv hand fills the middle
            when = function(app) return pending(app, "improv") end,
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
            when = function(app) return pending(app, "cook") end,
            done = function(app) return not pending(app, "cook") end,
            title = "Cooking the dice",
            text = "You can change a roll nobody saw. It might save the night, but if they catch you, trust takes a real hit.",
        },
        {
            id = "night_ruling", screen = "night", at = NIGHT,
            when = function(app) return pending(app, "ruling") end,
            done = function(app) return not pending(app, "ruling") end,
            title = "A rules call",
            text = "Nobody's sure how the rule works. Decide quickly, or look it up and slow the table down. Each player leans a different way.",
        },

        -- The first report ------------------------------------------------------------------------
        {
            id = "report_read", screen = "report", at = { 420, 330 },
            when = function(app, c) return week(c, 1) end,
            anchor = { 10, 94, 392, 572 },
            title = "How it landed",
            text = "Each player's night, and the bars that carry over (Over time). Weeks of low Commitment and someone takes a break.",
        },

        -- Later, the first time each feature matters ---------------------------------------------
        {
            id = "prep_messages", screen = "prep", at = MIDDLE,
            when = function(app, c)
                return #(c.open_convos or {}) > 0 and app.chat_tab ~= "messages" and not app.convo
            end,
            done = function(app) return app.chat_tab == "messages" or app.convo ~= nil end,
            anchor = { 184, 74, 160, 32 },
            title = "Someone messaged you",
            text = "Private messages settle table arguments before they boil over. Each conversation costs a little prep time.",
        },
        {
            id = "prep_drawer", screen = "prep", at = { 840, 572 },
            when = function(app, c) return c.week >= 2 and not app.sel and not app.convo end,
            anchor = { 360, 676, 820, 214 },
            title = "Evenings and seeds",
            text = "Spare prep time? An evening off draws fresh cards. Plant a seed now and pay it off in a week or three.",
        },
        {
            id = "prep_levelup", screen = "prep", at = LEFT,
            when = function(app, c)
                local st = c.level_status and c:level_status()
                return st and st.ready and not app.levelup
            end,
            done = function(app, c)
                local st = c.level_status and c:level_status()
                return not (st and st.ready)
            end,
            anchor = { 1204, 8, 144, 50 },
            title = "Level up",
            text = "The party is ready to level up. Do it when it feels earned; leave it too long and some players get restless.",
        },
    },
}
