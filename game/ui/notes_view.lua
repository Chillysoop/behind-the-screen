-- The DM's notes (real-session pass): the binder behind the screen. Open it with N or the
-- Notes button on prep, game night and the report; game night waits while it's open.
--   This session   what tonight is for, the opening to read, the story cards and the board
--   Story so far   the campaign's secrets, every session's clues and moments, seeds in play
--   Who's who      the people of the story, with who the party has met
--   The party      who's playing whom, their backstory hooks, and their character sheets
-- The data is game/model/story.lua; the story itself game/data/arc.lua.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local content = require "game.model.content"
local story = require "game.model.story"
local util = require "game.model.util"
local seeds_mod = require "game.model.seeds"
local panels = require "game.ui.panels"

local M = {}

local X, Y, W, H = 110, 44, 1380, 816
local TABS = { { "session", "This session" }, { "story", "Story so far" }, { "people", "Who's who" },
               { "party", "The party" } }
local CLASS_MINI = { fighter = "mini_fighter", rogue = "mini_rogue", cleric = "mini_cleric", wizard = "mini_wizard" }

function M.is_open(app)
    return app.overlay == "notes"
end

function M.open(app, tab)
    app.overlay = "notes"
    app.notes_tab = tab or app.notes_tab or "session"
    M.draw(app)
end

function M.close(app)
    if app.notes_layer then
        kit.drop(app.notes_layer)
        app.notes_layer = nil
    end
    if app.overlay == "notes" then
        app.overlay = nil
    end
    kit.reset_hover()
end

function M.toggle(app)
    if M.is_open(app) then
        M.close(app)
    else
        M.open(app)
    end
end

-- Clues found tonight count before the night is over.
local function clues(app)
    local list = {}
    for _, cl in ipairs(story.init(app.campaign).clues) do
        table.insert(list, cl)
    end
    local night = app.screen == "night" and app.night
    for _, f in ipairs(night and night.story_found or {}) do
        if not story.has_clue(app.campaign, f.id) then
            table.insert(list, { week = app.campaign.week, id = f.id, text = f.text, tonight = true })
        end
    end
    return list
end

local function has(list, id)
    for _, cl in ipairs(list) do
        if cl.id == id then
            return cl
        end
    end
end

-- A heading inside the binder.
local function head(x, y, text)
    kit.text(x, y, string.upper(text), "ui14", theme.gold)
    return y + 22
end

-- Wrapped text that never gets cut: returns the y after it.
local function para(x, y, w, text, font, color)
    font = font or "ui18"
    kit.text(x, y, text, font, color or theme.text, { w = w })
    return y + kit.text_height(text, font, w) + 6
end

-- This session ---------------------------------------------------------------------------------------

