-- The journey recap (v2): when the museum is done, the whole prologue on one page. The route the
-- party took, what each room left behind, Euryale's final card, and each friend: what their hero
-- did (their history, Wildermyth-style), and what they want next. Then the playtest questions.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local panels = require "game.ui.panels"
local content = require "game.model.content"
local util = require "game.model.util"
local adventure = require "game.model.adventure"

-- (The current adventure, read as it is now: another can be made current, adventure.use, the hand-off.)
local MODULE = setmetatable({}, { __index = function(_, k) return adventure.data[k] end })
local M = {}

local OUTCOME = { win = "went their way", lose = "a rough one" }

function M.build(app, on_next)
    local c = app.campaign
    local j = adventure.journey(c)
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    kit.text(24, 14, string.upper(MODULE.title), "title30", theme.gold)
    local ending = j.ending and j.ending.name or "Unfinished"
    kit.text(24, 58, "The adventure, as your table played it: " .. util.int(adventure.week(c)) .. " sessions. Ending: " .. ending .. ".",
        "ui18", theme.text)
    kit.text(24, 82, MODULE.credit, "ui14", theme.faint)
    -- The map, with the route.
    require("game.ui.museum_prep_view").draw_map(app, 24, 112, 380, 300)
    -- The rooms, in the order they played.
    local x, y, w = 424, 112, 560
    -- (The key from this adventure's first session: a party carried on starts at session 6, not 1. The playtest, November 6.)
    local s1 = (c.adv and c.adv.week0 or 0) + 1
    kit.text(x, y, "THE ROUTE  (S" .. util.int(s1) .. ": in session " .. util.int(s1) .. ")", "ui14", theme.dim)
    y = y + 22
    -- (A long prologue: the marks lines go, Euryale's card beside it lists them, so the ending
    -- still fits above the friends. The November 4 engine run had it running under them.)
    local LH = kit.line_height("ui14")
    local rows = #j.rooms
    for _, r in ipairs(j.rooms) do
        rows = rows + ((#r.marks > 0) and 1 or 0)
    end
    -- (Rooms never seen, and what someone else did there for them between sessions: Flitwidget woke the
    -- Mech. The confirming playtest's seed 54 had Hans fight for them, and only "Never seen" here.)
    local never
    if #j.skipped > 0 then
        local names = {}
        for _, n in ipairs(j.skipped) do
            table.insert(names, util.lower_first(n))
        end
        never = "Never seen: " .. util.join_names(names) .. "."
        for _, b in ipairs(j.between or {}) do
            never = never .. " Between sessions (S" .. util.int(b.week or 0) .. "): " .. b.text
        end
    end
    local room_for = 425 - y - (j.ending and 62 or 0) - (never and (kit.text_height(never, "ui14", w) + 10) or 0)
    local show_marks = rows * LH <= room_for
    -- Each room's story in as many lines as the route has room for, whole: all of it, its first
    -- sentence, or that sentence's first clause, so a line never stops halfway (the third playtest:
    -- "made the hunters come t...", "fought the..."). The whole of it on hover.
    local per = math.max(1, math.floor((room_for - (show_marks and (rows - #j.rooms) * LH or 0)) / (#j.rooms * LH)))
    local gl = require "game.ui.gloss"
    for i, r in ipairs(j.rooms) do
        -- (What happened there, one thing to the next, from the event log: R14. A room the log has no
        -- story for, an old save's, says how it went. A fight that happened is part of the route. F20.)
        local head = util.int(i) .. ".  " .. r.name .. " (S" .. util.int(r.week or 0) .. "): "
        local plain = (OUTCOME[r.outcome] or "done") .. (r.fought and (", and a fight with " .. r.fought) or "")
        local told, whole
        local said = r.said and ("They " .. r.said) or nil
        if r.chain and #r.chain > 0 then
            whole = table.concat(r.chain, " ")
            local all = string.gsub(whole, "%.$", "")
            local first = string.gsub(r.chain[1], "%.$", "")
            local clause = string.match(first, "^(.-), [sb][ou]t? ") or first
            local part = string.match(clause, "^(.-), ") or clause
            -- (All of it, or what it came to, before its first beat alone: "they tried to coax the rats out with
            -- food, but it didn't work" was a fight they won.)
            for _, t in ipairs({ all, said or first, first, clause, part }) do
                if not told and #kit.wrap(head .. t, "ui14", w) <= per then
                    told = t
                end
            end
        elseif said and #kit.wrap(head .. said, "ui14", w) <= per then
            told = said     -- (not "went their way": the rooms upstairs, where they found a cork for a ring)
        end
        -- (The plain words must fit too: just how it went, if a fight's name makes them too long.)
        if not told and #kit.wrap(head .. plain, "ui14", w) > per then
            plain = OUTCOME[r.outcome] or "done"
        end
        local line = head .. (told or plain)
        local nl = math.min(per, #kit.wrap(line, "ui14", w))
        local col = r.outcome == "win" and theme.text or theme.orange
        if whole then
            gl.card_spot(x - 2, y - 1, w + 4, nl * LH, r.name, whole)
        end
        kit.text(x, y, line, "ui14", col, { w = w, lines = nl })
        y = y + LH * nl
        if #r.marks > 0 and show_marks then
            kit.text(x + 22, y, "Left on her card: " .. table.concat(r.marks, ", "), "ui14", theme.gold, { w = w - 22, lines = 1 })
            y = y + LH
        end
    end
    if never then
        y = y + 6
        kit.text(x, y, never, "ui14", theme.faint, { w = w })
        y = y + kit.text_height(never, "ui14", w) + 4
    end
    if j.ending then
        y = y + 8
        kit.text(x, y, j.ending.line, "ui14", theme.dim, { w = w, lines = 3 })
    end
    -- Euryale's final card.
    require("game.ui.museum_prep_view").boss_card(app, 1000, 112, 576, 300, false)
    -- The friends.
    local cw = (kit.W - 48 - 36) / 4
    local st = c.adv
    for i, key in ipairs(content.players.order) do
        local p = c:player(key)
        if p then
            local px = 24 + (i - 1) * (cw + 12)
            local py = 430
            kit.box(px, py, cw, 390, theme.panel, { radius = 12 })
            kit.dot(px + 30, py + 28, 40, panels.COLORS[key] or theme.panel3)
            kit.picture(px + 12, py + 10, 36, 36, panels.face(key))
            kit.text(px + 60, py + 10, p.name, "ui22b", theme.text)
            kit.text(px + 60, py + 38, p.char .. ", " .. string.lower(p.class_name), "ui14", theme.dim)
            local hy = py + 72
            local h = adventure.hook(c, key)
            if h then
                kit.text(px + 14, hy, "CAME FOR", "ui14", theme.dim)
                kit.text(px + 100, hy, h.name, "ui14", theme.gold)
                hy = hy + 22
            end
            kit.text(px + 14, hy, "THEIR HISTORY", "ui14", theme.dim)
            hy = hy + 20
            local aspects = (st.aspects or {})[key] or {}
            if #aspects == 0 then
                kit.text(px + 14, hy, "Nothing for the history books this time.", "ui14", theme.faint, { w = cw - 28 })
                hy = hy + 20
            end
            for k = 1, math.min(4, #aspects) do
                kit.text(px + 14, hy, "- " .. aspects[k], "ui14", theme.text, { w = cw - 28, lines = 2 })
                hy = hy + kit.text_height("- " .. aspects[k], "ui14", cw - 28) + 2
            end
            -- (What they really said when it ended, not the first line on the list.)
            local lines = MODULE.want_more[key]
            local first = lines and lines[#lines]
            local said_text = (st.want_said or {})[key] or (type(first) == "table" and first[1] or first)
            if said_text then
                local said = "\"" .. util.fill(said_text, { char = p.char }) .. "\""
                kit.text(px + 14, py + 300, said, "story22", theme.text, { w = cw - 28, lines = 3 })
            end
        end
    end
    -- Carry on (Conner, November 6: two adventures tied together keep the party, what they carry and know, and the
    -- threads left open). The next adventure that can follow this one, with this party: the main way on, lit; the
    -- questions are how you finish here instead, and say so. (The playtest, November 6: "A few questions" was the
    -- bright one, with nothing saying it ends the run.)
    local nxt = on_next and app.carry_on and adventure.next_up(c)
    kit.button(1356, 836, 220, 48, nxt and "Finish here  >" or "A few questions  >", function()
        if on_next then
            on_next()
        end
    end, { color = (not nxt) and theme.go or nil, hover = (not nxt) and theme.go_hover or nil, font = "ui22b", key = "to_survey" })
    if nxt then
        local m = require("game.data.adventures").part(nxt, "module") or {}
        local label = "Carry on into " .. (m.title or nxt) .. "  >"
        local bw = math.max(300, kit.width(label, "ui22b") + 40)
        kit.button(1356 - 16 - bw, 836, bw, 48, label, function()
            app.carry_on(nxt)
        end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "carry_on" })
        kit.text(1340 - 16 - bw, 850, "Same heroes, what they carry and know. Or finish here, with a few questions.", "ui14",
            theme.dim, { pivot = gui.PIVOT_NE })
    else
        kit.text(1340, 850, "Then you're done. In the full game, the campaign would come next.", "ui14", theme.dim, { pivot = gui.PIVOT_NE })
    end
end

return M
