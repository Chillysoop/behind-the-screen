-- A person's sheet (the playtest, November 3: "NPCs should be clickable, Flitwidget, Euryale, and
-- bring up a character sheet"): click their name in any line. Who they are, where, how they stand
-- with the party now, their numbers when it comes to a fight, and what the DM has put in their
-- pockets, with how the party can get it (beat them, pick their pocket, ask). Only the DM sees
-- this. app.npc_sheet = their id; game.gui_script draws it over the screen, and game night waits.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"
local npcs = require "game.model.npcs"

local M = {}

M.W, M.H = 780, 600

function M.open(app, id)
    if not npcs.get(id) then
        return
    end
    app.npc_sheet = id
    app.npc_pick = app.npc_pick or 1
    app.refresh()
end

function M.close(app)
    app.npc_sheet = nil
    kit.reset_hover()
    app.refresh()
end

local TONE = { good = "green", bad = "orange", quiet = "dim" }

function M.draw(app)
    local id = app.npc_sheet
    local n = id and npcs.get(id)
    if not n then
        app.npc_sheet = nil
        return
    end
    local gloss = require "game.ui.gloss"
    local c = app.campaign
    local MODULE = require("game.model.adventure").data
    kit.layer("npc_sheet", true)
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.55), { round = false })
    local w, h = M.W, M.H
    local x, y = (kit.W - w) / 2, (kit.H - h) / 2
    kit.box(x - 2, y - 2, w + 4, h + 4, theme.gold, { radius = 14 })
    kit.box(x, y, w, h, theme.bg, { radius = 13 })
    kit.text(x + 28, y + 20, n.name, "ui22b", theme.gold, { lines = 1, w = w - 120, gloss = false })
    kit.text(x + 28, y + 52, util.capitalize(n.role or ""), "ui18", theme.dim, { lines = 1, w = w - 120, gloss = false })
    kit.button(x + w - 56, y + 16, 40, 36, "X", function()
        M.close(app)
    end, { key = "npc_close", font = "ui18b" })
    -- Their mini, and who they are.
    local px, py = x + 28, y + 92
    kit.box(px, py, 150, 186, theme.panel, { radius = 10 })
    if n.sprite then
        kit.picture(px + 11, py + 8, 128, 160, "mini_" .. n.sprite)
    end
    local tx, tw = x + 200, w - 228
    local ty = py
    if n.about then
        kit.text(tx, ty, n.about, "ui18", theme.text, { w = tw, gloss = false })
        ty = ty + kit.text_height(n.about, "ui18", tw) + 12
    end
    local room = n.room and MODULE.rooms[n.room]
    if room then
        kit.text(tx, ty, "Where: " .. room.name, "ui18", theme.dim, { w = tw, lines = 1, gloss = false })
        ty = ty + 28
    end
    local s = npcs.state(c, n)
    if s then
        local txt = "Now: " .. s.text
        kit.text(tx, ty, txt, "ui18", theme[TONE[s.tone] or "dim"] or theme.dim, { w = tw, gloss = false })
        ty = ty + kit.text_height(txt, "ui18", tw) + 8
    end
    local st = npcs.stats(n)
    if st then
        local line = "In a fight: " .. util.int(st.hp or 0) .. " Hit Points, Armor Class " .. util.int(st.ac or 0)
            .. (st.cr and (", Challenge " .. tostring(st.cr)) or "") .. "."
        kit.text(tx, ty, line, "ui18", theme.text, { w = tw })
        ty = ty + kit.text_height(line, "ui18", tw) + 8
    end
    -- What's in their pockets: the DM's, and how the party gets it.
    local ly = math.max(py + 200, ty + 10)
    kit.text(x + 28, ly, "IN THEIR POCKETS", "ui14", theme.gold)
    kit.text(x + 168, ly, "Only you know. The party finds out the way you pick.", "ui14", theme.faint, { w = w - 196, lines = 1 })
    ly = ly + 26
    local items_mod = require "game.model.items"
    local list = npcs.drops(c, id)
    if #list == 0 then
        kit.text(x + 28, ly, "Nothing yet. Put something on them below.", "ui18", theme.faint, { gloss = false })
        ly = ly + 32
    end
    for i, d in ipairs(list) do
        if i > 4 then
            break
        end
        local def = items_mod.def(d.item)
        local name = def and def.name or d.item
        kit.box(x + 28, ly, w - 56, 40, theme.panel, { radius = 8 })
        local nt = kit.text(x + 42, ly + 9, name, "ui18b", d.got and theme.dim or theme.text, { w = 250, lines = 1, gloss = false })
        if def and def.text then
            gloss.card_spot(x + 42, ly + 4, 250, 32, def.name, def.text .. (def.rarity and (" (" .. def.rarity .. ")") or ""), nil, nt)
        end
        if d.got then
            local who = d.holder and c:player(d.holder)
            kit.text(x + 310, ly + 10, "The party has it" .. (who and (": " .. who.char) or "") .. ".", "ui18", theme.green, { w = 400, lines = 1 })
        else
            local how = npcs.HOWS[d.how]
            kit.button(x + 300, ly + 4, 300, 32, how.label, function()
                npcs.cycle_how(c, id, i)
                app.refresh()
            end, { key = "npc_how_" .. i, font = "ui14", enabled = #n.hows > 1,
                   on_hover = function(_, on)
                       if on then
                           gloss.show(how.label, how.tip .. (#n.hows > 1 and " Click to change how." or ""), nil, x + 300, ly + 4, 300, 32)
                       else
                           gloss.hide()
                       end
                   end })
            kit.button(x + w - 140, ly + 4, 100, 32, "Take it", function()
                npcs.remove_drop(c, id, i)
                app.refresh()
            end, { key = "npc_drop_x_" .. i, font = "ui14" })
        end
        ly = ly + 46
    end
    -- Put something on them.
    local choices = npcs.item_choices()
    local k = util.clamp(app.npc_pick or 1, 1, math.max(1, #choices))
    app.npc_pick = k
    local by = y + h - 120
    kit.text(x + 28, by, "PUT SOMETHING ON THEM", "ui14", theme.gold)
    by = by + 24
    kit.button(x + 28, by, 40, 40, "<", function()
        app.npc_pick = (k - 2) % #choices + 1
        app.refresh()
    end, { key = "npc_prev" })
    local def = items_mod.def(choices[k])
    kit.box(x + 74, by, 340, 40, theme.panel2, { radius = 8 })
    local cn = kit.text(x + 88, by + 10, def and (def.name .. " (" .. (def.rarity or "") .. ")") or "", "ui18", theme.text,
        { w = 316, lines = 1, gloss = false })
    if def and def.text then
        gloss.card_spot(x + 74, by, 340, 40, def.name, def.text, nil, cn)
    end
    kit.button(x + 420, by, 40, 40, ">", function()
        app.npc_pick = k % #choices + 1
        app.refresh()
    end, { key = "npc_next" })
    kit.button(x + 470, by, 170, 40, "Put it on them", function()
        npcs.add_drop(c, id, choices[k])
        app.refresh()
    end, { key = "npc_add", color = theme.go, hover = theme.go_hover, enabled = #list < 4 })
    kit.button(x + w - 128, by, 100, 40, "Close", function()
        M.close(app)
    end, { key = "npc_done" })
end

return M
