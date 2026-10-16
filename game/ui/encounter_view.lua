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
local map_view = require "game.ui.map_view"

local M = {}

local X, Y, W, H = 90, 40, 1420, 820
local SPRITE = { goblin_warrior = "goblin_club" }

local function pic(id)
    return "mini_" .. (SPRITE[id] or id)
end

function M.open(app, scene)
    app.overlay = "encounter"
    app.enc_scene = scene
    app.enc_msg = nil
    M.draw(app)
end

function M.close(app)
    if app.enc_layer then
        kit.drop(app.enc_layer)
        app.enc_layer = nil
    end
    if app.overlay == "encounter" then
        app.overlay = nil
        -- Back to the drawer's resting state: inspiration and seeds (A6).
        app.sel = nil
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
    app.enc_msg = nil
    app.campaign.prep:set_encounter(app.enc_scene, ids)
    if app.refresh then
        app.refresh()
    else
        M.draw(app)
    end
end

local TONE = { danger = "orange", good = "green", info = "dim" }

-- The hazards the scene's board has a place for, and where each would start: { id = "hearth" }.
function M.board_hazards(campaign, s)
    local maps = require "game.model.maps"
    local set = maps.template(campaign, s.slots and s.slots.location, s.type)
    local layout = set and content.terrain_layout.sets[set]
    local out = {}
    if not layout then
        return out
    end
    local src = layout.sources or {}
    for hid, what in pairs({ spreading_fire = "fire", rising_water = "water", slippery_ice = "ice" }) do
        if src[what] and src[what][1] then
            out[hid] = src[what][1].name
        end
    end
    if layout.planks and next(layout.planks) then
        out.crumbling_bridge = "bridge"
    end
    return out
end

function M.draw(app)
    -- Every rules word in here explains itself on hover (the newcomer playtest, October 16).
    kit.gloss_scope({ fight = true }, function()
        M.draw_all(app)
    end)
end

