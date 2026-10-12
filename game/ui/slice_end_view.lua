-- The end of the slice (M7): a scrapbook of the first four sessions, then a short
-- playtest survey saved to the playtest log. Three stages: scrapbook, survey, thanks.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local content = require "game.model.content"
local subclasses = require "game.rules.subclasses"
local telemetry = require "game.model.telemetry"
local util = require "game.model.util"

local M = {}

M.SCALES = {
    { id = "satisfying", text = "Writing a session was satisfying." },
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

local TIER_COLOR = { loved = "green", fun = "teal", fine = "gold", bored = "orange", out = "red" }

local function state(app)
    app.slice = app.slice or { stage = "scrapbook", answers = { text = { drag = "", favourite = "" } } }
    return app.slice
end

-- Will they be back for session 5? From where Commitment ended up.
function M.verdict(p)
    if p.on_break then
        return "On a break", theme.orange
    elseif p.commitment >= 75 then
        return "Can't wait for session 5", theme.green
    elseif p.commitment >= 55 then
        return "Coming back", theme.teal
    elseif p.commitment >= 35 then
        return "On the fence", theme.gold
    end
    return "Drifting away", theme.orange
end

-- Their best night's quote: the week they had the most fun, as long as it fits the note (three
-- handwritten lines); otherwise the next best that does. A quote never gets cut off.
local QUOTE_LINES = 3
local function best_quote(app, key, width)
    local rows = {}
    for _, e in ipairs(app.campaign.journal) do
        local row = e.players[key]
        if row and row.present and row.quote then
            table.insert(rows, row)
        end
    end
    table.sort(rows, function(a, b) return (a.fun or 0) > (b.fun or 0) end)
    local line_h = kit.text_height("Ag", "hand24", width)
    for _, row in ipairs(rows) do
        if kit.text_height(row.quote, "hand24", width) <= line_h * QUOTE_LINES + 2 then
            return row.quote, "hand24"
        end
    end
    -- None fits in hand: the best one in a smaller hand.
    return rows[1] and rows[1].quote, "ui18"
end

local function player_column(app, p, i)
    local c = app.campaign
    local x, y, w, h = 24 + (i - 1) * 392, 96, 376, 468
    kit.box(x, y, w, h, theme.panel, { radius = 10 })
    kit.text(x + 16, y + 12, p.name, "ui22b", theme.text)
    kit.text(x + 16 + kit.width(p.name, "ui22b") + 10, y + 16, p.char .. ", " .. p.class_name, "ui18", theme.dim)
    local sub = c.subclasses and c.subclasses[p.class]
    local level = "Level " .. util.int(c.level) .. (sub and (" " .. subclasses.list[sub].name) or "")
    kit.text(x + 16, y + 44, level, "ui18b", theme.gold)
    -- The table's award for them (M9's awards, in the slice): a rosette, the title, and why.
    local award = app.awards and app.awards[p.key]
    if award then
        local rx, ry = x + 27, y + 82
        kit.box(rx - 8, ry + 4, 6, 16, theme.red, { radius = 2 })
        kit.box(rx + 2, ry + 4, 6, 16, theme.red, { radius = 2 })
        kit.dot(rx, ry, 24, theme.gold)
        kit.dot(rx, ry, 12, kit.rgba("#b8862e"))
        kit.text(x + 48, y + 70, award.title, "ui18b", theme.gold, { w = w - 64, lines = 1 })
        kit.text(x + 48, y + 94, award.reason, "ui14", theme.dim, { w = w - 64, lines = 2 })
    end
    -- A bar per session: how much fun they had.
    kit.text(x + 16, y + 136, "EACH SESSION", "ui14", theme.dim)
    local bw, gap, base, bh = 64, 18, y + 216, 60
    for k, e in ipairs(c.journal) do
        if k > 4 then
            break
        end
        local bx = x + 16 + (k - 1) * (bw + gap)
        local row = e.players[p.key]
        kit.box(bx, base - bh, bw, bh, kit.rgba("#000000", 0.25), { radius = 4 })
        if row and row.present and row.fun then
            local hgt = math.max(4, row.fun / 100 * bh)
            kit.box(bx, base - hgt, bw, hgt, theme[TIER_COLOR[row.tier] or "dim"], { radius = 4 })
        else
            kit.text(bx + bw / 2, base - bh / 2, row and row.on_break and "break" or "away", "ui14", theme.faint,
                { pivot = gui.PIVOT_CENTER })
        end
        kit.text(bx + bw / 2, base + 4, "S" .. util.int(k), "ui14", theme.faint, { pivot = gui.PIVOT_N })
    end
    local text, color = M.verdict(p)
    kit.text(x + 16, y + 246, "SESSION 5?", "ui14", theme.dim)
    kit.text(x + 16, y + 264, text, "ui22b", color)
    local quote, font = best_quote(app, p.key, w - 64)
    local qy = y + 302
    if quote then
        local qh = math.max(70, 24 + kit.text_height(quote, font, w - 64))
        kit.box(x + 16, qy, w - 32, qh, kit.rgba("#f3df8a"), { radius = 4 })
        kit.text(x + 32, qy + 12, quote, font, theme.ink, { w = w - 64 })
        qy = qy + qh + 14
    end
    -- Their backstory, and how often it came up.
    local scenes = p.thread_progress or 0
    local thread = util.capitalize(p.thread) .. ": " .. (scenes == 0 and "never came up yet."
        or (scenes == 1 and "came up once." or ("came up " .. util.int(scenes) .. " times.")))
    kit.text(x + 16, qy, thread, "ui14", scenes == 0 and theme.orange or theme.dim, { w = w - 32, lines = 2 })
