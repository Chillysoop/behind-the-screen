-- Session Zero (M6): before week 1 the table talks it through. Pitch a tone, hear
-- each player's ask, set the table rules. People say what they think, so their
-- reactions are shown plainly. Rebuilt from scratch on every click. Then (October 13)
-- their backstories, on a page of their own (game/ui/backstory_view.lua).

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local panels = require "game.ui.panels"
local content = require "game.model.content"
local social = require "game.model.social"

local M = {}

local KIND = { line = "A line", veil = "A veil", promise = "A promise" }
local KIND_ABOUT = {
    line = "A line: it never happens in the game.",
    veil = "A veil: it can happen, but off screen.",
    promise = "A promise about how you'll run things.",
}

local function choices(app)
    app.s0 = app.s0 or { tone = nil, asks = {}, rules = {} }
    return app.s0
end

-- Ready when every question has an answer.
function M.complete(app)
    local c = choices(app)
    if not c.tone then
        return false
    end
    for _, key in ipairs(content.session_zero.asks.order) do
        if not c.asks[key] then
            return false
        end
    end
    for _, rk in ipairs(content.session_zero.rules.order) do
        if not c.rules[rk] then
            return false
        end
    end
    return true
end

-- On to their backstories (October 13), then week 1.
function M.start(app)
    if not M.complete(app) then
        return false
    end
    local backstory_view = require "game.ui.backstory_view"
    if app.s0.page ~= "backstories" then
        app.s0.page = "backstories"
        app.refresh()
        return true
    end
    return backstory_view.start(app)
end

local function like_color(v)
    if v > 0 then
        return theme.green
    elseif v < 0 then
        return theme.orange
    end
    return theme.faint
end

-- Little name chips: who likes this option, who doesn't.
local function chips(x, y, like, max_w)
    local cx = x
    for _, key in ipairs(content.players.order) do
        local v = like[key] or 0
        if v ~= 0 then
            local name = content.players[key].name
            local label = name .. (v > 0 and " +" or " -")
            if v >= 2 or v <= -2 then
                label = label .. (v > 0 and "+" or "-")
            end
            local w = kit.width(label, "ui14") + 14
            if cx + w > x + max_w then
                return
            end
            kit.box(cx, y, w, 20, like_color(v), { radius = 6 })
            kit.text(cx + 7, y + 1, label, "ui14", theme.ink)
            cx = cx + w + 6
        end
    end
end

