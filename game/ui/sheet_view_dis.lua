-- rules: dis   (Death in Space's own screen, reached through game/ui/sets.lua: docs/design/rule-sets.md)
-- A Death in Space character sheet: who the hero is and what they roll with, from the adventure's own crew
-- (its `heroes`, made by the book's steps, pp. 12-23): the four abilities, hit points, defense rating, the void points
-- they hold and any marks the void has left, their origin and its benefit, background, trait, drive, looks, past
-- allegiance, kit and trinket. Opened like 5e's sheet (game/ui/sheet_view.lua): from a player's panel, their card on
-- the prep board, or the notes. Game night waits while it's open.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"
local panels = require "game.ui.panels"

local M = {}

local X, Y, W, H = 130, 40, 1340, 824
local ABILITIES = { { "bdy", "BODY", "Strength, toughness, endurance" }, { "dex", "DEXTERITY", "Agility, reflexes, aim" },
                    { "svy", "SAVVY", "Awareness, knowing things, reading people" }, { "tec", "TECH", "Machines, computers, repairs" } }

local function hero(key, campaign)
    return require("game.model.ruleset").get("dis").hero_of(campaign, key) or {}
end

function M.open(app, key)
    app.overlay = "sheet"
    app.sheet_key = key or app.sheet_key or app.campaign.players[1].key
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

-- What a hero carries, for the party page: their kit and trinket ({ name, text, gear }).
function M.carrying(_c, s)
    local h = hero(s.key, _c)
    local out = {}
    for _, k in ipairs(h.kit or {}) do
        table.insert(out, { name = k, gear = k, text = "" })
    end
    if h.trinket then
        table.insert(out, { name = h.trinket, gear = h.trinket, text = "A trinket" })
    end
    return out
end

local function stat_box(x, y, w, label, value)
    kit.box(x, y, w, 64, theme.panel2, { radius = 8 })
    kit.text(x + w / 2, y + 8, label, "ui14", theme.dim, { pivot = gui.PIVOT_N })
    kit.text(x + w / 2, y + 26, value, "ui22b", theme.text, { pivot = gui.PIVOT_N })
end

local function row(x, y, w, label, text)
    kit.text(x, y, label, "ui14", theme.gold)
    kit.text(x + 150, y, text, "ui18", theme.text, { w = w - 150 })
    return y + math.max(24, kit.text_height(text, "ui18", w - 150) + 6)
end

function M.draw(app)
    if app.sheet_layer then
        kit.drop(app.sheet_layer)
    end
    local l = kit.layer("sheet", true)
    app.sheet_layer = l
    local c = app.campaign
    local p = c:player(app.sheet_key)
    local h = hero(p.key, c)
    local sh = h.sheet or {}
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.55), { round = false })
    kit.box(X, Y, W, H, theme.bg, { radius = 14 })
    -- Header: who's playing whom, and what they are.
    kit.box(X, Y, W, 112, theme.panel, { radius = 14 })
    kit.dot(X + 62, Y + 56, 92, panels.COLORS[p.key] or theme.panel3)
    kit.picture(X + 16, Y + 10, 92, 92, panels.face(p.key))
    kit.picture(X + 114, Y + 14, 68, 85, panels.mini(p, p.class))
    local tx = X + 196
    local room = (X + W - 600) - tx - 16
    local name = kit.ellipsize(p.char, "title30", math.floor(room * 0.6))
    kit.text(tx, Y + 10, name, "title30", theme.text, { gloss = false })
    kit.text(tx + kit.width(name, "title30") + 14, Y + 22, "played by " .. p.name, "ui18", theme.gold, { gloss = false })
    local what = (h.origin and h.origin.name or "") .. " " .. string.lower(h.class_name or p.class_name or "")
    kit.text(tx, Y + 52, kit.ellipsize(util.capitalize(what) .. ".  " .. (h.trait or "") .. ".", "ui18", room), "ui18", theme.dim)
    kit.text(tx, Y + 84, kit.ellipsize("Drive: " .. (h.drive or "") .. ".", "ui14", room), "ui14", theme.dim)
    local px = X + W - 600
    for _, q in ipairs(c.players) do
        local on = q.key == p.key
        kit.button(px, Y + 62, 92, 34, string.match(q.char, "^(%S+)") or q.char, function()
            app.sheet_key = q.key
            M.draw(app)
        end, { font = "ui14", color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "sheet_who_" .. q.key })
        px = px + 98
    end
    kit.button(X + W - 130, Y + 16, 110, 34, "Close", function()
        if app.close_overlay then
            app.close_overlay()
        else
            M.close(app)
        end
    end, { font = "ui18b", key = "sheet_close" })
    kit.gloss_scope({ sheet = true, fight = true }, function()
        -- Left: the numbers.
        local x, y = X + 30, Y + 136
        local void = (c.void or {})[p.key] or 0
        local st = require("game.model.ruleset").part("tile_stats").of(c, app.night, p.key)
        stat_box(x, y, 130, "HIT POINTS", util.int(st and st.hp or sh.hp or 0) .. " / " .. util.int(sh.hp or 0))
        stat_box(x + 140, y, 150, "DEFENSE RATING", util.int(sh.dr or 0))
        stat_box(x + 300, y, 136, "VOID POINTS", util.int(void) .. " / 4")
        local ay = y + 100
        kit.text(x, ay, "ABILITIES: A D20 PLUS ONE OF THESE, 12 OR MORE", "ui14", theme.gold)
        ay = ay + 24
        for i, a in ipairs(ABILITIES) do
            local col, rw = (i - 1) % 2, math.floor((i - 1) / 2)
            local bx, by = x + col * 220, ay + rw * 104
            local v = sh[a[1]] or 0
            kit.box(bx, by, 210, 94, theme.panel2, { radius = 8 })
            kit.text(bx + 105, by + 6, a[2], "ui14", theme.dim, { pivot = gui.PIVOT_N })
            kit.text(bx + 105, by + 24, (v >= 0 and "+" or "") .. util.int(v), "ui22b", theme.text, { pivot = gui.PIVOT_N })
            kit.text(bx + 105, by + 60, a[3], "ui14", theme.faint, { pivot = gui.PIVOT_N, w = 196 })
        end
        local my = ay + 222
        kit.text(x, my, "WHAT THE VOID HAS LEFT", "ui14", theme.gold)
        my = my + 22
        local marks = (c.void_marks or {})[p.key] or {}
        if #marks == 0 then
            kit.text(x, my, "Nothing yet. A void point spent on a roll that still misses can leave a mark.", "ui14", theme.faint, { w = 430 })
        end
        for _, m in ipairs(marks) do
            kit.text(x, my, util.capitalize(m) .. ".", "ui18", theme.text, { w = 430 })
            my = my + 24
        end
        -- Right: who they are.
        local rx, ry, rw = X + 520, Y + 136, W - 550
        if h.origin then
            ry = row(rx, ry, rw, "ORIGIN", h.origin.name .. ". " .. (h.origin.benefit or ""))
        end
        ry = row(rx, ry, rw, "BACKGROUND", h.background or "")
        ry = row(rx, ry, rw, "TRAIT", h.trait or "")
        ry = row(rx, ry, rw, "DRIVE", h.drive or "")
        ry = row(rx, ry, rw, "LOOKS", h.looks or "")
        ry = row(rx, ry, rw, "ALLEGIANCE", h.allegiance or "")
        local arms = {}
        for _, w in ipairs(h.weapons or {}) do
            table.insert(arms, w.name .. " (" .. (w.damage or "1d4") .. (w.ranged and ((w.uses and (", " .. util.int(w.uses) .. " shots")) or "") .. ", Tech to hit"
                or ", Body to hit") .. ")")
        end
        ry = row(rx, ry + 8, rw, "WEAPONS", #arms > 0 and table.concat(arms, "; ") or "Bare hands (1d2)")
        ry = row(rx, ry, rw, "KIT", table.concat(h.kit or {}, ", "))
        ry = row(rx, ry, rw, "TRINKET", h.trinket or "")
        ry = row(rx, ry + 8, rw, "WHO THEY ARE", h.intro or "")
        row(rx, ry, rw, "AT THE TABLE", h.short or "")
    end)
end

return M