end

local function scrapbook(app)
    local c = app.campaign
    local arc = content.arc
    -- The table awards: picked once, when the scrapbook first opens.
    if not app.awards then
        app.awards = require("game.model.awards").pick(c)
    end
    kit.text(24, 14, "THE FIRST FOUR THURSDAYS", "title30", theme.gold)
    kit.text(24, 58, arc.name .. ", sessions 1 to " .. util.int(arc.SESSIONS) .. ". Session 5 is next Thursday.", "ui18",
        theme.text)
    for i, p in ipairs(c.players) do
        player_column(app, p, i)
    end
    -- What the chapter left behind.
    local y = 578
    kit.box(24, y, 1160, 308, theme.panel, { radius = 10 })
    kit.text(40, y + 12, "BEST MOMENTS", "ui14", theme.dim)
    local my = y + 34
    local shown = 0
    -- What the DM pinned on each report comes first (B7); otherwise the recap's first kept beats.
    local recap_mod = require "game.model.recap"
    local by_week = {}
    for _, le in ipairs(c.session_log or {}) do
        by_week[le.week] = le
    end
    for _, e in ipairs(c.journal) do
        local le = by_week[e.week]
        local list, pinned = {}, {}
        for _, b in ipairs(le and recap_mod.kept(le.recap) or {}) do
            if b.pinned then
                table.insert(pinned, { b.text, theme.gold })
            elseif b.kind ~= "start" then
                table.insert(list, { b.text, theme.text })
            end
        end
        if #pinned > 0 then
            list = pinned
        elseif not le then
            for _, m in ipairs(e.moments) do
                table.insert(list, { m, theme.text })
            end
        end
        for k, m in ipairs(list) do
            if k <= 2 and shown < 6 then
                local line = "S" .. util.int(e.week) .. "  " .. m[1]
                local lh = math.min(kit.text_height(line, "ui18", 520), 50)
                kit.text(40, my, line, "ui18", m[2], { w = 520, lines = 2 })
                my = my + lh + 8
                shown = shown + 1
            end
        end
    end
    if shown == 0 then
        kit.text(40, my, "Quiet nights. Nothing anyone will bring up later.", "ui18", theme.faint)
    end
    kit.text(600, y + 12, "WHAT CHANGED", "ui14", theme.dim)
    local lines = {}
    local fixes, payoffs, canon, story = {}, {}, 0, 0
    for _, e in ipairs(c.journal) do
        for _, id in ipairs(e.fixes) do
            table.insert(fixes, content.conflicts[id].name)
        end
        for _, id in ipairs(e.payoffs) do
            table.insert(payoffs, content.seeds[id].name)
        end
        canon = canon + #e.canon
        story = story + (e.story > 0 and 1 or 0)
    end
    table.insert(lines, util.int(story) .. " of " .. util.int(#c.journal) .. " sessions moved the story along.")
    -- The storylines (game/model/storylines.lua): what's still running into session 5, what was
    -- tied off, and the loose ends the table noticed (they can still come back).
    do
        local storylines = require "game.model.storylines"
        local going, loose, tied = {}, {}, {}
        local function nm(d)
            return d.kind == "backstory" and (d.short .. "'s story") or util.lower_first(d.short)
        end
        local all = storylines.get(c)
        for _, d in ipairs(storylines.defs(c)) do
            local st = all[d.id]
            if st and st.state == "open" then
                table.insert(st.loose and loose or going, nm(d))
            elseif st and st.state == "resolved" then
                table.insert(tied, nm(d))
            end
        end
        if #going > 0 then
            table.insert(lines, "Into session 5: " .. util.join_names(going) .. ".")
        end
        if #tied > 0 then
            table.insert(lines, "Tied off: " .. util.join_names(tied) .. ".")
        end
        table.insert(lines, #loose > 0 and ("Loose ends: " .. util.join_names(loose) .. ". They can still come back.")
            or "No loose ends. Every thread you opened is still alive.")
    end
    if #c.levelups > 0 then
        table.insert(lines, "The party reached level " .. util.int(c.level) .. ".")
    else
        table.insert(lines, "The party never levelled up.")
    end
    table.insert(lines, #payoffs > 0 and ("Paid off: " .. table.concat(payoffs, ", ") .. ".") or "No seeds paid off.")
    if #fixes > 0 then
        table.insert(lines, "Settled: " .. table.concat(fixes, ", ") .. ".")
    end
    for _, id in ipairs(content.conflicts.order) do
        local cf = c.conflicts[id]
        if cf.state == "brewing" or cf.state == "active" then
            table.insert(lines, "Still simmering: " .. content.conflicts[id].name .. ".")
        end
    end
    table.insert(lines, util.int(canon) .. " things you made up became canon.")
    local last = c.journal[#c.journal]
    if last and last.chapter then
        table.insert(lines, content.arc.finale[last.chapter])
    end
    local ly = y + 34
    for _, l in ipairs(lines) do
        if ly < y + 290 then
            kit.text(600, ly, l, "ui18", theme.text, { w = 560, lines = 2 })
            ly = ly + kit.text_height(l, "ui18", 560) + 6
        end
    end
    local st = state(app)
    if st.saved then
        kit.button(1204, 760, 372, 64, "Keep playing  >", function()
            app.go("prep")
        end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "keep_playing" })
    else
        kit.button(1204, 760, 372, 64, "Tell us how it went  >", function()
            st.stage = "survey"
            app.refresh()
        end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "to_survey" })
        kit.text(1390, 836, "Two minutes. It helps more than anything.", "ui14", theme.faint, { pivot = gui.PIVOT_N })
    end
    kit.text(1204, 596, "You ran Session Zero and four game nights.", "ui18", theme.text, { w = 372 })
    kit.text(1204, 652, "The arc runs for twenty sessions. This was the first act.", "ui14", theme.dim, { w = 372 })
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
    kit.text(44, y + 16, "Would you play session 5?", "ui18b", theme.text)
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
    kit.text(x + 48, y + 196, "If someone gave you this build to test, send them that file. You can keep playing: the "
        .. "story goes on past the slice, though it's rougher out there.", "ui18", theme.dim, { w = w - 96 })
    kit.button(x + w / 2 - 170, y + h - 100, 340, 60, "Keep playing  >", function()
        app.go("prep")
    end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "keep_playing" })
end

function M.build(app)
    local st = state(app)
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    if st.stage == "survey" then
        survey(app)
    elseif st.stage == "thanks" then
        scrapbook(app)
        kit.layer("thanks", true)
        kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.55), { round = false })
        thanks(app)
    else
        scrapbook(app)
    end
end

return M
