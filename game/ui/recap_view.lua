-- The DM's recap on game night (v2, November 1): two fold-out sidebars, the Story top left and the
-- Table top right, so a call can be made with the story and the people at the table both in view.
-- The night waits while one is open. One at a time (the third playtest's engine run, 8_12: both
-- open filled both sides of the board and cut the caption between them): the Story and Table
-- buttons in the top bar open theirs and close the other; S goes Story, Table, neither. What's in
-- them comes from game/model/standing.lua.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"
local panels = require "game.ui.panels"
local standing = require "game.model.standing"

local M = {}

M.W = 420
M.TOP, M.BOTTOM = 64, 736     -- (clear of the thought clouds over the panels)
M.LEFT_X = 12
M.RIGHT_X = 1600 - 12 - M.W

local TONE = { good = theme.green, bad = theme.orange, quiet = theme.dim }

local function alpha(c, a)
    return vmath.vector4(c.x, c.y, c.z, (c.w or 1) * a)
end

-- "The Knight of Shades" in the middle of a sentence: "the Knight of Shades".
local function mid(name)
    if type(name) == "string" and string.match(name, "^The ") then
        return "the" .. string.sub(name, 4)
    end
    return name
end

function M.open_any(app)
    return app.recap_left or app.recap_right
end

function M.close(app)
    if app.layers and app.layers.recap then
        kit.drop(app.layers.recap)
        app.layers.recap = nil
    end
    app.recap_left, app.recap_right = nil, nil
    kit.reset_hover()
end

-- side: "left" or "right": open it (and shut the other) if it's shut, shut it if it's open.
-- "both" (S): the Story, then the Table, then neither.
function M.toggle(app, side)
    if side == "both" then
        if app.recap_left then
            app.recap_left, app.recap_right = nil, true
        elseif app.recap_right then
            app.recap_left, app.recap_right = nil, nil
        else
            app.recap_left, app.recap_right = true, nil
        end
    elseif side == "left" then
        local open = not app.recap_left
        app.recap_left, app.recap_right = open or nil, nil
    else
        local open = not app.recap_right
        app.recap_left, app.recap_right = nil, open or nil
    end
    M.draw(app)
end

-- A small round face, with a ring in their colour.
local function face(key, x, y, size, dim)
    kit.dot(x + size / 2, y + size / 2, size + 4, alpha(panels.COLORS[key] or theme.gold, dim and 0.35 or 0.9))
    kit.picture(x, y, size, size, panels.face(key), alpha(kit.rgba("#ffffff"), dim and 0.5 or 1))
end

local function frame(x, title, sub, close_key, on_close)
    local h = M.BOTTOM - M.TOP
    -- (First, so it's hit last: a click on the panel doesn't fall through to a card under it.)
    kit.button(x, M.TOP, M.W, h, "", function() end, { color = alpha(theme.bg, 0), hover = alpha(theme.bg, 0) })
    kit.box(x - 2, M.TOP - 2, M.W + 4, h + 4, kit.rgba("#000000", 0.4), { radius = 14 })
    kit.box(x, M.TOP, M.W, h, theme.bg_glass, { radius = 12 })
    kit.text(x + 16, M.TOP + 12, title, "ui22b", theme.gold)
    kit.text(x + 16, M.TOP + 42, sub, "ui14", theme.faint, { w = M.W - 70 })
    kit.button(x + M.W - 44, M.TOP + 10, 32, 32, "x", on_close, { font = "ui18b", key = close_key, color = theme.panel2 })
    return M.TOP + 68
end

-- Top left: the story. Each side, its people and where each stands; who at the table is drawn to them.
local function draw_story(app)
    local x = M.LEFT_X
    local y = frame(x, "THE STORY", "Where each side stands, and who at the table cares.", "recap_close_left", function()
        M.toggle(app, "left")
    end)
    local w = M.W - 32
    local bottom = M.BOTTOM - 10
    for _, s in ipairs(standing.story(app.campaign)) do
        if y + 40 > bottom then
            break
        end
        kit.text(x + 16, y, string.upper(s.name), "ui14", theme.gold)
        y = y + 22
        for _, r in ipairs(s.people) do
            local line = r.line .. (r.with and (" " .. r.with) or "")
            local lh = kit.text_height(line, "ui14", w - 96)
            if y + 22 + lh > bottom then
                break
            end
            local nn = kit.text(x + 16, y, r.name, "ui18b", r.boss and theme.text or theme.text, { w = w - 96, lines = 1, gloss = false })
            -- (Their name opens their sheet: the playtest, November 3.)
            if r.id then
                require("game.ui.gloss").npc_spot(x + 14, y - 2, math.min(kit.width(r.name, "ui18b"), w - 96) + 4, 24, r.id, nn)
            end
            kit.text(x + 16, y + 22, line, "ui14", TONE[r.tone] or theme.dim, { w = w - 96 })
            -- Who's drawn to them (a full ring: keen), and who's put off (dimmed, with a red dot).
            local fx = x + M.W - 16
            for i = #r.keen, 1, -1 do
                local e = r.keen[i]
                fx = fx - 22
                face(e.key, fx, y + 2, 18, not e.strong)
            end
            for i = #r.cold, 1, -1 do
                fx = fx - 22
                face(r.cold[i], fx, y + 2, 18, true)
                kit.dot(fx + 16, y + 18, 8, theme.red)
            end
            y = y + 22 + lh + 8
        end
        if #s.ahead > 0 and y + 20 <= bottom then
            local names = {}
            for _, r in ipairs(s.ahead) do
                table.insert(names, mid(r.name))
            end
            local text = "Still ahead: " .. util.join_names(names) .. "."
            local th = kit.text_height(text, "ui14", w)
            kit.text(x + 16, y, text, "ui14", theme.faint, { w = w })
            y = y + th + 4
        end
        y = y + 12
    end
    if y + 34 <= bottom then
        kit.text(x + 16, bottom - 20, "A full ring: keen. A faint one: interested. A red dot: put off.", "ui14", theme.faint,
            { w = w, lines = 1 })
    end
