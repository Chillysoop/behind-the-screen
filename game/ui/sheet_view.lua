-- Character sheets (real-session pass): open one from a player's panel on game night, their
-- card on the prep board, or the party page of your notes. Two pages: the sheet (abilities,
-- saves, skills, attacks, spells) and everything the character can do (features in full).
-- The numbers come from the rules engine (game/model/sheet.lua): they're the ones the
-- table rolls with. Game night waits while a sheet is open.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"
local sheet_mod = require "game.model.sheet"
local panels = require "game.ui.panels"

local M = {}

local X, Y, W, H = 130, 40, 1340, 824
local CLASS_MINI = { fighter = "mini_fighter", rogue = "mini_rogue", cleric = "mini_cleric", wizard = "mini_wizard" }

function M.open(app, key)
    app.overlay = "sheet"
    app.sheet_key = key or app.sheet_key or app.campaign.players[1].key
    app.sheet_page = app.sheet_page or "sheet"
    M.draw(app)
end

function M.close(app)
    if app.sheet_layer then
        kit.drop(app.sheet_layer)
        app.sheet_layer = nil
    end
    if app.overlay == "sheet" then
        app.overlay = nil
    end
    kit.reset_hover()
end

local function stat_box(x, y, w, label, value, note)
    kit.box(x, y, w, 64, theme.panel2, { radius = 8 })
    kit.text(x + w / 2, y + 8, label, "ui14", theme.dim, { pivot = gui.PIVOT_N })
    kit.text(x + w / 2, y + 26, value, "ui22b", theme.text, { pivot = gui.PIVOT_N })
    if note then
        kit.text(x + w / 2, y + 66, note, "ui14", theme.faint, { pivot = gui.PIVOT_N, w = w + 40 })
    end
end

