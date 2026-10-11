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

local function column(app, rep, row, i)
    local x, y, w, h = 24 + (i - 1) * 392, 100, 376, 560
    local level = app.campaign:empathy()
    kit.box(x, y, w, h, theme.panel, { radius = 10 })
    kit.text(x + 16, y + 12, row.name, "ui22b", theme.text)
    local p = app.campaign:player(row.key)
    kit.text(x + 16 + kit.width(row.name, "ui22b") + 10, y + 16, row.char .. ", " .. p.class_name, "ui18", theme.dim)
    local standing = rep.standing and rep.standing[row.key]
    local long_y
    if row.on_break then
        kit.text(x + 16, y + 52, "On a break", "title30", theme.orange)
        kit.text(x + 16, y + 96, "Taking some time away from Thursdays. A check-in during prep brings them back sooner.",
            "ui14", theme.dim, { w = w - 32 })
        kit.text(x + 16, y + 150, "OVER TIME", "ui14", theme.dim)
        long_y = y + 172
    elseif not row.present then
        kit.text(x + 16, y + 56, "Couldn't make it this week.", "ui18", theme.orange)
        kit.text(x + 16, y + 84, "Missing one session makes people miss the group. Missing more starts a drift.", "ui14",
            theme.dim, { w = w - 32 })
    else
        kit.text(x + 16, y + 52, row.verdict, "title30", tier_color(row.tier))
        kit.bar(x + 16, y + 96, w - 32, 14, empathy.fill(level, row.fun), 100, tier_color(row.tier))
        -- Their quote, on a sticky note.
        local qh = math.max(70, 24 + kit.text_height(row.quote, "hand24", w - 64))
        kit.box(x + 16, y + 124, w - 32, qh, kit.rgba("#f3df8a"), { radius = 4 })
        kit.text(x + 32, y + 136, row.quote, "hand24", theme.ink, { w = w - 64 })
        local my = y + 124 + qh + 18
        kit.text(x + 16, my, "TONIGHT", "ui14", theme.dim)
        for k, key in ipairs(score.METERS) do
            local by = my + 22 + (k - 1) * 22
            kit.icon(x + 16, by - 4, 16, key, theme.meters[key])
            kit.text(x + 38, by - 3, score.METER_NAMES[key], "ui14", theme.text)
            kit.bar(x + 132, by, w - 148, 9, empathy.fill(level, row.meters[key]), 100, theme.meters[key])
        end
        my = my + 22 + #score.METERS * 22 + 12
        kit.text(x + 16, my, "OVER TIME", "ui14", theme.dim)
        long_y = my + 22
    end
    if long_y then
        for k, key in ipairs(score.LONG) do
            local by = long_y + (k - 1) * 22
            local read = empathy.long(level, p, key, app.campaign.week, i)
            kit.icon(x + 16, by - 4, 16, key, theme.long[key])
            kit.text(x + 38, by - 3, score.LONG_NAMES[key], "ui14", theme.text)
            if read.lo then
                kit.bar(x + 132, by, w - 192, 9, 0, 100, theme.long[key], { range = { read.lo, read.hi } })
            else
                kit.bar(x + 132, by, w - 192, 9, read.fill, 100, theme.long[key])
            end
            local mark = empathy.mark(level, row.long[key].delta)
            if mark then
                local mc = theme[MARK_COLOR[mark]]
                if key == "suspicion" and mark ~= "=" then
                    -- Rising suspicion is bad news.
                    mc = (row.long[key].delta > 0) and theme.red or theme.green
                end
                kit.text(x + w - 22, by - 5, mark, "ui18b", mc, { pivot = gui.PIVOT_NE })
            end
        end
    end
    if standing == "left" then
        -- Leaving shows even when they missed the night.
        local by = long_y and (long_y + 4 * 22 + 4) or (y + 140)
        kit.box(x + 10, by, w - 20, 30, kit.rgba("#000000", 0.25), { radius = 6 })
        kit.icon(x + 18, by + 7, 16, "warn", theme.orange)
        kit.text(x + 40, by + 6, "Says they need a break from Thursdays.", "ui14", theme.orange)
    end
end

