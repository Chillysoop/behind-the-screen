-- A small "are you sure?" modal (the slice rework): a question, a list of what's still
-- waiting, and two buttons. app.ask = { title, text, items = { text... }, yes, no, on_yes, on_no }
-- is drawn on top of the screen by game.gui_script's build_screen until either button closes it.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"

local M = {}

function M.ask(app, spec)
    app.ask = spec
    app.refresh()
end

function M.close(app)
    app.ask = nil
    app.refresh()
end

function M.draw(app)
    local a = app.ask
    if not a then
        return
    end
    kit.layer("ask", true)
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.6), { round = false })
    local w = 620
    local tw = w - 64
    local h = 64 + kit.text_height(a.text or "", "ui18", tw) + 20
    for _, it in ipairs(a.items or {}) do
        h = h + kit.text_height(it, "ui18", tw - 24) + 8
    end
    h = h + 80
    local x, y = (kit.W - w) / 2, (kit.H - h) / 2
    kit.box(x - 2, y - 2, w + 4, h + 4, theme.gold, { radius = 14 })
    kit.box(x, y, w, h, theme.bg, { radius = 13 })
    kit.text(x + 32, y + 22, a.title or "Are you sure?", "ui22b", theme.gold)
    local ty = y + 64
    if a.text then
        kit.text(x + 32, ty, a.text, "ui18", theme.text, { w = tw })
        ty = ty + kit.text_height(a.text, "ui18", tw) + 14
    end
    for _, it in ipairs(a.items or {}) do
        kit.dot(x + 40, ty + 11, 10, theme.orange)
        kit.text(x + 56, ty, it, "ui18", theme.text, { w = tw - 24 })
        ty = ty + kit.text_height(it, "ui18", tw - 24) + 8
    end
    local by = y + h - 64
    kit.button(x + 32, by, 250, 44, a.no or "Go back", function()
        local fn = a.on_no
        M.close(app)
        if fn then
            fn()
        end
    end, { font = "ui18b", key = "ask_no" })
    kit.button(x + w - 32 - 250, by, 250, 44, a.yes or "Continue", function()
        local fn = a.on_yes
        app.ask = nil
        if fn then
            fn()
        else
            app.refresh()
        end
    end, { font = "ui18b", color = theme.go, hover = theme.go_hover, key = "ask_yes" })
end

return M
