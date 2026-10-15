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
    return math.min(kit.text_height(text, LINE_FONT, W - 2 * PAD - 20), MAX_LINES * kit.line_height(LINE_FONT))
end

-- This week's objective, under the story so far (October 15): the label, then the sentence.
local NEXT_FONT = "ui18b"
local new_h
local function next_h(text)
    return 8 + 20 + math.min(kit.text_height(text, NEXT_FONT, W - 2 * PAD - 20), 3 * kit.line_height(NEXT_FONT)) + 8
end

-- New in the story this week: a line each, under its icon.
local function new_line_h(text)
    return math.min(kit.text_height(text, LINE_FONT, W - 2 * PAD - 20), 2 * kit.line_height(LINE_FONT)) + 4
end

new_h = function(pv)
    local h = 0
    if pv.new and #pv.new > 0 then
        h = 8 + 20
        for _, n in ipairs(pv.new) do
            h = h + new_line_h(n.text)
        end
    end
    -- The key to the other stories' marks, two to a row.
    if pv.legend and #pv.legend > 0 then
        h = h + 8 + 20 + math.ceil(#pv.legend / 2) * 22
    end
    return h
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
    h = h + new_h(pv)
    if pv.next then
        h = h + next_h(pv.next)
    end
    return h + 24 + PAD
end

local function open_log(app, id)
    if id then
        app.storylog_id = id
    end
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
        -- The storyline's icon in front (October 15), the same one it wears on the cards.
        local tx = X + PAD
        if l.id and require("game.ui.lore_marks").storyline(app, l.id, X + PAD - 2, ty + 1, 16) then
            tx = X + PAD + 20
        end
        kit.text(tx, ty, l.text, LINE_FONT, col, { w = W - PAD - (tx - X), lines = MAX_LINES })
        ty = ty + lh + 6
    end
    if pv.new and #pv.new > 0 then
        -- New in the story this week: a line each, under its icon (and a click opens its log).
        kit.box(X + PAD, ty + 2, W - 2 * PAD, 1, theme.panel3, { round = false })
        ty = ty + 8
        kit.text(X + PAD, ty, "NEW IN THE STORY", LINE_FONT, theme.gold)
        ty = ty + 20
        local marks = require "game.ui.lore_marks"
        for i, n in ipairs(pv.new) do
            local lh = new_line_h(n.text)
            kit.button(X + 4, ty - 2, W - 8, lh, "", function()
                open_log(app, n.id)
            end, { color = kit.rgba("#000000", 0), hover = theme.button_hover, key = "prev_new_" .. i })
            marks.storyline(app, n.id, X + PAD - 2, ty + 1, 16)
            kit.text(X + PAD + 20, ty, n.text, LINE_FONT, theme.text, { w = W - 2 * PAD - 20, lines = 2 })
            ty = ty + lh
        end
    end
    if pv.legend and #pv.legend > 0 then
        kit.box(X + PAD, ty + 2, W - 2 * PAD, 1, theme.panel3, { round = false })
        ty = ty + 8
        kit.text(X + PAD, ty, "ALSO IN YOUR HAND", LINE_FONT, theme.gold)
        ty = ty + 20
        local marks = require "game.ui.lore_marks"
        local cw = (W - 2 * PAD) / 2
        for i, n in ipairs(pv.legend) do
            local cx = X + PAD + ((i - 1) % 2) * cw
            local cy = ty + math.floor((i - 1) / 2) * 22
            kit.button(cx - 4, cy - 2, cw - 4, 20, "", function()
                open_log(app, n.id)
            end, { color = kit.rgba("#000000", 0), hover = theme.button_hover, key = "prev_legend_" .. i })
            marks.storyline(app, n.id, cx - 2, cy, 16)
            kit.text(cx + 18, cy, n.text, LINE_FONT, theme.text, { w = cw - 26, lines = 1 })
        end
        ty = ty + math.ceil(#pv.legend / 2) * 22
    end
    if pv.next then
        -- What they're out to do this week, under the main story's icon.
        local ld = require("game.model.content").lore.briefing
        kit.box(X + PAD, ty + 2, W - 2 * PAD, 1, theme.panel3, { round = false })
        ty = ty + 8
        local marks = require "game.ui.lore_marks"
        marks.storyline(app, ld.next_story, X + PAD - 2, ty, 16)
        kit.text(X + PAD + 20, ty, ld.next, LINE_FONT, theme.gold)
        ty = ty + 20
        kit.text(X + PAD + 20, ty, pv.next, NEXT_FONT, theme.text, { w = W - 2 * PAD - 20, lines = 3 })
        ty = ty + next_h(pv.next) - 28
    end
    local link = "Read it all in the Story log  >"
    kit.button(X + PAD - 4, ty, kit.width(link, LINE_FONT) + 8, 22, "", function()
        open_log(app, pv.open)
    end, { color = kit.rgba("#000000", 0), hover = theme.button_hover, key = "prev_log" })
    kit.text(X + PAD, ty + 2, link, LINE_FONT, theme.teal)
    return h
end

return M
