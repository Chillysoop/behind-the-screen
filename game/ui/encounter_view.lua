-- The encounter builder (real-session pass): build a combat or set-piece scene's fight on
-- the prep board. Add monsters from the roster, see how hard the fight is (the SRD XP budget
-- and the M3 meter's forecast) and how it lines up against the party's real abilities
-- (game/model/matchup.lua). Game night runs exactly this fight; "Use the suggestion" goes
-- back to the one the scene's cast and location bring.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local content = require "game.model.content"
local util = require "game.model.util"
local matchup = require "game.model.matchup"
local monsters = require "game.rules.data.monsters"

local M = {}

local X, Y, W, H = 90, 40, 1420, 820
local SPRITE = { goblin_warrior = "goblin_club" }

local function pic(id)
    return "mini_" .. (SPRITE[id] or id)
end

function M.open(app, scene)
    app.overlay = "encounter"
    app.enc_scene = scene
    M.draw(app)
end

function M.close(app)
    if app.enc_layer then
        kit.drop(app.enc_layer)
        app.enc_layer = nil
    end
    if app.overlay == "encounter" then
        app.overlay = nil
    end
    kit.reset_hover()
end

local function ids_now(app)
    local enc = app.campaign.prep:encounter(app.enc_scene)
    local out = {}
    for i, id in ipairs(enc.ids) do
        out[i] = id
    end
    return out, enc
end

-- Change the fight, then redraw the board underneath (which redraws this on top).
local function set(app, ids)
    app.campaign.prep:set_encounter(app.enc_scene, ids)
    if app.refresh then
        app.refresh()
    else
        M.draw(app)
    end
end

local TONE = { danger = "orange", good = "green", info = "dim" }

function M.draw(app)
    if app.enc_layer then
        kit.drop(app.enc_layer)
    end
    local prep = app.campaign.prep
    local i = app.enc_scene
    local s = prep.scenes[i]
    local l = kit.layer("encounter", true)
    app.enc_layer = l
    local ids, enc = ids_now(app)
    local a = matchup.analyze(app.campaign, ids)
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.55), { round = false })
    kit.box(X, Y, W, H, theme.bg, { radius = 14 })
    kit.box(X, Y, W, 64, theme.panel, { radius = 14 })
    local where = s.slots.location and (" at " .. util.lower_first(s.slots.location.name)) or ", place to be improvised"
    kit.text(X + 24, Y + 14, "BUILD THE FIGHT", "title30", theme.gold)
    kit.text(X + 24 + kit.width("BUILD THE FIGHT", "title30") + 36, Y + 22,
        "Scene " .. util.int(i) .. ": " .. (s.type and content.scenes[s.type].name or "") .. where, "ui18", theme.dim)
    kit.button(X + W - 380, Y + 14, 230, 36, "Use the suggestion", function()
        set(app, nil)
    end, { font = "ui18b", enabled = enc.built, key = "enc_reset" })
    kit.button(X + W - 140, Y + 14, 120, 36, "Done", function()
        M.close(app)
        if app.refresh then
            app.refresh()
        end
    end, { font = "ui18b", color = theme.go, hover = theme.go_hover, key = "enc_done" })

    -- The roster.
    local rx, ry = X + 24, Y + 86
    kit.text(rx, ry, "MONSTERS  (SRD 5.2.1)", "ui14", theme.gold)
    kit.text(rx + 660, ry, "Click to add. Up to " .. util.int(matchup.MAX) .. ".", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    local tw, th = 158, 150
    for k, id in ipairs(matchup.ROSTER) do
        local m = monsters[id]
        local col, row = (k - 1) % 4, math.floor((k - 1) / 4)
        local bx, by = rx + col * (tw + 10), ry + 26 + row * (th + 10)
        kit.button(bx, by, tw, th, "", function()
            if #ids < matchup.MAX then
                table.insert(ids, id)
                set(app, ids)
            end
        end, { color = theme.panel2, hover = theme.button_hover, enabled = #ids < matchup.MAX, key = "enc_add_" .. id })
        kit.picture(bx + 6, by + 8, 56, 70, pic(id))
        kit.text(bx + 66, by + 10, m.name, "ui18b", theme.text, { w = tw - 72 })
        kit.text(bx + 66, by + 56, "CR " .. tostring(m.cr) .. ", " .. util.int(m.xp) .. " XP", "ui14", theme.gold)
        kit.text(bx + 8, by + 84, "AC " .. util.int(m.ac) .. "   HP " .. util.int(m.hp) .. "   Speed " .. util.int(m.speed), "ui14",
            theme.text)
        local best, bname = 0, ""
        for _, at in ipairs(m.attacks or {}) do
            local d = 0
            for _, p in ipairs(at.damage) do
                d = d + p[1] * (p[2] + 1) / 2 + (p[3] or 0)
            end
            if d > best then
                best, bname = d, at.name .. " +" .. util.int(at.to_hit)
            end
        end
        kit.text(bx + 8, by + 104, bname .. ", avg " .. util.int(math.floor(best + 0.5))
            .. (m.multiattack and (" x" .. util.int(m.multiattack.count)) or ""), "ui14", theme.dim, { w = tw - 14 })
    end

    -- The fight as built.
    local fx, fy = X + 720, Y + 86
    local fw = W - 720 - 24
    kit.text(fx, fy, enc.built and "YOUR FIGHT" or "THE SCENE'S SUGGESTION", "ui14", theme.gold)
    kit.text(fx + fw, fy, "The first one leads it.", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    local counts, order = {}, {}
    for _, id in ipairs(ids) do
        if not counts[id] then
            table.insert(order, id)
        end
        counts[id] = (counts[id] or 0) + 1
    end
    local ly = fy + 26
    if #order == 0 then
        kit.text(fx, ly, "No monsters yet. Add some from the roster.", "ui18", theme.faint)
        ly = ly + 30
    end
    for k, id in ipairs(order) do
        local m = monsters[id]
        kit.box(fx, ly, fw, 52, k == 1 and kit.rgba("#3a2a1c") or theme.panel2, { radius = 8 })
        kit.picture(fx + 6, ly + 3, 36, 45, pic(id))
        kit.text(fx + 50, ly + 6, (k == 1 and (enc.boss_name and util.capitalize(enc.boss_name) .. " (" .. m.name .. ")" or m.name)
            or m.name), "ui18b", theme.text, { w = fw - 300 })
        kit.text(fx + 50, ly + 28, matchup.blurb(id), "ui14", theme.dim)
        local cx = fx + fw - 210
        kit.button(cx, ly + 10, 32, 32, "-", function()
            for j = #ids, 1, -1 do
                if ids[j] == id then
                    table.remove(ids, j)
                    break
                end
            end
            set(app, ids)
        end, { font = "ui18b", key = "enc_less_" .. id })
        kit.text(cx + 52, ly + 16, "x" .. util.int(counts[id]), "ui18b", theme.text, { pivot = gui.PIVOT_N })
        kit.button(cx + 72, ly + 10, 32, 32, "+", function()
            if #ids < matchup.MAX then
                table.insert(ids, id)
                set(app, ids)
            end
        end, { font = "ui18b", enabled = #ids < matchup.MAX, key = "enc_more_" .. id })
        if k > 1 then
            kit.button(cx + 112, ly + 10, 88, 32, "Lead", function()
                for j = 1, #ids do
                    if ids[j] == id then
                        table.remove(ids, j)
                        table.insert(ids, 1, id)
                        break
                    end
                end
                set(app, ids)
            end, { font = "ui14", key = "enc_lead_" .. id })
        else
            kit.text(cx + 156, ly + 16, "Leads", "ui14", theme.gold, { pivot = gui.PIVOT_N })
        end
        ly = ly + 58
    end

    -- How hard: the SRD budget and the meter.
    ly = math.max(ly + 8, fy + 26 + 4 * 58 + 8)
    kit.text(fx, ly, "HOW HARD", "ui14", theme.gold)
    ly = ly + 24
    if a.meter then
        local b = a.budget
        local scale = math.max(b.high * 1.5, a.xp)
        local bw = fw
        kit.box(fx, ly, bw, 14, kit.rgba("#000000", 0.35), { radius = 6 })
        kit.box(fx, ly, math.max(2, bw * math.min(1, a.xp / scale)), 14,
            a.xp > b.high and theme.red or (a.xp > b.moderate and theme.orange or (a.xp > b.low and theme.gold or theme.teal)),
            { radius = 6 })
        for _, mark in ipairs({ { b.low, "Low" }, { b.moderate, "Moderate" }, { b.high, "High" } }) do
            local mx = fx + bw * mark[1] / scale
            kit.box(mx - 1, ly - 4, 2, 22, theme.text, { round = false })
            kit.text(mx, ly + 20, mark[2], "ui14", theme.dim, { pivot = gui.PIVOT_N })
        end
        ly = ly + 44
        kit.text(fx, ly, util.int(a.xp) .. " XP: " .. (a.meter.srd or "?") .. " for " .. util.int(a.n) .. " level "
            .. util.int(a.level) .. " heroes (SRD budget).", "ui18", theme.text, { w = fw })
        ly = ly + 26
        if a.meter.someone_drops then
            kit.text(fx, ly, "Forecast: " .. (a.meter.danger or "") .. ". Someone drops in "
                .. util.int(math.floor(a.meter.someone_drops * 100 + 0.5)) .. "% of fights like this; the party falls in "
                .. util.int(math.floor((a.meter.party_falls or 0) * 100 + 0.5)) .. "%.", "ui18", theme.text, { w = fw })
            ly = ly + kit.text_height("Forecast: Dangerous. Someone drops in 100% of fights like this; the party falls in 100%.",
                "ui18", fw) + 6
        end
        if a.meter.extrapolated then
            kit.text(fx, ly, "Bigger or smaller than anything simulated: the forecast is a guess.", "ui14", theme.orange)
            ly = ly + 22
        end
    end
    -- Against this party.
    ly = ly + 6
    kit.text(fx, ly, "AGAINST THIS PARTY", "ui14", theme.gold)
    ly = ly + 24
    for _, n in ipairs(a.notes) do
        local col = theme[TONE[n.tone] or "dim"] or theme.dim
        kit.dot(fx + 6, ly + 10, 8, col)
        kit.text(fx + 18, ly, n.text, "ui18", theme.text, { w = fw - 18 })
        ly = ly + kit.text_height(n.text, "ui18", fw - 18) + 6
        if ly > Y + H - 30 then
            break
        end
    end
end

return M
