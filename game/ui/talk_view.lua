-- The one-on-one before the session (A6): "Talk 2h" opens this, a short conversation over
-- coffee. app.talk is the conversation (game/model/one_on_one.lua); drawn on top of prep by
-- game.gui_script's build_screen until you close it. Keys: talk_opt_<i>, talk_done.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local panels = require "game.ui.panels"
local one_on_one = require "game.model.one_on_one"

local M = {}

function M.open(app, key)
    local prep = app.campaign.prep
    if not prep:talk(key) then
        return false
    end
    app.talk = one_on_one.start(app.campaign, prep, key)
    app.refresh()
    return true
end

function M.draw(app)
    local t = app.talk
    if not t then
        return
    end
    local camp = app.campaign
    kit.layer("talk", true)
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.6), { round = false })
    local w, tw = 760, 760 - 64
    local x = (kit.W - w) / 2
    local lines = {}
    for _, l in ipairs(t.log) do
        local who = l.who == "dm" and "You" or (camp:player(l.who) and camp:player(l.who).name or l.who)
        table.insert(lines, { who = l.who, text = (l.who == "dm" and #lines == 0) and l.text or (who .. ": " .. l.text) })
    end
    local opts = one_on_one.options(t)
    local h = 70
    for _, l in ipairs(lines) do
        h = h + kit.text_height(l.text, "ui18", tw - 50) + 12
    end
    local learned
    if t.done then
        learned = "What you learned: mood " .. string.lower(t.learned.mood or "?") .. ". " .. (one_on_one.summary(t.learned) or "")
        h = h + kit.text_height(learned, "ui18b", tw) + 20 + 60
    else
        for _, o in ipairs(opts) do
            h = h + math.max(40, kit.text_height(o, "ui18", tw - 24) + 16) + 8
        end
        h = h + 20
    end
    local y = math.max(20, (kit.H - h) / 2)
    kit.box(x - 2, y - 2, w + 4, h + 4, theme.gold, { radius = 14 })
    kit.box(x, y, w, h, theme.bg, { radius = 13 })
    kit.dot(x + 50, y + 34, 40, panels.COLORS[t.key] or theme.panel3)
    kit.picture(x + 32, y + 16, 36, 36, panels.face(t.key))
    kit.text(x + 82, y + 22, "One-on-one with " .. t.with, "ui22b", theme.gold)
    local ty = y + 70
    for _, l in ipairs(lines) do
        local col = l.who == "dm" and theme.dim or theme.text
        kit.text(x + 32 + (l.who == "dm" and 0 or 24), ty, l.text, "ui18", col, { w = tw - 50 })
        ty = ty + kit.text_height(l.text, "ui18", tw - 50) + 12
    end
    if t.done then
        kit.text(x + 32, ty + 8, learned, "ui18b", theme.teal, { w = tw })
        kit.button(x + w - 32 - 200, y + h - 60, 200, 44, "Done", function()
            app.talk = nil
            app.refresh()
        end, { font = "ui18b", color = theme.go, hover = theme.go_hover, key = "talk_done" })
    else
        for i, o in ipairs(opts) do
            local oh = math.max(40, kit.text_height(o, "ui18", tw - 24) + 16)
            kit.button(x + 32, ty, tw, oh, o, function()
                one_on_one.choose(camp, camp.prep, t, i)
                app.refresh()
            end, { align = "left", color = theme.button, hover = theme.button_hover, key = "talk_opt_" .. i })   -- (no number hints: the number keys are game night's)
            ty = ty + oh + 8
        end
    end
end

return M
