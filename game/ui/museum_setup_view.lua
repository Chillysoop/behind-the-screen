-- Session Zero's second page in the museum (v2): why each hero came. Each player has two of the
-- book's background hooks and leans toward one; you pick. A hook ties the hero to a room, where
-- they'll sit up when it plays. Then week 1.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local panels = require "game.ui.panels"
local content = require "game.model.content"
local util = require "game.model.util"
local adventure = require "game.model.adventure"

local MODULE = adventure.data
local M = {}

local function picks(app)
    app.s0.hooks = app.s0.hooks or {}
    return app.s0.hooks
end

function M.ready(app)
    local h = picks(app)
    for _, key in ipairs(content.players.order) do
        if app.campaign:player(key) and not h[key] then
            return false
        end
    end
    return true
end

function M.start(app)
    if not M.ready(app) then
        return false
    end
    local c = app.campaign
    for key, id in pairs(picks(app)) do
        adventure.set_hook(c, key, id)
        local h = adventure.hook(c, key)
        local p = c:player(key)
        if h and p then
            -- They got the reason they leaned toward, or the other one.
            local score = require "game.model.score"
            score.add(p, "investment", h.lean >= 2 and 3 or 1)
        end
    end
    c:session_zero(app.s0)
    app.s0 = nil
    app.go("prep")
    return true
end

function M.build(app)
    local c = app.campaign
    local h = picks(app)
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    kit.text(24, 14, "SESSION ZERO", "title30", theme.gold)
    kit.text(280, 24, "Why did each hero come to the museum? Each player leans one way. You pick.", "ui18", theme.dim)
    kit.text(24, 70, MODULE.title .. ", by " .. MODULE.author .. ". " .. MODULE.pitch, "ui14", theme.faint, { w = 1500 })
    local x0, y0 = 24, 100
    local cw, ch = 770, 352
    for i, key in ipairs(content.players.order) do
        local p = c:player(key)
        if p then
            local x = x0 + ((i - 1) % 2) * (cw + 12)
            local y = y0 + math.floor((i - 1) / 2) * (ch + 12)
            kit.box(x, y, cw, ch, theme.panel, { radius = 12 })
            kit.dot(x + 32, y + 30, 40, panels.COLORS[key] or theme.panel3)
            kit.picture(x + 14, y + 12, 36, 36, panels.face(key))
            kit.text(x + 62, y + 12, p.name, "ui22b", theme.text)
            kit.text(x + 62 + kit.width(p.name, "ui22b") + 10, y + 17, p.char .. ", " .. string.lower(p.class_name), "ui18", theme.dim)
            local hooks = MODULE.hooks[key]
            local by = y + 62
            for _, hk in ipairs(hooks) do
                local on = h[key] == hk.id
                local room = MODULE.rooms[hk.room]
                if on then
                    kit.box(x + 13, by - 3, cw - 26, 130, theme.select, { radius = 10 })
                end
                kit.button(x + 16, by, cw - 32, 124, "", function()
                    h[key] = hk.id
                    app.refresh()
                end, { color = on and theme.panel3 or theme.panel2, hover = theme.button_hover, key = "hook_" .. key .. "_" .. hk.id })
                kit.text(x + 30, by + 8, hk.name, "ui18b", theme.gold)
                if hk.lean >= 2 then
                    kit.box(x + cw - 170, by + 8, 136, 22, theme.green, { radius = 6 })
                    kit.text(x + cw - 162, by + 10, p.name .. " leans here", "ui14", theme.ink)
                end
                kit.text(x + 30, by + 34, hk.text, "ui18", theme.text, { w = cw - 80, lines = 2 })
                kit.text(x + 30, by + 82, "\"" .. hk.says .. "\"", "ui14", theme.dim, { w = cw - 80, lines = 1 })
                kit.text(x + 30, by + 102, "Pays off in " .. util.lower_first(room.name) .. ".", "ui14", theme.faint)
                by = by + 136
            end
        end
    end
    kit.button(24, 836, 180, 44, "<  The table", function()
        app.s0.page = nil
        app.refresh()
    end, { font = "ui18b", key = "hooks_back" })
    local ready = M.ready(app)
    kit.button(1356, 830, 220, 50, "Session 1  >", function()
        M.start(app)
    end, { enabled = ready, color = theme.go, hover = theme.go_hover, font = "ui22b", key = "hooks_start" })
    kit.text(1340, 846, ready and "Next: the first session's prep." or "Pick a reason for every hero.", "ui14", theme.dim,
        { pivot = gui.PIVOT_NE })
end

return M