local function tab_session(app, x, y, w)
    local c = app.campaign
    local beat = c:arc_beat()
    local col_w = 640
    local ly = y
    if not beat then
        ly = para(x, ly, col_w, "The first act is over. The story carries on from here: keep playing, and the notes keep "
            .. "what the party found out.", "ui18", theme.dim)
    else
        kit.text(x, ly, "SESSION " .. util.int(c.week) .. " OF " .. util.int(content.arc.SESSIONS), "ui14", theme.dim)
        ly = ly + 20
        kit.text(x, ly, beat.title, "title30", theme.text)
        ly = ly + 44
        ly = para(x, ly, col_w, beat.about, "ui18", theme.dim)
        ly = head(x, ly + 6, "What you're hoping for")
        ly = para(x, ly, col_w, beat.goal or beat.hint, "ui18", theme.text)
        ly = head(x, ly + 6, "Read this when the night starts")
        local open = beat.open
        if beat.open_if and story.has_clue(c, beat.open_if.clue) then
            open = beat.open_if.text
        end
        local oh = kit.text_height(open or "", "story22", col_w - 32) + 22
        kit.box(x, ly, col_w, oh, kit.rgba("#efe4c8", 0.1), { radius = 8 })
        kit.text(x + 16, ly + 10, open or "", "story22", theme.text, { w = col_w - 32 })
        ly = ly + oh + 10
        ly = head(x, ly + 4, "This week's story cards")
        local found = clues(app)
        for _, id in ipairs(beat.cards) do
            local card = content.components[id]
            local prep = c.prep
            local placed = prep and prep:placed_at(id)
            local got = has(found, id)
            local state, scol
            if got then
                state, scol = got.tonight and "Played tonight" or "Played", theme.green
            elseif placed then
                state, scol = "On scene " .. util.int(placed), theme.gold
            elseif prep and prep.arc_cards and prep.arc_cards[id] then
                state, scol = "In your hand", theme.dim
            else
                state, scol = "Not this week", theme.faint
            end
            kit.text(x, ly, card and card.name or id, "ui18b", theme.text)
            kit.text(x + col_w, ly + 2, state, "ui14", scol, { pivot = gui.PIVOT_NE })
            ly = ly + 22
            local reveal = beat.reveal and beat.reveal[id]
            if reveal then
                ly = para(x + 12, ly, col_w - 12, reveal, "ui14", theme.dim)
            end
            ly = ly + 2
        end
    end
    -- The board as you wrote it.
    local rx = x + col_w + 40
    local rw = w - col_w - 40
    local ry = head(rx, y, "Your board this week")
    local prep = c.prep
    for i, s in ipairs(prep and prep.scenes or {}) do
        local tname = s.type and content.scenes[s.type].name or "No type yet"
        kit.text(rx, ry, "Scene " .. util.int(i) .. ":  " .. tname, "ui18b", s.type and theme.text or theme.faint)
        ry = ry + 24
        for _, kind in ipairs(content.kinds) do
            local card = s.slots[kind]
            kit.text(rx + 12, ry, content.kind_names[kind], "ui14", theme.dim)
            kit.text(rx + 130, ry, card and card.name or "improvise it", "ui14", card and theme.text or theme.faint,
                { w = rw - 130 })
            ry = ry + kit.text_height(card and card.name or "x", "ui14", rw - 130) + 2
        end
        if s.type == "combat" or s.type == "set_piece" then
            local enc = prep:encounter(i)
            local names = M.monster_list(enc.ids)
            ry = para(rx + 12, ry + 2, rw - 12, (enc.built and "Your fight: " or "Suggested fight: ") .. names, "ui14",
                enc.built and theme.gold or theme.dim)
        end
        ry = ry + 10
    end
    local night = app.screen == "night" and app.night
    if night and night.scenes then
        ry = head(rx, ry + 4, "Tonight so far")
        for _, sc in ipairs(night.scenes) do
            if sc.title then
                kit.text(rx + 12, ry, "Scene " .. util.int(sc.index) .. ": " .. sc.title, "ui14", theme.text)
                ry = ry + 20
            end
        end
    end
end

-- "the goblin chief, 3 goblin warriors"
function M.monster_list(ids)
    local monsters = require "game.rules.data.monsters"
    local counts, order = {}, {}
    for _, id in ipairs(ids or {}) do
        if not counts[id] then
            table.insert(order, id)
        end
        counts[id] = (counts[id] or 0) + 1
    end
    local parts = {}
    for _, id in ipairs(order) do
        local m = monsters[id]
        local name = m and m.name or id
        if counts[id] > 1 then
            name = util.int(counts[id]) .. " " .. name .. (string.sub(name, -1) == "f" and "s" or (string.sub(name, -1) == "s" and "" or "s"))
            name = string.gsub(name, "Wolfs$", "Wolves")
        end
        table.insert(parts, name)
    end
    return table.concat(parts, ", ")
end

-- Story so far ----------------------------------------------------------------------------------------

