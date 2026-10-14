-- "Previously on", at the top of the prep board's left column (playtest, October 13: the veteran
-- needed 14 actions to say what the story was so far, and the newcomer never found it). Last
-- session a line a scene, in the Story log's shorthand; in week 1, what Session Zero wrote into
-- each hero's past. Click a line for that storyline's log; Hide folds it to one line for the week.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local chronicle = require "game.model.chronicle"

local M = {}

local X, W = 24, 320
local PAD = 12
local LINE_FONT = "ui14"
local MAX_LINES = 3          -- a scene's line wraps to at most this many lines

local function data(app)
    return chronicle.previously(app.campaign)
end

local function folded(app)
    return app.prev_folded == app.campaign.week
end

local function line_h(text)
    return math.min(kit.text_height(text, LINE_FONT, W - 2 * PAD), MAX_LINES * kit.line_height(LINE_FONT))
end

-- How tall it draws (0 when there's nothing to show).
function M.height(app, pv)
    pv = pv or data(app)
    if not pv then
        return 0
    end
    if folded(app) then
        return 30
    end
    local h = PAD + 20 + 4
    if pv.sub then
        h = h + math.min(kit.text_height(pv.sub, LINE_FONT, W - 2 * PAD), 2 * kit.line_height(LINE_FONT)) + 6
    end
    for _, l in ipairs(pv.lines) do
        h = h + line_h(l.text) + 6
    end
    return h + 24 + PAD
end

local function open_log(app, id)
    if not id then
        return
    end
    app.storylog_id = id
    app.storylog_scroll = nil
    if app.open_notes then
        app.open_notes("storylog")
    end
end

-- Draws it at y; returns the height used.
function M.draw(app, y)
    local pv = data(app)
    if not pv then
        return 0
    end
    local h = M.height(app, pv)
    if folded(app) then
        kit.button(X, y, W, h, "", function()
            app.prev_folded = nil
            app.refresh()
        end, { color = theme.panel2, hover = theme.button_hover, key = "prev_show" })
        kit.text(X + PAD, y + 6, pv.label or pv.title, LINE_FONT, theme.gold, { w = W - 2 * PAD - 40, lines = 1 })
        kit.text(X + W - PAD, y + 6, "Show", LINE_FONT, theme.dim, { pivot = gui.PIVOT_NE })
        return h
    end
    kit.box(X, y, W, h, theme.panel2, { radius = 8 })
    kit.box(X, y, 4, h, theme.gold, { round = false })
    kit.text(X + PAD, y + PAD - 2, pv.title, "ui14", theme.gold)
    kit.button(X + W - 58, y + 6, 50, 22, "Hide", function()
        app.prev_folded = app.campaign.week
        app.refresh()
    end, { font = "ui14", color = theme.panel3, key = "prev_hide" })
    local ty = y + PAD + 20 + 4
    if pv.sub then
        kit.text(X + PAD, ty, pv.sub, LINE_FONT, theme.dim, { w = W - 2 * PAD, lines = 2 })
        ty = ty + math.min(kit.text_height(pv.sub, LINE_FONT, W - 2 * PAD), 2 * kit.line_height(LINE_FONT)) + 6
    end
    for i, l in ipairs(pv.lines) do
        local lh = line_h(l.text)
        -- Each line opens its storyline's log.
        kit.button(X + 4, ty - 2, W - 8, lh + 4, "", function()
            open_log(app, l.id or pv.open)
        end, { color = kit.rgba("#000000", 0), hover = theme.button_hover, key = "prev_line_" .. i })
        local col = (l.out == "lose") and theme.orange or theme.text
        kit.text(X + PAD, ty, l.text, LINE_FONT, col, { w = W - 2 * PAD, lines = MAX_LINES })
        ty = ty + lh + 6
    end
    local link = "Read it all in the Story log  >"
    kit.button(X + PAD - 4, ty, kit.width(link, LINE_FONT) + 8, 22, "", function()
        open_log(app, pv.open)
    end, { color = kit.rgba("#000000", 0), hover = theme.button_hover, key = "prev_log" })
    kit.text(X + PAD, ty + 2, link, LINE_FONT, theme.teal)
    return h
end

return M
