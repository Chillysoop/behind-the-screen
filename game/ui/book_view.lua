-- Reading a new book (A13): the "new supplement" evening opens this over prep. A page per entry
-- (what it is, what it would add, who at the table would light up); pull in up to three per
-- reading. app.book = { sel = entry id }; the reading is prep.reading (game/model/books.lua).
-- Keys: book_entry_<id>, book_pull, book_done.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local panels = require "game.ui.panels"
local content = require "game.model.content"
local util = require "game.model.util"
local books = require "game.model.books"

local M = {}

local X, Y, W, H = 120, 50, 1360, 800
local KIND = { monster = "Monster", item = "Magic item", place = "Place", hook = "Hook", module = "Published adventure" }

function M.open(app)
    local prep = app.campaign.prep
    local r = prep and prep.reading
    if not r then
        return false
    end
    local first = books.book(r.book).entries[1]
    app.book = { sel = app.book and app.book.sel or (first and first.id) }
    app.refresh()
    return true
end

function M.close(app)
    app.book = nil
    app.refresh()
end

-- What pulling it in would add, in a sentence.
local function adds(e)
    local card = e.card and content.components[e.card.id]
    if e.kind == "monster" then
        return "Adds " .. e.name .. " to your encounter builder, and a card for your deck: \"" .. card.name .. "\"."
    elseif e.kind == "item" then
        return "Adds a reward card to your deck: \"" .. card.name .. "\". Win the scene and someone at the table carries it, "
            .. "and the rules apply it from then on."
    elseif e.kind == "module" then
        local m = books.module(e.module)
        return "A whole scene ready to run: place, person, goal, twist and reward, for " .. util.int(content.books.MODULE_COST)
            .. "h of prep instead of 6 to 8. Swap its reward or recast its person with someone from your notebook for "
            .. util.int(content.books.SWAP_COST) .. "h each. Plays as " .. string.lower(content.scenes[m.type].name) .. "."
    end
    return "Adds a card to your deck: \"" .. card.name .. "\"."
end

-- The stat line for a monster, or the rules text for an item.
local function rules_text(e)
    if e.kind == "monster" then
        local m = require("game.rules.data.monsters")[e.monster]
        local atk = {}
        for _, a in ipairs(m.attacks) do
            table.insert(atk, a.name .. " +" .. util.int(a.to_hit))
        end
        return m.name .. ": AC " .. util.int(m.ac) .. ", HP " .. util.int(m.hp) .. ", CR " .. tostring(m.cr) .. " (" .. util.int(m.xp)
            .. " XP). " .. table.concat(atk, ", ") .. ". SRD 5.2.1, p. " .. util.int(m.page) .. "."
    elseif e.kind == "item" then
        local d = require("game.rules.data.magic_items")[e.item]
        return d.name .. " (" .. d.rarity .. (d.attune and ", requires Attunement" or "") .. "). " .. d.text
            .. " SRD 5.2.1, p. " .. util.int(d.page) .. "."
    elseif e.kind == "module" then
        return books.module(e.module).read_aloud
    end
    return e.card and e.card.line or ""
end