end

-- Top right: the table. Each friend: why they came, what they love, who they're drawn to, how they
-- seem tonight, the last thought of theirs you read, and how well you know them.
local function draw_table(app)
    local x = M.RIGHT_X
    local y = frame(x, "THE TABLE", "Why each came, and what they're after.",
        "recap_close_right", function()
            M.toggle(app, "right")
        end)
    local w = M.W - 32
    local rows = standing.table(app.campaign, app.night)
    local each = math.floor((M.BOTTOM - 10 - y) / math.max(1, #rows))
    for _, r in ipairs(rows) do
        local top = y
        face(r.key, x + 16, y + 2, 32, not r.present)
        kit.text(x + 58, y, r.name, "ui18b", r.present and theme.text or theme.faint)
        kit.text(x + 58 + kit.width(r.name, "ui18b") + 8, y + 3, r.char, "ui14", theme.dim)
        -- How well you know them: dots, top right of their block.
        for k = 1, r.of do
            kit.dot(x + M.W - 74 + (k - 1) * 11, y + 10, 7, k <= r.level and theme.teal or theme.panel3)
        end
        kit.text(x + 58, y + 20, "You know them: " .. string.lower(r.known), "ui14", theme.faint, { w = w - 50, lines = 1 })
        y = y + 42
        local lines = {}
        if not r.present then
            table.insert(lines, { "Not at the table tonight.", theme.faint })
        end
        if r.hook then
            table.insert(lines, { "Came for " .. string.lower(r.hook.name) .. ": " .. mid(r.hook.room) .. ", " .. r.hook.state .. ".",
                                  r.hook.state == "paid off" and theme.green or (r.hook.state == "still to come" and theme.text or theme.orange) })
        end
        table.insert(lines, { "Loves " .. string.lower(r.loves or "a bit of everything")
            .. (r.bored and ("; bored by " .. string.lower(r.bored)) or "") .. ".", theme.dim })
        if #r.drawn > 0 then
            local names = {}
            for _, n in ipairs(r.drawn) do
                table.insert(names, mid(n))
            end
            table.insert(lines, { "Drawn to " .. util.join_names(names) .. ".", theme.teal })
        end
        if #r.cold > 0 then
            local names = {}
            for _, n in ipairs(r.cold) do
                table.insert(names, mid(n))
            end
            table.insert(lines, { "Put off by " .. util.join_names(names) .. ".", theme.orange })
        end
        if r.tonight then
            -- (By how they're sitting, as the table shows it: their Fun builds over the night.)
            local e = r.tonight.engagement or 0.5
            local word = (e >= 0.68 and "into it") or (e >= 0.42 and "with you") or (e >= 0.3 and "drifting") or "checked out"
            table.insert(lines, { "Tonight: " .. word .. ", " .. r.tonight.tell .. ".", e < 0.42 and theme.orange or theme.text })
        end
        if r.read then
            table.insert(lines, { "You read them: " .. string.lower(string.sub(r.read, 1, 1)) .. string.sub(r.read, 2) .. ".",
                                  theme.purple })
        end
        for _, l in ipairs(lines) do
            local lh = kit.text_height(l[1], "ui14", w)
            if y + lh > top + each - 6 then
                break
            end
            kit.text(x + 16, y, l[1], "ui14", l[2], { w = w })
            y = y + lh + 2
        end
        y = top + each
        kit.box(x + 16, y - 5, w, 1, alpha(theme.dim, 0.25), { round = false })
    end
end

-- Draw whichever sidebars are open (or none). Called on open, close and every rebuild.
function M.draw(app)
    if app.layers and app.layers.recap then
        kit.drop(app.layers.recap)
        app.layers.recap = nil
    end
    if not (app.recap_left or app.recap_right) or not standing.has(app.campaign) then
        app.recap_left, app.recap_right = nil, nil
        return
    end
    local before = kit.current
    app.layers.recap = kit.layer("night_recap", false)
    if app.recap_left then
        draw_story(app)
    end
    if app.recap_right then
        draw_table(app)
    end
    kit.current = before or kit.current
end

return M
