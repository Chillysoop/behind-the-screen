-- The end of the prologue (M7): the table's journey (game/ui/museum_journey_view.lua), then a
-- short playtest survey saved to the playtest log. Three stages: scrapbook (the journey), survey,
-- thanks.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local telemetry = require "game.model.telemetry"
local util = require "game.model.util"
local journey_view = require "game.ui.museum_journey_view"

local M = {}

M.SCALES = {
    { id = "satisfying", text = "Prepping a session was satisfying." },
    { id = "payoff", text = "Watching it play out paid off." },
    { id = "homework", text = "Prep felt like homework." },
    { id = "gut", text = "The players reacted the way my gut said they would." },
}
M.NEXT = { "Yes", "Maybe", "No" }
M.TEXTS = {
    { id = "drag", text = "Where did it drag, or when did you almost stop?" },
    { id = "favourite", text = "What was your favourite moment?" },
}
M.MAX_TEXT = 400

local function state(app)
    app.slice = app.slice or { stage = "scrapbook", answers = { text = { drag = "", favourite = "" } } }
    return app.slice
end

-- The survey ---------------------------------------------------------------------------------

function M.complete(app)
    local a = state(app).answers
    for _, q in ipairs(M.SCALES) do
        if not a[q.id] then
            return false
        end
    end
    return a.next ~= nil
end

function M.save(app)
    local st = state(app)
    if not M.complete(app) then
        return false
    end
    local line = telemetry.slice_survey(app.campaign, st.answers)
    if app.log_line then
        app.log_line(line)
    end
    -- A resumed campaign shouldn't ask again (the save keeps this).
    app.campaign.slice_survey_done = true
    if app.save_campaign then
        app.save_campaign()
    end
    st.saved = true
    st.stage = "thanks"
    st.focus = nil
    app.refresh()
    return true
end

-- Typing into the focused answer box. Only plain characters the fonts can draw.
function M.on_text(app, text)
    local st = state(app)
    if not st.focus or not text then
        return false
    end
    local clean = string.gsub(text, "[^\32-\126]", "")
    local cur = st.answers.text[st.focus]
    st.answers.text[st.focus] = string.sub(cur .. clean, 1, M.MAX_TEXT)
    app.refresh()
    return true
end

function M.on_backspace(app)
    local st = state(app)
    if not st.focus then
        return false
    end
    local cur = st.answers.text[st.focus]
    st.answers.text[st.focus] = string.sub(cur, 1, math.max(0, #cur - 1))
    app.refresh()
    return true
end

function M.typing(app)
    return app.slice ~= nil and app.slice.stage == "survey" and app.slice.focus ~= nil
end

local function survey(app)
    local st = state(app)
    local a = st.answers
    kit.text(24, 14, "HOW DID IT GO?", "title30", theme.gold)
    kit.text(24, 58, "Five quick answers and two short ones. They're saved in the playtest log with your games, "
        .. "for whoever is running the playtest.", "ui18", theme.text)
    local y = 104
    for _, q in ipairs(M.SCALES) do
        kit.box(24, y, 1552, 56, theme.panel, { radius = 8 })
        kit.text(44, y + 16, q.text, "ui18b", theme.text)
        kit.text(880, y + 19, "Not at all", "ui14", theme.dim, { pivot = gui.PIVOT_NE })
        for v = 1, 5 do
            local bx = 896 + (v - 1) * 92
            local on = a[q.id] == v
            kit.button(bx, y + 8, 80, 40, util.int(v), function()
                a[q.id] = v
                app.refresh()
            end, { color = on and theme.go or theme.button, hover = theme.button_hover, key = "q_" .. q.id .. "_" .. v })
        end
        kit.text(1360, y + 19, "Very", "ui14", theme.dim)
        y = y + 64
    end
    kit.box(24, y, 1552, 56, theme.panel, { radius = 8 })
    kit.text(44, y + 16, "Would you play a full campaign after this adventure?", "ui18b", theme.text)
    for k, label in ipairs(M.NEXT) do
        local bx = 896 + (k - 1) * 152
        local on = a.next == label
        kit.button(bx, y + 8, 140, 40, label, function()
            a.next = label
            app.refresh()
        end, { color = on and theme.go or theme.button, hover = theme.button_hover, key = "q_next_" .. k })
    end
    y = y + 76
    for _, t in ipairs(M.TEXTS) do
        local focused = st.focus == t.id
        kit.text(24, y, t.text, "ui18b", theme.text)
        y = y + 28
        if focused then
            kit.box(21, y - 3, 1558, 96, theme.select, { radius = 10 })
        end
        kit.button(24, y, 1552, 90, "", function()
            st.focus = t.id
            app.refresh()
        end, { color = kit.rgba("#f3df8a"), hover = kit.rgba("#f7e6a0"), key = "text_" .. t.id })
        local body = a.text[t.id]
        if body == "" and not focused then
            kit.text(40, y + 12, "Click here and type. Optional.", "ui18", theme.ink_dim)
        else
            kit.text(40, y + 10, body .. (focused and "_" or ""), "ui18", theme.ink, { w = 1520, lines = 3 })
        end
        y = y + 104
    end
    local ready = M.complete(app)
    kit.button(1356, 830, 220, 50, "Save my answers", function()
        M.save(app)
    end, { enabled = ready, color = theme.go, hover = theme.go_hover, key = "save_survey" })
    kit.button(24, 830, 180, 50, "<  Back", function()
        st.stage = "scrapbook"
        st.focus = nil
        app.refresh()
    end, { key = "survey_back" })
    kit.text(1340, 846, ready and "" or "Answer the five quick ones to save.", "ui14", theme.dim, { pivot = gui.PIVOT_NE })
end

local function thanks(app)
    local x, y, w, h = 400, 220, 800, 420
    kit.box(x, y, w, h, theme.panel, { radius = 14 })
    kit.text(x + w / 2, y + 40, "THANK YOU", "title30", theme.gold, { pivot = gui.PIVOT_N })
    kit.text(x + 48, y + 100, "Your answers are saved in the playtest log, next to every week you played:", "ui18", theme.text,
        { w = w - 96 })
    kit.text(x + 48, y + 140, app.log_path or "playtest_log.jsonl", "ui14", theme.teal, { w = w - 96, lines = 2 })
    kit.text(x + 48, y + 196, "If someone gave you this build to test, send them that file. That's the prologue: "
        .. "the full campaign comes next.", "ui18", theme.dim, { w = w - 96 })
    kit.button(x + w / 2 - 170, y + h - 100, 340, 60, "Back to the title", function()
        app.go("intro")
    end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "keep_playing" })
end

function M.build(app)
    local st = state(app)
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    if st.stage == "survey" then
        survey(app)
    elseif st.stage == "thanks" then
        -- (Behind the thanks, the journey again.)
        journey_view.build(app, nil)
        kit.layer("thanks", true)
        kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.55), { round = false })
        thanks(app)
    else
        journey_view.build(app, function()
            st.stage = "survey"
            app.refresh()
        end)
    end
end

return M