function M.draw(app)
    local st = app.book
    local camp = app.campaign
    local prep = camp.prep
    local r = prep and prep.reading
    if not (st and r) then
        app.book = nil
        return
    end
    local bk = books.book(r.book)
    local pulled = books.get(camp).pulled
    kit.layer("book", true)
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.62), { round = false })
    kit.box(X - 2, Y - 2, W + 4, H + 4, theme.gold, { radius = 14 })
    kit.box(X, Y, W, H, theme.bg, { radius = 13 })
    kit.text(X + 28, Y + 16, bk.name, "title30", theme.gold)
    kit.text(X + 28, Y + 58, bk.blurb, "ui18", theme.dim, { w = W - 420 })
    local left = r.left
    kit.text(X + W - 28, Y + 22, left > 0 and ("Pull in " .. util.int(left) .. " more tonight") or "That's three for tonight",
        "ui22b", left > 0 and theme.teal or theme.dim, { pivot = gui.PIVOT_NE })
    kit.text(X + W - 28, Y + 56, "The rest stay on the shelf for another evening.", "ui14", theme.faint, { pivot = gui.PIVOT_NE })

    -- The contents: one row per entry.
    local lx, ly, lw = X + 24, Y + 100, 400
    local rows = bk.entries
    local rh = math.min(30, math.floor((H - 190) / #rows))
    for i, e in ipairs(rows) do
        local yy = ly + (i - 1) * rh
        local on = st.sel == e.id
        local done = pulled[e.id]
        local ex = #books.excited(camp, e) > 0
        kit.button(lx, yy, lw, rh - 3, "", function()
            st.sel = e.id
            app.refresh()
        end, { color = on and theme.button_hover or (done and kit.rgba("#28403c") or theme.panel2), hover = theme.button_hover,
               key = "book_entry_" .. e.id })
        kit.text(lx + 10, yy + (rh - 3) / 2, kit.ellipsize(e.name, "ui14", lw - 150), "ui14", done and theme.teal or theme.text,
            { pivot = gui.PIVOT_W })
        kit.text(lx + lw - 10, yy + (rh - 3) / 2, done and "In your game" or (KIND[e.kind] or e.kind), "ui14",
            done and theme.teal or theme.faint, { pivot = gui.PIVOT_E })
        if ex and not done then
            kit.dot(lx + lw - 10 - kit.width(KIND[e.kind] or e.kind, "ui14") - 14, yy + (rh - 3) / 2, 8, theme.green)
        end
    end

    -- The page.
    local e = books.entry(st.sel) or rows[1]
    local px, py, pw = X + 460, Y + 100, W - 460 - 32
    kit.box(px, py, pw, H - 190, theme.panel, { radius = 10 })
    local tx, tw = px + 24, pw - 48
    local ty = py + 18
    kit.text(tx, ty, e.name, "title30", theme.text, { w = tw })
    ty = ty + kit.text_height(e.name, "title30", tw) + 4
    kit.text(tx, ty, string.upper(KIND[e.kind] or e.kind), "ui14", theme.gold)
    ty = ty + 28
    kit.text(tx, ty, e.what, "story22", theme.text, { w = tw })
    ty = ty + kit.text_height(e.what, "story22", tw) + 14
    local rt = rules_text(e)
    kit.text(tx, ty, rt, "ui18", theme.dim, { w = tw })
    ty = ty + kit.text_height(rt, "ui18", tw) + 14
    local a = adds(e)
    kit.text(tx, ty, "WHAT IT ADDS", "ui14", theme.gold)
    ty = ty + 22
    kit.text(tx, ty, a, "ui18", theme.text, { w = tw })
    ty = ty + kit.text_height(a, "ui18", tw) + 16
    -- Who'd light up, and who'd rather not.
    local ex = books.excited(camp, e)
    kit.text(tx, ty, "AT THE TABLE", "ui14", theme.gold)
    ty = ty + 26
    if #ex == 0 then
        kit.text(tx, ty, "Nobody at the table is especially into this. It'd be for you.", "ui18", theme.faint, { w = tw })
        ty = ty + 30
    else
        local fx = tx
        for _, p in ipairs(ex) do
            kit.dot(fx + 20, ty + 20, 38, panels.COLORS[p.key] or theme.panel3)
            kit.picture(fx + 4, ty + 4, 32, 32, panels.face(p.key))
            fx = fx + 46
        end
        local names = {}
        for _, p in ipairs(ex) do
            table.insert(names, p.name)
        end
        kit.text(fx + 8, ty + 20, util.join_names(names) .. (#names == 1 and " would love this." or " would love this."), "ui18",
            theme.green, { pivot = gui.PIVOT_W })
        ty = ty + 52
    end
    for _, u in ipairs(books.uneasy(camp, e)) do
        local line = u.player.name .. " asked for " .. u.tag .. " to stay " .. (u.kind == "line" and "out of the game." or "off screen.")
        kit.text(tx, ty, line, "ui18", theme.orange, { w = tw })
        ty = ty + kit.text_height(line, "ui18", tw) + 6
    end

    -- Pull it in.
    local ok, why = books.can_pull(camp, r, e.id)
    local done = pulled[e.id]
    kit.button(px + pw - 24 - 260, py + H - 190 - 24 - 50, 260, 50, done and "In your game" or "Pull it in", function()
        local pulled_ok, lifted = books.pull(camp, prep, r, e.id)
        if pulled_ok and lifted and #lifted > 0 then
            local names = {}
            for _, p in ipairs(lifted) do
                table.insert(names, p.name)
            end
            app.toast = util.join_names(names) .. " will be thrilled."
        end
        app.refresh()
    end, { font = "ui22b", enabled = ok, color = theme.go, hover = theme.go_hover, key = "book_pull" })
    if not ok and not done and why then
        kit.text(px + pw - 24 - 270, py + H - 190 - 24 - 25, why, "ui14", theme.faint, { pivot = gui.PIVOT_E })
    end
    if app.toast and app.book then
        kit.text(px + 24, py + H - 190 - 24 - 25, app.toast, "ui18", theme.teal, { pivot = gui.PIVOT_W })
        app.toast = nil
    end
    kit.button(X + W - 28 - 200, Y + H - 66, 200, 46, "Done reading", function()
        M.close(app)
    end, { font = "ui18b", color = theme.button, hover = theme.button_hover, key = "book_done" })
end

return M
