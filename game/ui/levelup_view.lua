-- The level-up moment (M6): a modal over the report or the prep board. At level 3
-- everyone picks a subclass on their own, and says why; at level 4 everyone takes
-- an Ability Score Improvement.

local kit = require "game.ui.kit"
local ambience = require "game.ui.ambience"
local theme = require "game.ui.theme"
local content = require "game.model.content"
local subclasses = require "game.rules.subclasses"
local util = require "game.model.util"
local talk_mod = require "game.model.talk"

local M = {}

-- Level the party up and remember what everyone said.
function M.level_up(app)
    local c = app.campaign
    local moment = c:level_up()
    if not moment then
        return nil
    end
    c.chat_talk = c.chat_talk or talk_mod.new(c.rng)
    local talk = c.chat_talk
    moment.lines = {}
    for _, p in ipairs(c.players) do
        local trigger = "level_up"
        local pick = c.picks[p.key]
        if moment.level == 3 and pick then
            trigger = "pick_" .. pick.sub
        end
        local text = talk:line(trigger, p, { must = true })
        moment.lines[p.key] = text
    end
    app.levelup = moment
    ambience.level_up()
    -- Levelling up on the report screen happens between sessions: save it, so stopping
    -- here doesn't lose the picks (in prep it waits for the end of the night).
    if app.screen == "report" and app.save_campaign then
        app.save_campaign()
    end
    app.refresh()
    return moment
end

function M.close(app)
    app.levelup = nil
    app.refresh()
end

function M.modal(app)
    local m = app.levelup
    if not m then
        return
    end
    local c = app.campaign
    kit.layer("levelup", true)
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.6), { round = false })
    local x, y, w, h = 120, 80, 1360, 740
    kit.box(x, y, w, h, theme.bg, { radius = 14 })
    kit.text(x + w / 2, y + 22, "LEVEL " .. util.int(m.level) .. "!", "title30", theme.gold, { pivot = gui.PIVOT_N })
    local sub = m.level == 3 and "Everyone picks a subclass. You don't get a say, and that's the fun part."
        or "Everyone takes an Ability Score Improvement: +2 to their best ability."
    kit.text(x + w / 2, y + 64, sub, "ui18", theme.dim, { pivot = gui.PIVOT_N })
    local cw, gap = 310, 20
    local cx0 = x + (w - (4 * cw + 3 * gap)) / 2
    for i, p in ipairs(c.players) do
        local cx = cx0 + (i - 1) * (cw + gap)
        local cy = y + 104
        kit.box(cx, cy, cw, 540, theme.panel, { radius = 10 })
        kit.text(cx + 16, cy + 12, p.name, "ui22b", theme.text)
        kit.text(cx + 16, cy + 42, p.char .. ", " .. p.class_name, "ui18", theme.dim)
        local ty = cy + 74
        if p.on_break then
            kit.text(cx + 16, cy + 68, "On a break: picked by text from home.", "ui14", theme.orange, { w = cw - 32, lines = 1 })
            ty = cy + 94
        end
        local pick = c.picks[p.key]
        local line = m.lines and m.lines[p.key]
        local qh = line and math.max(80, 24 + kit.text_height(line, "hand24", cw - 64)) or 0
        local qy = cy + 540 - qh - 16
        if m.level == 3 and pick then
            kit.text(cx + 16, ty, string.upper(pick.sub_name), "ui22b", theme.gold, { w = cw - 32 })
            ty = ty + 32
            kit.text(cx + 16, ty, pick.why, "ui14", theme.text, { w = cw - 32, lines = 3 })
            ty = ty + kit.text_height(pick.why, "ui14", cw - 32) + 12
            -- Each feature in full while there's room; anything that doesn't fit is on their sheet.
            local quote_top = qy - 10
            local lh = kit.line_height("ui14")
            local more = false
            for _, f in ipairs(subclasses.list[pick.sub].features) do
                local need = lh + #kit.wrap(f[2], "ui14", cw - 32) * lh
                if ty + need > quote_top - lh then
                    more = true
                    break
                end
                kit.text(cx + 16, ty, f[1], "ui14", theme.gold, { w = cw - 32, lines = 1 })
                ty = ty + lh
                kit.text(cx + 16, ty, f[2], "ui14", theme.dim, { w = cw - 32 })
                ty = ty + need - lh + 8
            end
            if more then
                kit.text(cx + 16, ty, "More on their character sheet (Features).", "ui14", theme.faint)
            end
        else
            kit.text(cx + 16, ty, "+2 to their best ability", "ui18b", theme.gold, { w = cw - 32 })
            ty = ty + 34
        end
        if line then
            kit.box(cx + 16, qy, cw - 32, qh, kit.rgba("#f3df8a"), { radius = 4 })
            kit.text(cx + 32, qy + 12, line, "hand24", theme.ink, { w = cw - 64 })
        end
    end
    kit.button(x + w / 2 - 140, y + h - 76, 280, 52, "Back to the table", function()
        M.close(app)
    end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "levelup_close" })
end

return M