local function tab_story(app, x, y, w)
    local notes = story.notes(app.campaign)
    local found = clues(app)
    local col_w = 620
    local ly = head(x, y, "Only you know this")
    for _, line in ipairs(notes.premise) do
        ly = para(x, ly, col_w, line, "ui18", theme.dim)
    end
    ly = head(x, ly + 8, "What the party knows")
    if #found == 0 then
        ly = para(x, ly, col_w, "Nothing yet. Put this week's story cards on the board and the story starts moving.",
            "ui18", theme.faint)
    end
    for _, cl in ipairs(found) do
        kit.dot(x + 6, ly + 11, 8, cl.tonight and theme.gold or theme.teal)
        kit.text(x + 18, ly, (cl.tonight and "Tonight: " or ("Session " .. util.int(cl.week) .. ": ")) .. cl.text, "ui18",
            theme.text, { w = col_w - 18 })
        ly = ly + kit.text_height(cl.text .. "Session 0: ", "ui18", col_w - 18) + 6
    end
    -- Seeds in play.
    local growing = seeds_mod.growing(app.campaign)
    if #growing > 0 then
        ly = head(x, ly + 8, "Seeds in play")
        for _, s in ipairs(growing) do
            local def = content.seeds[s.id]
            local left = s.week + content.seeds.PAYOFF_WEEKS - app.campaign.week
            ly = para(x, ly, col_w, def.name .. ": planted in session " .. util.int(s.week)
                .. (left > 0 and (", " .. util.int(left) .. " more week" .. (left == 1 and "" or "s") .. " to pay it off.") or ". Pay it off now."),
                "ui14", theme.text)
        end
    end
    -- The sessions.
    local rx = x + col_w + 40
    local rw = w - col_w - 40
    local ry = head(rx, y, content.arc.name .. ", the first act")
    for i, b in ipairs(notes.beats) do
        local week = notes.weeks[i]
        local n_found = 0
        for _, id in ipairs(b.cards) do
            if has(found, id) then
                n_found = n_found + 1
            end
        end
        local status = b.now and "Now" or (b.done and "Played" or "Coming up")
        local scol = b.now and theme.gold or (b.done and theme.teal or theme.faint)
        kit.text(rx, ry, util.int(i) .. ".  " .. b.title, "ui18b", theme.text)
        kit.text(rx + rw, ry + 2, status, "ui14", scol, { pivot = gui.PIVOT_NE })
        ry = ry + 24
        ry = para(rx + 22, ry, rw - 22, b.about, "ui14", theme.dim)
        if b.total > 0 and (b.done or b.now) then
            ry = para(rx + 22, ry, rw - 22, "Story found: " .. util.int(n_found) .. " of " .. util.int(b.total), "ui14",
                n_found == b.total and theme.green or (n_found > 0 and theme.gold or theme.orange))
        end
        if week then
            if #week.scenes > 0 then
                ry = para(rx + 22, ry, rw - 22, "Where they went: " .. table.concat(week.scenes, ", "), "ui14", theme.text)
            end
            for _, m in ipairs(week.moments or {}) do
                ry = para(rx + 22, ry, rw - 22, "Moment: " .. m, "ui14", theme.text)
            end
            if week.cliff then
                ry = para(rx + 22, ry, rw - 22, "Ended on a cliffhanger.", "ui14", theme.gold)
            end
        end
        ry = ry + 8
    end
end

-- Who's who ---------------------------------------------------------------------------------------------

local function tab_people(app, x, y, w)
    local notes = story.notes(app.campaign)
    local cw, ch, gap = 430, 150, 14
    for i, p in ipairs(notes.people) do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local px, py = x + col * (cw + gap), y + row * (ch + gap)
        kit.box(px, py, cw, ch, p.met and theme.panel2 or theme.panel, { radius = 10 })
        if p.sprite then
            kit.picture(px + 10, py + 10, 76, 95, "mini_" .. p.sprite, kit.rgba("#ffffff", p.met and 1 or 0.45))
        else
            kit.dot(px + 48, py + 56, 70, kit.rgba("#000000", 0.25))
            kit.text(px + 48, py + 56, "?", "title30", theme.faint, { pivot = gui.PIVOT_CENTER })
        end
        kit.text(px + 100, py + 10, p.name, "ui18b", theme.text)
        kit.text(px + 100, py + 32, p.role, "ui14", theme.gold, { w = cw - 110 })
        local ah = kit.text_height(p.role, "ui14", cw - 110)
        kit.text(px + 100, py + 36 + ah, p.about, "ui14", theme.dim, { w = cw - 110 })
        local tag = p.met and (p.week and ("Met in session " .. util.int(p.week)) or "Known to everyone")
            or "The party hasn't met them yet"
        kit.text(px + cw - 10, py + ch - 22, tag, "ui14", p.met and theme.teal or theme.faint, { pivot = gui.PIVOT_NE })
    end
