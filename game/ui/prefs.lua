-- The player's own settings, kept across campaigns in a small file beside the save.
--
-- Chill mode (October 26: "'default' mode be that you don't see any green / red happy / sad
-- circles from the players. There should be a toggle for chill mode"): off by default, you read
-- your friends from what they say and how they sit. On, the faces and dots come back on every
-- choice: who'd love it (green) and who wouldn't (red), on scene types, cards, Session Zero's
-- options and game night's calls.

local M = {}

local state = { chill = false }
local loaded = false

local function path()
    if sys and sys.get_save_file then
        local ok, p = pcall(sys.get_save_file, "behind_the_screen", "settings.txt")
        return ok and p or nil
    end
end

local function load()
    loaded = true
    local p = path()
    local f = p and io.open(p, "r")
    if not f then
        return
    end
    local text = f:read("*a") or ""
    f:close()
    state.chill = string.find(text, "chill=on", 1, true) ~= nil
end

local function save()
    local p = path()
    local f = p and io.open(p, "w")
    if f then
        f:write("chill=" .. (state.chill and "on" or "off") .. "\n")
        f:close()
    end
end

-- Whether the who'd-like-it faces and dots show.
function M.chill()
    if not loaded then
        load()
    end
    return state.chill
end

function M.set_chill(on)
    if not loaded then
        load()
    end
    state.chill = on and true or false
    save()
end

local LABEL = "Chill mode"

function M.switch_w(font)
    return require("game.ui.kit").width(LABEL, font or "ui14") + 70
end

-- What it says when you flip it.
function M.said(on)
    return on and "Chill mode on: green and red faces show who'd love each choice and who wouldn't."
        or "Chill mode off: read the table from what they say and how they sit."
end

-- The switch, wherever it sits: a pill with a light. Returns its width.
function M.switch(x, y, opts)
    local kit = require "game.ui.kit"
    local theme = require "game.ui.theme"
    opts = opts or {}
    local on = M.chill()
    local label = LABEL
    local font = opts.font or "ui14"
    local w = M.switch_w(font)
    local h = opts.h or 38
    kit.button(x, y, w, h, "", function()
        M.set_chill(not on)
        if opts.changed then
            opts.changed(not on)
        end
    end, { color = on and kit.rgba("#2f5a3c") or theme.panel2, hover = theme.button_hover, radius = h / 2,
           key = "chill_mode" })
    kit.text(x + 16, y + h / 2, label, font, on and theme.text or theme.dim, { pivot = gui.PIVOT_W, gloss = false })
    -- The little switch: a track and a knob, right when it's on.
    local tx, ty = x + w - 46, y + h / 2 - 9
    kit.box(tx, ty, 32, 18, on and theme.green or kit.rgba("#000000", 0.35), { radius = 9 })
    kit.dot(tx + (on and 23 or 9), ty + 9, 14, on and theme.text or theme.faint)
    return w
end

return M
