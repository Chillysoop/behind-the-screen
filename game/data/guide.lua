-- The first-session tips (tester-ready pass, after M7): one short tip at a time that walks
-- someone who has never seen the game through Session Zero, their first prep, game night and
-- the report, then points out each later feature the first time it matters. Tips never block:
-- the game carries on around them, and doing the thing a tip asks for moves it along.
--
-- Each step:
--   id       unique; seen steps are kept in the campaign (and its save)
--   screen   the screen it belongs to ("session_zero", "prep", "lore", "night", "report")
--   when     function(app, c) -> true when it should show (optional)
--   done     function(app, c) -> true once the player has done what it asks (optional)
--   timeout  seconds on screen (in total) before it quietly goes (optional)
--   leave    true: counts as seen once the player leaves the screen while it shows
--   anchor   { x, y, w, h } to outline on screen (top-left coordinates, 1600x900), optional; or
--            function(app) -> that, for something that moves
--   at       { x, y } where the tip panel goes, or function(app) -> that
--   seq      a run of tips that belong together ("first_prep"): the panel says which one of how many
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

-- Cards on the board besides the places (the valley map, October 17: a stop's place is a slot too).
local function filled_cards(c)
    local n = 0
    for _, s in ipairs(c.prep and c.prep.scenes or {}) do
        for kind in pairs(s.slots or {}) do
            if kind ~= "location" then
                n = n + 1
            end
        end
    end
    return n
end

-- A stop has a place, and its scene card shows beside the map (no place's card open over it).
local function stop_card_showing(app, c)
    if app.valley and app.valley.open then
        return false
    end
    for _, s in ipairs(c.prep and c.prep.scenes or {}) do
        if s.slots and s.slots.location then
            return true
        end
    end
    return false
end

local LEFT = { 24, 540 }          -- prep: bottom of the chat column
-- The first prep's tips sit over the "Your first prep" checklist, which says the same things, and
-- leave the group chat in view (the newcomer playtest, October 16: six tips, one after another, all
-- over the chat).
-- While the drawer there shows cards to pick, it goes back to the chat column.
local function FIRST(app)
    return app.sel and LEFT or { 364, 676 }
end
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
            text = "Real DMs sketch a campaign before the first game: three truths about the world, where it happens, a second front, two players' stories to feature, who's at the table and your dice. The defaults are fine too.",
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
                return app.s0 ~= nil and require("game.ui.session_zero_view").asks_done(app)
            end,
        },
        {
            id = "s0_rules", screen = "session_zero", at = S0,
            anchor = { 1062, 84, 520, 712 },     -- (down to "When a hero dies": the re-test, cut through a row)
            title = "Table rules",
            text = "The house rules, and everyone has an opinion. When you've answered everything, go on to their backstories (bottom right).",
            done = function(app)
                return app.s0 ~= nil and require("game.ui.session_zero_view").rules_done(app)
            end,
        },

        {
            id = "s0_backstories", screen = "session_zero", at = { 808, 600 },
            when = function(app) return app.s0 ~= nil and app.s0.page == "backstories" end,
            done = function(app)
                -- Gone once you've asked something or written something in.
                for _, ch in pairs(app.s0 and app.s0.backstories or {}) do
                    if ch.hook or #(ch.asked or {}) > 0 then
                        return true
                    end
                end
                return false
            end,
            anchor = { 20, 64, 1086, 68 },
            title = "Their backstories",
            text = "Each player brings their hero's past. Ask what you want to know (six questions, all told), answer their idea, and pick what turns up first. It goes in their Story log, and in your first hand.",
        },

        -- The first prep ----------------------------------------------------------------------
        {
            id = "prep_story", screen = "prep", at = FIRST, seq = "first_prep", leave = true,
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
            text = "This week's story beat. Your notes (the Notes button, or N) say what tonight is for and what to read out. Its story cards are in your hand.",
        },
        -- The valley map (October 17): prep starts on the map.
        {
            id = "prep_map", screen = "prep", at = FIRST, seq = "first_prep",
            when = function(app, c) return week(c, 1) end,
            done = function(app, c)
                local n = 0
                for _, s in ipairs(c.prep and c.prep.scenes or {}) do
                    if s.slots and s.slots.location then
                        n = n + 1
                    end
                end
                return n >= 2
            end,
            anchor = { 360, 80, 544, 480 },
            title = "The valley",
            text = "Every campaign starts at the Kettle: it's stop 1. Click a place to see what's there, then make it stop 2. A green number counts your cards that happen there.",
        },
        {
            id = "prep_types", screen = "prep", at = FIRST, seq = "first_prep",
            -- (Once there's a stop, and its scene card is showing beside the map.)
            when = function(app, c) return week(c, 1) and stop_card_showing(app, c) end,
            anchor = { 916, 80, 264, 82 },
            title = "What kind of scene",
            text = "Pick a type for each stop (the tabs switch stops). Every player loves some types and gets bored in others; the table on the right forecasts it.",
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
            id = "prep_slots", screen = "prep", at = FIRST, seq = "first_prep",
            when = function(app, c) return week(c, 1) and stop_card_showing(app, c) end,
            anchor = { 916, 160, 264, 400 },
            title = "Fill the slots",
            text = "Click a slot, then pick a card below. The faces show who'd love it (green) or not (red); point at a card for the details. Empty slots get improvised.",
            done = function(app, c) return filled_cards(c) >= 2 end,
        },
        {
            id = "prep_table", screen = "prep", at = FIRST, seq = "first_prep", leave = true, timeout = 25,
            when = function(app, c) return week(c, 1) and filled_slots(c) >= 2 end,
            anchor = { 1192, 76, 388, 812 },
            title = "Your players",
            text = "What each one wants, the kinds of scene they love and the ones that bore them, and the forecast for Thursday as the board stands.",
        },
        {
            id = "prep_run", screen = "prep", at = FIRST, seq = "first_prep", leave = true,
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

        -- Later, the first time each feature matters ---------------------------------------------
        {
            id = "prep_messages", screen = "prep", at = MIDDLE,
            when = function(app, c)
                return #(c.open_convos or {}) > 0 and app.chat_tab ~= "messages" and not app.convo
            end,
            done = function(app) return app.chat_tab == "messages" or app.convo ~= nil end,
            anchor = function(app) return { 184, (app.chat_tab_y or 78) - 4, 160, 32 } end,
            title = "Someone messaged you",
            text = "Private messages settle table arguments before they boil over. Each conversation costs a little prep time.",
        },
        {
            id = "prep_story_log", screen = "prep", at = LEFT, timeout = 30, leave = true,
            when = function(app) return app.story_panel ~= nil and not app.convo end,
            done = function(app) return app.story_panel == nil end,
            anchor = { 1186, 68, 408, 826 },
            title = "The Story log",
            text = "A storyline so far, scene by scene, with this week's plans at the end. Point at a lit name for who or what it is. S opens and closes it.",
        },
        -- Week 2 brings what the first prep board left out (the October 13 playtest: week 1 was a
        -- wall), one tip each.
        {
            id = "prep_drawer", screen = "prep", at = { 840, 572 },
            when = function(app, c) return c.week >= 2 and not app.sel and not app.convo end,
            anchor = { 360, 676, 820, 214 },
            title = "New: evenings off",
            text = "Spare prep time? An evening off (a novel, movie night, rereading a backstory) draws fresh cards. Two a week.",
        },
        {
            id = "prep_long_game", screen = "prep", at = LEFT, leave = true, timeout = 30,
            when = function(app, c) return c.week >= 2 and not app.sel and not app.convo end,
            anchor = { 1192, 76, 388, 812 },
            title = "New: the long game",
            text = "Each player now shows Commitment, Trust, Investment and Suspicion. Weeks of low Commitment and they take a break. Talk (2h) is a one-on-one: how their week is going, and a chance to fix things.",
        },
        {
            id = "prep_world", screen = "prep", at = LEFT, leave = true, timeout = 25,
            when = function(app, c)
                return c.week >= 2 and not app.sel and not app.convo and require("game.model.world").pending(c) > 0
            end,
            done = function(app) return app.overlay == "notes" end,
            anchor = { 908, 4, 320, 30 },
            title = "New: the world moves",
            text = "Every faction makes a move off screen each week. Open it (top of the board) to let it happen, bring one on screen as a card, or hold it a week.",
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
