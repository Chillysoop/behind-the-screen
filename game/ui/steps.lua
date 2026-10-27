-- One decision at a time (October 26: "the pre-session menus are overwhelming"). The frame that
-- setting up a campaign (game/ui/setup_view.lua) and each week's prep (game/ui/prep_view.lua)
-- share: one question per screen, Back and Next along the bottom, and a strip across the top
-- that says where you are and takes you back to anything you've already answered.
--
-- A flow: { id, title, steps = { step... }, finish = { label, fn }, header = fn(app) (the top
-- bar's right end), aside = { x, w, draw = fn(app, x, y, w, h) } (a column beside the step) }.
-- A step: { id, section, ask, sub (strings, or functions of app), draw = fn(app, area),
-- done = fn(app) -> bool (answered; nil = nothing to answer), need = text or fn (what's missing),
-- skip = fn(app) -> bool (not this time), next_label, on_next = fn(app) (on the way forward),
-- enter = fn(app) (on arriving), layout = "table" or "full", talk = fn(app, key) }. area =
-- { x, y, w, h }: what's left under the question.
--
-- The table (October 26: "put in character visuals... some sort of thought bubble or dialogue to
-- help the player steer decisions"): a "table" step leaves the room in view, your friends in
-- their chairs, and asks its question in a panel along the bottom. Over each head, a bubble:
-- what they say about it (out of character, at setup) or what's on their hero's mind (in
-- character, at prep), from step.talk(app, key) -> { text, think = true (a thought, not said),
-- like = -2..2 }. They strike a pose to match: a cheer for what they love, arms folded for what
-- they don't. flow.people(app): who's at the table.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local panels = require "game.ui.panels"
local content = require "game.model.content"
local util = require "game.model.util"

local M = {}

M.TOP_H = 70
M.FOOT_Y = 836
M.PANEL_Y = 452      -- a "table" step's panel: the room above it, your friends' heads in view

-- Where their heads are in the room camera when the table hasn't said yet (headless runs, the
-- first frame): x and y as fractions of the screen.
local HEADS = { dev = { 0.35, 0.30 }, mara = { 0.49, 0.28 }, jess = { 0.61, 0.30 }, sam = { 0.68, 0.38 } }
-- How each of them sits while a choice stands: by how much they like it.
local POSE = { [2] = "cheer", [1] = "lean", [0] = "think", [-1] = "arms", [-2] = "phone" }

local function val(v, app)
    if type(v) == "function" then
        return v(app)
    end
    return v
end
M.val = val

-- The steps that apply this time, in order.
function M.visible(app, flow)
    local out = {}
    for _, s in ipairs(flow.steps) do
        if not (s.skip and s.skip(app)) then
            table.insert(out, s)
        end
    end
    return out
end

local function at(app)
    app.step_at = app.step_at or {}
    return app.step_at
end

function M.done(app, s)
    return s.done == nil or s.done(app) and true or false
end

-- The step on screen: the one you were on, the first one (a fresh start), or the first one still
-- waiting (the one you were on doesn't apply any more).
function M.current(app, flow)
    local list = M.visible(app, flow)
    local id = at(app)[flow.id]
    for i, s in ipairs(list) do
        if s.id == id then
            return s, i, list
        end
    end
    -- A fresh start begins at the beginning; a step that no longer applies, at the first one
    -- still waiting.
    for i, s in ipairs(list) do
        if id and not M.done(app, s) then
            at(app)[flow.id] = s.id
            return s, i, list
        end
    end
    at(app)[flow.id] = list[1] and list[1].id
    return list[1], 1, list
end

-- Can you get there from here? Everything before it answered.
function M.reachable(app, flow, id)
    for _, s in ipairs(M.visible(app, flow)) do
        if s.id == id then
            return true
        end
        if not M.done(app, s) then
            return false
        end
    end
    return false
end

function M.go(app, flow, id)
    for _, s in ipairs(M.visible(app, flow)) do
        if s.id == id then
            at(app)[flow.id] = id
            app.step_scroll = nil
            if s.enter then
                s.enter(app)
            end
            if app.refresh then
                app.refresh()
            end
            return true
        end
    end
    return false
end

function M.reset(app, flow)
    at(app)[flow.id] = nil
end

-- Next (or Enter): on to the next step, or the flow's finish on the last one.
function M.next(app, flow)
    local s, i, list = M.current(app, flow)
    if not s or not M.done(app, s) then
        return false
    end
    if s.on_next then
        s.on_next(app)
    end
    -- (Answering a step can change which steps come next: look again.)
    list = M.visible(app, flow)
    local nxt
    for k, t in ipairs(list) do
        if t.id == s.id then
            nxt = list[k + 1]
        end
    end
    if not nxt then
        if flow.finish then
            flow.finish.fn(app)
        end
        return true
    end
    return M.go(app, flow, nxt.id)
end

function M.back(app, flow)
    local s, i, list = M.current(app, flow)
    if i > 1 then
        return M.go(app, flow, list[i - 1].id)
    end
    return false
end

-- The sections, in order, each with its first step.
local function sections(list)
    local out, seen = {}, {}
    for _, s in ipairs(list) do
        if not seen[s.section] then
            seen[s.section] = true
            table.insert(out, { name = s.section, first = s.id, steps = {} })
        end
        table.insert(out[#out].steps, s)
    end
    return out
end

-- The top bar: the flow's title, the sections (the one you're in, gold; the ones done, ticked),
-- and the step count.
local function top(app, flow, cur, i, list)
    kit.box(0, 0, kit.W, M.TOP_H, theme.bg, { round = false })
    kit.box(0, M.TOP_H - 1, kit.W, 1, kit.rgba("#ffffff", 0.06), { round = false })
    local title = val(flow.title, app)
    kit.text(24, 12, title, "title30", theme.gold)
    kit.text(24, 48, "Step " .. util.int(i) .. " of " .. util.int(#list), "ui14", theme.faint)
    local x = 24 + math.max(kit.width(title, "title30"), 120) + 40
    local right = math.min(flow.header and flow.header_x or kit.W, M.header_right())
    for k, sec in ipairs(sections(list)) do
        local here = sec.name == cur.section
        local all_done = true
        for _, s in ipairs(sec.steps) do
            all_done = all_done and M.done(app, s)
        end
        local label = sec.name
        local tw = kit.width(label, "ui18b") + 24
        if x + tw > right then
            break
        end
        local ok = M.reachable(app, flow, sec.first)
        local col = here and theme.gold or ((all_done and ok) and theme.teal or theme.faint)
        if here then
            kit.box(x, 16, tw, 36, kit.rgba("#e8b04a", 0.14), { radius = 18 })
        end
        kit.button(x, 16, tw, 36, "", function()
            if not here and ok then
                M.go(app, flow, sec.first)
            end
        end, { color = kit.rgba("#000000", 0), hover = ok and theme.button_hover or kit.rgba("#000000", 0),
               radius = 18, key = "section_" .. k })
        kit.text(x + tw / 2, 34, label, "ui18b", col, { pivot = gui.PIVOT_CENTER, gloss = false })
        x = x + tw + 8
    end
    if flow.header then
        flow.header(app)
    end
    -- Chill mode, top right on every step (October 26).
    local prefs = require "game.ui.prefs"
    prefs.switch(kit.W - 24 - prefs.switch_w(), 16, { changed = function(on)
        app.toast, app.toast_tone = prefs.said(on), "info"
        app.refresh()
    end })
end

-- Where a flow's own header has to stop: the Chill mode switch is to its right.
function M.header_right()
    return kit.W - 24 - require("game.ui.prefs").switch_w() - 12
end

-- The question, what it's about, and below them the step's own area.
local function body(app, flow, s, x, w, y0)
    local y = y0 or (M.TOP_H + 22)
    local ask = val(s.ask, app) or ""
    kit.text(x, y, ask, "title30", theme.text, { w = w })
    y = y + kit.text_height(ask, "title30", w) + 6
    local sub = val(s.sub, app)
    if sub and sub ~= "" then
        kit.text(x, y, sub, "ui18", theme.dim, { w = w })
        y = y + kit.text_height(sub, "ui18", w) + 4
    end
    return { x = x, y = y + 16, w = w, h = M.FOOT_Y - 16 - (y + 16) }
end

-- Back and Next.
local function foot(app, flow, s, i, list, x, w)
    local y = M.FOOT_Y
    kit.button(x, y, 150, 50, "<  Back", function()
        M.back(app, flow)
    end, { font = "ui18b", enabled = i > 1, key = "step_back" })
    local last = i == #list
    local label = val(s.next_label, app) or (last and flow.finish and val(flow.finish.label, app)) or "Next  >"
    local ok = M.done(app, s)
    local bw = math.max(220, kit.width(label, "ui22b") + 48)
    kit.button(x + w - bw, y, bw, 54, label, function()
        M.next(app, flow)
    end, { font = "ui22b", enabled = ok, color = theme.go, hover = theme.go_hover, key = "step_next" })
    local hint = ok and "or press Enter" or (val(s.need, app) or "Choose one to go on.")
    kit.text(x + w - bw - 16, y + 18, hint, "ui14", ok and theme.faint or theme.dim, { pivot = gui.PIVOT_NE })
end

-- Bubbles over their heads ----------------------------------------------------------------------

local function head_xy(app, key)
    local h = app.anchors and app.anchors.heads and app.anchors.heads[key]
    if h and h[1] and h[1] > 0.02 and h[1] < 0.98 and h[2] > 0.05 and h[2] < 0.95 then
        return h[1] * kit.W, h[2] * kit.H
    end
    local f = HEADS[key] or { 0.5, 0.4 }
    return f[1] * kit.W, f[2] * kit.H
end

-- How tall a bubble is for its words.
local function bubble_h(text, w)
    return math.min(kit.text_height(text, "ui18", w - 28), 5 * kit.line_height("ui18")) + 24 + 22
end

-- One bubble: who's talking, then a speech bubble with a tail to their head, or a thought with a
-- trail of dots.
local function bubble(x, y, w, key, text, hx, hy, think, like)
    local tw = w - 28
    local h = bubble_h(text, w)
    -- The edge says how they feel only in Chill mode: otherwise it's in their words and how they sit.
    if not require("game.ui.prefs").chill() then
        like = nil
    end
    local edge = like and like > 0 and theme.green or (like and like < 0 and theme.orange or kit.rgba("#c8b48a"))
    -- The tail first, under the bubble: from its bottom edge toward the head.
    -- (The table's head anchors already sit just over each head: the tail stops there.)
    local bx, by = x + w / 2, y + h
    local tx, ty = hx, hy
    if think then
        for k = 1, 3 do
            local f = k / 4
            kit.dot(bx + (tx - bx) * f, by + (ty - by) * f, 18 - k * 3, theme.paper)
        end
    else
        kit.line(bx, by - 4, tx, ty, 10, theme.paper)
    end
    kit.box(x - 3, y - 3, w + 6, h + 6, edge, { radius = 16 })
    kit.box(x, y, w, h, theme.paper, { radius = 14 })
    local d = content.players[key]
    kit.text(x + 14, y + 8, string.upper(d and d.name or key) .. (think and ("  (" .. (d and d.char or "") .. ", thinking)") or ""),
        "ui14", theme.ink_dim, { gloss = false })
    kit.text(x + 14, y + 30, text, "ui18", theme.ink, { w = tw, lines = 5, gloss = false })
    return h
end

-- Everyone's bubble, spread across the room above their heads, left to right as they sit.
local function people(app, flow, s)
    local fn = s.people or flow.people
    return fn and fn(app) or {}
end

local function bubbles(app, flow, s)
    if not s.talk then
        return
    end
    local who = {}
    for _, key in ipairs(people(app, flow, s)) do
        local t = s.talk(app, key)
        if t and t.text and t.text ~= "" then
            local hx, hy = head_xy(app, key)
            table.insert(who, { key = key, t = t, hx = hx, hy = hy })
        end
    end
    table.sort(who, function(a, b) return a.hx < b.hx end)
    local n = #who
    if n == 0 then
        return
    end
    local gap = 16
    local w = math.min(360, math.floor((kit.W - 48 - (n - 1) * gap) / n))
    local total = n * w + (n - 1) * gap
    local x0 = math.floor((kit.W - total) / 2)
    for i, b in ipairs(who) do
        local x = x0 + (i - 1) * (w + gap)
        -- Just over their head, as low as the room allows (never under the top bar).
        local h = bubble_h(b.t.text, w)
        local y = math.max(M.TOP_H + 12, math.min(b.hy - 50 - h, M.PANEL_Y - 60 - h))
        bubble(x, y, w, b.key, b.t.text, b.hx, b.hy, b.t.think, b.t.like)
    end
end

-- Their poses: a resting pose for how they feel about what's chosen, posted when it changes.
local function poses(app, flow, s)
    if not app.table_post then
        return
    end
    local want = {}
    for _, key in ipairs(people(app, flow, s)) do
        local t = s.talk and s.talk(app, key)
        local like = t and t.like
        want[key] = like and POSE[math.max(-2, math.min(2, like))] or "neutral"
    end
    local same = app.posed ~= nil
    for k, v in pairs(want) do
        same = same and app.posed[k] == v
    end
    if not same then
        app.posed = want
        app.table_post("mood", { poses = want })
    end
end

-- Where the heads are, from the table each frame: redraw when they've moved (the camera
-- settling), at most every few frames.
function M.on_anchors(app, m)
    app.anchors = app.anchors or {}
    app.anchors.heads = m.heads
    app.anchors.minis = m.minis
    app.anchor_frames = (app.anchor_frames or 0) + 1
    local moved = false
    for key, h in pairs(m.heads or {}) do
        local was = app.drawn_heads and app.drawn_heads[key]
        if not was or math.abs(was[1] - h[1]) * kit.W > 6 or math.abs(was[2] - h[2]) * kit.H > 6 then
            moved = true
        end
    end
    if moved and app.anchor_frames >= 8 and app.table_view and app.refresh then
        app.anchor_frames = 0
        app.refresh()
    end
end

-- The whole screen for the step you're on.
function M.draw(app, flow, opts)
    opts = opts or {}
    local s, i, list = M.current(app, flow)
    if not s then
        return
    end
    local layout = s.layout or flow.layout or "full"
    -- Back and Next span the flow's width; a step can put its question in a column of its own.
    local fx = opts.x or 24
    local fw = opts.w or (kit.W - 48)
    local x = s.x or fx
    local w = s.w or fw
    app.table_view = layout == "table"
    local area
    if layout == "table" then
        -- The room stays in view: only the top bar, the bubbles and the panel along the bottom.
        app.drawn_heads = {}
        for _, key in ipairs(people(app, flow, s)) do
            local hx, hy = head_xy(app, key)
            app.drawn_heads[key] = { hx / kit.W, hy / kit.H }
        end
        top(app, flow, s, i, list)
        bubbles(app, flow, s)
        kit.box(0, M.PANEL_Y, kit.W, kit.H - M.PANEL_Y, kit.rgba("#1c1410", 0.96), { round = false })
        kit.box(0, M.PANEL_Y, kit.W, 2, kit.rgba("#e8b04a", 0.35), { round = false })
        area = body(app, flow, s, x, w, M.PANEL_Y + 12)
        poses(app, flow, s)
    else
        kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
        top(app, flow, s, i, list)
        local aside = s.aside or flow.aside
        if aside then
            aside.draw(app, aside.x, M.TOP_H + 14, aside.w, M.FOOT_Y - M.TOP_H - 28)
        end
        area = body(app, flow, s, x, w)
    end
    if s.draw then
        s.draw(app, area)
    end
    foot(app, flow, s, i, list, fx, fw)
    if app.toast then
        kit.text(fx + fw / 2, M.FOOT_Y - 30, app.toast, "ui18", app.toast_tone == "info" and theme.teal or theme.orange,
            { pivot = gui.PIVOT_N, w = fw - 300 })
        app.toast, app.toast_tone = nil, nil
    end
end

-- Choice cards ---------------------------------------------------------------------------------

-- A grid of choices. Each item: { title, body, foot (a small line at the bottom), on (chosen),
-- click, key, enabled, color (the card's own), deco = fn(x, y, w, h) (faces, icons), tall (min h) }.
-- opts: cols, gap, title_font, body_font. Returns the y under the grid.
function M.cards(app, a, items, opts)
    opts = opts or {}
    local cols = opts.cols or math.min(#items, 3)
    local gap = opts.gap or 14
    local cw = math.floor((a.w - (cols - 1) * gap) / cols)
    local tf = opts.title_font or "ui22b"
    local bf = opts.body_font or "ui18"
    local y = a.y
    for r = 0, math.ceil(#items / cols) - 1 do
        -- Every card in a row as tall as the tallest.
        local rh = opts.min_h or 0
        for c = 1, cols do
            local it = items[r * cols + c]
            if it then
                local h = 16 + (it.title and kit.text_height(it.title, tf, cw - 32 - (it.title_pad or 0)) or 0)
                    + (it.body and (8 + kit.text_height(it.body, bf, cw - 32)) or 0)
                    + (it.foot and (10 + kit.text_height(it.foot, "ui14", cw - 32)) or 0) + 18 + (it.extra_h or 0)
                rh = math.max(rh, h, it.tall or 0)
            end
        end
        for c = 1, cols do
            local it = items[r * cols + c]
            if it then
                local x = a.x + (c - 1) * (cw + gap)
                if it.on then
                    kit.box(x - 4, y - 4, cw + 8, rh + 8, theme.gold, { radius = 14 })
                end
                kit.button(x, y, cw, rh, "", it.click, { color = it.color or (it.on and theme.panel3 or theme.panel2),
                    hover = theme.button_hover, enabled = it.enabled, radius = 12, key = it.key, on_hover = it.on_hover })
                local ty = y + 16
                if it.title then
                    kit.text(x + 16, ty, it.title, tf, it.enabled == false and theme.faint or theme.text, { w = cw - 32 - (it.title_pad or 0) })
                    ty = ty + kit.text_height(it.title, tf, cw - 32 - (it.title_pad or 0)) + 8
                end
                if it.body then
                    kit.text(x + 16, ty, it.body, bf, it.on and theme.text or theme.dim, { w = cw - 32 })
                    ty = ty + kit.text_height(it.body, bf, cw - 32) + 10
                end
                if it.foot then
                    kit.text(x + 16, y + rh - 14 - kit.text_height(it.foot, "ui14", cw - 32), it.foot, "ui14",
                        it.foot_color or theme.faint, { w = cw - 32 })
                end
                if it.deco then
                    it.deco(x, y, cw, rh)
                end
            end
        end
        y = y + rh + gap
    end
    return y
end

-- Who at the table likes it (green) and who doesn't (orange): their faces with a mark.
-- likes: { [player key] = number }. keys: whose to show. Returns the x after the last face.
function M.faces(x, y, likes, keys, size)
    size = size or 26
    local cx = x
    if not require("game.ui.prefs").chill() then
        return cx     -- (Chill mode only: October 26)
    end
    for _, key in ipairs(keys) do
        local v = likes and likes[key] or 0
        if v ~= 0 then
            kit.dot(cx + size / 2, y + size / 2, size + 6, v > 0 and theme.green or theme.orange)
            kit.dot(cx + size / 2, y + size / 2, size, panels.COLORS[key] or theme.panel3)
            kit.picture(cx + 2, y + 2, size - 4, size - 4, panels.face(key))
            if v >= 2 or v <= -2 then
                kit.text(cx + size - 2, y - 6, v > 0 and "++" or "--", "ui14", v > 0 and theme.green or theme.orange)
            end
            cx = cx + size + 12
        end
    end
    return cx
end

-- A player's face and name, as a small heading for a step about them.
function M.person(x, y, key, line)
    local d = content.players[key]
    kit.dot(x + 28, y + 28, 56, panels.COLORS[key] or theme.panel3)
    kit.picture(x + 4, y + 4, 48, 48, panels.face(key))
    kit.text(x + 70, y + 2, d.name, "ui22b", theme.text)
    kit.text(x + 70, y + 32, line or (d.char .. ", " .. string.lower(d.class_name or "")), "ui18", theme.dim)
    return y + 64
end

-- A quote, in the story font.
function M.quote(x, y, w, text, color)
    kit.text(x, y, text, "story22", color or theme.log.quote, { w = w })
    return y + kit.text_height(text, "story22", w) + 10
end

return M
