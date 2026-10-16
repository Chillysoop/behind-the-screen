-- Rules words, explained where they stand (the newcomer playtest, October 16): on the screens
-- that turn it on, every D&D term in the text gets a faint underline, and pointing at it brings
-- up a small card with the plain word, what it means at the table, and what D&D calls it. The
-- words are game/data/rules_glossary.lua's. A word's hover never takes a click away from the
-- button it sits on (kit.spot).
--
-- Turning it on: kit.gloss_scope({ fight = true }, function() ...draw... end), or opts.gloss on
-- a single kit.text. Custom cards for things that aren't words in a text (the top bar's
-- counters): M.card_spot(x, y, w, h, title, text).

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local data = require "game.data.rules_glossary"

local M = {}

M.MAX_PER_TEXT = 4      -- underlines in one piece of text, at most
M.W = 340               -- the card's width

M.by_id = {}
for _, t in ipairs(data) do
    M.by_id[t.id] = t
end

local function applies(t, tags)
    if not t.tags then
        return true
    end
    if tags == true then
        return true
    end
    for _, k in ipairs(t.tags) do
        if tags[k] then
            return true
        end
    end
    return false
end

-- The terms in one line of text: { { s, e, term } }, at most one per term, never overlapping.
function M.find(line, tags, used, out, limit)
    out = out or {}
    used = used or {}
    for _, t in ipairs(data) do
        if #out >= limit then
            break
        end
        if not used[t.id] and applies(t, tags) then
            for _, p in ipairs(t.match) do
                local s, e = string.find(line, p)
                if s then
                    -- Trim a pattern's edges that aren't the word itself.
                    while e > s and string.find(string.sub(line, e, e), "[%s%p]") and not string.find(string.sub(line, e, e), "[%+%-/!]") do
                        e = e - 1
                    end
                    local clash = false
                    for _, o in ipairs(out) do
                        if s <= o[2] and o[1] <= e then
                            clash = true
                            break
                        end
                    end
                    if not clash then
                        table.insert(out, { s, e, t })
                        used[t.id] = true
                    end
                    break
                end
            end
        end
    end
    return out
end

-- The card ------------------------------------------------------------------------------------

function M.hide()
    local l = M.layer
    if l then
        -- Dropping a layer makes the top one current; whatever was being drawn into stays current.
        local before = kit.current
        M.layer = nil
        kit.drop(l)
        if before and before ~= l then
            kit.current = before
        end
    end
end

-- Show a card near a rectangle (top-left coordinates): below it when there's room, else above.
function M.show(title, text, dnd, rx, ry, rw, rh)
    M.hide()
    local w = M.W
    local th = kit.text_height(text, "ui18", w - 28)
    local h = 14 + 26 + th + (dnd and 26 or 0) + 12
    local x = math.max(8, math.min(kit.W - w - 8, rx + rw / 2 - w / 2))
    local y = ry + rh + 8
    if y + h > kit.H - 8 then
        y = ry - h - 8
    end
    y = math.max(8, y)
    local l = kit.layer("gloss_card", false, true)
    M.layer = l
    kit.into(l, function()
        kit.box(x - 2, y - 2, w + 4, h + 4, kit.rgba("#7fb7a8", 0.85), { radius = 11 })
        kit.box(x, y, w, h, kit.rgba("#1d1612", 0.98), { radius = 10 })
        kit.text(x + 14, y + 12, title, "ui18b", theme.gold, { w = w - 28, lines = 1, gloss = false })
        kit.text(x + 14, y + 40, text, "ui18", theme.text, { w = w - 28, gloss = false })
        if dnd then
            kit.text(x + 14, y + 40 + th + 6, "In D&D: " .. dnd, "ui14", theme.dim, { w = w - 28, lines = 1, gloss = false })
        end
    end)
end

-- Every frame: the card stays above whatever was drawn since (the log redraws under it as lines
-- come in; the newcomer playtest, October 16: a card under the log's text).
function M.raise()
    local l = M.layer
    if l and gui.move_above then
        for _, n in ipairs(l.nodes) do
            pcall(gui.move_above, n, nil)
        end
    end
end

-- The underlines --------------------------------------------------------------------------------

local function split(str)
    local out = {}
    for line in string.gmatch(str .. "\n", "(.-)\n") do
        table.insert(out, line)
    end
    return out
end

-- Where each line of a text node starts (x) and its top (y), for the pivot it was drawn with.
local function line_x(x, lw, pivot)
    if pivot == gui.PIVOT_N or pivot == gui.PIVOT_CENTER or pivot == gui.PIVOT_S then
        return x - lw / 2
    elseif pivot == gui.PIVOT_NE or pivot == gui.PIVOT_E or pivot == gui.PIVOT_SE then
        return x - lw
    end
    return x
end

local function top_y(y, h, pivot)
    if pivot == gui.PIVOT_CENTER or pivot == gui.PIVOT_W or pivot == gui.PIVOT_E then
        return y - h / 2
    elseif pivot == gui.PIVOT_S or pivot == gui.PIVOT_SW or pivot == gui.PIVOT_SE then
        return y - h
    end
    return y
end

-- kit.text's hook: underline the terms in the text it's about to draw, each with a hover spot.
function M.hook(x, y, str, font, color, pivot, tags)
    if M.off then
        return
    end
    local lines = split(str)
    local lh = kit.line_height(font)
    local top = top_y(y, #lines * lh, pivot)
    local used, n = {}, 0
    -- A word is underlined the first time it shows on a layer; after that it still explains itself
    -- on hover, without lining every card on the screen (a roster of twelve monsters).
    local layer = kit.current
    layer.gloss_seen = layer.gloss_seen or {}
    for i, line in ipairs(lines) do
        if n >= M.MAX_PER_TEXT then
            break
        end
        local found = M.find(line, tags, used, {}, M.MAX_PER_TEXT - n)
        if #found > 0 then
            local lx = line_x(x, kit.width(line, font), pivot)
            local ly = top + (i - 1) * lh
            for _, f in ipairs(found) do
                local s, e, t = f[1], f[2], f[3]
                local wx = lx + kit.width(string.sub(line, 1, s - 1), font)
                local ww = kit.width(string.sub(line, s, e), font)
                local first = not layer.gloss_seen[t.id]
                layer.gloss_seen[t.id] = true
                local base = vmath.vector4(color.x, color.y, color.z, first and 0.38 * (color.w or 1) or 0)
                local under = kit.box(wx, ly + lh - 4, ww, 1, base, { round = false })
                kit.spot(wx - 2, ly, ww + 4, lh, function(_, on)
                    if on then
                        pcall(gui.set_color, under, vmath.vector4(color.x, color.y, color.z, 1))
                        M.show(t.plain, t.text, t.dnd, wx, ly, ww, lh)
                    else
                        pcall(gui.set_color, under, base)
                        M.hide()
                    end
                end, under)
                n = n + 1
            end
        end
    end
end

-- A hover card over any rectangle (no underline): for counters and marks that aren't words.
-- node: a node the spot goes with (kit.remove of that node takes the spot too).
function M.card_spot(x, y, w, h, title, text, dnd, node)
    return kit.spot(x, y, w, h, function(_, on)
        if on then
            M.show(title, text, dnd, x, y, w, h)
        else
            M.hide()
        end
    end, node)
end

kit.gloss_hook = M.hook

-- Draw with the glossary on for these tags ({ fight = true }, or true for every term).
function kit.gloss_scope(tags, fn)
    local before = kit.gloss_tags
    kit.gloss_tags = tags
    local ok, err = pcall(fn)
    kit.gloss_tags = before
    if not ok then
        error(err, 0)
    end
end

return M
