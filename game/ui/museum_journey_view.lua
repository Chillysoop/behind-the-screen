-- The journey recap (v2): when the museum is done, the whole prologue on one page. The route the
-- party took, what each room left behind, Euryale's final card, and each friend: what their hero
-- did (their history, Wildermyth-style), and what they want next. Then the playtest questions.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local panels = require "game.ui.panels"
local content = require "game.model.content"
local util = require "game.model.util"
local adventure = require "game.model.adventure"

local MODULE = adventure.data
local M = {}

local OUTCOME = { win = "went their way", lose = "a rough one" }

function M.build(app, on_next)
    local c = app.campaign
    local j = adventure.journey(c)
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    kit.text(24, 14, string.upper(MODULE.title), "title30", theme.gold)
    local ending = j.ending and j.ending.name or "Unfinished"
    kit.text(24, 58, "The prologue, as your table played it: " .. util.int(c.week) .. " sessions. Ending: " .. ending .. ".",
        "ui18", theme.text)
    kit.text(24, 82, MODULE.credit, "ui14", theme.faint)
    -- The map, with the route.
    require("game.ui.museum_prep_view").draw_map(app, 24, 112, 380, 300)
    -- The rooms, in the order they played.
    local x, y, w = 424, 112, 560
    kit.text(x, y, "THE ROUTE", "ui14", theme.dim)
    y = y + 22
    -- (A long prologue: the marks lines go, Euryale's card beside it lists them, so the ending
    -- still fits above the friends. The November 4 engine run had it running under them.)
    local rows = #j.rooms
    for _, r in ipairs(j.rooms) do
        rows = rows + ((#r.marks > 0) and 1 or 0)
    end
    local room_for = 425 - y - (j.ending and 62 or 0) - (#j.skipped > 0 and 26 or 0)
    local show_marks = rows * 18 <= room_for
    -- (Each room's story gets two lines when the route has the room for it: R14.)
    local two = (#j.rooms * 2 + (show_marks and (rows - #j.rooms) or 0)) * 18 <= room_for
    for i, r in ipairs(j.rooms) do
        -- (What happened there, one thing to the next, from the event log: R14. A room the log has no
        -- story for, an old save's, says how it went. A fight that happened is part of the route. F20.)
        local head = util.int(i) .. ".  " .. r.name .. "  (session " .. util.int(r.week or 0) .. "): "
        local told
        if r.chain then
            -- (As much of the room's story as fits: all of it, its first sentence, or that sentence's
            -- first clause, so a line never stops halfway through a "so".)
            local room = w * (two and 2 or 1) - kit.width(head, "ui14") - 12
            local all = string.gsub(table.concat(r.chain, " "), "%.$", "")
            local first = string.gsub(r.chain[1], "%.$", "")
            local clause = string.match(first, "^(.-), [sb][ou]t? ") or first
            local part = string.match(clause, "^(.-), ") or clause
            for _, t in ipairs({ all, first, clause, part }) do
                if not told and kit.width(t, "ui14") <= room then
                    told = t
                end
            end
            told = told or part
        end
        local line = head .. (told or ((OUTCOME[r.outcome] or "done") .. (r.fought and (", and a fight with " .. r.fought) or "")))
        local nl = (two and kit.text_height(line, "ui14", w) > 18) and 2 or 1
        kit.text(x, y, line, "ui14", r.outcome == "win" and theme.text or theme.orange, { w = w, lines = nl })
        y = y + 18 * nl
        if #r.marks > 0 and show_marks then
            kit.text(x + 22, y, "Left on her card: " .. table.concat(r.marks, ", "), "ui14", theme.gold, { w = w - 22, lines = 1 })
            y = y + 18
        end
    end
    if #j.skipped > 0 then
        y = y + 6
        local names = {}
        for _, n in ipairs(j.skipped) do
            table.insert(names, util.lower_first(n))
        end
        local line = "Never seen: " .. util.join_names(names) .. "."
        kit.text(x, y, line, "ui14", theme.faint, { w = w })
        y = y + kit.text_height(line, "ui14", w) + 4
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
    kit.button(1356, 836, 220, 48, "A few questions  >", function()
        if on_next then
            on_next()
        end
    end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "to_survey" })
    kit.text(1340, 850, "Then you're done. In the full game, the campaign would come next.", "ui14", theme.dim, { pivot = gui.PIVOT_NE })
end

return M
