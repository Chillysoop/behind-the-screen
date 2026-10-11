-- The welcome card, over the room.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local content = require "game.model.content"

local M = {}

function M.build(app)
    local x, y, w, h = 470, 120, 660, 660
    kit.box(x, y, w, h, kit.rgba("#1b1411", 0.92), { radius = 14 })
    kit.text(x + w / 2, y + 30, "BEHIND THE SCREEN", "title30", theme.gold, { pivot = gui.PIVOT_N })
    kit.text(x + w / 2, y + 74, "A cozy game about running the table for your friends", "ui18", theme.dim, { pivot = gui.PIVOT_N })
    local lines = {
        { "Prep", "Pick a type for each of three scenes, then fill their slots from your hand. Prep time is limited, so some slots stay empty and get improvised at the table." },
        { "Game night", "It plays itself. When a card slides across your screen, you make the call. Big rolls can go in the open or behind the screen." },
        { "The table", "Mara, Dev, Jess and Sam each want something different. Watch their tells, read the group chat, and keep them coming back." },
        { "Between", "Answer messages, settle arguments, plant mysteries and pay them off. Level the party up when it feels earned." },
        { "This build", "Session Zero, then the first four sessions of the arc. Afterwards, a few questions about how it went." },
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
        if saved.at_night then
            label = "Continue: Session " .. saved.week .. " night  >"   -- saved at Run game night
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
                app.go("planner")
            else
                app.confirm_new = true
                app.refresh()
            end
        end, { font = "ui18b", key = "new_campaign", color = app.confirm_new and theme.red or nil })
    else
        kit.button(x + w / 2 - 150, y + h - 110, 300, 56, "Plan the campaign  >", function()
            app.go("planner")
        end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "session_zero" })
    end
    local foot
    if app.resume_error then
        foot = "The saved campaign couldn't be opened (" .. app.resume_error .. "). Start a new one."
    elseif saved and app.confirm_new then
        foot = "Click again to start over. Your saved campaign is replaced once you finish the new Session Zero."
    elseif saved then
        foot = "A new campaign replaces the saved one once you finish its Session Zero."
    elseif app.tester_build then
        foot = "The game saves after every session, so you can stop and pick it up later."
    else
        foot = "F2: free camera sandbox    F3: show the numbers    The game saves after every session."
    end
    kit.text(x + w / 2, y + h - 40, foot, "ui14", app.resume_error and theme.orange or theme.faint,
        { pivot = gui.PIVOT_N, w = w - 60 })
end

return M
