-- The session report: how each player felt, what moved, and the best moments.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
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

-- What the wrap-up lists: what the museum kept from tonight, then the table.
local function wrapup_items(app, rep)
    local items = {}
    local mu = rep.museum      -- (every museum night has one: museum_week.after_night)
    if mu then
        local MODULE = require("game.model.adventure").data
        local names = {}
        for _, r in ipairs(mu.rooms or {}) do
            local room = MODULE.rooms[r.room]
            if room and not room.virtual then
                -- (A side room by its own name, off its room; a trip back as a trip back.)
                -- (Lower-case "the" after the first, as in a sentence: "The street, The garden" was uneven.)
                local rn = #names > 0 and util.lower_first(room.name) or room.name
                local name = (r.side and (r.side .. ", off " .. util.lower_first(room.name)))
                    or (r.back and (rn .. " (back again)")) or rn
                if not util.contains(names, name) then
                    table.insert(names, name)
                end
            end
        end
        if #names > 0 then
            table.insert(items, { "Tonight: " .. util.join_names(names) .. ".", theme.text })
        end
        -- Where it stands now, second: the line next week starts from (the third playtest: it was last,
        -- and the first to fall off a full column).
        if mu.ending then
            table.insert(items, { "The museum is done. Ending: " .. MODULE.endings[mu.ending].name .. ".", theme.gold })
            -- (Out of sessions, nothing at the table said so: the report does, with Flitwidget's word.)
            if mu.ending == "timeout" then
                local e = MODULE.endings.timeout
                table.insert(items, { e.line .. " Flitwidget: " .. e.flit, theme.dim })
            end
        else
            table.insert(items, { mu.where, theme.dim })
        end
    end
    -- How long the night ran against the time you all agreed, next (the third playtest: a night that ran
    -- two hours over said so only under "+7 more").
    if rep.table_text then
        table.insert(items, { rep.table_text, theme.dim })
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
    -- What the museum kept from tonight: her card, the harsh calls, where you stopped.
    if mu then
        local MODULE = require("game.model.adventure").data
        for _, id in ipairs(mu.marks or {}) do
            local m = MODULE.marks[id]
            if m then
                table.insert(items, { "Euryale's card: " .. m.name .. ". " .. m.showdown .. ".", theme.gold })
            end
        end
        -- (Where it was: "A harsh call felt arbitrary" didn't say which, the third playtest's engine run.)
        for _, h in ipairs(mu.harsh or {}) do
            local room = h.room and MODULE.rooms[h.room]
            local at = room and (" in " .. util.lower_first(room.name)) or ""
            table.insert(items, h.earned and { "A harsh call" .. at .. " landed as fair: they knew the risk.", theme.green }
                or { "A harsh call" .. at .. " felt arbitrary. Nobody had been warned.", theme.orange })
        end
        if mu.stopped then
            table.insert(items, { "You stopped mid-museum: " .. mu.stopped .. " is still ahead.", theme.dim })
        end
    end
    for _, t in ipairs(rep.threads or {}) do
        table.insert(items, { "- " .. t, theme.text })
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
    -- Your calls tonight, last (the rest needs the DM sooner): the ones that moved the table most,
    -- and who they moved. Each says it's a call, so a line that fits after one that didn't still reads.
    for i, line in ipairs((rep.museum and rep.museum.calls) or {}) do
        if i <= 3 then
            table.insert(items, { "Your call: " .. line, theme.gold })
        end
    end
    return items
end

-- (The GDD's part numbers came off the headings, October 20: one of the five, what it earned,
-- has no heading, so they read 1, 2, 3, 5.)
local function head(x, y, n, text)
    kit.text(x, y, text, "ui14", theme.gold)
    return y + 24
end

-- The night's chain from x, y down to max_y: a sentence to a line when they all fit that way, else
-- the sentences run on as one paragraph. partial: whole sentences only, as many as fit (the rest
-- is the caller's to offer); otherwise all of it, the last line cut with its hover if it must be.
-- Returns how many sentences it drew.
function M.draw_chain(chain, x, y, w, max_y, partial)
    local lh = kit.line_height("ui14")
    local room = math.max(0, math.floor((max_y - y) / lh))
    local each = 0
    for _, line in ipairs(chain) do
        each = each + #kit.wrap(line, "ui14", w)
    end
    if each + math.max(0, #chain - 1) * 0.15 <= room then
        local ty = y
        for _, line in ipairs(chain) do
            kit.text(x, ty, line, "ui14", theme.text, { w = w })
            ty = ty + kit.text_height(line, "ui14", w) + 3
        end
        return #chain
    end
    -- Paragraphs: a new one at each sentence about the party ("They went into the offices."), so a
    -- "They" never reads as the one hero just named before it, and the night falls into its rooms.
    local paras = {}
    for i, line in ipairs(chain) do
        if i == 1 or string.find(line, "^They[%s']") or string.find(line, "^Their ") then
            table.insert(paras, { first = i, last = i })
        else
            paras[#paras].last = i
        end
    end
    local function lines_of(pa, upto)
        return #kit.wrap(table.concat(chain, " ", pa.first, math.min(pa.last, upto)), "ui14", w)
    end
    -- How many sentences fit, whole.
    local n, used = 0, 0
    for _, pa in ipairs(paras) do
        local whole = lines_of(pa, pa.last)
        if used + whole <= room then
            n, used = pa.last, used + whole
        else
            for k = pa.last - 1, pa.first, -1 do
                if used + lines_of(pa, k) <= room then
                    n = k
                    break
                end
            end
            break
        end
    end
    if not partial and n < #chain then
        n = #chain      -- (all of it: the last paragraph cut, with its hover)
    end
    local ty = y
    for _, pa in ipairs(paras) do
        if pa.first > n or ty + lh > max_y + 1 then
            break
        end
        local text = table.concat(chain, " ", pa.first, math.min(pa.last, n))
        local left = math.max(1, math.floor((max_y - ty) / lh))
        if #kit.wrap(text, "ui14", w) > left then
            -- (Out of room: the rest of the night in this last paragraph, cut, the whole of it on hover.)
            kit.text(x, ty, table.concat(chain, " ", pa.first, n), "ui14", theme.text, { w = w, lines = left })
            break
        end
        kit.text(x, ty, text, "ui14", theme.text, { w = w })
        ty = ty + #kit.wrap(text, "ui14", w) * lh
    end
    return n
end

-- 1. The recap.
local function recap_panel(app, rep, x, y, w, h)
    local r = rep.recap
    kit.box(x, y, w, h, theme.panel, { radius = 10 })
    local ty = head(x + 16, y + 12, 1, "THE RECAP")
    -- What Pin and Cut do (the playtest, November 3: "it's unclear what pin / cut does").
    local how = "Pin: next session opens on it. Cut: it's left out."
    kit.text(x + w - 16, y + 12, how, "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    local PIN_TIP = "Next session starts with your recap of this one (\"Last time...\"). A pinned beat is always in it, "
        .. "first. Use it for what you want the table to remember."
    local CUT_TIP = "Leave this beat out of next session's recap (\"Last time...\"): a moment that fell flat, or one you'd "
        .. "rather they forgot. It stays in your notes. Undo puts it back."
    local gl = require "game.ui.gloss"
    gl.card_spot(x + w - 16 - kit.width(how, "ui14"), y + 10, kit.width(how, "ui14"), 20, "Pin and Cut",
        "Next session opens with a short recap of this one (\"Last time...\"). A pinned beat is always in it, first. "
        .. "A cut one is left out; it stays in your notes. Beats you leave alone may or may not come up.")
    local chain = rep.museum and rep.museum.chain or {}
    local bottom = y + h - 166
    local cw = w - 32
    -- The whole night on a page of its own (the third playtest: the chain stopped partway through
    -- the night with nothing to say there was more). Back goes to the beats.
    if app.report_chain == rep.week and #chain > 0 then
        kit.text(x + 16, ty, "HOW IT WENT, ONE THING TO THE NEXT", "ui14", theme.dim)
        kit.button(x + w - 16 - 150, ty - 4, 150, 24, "<  Back to the recap", function()
            app.report_chain = nil
            app.refresh()
        end, { font = "ui14", color = theme.panel2, hover = theme.button_hover, key = "report_chain_back" })
        M.draw_chain(chain, x + 16, ty + 26, cw, bottom + 4)
    else
        if not r or #r.beats == 0 then
            kit.text(x + 16, ty + 4, "A quiet night. Nothing anyone will bring up later.", "ui18", theme.faint)
            ty = ty + 34
        else
            -- The beats in the reading hand when the whole night still fits under them; smaller when
            -- that's what lets the chain be read in full (the third playtest).
            local bw = w - 32 - 120
            local function beats_h(font, step)
                local t = 0
                for _, b in ipairs(r.beats) do
                    t = t + math.max(kit.text_height(b.text, font, bw), step) + (font == "ui18" and 8 or 4)
                end
                return t
            end
            local chain_h = #chain > 0 and (28 + #kit.wrap(table.concat(chain, " "), "ui14", cw) * kit.line_height("ui14")) or 0
            local small = ty + beats_h("ui18", 24) + chain_h > bottom and ty + beats_h("ui14", 22) + chain_h <= bottom + 40
            local bf, bh = small and "ui14" or "ui18", small and 22 or 26
            for k, b in ipairs(r.beats) do
                local th = kit.text_height(b.text, bf, bw)
                if ty + th > bottom then
                    break
                end
                kit.text(x + 16, ty, b.text, bf, b.cut and theme.faint or (b.pinned and theme.gold or theme.text), { w = bw })
                kit.button(x + w - 128, ty - 2, 54, bh, b.pinned and "Pinned" or "Pin", function()
                    b.pinned = not b.pinned
                    b.cut = nil
                    app.refresh()
                end, { font = "ui14", color = b.pinned and theme.go or theme.panel2, hover = theme.button_hover, key = "recap_pin_" .. k })
                gl.card_spot(x + w - 128, ty - 2, 54, bh, b.pinned and "Pinned" or "Pin", PIN_TIP)
                kit.button(x + w - 68, ty - 2, 52, bh, b.cut and "Undo" or "Cut", function()
                    b.cut = not b.cut
                    b.pinned = nil
                    app.refresh()
                end, { font = "ui14", color = theme.panel2, hover = theme.button_hover, key = "recap_cut_" .. k })
                gl.card_spot(x + w - 68, ty - 2, 52, bh, b.cut and "Cut (Undo to keep it)" or "Cut", CUT_TIP)
                ty = ty + math.max(th, bh - 2) + (small and 4 or 8)
            end
        end
        -- How the night went, one thing to the next (R14): the event log's chain, "so" and "but". All of
        -- it when it fits under the beats; else as much as fits, whole sentences, and a button for the rest.
        if #chain > 0 and ty + 44 <= bottom then
            ty = ty + 4
            kit.text(x + 16, ty, "HOW IT WENT, ONE THING TO THE NEXT", "ui14", theme.dim)
            local shown = M.draw_chain(chain, x + 16, ty + 20, cw, bottom - 30, true)
            if shown < #chain then
                local more = #chain - shown
                local label = "The whole night  (" .. util.int(more) .. " more)  >"
                kit.button(x + w - 16 - 210, bottom - 26, 210, 24, label, function()
                    app.report_chain = rep.week
                    app.refresh()
                end, { font = "ui14", color = theme.panel2, hover = theme.button_hover, key = "report_chain" })
                kit.text(x + 16, bottom - 22, "...and the night goes on.", "ui14", theme.faint)
            end
        elseif #chain > 0 then
            kit.button(x + w - 16 - 210, bottom - 26, 210, 24, "How it went, the whole night  >", function()
                app.report_chain = rep.week
                app.refresh()
            end, { font = "ui14", color = theme.panel2, hover = theme.button_hover, key = "report_chain" })
        end
    end
    if not r then
        return
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
        local cap = util.capitalize(sn.caption or "")      -- ("the Lecturer falls." starts a caption: the third playtest)
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
        require("game.ui.gloss").card_spot(sx + sw - 62, sy + 14, 50, 24, "Look", sn.frames
            and "Set the moment out on the table: the fight plays back, turn by turn, up to it."
            or "Set the moment out on the table, minis and all.")
    end
end

-- A long-term stat's row: its hover says what it is, how it moved tonight, and if that's good.
local STAT_GOOD_UP = { commitment = true, investment = true, trust = true, suspicion = false }
function M.stat_spot(name, key, mark, blurred, x, y, w, h)
    local gl = require "game.ui.gloss"
    local t = gl.by_id[key]
    local stat = score.LONG_NAMES[key] or key
    local up = mark and string.find(mark, "+", 1, true) ~= nil
    local down = mark and string.find(mark, "-", 1, true) ~= nil
    local moved
    if not mark then
        moved = "You can't tell how it moved tonight: your Empathy is too low to read it yet."
    elseif up or down then
        local good = (up and STAT_GOOD_UP[key]) or (down and not STAT_GOOD_UP[key])
        moved = (up and "Up" or "Down") .. ((#mark > 1) and " a lot" or "") .. " tonight (" .. mark .. "), which is "
            .. (good and "good." or "a worry.")
    else
        moved = "About the same as before tonight (=)."
    end
    local how = " The bar: where it stands now" .. (blurred and ", as a blur: your Empathy only lets you guess." or
        "; the bright stretch is what it gained tonight, the hollow red one what it lost.")
    gl.card_spot(x, y, w, h, name .. ": " .. stat, moved .. " " .. ((t and t.text) or "") .. how)
end

-- 2. How the table felt: a card per player, the least happy first.
local function felt_panel(app, rep, x, y, w, h)
    kit.box(x, y, w, h, theme.panel, { radius = 10 })
    local level = app.campaign:empathy()
    local t1 = "HOW THE TABLE FELT"
    kit.button(x + 8, y + 6, kit.width(t1, "ui14") + 20, 26, t1, function()
        app.refresh()
    end, { font = "ui14", color = theme.panel3, hover = theme.button_hover, text_color = theme.gold, key = "report_tab_felt" })
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
            -- Which of your calls did it (the playtest, Nov 2: the reasons were generic). It takes
            -- the meter's guess's place, and its room; next to a real reason, one line.
            if row.why and not (row.call and row.why_generic) then
                table.insert(lines, { row.why, theme.dim, 1 })
            end
            if row.call then
                table.insert(lines, { row.call, theme.gold, row.why_generic and 2 or 1 })
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
        for k, key in ipairs(score.LONG) do
            local by = ry + 10 + (k - 1) * 20
            local read = empathy.long(level, p, key, app.campaign.week, i)
            kit.icon(bx, by - 3, 14, key, theme.long[key])
            kit.text(bx + 19, by - 6, score.LONG_NAMES[key], "ui14", theme.dim)
            local mark = row.long and row.long[key] and empathy.mark(level, row.long[key].delta)
            if read.lo then
                kit.bar(bx + 112, by - 1, 74, 9, 0, 100, theme.long[key], { range = { read.lo, read.hi } })
            else
                kit.bar(bx + 112, by - 1, 74, 9, read.fill, 100, theme.long[key])
                -- How far it moved tonight, inside the bar (the playtest, November 3): what it gained
                -- lit up, what it lost as a hollow stretch where the bar used to reach.
                local d = row.long[key] and row.long[key].delta or 0
                if mark and mark ~= "=" and p then
                    local now = math.max(0, math.min(100, p[key] or 0))
                    local was = math.max(0, math.min(100, (p[key] or 0) - d))
                    local moved = now - was
                    local a = math.max(0, math.min(100, read.fill - moved))
                    local lo, hi = math.min(a, read.fill), math.max(a, read.fill)
                    if hi - lo >= 1 then
                        local sx, sw = bx + 112 + 74 * lo / 100, math.max(2, 74 * (hi - lo) / 100)
                        if moved > 0 then
                            kit.box(sx, by - 1, sw, 9, kit.rgba("#ffffff", 0.55), { round = false })
                        else
                            kit.box(sx, by - 1, sw, 9, kit.rgba("#e86a5a", 0.35), { round = false })
                            kit.box(sx, by - 1, sw, 1, kit.rgba("#e86a5a", 0.9), { round = false })
                            kit.box(sx, by + 7, sw, 1, kit.rgba("#e86a5a", 0.9), { round = false })
                        end
                        kit.box(bx + 112 + 74 * a / 100 - 1, by - 3, 2, 13, kit.rgba("#f3e7cf", 0.9), { round = false })
                    end
                end
            end
            if mark then
                local mc = theme[MARK_COLOR[mark]]
                if key == "suspicion" and mark ~= "=" then
                    mc = (row.long[key].delta > 0) and theme.red or theme.green
                end
                kit.text(bx + 200, by - 6, mark, "ui14", mc, { pivot = gui.PIVOT_NE })
            end
            -- What it is, which way it went tonight and whether that's good, on the row (the third
            -- playtest: "nothing says what they are, or whether '-' on Suspicion is good").
            M.stat_spot(p and p.name or row.name, key, mark, read.lo ~= nil, bx - 2, by - 7, 210, 20)
        end
    end
end

function M.build(app)
    local rep = app.campaign.report
    if app.snapshot_view then
        return M.snapshot_overlay(app)
    end
    -- First, how the table felt and the night's reward (game/ui/rewards_view.lua).
    local rewards = require "game.ui.rewards_view"
    if rewards.pending(app) then
        return rewards.build(app)
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
    kit.text(24 + kit.width(title, "title30") + 152, 42, sub, "ui14", theme.dim, { w = 1440 - (24 + kit.width(title, "title30") + 152),
        lines = 1 })
    -- Save to a slot of your own (November 3): it picks up at the start of next session.
    kit.button(1456, 14, 120, 32, "Save game", function()
        require("game.ui.saves_view").open(app, "save")
    end, { font = "ui14", key = "save_game" })
    -- (The recap wider and the table's cards narrower than before: the night's chain reads in full more
    -- often, the third playtest.)
    recap_panel(app, rep, 24, 84, 876, 556)
    kit.gloss_scope({ report = true }, function()
        felt_panel(app, rep, 916, 84, 660, 556)
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
    elseif app.campaign.level < 4 then
        -- (The book's milestones, not a count of nights.)
        kit.text(412, ey, "Level " .. util.int(lv.level) .. ". The book's next level comes "
            .. (lv.level < 3 and "after the gift shop." or "when the museum is done."), "ui14", theme.faint, { w = 348 })
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
        -- (Hover: what it does, and who has it. The playtest, November 3.)
        table.insert(earned, { "Earned: " .. d.name .. (who and (". " .. who.char .. " carries it.") or "."), theme.gold,
                               tip = { d.name, (d.text or "") .. (who and (" " .. who.char .. " (" .. who.name .. ") has it.") or "") } })
    end
    -- What the museum gave them tonight: Francs, and anything they picked up or bought.
    local mu = rep.museum
    if mu then
        if (mu.francs_tonight or 0) > 0 then
            table.insert(earned, { util.int(mu.francs_tonight) .. (mu.francs_tonight == 1 and " Flitwidget Franc" or " Flitwidget Francs")
                .. " tonight" .. ((mu.francs_spent or 0) > 0 and (", " .. util.int(mu.francs_spent) .. " spent") or "")
                .. " (" .. util.int(mu.francs or 0) .. " in the pool).", theme.gold })
        end
        -- Anything lifted tonight (the event log: R7, R13), and who has it now.
        for _, l in ipairs(mu.lifted or {}) do
            table.insert(earned, { "Lifted: " .. util.sentence_case(l.text) .. ".", theme.gold })
        end
        -- Each thing on its own line, with a hover: what it does, and who has it.
        local mn = require "game.model.museum_night"
        for _, g in ipairs(mu.got or {}) do
            local info = mn.item_info(app.campaign, g)
            local who = info and info.holder
            -- (Whose pack it's in, which reads right for one thing or several: "fire arrows and slime
            -- (Brannoc has it)" in the third playtest.)
            table.insert(earned, { "Picked up: " .. g .. (who and (", in " .. who.char .. "'s pack") or "") .. ".", theme.gold,
                                   tip = info and { info.title, info.text .. (who and (" In " .. who.char .. "'s pack.") or "") } or nil })
        end
    end
    if #earned == 0 then
        table.insert(earned, { "Nothing picked up or handed out tonight.", theme.faint })
    end
    for _, it in ipairs(earned) do
        local hh = kit.text_height(it[1], "ui14", 348)
        if ey + hh <= y + 226 then
            local opts = { w = 348 }
            if it.tip then
                opts.gloss = false       -- (its own hover card instead of a word's)
            end
            local tn = kit.text(412, ey, it[1], "ui14", it[2], opts)
            if it.tip and it.tip[2] ~= "" then
                require("game.ui.gloss").card_spot(412, ey, 348, hh, it.tip[1], it.tip[2], nil, tn)
            end
            ey = ey + hh + 4
        end
    end
    -- 5. Wrap-up.
    kit.box(788, y, 400, 234, theme.panel, { radius = 10 })
    head(804, y + 12, 5, "WRAP-UP")
    local wy = y + 40
    local rest = {}
    for _, it in ipairs(wrapup_items(app, rep)) do
        local hh = kit.text_height(it[1], "ui14", 368)
        if #rest == 0 and wy + hh <= y + 226 then
            kit.text(804, wy, it[1], "ui14", it[2], { w = 368 })
            wy = wy + hh + 3
        else
            table.insert(rest, it[1])
        end
    end
    -- What didn't fit, on hover (the third playtest: "+3 in your notes", and they weren't in the notes).
    if #rest > 0 then
        local label = "+" .. util.int(#rest) .. " more (point here)"
        kit.text(1172, y + 12, label, "ui14", theme.faint, { pivot = gui.PIVOT_NE })
        require("game.ui.gloss").card_spot(1172 - kit.width(label, "ui14") - 4, y + 8, kit.width(label, "ui14") + 8, 24,
            "The rest of the wrap-up", table.concat(rest, "\n"))
    end
    -- Empathy, and on to next week.
    local e = rep.empathy
    if e then
        kit.icon(1204, y + 6, 18, "empathy", theme.teal)
        local text = "Empathy: " .. empathy.NAMES[e.level] .. (e.up and ". You read the table better now." or "")
        -- The friends' thoughts you caught tonight, and what you did about them.
        local th = rep.thoughts
        if th and th.shown > 0 then
            -- (Kept to two lines: the new dice sit just under it.)
            text = "Empathy: " .. empathy.NAMES[e.level] .. (e.up and " (up!)" or "") .. ". Thoughts: caught " .. util.int(th.shown)
                .. ", read " .. util.int(th.clear or 0) .. " clearly, answered " .. util.int(th.answered) .. "."
        end
        -- Who you know better now (game/model/familiar.lua).
        local names = {}
        for _, p in ipairs(app.campaign.players) do
            if rep.familiar_up and rep.familiar_up[p.key] then
                table.insert(names, p.name)
            end
        end
        if #names > 0 then
            text = text .. (#names >= 4 and " Closer to everyone." or (" Closer to " .. util.join_names(names) .. "."))
        end
        -- (Two lines: a third ran into the new dice under it, the November 4 engine run showed.)
        kit.text(1230, y + 6, text, "ui14", e.up and theme.teal or theme.dim, { w = 346, lines = 2 })
    end
    kit.gloss_tags = nil
    M.gift_row(app, rep, 1204, 708)
    local closing = M.closing_chapter(app)
    -- (The prologue ends on its journey recap.)
    kit.button(1204, 790, 372, 56, closing and "Your table's journey  >" or ("On to session " .. util.int(rep.week + 1) .. "  >"),
        function()
            app.report_note = nil
            M.next(app)
        end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "next_week" })
    -- (Not "Playtest notes are saved after every week": what the button leads to.)
    kit.text(1390, 852, closing and "The whole prologue, room by room." or "Next: the group chat, then your prep board.",
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
        or require("game.ui.rewards_view").pending(app)
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
    kit.text(x + 82, y + 82, util.fill("{Name_their} Goodwill filled up this week.", { name = name }), "ui14", theme.dim)
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

-- New dice for someone who earned it (dice_sets): once a week, after the session, from your bag.
-- The table notices, and they bring the good mood (and the dice) next week.
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
    -- The bag fills with boxes won after happy sessions (game/model/loot.lua).
    local loot = require "game.model.loot"
    local dd = require "game.data.dice"
    local bag = loot.bag(camp)
    if #bag == 0 then
        kit.text(x, y, "YOUR DICE BAG", "ui14", theme.dim)
        kit.text(x + 110, y, "Empty. Happy sessions earn boxes of dice to give.", "ui14", theme.faint,
            { w = 262, lines = 2 })
        return
    end
    -- Tonight's box first, and "NEW DICE" only for it (the third playtest's engine run: "NEW DICE:
    -- Rose quartz" every week, the first set in the bag, while the bag filled up). Older sets are
    -- "IN YOUR BAG", one of how many.
    -- (Which one is tonight's: loot.newest_index, one owner.)
    local opened = loot.opened(camp)
    if app.gift_pick_week ~= camp.week then
        app.gift_pick_week = camp.week
        app.gift_pick = loot.newest_index(camp)
    end
    app.gift_pick = util.clamp(app.gift_pick or #bag, 1, #bag)
    local sid = bag[app.gift_pick]
    local new = opened and opened.set == sid
    kit.text(x, y, new and "NEW DICE" or (#bag > 1 and ("IN YOUR BAG " .. util.int(app.gift_pick) .. "/" .. util.int(#bag))
        or "IN YOUR BAG"), "ui14", new and theme.gold or theme.dim)
    local set = dd.SETS[sid]
    local r = loot.rarity(set and set.rarity)
    local lx = x + math.max(84, kit.width("IN YOUR BAG 9/9", "ui14") + 10)
    kit.picture(lx, y - 4, 26, 26, "dice_" .. sid)
    kit.text(lx + 32, y, (set and set.name or sid) .. (r and (" (" .. r.name .. ")") or ""), "ui14",
        r and kit.rgba(r.color) or theme.text, { w = x + 316 - lx - 32, lines = 1 })
    if #bag > 1 then
        kit.button(x + 322, y - 4, 24, 22, "<", function()
            app.gift_pick = (app.gift_pick - 2) % #bag + 1
            app.refresh()
        end, { font = "ui14", key = "gift_prev" })
        kit.button(x + 348, y - 4, 24, 22, ">", function()
            app.gift_pick = app.gift_pick % #bag + 1
            app.refresh()
        end, { font = "ui14", key = "gift_next" })
    end
    local bw2 = 87
    for i, p in ipairs(camp.players) do
        local bx = x + (i - 1) * (bw2 + 8)
        local ok = (dice_sets.get(camp).gift_week ~= camp.week) and dice_sets.of(camp, p.key) ~= sid
        kit.button(bx, y + 24, bw2, 40, "", function()
            if loot.give(camp, p.key, sid) then
                app.gift_line = dd.GIFT_LINES[((camp.week + i) % #dd.GIFT_LINES) + 1]
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
        kit.text(bx + 40, y + 34, p.name, "ui14", ok and theme.text or theme.faint, { w = bw2 - 42, lines = 1 })
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
    -- A fight's moment plays back with everyone's hit points and what they did (night_view).
    require("game.ui.night_view").draw_replay_hud(app, sn)
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

-- The museum's done: the last report leads to the journey recap instead of another week.
function M.closing_chapter(app)
    return app.campaign:slice_done() and not app.slice_seen
end

-- On to next week, by way of two quick playtest questions (M7).
function M.next(app)
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
