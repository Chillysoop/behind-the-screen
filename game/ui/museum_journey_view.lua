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
    for i, r in ipairs(j.rooms) do
        local line = util.int(i) .. ".  " .. r.name .. "  (session " .. util.int(r.week or 0) .. "): " .. (OUTCOME[r.outcome] or "done")
        kit.text(x, y, line, "ui14", r.outcome == "win" and theme.text or theme.orange, { w = w, lines = 1 })
        y = y + 18
        if #r.marks > 0 then
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
                kit.text(px + 14, hy, "Kept their head down, mostly.", "ui14", theme.faint, { w = cw - 28 })
                hy = hy + 20
            end
            for k = 1, math.min(4, #aspects) do
                kit.text(px + 14, hy, "- " .. aspects[k], "ui14", theme.text, { w = cw - 28, lines = 2 })
                hy = hy + kit.text_height("- " .. aspects[k], "ui14", cw - 28) + 2
            end
            local lines = MODULE.want_more[key]
            if lines then
                local said = "\"" .. lines[1] .. "\""
                kit.text(px + 14, py + 300, said, "story22", theme.text, { w = cw - 28, lines = 3 })
            end
        end
    end
    kit.button(1356, 836, 220, 48, "A few questions  >", function()
        if on_next then
            on_next()
        end
    end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "to_survey" })
    kit.text(1340, 850, "Then you're done: the full campaign comes next.", "ui14", theme.dim, { pivot = gui.PIVOT_NE })
end

return M
