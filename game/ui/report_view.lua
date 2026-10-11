-- The session report: how each player felt, what moved, and the best moments.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local content = require "game.model.content"
local score = require "game.model.score"
local empathy = require "game.model.empathy"
local util = require "game.model.util"
local levelup_view = require "game.ui.levelup_view"

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
            table.insert(items, { (via and (via.name .. " leads on: ") or "A way on: ") .. util.join_names(g.names)
                .. " (" .. styles.def(to).name .. ") join the deck.", theme.teal })
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

local function head(x, y, n, text)
    kit.text(x, y, util.int(n) .. "  " .. text, "ui14", theme.gold)
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
        local th = kit.text_height(b.text, "ui18", bw)
        if ty + th > y + h - 150 then
            break
        end
        kit.text(x + 16, ty, b.text, "ui18", b.cut and theme.faint or (b.pinned and theme.gold or theme.text), { w = bw })
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
    local ny = y + h - 140
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
    local sy = y + h - 96
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
        kit.box(sx, sy, sw, 80, kit.rgba("#f7f1e3"), { radius = 4 })
        kit.box(sx + 6, sy + 6, sw - 12, 40, kit.rgba("#2a3a2c"), { radius = 2 })
        kit.text(sx + 12, sy + 14, kit.ellipsize(sn.title or "", "ui14", sw - 24), "ui14", kit.rgba("#e8e0c8"))
        kit.text(sx + 8, sy + 50, kit.ellipsize(sn.caption or "", "ui14", sw - 70), "ui14", theme.ink)
        kit.button(sx + sw - 58, sy + 50, 50, 24, "Look", function()
            M.view_snapshot(app, sn)
        end, { font = "ui14", key = "snapshot_" .. k })
    end
end

-- 2. How the table felt: a card per player, the least happy first.
local function felt_panel(app, rep, x, y, w, h)
    kit.box(x, y, w, h, theme.panel, { radius = 10 })
    local level = app.campaign:empathy()
    head(x + 16, y + 12, 2, "HOW THE TABLE FELT")
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
        if row.present and not row.on_break then
            table.insert(lines, { '"' .. (row.quote or "") .. '"', theme.text, 2 })
            if row.why then
                table.insert(lines, { row.why, theme.dim, 1 })
            end
        end
        if row.suspicion_why then
            table.insert(lines, { "Suspicious of " .. row.suspicion_why .. ".", theme.red, 1 })
        end
        if standing == "left" then
            table.insert(lines, { "Says they need a break.", theme.orange, 1 })
        end
        for _, ln in ipairs(lines) do
            local lh = math.min(kit.text_height(ln[1], "ui14", tw), ln[3] * 19)
            if ty + lh > ry + rh - 2 then
                break
            end
            kit.text(x + 92, ty, ln[1], "ui14", ln[2], { w = tw, lines = ln[3] })
            ty = ty + lh + 1
        end
        -- Their long-term bars and which way they moved.
        local bx = x + w - 220
        for k, key in ipairs(score.LONG) do
            local by = ry + 10 + (k - 1) * 20
            local read = empathy.long(level, p, key, app.campaign.week, i)
            kit.icon(bx, by - 3, 14, key, theme.long[key])
            if read.lo then
                kit.bar(bx + 20, by, 150, 7, 0, 100, theme.long[key], { range = { read.lo, read.hi } })
            else
                kit.bar(bx + 20, by, 150, 7, read.fill, 100, theme.long[key])
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
    kit.text(24, 12, "WEEK " .. util.int(rep.week) .. "  -  SESSION REPORT", "ui14", theme.gold)
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
    kit.text(24 + kit.width(title, "title30") + 152, 42, rep.headline, "ui14", theme.dim)
    recap_panel(app, rep, 24, 84, 736, 556)
    felt_panel(app, rep, 776, 84, 800, 556)
    -- 3. The verdict.
    local y = 652
    kit.box(24, y, 360, 234, theme.panel, { radius = 10 })
    head(40, y + 12, 3, "THE VERDICT")
    local vc = theme[VERDICT_COLOR[rep.verdict] or "text"] or theme.text
    kit.text(40, y + 40, rep.verdict or "", "title30", vc)
    kit.bar(40, y + 86, 328, 12, rep.score or 0, 100, vc)
    kit.text(40, y + 104, "Table Score: everyone's Fun, pulled toward whoever had the worst night.", "ui14", theme.faint, { w = 328 })
    local rr = rep.rolls
    local dice = "Big rolls: " .. util.int(rr.open) .. " in the open, " .. util.int(rr.hidden) .. " behind the screen"
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
    -- Empathy, and on to next week.
    local e = rep.empathy
    if e then
        kit.icon(1204, y + 6, 18, "empathy", theme.teal)
        local text = "Empathy: " .. empathy.NAMES[e.level] .. (e.up and ". You read the table better now." or "")
        kit.text(1230, y + 6, text, "ui14", e.up and theme.teal or theme.dim, { w = 346, lines = 2 })
    end
    M.gift_row(app, rep, 1204, 708)
    local closing = M.closing_chapter(app)
    kit.button(1204, 790, 372, 56, closing and "Close the first act  >" or ("On to week " .. util.int(rep.week + 1) .. "  >"),
        function()
            app.report_note = nil
            M.next(app)
        end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "next_week" })
    kit.text(1390, 852, closing and "A look back at the first four sessions." or "Playtest notes are saved after every week.",
        "ui14", theme.faint, { pivot = gui.PIVOT_N })
    if app.quick then
        M.quick_modal(app)
    end
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
    return c.week == content.arc.SESSIONS and c:slice_done() and not app.slice_seen
end

-- On to next week, by way of two quick playtest questions (M7).
function M.next(app)
    local c = app.campaign
    app.gift_line = nil
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
