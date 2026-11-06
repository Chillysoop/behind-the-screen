-- The welcome card, over the room.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"

local M = {}

-- The prototype notice (October 29, for outside playtesters): on every launch, before the
-- welcome card. One click to agree, then the welcome card as before.
local function notice_lines()
    local adventures = require "game.data.adventures"
    local names = {}
    for _, id in ipairs(adventures.order or {}) do
        local m = adventures.part(id, "module")
        if m and m.title then
            table.insert(names, m.title .. (m.author and (" by " .. m.author) or ""))
        end
    end
    return {
        "This is a prototype of an engine for running all kinds of tabletop RPG campaigns.",
        "It runs real published adventures (" .. table.concat(names, "; ") .. "), adapted for private testing.",
        "It tests the play loop and mechanics. Art and polish come later.",
    }
end

local function notice(app)
    local x, y, w = 500, 0, 600
    local tw = w - 100
    local body = 0
    for _, line in ipairs(notice_lines()) do
        body = body + kit.text_height(line, "ui18", tw) + 18
    end
    local h = 100 + body + 100
    y = math.floor((900 - h) / 2)
    kit.box(x, y, w, h, kit.rgba("#1b1411", 0.94), { radius = 14 })
    kit.text(x + w / 2, y + 30, "BEFORE YOU PLAY", "title30", theme.gold, { pivot = gui.PIVOT_N })
    local ly = y + 96
    for _, line in ipairs(notice_lines()) do
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
    local x, y, w, h = 470, 90, 660, 720
    kit.box(x, y, w, h, kit.rgba("#1b1411", 0.92), { radius = 14 })
    kit.text(x + w / 2, y + 30, "BEHIND THE SCREEN", "title30", theme.gold, { pivot = gui.PIVOT_N })
    kit.text(x + w / 2, y + 74, "A cozy game about running the table for your friends", "ui18", theme.dim, { pivot = gui.PIVOT_N })
    local lines = {
        { "Prep", "Tonight's scenes are on the adventure's map. Prep the ones you think they'll reach, and choose how you'll run each one. Prep time is limited." },
        { "Game night", "It plays itself, room by room. When a card slides across your screen, you make the call. The party picks the way at forks." },
        { "The table", "Mara, Dev, Jess and Sam each want something different. Watch their tells, read the group chat, and keep them coming back." },
        { "Between", "Answer their requests, decide where loose ends go, and see what everything they do changes." },
        { "This build", "Session Zero, then the adventure you pick below, played over as many sessions as your table needs." },
    }
    local ly = y + 120
    for _, l in ipairs(lines) do
        kit.text(x + 40, ly, l[1], "ui18b", theme.gold)
        kit.text(x + 160, ly, l[2], "ui18", theme.text, { w = w - 200 })
        ly = ly + kit.text_height(l[2], "ui18", w - 200) + 18
    end
    -- The main menu (November 3): Continue (the newest save), Load (any save), New game.
    local saved = app.resume and app.resume.head
    local any = false
    for _, sv in ipairs(app.save_list or {}) do
        any = any or sv.found ~= nil
    end
    local bw, by = 420, y + h - 176
    -- Which adventure a new game is (November 6: any adventure, not the museum). One button cycles them.
    local adventures = require "game.data.adventures"
    local order = adventures.order or {}
    if #order > 1 then
        local pick = app.adventure_pick or order[1]
        local m = adventures.part(pick, "module") or {}
        kit.button(x + (w - bw) / 2, by - 58, bw, 44, "New game plays: " .. (m.title or pick) .. "   (change)", function()
            local i = 1
            for k, id in ipairs(order) do
                if id == pick then i = k end
            end
            app.adventure_pick = order[i % #order + 1]
            app.refresh()
        end, { font = "ui18b", key = "pick_adventure" })
    end
    if saved then
        local label = (saved.done and "Continue: your table's journey  >")
            or saved.at_night and ("Continue: Session " .. saved.week .. " night  >")
            or (saved.at_prep and ("Continue: Session " .. saved.week .. " prep  >"))
            or ("Continue: Session " .. (saved.week + 1) .. "  >")
        kit.button(x + (w - bw) / 2, by, bw, 56, label, function()
            app.continue_campaign()
        end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "continue" })
    else
        kit.button(x + (w - bw) / 2, by, bw, 56, "New game  >", function()
            app.new_campaign()
        end, { color = theme.go, hover = theme.go_hover, font = "ui22b", key = "session_zero" })
    end
    local hw = (any or saved) and (bw - 12) / 2 or bw
    kit.button(x + (w - bw) / 2, by + 68, hw, 44, any and "Load" or "Load (no saves yet)", function()
        require("game.ui.saves_view").open(app, "load")
    end, { font = "ui18b", key = "load_game", enabled = any })
    if saved or any then
        -- Two clicks: the first only asks, so a stray click can't start over.
        kit.button(x + (w - bw) / 2 + hw + 12, by + 68, hw, 44, app.confirm_new and "Yes, start over" or "New game", function()
            if app.confirm_new then
                app.confirm_new = nil
                app.new_campaign()
            else
                app.confirm_new = true
                app.refresh()
            end
        end, { font = "ui18b", key = "new_campaign", color = app.confirm_new and theme.red or nil })
    end
    local foot
    if app.resume_error then
        foot = "A saved game couldn't be opened (" .. app.resume_error .. "). Try another in Load, or start a new one."
    elseif any and app.confirm_new then
        foot = "Click again to start over. Your saves stay in Load; the autosave is replaced once the new Session Zero is done."
    elseif any then
        local sm = saved and saved.adventure and adventures.part(saved.adventure, "module")
        foot = "Continue picks up your newest save" .. (sm and sm.title and (", in " .. sm.title) or "")
            .. ". Load has the autosave and your own three slots."
    else
        -- (The developer keys aren't the player's business: October 20.)
        foot = "The game saves on its own as you play, and you can save to one of three slots from prep or the report."
    end
    kit.text(x + w / 2, y + h - 40, foot, "ui14", app.resume_error and theme.orange or theme.faint,
        { pivot = gui.PIVOT_N, w = w - 60 })
end

return M