local function pitch(app, c)
    local s0 = content.session_zero
    local x, w = 24, 500
    kit.text(x, 84, "THE PITCH", "ui14", theme.dim)
    kit.text(x + 96, 84, "What should this campaign feel like?", "ui14", theme.faint)
    local y = 108
    for _, key in ipairs(s0.tones.order) do
        local t = s0.tones[key]
        local chosen = c.tone == key
        if chosen then
            kit.box(x - 3, y - 3, w + 6, 70, theme.select, { radius = 10 })
        end
        kit.button(x, y, w, 64, "", function()
            c.tone = key
            app.refresh()
        end, { color = chosen and theme.panel3 or theme.panel2, hover = theme.button_hover })
        kit.text(x + 14, y + 8, t.name, "ui18b", theme.text)
        kit.text(x + 14, y + 34, t.blurb, "ui14", theme.dim, { w = w - 28, lines = 1 })
        y = y + 74
    end
    -- What everyone says about the pitch.
    kit.text(x, y + 8, "AROUND THE TABLE", "ui14", theme.dim)
    -- The style the planner picked (A18), and who's keen.
    do
        local styles = require "game.model.styles"
        local sid = styles.current(app.campaign)
        local sd = styles.def(sid)
        if sd then
            local keen, unsure = {}, {}
            for _, p in ipairs(app.campaign.players) do
                local f = styles.fit(p, sid)
                if f >= 1 then
                    table.insert(keen, p.name)
                elseif f < 0 then
                    table.insert(unsure, p.name)
                end
            end
            local line = sd.name .. (#keen > 0 and (". Keen: " .. table.concat(keen, ", ")) or "")
                .. (#unsure > 0 and (". Not sold: " .. table.concat(unsure, ", ")) or "") .. "."
            kit.text(x + 160, y + 8, kit.ellipsize(line, "ui14", w - 160), "ui14", theme.faint)
        end
    end
    y = y + 32
    local t = c.tone and s0.tones[c.tone]
    -- The party (A8): who they are and how they know each other.
    local function party(py)
        kit.text(x, py, "THE PARTY", "ui14", theme.dim)
        py = py + 22
        for _, key in ipairs(content.players.order) do
            local d = content.players[key]
            kit.dot(x + 18, py + 18, 36, panels.COLORS[key] or theme.panel3)
            kit.picture(x + 2, py + 2, 32, 32, panels.face(key))
            kit.text(x + 44, py, d.char .. ", " .. string.lower(d.class_name) .. "  (" .. d.name .. ")", "ui18b", theme.text)
            kit.text(x + 44, py + 21, d.intro or d.notes, "ui14", theme.dim, { w = w - 50, lines = 2 })
            py = py + 62
        end
    end
    if not t then
        kit.text(x, y, "Pitch a tone and see how it lands.", "ui18", theme.faint)
        party(y + 40)
        return
    end
    for _, key in ipairs(content.players.order) do
        local v = t.like[key] or 0
        kit.dot(x + 8, y + 10, 12, like_color(v))
        kit.text(x + 22, y, content.players[key].name, "ui18b", theme.text)
        local said = '"' .. (t.says[key] or "") .. '"'
        kit.text(x + 92, y + 2, said, "ui14", theme.text, { w = w - 96, lines = 2 })
        y = y + math.max(26, kit.text_height(said, "ui14", w - 96)) + 12
    end
    party(y + 8)
end

local function asks(app, c)
    local s0 = content.session_zero
    local x, w = 548, 500
    kit.text(x, 84, "LINES, VEILS AND ASKS", "ui14", theme.dim)
    local y = 108
    for _, key in ipairs(s0.asks.order) do
        local a = s0.asks[key]
        local answer = c.asks[key]
        local h = 168
        kit.box(x, y, w, h, theme.panel, { radius = 10 })
        kit.text(x + 14, y + 10, content.players[key].name, "ui18b", theme.text)
        local kind = KIND[a.kind]
        local kw = kit.width(kind, "ui14") + 16
        kit.box(x + w - 14 - kw, y + 10, kw, 22, a.kind == "promise" and theme.purple or theme.teal, { radius = 6 })
        kit.text(x + w - 14 - kw + 8, y + 12, kind, "ui14", theme.ink)
        kit.text(x + 14, y + 36, '"' .. a.text .. '"', "ui18", theme.text, { w = w - 28, lines = 2 })
        local by = y + 86
        local bw = (w - 38) / 2
        for i, which in ipairs({ "agree", "push" }) do
            local o = a[which]
            local chosen = answer == which
            local bx = x + 14 + (i - 1) * (bw + 10)
            if chosen then
                kit.box(bx - 3, by - 3, bw + 6, 46, theme.select, { radius = 9 })
            end
            kit.button(bx, by, bw, 40, o.label, function()
                c.asks[key] = which
                app.refresh()
            end, { font = "ui14", color = chosen and theme.panel3 or theme.button })
        end
        if answer then
            local o = a[answer]
            kit.text(x + 14, y + 136, '"' .. o.reply .. '"', "ui14", like_color(o.like), { w = w - 28, lines = 1 })
        else
            kit.text(x + 14, y + 136, KIND_ABOUT[a.kind], "ui14", theme.faint, { w = w - 28, lines = 1 })
        end
        y = y + h + 8
    end
end

local function rules(app, c)
    local s0 = content.session_zero
    local x, w = 1072, 504
    kit.text(x, 84, "TABLE RULES", "ui14", theme.dim)
    local y = 108
    for _, rk in ipairs(s0.rules.order) do
        local r = s0.rules[rk]
        -- (Four rules with the table clock's length, A14: rows are compact to fit above the button.)
        kit.text(x, y, r.name, "ui18b", theme.text)
        if r.compact then
            -- When a hero dies (B3): the options side by side, the about line saved for the chosen one.
            local cur = c.rules[rk] and r[c.rules[rk]]
            kit.text(x + kit.width(r.name, "ui18b") + 10, y + 3, cur and cur.about or r.about, "ui14", theme.dim,
                { w = w - kit.width(r.name, "ui18b") - 10, lines = 1 })
            y = y + 24
            local bw = (w - 3 * 6) / #r.order
            for i, ok in ipairs(r.order) do
                local o = r[ok]
                local chosen = c.rules[rk] == ok
                local bx = x + (i - 1) * (bw + 6)
                if chosen then
                    kit.box(bx - 3, y - 3, bw + 6, 36, theme.select, { radius = 9 })
                end
                kit.button(bx, y, bw, 30, o.name, function()
                    c.rules[rk] = ok
                    app.refresh()
                end, { font = "ui14", color = chosen and theme.panel3 or theme.panel2, hover = theme.button_hover,
                       key = "rule_" .. rk .. "_" .. ok })
            end
            y = y + 34
        else
        kit.text(x, y + 21, r.about, "ui14", theme.dim, { w = w, lines = 1 })
        y = y + 42
        for _, ok in ipairs(r.order) do
            local o = r[ok]
            local chosen = c.rules[rk] == ok
            if chosen then
                kit.box(x - 3, y - 3, w + 6, 36, theme.select, { radius = 9 })
            end
            kit.button(x, y, w, 30, "", function()
                c.rules[rk] = ok
                app.refresh()
            end, { color = chosen and theme.panel3 or theme.panel2, hover = theme.button_hover, key = "rule_" .. rk .. "_" .. ok })
            kit.text(x + 12, y + 5, o.name, "ui18", theme.text, { w = 250, lines = 1 })
            chips(x + 262, y + 5, o.like, w - 270)
            y = y + 34
        end
        end
        -- What people said about the chosen option: whoever feels most strongly about it.
        local o = c.rules[rk] and r[c.rules[rk]]
        local said, strongest
        for _, key in ipairs(content.players.order) do
            if o and o.says and o.says[key] then
                local v = math.abs((o.like or {})[key] or 0)
                if not strongest or v > strongest then
                    strongest = v
                    said = content.players[key].name .. ': "' .. o.says[key] .. '"'
                end
            end
        end
        kit.text(x, y, said or " ", "ui14", theme.dim, { w = w, lines = 1 })
        y = y + 22
    end
    return y
end

-- How everyone's feeling about the whole package.
local function feelings(app, c, y)
    local x, w = 548, 500     -- under the asks (the rules column runs down to the Start button)
    kit.text(x, y, "HOW EVERYONE FEELS", "ui14", theme.dim)
    -- What the words mean (A8).
    kit.text(x + w, y, "Heard > Happy > Okay > Uneasy", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    y = y + 22
    local full = { tone = c.tone or "mixed", asks = c.asks, rules = c.rules }
    local f = social.feelings(full)
    for i, key in ipairs(content.players.order) do
        local v = f[key] or 0
        local bx = x + ((i - 1) % 2) * (w / 2)
        local by = y + math.floor((i - 1) / 2) * 26
        kit.text(bx, by, content.players[key].name, "ui18b", theme.text)
        local word = v >= 3 and "Heard" or (v >= 1 and "Happy" or (v >= -1 and "Okay" or "Uneasy"))
        kit.text(bx + 70, by + 2, word, "ui18", like_color(v >= 1 and 1 or (v <= -2 and -1 or 0)))
    end
end

function M.build(app)
    local c = choices(app)
    if c.page == "backstories" then
        return require("game.ui.backstory_view").build(app)
    end
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    kit.text(24, 14, "SESSION ZERO", "title30", theme.gold)
    kit.text(280, 24, "Before week 1, everyone talks it through: how it should feel, what's off the table, how you'll run it.",
        "ui18", theme.dim)
    pitch(app, c)
    asks(app, c)
    rules(app, c)
    feelings(app, c, 108 + 4 * 176)
    local ready = M.complete(app)
    kit.button(1356, 830, 220, 50, "Backstories  >", function()
        M.start(app)
    end, { enabled = ready, color = theme.go, hover = theme.go_hover, font = "ui22b", key = "s0_next" })
    -- (Short, so it clears how everyone feels, on the left.)
    kit.text(1340, 846, ready and "Next: their backstories." or "Pitch a tone, answer every ask and set the table rules.", "ui14", theme.dim,
        { pivot = gui.PIVOT_NE })
end

return M