function M.draw_all(app)
    if app.enc_layer then
        kit.drop(app.enc_layer)
    end
    local prep = app.campaign.prep
    local i = app.enc_scene
    local s = prep.scenes[i]
    local l = kit.layer("encounter", true)
    app.enc_layer = l
    local ids, enc = ids_now(app)
    local hazard = app.campaign.prep:hazard(i)
    local a = matchup.analyze(app.campaign, ids, hazard)
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.55), { round = false })
    kit.box(X, Y, W, H, theme.bg, { radius = 14 })
    kit.box(X, Y, W, 64, theme.panel, { radius = 14 })
    local where = s.slots.location and (" at " .. util.lower_first(s.slots.location.name)) or ", place to be improvised"
    kit.text(X + 24, Y + 14, "BUILD THE FIGHT", "title30", theme.gold)
    kit.text(X + 24 + kit.width("BUILD THE FIGHT", "title30") + 36, Y + 22,
        "Scene " .. util.int(i) .. ": " .. (s.type and content.scenes[s.type].name or "") .. where, "ui18", theme.dim)
    local undo = app.enc_undo and app.enc_undo.scene == i and not enc.built and app.enc_undo.ids
    if undo then
        -- "Use the suggestion" can be undone (A7).
        kit.button(X + W - 380, Y + 14, 230, 36, "Undo: back to yours", function()
            app.enc_undo = nil
            set(app, undo)
        end, { font = "ui18b", key = "enc_undo" })
    else
        kit.button(X + W - 380, Y + 14, 230, 36, "Use the suggestion", function()
            app.enc_undo = { scene = i, ids = ids }
            set(app, nil)
        end, { font = "ui18b", enabled = enc.built, key = "enc_reset" })
    end
    kit.button(X + W - 140, Y + 14, 120, 36, "Done", function()
        M.close(app)
        if app.refresh then
            app.refresh()
        end
    end, { font = "ui18b", color = theme.go, hover = theme.go_hover, key = "enc_done" })
    -- The fight, or its map (B9).
    local tab = app.enc_tab or "fight"
    for k, t in ipairs({ { "fight", "The fight" }, { "map", "The map" } }) do
        kit.button(X + W - 660 + (k - 1) * 128, Y + 14, 120, 36, t[2], function()
            app.enc_tab = t[1]
            M.draw(app)
        end, { font = "ui18b", color = tab == t[1] and theme.go or theme.panel2, hover = theme.button_hover, key = "enc_tab_" .. t[1] })
    end
    if tab == "map" then
        map_view.draw(app, X + 24, Y + 86, 760, H - 110, ids, hazard)
        map_view.side(app, X + 816, Y + 86, W - 816 - 24, ids, hazard)
        return
    end

    -- The roster.
    local rx, ry = X + 24, Y + 86
    kit.text(rx, ry, "MONSTERS  (SRD 5.2.1)", "ui14", theme.gold)
    kit.text(rx + 660, ry, "Click to add. Up to " .. util.int(matchup.MAX) .. ".", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    -- The slice's monsters, then any pulled in from a book (A13), weakest first.
    local roster = {}
    for _, id in ipairs(matchup.ROSTER) do
        table.insert(roster, id)
    end
    local extra = {}
    for _, id in ipairs(require("game.model.books").roster(app.campaign)) do
        if not util.contains(roster, id) then
            table.insert(extra, id)
        end
    end
    table.sort(extra, function(a, b)
        if monsters[a].xp ~= monsters[b].xp then
            return monsters[a].xp < monsters[b].xp
        end
        return a < b
    end)
    for _, id in ipairs(extra) do
        table.insert(roster, id)
    end
    local compact = #roster > 12
    local cols = compact and 5 or 4
    local tw, th = compact and 124 or 158, compact and 104 or 150
    for k, id in ipairs(roster) do
        local m = monsters[id]
        local col, row = (k - 1) % cols, math.floor((k - 1) / cols)
        local bx, by = rx + col * (tw + 9), ry + 26 + row * (th + (compact and 7 or 10))
        local from_book = k > #matchup.ROSTER
        kit.button(bx, by, tw, th, "", function()
            if #ids < matchup.MAX then
                table.insert(ids, id)
                set(app, ids)
            end
        end, { color = from_book and kit.rgba("#2b3a3c") or theme.panel2, hover = theme.button_hover, enabled = #ids < matchup.MAX,
               key = "enc_add_" .. id })
        if compact then
            kit.picture(bx + 4, by + 6, 40, 50, pic(id))
            kit.text(bx + 48, by + 6, m.name, "ui14", theme.text, { w = tw - 52, lines = 2 })
            kit.text(bx + 48, by + 44, "CR " .. tostring(m.cr), "ui14", theme.gold)
            kit.text(bx + 6, by + 62, "AC " .. util.int(m.ac) .. "  HP " .. util.int(m.hp), "ui14", theme.text)
            kit.text(bx + 6, by + 82, util.int(m.xp) .. " XP" .. (from_book and "  (book)" or ""), "ui14", theme.dim)
        else
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
            -- The last one can't go (a fight needs someone to fight): say so, rather than nothing
            -- happening (the newcomer playtest, October 16).
            if #ids <= 1 then
                app.enc_msg = "A fight needs at least one monster. Add a different one from the left first, then take this one off."
                M.draw(app)
                return
            end
            app.enc_msg = nil
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

    if app.enc_msg then
        kit.text(fx, ly + 2, app.enc_msg, "ui14", theme.orange, { w = fw })
        ly = ly + kit.text_height(app.enc_msg, "ui14", fw) + 6
    end
    -- A hazard on the mat (A10): from the SRD's traps and environment. The ones this board's own
    -- scenery brings (a hearth to catch, a stream to flood, a bridge to give way) are marked.
    ly = math.max(ly + 4, fy + 26 + 4 * 58 + 4)
    local hz = require "game.rules.data.hazards"
    local here = M.board_hazards(app.campaign, s)
    kit.text(fx, ly, "HAZARD", "ui14", theme.gold)
    local hdef = hazard and hz.hazards[hazard]
    local START = { spreading_fire = " It catches by the %s.", rising_water = " It comes up out of the %s.",
                    slippery_ice = " It forms where the %s is." }
    local habout = hdef and (hdef.about .. (here[hazard] and START[hazard] and string.format(START[hazard], here[hazard]) or "")
        .. " (" .. hdef.src .. ")")
    kit.text(fx + 70, ly, habout or "None. Add one to make the place part of the fight.",
        "ui14", hdef and theme.text or theme.faint, { w = fw - 70, lines = 2 })
    ly = ly + 40
    local prep = app.campaign.prep
    local hbw = (fw - 12) / 3
    for k, hid in ipairs(hz.hazard_order) do
        local d = hz.hazards[hid]
        local on = hazard == hid
        local col, row = (k - 1) % 3, math.floor((k - 1) / 3)
        local bx, by = fx + col * (hbw + 6), ly + row * 34
        -- what this place has for it: "Spreading fire: hearth"
        local label = d.name
        if here[hid] and hid ~= "crumbling_bridge" and kit.width(d.name .. ": " .. here[hid], "ui14") < hbw - 24 then
            label = d.name .. ": " .. here[hid]
        end
        kit.button(bx, by, hbw, 28, label, function()
            prep:set_hazard(i, on and false or hid)
            M.draw(app)
        end, { font = "ui14", color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "enc_hazard_" .. hid })
        if here[hid] then
            kit.box(bx + hbw - 12, by + 4, 8, 8, theme.gold, { radius = 4 })     -- this place has one
        end
    end
    ly = ly + 2 * 34 + 8

    -- How hard: the SRD budget and the meter.
    kit.text(fx, ly, "HOW HARD", "ui14", theme.gold)
    if a.meter then
        -- The word names the band the XP reaches, on the same scale as the bar (A7).
        local b = a.budget
        local word, wcol
        if a.xp >= b.high then
            word, wcol = "High", theme.red
        elseif a.xp >= b.moderate then
            word, wcol = "Moderate", theme.orange
        elseif a.xp >= b.low then
            word, wcol = "Low", theme.gold
        else
            word, wcol = "Under Low", theme.teal
        end
        kit.text(fx + 90, ly - 4, word, "ui22b", wcol)
    end
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
        local xpline = util.int(a.xp) .. " XP" .. (hazard and " (with the hazard)" or "") .. " against a budget of "
            .. util.int(b.low) .. " / " .. util.int(b.moderate) .. " / " .. util.int(b.high) .. " (Low / Moderate / High) for "
            .. util.int(a.n) .. " level " .. util.int(a.level) .. " heroes, SRD 5.2.1."
        kit.text(fx, ly, xpline, "ui18", theme.text, { w = fw })
        ly = ly + kit.text_height(xpline, "ui18", fw) + 4
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
