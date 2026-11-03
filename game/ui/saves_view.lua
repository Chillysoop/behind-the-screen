-- Saving and loading (November 3). The game autosaves as you play; three slots hold saves you
-- make yourself. On the title, Load picks one up; on the prep board and the report, Save writes
-- one. app.saves_ui = { mode = "load" | "save", confirm = slot id, said = text, bad = text } is
-- drawn over everything by game.gui_script's build_screen until Close (or Esc).

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"

local M = {}

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

function M.open(app, mode)
    app.scan_saves()
    app.saves_ui = { mode = mode }
    app.refresh()
end

function M.close(app)
    app.saves_ui = nil
    app.refresh()
end

-- Where a save picks up: "Session 2, prep".
function M.when_label(head)
    if head.done then
        return "The prologue is over: your table's journey"
    elseif head.at_night then
        return "Session " .. util.int(head.week) .. ", game night (from its start)"
    elseif head.at_prep then
        return "Session " .. util.int(head.week) .. ", prep"
    end
    return "Before session " .. util.int(head.week + 1)
end

-- When it was saved: "Nov 3, 12:40 pm". A save from before this version has no time.
function M.time_label(t)
    if not t then
        return nil
    end
    local ok, d = pcall(os.date, "*t", t)
    if not ok or type(d) ~= "table" then
        return nil
    end
    local h = d.hour % 12
    if h == 0 then
        h = 12
    end
    return MONTHS[d.month] .. " " .. d.day .. ", " .. h .. ":" .. string.format("%02d", d.min) .. (d.hour < 12 and " am" or " pm")
end

-- What saving right now keeps, said in the window.
local function what_it_keeps(app)
    if app.screen == "prep" then
        return "Saving here keeps this prep board just as it is."
    elseif app.screen == "report" then
        local rep = app.campaign and app.campaign.report
        local wk = rep and rep.week or (app.campaign and app.campaign.week) or 0
        return "Saving here picks up at the start of session " .. util.int(wk + 1) .. "."
    end
    return "Saving here keeps the campaign as it stands."
end

function M.draw(app)
    local ui = app.saves_ui
    if not ui then
        return
    end
    local list = app.save_list or app.scan_saves()
    kit.layer("saves", true)
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.6), { round = false })
    local w, rh = 680, 84
    local h = 150 + #list * (rh + 8) + 92
    local x, y = math.floor((kit.W - w) / 2), math.floor((kit.H - h) / 2)
    kit.box(x - 2, y - 2, w + 4, h + 4, theme.gold, { radius = 14 })
    kit.box(x, y, w, h, theme.bg, { radius = 13 })
    local load = ui.mode == "load"
    kit.text(x + 32, y + 22, load and "LOAD A SAVED GAME" or "SAVE YOUR GAME", "ui22b", theme.gold)
    local sub = load and "Pick up where you left off. Continue on the title always takes the newest one."
        or (what_it_keeps(app) .. " The autosave carries on by itself: after Session Zero, all through prep, and at the start and end of each game night.")
    kit.text(x + 32, y + 60, sub, "ui18", theme.dim, { w = w - 64 })
    local ry = y + 130
    for _, sv in ipairs(list) do
        local f = sv.found
        kit.box(x + 24, ry, w - 48, rh, theme.panel, { radius = 10 })
        kit.text(x + 44, ry + 12, sv.name, "ui18b", sv.id == "auto" and theme.teal or theme.text)
        local tx = x + 44 + 120
        local tw = w - 48 - 120 - 40 - 180
        if f and sv.broken then
            kit.text(tx, ry + 12, "This save couldn't be opened.", "ui18", theme.orange, { w = tw, lines = 1 })
            kit.text(tx, ry + 40, "It's left as it is; a new save here replaces it.", "ui14", theme.dim, { w = tw, lines = 2 })
        elseif f then
            kit.text(tx, ry + 12, M.when_label(f.head), "ui18", theme.text, { w = tw, lines = 1 })
            local bits = {}
            if f.head.where and f.head.where ~= "" then
                table.insert(bits, f.head.where)
            end
            local when = M.time_label(f.head.time)
            table.insert(bits, when and ("Saved " .. when) or "Saved before this version")
            kit.text(tx, ry + 40, table.concat(bits, "  "), "ui14", theme.dim, { w = tw, lines = 2 })
        elseif sv.id == "auto" then
            kit.text(tx, ry + 12, "Nothing yet.", "ui18", theme.dim, { w = tw, lines = 1 })
            kit.text(tx, ry + 40, "The game saves on its own once Session Zero is done.", "ui14", theme.dim, { w = tw, lines = 2 })
        else
            kit.text(tx, ry + 12, "Empty", "ui18", theme.dim, { w = tw, lines = 1 })
        end
        local bx, bw = x + w - 24 - 20 - 170, 170
        if load then
            kit.button(bx, ry + 20, bw, 44, "Load", function()
                app.load_save(f)
            end, { color = theme.go, hover = theme.go_hover, font = "ui18b", key = "load_" .. sv.id,
                   enabled = f ~= nil and not sv.broken })
        elseif sv.id == "auto" then
            kit.text(bx + bw / 2, ry + 32, "Saves on its own", "ui14", theme.faint, { pivot = gui.PIVOT_N, w = bw })
        else
            -- (Two clicks over an old save, so a stray one can't lose it.)
            local asking = ui.confirm == sv.id
            local label = (f and not asking and "Overwrite") or (asking and "Yes, overwrite") or "Save here"
            kit.button(bx, ry + 20, bw, 44, label, function()
                if f and not asking then
                    ui.confirm = sv.id
                    ui.said, ui.bad = nil, nil
                    app.refresh()
                    return
                end
                ui.confirm = nil
                local ok, err = app.save_to_slot(sv.id)
                if ok then
                    ui.said, ui.bad = "Saved to " .. sv.name .. ".", nil
                else
                    ui.said, ui.bad = nil, "Couldn't save: " .. tostring(err)
                end
                app.refresh()
            end, { color = asking and theme.red or theme.go, hover = asking and theme.red or theme.go_hover, font = "ui18b",
                   key = "save_" .. sv.id })
        end
        ry = ry + rh + 8
    end
    if ui.said or ui.bad then
        kit.text(x + 32, y + h - 74, ui.said or ui.bad, "ui18b", ui.bad and theme.orange or theme.green, { w = w - 250, lines = 2 })
    end
    kit.button(x + w - 32 - 180, y + h - 70, 180, 46, "Close", function()
        M.close(app)
    end, { font = "ui18b", key = "saves_close" })
end

return M