function M.build(app)
    local rep = app.campaign.report
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    kit.text(24, 14, "WEEK " .. util.int(rep.week) .. "  -  SESSION REPORT", "title30", theme.gold)
    kit.text(24, 58, rep.headline, "ui18", theme.text)
    for i, row in ipairs(rep.players) do
        column(app, rep, row, i)
    end
    -- Bottom strip: moments, canon, threads and seeds, the table.
    local y = 674
    kit.box(24, y, 1160, 212, theme.panel, { radius = 10 })
    kit.text(40, y + 12, "BEST MOMENTS", "ui14", theme.dim)
    local my = y + 34
    if #rep.moments == 0 then
        kit.text(40, my, "Nothing anyone will bring up later.", "ui18", theme.faint)
    end
    for _, m in ipairs(rep.moments) do
        local mh = kit.text_height("- " .. m, "ui18", 360)
        if my + mh <= y + 176 then
            kit.text(40, my, "- " .. m, "ui18", theme.text, { w = 360 })
            my = my + mh + 4
        end
    end
    -- The story: what the party found out tonight (it's in your notes), backstories, seeds,
    -- and whatever you made up that's now canon.
    kit.text(420, y + 12, "THE STORY", "ui14", theme.dim)
    kit.text(900, y + 12, "Your notes: N", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    local items = {}
    if rep.table_text then
        table.insert(items, { rep.table_text, theme.dim })
    end
    -- Between the players (A17): the friendships under strain after tonight.
    do
        local rapport = require "game.model.rapport"
        for k, s in ipairs(rapport.strained(app.campaign)) do
            if k <= 2 then
                table.insert(items, { (s.stage == "live" and "Rift: " or "Strained: ") .. s.hurt.name .. " is fed up with "
                    .. s.doer.char .. ". A one-on-one or a word with the table would help.", s.stage == "live" and theme.red or theme.orange })
            end
        end
    end
    for _, c in ipairs(rep.clues or {}) do
        table.insert(items, { "Found out: " .. c, theme.gold })
    end
    for _, t in ipairs(rep.threads) do
        table.insert(items, { "- " .. t, theme.text })
    end
    -- The slice rework: who feels differently now, and what tonight opened for the weeks ahead.
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
    for _, id in ipairs(rep.payoffs or {}) do
        table.insert(items, { "Paid off: " .. content.seeds[id].name, theme.green })
    end
    if rep.planted then
        table.insert(items, { "Planted: " .. content.seeds[rep.planted].name, theme.teal })
    end
    for k, c in ipairs(rep.canon) do
        if k <= 3 then
            table.insert(items, { "Now canon: " .. c, theme.dim })
        end
    end
    if #items == 0 then
        table.insert(items, { "The story didn't move tonight. This week's story cards are how it moves.", theme.faint })
    end
    local ty = y + 34
    local more = 0
    for _, it in ipairs(items) do
        local hgt = kit.text_height(it[1], "ui14", 470)
        if ty + hgt <= y + 176 then
            kit.text(420, ty, it[1], "ui14", it[2], { w = 470 })
            ty = ty + hgt + 3
        else
            more = more + 1
        end
    end
    if more > 0 then
        kit.text(420, ty, "And " .. util.int(more) .. " more in your notes.", "ui14", theme.faint)
    end
    kit.text(920, y + 12, "AT THE TABLE", "ui14", theme.dim)
    local ay = y + 34
    local notes = {}
    for _, st in ipairs(rep.table or {}) do
        local col = st.state == "fixed" and theme.green or (st.state == "active" and theme.red or theme.orange)
        table.insert(notes, { st.text, col })
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
            table.insert(notes, { util.fill(line, { name = p.name }), e.kind == "xcard" and theme.dim or theme.orange })
        end
    end
    if rep.broken == "look_it_up" then
        table.insert(notes, { "You never posted the ruling you promised to look up. Sam noticed.", theme.orange })
    end
    if #notes == 0 then
        table.insert(notes, { "Nobody's at odds. Enjoy it.", theme.faint })
    end
    for _, n in ipairs(notes) do
        local nh = kit.text_height(n[1], "ui14", 250)
        if ay + nh <= y + 176 then
            kit.text(920, ay, n[1], "ui14", n[2], { w = 250 })
            ay = ay + nh + 4
        end
    end
    local r = rep.rolls
    local dice = "Big rolls: " .. util.int(r.open) .. " in the open, " .. util.int(r.hidden) .. " with the DC behind the screen"
    if r.cooked > 0 then
        dice = dice .. ", " .. util.int(r.cooked) .. " cooked"
    end
    if rep.callouts > 0 then
        dice = dice .. ". Someone asked to see a roll."
    else
        dice = dice .. "."
    end
    kit.text(40, y + 182, dice, "ui14", theme.dim)
    -- How well you read the table, and whether that just got better.
    local e = rep.empathy
    if e then
        kit.icon(1204, 684, 18, "empathy", theme.teal)
        local text = "Empathy: " .. empathy.NAMES[e.level]
        if e.up then
            text = text .. ". You read the table better now."
        end
        kit.text(1230, 684, text, "ui14", e.up and theme.teal or theme.dim, { w = 346, lines = 2 })
    end
    if rep.hype > 0 then
        kit.text(920, y + 182, "That cliffhanger has everyone hooked.", "ui14", theme.gold)
    end
    -- Level-ups (M6): the DM decides when; the players decide what.
    local lv = app.campaign:level_status()
    if lv.ready then
        kit.button(1204, 720, 372, 44, "Level up to " .. util.int(lv.level + 1), function()
            levelup_view.level_up(app)
        end, { color = lv.overdue and kit.rgba("#8a4a2a") or theme.button, font = "ui18b", key = "level_up" })
        kit.text(1390, 766, lv.overdue and "Overdue: the table keeps asking." or (lv.level + 1 == 3
            and "Everyone picks a subclass." or "Everyone gets stronger."), "ui14", lv.overdue and theme.orange or theme.dim,
            { pivot = gui.PIVOT_N })
    elseif app.campaign.level < content.progression.MAX_LEVEL then
        kit.text(1204, 730, "Level " .. util.int(lv.level) .. ". The next level feels earned after "
            .. util.int(content.progression.READY_AFTER) .. " nights.", "ui14", theme.faint, { w = 372 })
    end
    local closing = M.closing_chapter(app)
    kit.button(1204, 790, 372, 56, closing and "Close the first act  >" or ("On to week " .. util.int(rep.week + 1) .. "  >"),
        function()
            M.next(app)
        end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "next_week" })
    kit.text(1390, 852, closing and "A look back at the first four sessions." or "Playtest notes are saved after every week.",
        "ui14", theme.faint, { pivot = gui.PIVOT_N })
    if app.quick then
        M.quick_modal(app)
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
