-- The Story log (October 13): each storyline told so far, in one place. Its model is
-- game/model/chronicle.lua. It shows in two places:
--   the notebook's "Story log" tab   every storyline down the left; the chosen one's premise,
--                                    a bullet per scene that moved it (this week's plans and
--                                    tonight's scenes too), its leads, and who and where it
--                                    involves down the right
--   the prep board's story panel     opens over the table column when you place a card that
--                                    moves a storyline: that story so far and the card you
--                                    just placed, a tab per storyline the card moves
-- Names in it light up: hover one for who or what it is and which stories it's part of;
-- click a storyline's name to read that one. The mouse wheel scrolls.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"
local content = require "game.model.content"
local chronicle = require "game.model.chronicle"
local storylines = require "game.model.storylines"
local ledger = require "game.model.ledger"
local panels = require "game.ui.panels"

local M = {}

M.PANEL = { x = 1188, y = 78, w = 404, h = 814 }

local KIND_COLOR = {
    person = kit.rgba("#f0c987"), place = kit.rgba("#8cc7bf"), faction = kit.rgba("#e6a06a"),
    item = kit.rgba("#a8d890"), term = kit.rgba("#c9b896"),
}

local OUT_WORD = { win = { "Won", theme.green }, lose = { "Lost", theme.red } }

local function marks()
    return require "game.ui.lore_marks"
end

local function story_color(d)
    return kit.rgba((d and d.color) or "#e8b04a")
end

-- A touch lighter, so the darker shirt and storyline colours read on the dark panel.
local function lighter(c, k)
    k = k or 0.3
    return vmath.vector4(math.min(1, c.x * (1 - k) + k), math.min(1, c.y * (1 - k) + k), math.min(1, c.z * (1 - k) + k), 1)
end

local function kw_color(app, kw)
    if kw.kind == "hero" then
        return lighter(panels.COLORS[kw.id] or theme.gold, 0.45)
    elseif kw.kind == "story" then
        return lighter(story_color(storylines.def(app.campaign, kw.id)), 0.3)
    end
    return KIND_COLOR[kw.kind] or theme.gold
end

-- Where the night is, if one is on (live entries come from it).
local function live_night(app)
    local n = app.screen == "night" and app.night or nil
    if n and not n.filed then
        return n
    end
    return nil
end

local function this_prep(app)
    return app.screen == "prep" and app.campaign.prep or nil
end

-- Hover popups ------------------------------------------------------------------------------

function M.drop_hover(app)
    if app.story_hover then
        kit.drop(app.story_hover)
        app.story_hover = nil
    end
end

local function popup(app, rows, x0, y0, w)
    M.drop_hover(app)
    w = w or 420
    local h = 24
    for _, r in ipairs(rows) do
        h = h + kit.text_height(r[1], r[2], w - 32) + (r[4] or 6)
    end
    local x = util.clamp(x0, 8, kit.W - w - 8)
    local y = y0
    if y + h > kit.H - 8 then
        y = math.max(8, y0 - h - 40)
    end
    local before = kit.current
    local l = kit.layer("story_hover")
    app.story_hover = l
    kit.box(x - 2, y - 2, w + 4, h + 4, theme.gold, { radius = 12 })
    kit.box(x, y, w, h, kit.rgba("#201813", 0.98), { radius = 11 })
    local ry = y + 12
    for _, r in ipairs(rows) do
        kit.text(x + 16, ry, r[1], r[2], r[3], { w = w - 32 })
        ry = ry + kit.text_height(r[1], r[2], w - 32) + (r[4] or 6)
    end
    kit.current = before
end

local TONE = { text = theme.text, dim = theme.dim, good = theme.green, bad = theme.red, warn = theme.orange, gold = theme.gold }

-- What a keyword means: the notebook's own card for someone it keeps, else the Story log's.
function M.rows_for(app, kw)
    if kw.kind == "story" then
        return M.glance_rows(app, kw.id, { hint = "Click to read it all." })
    end
    if kw.kind == "term" then
        local def = chronicle.glossary.terms[kw.id]
        return { { kw.title or util.capitalize(kw.term), "ui18b", theme.text, 2 }, { def or "", "ui14", theme.dim } }
    end
    local night = live_night(app)
    local d = chronicle.define(app.campaign, kw, night)
    local rows
    if kw.kind == "person" and ledger.data.people[kw.id] then
        rows = require("game.ui.notebook_pages").person_rows(app, kw.id)
        while #rows > 12 do
            table.remove(rows)
        end
    else
        rows = { { d.title or kw.term, "ui18b", theme.text, 2 } }
        if d.sub then
            table.insert(rows, { d.sub, "ui14", theme.gold })
        end
        for _, ln in ipairs(d.lines) do
            table.insert(rows, { ln.text, "ui14", TONE[ln.tone] or theme.text, 4 })
        end
    end
    if #d.stories > 0 then
        table.insert(rows, { "IN THE STORIES", "ui14", theme.gold, 2 })
        table.insert(rows, { util.join_names(d.stories), "ui14", theme.text })
    end
    return rows
end

-- At a glance (October 13): the whole story as a short chain, to read in a second. compact:
-- the gist and the last two steps (several storylines in one hover).
local OUT_SHORT = { win = ", won", lose = ", lost" }

function M.glance_rows(app, id, opts)
    opts = opts or {}
    local g = chronicle.glance(app.campaign, id, { night = live_night(app), prep = this_prep(app) })
    if not g then
        return {}
    end
    local rows = {}
    local hw, hc = M.heat_label(g.heat)
    table.insert(rows, { g.title, opts.compact and "ui18b" or "ui22b", theme.text, 0 })
    table.insert(rows, { (opts.compact and "" or "AT A GLANCE  -  ") .. hw, "ui14", hc, 6 })
    table.insert(rows, { g.gist, "ui18", theme.gold, 6 })
    local steps = {}
    for _, st in ipairs(g.steps) do
        if not (opts.compact and (st.tag == "planned" or st.tag == "later")) then
            table.insert(steps, st)
        end
    end
    local keep = {}
    local limit = opts.compact and 2 or 7
    if #steps > limit then
        if not opts.compact then
            table.insert(keep, steps[1])
        end
        table.insert(keep, { skip = #steps - limit + (opts.compact and 0 or 1) })
        for i = #steps - (opts.compact and limit or limit - 2) + 1, #steps do
            table.insert(keep, steps[i])
        end
    else
        keep = steps
    end
    for _, st in ipairs(keep) do
        if st.skip then
            table.insert(rows, { "   ... " .. util.int(st.skip) .. (st.skip == 1 and " more scene" or " more scenes"), "ui14", theme.faint, 4 })
        else
            local col = (st.tag == "past" and theme.text) or (st.tag == "zero" and theme.gold) or (st.tag == "tonight" and theme.teal)
                or (st.focus and theme.orange or theme.gold)
            local text = "-> " .. st.label .. "  " .. st.text .. (OUT_SHORT[st.out or ""] or (st.now and ", playing now" or ""))
            table.insert(rows, { text, "ui14", col, 4 })
        end
    end
    if #steps == 0 then
        table.insert(rows, { "Nothing's happened yet.", "ui14", theme.faint, 4 })
    end
    if not opts.compact and #g.next > 0 then
        table.insert(rows, { "Waiting in your deck: " .. table.concat(g.next, "; ") .. ".", "ui14", theme.dim, 4 })
    end
    if opts.hint then
        table.insert(rows, { opts.hint, "ui14", theme.faint })
    end
    return rows
end

-- One storyline's glance (or several, compact) in a popup near a point.
function M.show_glance(app, ids, x, y, hint)
    local rows = {}
    local compact = #ids > 1
    for k, id in ipairs(ids) do
        if k <= 3 then
            if k > 1 then
                table.insert(rows, { " ", "ui14", theme.faint, 0 })
            end
            for _, r in ipairs(M.glance_rows(app, id, { compact = compact })) do
                table.insert(rows, r)
            end
        end
    end
    if hint then
        table.insert(rows, { hint, "ui14", theme.faint })
    end
    popup(app, rows, x, y, compact and 460 or 540)
end

-- A hover that shows a storyline at a glance.
function M.glance_hover(app, id, x, y, hint)
    return function(_, on)
        if on then
            pcall(M.show_glance, app, { id }, x, y, hint)
        else
            M.drop_hover(app)
        end
    end
end

-- A keyword's hot spot: its underline is the button (hit-tested by its rectangle, so it costs
-- no extra nodes), and it lights up under the pointer.
local function hotspot(app, kw, x, y, w, h, under, on_story)
    local base = kw_color(app, kw)
    local dimmed = vmath.vector4(base.x, base.y, base.z, 0.45)
    gui.set_color(under, dimmed)
    local b = { node = under, enabled = true, color = dimmed, hover = vmath.vector4(base.x, base.y, base.z, 1),
                key = "kw_" .. kw.kind .. "_" .. tostring(kw.id), rect = { x, y, w, h }, rect_hit = true,
                on_hover = function(_, on)
                    if on then
                        local ok, rows = pcall(M.rows_for, app, kw)
                        if ok and rows then
                            popup(app, rows, x, y + h + 6)
                        end
                    else
                        M.drop_hover(app)
                    end
                end }
    if kw.kind == "story" and on_story then
        b.on_click = function()
            M.drop_hover(app)
            on_story(kw.id)
        end
    end
    table.insert(kit.current.buttons, b)
    return b
end

-- Rich text ----------------------------------------------------------------------------------

-- Lines of words, laid out the way kit.wrap does it: { { w, words = { { s, e, x, w } } } }.
local function layout(text, font, w)
    local space = kit.width(" ", font)
    local lines, cur = {}, nil
    for s, word, e in string.gmatch(text, "()(%S+)()") do
        local ww = kit.width(word, font)
        if cur and cur.w + space + ww <= w then
            table.insert(cur.words, { s = s, e = e - 1, x = cur.w + space, w = ww })
            cur.w = cur.w + space + ww
        else
            cur = { w = ww, words = { { s = s, e = e - 1, x = 0, w = ww } } }
            table.insert(lines, cur)
        end
    end
    return lines
end

function M.height(text, font, w)
    return math.max(1, #layout(text or "", font, w)) * kit.line_height(font)
end

-- Draw text with its keywords lit: returns the y under it. opts: on_story (a storyline's name
-- was clicked), plain (no keywords).
function M.rich(app, x, y, w, text, font, color, kws, opts)
    opts = opts or {}
    text = text or ""
    local lh = kit.line_height(font)
    local lines = layout(text, font, w)
    if #lines == 0 then
        return y + lh
    end
    -- Which keyword each byte belongs to.
    local owner = {}
    if not opts.plain then
        local pos = 1
        for _, seg in ipairs(chronicle.mark(text, kws)) do
            if seg.kw then
                for i = pos, pos + #seg.text - 1 do
                    owner[i] = seg.kw
                end
            end
            pos = pos + #seg.text
        end
    end
    for li, line in ipairs(lines) do
        local ly = y + (li - 1) * lh
        -- Pieces: each word split where keywords start and stop, spaces belonging to a
        -- keyword when it runs on across them ("Madame Sable").
        local runs = {}
        local function push(str, kw, px)
            local last = runs[#runs]
            if last and last.kw == kw then
                last.text = last.text .. str
            else
                table.insert(runs, { text = str, kw = kw, x = px })
            end
        end
        for wi, wd in ipairs(line.words) do
            if wi > 1 then
                local prev = line.words[wi - 1]
                local kw = owner[prev.e] ~= nil and owner[prev.e] == owner[wd.s] and owner[wd.s] or nil
                push(" ", kw, prev.x + prev.w)
            end
            local i = wd.s
            while i <= wd.e do
                local kw = owner[i]
                local j = i
                while j + 1 <= wd.e and owner[j + 1] == kw do
                    j = j + 1
                end
                local px = wd.x + kit.width(string.sub(text, wd.s, i - 1), font)
                push(string.sub(text, i, j), kw, px)
                i = j + 1
            end
        end
        for _, r in ipairs(runs) do
            if r.kw then
                local str = string.gsub(r.text, "%s+$", "")
                local rw = kit.width(str, font)
                local col = kw_color(app, r.kw)
                kit.text(x + r.x, ly, str, font, col)
                local under = kit.box(x + r.x, ly + lh - 3, rw, 1.5, col, { round = false })
                hotspot(app, r.kw, x + r.x, ly, rw, lh, under, opts.on_story)
            elseif string.find(r.text, "%S") then
                kit.text(x + r.x, ly, r.text, font, color)
            end
        end
    end
    return y + #lines * lh
end

-- The blocks of a storyline ------------------------------------------------------------------

local STYLE = {
    page = { body = "ui18", head = "ui14", place = "ui18b", quote = "story22", gap = 14, indent = 26 },
    panel = { body = "ui14", head = "ui14", place = "ui18b", quote = "ui14", gap = 10, indent = 22 },
}

local function term_kw(id, word)
    return { kind = "term", id = id, term = word, title = word }
end

-- One scene's bullet.
local function entry_block(app, e, w, st, kws, d, last, on_story)
    local tw = w - st.indent
    local text = table.concat(e.parts or {}, " ")
    local head
    if e.tag == "zero" then
        head = "SESSION ZERO"
    elseif e.tag == "past" then
        head = "SESSION " .. util.int(e.w) .. "  -  SCENE " .. util.int(e.s)
    elseif e.tag == "tonight" then
        head = "TONIGHT  -  SCENE " .. util.int(e.s)
    elseif e.tag == "later" then
        head = "LATER TONIGHT  -  SCENE " .. util.int(e.s)
    else
        head = "THIS WEEK  -  SCENE " .. util.int(e.s)
    end
    local right, rcol, rterm
    if e.out and OUT_WORD[e.out] then
        right, rcol, rterm = OUT_WORD[e.out][1], OUT_WORD[e.out][2], e.out == "win" and "won" or "lost"
    elseif e.now then
        right, rcol, rterm = "Playing now", theme.teal, "tonight"
    elseif e.tag == "planned" or e.tag == "later" then
        right, rcol, rterm = e.focus and "Just placed" or "Planned", e.focus and theme.orange or theme.gold, "planned"
    elseif e.tag == "tonight" then
        right, rcol, rterm = "Tonight", theme.teal, "tonight"
    elseif e.tag == "zero" then
        right, rcol, rterm = "Written in", theme.gold, "written"
    end
    local type_name = e.type and content.scenes[e.type] and content.scenes[e.type].name or nil
    local where = (e.loc or e.tag == "past" or e.tag == "tonight") and (e.where or "") or "No place yet"
    if e.tag == "zero" then
        where = "Around the table, before week 1"
    end
    local where_line = where .. (type_name and ("  -  " .. type_name) or "")
    local lh_head = kit.line_height(st.head)
    local h = lh_head + 2 + M.height(where_line, st.place, tw) + 4 + M.height(text, st.body, tw) + 8
    if e.focus then
        h = h + 8
    end
    return { h = h, draw = function(x, y)
        local col = story_color(d)
        if e.focus then
            kit.box(x - 6, y - 6, w + 12, h - 2, kit.rgba("#e8b04a", 0.12), { radius = 8 })
        end
        -- The timeline: a dot per scene, a thread between them.
        if not last then
            kit.box(x + 6, y + 14, 2, h - 6, vmath.vector4(col.x, col.y, col.z, 0.35), { round = false })
        end
        local settled = e.tag == "past" or e.tag == "zero"
        kit.dot(x + 7, y + 9, settled and 12 or 14, settled and col or (e.focus and theme.orange or theme.gold))
        local tx = x + st.indent
        kit.text(tx, y, head, st.head, settled and theme.dim or theme.gold)
        if right then
            local rw = kit.width(right, st.head)
            local rx = x + w - rw
            kit.text(rx, y, right, st.head, rcol)
            local under = kit.box(rx, y + lh_head - 3, rw, 1.5, rcol, { round = false })
            hotspot(app, term_kw(rterm, right), rx, y, rw, lh_head, under)
        end
        local yy = y + lh_head + 2
        -- Where, and what kind of scene (hover the kind for what it means).
        local place_kws = {}
        for _, k in ipairs(kws) do
            table.insert(place_kws, k)
        end
        if type_name then
            table.insert(place_kws, 1, term_kw(e.type, type_name))
        end
        yy = M.rich(app, tx, yy, tw, where_line, st.place, theme.text, place_kws, { on_story = on_story })
        yy = M.rich(app, tx, yy + 4, tw, text, st.body, (e.tag == "past" or e.tag == "zero") and theme.text or kit.rgba("#e9dcc3"), kws,
            { on_story = on_story })
    end }
end

local function heading(text, font, color, kw)
    font = font or "ui14"
    return { h = kit.line_height(font) + 6, draw = function(x, y)
        kit.text(x, y + 2, text, font, color or theme.gold)
    end }
end

local function para_block(app, text, font, color, w, kws, on_story, indent)
    indent = indent or 0
    return { h = M.height(text, font, w - indent) + 6, draw = function(x, y)
        M.rich(app, x + indent, y, w - indent, text, font, color, kws, { on_story = on_story })
    end }
end

-- Everything under the title, in reading order. Returns blocks and the one to keep in view.
local function story_blocks(app, view, w, mode, kws, on_story)
    local st = STYLE[mode]
    local d = view.def
    local blocks = {}
    local focus
    local function add(b)
        table.insert(blocks, b)
        return #blocks
    end
    if view.premise and view.premise ~= "" then
        add(para_block(app, view.premise, st.body, theme.text, w, kws, on_story))
    end
    if view.quote then
        local label = "In " .. view.quote.who .. "'s words, at the first session:"
        add({ h = kit.line_height("ui14") + 2, draw = function(x, y)
            kit.text(x, y, label, "ui14", theme.faint)
        end })
        add(para_block(app, '"' .. view.quote.text .. '"', st.quote, theme.log.quote, w, kws, on_story, 12))
    end
    if view.woven and #view.woven > 0 then
        local names = {}
        for _, id in ipairs(view.woven) do
            local od = storylines.def(app.campaign, id)
            if od then
                table.insert(names, od.name)
            end
        end
        add(para_block(app, "Woven with " .. util.join_names(names) .. ".", "ui14", theme.dim, w, kws, on_story))
    end
    add(heading("THE STORY SO FAR", st.head))
    if #view.entries == 0 then
        local none = d.kind == "backstory"
            and ("Not on the table yet. Put one of " .. (d.short or "their") .. "'s cards on a scene and it starts here.")
            or "Not started yet. It opens the first time one of its cards plays."
        add(para_block(app, none, st.body, theme.faint, w, kws, on_story))
    end
    local live_focus, newest
    for i, e in ipairs(view.entries) do
        local idx = add(entry_block(app, e, w, st, kws, d, i == #view.entries, on_story))
        if e.focus then
            focus = idx
        end
        if e.tag == "tonight" then
            live_focus = idx
        end
        if e.tag == "past" or e.tag == "tonight" or e.tag == "zero" then
            newest = idx
        end
    end
    -- Left to itself, the log opens on what happened last (playtest, October 13: it opened on
    -- Session Zero every time, and the latest session sat out of sight below it).
    focus = focus or live_focus or newest
    if #view.leads > 0 then
        local hb = heading("WAITING IN YOUR DECK", st.head)
        local lw = kit.width("WAITING IN YOUR DECK", st.head)
        add({ h = hb.h, draw = function(x, y)
            hb.draw(x, y)
            local under = kit.box(x, y + kit.line_height(st.head) + 1, lw, 1.5, theme.gold, { round = false })
            hotspot(app, term_kw("lead", "Waiting in your deck"), x, y, lw, kit.line_height(st.head) + 2, under)
        end })
        for k, l in ipairs(view.leads) do
            if k <= 6 then
                add(para_block(app, "- " .. l.name .. (l.when == "next week" and " (next week)" or ""), st.body, theme.dim, w,
                    kws, on_story, 8))
            end
        end
        if #view.leads > 6 then
            add(para_block(app, "and " .. util.int(#view.leads - 6) .. " more.", "ui14", theme.faint, w, kws, on_story, 8))
        end
    end
    return blocks, focus
end

-- The cast, as lines of names: People, Places, Heroes, Factions.
local function cast_lines(app, view)
    local c = view.cast or {}
    local out = {}
    local function names(list, fn)
        local n = {}
        for _, it in ipairs(list) do
            table.insert(n, fn(it))
        end
        return table.concat(n, ", ")
    end
    if #c.people > 0 then
        table.insert(out, { "PEOPLE", names(c.people, function(p)
            if p.extra then
                return p.name
            end
            return p.name .. (p.met and p.label and (" (" .. string.lower(p.label) .. ")") or " (not met)")
        end) })
    end
    if #c.places > 0 then
        table.insert(out, { "PLACES", names(c.places, function(p)
            return p.name .. (p.visits == 0 and " (not yet)" or "")
        end) })
    end
    if #c.factions > 0 then
        table.insert(out, { "FACTIONS", names(c.factions, function(f)
            return f.name
        end) })
    end
    if #c.heroes > 0 then
        table.insert(out, { "HEROES", names(c.heroes, function(h)
            return h.char .. (h.own and " (whose story it is)" or "")
        end) })
    end
    return out
end

-- Scrolled blocks between top and bottom: the first block shown is scroll (or, left to itself,
-- whatever keeps `focus` in view). Returns the first and last shown, and where the drawing stopped.
local function draw_scrolled(blocks, x, top, bottom, gap, first, focus)
    local avail = bottom - top
    if not first then
        first = 1
        if focus then
            local sum = 0
            for i = focus, 1, -1 do
                sum = sum + blocks[i].h + gap
                if sum > avail then
                    break
                end
                first = i
            end
        end
    end
    first = util.clamp(first, 1, math.max(1, #blocks))
    local y, last = top, first - 1
    for i = first, #blocks do
        local b = blocks[i]
        if i > first and y + b.h > bottom then
            break
        end
        b.draw(x, y)
        y = y + b.h + gap
        last = i
    end
    return first, last, y
end

-- A page up or down: the block the page should start at next.
local function page_from(blocks, first, last, avail, gap, dir)
    if dir > 0 then
        return math.min(#blocks, math.max(first + 1, last))
    end
    local n, sum = first, 0
    for i = first, 1, -1 do
        sum = sum + blocks[i].h + gap
        if sum > avail then
            break
        end
        n = i
    end
    return math.max(1, math.min(n, first - 1))
end
M.page_from = page_from

-- A notch of the wheel: at least a few lines' worth, however small the blocks are.
local function notch_from(heights, first, dir)
    local n, moved = first, 0
    repeat
        local nxt = n + dir
        if nxt < 1 or nxt > #heights then
            break
        end
        moved = moved + (heights[dir > 0 and n or nxt] or 0)
        n = nxt
    until moved >= 90
    return n
end

local function heights_of(blocks)
    local hs = {}
    for i, b in ipairs(blocks) do
        hs[i] = b.h
    end
    return hs
end

-- "More above" over the top, "More below" right where the drawing stopped, so the blank under a
-- block too tall to fit never reads as the end (playtest, October 13: "Later" read as "remind me
-- later", and the gap read as the end of the story).
local function scroll_buttons(app, x, top, stop, w, first, last, total, key, on_move)
    if first > 1 then
        local label = "More above"
        local bw = kit.width(label, "ui14") + 24
        kit.button(x + w - bw, top - 30, bw, 24, label, function()
            on_move(-1)
        end, { font = "ui14", key = key .. "_up", color = theme.panel3 })
    end
    if last < total then
        local label = "More below"
        local bw = kit.width(label, "ui14") + 24
        kit.button(x + w - bw, stop - 4, bw, 24, label, function()
            on_move(1)
        end, { font = "ui14", key = key .. "_down", color = theme.panel3 })
    end
end

-- The notebook page -------------------------------------------------------------------------

local function heat_label(heat)
    local words = { warm = "Moving", cooling = "Cooling", cold = "Touch it this week", loose = "Loose end",
                    unopened = "Not started", resolved = "Tied off", ended = "Over" }
    local cols = { warm = theme.green, cooling = theme.gold, cold = theme.orange, loose = theme.red, unopened = theme.faint,
                   resolved = theme.teal, ended = theme.faint }
    return words[heat] or heat, cols[heat] or theme.dim
end
M.heat_label = heat_label

function M.chosen(app, list)
    local id = app.storylog_id
    for _, it in ipairs(list) do
        if it.def.id == id then
            return id
        end
    end
    return list[1] and list[1].def.id or nil
end

function M.page(app, x, y, w, h)
    local c = app.campaign
    local night, prep = live_night(app), this_prep(app)
    local list = chronicle.list(c, prep, night)
    local id = M.chosen(app, list)
    app.storylog_id = id
    if not id then
        kit.text(x, y, "No storylines yet.", "ui18", theme.faint)
        return
    end
    local function redraw()
        if app.refresh_notes then
            app.refresh_notes()
        end
    end
    local function pick(sid)
        app.storylog_id = sid
        app.storylog_scroll = nil
        redraw()
    end
    -- The storylines, down the left.
    local lw = 262
    local by = y
    for _, it in ipairs(list) do
        local d = it.def
        local on = d.id == id
        local bh = 50
        if by + bh > y + h then
            break
        end
        kit.button(x, by, lw, bh, "", function()
            pick(d.id)
        end, { color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "storylog_pick_" .. d.id,
               on_hover = M.glance_hover(app, d.id, x + lw + 12, by, not on and "Click to read it all." or nil) })
        kit.box(x, by, 6, bh, story_color(d), { radius = 3 })
        -- Its icon (October 15), the one it wears on the cards.
        marks().storyline(app, d.id, x + 14, by + 9, 30)
        local nx = x + 52
        local nfont = kit.width(d.name, "ui18b") <= lw - 64 and "ui18b" or "ui14"
        kit.text(nx, by + 6, d.name, nfont, it.started and theme.text or theme.dim, { w = lw - 64 })
        local heat = storylines.heat(c, d.id)
        local hw, hc = heat_label(heat)
        kit.text(nx, by + 28, hw, "ui14", hc)
        if it.touched then
            local tag = night and "Tonight" or "On the board"
            kit.text(x + lw - 12, by + 28, tag, "ui14", theme.gold, { pivot = gui.PIVOT_NE })
        end
        by = by + bh + 6
    end
    -- The chosen one.
    local view = chronicle.story(c, id, { night = night, prep = prep })
    local kws = chronicle.keywords(c)
    local mx, mw = x + lw + 24, 560
    local d = view.def
    kit.box(mx, y, 6, 40, story_color(d), { radius = 3 })
    local tx = mx + 18
    marks().storyline(app, d.id, tx, y, 40)
    tx = tx + 50
    kit.text(tx, y - 2, d.name, "title30", theme.text, { w = mx + mw - tx })
    -- Point at the title: the whole story at a glance.
    kit.button(tx, y - 2, math.min(kit.width(d.name, "title30"), mx + mw - tx), 40, "", nil,
        { color = kit.rgba("#000000", 0), hover = kit.rgba("#ffffff", 0.04), key = "storylog_title",
          on_hover = M.glance_hover(app, id, tx, y + 42) })
    local hw, hc = heat_label(view.heat)
    local kind = string.upper(d.kind == "backstory" and "Backstory" or (d.kind or "story"))
    kit.text(tx, y + 38, kind .. "  -", "ui14", theme.faint)
    local kx = tx + kit.width(kind .. "  - ", "ui14")
    kit.text(kx, y + 38, hw, "ui14", hc)
    local under = kit.box(kx, y + 38 + kit.line_height("ui14") - 3, kit.width(hw, "ui14"), 1.5, hc, { round = false })
    hotspot(app, term_kw(view.heat, hw), kx, y + 38, kit.width(hw, "ui14"), kit.line_height("ui14"), under)
    local top, bottom = y + 74, y + h - 32
    local blocks, focus = story_blocks(app, view, mw, "page", kws, pick)
    local first, last, stop = draw_scrolled(blocks, mx, top, bottom, STYLE.page.gap, app.storylog_scroll, focus)
    app.storylog_first = first
    app.storylog_count = #blocks
    app.storylog_heights = heights_of(blocks)
    scroll_buttons(app, mx, top, math.min(stop, bottom + 4), mw, first, last, #blocks, "storylog", function(dir)
        app.storylog_scroll = page_from(blocks, first, last, bottom - top, STYLE.page.gap, dir)
        redraw()
    end)
    if first > 1 or last < #blocks then
        kit.text(mx, bottom + 8, (last < #blocks and "More below. " or "") .. "Wheel to scroll", "ui14", theme.faint)
    end
    app.storylog_area = { mx, top - 30, mw, bottom - top + 60 }
    -- Who and where, down the right.
    local rx, rw = mx + mw + 30, x + w - (mx + mw + 30)
    local ry = y
    for _, ln in ipairs(cast_lines(app, view)) do
        if ry + 60 > y + h then
            break
        end
        kit.text(rx, ry, ln[1], "ui14", theme.gold)
        ry = ry + 22
        local hgt = M.height(ln[2], "ui14", rw)
        if ry + hgt > y + h then
            break
        end
        ry = M.rich(app, rx, ry, rw, ln[2], "ui14", theme.dim, kws, { on_story = pick }) + 14
    end
end

-- Scroll the page or the panel under the pointer: true if it took the wheel.
function M.on_wheel(app, x, y, dir)
    local ly = kit.H - y
    local function inside(r)
        return r and x >= r[1] and x <= r[1] + r[3] and ly >= r[2] and ly <= r[2] + r[4]
    end
    if app.overlay == "notes" and app.notes_tab == "storylog" then
        if inside(app.storylog_area) then
            local n = util.clamp(notch_from(app.storylog_heights or {}, app.storylog_first or 1, dir), 1,
                math.max(1, app.storylog_count or 1))
            if n ~= app.storylog_first then
                app.storylog_scroll = n
                if app.refresh_notes then
                    app.refresh_notes()
                end
            end
        end
        return true
    end
    if app.screen == "prep" and app.story_panel and not app.overlay and not app.ask and not app.convo then
        local p = M.PANEL
        if inside({ p.x, p.y, p.w, p.h }) then
            local sp = app.story_panel
            local n = util.clamp(notch_from(sp.heights or {}, sp.first or 1, dir), 1, math.max(1, sp.count or 1))
            if n ~= sp.first then
                sp.scroll = n
                app.refresh()
            end
            return true
        end
    end
    return false
end

-- The prep board's story panel ---------------------------------------------------------------

-- Open it on the storylines a card moves (backstories first), keeping the card in view.
function M.open_panel(app, ids, focus)
    if not ids or #ids == 0 then
        return
    end
    local list = {}
    for _, id in ipairs(ids) do
        if string.sub(id, 1, 3) == "bs_" then
            table.insert(list, id)
        end
    end
    for _, id in ipairs(ids) do
        if string.sub(id, 1, 3) ~= "bs_" then
            table.insert(list, id)
        end
    end
    app.story_panel = { ids = list, id = list[1], focus = focus }
end

-- A placed card that moves a storyline opens the panel (unless the DM turned that off): the first
-- time each storyline moves this week, or whenever the panel is already open. Playtest, October
-- 13: opening on every placement kept the table's forecasts covered all through prep.
function M.on_placed(app, c)
    if not c then
        return
    end
    local camp = app.campaign
    local ids = storylines.of_card(camp, c)
    if #ids == 0 then
        return
    end
    local week = camp.week
    if not app.story_shown or app.story_shown.week ~= week then
        app.story_shown = { week = week, ids = {} }
    end
    local fresh = false
    for _, id in ipairs(ids) do
        if not app.story_shown.ids[id] then
            fresh = true
        end
        app.story_shown.ids[id] = true
    end
    if app.story_panel then
        M.open_panel(app, ids, c.id)
        return
    end
    if not fresh then
        return
    end
    -- It opens by itself the first time a card moves a story (so you know it's there), then only
    -- when asked to every week; after that, a note on the drawer says which story moved (the
    -- newcomer playtest, October 16: the panel kept covering the board mid-prep).
    local weekly = camp.story_auto == "weekly"
    if not camp.story_auto_off and (weekly or not camp.story_auto_seen) then
        camp.story_auto_seen = true
        M.open_panel(app, ids, c.id)
        return
    end
    local names = {}
    for _, id in ipairs(ids) do
        local d = storylines.def(camp, id)
        table.insert(names, d and (d.short or d.name) or id)
    end
    app.toast = "This card moves " .. util.join_names(names) .. ". Press S to read the story so far."
    app.toast_tone = "info"
end

-- S on the prep board: the panel on whatever's most pressing, or closed again.
function M.toggle_panel(app)
    if app.story_panel then
        app.story_panel = nil
        M.drop_hover(app)
        return
    end
    local list = chronicle.list(app.campaign, app.campaign.prep, nil)
    if list[1] then
        app.story_panel = { ids = { list[1].def.id }, id = list[1].def.id, browse = true }
    end
end

function M.panel(app)
    local sp = app.story_panel
    local c = app.campaign
    if not sp or not c.prep then
        return
    end
    local P = M.PANEL
    local view = chronicle.story(c, sp.id, { prep = c.prep, focus = sp.focus })
    if not view then
        app.story_panel = nil
        return
    end
    local d = view.def
    local x, y, w, h = P.x, P.y, P.w, P.h
    kit.box(x - 2, y - 2, w + 4, h + 4, story_color(d), { radius = 12 })
    -- The panel takes the clicks that land on it (nothing under it gets them).
    kit.button(x, y, w, h, "", function() end, { color = theme.bg, hover = theme.bg, radius = 11, key = "story_panel_bg" })
    local ix, iw = x + 16, w - 32
    kit.text(ix, y + 12, "STORY LOG", "ui14", theme.gold)
    kit.button(x + w - 70, y + 8, 56, 26, "Close", function()
        app.story_panel = nil
        M.drop_hover(app)
        app.refresh()
    end, { font = "ui14", key = "story_panel_close" })
    kit.button(x + w - 198, y + 8, 120, 26, "In your notes", function()
        app.storylog_id = sp.id
        app.storylog_scroll = nil
        if app.open_notes then
            app.open_notes("storylog")
        end
    end, { font = "ui14", key = "story_panel_notes" })
    local ty = y + 42
    -- A tab per storyline the card moves (or, browsing, a way to step through them all).
    local function choose(id)
        sp.id = id
        sp.scroll = nil
        M.drop_hover(app)
        app.refresh()
    end
    local tabs = sp.ids
    if sp.browse then
        tabs = {}
        for _, it in ipairs(chronicle.list(c, c.prep, nil)) do
            if it.started or it.touched then
                table.insert(tabs, it.def.id)
            end
        end
    end
    if #tabs > 1 then
        local tx = ix
        for _, id in ipairs(tabs) do
            local td = storylines.def(c, id)
            if td then
                local label = td.kind == "backstory" and (td.short .. "'s story") or td.short
                local bw = kit.width(label, "ui14") + 30
                if tx + bw > ix + iw then
                    tx = ix
                    ty = ty + 30
                end
                kit.button(tx, ty, bw, 26, "", function()
                    choose(id)
                end, { color = id == sp.id and theme.go or theme.panel2, hover = theme.button_hover, key = "story_tab_" .. id,
                       on_hover = M.glance_hover(app, id, x - 560, ty) })
                marks().storyline(app, id, tx + 5, ty + 5, 16)
                kit.text(tx + 24, ty + 4, label, "ui14", theme.text)
                tx = tx + bw + 6
            end
        end
        ty = ty + 34
    end
    -- The title.
    local tx = ix
    marks().storyline(app, sp.id, tx, ty, 30)
    tx = tx + 40
    kit.text(tx, ty, d.name, "ui22b", theme.text, { w = ix + iw - tx })
    kit.button(tx, ty, math.min(kit.width(d.name, "ui22b"), ix + iw - tx), 30, "", nil,
        { color = kit.rgba("#000000", 0), hover = kit.rgba("#ffffff", 0.05), key = "story_panel_title",
          on_hover = M.glance_hover(app, sp.id, x - 560, ty) })
    ty = ty + kit.text_height(d.name, "ui22b", ix + iw - tx)
    local hw, hc = heat_label(view.heat)
    kit.text(tx, ty, hw, "ui14", hc)
    local under = kit.box(tx, ty + kit.line_height("ui14") - 3, kit.width(hw, "ui14"), 1.5, hc, { round = false })
    hotspot(app, term_kw(view.heat, hw), tx, ty, kit.width(hw, "ui14"), kit.line_height("ui14"), under)
    ty = ty + 30
    local kws = chronicle.keywords(c)
    local blocks, focus = story_blocks(app, view, iw, "panel", kws, choose)
    -- The cast at the end of the scroll.
    for _, ln in ipairs(cast_lines(app, view)) do
        local text = ln[2]
        local label = ln[1]
        table.insert(blocks, { h = kit.line_height("ui14") + 2 + M.height(text, "ui14", iw) + 4, draw = function(bx, by)
            kit.text(bx, by, label, "ui14", theme.gold)
            M.rich(app, bx, by + kit.line_height("ui14") + 2, iw, text, "ui14", theme.dim, kws, { on_story = choose })
        end })
    end
    local top, bottom = ty + 4, y + h - 62
    local first, last, stop = draw_scrolled(blocks, ix, top, bottom, STYLE.panel.gap, sp.scroll, focus)
    sp.first, sp.count, sp.heights = first, #blocks, heights_of(blocks)
    scroll_buttons(app, ix, top + 4, math.min(stop, bottom + 2), iw, first, last, #blocks, "story_panel", function(dir)
        sp.scroll = page_from(blocks, first, last, bottom - top, STYLE.panel.gap, dir)
        app.refresh()
    end)
    -- Whether it opens by itself.
    local auto = c.story_auto == "weekly" and not c.story_auto_off
    kit.button(ix, y + h - 34, 22, 22, auto and "x" or "", function()
        c.story_auto = (not auto) and "weekly" or nil
        c.story_auto_off = nil
        app.refresh()
    end, { font = "ui14", color = theme.panel3, key = "story_panel_auto" })
    kit.text(ix + 30, y + h - 32, "Open by itself each week a story moves", "ui14", theme.dim)
    kit.text(x + w - 16, y + h - 32, "S", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
end

return M
