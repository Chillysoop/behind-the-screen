-- The campaign planner screen (the slice rework, S4): before Session Zero, the DM sketches
-- the campaign the way real DMs do (the 2024 DMG's campaign steps, Sly Flourish's truths,
-- Dungeon World's fronts). Three truths about the world, a second front beside Kessrick's,
-- and two featured threads. The plan decides what goes in the story deck
-- (game/model/planner.lua, game/data/planner.lua). Rebuilt on every click.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local content = require "game.model.content"
local util = require "game.model.util"
local planner = require "game.model.planner"
local panels = require "game.ui.panels"
local dice_sets = require "game.model.dice_sets"

local M = {}

local function choices(app)
    if not app.plan_choices then
        local d = planner.data.default
        local t = {}
        for i, id in ipairs(d.truths) do
            t[i] = id
        end
        local th = {}
        for i, k in ipairs(d.threads) do
            th[i] = k
        end
        app.plan_choices = { truths = t, front = d.front, threads = th, style = "frontier",
                             dice = dice_sets.get(app.campaign).dm or dice_sets.offer(app.campaign)[1] }
    end
    return app.plan_choices
end

local function toggle(list, id, max)
    for i, v in ipairs(list) do
        if v == id then
            table.remove(list, i)
            return true
        end
    end
    if #list >= max then
        return false
    end
    table.insert(list, id)
    return true
end

function M.ready(app)
    local c = choices(app)
    return #c.truths == planner.data.PICK_TRUTHS and c.front ~= nil and #c.threads == planner.data.PICK_THREADS
end

-- Lay the plan down and go on to Session Zero.
function M.start(app)
    if not M.ready(app) then
        return false
    end
    planner.apply(app.campaign, choices(app))
    dice_sets.pick_dm(app.campaign, choices(app).dice)
    if app.paint_dice then
        app.paint_dice()
    end
    app.plan_choices = nil
    app.go("session_zero")
    return true
end

function M.build(app)
    local c = choices(app)
    local data = planner.data
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    kit.text(24, 14, "THE CAMPAIGN PLANNER", "title30", theme.gold)
    kit.text(24, 58, "Before Session Zero, sketch the campaign: what everyone knows about the world, the trouble that's coming, "
        .. "and whose stories you'll feature. It decides what goes in your deck.", "ui18", theme.dim, { w = 1500 })
    -- The premise (fixed in the slice).
    kit.box(24, 96, 1552, 70, theme.panel, { radius = 10 })
    kit.text(40, 106, data.premise.name, "ui22b", theme.text)
    kit.text(40, 136, data.premise.text, "ui18", theme.dim, { w = 1500 })
    -- Three truths: the Vale's six, and two from the campaign's style.
    local truths = planner.truths_for(c.style or "frontier")
    local tx, ty = 24, 186
    kit.text(tx, ty, "THREE TRUTHS ABOUT THE WORLD  (" .. util.int(#c.truths) .. " OF " .. util.int(data.PICK_TRUTHS) .. ")", "ui14",
        theme.gold)
    local cols = 3
    local cw, ch = (912 - (cols - 1) * 10) / cols, 100
    for i, t in ipairs(truths) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local x, y = tx + col * (cw + 10), ty + 26 + row * (ch + 10)
        local on = util.contains(c.truths, t.id)
        kit.button(x, y, cw, ch, "", function()
            if not toggle(c.truths, t.id, data.PICK_TRUTHS) then
                app.toast = "Three truths. Take one out first."
            end
            app.refresh()
        end, { color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "truth_" .. t.id })
        if t.style then
            kit.dot(x + cw - 12, y + ch - 12, 10, theme.gold)
        end
        -- A long truth takes two lines and its note gives one up (A8: nothing cut off).
        local two = kit.text_height(t.name, "ui18b", cw - 24) > kit.text_height("A", "ui18b", cw - 24)
        kit.text(x + 12, y + 8, t.name, "ui18b", theme.text, { w = cw - 24, lines = two and 2 or 1 })
        kit.text(x + 12, two and y + 56 or y + 36, t.about, "ui14", on and theme.text or theme.dim,
            { w = cw - 28, lines = two and 2 or 3 })
    end
    do
        local k = #truths
        if k % cols ~= 0 then
            local col, row = k % cols, math.floor(k / cols)
            local x, y = tx + col * (cw + 10), ty + 26 + row * (ch + 10)
            kit.dot(x + 14, y + 16, 10, theme.gold)
            kit.text(x + 28, y + 6, "Two truths come from the campaign's style. Change the style and they change too.",
                "ui14", theme.faint, { w = cw - 36 })
        end
    end
    -- The campaign's style (A18): where most nights happen. The Silent Bells still pulls the
    -- party back to Millbrook; the rest of the deck leans to the style.
    local styles = content.styles
    local fx, fw = 960, 616
    local sy = 186
    kit.text(fx, sy, "CAMPAIGN STYLE", "ui14", theme.gold)
    kit.text(fx + 136, sy, "Where most nights happen. The bells still call them home.", "ui14", theme.faint)
    sy = sy + 26
    local sw = (fw - 20) / 3
    for k, sid in ipairs(styles.order) do
        local st = styles.styles[sid]
        local on = (c.style or "frontier") == sid
        local col, row = (k - 1) % 3, math.floor((k - 1) / 3)
        kit.button(fx + col * (sw + 10), sy + row * 42, sw, 36, st.name, function()
            c.style = sid
            -- Truths and fronts from the old style don't come along.
            for i = #c.truths, 1, -1 do
                local def = planner.truth_def(c.truths[i])
                if def and def.style and def.style ~= sid then
                    table.remove(c.truths, i)
                end
            end
            if not util.contains(planner.fronts_for(sid), c.front) then
                c.front = data.default.front
            end
            app.refresh()
        end, { font = "ui18", color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "style_" .. sid })
    end
    sy = sy + 2 * 42 + 2
    local sd = styles.styles[c.style or "frontier"]
    kit.text(fx, sy, sd.pitch, "ui14", theme.text, { w = fw })
    sy = sy + kit.text_height(sd.pitch, "ui14", fw) + 2
    local sm = require "game.model.styles"
    local keen, unsure = {}, {}
    for _, p in ipairs(app.campaign.players) do
        local f = sm.fit(p, c.style or "frontier")
        if f >= 1 then
            table.insert(keen, p.name)
        elseif f < 0 then
            table.insert(unsure, p.name)
        end
    end
    local who = (#keen > 0 and ("Keen: " .. util.join_names(keen) .. ". ") or "")
        .. (#unsure > 0 and ("Not sold: " .. util.join_names(unsure) .. ".") or "")
    if who ~= "" then
        kit.text(fx, sy, who, "ui14", #unsure > 0 and theme.orange or theme.teal, { w = fw })
        sy = sy + 22
    end
    -- A second front: the picked one shows its portents, the others stay short.
    local fy = sy + 10
    kit.text(fx, fy, "A SECOND FRONT", "ui14", theme.gold)
    kit.text(fx + 130, fy, "Kessrick's warband is the main one.", "ui14", theme.faint)
    local y = fy + 26
    for _, id in ipairs(planner.fronts_for(c.style or "frontier")) do
        local f = data.fronts[id]
        local on = c.front == id
        local lines = {}
        if on then
            for k, p in ipairs(f.portents) do
                table.insert(lines, util.int(k) .. ". " .. p.text)
            end
        end
        local body = table.concat(lines, "\n")
        local h = 44 + kit.text_height(f.about, "ui14", fw - 28) + (on and (kit.text_height(body, "ui14", fw - 28) + 4) or 0)
            + kit.text_height("Doom: " .. f.doom, "ui14", fw - 28) + 8
        kit.button(fx, y, fw, h, "", function()
            c.front = id
            app.refresh()
        end, { color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "front_" .. id })
        kit.text(fx + 14, y + 8, f.name, "ui18b", theme.text, { w = fw - 160 })
        if f.style then
            kit.text(fx + fw - 12, y + 10, styles.styles[f.style].name, "ui14", theme.gold, { pivot = gui.PIVOT_NE })
        end
        local by = y + 34
        kit.text(fx + 14, by, f.about, "ui14", theme.dim, { w = fw - 28 })
        by = by + kit.text_height(f.about, "ui14", fw - 28) + 2
        if on then
            kit.text(fx + 14, by, body, "ui14", theme.text, { w = fw - 28 })
            by = by + kit.text_height(body, "ui14", fw - 28) + 4
        end
        kit.text(fx + 14, by, "Doom: " .. f.doom, "ui14", theme.orange, { w = fw - 28 })
        y = y + h + 8
    end
    -- Two featured threads.
    local hy = 546
    kit.text(24, hy, "TWO FEATURED THREADS  (" .. util.int(#c.threads) .. " OF " .. util.int(data.PICK_THREADS) .. ")", "ui14",
        theme.gold)
    kit.text(330, hy, "Their story cards come sooner.", "ui14", theme.faint)
    local pw = 222
    for i, p in ipairs(app.campaign.players) do
        local x = 24 + (i - 1) * (pw + 12)
        local yy = hy + 26
        local on = util.contains(c.threads, p.key)
        kit.button(x, yy, pw, 100, "", function()
            if not toggle(c.threads, p.key, data.PICK_THREADS) then
                app.toast = "Two featured threads. Take one out first."
            end
            app.refresh()
        end, { color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "thread_" .. p.key })
        kit.dot(x + 34, yy + 34, 46, panels.COLORS[p.key] or theme.panel3)
        kit.picture(x + 14, yy + 14, 40, 40, panels.face(p.key))
        kit.text(x + 66, yy + 12, p.char, "ui18b", theme.text, { w = pw - 76 })
        kit.text(x + 66, yy + 34, p.name, "ui14", theme.dim)
        kit.text(x + 14, yy + 62, util.capitalize(p.thread or ""), "ui14", on and theme.text or theme.dim, { w = pw - 28 })
    end
    -- Your dice (the DM's own set): one of three. The players start on plain grey.
    local dy = 692
    kit.text(24, dy, "YOUR DICE", "ui14", theme.gold)
    kit.text(120, dy, "The set you'll roll behind the screen. The players start on plain grey; better dice come later.",
        "ui14", theme.faint)
    local offer = dice_sets.offer(app.campaign)
    local cw = 300
    for i, id in ipairs(offer) do
        local set = dice_sets.data.SETS[id]
        local x = 24 + (i - 1) * (cw + 12)
        local yy = dy + 26
        local on = c.dice == id
        kit.button(x, yy, cw, 100, "", function()
            c.dice = id
            app.refresh()
        end, { color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "dice_" .. i })
        kit.picture(x + 12, yy + 14, 72, 72, "dice_" .. id)
        kit.text(x + 96, yy + 14, set.name, "ui18b", theme.text, { w = cw - 106 })
        kit.text(x + 96, yy + 40, set.about, "ui14", on and theme.text or theme.dim, { w = cw - 106, lines = 3 })
    end
    -- Off to Session Zero.
    local ready = M.ready(app)
    kit.button(1316, 820, 260, 56, "To Session Zero  >", function()
        M.start(app)
    end, { enabled = ready, color = theme.go, hover = theme.go_hover, font = "ui22b", key = "plan_done" })
    kit.text(1300, 838, ready and "or press Enter" or "Pick three truths, a front and two threads.", "ui14", theme.dim,
        { pivot = gui.PIVOT_NE })
    if app.toast then
        kit.text(800, 860, app.toast, "ui18", theme.orange, { pivot = gui.PIVOT_N })
        app.toast = nil
    end
end

return M
