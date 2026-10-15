-- A storyline's or faction's mark, drawn the same way everywhere (October 15): its icon in its
-- color, or for a hero's own story, their face. game/model/lore.lua says which is which.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local panels = require "game.ui.panels"
local lore = require "game.model.lore"

local M = {}

local function darker(col, f)
    return vmath.vector4(col.x * f, col.y * f, col.z * f, col.w or 1)
end
M.darker = darker

-- size: the icon's box. on_paper: darken it to read on the light cards.
function M.storyline(app, id, x, y, size, on_paper)
    local m = lore.storyline(app.campaign, id)
    if not m then
        return false
    end
    if m.face then
        kit.dot(x + size / 2, y + size / 2, size, panels.COLORS[m.face] or theme.panel3)
        kit.picture(x + 1, y + 1, size - 2, size - 2, panels.face(m.face))
    else
        local col = m.color and kit.rgba(m.color) or theme.gold
        kit.icon(x, y, size, m.icon, on_paper and darker(col, 0.7) or col)
    end
    return true
end

-- A mark as lore.clue_mark gives it: { face } or { icon, color }.
function M.mark(m, x, y, size, on_paper)
    if m.face then
        kit.dot(x + size / 2, y + size / 2, size, panels.COLORS[m.face] or theme.panel3)
        kit.picture(x + 1, y + 1, size - 2, size - 2, panels.face(m.face))
    else
        local col = m.color and kit.rgba(m.color) or theme.gold
        kit.icon(x, y, size, m.icon or "story", on_paper and darker(col, 0.7) or col)
    end
end

function M.faction(id, x, y, size, on_paper)
    local m = lore.faction(id)
    local col = kit.rgba(m.color)
    kit.icon(x, y, size, m.icon, on_paper and darker(col, 0.7) or col)
end

-- A lore icon by name, in a color given as "#rrggbb" (the opening's rows, a truth).
function M.icon(name, color, x, y, size)
    kit.icon(x, y, size, name or "story", color and kit.rgba(color) or theme.gold)
end

return M
