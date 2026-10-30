-- The session report: how each player felt, what moved, and the best moments.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local content = require "game.model.content"
local score = require "game.model.score"
local empathy = require "game.model.empathy"
local util = require "game.model.util"
local levelup_view = require "game.ui.levelup_view"
local keepsakes = require "game.model.keepsakes"
local panels = require "game.ui.panels"

local M = {}

local function tier_color(tier)
    return ({ loved = theme.green, fun = theme.teal, fine = theme.gold, bored = theme.orange, out = theme.red })[tier] or theme.dim
end

local MARK_COLOR = { ["++"] = "green", ["+"] = "green", ["--"] = "red", ["-"] = "red", ["="] = "faint" }

-- The report (M8, B7) in the GDD's five parts: the recap, how the table felt, the verdict, what
-- it earned, and the wrap-up. The recap is the DM's: pick a title, pin a beat for the scrapbook,
-- cut one, add a note. Snapshots re-stage the moment on the table.

local recap_mod = require "game.model.recap"

local VERDICT_COLOR = { ["One for the stories"] = "gold", ["Great session"] = "green", ["Good session"] = "teal",
                        Okay = "dim", ["Rough night"] = "orange" }

-- What the wrap-up lists: the story, the table, the world, the deck (the old report's strip).
local function wrapup_items(app, rep)
    local items = {}
    -- v2: what the museum kept from tonight.
    local mu = rep.museum
    if mu then
        local MODULE = require("game.model.adventure").data
        local names = {}
        for _, r in ipairs(mu.rooms or {}) do
            local room = MODULE.rooms[r.room]
            if room and not room.virtual then
                table.insert(names, room.name)
            end
        end
        if #names > 0 then
            table.insert(items, { "Tonight: " .. util.join_names(names) .. ".", theme.text })
        end
        for _, id in ipairs(mu.marks or {}) do
            local m = MODULE.marks[id]
            if m then
                table.insert(items, { "Euryale's card: " .. m.name .. ". " .. m.showdown .. ".", theme.gold })
            end
        end
        for _, h in ipairs(mu.harsh or {}) do
            table.insert(items, h.earned and { "A harsh call landed as fair: they knew the risk.", theme.green }
                or { "A harsh call felt arbitrary. Nobody had been warned.", theme.orange })
        end
        if mu.stopped then
            table.insert(items, { "You stopped mid-museum: " .. mu.stopped .. " is still ahead.", theme.dim })
        end
        if mu.ending then
            table.insert(items, { "The museum is done. Ending: " .. MODULE.endings[mu.ending].name .. ".", theme.gold })
        else
            table.insert(items, { mu.where, theme.dim })
        end
    end
    -- At the table first: what needs the DM's attention before next week.
    for _, st in ipairs(rep.table or {}) do
        local col = st.state == "fixed" and theme.green or (st.state == "active" and theme.red or theme.orange)
        table.insert(items, { st.text, col })
    end
    local SAFETY = {
        xcard = "{name} tapped the X-card. It worked like it should.",
        hurt = "Something {name} asked about at Session Zero came up anyway.",
        promise = "You broke a Session Zero promise to {name}.",
    }
    for _, e in ipairs(rep.safety or {}) do
        local line = SAFETY[e.kind]
        if line then
            local p = app.campaign:player(e.key)
            table.insert(items, { util.fill(line, { name = p.name }), e.kind == "xcard" and theme.dim or theme.orange })
        end
    end
    if rep.broken == "look_it_up" then
        table.insert(items, { "You never posted the ruling you promised to look up. Sam noticed.", theme.orange })
    end
    -- Between the players (A17): the friendships under strain after tonight.
    do
        local rapport = require "game.model.rapport"
        for k, st in ipairs(rapport.strained(app.campaign)) do
            if k <= 2 then
                table.insert(items, { (st.stage == "live" and "Rift: " or "Strained: ") .. st.hurt.name .. " is fed up with "
                    .. st.doer.char .. ". A one-on-one or a word with the table would help.", st.stage == "live" and theme.red or theme.orange })
            end
        end
    end
    if rep.table_text then
        table.insert(items, { rep.table_text, theme.dim })
    end
    -- The storylines (game/model/storylines.lua): dropped long enough for the table to notice,
    -- back from the dead, spread too thin, and what moved.
    local sl = rep.storylines
    if sl then
        local storylines = require "game.model.storylines"
        local function names(ids)
            local n = {}
            for _, id in ipairs(ids) do
                local d = storylines.def(app.campaign, id)
                if d then
                    table.insert(n, d.kind == "backstory" and (d.short .. "'s story") or util.lower_first(d.short))
                end
            end
            return util.join_names(n)
        end
        if #sl.noticed > 0 then
            table.insert(items, { "The table noticed you dropped " .. names(sl.noticed) .. ". It'll wear on them until it comes back.",
                                  theme.red })
        end
        if #sl.back > 0 then
            table.insert(items, { "Back from the dead: " .. names(sl.back) .. ". Nobody saw it coming.", theme.gold })
        end
        if sl.thin then
            table.insert(items, { "Spread thin: " .. util.int(sl.thin) .. " separate storylines in one night. The table lost the thread.",
                                  theme.orange })
        end
        if #sl.cold > 0 then
            table.insert(items, { "Cooling: " .. names(sl.cold) .. ". Next week, or the table notices.", theme.orange })
        end
        if #sl.resolved > 0 then
            table.insert(items, { "Tied off: " .. names(sl.resolved) .. ".", theme.teal })
        end
        if #sl.opened > 0 then
            table.insert(items, { "A new storyline: " .. names(sl.opened) .. ".", theme.green })
        end
    end
    -- The story: what they found, what's still open, what moved, what tonight opened.
    for _, c in ipairs(rep.clues or {}) do
        table.insert(items, { "Found out: " .. c, theme.gold })
    end
    for _, t in ipairs(rep.threads or {}) do
        table.insert(items, { "- " .. t, theme.text })
    end
    local ledger = require "game.model.ledger"
    for k, ch in ipairs(rep.moved or {}) do
        if k <= 3 and ch.kind ~= "standing" then
            local worse = ch.to == "Hostile" or ch.to == "Wary" or ch.kind == "status"
            table.insert(items, { ledger.change_text(app.campaign, ch), worse and theme.orange or theme.teal })
        end
    end
    local opened = {}
    for _, o in ipairs(rep.opened or {}) do
        local c = content.components[o.id]
        if c and not c.agenda then
            table.insert(opened, c.name)
        end
    end
    if #opened > 0 then
        table.insert(items, { "Tonight opened: " .. util.join_names(opened) .. ". They're in next week's deck.", theme.green })
    end
    -- Crossovers and changes of course (A18).
    do
        local styles = require "game.model.styles"
        local by = {}
        for _, x in ipairs(rep.crossed or {}) do
            local c = content.components[x.id]
            if c then
                by[x.to] = by[x.to] or { via = x.via, names = {} }
                table.insert(by[x.to].names, c.name)
            end
        end
        for to, g in pairs(by) do
            local via = content.components[g.via]
            -- (October 15: "Find old Dunnet the prospector leads on: ..." read as one garbled line.)
            table.insert(items, { "New in your deck" .. (via and (", from \"" .. (via.short or via.name) .. "\"") or "")
                .. " (" .. styles.def(to).name .. "): " .. util.join_names(g.names) .. ".", theme.teal })
        end
        if rep.course then
            table.insert(items, { "The campaign changes course: from now on it's " .. styles.def(rep.course).name .. ".", theme.gold })
        end
    end
    if rep.planted then
        table.insert(items, { "Planted: " .. content.seeds[rep.planted].name, theme.teal })
    end
    -- Running jokes born tonight (B5).
    for _, j in ipairs(rep.jokes or {}) do
        table.insert(items, { "A running joke is born: " .. j.text .. ".", theme.purple })
    end
    for k, c in ipairs(rep.canon or {}) do
        if k <= 3 then
            table.insert(items, { "Now canon: " .. c, theme.dim })
        end
    end
    if #items == 0 then
        table.insert(items, { "The story didn't move tonight. This week's story cards are how it moves.", theme.faint })
    end
    return items
end

-- (The GDD's part numbers came off the headings, October 20: one of the five, what it earned,
-- has no heading, so they read 1, 2, 3, 5.)
local function head(x, y, n, text)
    kit.text(x, y, text, "ui14", theme.gold)
    return y + 24
end

-- 1. The recap.
local function recap_panel(app, rep, x, y, w, h)
    local r = rep.recap
    kit.box(x, y, w, h, theme.panel, { radius = 10 })
    local ty = head(x + 16, y + 12, 1, "THE RECAP")
    kit.text(x + w - 16, y + 12, "For your eyes only. Pin a beat to keep it; cut one to drop it.", "ui14", theme.faint,
        { pivot = gui.PIVOT_NE })
    if not r or #r.beats == 0 then
        kit.text(x + 16, ty + 4, "A quiet night. Nothing anyone will bring up later.", "ui18", theme.faint)
        return
    end
    local bw = w - 32 - 120
    for k, b in ipairs(r.beats) do
        local th = kit.text_height(b.text, "ui18", b.clue and (bw - 26) or bw)
        if ty + th > y + h - 166 then
            break
        end
        -- What they found out wears its storyline's icon (October 15), as on the cards.
        local mk = b.clue and require("game.model.lore").clue_mark(app.campaign, b.clue)
        local tx = x + 16
        if mk then
            require("game.ui.lore_marks").mark(mk, x + 14, ty + 1, 20)
            tx = x + 42
        end
        kit.text(tx, ty, b.text, "ui18", b.cut and theme.faint or (b.pinned and theme.gold or theme.text),
            { w = bw - (tx - x - 16) })
        kit.button(x + w - 128, ty - 2, 54, 26, b.pinned and "Pinned" or "Pin", function()
            b.pinned = not b.pinned
            b.cut = nil
            app.refresh()
        end, { font = "ui14", color = b.pinned and theme.go or theme.panel2, hover = theme.button_hover, key = "recap_pin_" .. k })
        kit.button(x + w - 68, ty - 2, 52, 26, b.cut and "Undo" or "Cut", function()
            b.cut = not b.cut
            b.pinned = nil
            app.refresh()
        end, { font = "ui14", color = theme.panel2, hover = theme.button_hover, key = "recap_cut_" .. k })
        ty = ty + math.max(th, 24) + 8
    end
    -- The DM's note: one line, typed.
    local ny = y + h - 156
    local typing = app.report_note
    kit.box(x + 16, ny, w - 32, 32, typing and theme.panel3 or kit.rgba("#000000", 0.25), { radius = 6 })
    local note = (r.note or "") ~= "" and r.note or (typing and "" or "Add a one-line note...")
    local nf = (r.note or "") ~= "" and "ui18" or "ui14"
    kit.text(x + 26, ny + 7, kit.ellipsize(note .. (typing and "_" or ""), nf, w - 170), nf,
        (r.note or "") ~= "" and theme.text or theme.faint)
    kit.button(x + w - 128, ny + 3, 104, 26, typing and "Done" or "Write", function()
        app.report_note = not app.report_note or nil
        app.refresh()
    end, { font = "ui14", key = "recap_note" })
    -- Snapshots: the night's framed moments. Look at one and the table shows it as it was.
    local sy = y + h - 112
    local snaps = {}
    for _, sn in ipairs(rep.snapshots or {}) do
        table.insert(snaps, sn)
    end
    table.sort(snaps, function(a, b) return (a.weight or 0) > (b.weight or 0) end)
    if #snaps == 0 then
        kit.text(x + 16, sy + 10, "No snapshots tonight. C on game night takes one.", "ui14", theme.faint)
        return
    end
    local sw = (w - 32 - 2 * 10) / 3
    for k = 1, math.min(3, #snaps) do
        local sn = snaps[k]
        local sx = x + 16 + (k - 1) * (sw + 10)
        -- A polaroid: the place on the photo, the moment written underneath (two lines, nothing cut).
        kit.box(sx, sy, sw, 108, kit.rgba("#f7f1e3"), { radius = 4 })
        kit.box(sx + 6, sy + 6, sw - 12, 40, kit.rgba("#2a3a2c"), { radius = 2 })
        local tt = sn.title or ""
        local two = kit.width(tt, "ui14") > sw - 84
        kit.text(sx + 12, two and sy + 8 or sy + 14, tt, "ui14", kit.rgba("#e8e0c8"), { w = sw - 84, lines = 2 })
        -- A caption too long for two lines keeps its first sentence (October 15: they were cut).
        local cap = sn.caption or ""
        if kit.text_height(cap, "ui14", sw - 16) > 3 * kit.line_height("ui14") + 1 then
            cap = string.match(cap, "^(.-[%.!?])%s") or cap
        end
        if kit.text_height(cap, "ui14", sw - 16) > 3 * kit.line_height("ui14") + 1 then
            local head = string.match(cap, "^(.-)[:;]%s")   -- "A stranger drags them out before the end."
            cap = head and (head .. ".") or cap
        end
        kit.text(sx + 8, sy + 50, cap, "ui14", theme.ink, { w = sw - 16, lines = 3 })
        kit.button(sx + sw - 62, sy + 14, 50, 24, "Look", function()
            M.view_snapshot(app, sn)
        end, { font = "ui14", key = "snapshot_" .. k })
    end
end

-- 2. How the table felt: a card per player, the least happy first.
-- Behind the screen (the rebuild's second milestone, October 18): the hidden layer, after the
-- fact. Who moved the story tonight and over the sessions (fills, never numbers), what each player
-- pulled toward and your call on it, what's still owed, and whether the table felt railroaded.
local ANSWER_WORDS = { follow = "You followed it.", weave = "You wove it in.", park = "You parked it", steer = "You steered them back." }

local function pull_line(app, e)
    local text = "Pulled toward " .. e.name .. ". " .. (ANSWER_WORDS[e.answer] or "")
    if e.answer == "park" then
        local o
        for _, x in ipairs(require("game.model.pulls").get(app.campaign).owed) do
            if x.id == e.id and x.key == e.key and x.week == e.week then
                o = x
            end
        end
        text = text .. (o and o.state == "paid" and ", and paid it off." or (": owed by session "
            .. util.int((e.week or 0) + require("game.data.skews").OWED_SESSIONS) .. "."))
    end
    if e.made_true then
        text = text .. " Their theory came true."
    end
    return text
end

local function behind_panel(app, rep, x, y, w, h)
    local pr = rep.pulls or {}
    kit.text(x + w - 16, y + 12, "Only you see this: what they pulled toward.", "ui14",
        theme.faint, { pivot = gui.PIVOT_NE, w = w - 460, lines = 1 })
    local rh = (h - 48 - 40) / 4
    local by_key = {}
    for _, e in ipairs(pr.pulls or {}) do
        by_key[e.key] = by_key[e.key] or {}
        table.insert(by_key[e.key], e)
    end
    local paid_by = {}
    for _, o in ipairs(pr.paid or {}) do
        paid_by[o.key] = o
    end
    for i, row in ipairs(rep.players or {}) do
        local ry = y + 40 + (i - 1) * rh
        kit.dot(x + 50, ry + 34, 56, kit.rgba("#000000", 0.3))
        kit.picture(x + 24, ry + 8, 52, 52, panels.face(row.key))
        kit.text(x + 92, ry + 4, row.name, "ui18b", theme.text)
        kit.text(x + 92 + kit.width(row.name, "ui18b") + 8, ry + 6, row.char, "ui14", theme.dim)
        -- Who moved the story: tonight, and over the sessions so far.
        local bx = x + w - 236
        kit.text(bx, ry + 4, "Moved the story", "ui14", theme.dim)
        kit.text(bx, ry + 24, "Tonight", "ui14", theme.faint)
        kit.bar(bx + 70, ry + 30, 140, 8, math.floor(100 * ((pr.tonight or {})[row.key] or 0) + 0.5), 100, theme.gold)
        kit.text(bx, ry + 44, "So far", "ui14", theme.faint)
        kit.bar(bx + 70, ry + 50, 140, 8, math.floor(100 * ((pr.slice or {})[row.key] or 0) + 0.5), 100, theme.teal)
        local tw = w - 92 - 260
        local ty = ry + 28
        local lines = {}
        for _, e in ipairs(by_key[row.key] or {}) do
            table.insert(lines, { pull_line(app, e), theme.text })
            if e.railroad then
                table.insert(lines, { "That was the second time you steered them back tonight: it felt like railroading.", theme.orange })
            end
        end
        if paid_by[row.key] then
            table.insert(lines, { "You came back to " .. paid_by[row.key].name .. ", like you promised.", theme.green })
        end
        if #lines == 0 then
            table.insert(lines, { row.present == false and "Wasn't at the table." or "No pull tonight.", theme.faint })
        end
        for _, ln in ipairs(lines) do
            local lh = kit.text_height(ln[1], "ui14", tw)
            if ty + lh > ry + rh - 2 then
                break
            end
            kit.text(x + 92, ty, ln[1], "ui14", ln[2], { w = tw })
            ty = ty + lh + 2
        end
    end
    -- What's still owed.
    local owed = pr.owed or {}
    local foot = #owed == 0 and "Nothing owed: no parked pulls waiting." or ""
    if #owed > 0 then
        local parts = {}
        for _, o in ipairs(owed) do
            local p = app.campaign:player(o.key)
            table.insert(parts, (p and p.name or "?") .. ": " .. o.name .. " (by session " .. util.int(o.due) .. ")")
        end
        foot = "Still owed. " .. table.concat(parts, ", ") .. ". They glow on the map."
    end
    kit.text(x + 16, y + h - 34, foot, "ui14", #owed > 0 and theme.orange or theme.faint, { w = w - 32, lines = 1 })
end

local function felt_panel(app, rep, x, y, w, h)
    kit.box(x, y, w, h, theme.panel, { radius = 10 })
    local level = app.campaign:empathy()
    -- Two views of the table: how they felt, and behind the screen.
    local behind = app.report_tab == "behind"
    local n_pulls = #((rep.pulls or {}).pulls or {})
    -- (Not "Behind the screen", October 20: prep and the lore screen use that for the villains'
    -- plans, which only you know.)
    local t1, t2 = "HOW THE TABLE FELT", "WHO MOVED THE STORY" .. (n_pulls > 0 and ("  (" .. util.int(n_pulls)
        .. (n_pulls == 1 and " pull)" or " pulls)")) or "")
    local w1, w2 = kit.width(t1, "ui14") + 20, kit.width(t2, "ui14") + 20
    kit.button(x + 8, y + 6, w1, 26, t1, function()
        app.report_tab = nil
        app.refresh()
    end, { font = "ui14", color = behind and theme.panel or theme.panel3, hover = theme.button_hover,
           text_color = behind and theme.dim or theme.gold, key = "report_tab_felt" })
    kit.button(x + 14 + w1, y + 6, w2, 26, t2, function()
        app.report_tab = "behind"
        app.refresh()
    end, { font = "ui14", color = behind and theme.panel3 or theme.panel, hover = theme.button_hover,
           text_color = behind and theme.gold or theme.dim, key = "report_tab_behind" })
    if n_pulls > 0 and not behind then
        kit.dot(x + 14 + w1 + w2 - 6, y + 10, 10, theme.orange)
    end
    if behind then
        behind_panel(app, rep, x, y, w, h)
        return
    end
    kit.text(x + w - 16, y + 12, "The least happy first.", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    local rh = (h - 48) / 4
    for i, row in ipairs(rep.order or rep.players) do
        local ry = y + 40 + (i - 1) * rh
        local p = app.campaign:player(row.key)
        kit.dot(x + 50, ry + 40, 60, kit.rgba("#000000", 0.3))
        kit.picture(x + 22, ry + 12, 56, 56, require("game.ui.panels").face(row.key))
        kit.text(x + 92, ry + 6, row.name, "ui18b", theme.text)
        kit.text(x + 92 + kit.width(row.name, "ui18b") + 8, ry + 8, row.char, "ui14", theme.dim)
        local standing = rep.standing and rep.standing[row.key]
        if row.on_break then
            kit.text(x + 92, ry + 30, "On a break. A check-in during prep brings them back sooner.", "ui14", theme.orange, { w = w - 300 })
        elseif not row.present then
            kit.text(x + 92, ry + 30, "Couldn't make it this week.", "ui14", theme.orange)
        else
            kit.text(x + 92, ry + 28, row.verdict, "ui18b", tier_color(row.tier))
            kit.bar(x + 92 + 190, ry + 34, 150, 9, empathy.fill(level, row.fun), 100, tier_color(row.tier))
        end
        -- Then what they said, why, and anything the DM should watch: as much as fits the row.
        local tw = w - 330
        local ty = ry + 52
        local lines = {}
        -- Someone leaving says so first: it's the one line the DM can't miss.
        if standing == "left" then
            table.insert(lines, { "Says they need a break.", theme.orange, 1 })
        end
        if row.present and not row.on_break then
            table.insert(lines, { '"' .. (row.quote or "") .. '"', theme.text, 2, true })     -- (their words: no glossary)
            if row.why then
                table.insert(lines, { row.why, theme.dim, 1 })
            end
        end
        if row.suspicion_why then
            table.insert(lines, { "Suspicious of " .. row.suspicion_why .. ".", theme.red, 1 })
        end
        for _, ln in ipairs(lines) do
            local lh = math.min(kit.text_height(ln[1], "ui14", tw), ln[3] * 19)
            if ty + lh > ry + rh - 2 then
                break
            end
            kit.text(x + 92, ty, ln[1], "ui14", ln[2], { w = tw, lines = ln[3], gloss = (not ln[4]) and nil or false })
            ty = ty + lh + 1
        end
        -- Their long-term bars and which way they moved, named as on the prep board (the newcomer
        -- playtest, October 16: four unlabelled icons).
        local bx = x + w - 220
        require("game.ui.gloss").card_spot(bx + 186, ry + 2, 20, 82, "Which way it moved",
            "+ went up tonight, - went down, = about the same. Your Empathy decides how sure you can be.")
        for k, key in ipairs(score.LONG) do
            local by = ry + 10 + (k - 1) * 20
            local read = empathy.long(level, p, key, app.campaign.week, i)
            kit.icon(bx, by - 3, 14, key, theme.long[key])
            kit.text(bx + 19, by - 6, score.LONG_NAMES[key], "ui14", theme.dim)
            if read.lo then
                kit.bar(bx + 112, by, 74, 7, 0, 100, theme.long[key], { range = { read.lo, read.hi } })
            else
                kit.bar(bx + 112, by, 74, 7, read.fill, 100, theme.long[key])
            end
            local mark = row.long and row.long[key] and empathy.mark(level, row.long[key].delta)
            if mark then
                local mc = theme[MARK_COLOR[mark]]
                if key == "suspicion" and mark ~= "=" then
                    mc = (row.long[key].delta > 0) and theme.red or theme.green
                end
                kit.text(bx + 200, by - 6, mark, "ui14", mc, { pivot = gui.PIVOT_NE })
            end
        end
    end
end

function M.build(app)
    local rep = app.campaign.report
    if app.snapshot_view then
        return M.snapshot_overlay(app)
    end
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    kit.text(24, 12, "SESSION " .. util.int(rep.week) .. "  -  REPORT", "ui14", theme.gold)
    -- The title: one of three suggestions.
    local r = rep.recap
    local title = r and r.titles[r.title] or rep.headline
    kit.text(24, 32, title, "title30", theme.text)
    if r and #r.titles > 1 then
        kit.button(24 + kit.width(title, "title30") + 16, 36, 120, 30, "Other title", function()
            r.title = r.title % #r.titles + 1
            app.refresh()
        end, { font = "ui14", key = "recap_title" })
    end
    -- Renamed: say what it was planned as, so it reads as one session with a new name.
    local sub = rep.headline
    if r and r.planned and title ~= r.planned then
        sub = "Planned as \"" .. r.planned .. "\".  " .. (rep.headline or "")
    end
    kit.text(24 + kit.width(title, "title30") + 152, 42, sub, "ui14", theme.dim, { w = 1576 - (24 + kit.width(title, "title30") + 152),
        lines = 1 })
    recap_panel(app, rep, 24, 84, 736, 556)
    kit.gloss_scope({ report = true }, function()
        felt_panel(app, rep, 776, 84, 800, 556)
    end)
    kit.gloss_tags = { report = true, table = true }     -- the boxes along the bottom too
    -- 3. The verdict.
    local y = 652
    kit.box(24, y, 360, 234, theme.panel, { radius = 10 })
    head(40, y + 12, 3, "THE VERDICT")
    local vc = theme[VERDICT_COLOR[rep.verdict] or "text"] or theme.text
    kit.text(40, y + 40, rep.verdict or "", "title30", vc)
    kit.bar(40, y + 86, 328, 12, rep.score or 0, 100, vc)
    kit.text(40, y + 104, "Table Score: everyone's Fun, pulled toward whoever had the worst night.", "ui14", theme.faint, { w = 328 })
    local rr = rep.rolls
    local dice = "Big rolls tonight: " .. util.int(rr.open) .. " in the open, " .. util.int(rr.hidden) .. " behind your screen"
        .. (rr.cooked > 0 and (", " .. util.int(rr.cooked) .. " cooked") or "") .. "." .. (rep.callouts > 0 and " Someone asked to see a roll." or "")
    kit.text(40, y + 150, dice, "ui14", theme.dim, { w = 328 })
    if rep.hype > 0 then
        kit.text(40, y + 200, "That cliffhanger has everyone hooked.", "ui14", theme.gold)
    end
    -- 4. What it earned.
    kit.box(396, y, 380, 234, theme.panel, { radius = 10 })
    head(412, y + 12, 4, "WHAT IT EARNED")
    local ey = y + 40
    local lv = app.campaign:level_status()
    if lv.ready then
        kit.button(412, ey, 348, 40, "Level up to " .. util.int(lv.level + 1), function()
            levelup_view.level_up(app)
        end, { color = lv.overdue and kit.rgba("#8a4a2a") or theme.button, font = "ui18b", key = "level_up" })
        kit.text(586, ey + 44, lv.overdue and "Overdue: the table keeps asking." or (lv.level + 1 == 3
            and "Everyone picks a subclass." or "Everyone gets stronger."), "ui14", lv.overdue and theme.orange or theme.dim,
            { pivot = gui.PIVOT_N })
        ey = ey + 70
    elseif app.campaign.level < content.progression.MAX_LEVEL then
        kit.text(412, ey, "Level " .. util.int(lv.level) .. ". The next level feels earned after "
            .. util.int(content.progression.READY_AFTER) .. " nights.", "ui14", theme.faint, { w = 348 })
        ey = ey + 40
    end
    local earned = {}
    local gift = rep.keepsake
    if gift then
        local gp = app.campaign:player(gift.from)
        table.insert(earned, { "A gift from " .. (gp and gp.name or "the table") .. ": " .. keepsakes.def(gift.id).name
            .. ". It's on your side of the table now.", theme.heart })
    end
    for _, e in ipairs(rep.inspiration or {}) do
        table.insert(earned, { e.text, e.spent and theme.dim or theme.gold })
    end
    local items_mod = require "game.model.items"
    for _, it in ipairs(rep.items or {}) do
        local d = items_mod.def(it.id)
        local who = it.holder and app.campaign:player(it.holder)
        table.insert(earned, { "Earned: " .. d.name .. (who and (". " .. who.char .. " carries it.") or "."), theme.gold })
    end
    for _, id in ipairs(rep.payoffs or {}) do
        table.insert(earned, { "Paid off: " .. content.seeds[id].name, theme.green })
    end
    if #earned == 0 then
        table.insert(earned, { "No items or Inspiration handed out tonight.", theme.faint })
    end
    for _, it in ipairs(earned) do
        local hh = kit.text_height(it[1], "ui14", 348)
        if ey + hh <= y + 226 then
            kit.text(412, ey, it[1], "ui14", it[2], { w = 348 })
            ey = ey + hh + 4
        end
    end
    -- 5. Wrap-up.
    kit.box(788, y, 400, 234, theme.panel, { radius = 10 })
    head(804, y + 12, 5, "WRAP-UP")
    local wy = y + 40
    local more = 0
    for _, it in ipairs(wrapup_items(app, rep)) do
        local hh = kit.text_height(it[1], "ui14", 368)
        if wy + hh <= y + 226 then
            kit.text(804, wy, it[1], "ui14", it[2], { w = 368 })
            wy = wy + hh + 3
        else
            more = more + 1
        end
    end
    if more > 0 then
        kit.text(1172, y + 12, "+" .. util.int(more) .. " in your notes", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    end
    -- The Story log: tonight's scenes, filed under the storylines they moved. (Not in the museum,
    -- v2: the prologue has no storylines; its notebook's Museum tab does that job.)
    if not app.campaign.module then kit.button(904, y + 8, 124, 24, "Story log (S)", function()
        local moved = rep.storylines and rep.storylines.moved or {}
        if moved[1] then
            app.storylog_id = moved[1]
            app.storylog_scroll = nil
        end
        if app.open_notes then
            app.open_notes("storylog")
        end
    end, { font = "ui14", color = theme.panel3, key = "report_story_log" }) end
    -- Empathy, and on to next week.
    local e = rep.empathy
    if e then
        kit.icon(1204, y + 6, 18, "empathy", theme.teal)
        local text = "Empathy: " .. empathy.NAMES[e.level] .. (e.up and ". You read the table better now." or "")
        -- v2: the friends' thoughts you caught tonight, and what you did about them.
        local th = rep.thoughts
        if th and th.shown > 0 then
            text = text .. (e.up and " " or ". ") .. "You caught " .. util.int(th.shown)
                .. (th.shown == 1 and " thought" or " thoughts") .. " and answered " .. util.int(th.answered) .. "."
        end
        kit.text(1230, y + 6, text, "ui14", e.up and theme.teal or theme.dim, { w = 346, lines = 3 })
    end
    kit.gloss_tags = nil
    M.gift_row(app, rep, 1204, 708)
    local closing = M.closing_chapter(app)
    local museum = app.campaign.module ~= nil   -- (v2: the prologue ends on its journey recap)
    kit.button(1204, 790, 372, 56, closing and (museum and "Your table's journey  >" or "Close the first act  >")
        or ("On to session " .. util.int(rep.week + 1) .. "  >"),
        function()
            app.report_note = nil
            M.next(app)
        end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "next_week" })
    kit.text(1390, 852, closing and (museum and "The whole prologue, room by room." or "A look back at the first four sessions.")
        or "Playtest notes are saved after every week.",
        "ui14", theme.faint, { pivot = gui.PIVOT_N })
    if app.quick then
        M.quick_modal(app)
    elseif app.keepsake_shown or keepsakes.waiting(app.campaign) then
        M.keepsake_modal(app)
    end
end

-- Something on top of the report that Enter mustn't skip past: the quick questions, a gift, a
-- snapshot (October 20: Enter went on to next week under the gift and dropped it).
function M.busy(app)
    return app.quick or app.snapshot_view or app.keepsake_shown or keepsakes.waiting(app.campaign)
end

-- A gift from the table (game/model/keepsakes.lua): as everyone packs up, the player whose
-- Goodwill filled hands you something. You choose how to take it; then it's on your side of
-- the table for good.
local function wrapped(x, y, w, h, open)
    if open then
        kit.box(x, y + h * 0.35, w, h * 0.65, kit.rgba("#8a5e38"), { radius = 4 })
        kit.box(x - 6, y + h * 0.35 - 10, w + 12, 14, kit.rgba("#a07848"), { radius = 3 })
        kit.box(x + w / 2 - 5, y + h * 0.35 - 10, 10, h * 0.65 + 10, theme.gold, { round = false })
        return
    end
    kit.box(x, y, w, h, kit.rgba("#9a3a3a"), { radius = 5 })
    kit.box(x + w / 2 - 6, y, 12, h, theme.gold, { round = false })
    kit.box(x, y + h / 2 - 6, w, 12, theme.gold, { round = false })
    kit.dot(x + w / 2 - 12, y - 4, 22, theme.gold)
    kit.dot(x + w / 2 + 12, y - 4, 22, theme.gold)
    kit.dot(x + w / 2, y - 2, 12, kit.rgba("#c8902e"))
end

function M.keepsake_modal(app)
    local camp = app.campaign
    local shown = app.keepsake_shown
    local g = shown and shown.g or keepsakes.waiting(camp)
    if not g then
        app.keepsake_shown = nil
        return
    end
    local def = keepsakes.def(g.id)
    local p = camp:player(g.from)
    local name = p and p.name or "Someone"
    kit.layer("keepsake", true)
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.6), { round = false })
    local x, y, w, h = 450, 190, 700, 500
    kit.box(x - 2, y - 2, w + 4, h + 4, theme.heart, { radius = 16 })
    kit.box(x, y, w, h, theme.bg, { radius = 14 })
    kit.text(x + 30, y + 24, "AS EVERYONE PACKS UP", "ui14", theme.heart)
    kit.dot(x + 50, y + 74, 40, panels.COLORS[g.from] or theme.panel3)
    kit.picture(x + 31, y + 55, 38, 38, panels.face(g.from))
    kit.text(x + 82, y + 52, name .. " hangs back and hands you something.", "ui22b", theme.text, { w = w - 112 })
    kit.text(x + 82, y + 82, "Their Goodwill filled up this week.", "ui14", theme.dim)
    wrapped(x + 40, y + 136, 96, 76, shown ~= nil)
    kit.text(x + 160, y + 128, util.sentence_case(def.name) .. ".", "story22", theme.gold, { w = w - 190 })
    kit.text(x + 160, y + 128 + kit.text_height(util.sentence_case(def.name) .. ".", "story22", w - 190) + 10,
        '"' .. def.line .. '"', "ui18", kit.rgba("#ffd890"), { w = w - 190 })
    if shown then
        kit.text(x + 40, y + 268, shown.said, "ui18", theme.text, { w = w - 80 })
        kit.text(x + 40, y + 268 + kit.text_height(shown.said, "ui18", w - 80) + 12, shown.landed, "ui18b",
            (g.landed or 0) >= 1 and theme.heart or ((g.landed or 0) < 0 and theme.orange or theme.dim), { w = w - 80 })
        kit.text(x + 40, y + h - 120, "It's on your side of the table from now on, every session.", "ui14", theme.faint)
        kit.button(x + w - 260, y + h - 76, 230, 48, "Put it with your things", function()
            app.keepsake_shown = nil
            if app.place_keepsakes then
                app.place_keepsakes(g.id)
            end
            app.refresh()
        end, { color = theme.go, hover = theme.go_hover, font = "ui18b", key = "keepsake_done" })
        return
    end
    kit.text(x + 40, y + 270, "How do you take it?", "ui18b", theme.text)
    for k, r in ipairs(keepsakes.data.REACTIONS) do
        local bx = x + 40 + (k - 1) * 212
        kit.button(bx, y + 306, 200, 54, r.label, function()
            local said, landed = keepsakes.react(camp, r.id)
            if said then
                app.keepsake_shown = { g = g, said = said, landed = landed }
                if app.save_campaign then
                    app.save_campaign()
                end
            end
            app.refresh()
        end, { font = "ui18b", key = "keepsake_" .. r.id })
    end
    kit.text(x + 40, y + 376, "Some players want a fuss made. Some would rather you just use the thing.", "ui14", theme.faint,
        { w = w - 80 })
end

-- New dice for someone who earned it (dice_sets): once a week, after the session. The table
-- notices, and they bring the good mood (and the dice) next week.
function M.gift_row(app, rep, x, y)
    local dice_sets = require "game.model.dice_sets"
    local camp = app.campaign
    local d = dice_sets.get(camp)
    if d.gift_week == camp.week and d.last_gift then
        local p = camp:player(d.last_gift.key)
        kit.picture(x, y + 2, 36, 36, "dice_" .. d.last_gift.set)
        kit.text(x + 44, y, "You gave " .. (p and p.name or "them") .. " the " .. dice_sets.name(d.last_gift.set) .. " set.",
            "ui14", theme.gold, { w = 328 })
        if app.gift_line then
            kit.text(x + 44, y + 20, '"' .. app.gift_line .. '"', "ui14", theme.text, { w = 328, lines = 2 })
        end
        return
    end
    kit.text(x, y, "NEW DICE", "ui14", theme.dim)
    kit.text(x + 84, y, "For whoever earned it. One set a week.", "ui14", theme.faint, { w = 288, lines = 1 })
    local bw = 87
    for i, p in ipairs(camp.players) do
        local bx = x + (i - 1) * (bw + 8)
        local ok = dice_sets.can_gift(camp, p.key) and dice_sets.upgrade_for(camp, p.key) ~= nil
        kit.button(bx, y + 24, bw, 40, "", function()
            local id, line = dice_sets.gift(camp, p.key)
            if id then
                app.gift_line = line
                if app.paint_dice then
                    app.paint_dice()
                end
                if app.save_campaign then
                    app.save_campaign()
                end
            end
            app.refresh()
        end, { enabled = ok, color = theme.panel2, hover = theme.button_hover, key = "gift_" .. p.key })
        kit.picture(bx + 4, y + 28, 32, 32, "dice_" .. dice_sets.of(camp, p.key))
        kit.text(bx + 40, y + 34, p.name, "ui14", ok and theme.text or theme.faint, { w = bw - 42, lines = 1 })
    end
end

-- Looking at a snapshot: the table re-stages the moment and the report steps aside.
function M.view_snapshot(app, sn)
    app.snapshot_view = sn
    if app.restage then
        app.restage(sn)
    end
    app.refresh()
end

function M.snapshot_overlay(app)
    local sn = app.snapshot_view
    kit.box(0, 820, kit.W, 80, kit.rgba("#140e0b", 0.85), { round = false })
    kit.text(40, 834, (sn.title and (sn.title .. ", session " .. util.int(sn.week)) or ("Session " .. util.int(sn.week))), "ui14",
        theme.dim)
    kit.text(40, 852, sn.caption or "", "hand24", kit.rgba("#f3df8a"))
    kit.button(1376, 836, 200, 46, "Back to the report", function()
        app.snapshot_view = nil
        if app.restage then
            app.restage(nil)
        end
        app.refresh()
    end, { font = "ui18b", key = "snapshot_back" })
end

-- Typing the DM's note (B7).
function M.typing(app)
    return app.screen == "report" and app.report_note ~= nil
end

function M.on_text(app, text)
    local r = app.campaign.report and app.campaign.report.recap
    if not r or not text then
        return
    end
    local clean = string.gsub(text, "[^\32-\126]", "")
    r.note = string.sub((r.note or "") .. clean, 1, 90)
    app.refresh()
end

function M.on_backspace(app)
    local r = app.campaign.report and app.campaign.report.recap
    if r and r.note then
        r.note = string.sub(r.note, 1, math.max(0, #r.note - 1))
        app.refresh()
    end
end

-- The last session of the slice leads to the scrapbook instead of another week.
function M.closing_chapter(app)
    local c = app.campaign
    if c.module then
        return c:slice_done() and not app.slice_seen      -- v2: the museum's done: the journey recap
    end
    return c.week == content.arc.SESSIONS and c:slice_done() and not app.slice_seen
end

-- On to next week, by way of two quick playtest questions (M7).
function M.next(app)
    app.report_tab = nil
    local c = app.campaign
    app.gift_line = nil
    app.keepsake_shown = nil
    if app.playtest ~= false and not app.quick_done then
        app.quick = app.quick or { week = c.week }
        app.refresh()
        return
    end
    app.quick, app.quick_done = nil, nil
    if M.closing_chapter(app) then
        app.slice_seen = true
        app.go("slice_end")
    else
        app.go("prep")
    end
end

M.QUICK = {
    { id = "prep", text = "Prep this week felt...", options = { "Satisfying", "Okay", "Like homework" } },
    { id = "watch", text = "Watching it play out...", options = { "Paid off", "Was okay", "Dragged" } },
}

local function answer_quick(app, skipped)
    local q = app.quick
    q.skipped = skipped or nil
    if app.log_line then
        app.log_line(require("game.model.telemetry").week_survey(app.campaign, q.week, q))
    end
    app.quick_done = true
    M.next(app)
end

function M.quick_modal(app)
    local q = app.quick
    kit.layer("quick", true)
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.55), { round = false })
    local x, y, w, h = 440, 250, 720, 380
    kit.box(x, y, w, h, theme.bg, { radius = 14 })
    kit.text(x + 28, y + 22, "TWO QUICK QUESTIONS", "ui14", theme.gold)
    kit.text(x + 28, y + 44, "For the playtest. Tap one in each row.", "ui18", theme.dim)
    local ry = y + 92
    for _, row in ipairs(M.QUICK) do
        kit.text(x + 28, ry, row.text, "ui18b", theme.text)
        for k, label in ipairs(row.options) do
            local bx = x + 28 + (k - 1) * 224
            local on = q[row.id] == label
            kit.button(bx, ry + 30, 212, 48, label, function()
                q[row.id] = label
                if q.prep and q.watch then
                    answer_quick(app)
                else
                    app.refresh()
                end
            end, { color = on and theme.go or theme.button, hover = theme.button_hover, key = "quick_" .. row.id .. "_" .. k })
        end
        ry = ry + 110
    end
    kit.button(x + w - 148, y + h - 58, 120, 38, "Skip", function()
        answer_quick(app, true)
    end, { font = "ui14", key = "quick_skip" })
end

return M
