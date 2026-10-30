-- The welcome card, over the room.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local content = require "game.model.content"

local M = {}

-- The prototype notice (October 29, for outside playtesters): on every launch, before the
-- welcome card. One click to agree, then the welcome card as before.
local NOTICE = {
    "This is a prototype of an engine for running all kinds of tabletop RPG campaigns.",
    "This prologue runs a real published adventure, The Museum of Nightmares by Luke Russell, adapted for private testing.",
    "It tests the play loop and mechanics. Art and polish come later.",
}

local function notice(app)
    local x, y, w = 500, 0, 600
    local tw = w - 100
    local body = 0
    for _, line in ipairs(NOTICE) do
        body = body + kit.text_height(line, "ui18", tw) + 18
    end
    local h = 100 + body + 100
    y = math.floor((900 - h) / 2)
    kit.box(x, y, w, h, kit.rgba("#1b1411", 0.94), { radius = 14 })
    kit.text(x + w / 2, y + 30, "BEFORE YOU PLAY", "title30", theme.gold, { pivot = gui.PIVOT_N })
    local ly = y + 96
    for _, line in ipairs(NOTICE) do
        kit.text(x + 50, ly, line, "ui18", theme.text, { w = tw })
        ly = ly + kit.text_height(line, "ui18", tw) + 18
    end
    kit.button(x + w / 2 - 110, y + h - 84, 220, 56, "Agree", function()
        app.notice_ok = true
        app.refresh()
    end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "agree" })
end

function M.build(app)
    if not app.notice_ok then
        return notice(app)
    end
    local x, y, w, h = 470, 120, 660, 660
    kit.box(x, y, w, h, kit.rgba("#1b1411", 0.92), { radius = 14 })
    kit.text(x + w / 2, y + 30, "BEHIND THE SCREEN", "title30", theme.gold, { pivot = gui.PIVOT_N })
    kit.text(x + w / 2, y + 74, "A cozy game about running the table for your friends", "ui18", theme.dim, { pivot = gui.PIVOT_N })
    local lines = {
        { "Prep", "Tonight's rooms are on the museum map. Prep the ones you think they'll reach, and choose how you'll run each one. Prep time is limited." },
        { "Game night", "It plays itself, room by room. When a card slides across your screen, you make the call. The party picks the way at forks." },
        { "The table", "Mara, Dev, Jess and Sam each want something different. Watch their tells, read the group chat, and keep them coming back." },
        { "Between", "Answer their requests, decide where loose ends go, and watch the Gorgon's card change with everything they do." },
        { "This build", "Session Zero, then The Museum of Nightmares: a one-shot prologue that runs as many sessions as it needs." },
    }
    local ly = y + 120
    for _, l in ipairs(lines) do
        kit.text(x + 40, ly, l[1], "ui18b", theme.gold)
        kit.text(x + 160, ly, l[2], "ui18", theme.text, { w = w - 200 })
        ly = ly + kit.text_height(l[2], "ui18", w - 200) + 18
    end
    local saved = app.resume and app.resume.head
    if saved then
        -- A campaign saved between sessions (M7): carry on, or start a new one.
        local sessions = content.arc.SESSIONS
        local label
        if content.arc.module then
            -- v2: the museum runs as many sessions as it takes.
            label = saved.at_night and ("Continue: Session " .. saved.week .. " night  >")
                or (saved.at_prep and ("Continue: Session " .. saved.week .. " prep  >"))
                or ("Continue: Session " .. (saved.week + 1) .. "  >")
        elseif saved.at_night then
            label = "Continue: Session " .. saved.week .. " night  >"   -- saved at Run game night
        elseif saved.at_prep then
            label = "Continue: Session " .. saved.week .. " prep  >"    -- saved mid-prep (A11)
        elseif saved.week >= sessions and not saved.survey_done then
            label = "Continue: end of the first act  >"
        elseif saved.week >= sessions then
            label = "Continue: Session " .. (saved.week + 1) .. "  >"
        elseif saved.week == 0 then
            label = "Continue: Session 1 of " .. sessions .. "  >"
        else
            label = "Continue: Session " .. (saved.week + 1) .. " of " .. sessions .. "  >"
        end
        kit.button(x + 50, y + h - 110, 340, 56, label, function()
            app.continue_campaign()
        end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "continue" })
        -- Two clicks: the first only asks, so a stray click can't start over.
        kit.button(x + 410, y + h - 110, 200, 56, app.confirm_new and "Yes, start over" or "New campaign", function()
            if app.confirm_new then
                app.confirm_new = nil
                app.new_campaign()
            else
                app.confirm_new = true
                app.refresh()
            end
        end, { font = "ui18b", key = "new_campaign", color = app.confirm_new and theme.red or nil })
    else
        kit.button(x + w / 2 - 150, y + h - 110, 300, 56, "Session Zero  >", function()
            app.new_campaign()
        end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "session_zero" })
    end
    local foot
    if app.resume_error then
        foot = "The saved campaign couldn't be opened (" .. app.resume_error .. "). Start a new one."
    elseif saved and app.confirm_new then
        foot = "Click again to start over. Your saved campaign is replaced once you finish the new Session Zero."
    elseif saved then
        foot = "A new campaign replaces the saved one once you finish its Session Zero."
    else
        -- (The developer keys aren't the player's business: October 20.)
        foot = "The game saves after every session, so you can stop and pick it up later."
    end
    kit.text(x + w / 2, y + h - 40, foot, "ui14", app.resume_error and theme.orange or theme.faint,
        { pivot = gui.PIVOT_N, w = w - 60 })
end

return M
