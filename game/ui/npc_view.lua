-- A person's sheet (the playtest, November 3: "NPCs should be clickable, Flitwidget, Euryale, and
-- bring up a character sheet"): click their name in any line. Who they are, where, how they stand
-- with the party now, their numbers when it comes to a fight, and what the DM has put in their
-- pockets, with how the party can get it (beat them, pick their pocket, ask). Only the DM sees
-- this. app.npc_sheet = their id; game.gui_script draws it over the screen, and game night waits.
--
-- And what they know (Conner, November 5: "click into an NPC and see what secrets they have, and give the
-- DM more flexibility on when and how to reveal"): each secret they keep, whether the table has it, the
-- ways it could come out, and your say in when: Reveal now, Drop a hint, Hold it back tonight. You can give
-- them a secret to keep, too (game/model/secrets.lua).

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"
local npcs = require "game.model.npcs"

local M = {}

M.W, M.H = 1080, 820

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
    local tx, tw = x + 200, 330          -- (the left column: what they know takes the right)
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
    local cw = 500                     -- (the left column; what they know is on the right)
    local ly = math.max(py + 200, ty + 10)
    kit.text(x + 28, ly, "IN THEIR POCKETS", "ui14", theme.gold)
    kit.text(x + 168, ly, "Only you know.", "ui14", theme.faint, { w = cw - 150, lines = 1 })
    ly = ly + 26
    local items_mod = require "game.model.items"
    local list = npcs.drops(c, id)
    if #list == 0 then
        kit.text(x + 28, ly, "Nothing yet. Put something on them below.", "ui18", theme.faint, { gloss = false, w = cw, lines = 1 })
        ly = ly + 32
    end
    for i, d in ipairs(list) do
        if i > 4 then
            break
        end
        local def = items_mod.def(d.item)
        local name = def and def.name or d.item
        kit.box(x + 28, ly, cw, 40, theme.panel, { radius = 8 })
        local nt = kit.text(x + 42, ly + 9, name, "ui18b", d.got and theme.dim or theme.text, { w = 170, lines = 1, gloss = false })
        if def and def.text then
            gloss.card_spot(x + 42, ly + 4, 170, 32, def.name, def.text .. (def.rarity and (" (" .. def.rarity .. ")") or ""), nil, nt)
        end
        if d.got then
            local e = d.entry
            local hk = (e and not e.gone and not e.destroyed and e.holder) or (not e and d.holder) or nil
            local who = hk and c:player(hk)
            kit.text(x + 220, ly + 10, "The party has it" .. (who and (": " .. who.char) or "") .. ".", "ui18", theme.green, { w = cw - 200, lines = 1 })
        else
            local how = npcs.HOWS[d.how]
            kit.button(x + 216, ly + 4, 210, 32, how.label, function()
                npcs.cycle_how(c, id, i)
                app.refresh()
            end, { key = "npc_how_" .. i, font = "ui14", enabled = #n.hows > 1,
                   on_hover = function(_, on)
                       if on then
                           gloss.show(how.label, how.tip .. (#n.hows > 1 and " Click to change how." or ""), nil, x + 216, ly + 4, 210, 32)
                       else
                           gloss.hide()
                       end
                   end })
            kit.button(x + 28 + cw - 84, ly + 4, 76, 32, "Take it", function()
                npcs.remove_drop(c, id, i)
                app.refresh()
            end, { key = "npc_drop_x_" .. i, font = "ui14" })
        end
        ly = ly + 46
    end
    M.draw_secrets(app, n, x + 560, y + 92, w - 588, h - 92 - 210)
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
    kit.box(x + 74, by, 250, 40, theme.panel2, { radius = 8 })
    local cn = kit.text(x + 88, by + 10, def and (def.name .. " (" .. (def.rarity or "") .. ")") or "", "ui18", theme.text,
        { w = 226, lines = 1, gloss = false })
    if def and def.text then
        gloss.card_spot(x + 74, by, 250, 40, def.name, def.text, nil, cn)
    end
    kit.button(x + 330, by, 40, 40, ">", function()
        app.npc_pick = k % #choices + 1
        app.refresh()
    end, { key = "npc_next" })
    kit.button(x + 378, by, 150, 40, "Put it on them", function()
        npcs.add_drop(c, id, choices[k])
        app.refresh()
    end, { key = "npc_add", color = theme.go, hover = theme.go_hover, enabled = #list < 4 })
    M.draw_give(app, n, x + 560, by - 104, w - 588)
    kit.button(x + w - 128, by, 100, 40, "Close", function()
        M.close(app)
    end, { key = "npc_done" })
end

-- What they know: each secret they keep (theirs in the book, or one you gave them), where the table stands
-- with it, the ways it could come out, and your say in when.
M.ROWS = 4
function M.draw_secrets(app, n, x, y, w, h)
    local secrets = require "game.model.secrets"
    local gloss = require "game.ui.gloss"
    local c = app.campaign
    kit.text(x, y, "WHAT THEY KNOW", "ui14", theme.gold)
    kit.text(x + 140, y, "Only you know. Say it when you like.", "ui14", theme.faint, { w = w - 140, lines = 1 })
    local ry = y + 26
    local keys = secrets.held_by(c, n.id)
    if #keys == 0 then
        kit.text(x, ry, "Nothing they're keeping. Give them a secret below.", "ui18", theme.faint, { gloss = false, w = w, lines = 1 })
        return
    end
    local asked = {}
    for _, a in ipairs(secrets.asked(c)) do
        asked[a.key] = a.level
    end
    local row_h = 118
    for i, key in ipairs(keys) do
        if i > M.ROWS or ry + row_h > y + h then
            break
        end
        local d = secrets.def(key)
        kit.box(x, ry, w, row_h - 8, theme.panel, { radius = 8 })
        local title = util.capitalize(d.name or key) .. (d.page and ("  (page " .. d.page .. ")") or "")
        local _, planted = secrets.holds(c, key, n.id)
        local tt = kit.text(x + 12, ry + 8, title, "ui18b", theme.text, { w = w - 24, lines = 1, gloss = false })
        gloss.card_spot(x + 12, ry + 6, w - 24, 24, d.name or key, d.what .. (planted and " (You gave them this one.)" or ""), nil, tt)
        local stand, tone = secrets.standing(c, key)
        if asked[key] then
            stand = (asked[key] == "known" and "You'll tell them" or "You'll drop a hint") .. " at the next quiet moment."
            tone = "teal"
        elseif secrets.held(c, key) then
            stand = stand .. " Held back tonight."
            tone = "orange"
        end
        kit.text(x + 12, ry + 34, stand, "ui14", theme[tone] or theme.dim, { w = w - 24, lines = 1 })
        local ways = "Could come out by: " .. secrets.ways_text(key, c) .. ". The friends may find their own way, too."
        local wt = kit.text(x + 12, ry + 54, ways, "ui14", theme.faint, { w = w - 24, lines = 1 })
        gloss.card_spot(x + 12, ry + 52, w - 24, 20, "How it could come out", ways, nil, wt)
        local lv = secrets.level(c, key)
        local bx, bw = x + 12, math.floor((w - 24 - 16) / 3)
        kit.button(bx, ry + 76, bw, 30, "Reveal now", function()
            secrets.ask(c, key, "known")
            app.refresh()
        end, { key = "npc_reveal_" .. i, font = "ui14", enabled = lv ~= "known" and asked[key] ~= "known",
               color = theme.go, hover = theme.go_hover })
        kit.button(bx + bw + 8, ry + 76, bw, 30, "Drop a hint", function()
            secrets.ask(c, key, "hint")
            app.refresh()
        end, { key = "npc_hint_" .. i, font = "ui14", enabled = lv == nil and not asked[key] })
        local held = secrets.held(c, key)
        kit.button(bx + 2 * (bw + 8), ry + 76, bw, 30, held and "Let it out" or "Hold it back", function()
            secrets.hold(c, key, not held)
            app.refresh()
        end, { key = "npc_hold_" .. i, font = "ui14", enabled = lv ~= "known" })
        ry = ry + row_h
    end
end

-- Give them a secret to keep: one of the adventure's they don't hold yet. A new way for it to come out.
function M.draw_give(app, n, x, y, w)
    local secrets = require "game.model.secrets"
    local c = app.campaign
    local choices = {}
    for _, key in ipairs(secrets.list()) do
        local d = secrets.def(key)
        if d.type == "person" or d.type == "document" or d.type == "place" or d.type == "creature" then
            if not secrets.holds(c, key, n.id) and not secrets.knows(c, key) then
                table.insert(choices, key)
            end
        end
    end
    kit.text(x, y, "GIVE THEM A SECRET TO KEEP", "ui14", theme.gold)
    if #choices == 0 then
        kit.text(x, y + 30, "They could tell everything that's still hidden.", "ui14", theme.faint, { w = w, lines = 1 })
        return
    end
    local k = util.clamp(app.npc_secret_pick or 1, 1, #choices)
    app.npc_secret_pick = k
    local by = y + 24
    kit.button(x, by, 40, 40, "<", function()
        app.npc_secret_pick = (k - 2) % #choices + 1
        app.refresh()
    end, { key = "npc_sec_prev" })
    kit.box(x + 46, by, w - 46 - 46 - 176, 40, theme.panel2, { radius = 8 })
    local d = secrets.def(choices[k])
    local nt = kit.text(x + 58, by + 10, util.capitalize(d.name or choices[k]), "ui18", theme.text, { w = w - 46 - 46 - 200, lines = 1, gloss = false })
    require("game.ui.gloss").card_spot(x + 46, by, w - 46 - 46 - 176, 40, d.name or choices[k], d.what, nil, nt)
    kit.button(x + w - 46 - 176 + 6, by, 40, 40, ">", function()
        app.npc_secret_pick = k % #choices + 1
        app.refresh()
    end, { key = "npc_sec_next" })
    kit.button(x + w - 176 + 6, by, 170, 40, "Give it to them", function()
        secrets.plant(c, choices[k], n.id)
        app.refresh()
    end, { key = "npc_sec_give", color = theme.go, hover = theme.go_hover })
end

return M