end

-- The party -------------------------------------------------------------------------------------------------

local function tab_party(app, x, y, w)
    local c = app.campaign
    local cw, gap = 316, 18
    for i, p in ipairs(c.players) do
        local px = x + (i - 1) * (cw + gap)
        kit.box(px, y, cw, 600, theme.panel2, { radius = 10 })
        kit.dot(px + 60, y + 60, 96, panels.COLORS[p.key] or theme.panel3)
        kit.picture(px + 12, y + 12, 96, 96, panels.face(p.key))
        kit.picture(px + 120, y + 20, 72, 90, CLASS_MINI[p.class] or "mini_fighter")
        kit.text(px + 204, y + 20, p.name, "ui22b", theme.text)
        kit.text(px + 204, y + 50, "plays", "ui14", theme.dim)
        kit.text(px + 204, y + 68, p.char, "ui18b", theme.gold)
        local level = c.level or 2
        local sub = level >= 3 and c.subclasses and c.subclasses[p.class]
        local subs = require "game.rules.subclasses"
        local line = p.class_name .. ", level " .. util.int(level)
        if sub and subs.list[sub] then
            line = line .. ", " .. subs.list[sub].name
        end
        local py = y + 124
        py = para(px + 14, py, cw - 28, line, "ui18", theme.text)
        py = head(px + 14, py + 6, "Backstory hook")
        py = para(px + 14, py, cw - 28, util.capitalize(p.thread or ""), "ui18", theme.text)
        py = head(px + 14, py + 6, "At the table")
        py = para(px + 14, py, cw - 28, p.notes or "", "ui14", theme.dim)
        if not p.present then
            py = para(px + 14, py + 4, cw - 28, p.on_break and "Taking a break from Thursdays." or "Out this week.", "ui14",
                theme.orange)
        end
        kit.button(px + 14, y + 600 - 54, cw - 28, 40, "Character sheet", function()
            M.close(app)
            if app.open_sheet then
                app.open_sheet(p.key)
            end
        end, { font = "ui18b", key = "notes_sheet_" .. p.key })
    end
end

function M.draw(app)
    if app.notes_layer then
        kit.drop(app.notes_layer)
    end
    local l = kit.layer("notes", true)
    app.notes_layer = l
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.55), { round = false })
    kit.box(X, Y, W, H, theme.bg, { radius = 14 })
    kit.box(X, Y, W, 60, theme.panel, { radius = 14 })
    kit.text(X + 24, Y + 14, "YOUR NOTES", "title30", theme.gold)
    local tx = X + 240
    for _, t in ipairs(TABS) do
        local on = app.notes_tab == t[1]
        local tw = kit.width(t[2], "ui18b") + 36
        kit.button(tx, Y + 12, tw, 36, t[2], function()
            app.notes_tab = t[1]
            M.draw(app)
        end, { font = "ui18b", color = on and theme.go or theme.panel2, hover = theme.button_hover,
               key = "notes_tab_" .. t[1] })
        tx = tx + tw + 10
    end
    kit.button(X + W - 130, Y + 12, 110, 36, "Close", function()
        if app.close_overlay then
            app.close_overlay()
        else
            M.close(app)
        end
    end, { font = "ui18b", key = "notes_close" })
    kit.text(X + W - 144, Y + 22, "N or Esc", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    local cx, cy, cw = X + 30, Y + 84, W - 60
    local tab = app.notes_tab or "session"
    if tab == "session" then
        tab_session(app, cx, cy, cw)
    elseif tab == "story" then
        tab_story(app, cx, cy, cw)
    elseif tab == "people" then
        tab_people(app, cx, cy, cw)
    else
        tab_party(app, cx, cy, cw)
    end
end

return M