local function page_sheet(app, s, x, y)
    -- Left: the core numbers, abilities and saves.
    local hp_now
    local battle = app.screen == "night" and app.hp and app.hp[s.key]
    if battle then
        hp_now = util.int(math.max(0, battle[1])) .. " / " .. util.int(s.hp_max)
    end
    stat_box(x, y, 106, "ARMOR CLASS", util.int(s.ac), s.ac_note and "with Mage Armor" or nil)
    stat_box(x + 114, y, 106, "HIT POINTS", hp_now or util.int(s.hp_max))
    stat_box(x + 228, y, 96, "SPEED", util.int(s.speed) .. " ft")
    stat_box(x + 332, y, 100, "INITIATIVE", s.initiative)
    local ay = y + 100
    kit.text(x, ay, "ABILITIES AND SAVING THROWS", "ui14", theme.gold)
    ay = ay + 24
    for i, a in ipairs(s.abilities) do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local bx, by = x + col * 146, ay + row * 104
        kit.box(bx, by, 136, 94, theme.panel2, { radius = 8 })
        kit.text(bx + 68, by + 6, a.name, "ui14", theme.dim, { pivot = gui.PIVOT_N })
        kit.text(bx + 68, by + 24, a.mod, "ui22b", theme.text, { pivot = gui.PIVOT_N })
        kit.text(bx + 68, by + 50, util.int(a.score), "ui14", theme.faint, { pivot = gui.PIVOT_N })
        kit.text(bx + 68, by + 70, "Save " .. a.save .. (a.save_prof and "  (proficient)" or ""), "ui14",
            a.save_prof and theme.teal or theme.dim, { pivot = gui.PIVOT_N })
    end
    local ly = ay + 222
    kit.text(x, ly, "PROFICIENCY BONUS  +" .. util.int(s.pb) .. "      PASSIVE PERCEPTION  " .. util.int(s.passive_perception),
        "ui14", theme.dim)
    ly = ly + 26
    kit.text(x, ly, "ATTACKS", "ui14", theme.gold)
    ly = ly + 22
    for _, a in ipairs(s.attacks) do
        kit.text(x, ly, a.name, "ui18b", theme.text)
        kit.text(x + 170, ly, a.to_hit .. " to hit", "ui18", theme.text)
        kit.text(x + 270, ly, a.damage, "ui18", theme.text)
        ly = ly + 22
        if a.notes ~= "" then
            kit.text(x + 12, ly, a.notes, "ui14", theme.dim)
            ly = ly + 20
        end
    end
    if s.spell_dc then
        ly = ly + 6
        kit.text(x, ly, "SPELLCASTING", "ui14", theme.gold)
        ly = ly + 22
        local slots = {}
        for l, n in ipairs(s.slots or {}) do
            table.insert(slots, "level " .. util.int(l) .. ": " .. util.int(n))
        end
        kit.text(x, ly, "Save DC " .. util.int(s.spell_dc) .. "    Attack " .. s.spell_attack .. "    Slots " .. table.concat(slots, ", "),
            "ui18", theme.text, { w = 440 })
        ly = ly + kit.text_height("x", "ui18", 440) + 6
    end
    -- Middle: skills.
    local mx = x + 470
    kit.text(mx, y, "SKILLS", "ui14", theme.gold)
    kit.text(mx + 300, y, "* proficient   ** expertise", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    local sy = y + 24
    for _, sk in ipairs(s.skills) do
        local col = sk.expert and theme.gold or (sk.prof and theme.teal or theme.dim)
        kit.text(mx, sy, sk.mod, "ui18b", col)
        kit.text(mx + 44, sy, sk.name .. (sk.expert and " **" or (sk.prof and " *" or "")), "ui18", sk.prof and theme.text or theme.dim)
        kit.text(mx + 300, sy + 2, sk.ability, "ui14", theme.faint, { pivot = gui.PIVOT_NE })
        sy = sy + 26
    end
    -- Right: spells and gear.
    local rx = x + 800
    local rw = W - 60 - 800
    local ry = y
    if s.spell_dc then
        kit.text(rx, ry, "CANTRIPS", "ui14", theme.gold)
        ry = ry + 22
        local t = table.concat(s.cantrips, ", ")
        kit.text(rx, ry, t, "ui18", theme.text, { w = rw })
        ry = ry + kit.text_height(t, "ui18", rw) + 10
        kit.text(rx, ry, "PREPARED SPELLS", "ui14", theme.gold)
        ry = ry + 22
        local p = table.concat(s.prepared, ", ")
        kit.text(rx, ry, p, "ui18", theme.text, { w = rw })
        ry = ry + kit.text_height(p, "ui18", rw) + 6
        if s.free_spell then
            kit.text(rx, ry, s.free_spell, "ui14", theme.dim, { w = rw })
            ry = ry + kit.text_height(s.free_spell, "ui14", rw) + 6
        end
        ry = ry + 10
    end
    kit.text(rx, ry, "GEAR", "ui14", theme.gold)
    ry = ry + 22
    local g = table.concat(s.gear, ", ")
    kit.text(rx, ry, g, "ui18", theme.text, { w = rw })
    ry = ry + kit.text_height(g, "ui18", rw) + 14
    kit.text(rx, ry, "BACKSTORY HOOK", "ui14", theme.gold)
    ry = ry + 22
    local hook = util.capitalize(s.thread or "")
    kit.text(rx, ry, hook, "ui18", theme.text, { w = rw })
    ry = ry + kit.text_height(hook, "ui18", rw) + 6
    -- How far the villain may go with it (Session Zero's backstory boundary): theirs to say, and
    -- yours to change after a check-in.
    local villains = require "game.model.villains"
    local b = villains.boundary(app.campaign, s.key)
    local vd = villains.data
    local bline = "Villains: " .. vd.BOUNDARY_NAME[b] .. ". " .. vd.BOUNDARY_ABOUT[b]
    kit.text(rx, ry, bline, "ui14", theme.dim, { w = rw - 110 })
    kit.button(rx + rw - 100, ry - 4, 100, 26, "Change", function()
        local order = vd.BOUNDARY_ORDER
        local at = 1
        for k, id in ipairs(order) do
            if id == b then
                at = k
            end
        end
        villains.set_boundary(app.campaign, s.key, order[at % #order + 1])
        M.draw(app)
    end, { font = "ui14", key = "sheet_boundary" })
    ry = ry + math.max(26, kit.text_height(bline, "ui14", rw - 110)) + 12
    kit.text(rx, ry, "AT THE TABLE", "ui14", theme.gold)
    ry = ry + 22
    kit.text(rx, ry, s.notes or "", "ui14", theme.dim, { w = rw })
end

local function page_features(app, s, x, y)
    local colw = (W - 60 - 40) / 2
    local cx, cy = x, y
    local function section(title)
        kit.text(cx, cy, title, "ui14", theme.gold)
        cy = cy + 22
    end
    local groups = {
        { "CLASS FEATURES", function(f) return not f.sub and not f.feat and not f.species end },
        { "SUBCLASS", function(f) return f.sub end },
        { "FEATS", function(f) return f.feat end },
        { "SPECIES", function(f) return f.species end },
    }
    for _, g in ipairs(groups) do
        local list = {}
        for _, f in ipairs(s.features) do
            if g[2](f) then
                table.insert(list, f)
            end
        end
        if #list > 0 then
            local need = 22
            for _, f in ipairs(list) do
                need = need + 22 + kit.text_height(f.text, "ui14", colw) + 8
            end
            if cy + math.min(need, 120) > Y + H - 30 and cx == x then
                cx, cy = x + colw + 40, y
            end
            section(g[1])
            for _, f in ipairs(list) do
                if cy + 40 > Y + H - 20 and cx == x then
                    cx, cy = x + colw + 40, y
                end
                kit.text(cx, cy, f.name .. (f.level and f.level > 1 and ("  (level " .. util.int(f.level) .. ")") or ""),
                    "ui18b", theme.text)
                cy = cy + 22
                kit.text(cx, cy, f.text, "ui14", theme.dim, { w = colw })
                cy = cy + kit.text_height(f.text, "ui14", colw) + 8
            end
            cy = cy + 6
        end
    end
end

function M.draw(app)
    if app.sheet_layer then
        kit.drop(app.sheet_layer)
    end
    local l = kit.layer("sheet", true)
    app.sheet_layer = l
    local s = sheet_mod.build(app.campaign, app.sheet_key)
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.55), { round = false })
    kit.box(X, Y, W, H, theme.bg, { radius = 14 })
    -- Header: who's playing whom.
    kit.box(X, Y, W, 112, theme.panel, { radius = 14 })
    kit.dot(X + 62, Y + 56, 92, panels.COLORS[s.key] or theme.panel3)
    kit.picture(X + 16, Y + 10, 92, 92, panels.face(s.key))
    kit.picture(X + 114, Y + 14, 68, 85, panels.mini(app.campaign:player(s.key), s.class))
    kit.text(X + 196, Y + 14, s.name, "title30", theme.text)
    local line = s.species .. " " .. s.class_name .. ", level " .. util.int(s.level)
        .. (s.subclass_name and (", " .. s.subclass_name) or "") .. ".  " .. s.background .. " background."
    kit.text(X + 196, Y + 56, line, "ui18", theme.dim)
    kit.text(X + 196, Y + 80, "Played by " .. s.player, "ui14", theme.gold)
    -- When this hero dies (B3): the table's rule, or theirs if you've agreed to honour it. Revisit
    -- it here any time.
    local death = require "game.model.death"
    local camp = app.campaign
    local mode, pref = death.mode_for(camp, s.key), death.pref(s.key)
    local dx = X + 196 + kit.width("Played by " .. s.player, "ui14") + 18
    local dline = "If " .. s.name .. " dies: " .. string.lower(death.data.MODE[mode].short) .. "."
    local wants = pref and pref ~= mode and (s.player .. " wants: " .. string.lower(death.data.MODE[pref].short) .. ".")
    local room = (X + W - 600) - dx - 20
    local honour = pref and pref ~= mode
    local undo = camp.death_overrides and camp.death_overrides[s.key]
    local bw = (honour or undo) and 120 or 0
    -- Two short lines: the rule, and what the player would rather (A8: nothing cut off).
    kit.text(dx, wants and Y + 72 or Y + 80, kit.ellipsize(dline, "ui14", room - bw - 8), "ui14", theme.dim)
    if wants then
        kit.text(dx, Y + 90, kit.ellipsize(wants, "ui14", room - bw - 8), "ui14", theme.gold)
    end
    if honour or undo then
        kit.button(dx + room - bw, Y + 74, bw, 28, honour and "Honour it" or "Table's rule", function()
            death.set_override(camp, s.key, honour and pref or nil)
            M.draw(app)
        end, { font = "ui14", key = "sheet_death" })
    end
    -- Pages and the other sheets.
    local bx = X + W - 600
    for _, pg in ipairs({ { "sheet", "Sheet" }, { "features", "Features" } }) do
        local on = (app.sheet_page or "sheet") == pg[1]
        kit.button(bx, Y + 16, 110, 34, pg[2], function()
            app.sheet_page = pg[1]
            M.draw(app)
        end, { font = "ui18b", color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "sheet_page_" .. pg[1] })
        bx = bx + 120
    end
    local px = X + W - 600
    for _, p in ipairs(app.campaign.players) do
        local on = p.key == s.key
        kit.button(px, Y + 62, 92, 34, p.char, function()
            app.sheet_key = p.key
            M.draw(app)
        end, { font = "ui14", color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "sheet_who_" .. p.key })
        px = px + 98
    end
    kit.button(X + W - 130, Y + 16, 110, 34, "Close", function()
        if app.close_overlay then
            app.close_overlay()
        else
            M.close(app)
        end
    end, { font = "ui18b", key = "sheet_close" })
    kit.text(X + W - 20, Y + 70, "Esc", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    -- Rules words on the sheet explain themselves on hover (the newcomer playtest, October 16).
    kit.gloss_scope({ sheet = true, fight = true }, function()
        if (app.sheet_page or "sheet") == "features" then
            page_features(app, s, X + 30, Y + 136)
        else
            page_sheet(app, s, X + 30, Y + 136)
        end
    end)
end

return M
