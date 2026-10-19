-- The prep board: group chat, the valley map with tonight's route and a stop's scene card beside
-- it, the pacing curve, the card drawer and the players. Rebuilt from scratch whenever something
-- changes.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local gloss = require "game.ui.gloss"
local content = require "game.model.content"
local score = require "game.model.score"
local prep_mod = require "game.model.prep"
local empathy = require "game.model.empathy"
local util = require "game.model.util"
local social = require "game.model.social"
local seeds_mod = require "game.model.seeds"
local one_on_one = require "game.model.one_on_one"
local places_mod = require "game.model.places"
local valley_view = require "game.ui.valley_view"
local function notes_view_mod()
    return require "game.ui.notes_view"
end
local talk_view = require "game.ui.talk_view"
local book_view = require "game.ui.book_view"
local books_mod = require "game.model.books"
local messages_view = require "game.ui.messages_view"
local levelup_view = require "game.ui.levelup_view"
local panels = require "game.ui.panels"
local notes_view = require "game.ui.notes_view"
local ask_view = require "game.ui.ask_view"
local deck = require "game.model.deck"
local world = require "game.model.world"
local ledger = require "game.model.ledger"

local M = {}

local CARD_X, CARD_Y, CARD_W, CARD_H, CARD_GAP = 364, 84, 256, 472, 22

-- The first prep board keeps to the scenes, the hand, seeds and the players (playtest, October
-- 13: week 1 was a wall of about 60 controls). Evenings off, the world's moves, one-on-ones,
-- Empathy and the long-term bars arrive in week 2, each with a tip. Nothing is gone: the world
-- still moves off screen in week 1, it just isn't asked about.
function M.staged(app)
    return (app.campaign.week or 0) <= 1
end
local SLOT_H = 70

local function tier_color(fun)
    if fun >= 72 then
        return theme.green
    elseif fun >= 55 then
        return theme.teal
    elseif fun >= 40 then
        return theme.gold
    elseif fun >= 25 then
        return theme.orange
    end
    return theme.red
end

-- Who at the table would enjoy a card, from what they like and whose backstory it is: the
-- DM's read of their friends (real-session pass). { key = 1 | -1 }
local function card_leans(app, c)
    local out = {}
    for _, p in ipairs(app.campaign.players) do
        if p.present then
            local like = 0
            for _, t in ipairs(c.tags or {}) do
                like = like + score.like(p, t)
            end
            if c.thread == p.key then
                like = like + 2
            end
            if like >= 1.3 then
                out[p.key] = 1
            elseif like <= -0.3 then
                out[p.key] = -1
            end
        end
    end
    return out
end

local function type_leans(app, scene_type)
    local out = {}
    for _, p in ipairs(app.campaign.players) do
        if p.present then
            local t = score.taste(p, scene_type)
            if t >= 1.3 then
                out[p.key] = 1
            elseif t <= -0.3 then
                out[p.key] = -1
            end
        end
    end
    return out
end

-- Little faces in a row, ringed green (they'd love it) or red (they wouldn't).
local function faces(app, x, y, leans, size)
    size = size or 20
    local fx = x
    for _, want in ipairs({ 1, -1 }) do
        for _, p in ipairs(app.campaign.players) do
            if leans[p.key] == want then
                kit.dot(fx + size / 2 + 2, y + size / 2 + 2, size + 4, want > 0 and theme.green or theme.red)
                kit.picture(fx + 2, y + 2, size, size, panels.face(p.key))
                fx = fx + size + 6
            end
        end
    end
    return fx - x
end

-- Why someone likes a card, in words: "Dev: action. Mara: lore, mystery."
local function lean_reasons(app, c)
    local likes, dislikes = {}, {}
    for _, p in ipairs(app.campaign.players) do
        if p.present then
            local pos, neg = {}, {}
            for _, t in ipairs(c.tags or {}) do
                local v = score.like(p, t)
                if v >= 0.6 then
                    table.insert(pos, t)
                elseif v <= -0.3 then
                    table.insert(neg, t)
                end
            end
            local net = 0
            for _, t in ipairs(c.tags or {}) do
                net = net + score.like(p, t)
            end
            if c.thread == p.key then
                table.insert(pos, 1, p.char .. "'s backstory")
                net = net + 1.5
            end
            -- One list per player (A6): mixed feelings land on whichever side wins.
            if #pos > 0 and #neg > 0 then
                if net >= 0 then
                    neg = {}
                else
                    pos = {}
                end
            end
            if #pos > 0 then
                table.insert(likes, p.name .. " (" .. table.concat(pos, ", ") .. ")")
            end
            if #neg > 0 then
                table.insert(dislikes, p.name .. " (" .. table.concat(neg, ", ") .. ")")
            end
        end
    end
    return likes, dislikes
end

-- Hovering a card in the hand: everything about it, nothing cut off.
local function card_detail(app, prep, c, s, x0, why)
    local w = 470
    local loc = s and s.slots and s.slots.location
    local line = content.line_for(c, c.kind ~= "location" and loc or nil)
    local likes, dislikes = lean_reasons(app, c)
    local rows = {}
    table.insert(rows, { line, "story22", theme.text })
    if why then
        table.insert(rows, { why, "ui18b", theme.orange })
    end
    -- Why it's in your hand, and what it follows from (the slice rework).
    local pin = prep.pins and prep.pins[c.id]
    if pin and pin.note then
        table.insert(rows, { "Pinned: " .. pin.note, "ui14", theme.gold })
    end
    local camp = app.campaign
    local from, how = deck.follows(camp, c.id)
    if from then
        local hw = how == "win" and "won" or (how == "lose" and "lost" or (how == "escaped" and "got away" or "played"))
        table.insert(rows, { "Follows \"" .. from.name .. "\" (" .. hw .. ").", "ui14", theme.teal })
    else
        local e = deck.entry(camp, c.id)
        if e and e.from and string.sub(e.from, 1, 6) == "world:" then
            local fd = ledger.data[string.sub(e.from, 7)]
            table.insert(rows, { "From off screen: " .. (fd and fd.name or "the world") .. ".", "ui14", theme.teal })
        end
    end
    if c.kind == "cast" then
        local pid = ledger.person_of(c)
        if pid and ledger.met(camp, pid) then
            local a = ledger.att(camp, pid)
            local label = ledger.label(a)
            local last = ledger.history(camp, pid)[1]
            table.insert(rows, { label .. " toward the party" .. (last and (". Last time: " .. ledger.entry_text(camp, last, { short_target = true })) or "."),
                "ui14", (a <= -1) and theme.red or ((a >= 1) and theme.green or theme.dim) })
        end
    end
    -- The storylines it moves: placing it opens their Story log beside the board.
    do
        local storylines = require "game.model.storylines"
        local names = {}
        for _, id in ipairs(storylines.of_card(camp, c)) do
            local d = storylines.def(camp, id)
            if d then
                table.insert(names, d.name)
            end
        end
        if #names > 0 then
            table.insert(rows, { "Moves " .. util.join_names(names) .. ". Place it to see the story so far.", "ui14", theme.teal })
            -- The story it moves, at a glance (a backstory first).
            local ids = storylines.of_card(camp, c)
            table.sort(ids, function(a, b)
                local ba, bb = string.sub(a, 1, 3) == "bs_", string.sub(b, 1, 3) == "bs_"
                if ba ~= bb then
                    return ba
                end
                return false
            end)
            local line = ids[1] and require("game.model.chronicle").glance_line(camp, ids[1], 1)
            if line then
                table.insert(rows, { "So far: " .. line, "ui14", theme.dim })
            end
        end
    end
    -- What it can change for next session (the lore screen's lines, October 16): what a win or a
    -- loss puts in your hand, a story it ties off, a front it holds back.
    do
        local ok, items = pcall(require("game.model.lore_screen").card_items, camp, prep, nil, c, nil)
        local TONES = { good = theme.green, bad = theme.orange, front = theme.purple }
        local n = 0
        for _, it in ipairs(ok and items or {}) do
            if n < 3 and (it.kind == "opens_win" or it.kind == "opens_lose" or it.kind == "opens" or it.kind == "resolve"
                or it.kind == "front" or it.kind == "move") then
                n = n + 1
                table.insert(rows, { it.text, "ui14", TONES[it.tone] or theme.dim })
            end
        end
    end
    local fits = {}
    for _, f in ipairs(c.fits or {}) do
        table.insert(fits, content.scenes[f] and content.scenes[f].name or f)
    end
    if #fits > 0 then
        table.insert(rows, { "Best in: " .. table.concat(fits, ", ") .. ".", "ui14", theme.dim })
    end
    if c.where then
        local need = {}
        for _, wh in ipairs(c.where) do
            table.insert(need, wh)
        end
        table.insert(rows, { "Only happens somewhere: " .. table.concat(need, ", ") .. ".", "ui14", theme.dim })
    end
    if #likes > 0 then
        table.insert(rows, { "Would love it: " .. table.concat(likes, ", ") .. ".", "ui14", theme.green })
    end
    if #dislikes > 0 then
        table.insert(rows, { "Not their thing: " .. table.concat(dislikes, ", ") .. ".", "ui14", theme.red })
    end
    local h = 52
    for _, r in ipairs(rows) do
        h = h + kit.text_height(r[1], r[2], w - 32) + 8
    end
    local x = util.clamp(x0 - w / 2, 8, kit.W - w - 8)
    local y = (app.sel and app.sel.kind ~= "type") and math.max(8, 560 - h) or (676 - h)
    local l = kit.layer("prep_hover")
    app.hover_layer = l
    kit.box(x - 2, y - 2, w + 4, h + 4, theme.gold, { radius = 12 })
    kit.box(x, y, w, h, kit.rgba("#201813", 0.98), { radius = 11 })
    kit.text(x + 16, y + 12, c.name, "ui18b", theme.text, { w = w - 90 })
    kit.text(x + w - 16, y + 14, string.upper(content.kind_names[c.kind]) .. "  " .. util.int(c.cost) .. "h", "ui14",
        theme.gold, { pivot = gui.PIVOT_NE })
    local ry = y + 44
    for _, r in ipairs(rows) do
        kit.text(x + 16, ry, r[1], r[2], r[3], { w = w - 32 })
        ry = ry + kit.text_height(r[1], r[2], w - 32) + 8
    end
end

local function drop_hover(app)
    if app.hover_layer then
        kit.drop(app.hover_layer)
        app.hover_layer = nil
    end
end

local function top_bar(app, prep)
    kit.box(0, 0, kit.W, 66, theme.bg, { round = false })
    -- "Session", everywhere the DM looks (October 15: week and session were the same number by two
    -- names).
    kit.text(24, 14, "SESSION " .. util.int(app.campaign.week), "title30", theme.gold)
    -- The slice's story beat (M7), or the plain reminder once the slice is over.
    local beat = app.campaign:arc_beat()
    -- The story beat is the way into your notes (N).
    kit.button(292, 4, 524, 58, "", function()
        if app.open_notes then
            app.open_notes("session")
        end
    end, { color = theme.bg, hover = theme.panel, radius = 8, key = "notes_open" })
    if beat then
        kit.text(300, 12, "PREP  -  " .. util.int(app.campaign.week) .. " OF " .. util.int(content.arc.SESSIONS) .. ":  "
            .. string.upper(beat.title), "ui14", theme.gold, { w = 400, lines = 1 })
        local hint = beat.hint .. " Story cards are in your hand."
        if kit.width(hint, "ui18") > 510 then
            hint = beat.hint
        end
        kit.text(300, 32, hint, "ui18", theme.dim)
    else
        kit.text(300, 24, "Game night is Thursday. Plan tonight's route.", "ui18", theme.dim)
    end
    local pending = M.staged(app) and 0 or world.pending(app.campaign)
    local moved = notes_view_mod().threads_moved(app)
    -- All three are links into your notes (playtest, October 13: "5 world moves to decide" read
    -- as a label, and nobody found where to decide them).
    local nw = kit.width("Your notes (N)", "ui14")
    kit.button(808 - nw - 4, 8, nw + 8, 22, "", function()
        app.open_notes()
    end, { color = kit.rgba("#000000", 0), hover = theme.button_hover, key = "prep_notes" })
    kit.text(808, 12, "Your notes (N)", "ui14", (pending > 0 or moved) and theme.orange or theme.faint, { pivot = gui.PIVOT_NE })
    local function link(text, tab, key)
        local tw = kit.width(text, "ui14")
        kit.button(912, 8, tw + 8, 22, "", function()
            app.open_notes(tab)
        end, { color = kit.rgba("#000000", 0), hover = theme.button_hover, key = key })
        kit.text(916, 12, text, "ui14", theme.orange)
        kit.box(916, 12 + kit.line_height("ui14") - 3, tw, 1.5, theme.orange, { round = false })
    end
    if moved and pending == 0 then
        kit.dot(808 - nw - 10, 20, 10, theme.orange)
        link("A storyline moved: see Storylines", "threads", "prep_threads_moved")
    end
    if pending > 0 then
        -- The world's moves wait in your notes (This week): a dot until you've decided them.
        kit.dot(808 - nw - 10, 20, 10, theme.orange)
        link(util.int(pending) .. (pending == 1 and " world move to decide" or " world moves to decide") .. ": open", "week",
            "prep_world_moves")
    end
    -- Prep hours as pips.
    local left = math.max(0, prep:left())
    local x0 = 820
    kit.text(x0, 12, "PREP TIME", "ui14", theme.dim)
    -- What the hours are, and what the level is (the newcomer playtest, October 16).
    gloss.card_spot(x0 - 4, 30, prep.budget * 22 + 8, 26, "Prep time",
        "The hours you have this week to get ready. Each card you put on a stop costs some. Whatever you leave "
        .. "empty, you'll make up at the table.")
    for i = 1, prep.budget do
        local filled = i <= left
        kit.box(x0 + (i - 1) * 22, 34, 18, 18, filled and theme.gold or theme.panel3, { radius = 4 })
    end
    kit.text(x0 + prep.budget * 22 + 8, 33, util.int(left) .. (left == 1 and " hour left" or " hours left"), "ui18", theme.text)
    -- The party's level (M6): level up from here once it's earned.
    local lv = app.campaign:level_status()
    if lv.ready then
        kit.button(1208, 12, 136, 42, "Level up", function()
            levelup_view.level_up(app)
        end, { font = "ui18b", color = lv.overdue and kit.rgba("#8a4a2a") or theme.button, key = "level_up" })
        kit.dot(1212, 16, 12, theme.orange)   -- waiting on you (A6)
        kit.text(1276, 56, lv.overdue and "Overdue!" or ("Level " .. util.int(lv.level + 1) .. " is ready"), "ui14",
            lv.overdue and theme.orange or theme.dim, { pivot = gui.PIVOT_N })
    else
        kit.text(1276, 24, "LEVEL " .. util.int(lv.level), "ui18b", theme.dim, { pivot = gui.PIVOT_N, gloss = { story = true } })
    end
    local ready = prep:ready()
    kit.button(1356, 12, 220, 42, "Run game night  >", function()
        M.run_night(app)
    end, { enabled = ready, color = theme.go, hover = theme.go_hover, key = "run_night" })
    if not (ready and M.party_not_rested(app)) then
        kit.text(1466, 56, ready and "or press Enter" or "Pick a type for every stop first.", "ui14", theme.dim, { pivot = gui.PIVOT_N })
    end
end

-- Theories pinned to a corner of the board (B5): the chat's best guesses, as sticky notes. Make
-- one true and the seed's payoff proves them right.
local function theory_pins(app)
    local c = app.campaign
    local pins = seeds_mod.pinned(c)
    local y = 885 - #pins * messages_view.PIN_H + 6
    for _, th in ipairs(pins) do
        local claim = seeds_mod.claim(th)
        local p = c:player(th.key)
        local h = messages_view.PIN_H - 10
        kit.box(24, y, 320, h, kit.rgba("#f3df8a"), { radius = 4 })
        kit.text(34, y + 6, "THEORY: " .. string.upper(p and p.name or "?"), "ui14", theme.ink_dim)
        local text = claim and claim.says or ""
        kit.text(34, y + 24, text, "ui14", theme.ink, { w = 300, lines = 2 })      -- the whole theory (A8)
        local ok, why = seeds_mod.can_steal(c, th)
        -- Under it: the seed it's about, or why it can't come true now (two short lines, beside the button).
        local under = (not ok and why) or content.seeds[th.seed].name
        kit.text(34, y + h - 38, under, "ui14", theme.ink_dim, { w = 172, lines = 2 })
        kit.button(214, y + h - 34, 120, 28, "Make it true", function()
            local done, msg = seeds_mod.steal(c, th)
            local who = p and p.name or "They"
            app.toast = done and ("Canon now: when \"" .. content.seeds[th.seed].name .. "\" pays off, it proves " .. who
                .. " right. " .. who .. " is going to be insufferable about this.") or msg
            app.refresh()
        end, { font = "ui14", enabled = ok, color = theme.go, hover = theme.go_hover, key = "steal_" .. th.seed })
        y = y + messages_view.PIN_H
    end
end

local function chat_column(app)
    messages_view.column(app)
    theory_pins(app)
end

-- A stop's scene card, beside the valley map (October 17: the map replaced the three cards in a
-- row). Its tabs switch between the stops.
local function scene_card(app, prep, i)
    local s = prep.scenes[i]
    local x = valley_view.SIDE_X
    local y = CARD_Y
    local sel = app.sel
    kit.box(x, y, CARD_W, CARD_H, theme.paper, { radius = 10 })
    kit.text(x + 12, y + 9, "STOP", "ui14", theme.ink_dim)
    for k = 1, #prep.scenes do
        local on = k == i
        local done = prep.scenes[k].type ~= nil
        kit.button(x + 56 + (k - 1) * 26, y + 5, 22, 22, util.int(k), function()
            valley_view.show_stop(app, k)
            app.refresh()
        end, { font = "ui14", color = on and kit.rgba("#e8b04a") or theme.paper_dim, hover = kit.rgba("#f6edd6"),
               text_color = (on or done) and theme.ink or theme.ink_dim, radius = 6, key = "stop_" .. util.int(k) })
    end
    -- The storylines this scene moves (game/model/storylines.lua): a colored pip each, hover to name them.
    M.scene_storylines(app, prep, s, x + 142, y + 17, 2)
    -- Tension pips.
    local t = prep_mod.tension(s.type, s.slots, i == #prep.scenes)
    for k = 1, 5 do
        kit.dot(x + CARD_W - 16 - (5 - k) * 12, y + 17, 9, k <= t and theme.red or kit.rgba("#000000", 0.15))
    end
    gloss.card_spot(x + CARD_W - 16 - 4 * 12 - 8, y + 9, 5 * 12 + 8, 18, "Tension",
        "How intense the scene is, from 1 (calm) to 5 (edge of their seats). The pacing graph below plots it: a "
        .. "good night rises and falls, and ends high.")
    -- Scene type.
    local selected_type = sel and sel.scene == i and sel.kind == "type"
    if selected_type then
        kit.box(x + 7, y + 29, CARD_W - 14, 46, theme.select, { radius = 9 })
    end
    local tcolor = s.type and theme.scene[s.type] or kit.rgba("#8a3a30")
    local fighty = s.type == "combat" or s.type == "set_piece"
    if s.open then
        tcolor, fighty = theme.decision.agency, false
    end
    kit.button(x + 10, y + 32, fighty and CARD_W - 112 or CARD_W - 20, 40,
        s.open and "Open: they choose" or (s.module and books_mod.module(s.module.id).name)
            or (s.type and content.scenes[s.type].name or "Choose a type"),
        function()
            app.sel = { scene = i, kind = "type" }
            app.refresh()
        end, { color = tcolor, hover = theme.button_hover, font = (fighty or s.open) and "ui18b" or "ui22b", key = "type_" .. util.int(i) })
    if fighty then
        -- The encounter builder: the fight this scene brings, built around the party.
        local enc = prep:encounter(i)
        kit.button(x + CARD_W - 98, y + 32, 88, 40, enc.built and "Your fight" or "The fight", function()
            if app.open_encounter then
                app.open_encounter(i)
            end
        end, { font = "ui14", color = enc.built and theme.go or theme.button, hover = theme.button_hover,
               key = "fight_" .. util.int(i) })
    end
    -- Slots.
    for k, kind in ipairs(content.kinds) do
        repeat   -- (break = on to the next slot)
        local sy = y + 84 + (k - 1) * (SLOT_H + 6)
        local c = s.slots[kind]
        local selected = sel and sel.scene == i and sel.kind == kind
        if selected then
            kit.box(x + 7, sy - 3, CARD_W - 14, SLOT_H + 6, theme.select, { radius = 9 })
        end
        kit.button(x + 10, sy, CARD_W - 20, SLOT_H, "", function()
            app.sel = { scene = i, kind = kind }
            app.refresh()
        end, { color = theme.paper_dim, hover = kit.rgba("#f6edd6"), key = "slot_" .. util.int(i) .. "_" .. kind })
        local label = string.upper(content.kind_names[kind])
        if s.open and kind == "location" then
            -- An open scene's spots instead of one place (A15).
            label = "SPOTS  (" .. util.int(#s.spots) .. " OF " .. util.int(content.open_scenes.SPOTS) .. ")"
            local names = {}
            for _, id in ipairs(s.spots) do
                local sc = content.components[id]
                table.insert(names, sc and (sc.short or sc.name) or id)
            end
            kit.text(x + 20, sy + 6, label, "ui14", kit.rgba("#2f6f5a"))
            -- (A dot between them: "Ilsa's room, Hale's Crossing" read as one address, October 15.)
            local spots = #names > 0 and util.capitalize(table.concat(names, "  /  ")) or "Sketch a few places they might go"
            -- (Long place names drop to the small type rather than get cut off, A8.)
            local sfont = (#names > 0 and kit.text_height(spots, "ui18b", CARD_W - 40) <= 2 * kit.text_height("A", "ui18b", CARD_W - 40))
                and "ui18b" or "ui14"
            kit.text(x + 20, sy + 25, spots, sfont, #names > 0 and theme.ink or kit.rgba("#9a8a72"),
                { w = CARD_W - 40, lines = 2 })
            break
        end
        if not c and M.new_in_hand(app, prep, kind) > 0 then
            -- New cards of this kind in your hand (A6): a dot until you've opened it.
            kit.dot(x + CARD_W - 28, sy + 13, 11, theme.green)
            kit.text(x + CARD_W - 38, sy + 6, "new", "ui14", kit.rgba("#2f6f3a"), { pivot = gui.PIVOT_NE })
        end
        if c and c.thread then
            local owner = app.campaign:player(c.thread)
            label = label .. "  -  " .. owner.name .. "'s thread"
        end
        kit.text(x + 20, sy + 6, kit.ellipsize(label, "ui14", CARD_W - 96), "ui14", c and c.thread and kit.rgba("#6a4f8f") or theme.ink_dim)
        if c then
            local tag = util.int(prep:cost_of(c)) .. "h"
            if s.module then
                tag = s.module.swaps[kind] and "Yours" or "Book"     -- a published adventure (A13)
            end
            kit.text(x + CARD_W - 20, sy + 6, tag, "ui14", theme.ink_dim, { pivot = gui.PIVOT_NE })
            if prep.handouts and prep.handouts[c.id] then
                -- A handout's made for it: a little folded letter by the cost.
                local hx = x + CARD_W - 28 - kit.width(tag, "ui14") - 20
                kit.box(hx - 1, sy + 7, 20, 15, kit.rgba("#8a5a0e"), { radius = 2 })
                kit.box(hx + 1, sy + 9, 16, 11, theme.paper, { radius = 1 })
                kit.dot(hx + 9, sy + 15, 6, kit.rgba("#a8463a"))
            end
            kit.text(x + 20, sy + 25, c.name, "ui18b", theme.ink, { w = CARD_W - 40, lines = 2 })
        else
            kit.text(x + 20, sy + 30, "Empty: improvise it at the table", "ui14", kit.rgba("#9a8a72"))
        end
        until true
    end
end

local function pacing_panel(app, prep)
    local x, y, w, h = CARD_X, 566, 812, 104
    kit.box(x, y, w, h, theme.panel, { radius = 8 })
    kit.text(x + 14, y + 8, "PACING", "ui14", theme.dim)
    -- The table clock (A14): the board's rough length against the time you agreed on.
    do
        local est, plan = prep:estimate_minutes(), prep:planned_minutes()
        local function hm(m)
            local h, mm = math.floor(m / 60), math.floor(m % 60)
            return util.int(h) .. "h" .. (mm > 0 and (" " .. util.int(mm) .. "m") or "")
        end
        local over = est - plan
        -- Short enough to stay left of the notes column (x + 300).
        kit.text(x + 80, y + 8, kit.ellipsize("About " .. hm(est) .. " of your " .. hm(plan) .. ".", "ui14", 212), "ui14",
            over > 20 and theme.orange or theme.faint)
    end
    local pv = prep:pacing_now()
    -- The curve.
    local gx = { x + 40, x + 140, x + 240 }
    local function gy(t)
        return y + 88 - (math.max(t, 1) - 1) * 14
    end
    for k = 1, 5 do
        kit.box(x + 28, gy(k), 230, 1, kit.rgba("#ffffff", 0.06), { round = false })
    end
    local pts = {}
    for i, s in ipairs(prep.scenes) do
        if s.type then
            pts[i] = { gx[i], gy(pv.tensions[i]) }
        end
    end
    for i = 1, 2 do
        if pts[i] and pts[i + 1] then
            kit.line(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], 3, theme.dim)
        end
    end
    for i = 1, 3 do
        if pts[i] then
            kit.dot(pts[i][1], pts[i][2], 14, theme.scene[prep.scenes[i].type])
        end
        kit.text(gx[i], y + 92, util.int(i), "ui14", theme.faint, { pivot = gui.PIVOT_N })
    end
    -- Notes.
    local notes = {}
    for _, g in ipairs(pv.good or {}) do
        table.insert(notes, { g, theme.teal })
    end
    for _, wtext in ipairs(pv.warnings) do
        table.insert(notes, { wtext, theme.orange })
    end
    local sk = prep:sketched()
    if sk > 0 then
        table.insert(notes, { util.int(sk) .. (sk == 1 and " empty slot" or " empty slots") .. ": you'll improvise them at the table.", theme.dim })
    end
    -- The storylines (game/model/storylines.lua): too many at once, ones about to be dropped,
    -- loose ends wearing the table down, or simply which ones this week moves.
    for k, n in ipairs(M.storyline_notes(app, prep)) do
        table.insert(notes, k, n)
    end
    -- Session Zero: what's on the board that someone asked about.
    local board = {}
    for _, sc in ipairs(prep.scenes) do
        for _, c in pairs(sc.slots) do
            table.insert(board, c)
        end
    end
    for _, f in ipairs(social.content_flags(app.campaign, board)) do
        local p = app.campaign:player(f.key)
        if p.present then
            if f.kind == "line" then
                table.insert(notes, 1, { p.name .. " drew a line at this at Session Zero: " .. f.card.name .. ".", theme.red })
            elseif f.kind == "veil" then
                table.insert(notes, { "You'll keep the " .. f.tag .. " off screen for " .. p.name .. ".", theme.dim })
            else
                table.insert(notes, 1, { p.name .. " asked you about this at Session Zero: " .. f.card.name .. ".", theme.orange })
            end
        end
    end
    for _, st in ipairs(social.status(app.campaign)) do
        if st.state ~= "fixed" then
            table.insert(notes, 1, { st.text, st.state == "active" and theme.red or theme.orange })
        end
    end
    local lv = app.campaign:level_status()
    if lv.overdue then
        table.insert(notes, { "The party is overdue a level-up. Dev keeps asking.", theme.orange })
    end
    local ny = y + 10
    for _, n in ipairs(notes) do
        local hgt = kit.text_height(n[1], "ui14", 490)
        if ny + hgt > y + h - 4 then
            break
        end
        kit.dot(x + 300, ny + 9, 7, n[2])
        kit.text(x + 312, ny, n[1], "ui14", theme.text, { w = 490 })
        ny = ny + hgt + 2
    end
end

local function fit_text(c, scene_type)
    if not scene_type then
        return "Pick a scene type first", theme.ink_dim
    end
    if util.contains(c.fits, scene_type) then
        return "Fits " .. content.scenes[scene_type].name, kit.rgba("#2f6f68")
    end
    return "A stretch here", kit.rgba("#a0522d")
end

-- A short note about what just happened (or why it couldn't), as a pill on the drawer's top edge
-- so it never sits on top of the cards' own text (playtest, October 13).
function M.draw_toast(app, cx, y)
    if not app.toast then
        return
    end
    local text = app.toast
    -- A note (a story moved) in teal; why something couldn't happen in orange.
    local col = app.toast_tone == "info" and theme.teal or theme.orange
    app.toast, app.toast_tone = nil, nil
    local maxw = 780
    local tw = math.min(kit.width(text, "ui14"), maxw)
    local th = kit.text_height(text, "ui14", maxw)
    local bw, bh = tw + 32, th + 12
    kit.box(cx - bw / 2, y - bh / 2, bw, bh, theme.bg, { radius = bh / 2 })
    kit.box(cx - bw / 2, y - bh / 2, bw, 2, col, { round = false })
    kit.text(cx, y - bh / 2 + 6, text, "ui14", col, { pivot = gui.PIVOT_N, w = maxw })
end

local function drawer(app, prep)
    local x, y, w, h = CARD_X, 680, 812, 206
    kit.box(x, y, w, h, theme.panel, { radius = 8 })
    local sel = app.sel
    if not sel then
        if M.staged(app) then
            M.first_prep(app, prep, x, y)
        else
            M.inspiration(app, prep, x, y)
        end
        M.seeds(app, prep, x + 430, y)
        M.draw_toast(app, x + w / 2, y)
        return
    end
    local s = prep.scenes[sel.scene]
    if sel.kind == "type" then
        kit.text(x + 16, y + 12, "Stop " .. util.int(sel.scene) .. ": what kind of scene?", "ui18b", theme.text)
        -- What this campaign's style mostly plays (A18).
        -- What this campaign usually plays (A18): a gold corner on those types, named once here.
        local usual = {}
        do
            local sm = require "game.model.styles"
            local types = sm.usual_types(app.campaign, 3)
            for _, t in ipairs(types) do
                usual[t] = true
            end
            if #types > 0 then
                local q = kit.width("Stop 1: what kind of scene?", "ui18b") + 34
                kit.dot(x + q + 6, y + 23, 10, theme.gold)
                kit.text(x + q + 16, y + 15, kit.ellipsize("Usual in " .. sm.def(sm.current(app.campaign)).name, "ui14",
                    w - q - 366), "ui14", theme.faint)
            end
        end
        -- Or let the players choose (A15).
        kit.button(x + w - 330, y + 8, 314, 30, s.open and "Open scene: the players choose (on)" or "Or let the players choose: Open scene",
            function()
                prep:set_open(sel.scene, not s.open)
                app.sel = s.open and { scene = sel.scene, kind = "location" } or { scene = sel.scene, kind = "type" }
                app.loc_tab = (s.open and #prep:spot_suggestions(sel.scene) > 0) and "suggested" or nil
                app.refresh()
            end, { font = "ui14", color = s.open and theme.decision.agency or theme.panel2, key = "open_scene" })
        local cw = 105
        for k, key in ipairs(content.scenes.order) do
            local st = content.scenes[key]
            local cx = x + 14 + (k - 1) * (cw + 8)
            local cy = y + 42
            local chosen = s.type == key and not s.open
            if chosen then
                kit.box(cx - 3, cy - 3, cw + 6, 156, theme.select, { radius = 9 })
            end
            kit.button(cx, cy, cw, 150, "", function()
                if s.open then
                    prep:set_open(sel.scene, false)
                end
                if s.module then
                    prep:clear_module(sel.scene)
                end
                prep:set_type(sel.scene, key)
                -- Move on to the first empty slot.
                app.sel = { scene = sel.scene, kind = "location" }
                for _, kind in ipairs(content.kinds) do
                    if not s.slots[kind] then
                        app.sel.kind = kind
                        break
                    end
                end
                app.refresh()
            end, { color = theme.scene[key], hover = theme.button_hover })
            kit.text(cx + 8, cy + 8, st.name, "ui18b", theme.text, { w = cw - 12 })
            for d = 1, 5 do
                kit.dot(cx + 12 + (d - 1) * 11, cy + 38, 8, d <= st.tension and theme.text or kit.rgba("#000000", 0.25))
            end
            gloss.card_spot(cx + 6, cy + 32, 5 * 11 + 8, 14, "Tension",
                "How intense this kind of scene runs, from 1 (calm) to 5 (edge of their seats).")
            kit.text(cx + 8, cy + 50, st.short or st.blurb, "ui14", theme.text, { w = cw - 14 })
            faces(app, cx + 6, cy + 120, type_leans(app, key), 18)
            if usual[key] then
                kit.dot(cx + cw - 12, cy + 138, 10, theme.gold)
            end
        end
        -- Published adventures from your books (A13): the whole scene, ready to run.
        local mods = books_mod.modules(app.campaign)
        if #mods > 0 or s.module then
            local my = y + 204
            kit.text(x + 16, my + 8, "OR RUN A PUBLISHED ADVENTURE", "ui14", theme.gold)
            local mx = x + 16 + kit.width("OR RUN A PUBLISHED ADVENTURE", "ui14") + 16
            for _, mid in ipairs(mods) do
                local m = books_mod.module(mid)
                local label = m.name .. "  " .. util.int(content.books.MODULE_COST) .. "h"
                local on = s.module and s.module.id == mid
                local ok, why = prep:can_place_module(sel.scene, mid)
                local bw = kit.width(label, "ui14") + 28
                kit.button(mx, my, bw, 32, label, function()
                    if on then
                        prep:clear_module(sel.scene)
                    else
                        local placed, why2 = prep:place_module(sel.scene, mid)
                        if not placed then
                            app.toast = why2
                        end
                    end
                    app.refresh()
                end, { font = "ui14", color = on and theme.go or theme.decision.agency, hover = theme.button_hover,
                       enabled = ok or on, key = "module_" .. mid })
                mx = mx + bw + 8
            end
            kit.text(x + 16, my + 44, "Everything in one: place, person, goal, twist, reward and the fight, instead of 6 to 8 hours of cards. "
                .. "Swap its reward or recast its person to tie it to your campaign.", "ui14", theme.faint, { w = w - 32 })
        end
        return
    end
    local kind = sel.kind
    local current = s.slots[kind]
    if s.module then
        M.module_drawer(app, prep, s, sel, kind)
        return
    end
    M.hand_drawer(app, prep, s, sel, kind, current)
end

local HAND_X, HAND_Y, HAND_W, HAND_H = CARD_X, 566, 812, 320

-- A published adventure's slot (A13): its reward and its person can be made yours, the rest is
-- the book's.
function M.module_drawer(app, prep, s, sel, kind)
    local x, y, w, h = HAND_X, HAND_Y, HAND_W, HAND_H
    local m = books_mod.module(s.module.id)
    local bk = books_mod.book(m.book)
    kit.box(x, y, w, h, theme.panel, { radius = 8 })
    kit.text(x + 16, y + 12, "Stop " .. util.int(sel.scene) .. ": " .. m.name .. ", from " .. bk.name, "ui18b", theme.text,
        { w = w - 260, lines = 1 })
    kit.button(x + w - 122, y + 8, 106, 28, "Close", function()
        app.sel = nil
        app.refresh()
    end, { font = "ui14", key = "hand_close" })
    local c = s.slots[kind]
    local book_card = content.components[m.cards[kind] and m.cards[kind].id or ""]
    local swapped = s.module.swaps[kind]
    local ty = y + 48
    if c then
        kit.text(x + 16, ty, (swapped and "Yours: " or "From the book: ") .. c.name, "ui18b", swapped and theme.teal or theme.gold)
        ty = ty + 26
        kit.text(x + 16, ty, c.line or "", "ui14", theme.dim, { w = w - 32, lines = 2 })
        ty = ty + 44
    end
    if kind ~= "reward" and kind ~= "cast" then
        kit.text(x + 16, ty, "This part comes from the book. Swap the reward or recast the person to make the scene yours.", "ui18",
            theme.faint, { w = w - 32 })
        return
    end
    if swapped then
        kit.button(x + 16, ty, 300, 32, "Put the book's " .. (kind == "cast" and "person" or "reward") .. " back", function()
            prep:unswap(sel.scene, kind)
            app.refresh()
        end, { font = "ui14", key = "unswap_" .. kind })
        ty = ty + 40
    end
    local options = {}
    if kind == "cast" then
        kit.text(x + 16, ty, "Recast " .. (book_card and book_card.name or "them") .. " with someone the party knows ("
            .. util.int(content.books.SWAP_COST) .. "h). Then what happens goes in your notebook.", "ui14", theme.text, { w = w - 32 })
        for _, o in ipairs(prep:recast_options(sel.scene)) do
            table.insert(options, o.card)
        end
    else
        kit.text(x + 16, ty, "Swap the book's reward for one of yours (" .. util.int(content.books.SWAP_COST)
            .. "h). Then it can move someone's story.", "ui14", theme.text, { w = w - 32 })
        for _, card in ipairs(prep.hand.reward or {}) do
            if prep:can_swap(sel.scene, card.id) then
                table.insert(options, card)
            end
        end
    end
    ty = ty + 26
    if #options == 0 then
        kit.text(x + 16, ty, kind == "cast" and "Nobody from your notebook fits yet." or "No rewards in your hand to swap in.", "ui18",
            theme.faint)
        return
    end
    local bw = (w - 32 - 16) / 3
    for k, card in ipairs(options) do
        if k > 9 then
            break
        end
        local col, row = (k - 1) % 3, math.floor((k - 1) / 3)
        kit.button(x + 16 + col * (bw + 8), ty + row * 38, bw, 32, kit.ellipsize(card.name, "ui14", bw - 16), function()
            local ok, why = prep:swap(sel.scene, card.id)
            if not ok then
                app.toast = why
            end
            app.refresh()
        end, { font = "ui14", color = theme.paper, text_color = theme.ink, hover = kit.rgba("#fff6e0"), key = "swap_" .. card.id })
    end
end

-- The hand when a slot is picked (the slice rework): every card of the kind on one page, two
-- rows of five, over the pacing panel. Pins first, with why; then new cards, then the rest.
-- A card on another scene is dimmed and says where; moving it asks first. The x shelves a card.
local HCW, HCH = 150, 128

-- A margin note in the DM's handwriting, a little smaller than the font's size.
local NOTE_SCALE = 0.72
local function hand_note(x, y, text, w, color)
    kit.text(x, y, text, "hand24", color, { w = w / NOTE_SCALE, scale = NOTE_SCALE })
    return kit.text_height(text, "hand24", w / NOTE_SCALE) * NOTE_SCALE
end

-- The badge under a card's name: why it's in the hand.
local function badge(app, prep, c, at, sel)
    local camp = app.campaign
    local pin = prep.pins and prep.pins[c.id]
    if at and at ~= sel.scene and c.kind == "location" then
        return "Also stop " .. util.int(at) .. " (no extra time)", kit.rgba("#2f5f8a")
    elseif at and at ~= sel.scene then
        return "On stop " .. util.int(at), theme.ink_dim
    elseif pin then
        local tag = pin.why == "spotlight" and "Spotlight" or (pin.why == "screen" and "Off screen, now on"
            or (pin.why == "course" and "Change course" or "Brought in"))
        return tag, kit.rgba("#8a5a0e")
    elseif prep.arc_cards[c.id] then
        return "Story card", kit.rgba("#8a5a0e")
    elseif prep.payoffs[c.id] then
        return "Pays off a seed", kit.rgba("#2f6f3a")
    elseif deck.is_new(camp, c.id) then
        local from = deck.follows(camp, c.id)
        local e = deck.entry(camp, c.id)
        if e and e.from and string.sub(e.from, 1, 6) == "world:" then
            return "New: from off screen", kit.rgba("#2f6f3a")
        end
        if e and e.from and string.sub(e.from, 1, 5) == "book:" then
            return "New: from a book", kit.rgba("#2f6f3a")
        end
        return from and "New: follows" or "New", kit.rgba("#2f6f3a")
    elseif prep.inspired[c.id] then
        return "Inspired", kit.rgba("#2f6f3a")
    elseif c.thread then
        return camp:player(c.thread).name .. "'s past", kit.rgba("#6a4f8f")
    elseif c.book then
        return "From a book", kit.rgba("#2f5f8a")
    end
    return nil
end

-- Green and red dots for who'd enjoy it (no faces: hover says who).
local function lean_dots(app, x, y, leans)
    local dx = x
    for _, want in ipairs({ 1, -1 }) do
        for _, p in ipairs(app.campaign.players) do
            if leans[p.key] == want then
                kit.dot(dx + 6, y + 6, 11, want > 0 and theme.green or theme.red)
                dx = dx + 15
            end
        end
    end
end

-- New cards of a kind you haven't looked at yet this week.
function M.new_in_hand(app, prep, kind)
    if prep.seen_kinds and prep.seen_kinds[kind] then
        return 0
    end
    local n = 0
    for _, c in ipairs(prep.hand[kind] or {}) do
        if deck.is_new(app.campaign, c.id) then
            n = n + 1
        end
    end
    return n
end

function M.hand_drawer(app, prep, s, sel, kind, current)
    local x, y, w, h = HAND_X, HAND_Y, HAND_W, HAND_H
    prep.seen_kinds = prep.seen_kinds or {}
    prep.seen_kinds[kind] = true
    kit.box(x, y, w, h, theme.panel, { radius = 8 })
    local open = s.open and kind == "location"
    local title = open and ("Stop " .. util.int(sel.scene) .. ": spots (" .. util.int(#s.spots) .. " of "
        .. util.int(content.open_scenes.SPOTS) .. ")") or ("Stop " .. util.int(sel.scene) .. ": choose a " .. string.lower(content.kind_names[kind]))
    kit.text(x + 16, y + 12, title, "ui18b", theme.text)
    -- Places: the hand, Your places (free, no card needed), and for open scenes, suggestions (A15).
    local tab = "hand"
    if kind == "location" then
        tab = app.loc_tab or "hand"
        local known = places_mod.list(app.campaign)
        local tabs = { { "hand", "Hand" }, { "places", "Your places (" .. util.int(#known) .. ")" } }
        if open then
            table.insert(tabs, { "suggested", "Suggested (" .. util.int(#prep:spot_suggestions(sel.scene)) .. ")" })
        end
        local tx = x + 16 + kit.width(title, "ui18b") + 16
        for _, t in ipairs(tabs) do
            local tw = kit.width(t[2], "ui14") + 20
            kit.button(tx, y + 8, tw, 28, t[2], function()
                app.loc_tab = t[1]
                app.refresh()
            end, { font = "ui14", color = tab == t[1] and theme.go or theme.panel2, key = "loc_tab_" .. t[1] })
            tx = tx + tw + 6
        end
    end
    if current then
        kit.button(x + w - 236, y + 8, 104, 28, "Remove", function()
            prep:clear(sel.scene, kind)
            app.refresh()
        end, { font = "ui14", key = "slot_remove" })
        -- A handout for it (game/model/handouts.lua): an hour making the real thing.
        local handouts = require "game.model.handouts"
        if handouts.worth_it(app.campaign, current) then
            local made = prep.handouts and prep.handouts[current.id]
            kit.button(x + w - 400, y + 8, 156, 28, made and "Handout made" or ("Make a handout  " .. util.int(handouts.data.COST) .. "h"),
                function()
                    local ok, why = handouts.toggle(prep, current.id)
                    if not ok then
                        app.toast = why
                    end
                    app.refresh()
                end, { font = "ui14", color = made and theme.go or theme.button, key = "handout_toggle",
                       enabled = made or (handouts.count(prep) < handouts.data.PER_WEEK and prep:left() >= handouts.data.COST) })
        end
    end
    kit.button(x + w - 122, y + 8, 106, 28, "Close", function()
        app.sel = nil
        app.refresh()
    end, { font = "ui14", key = "hand_close" })
    local hand = prep.hand[kind]
    local reasons = {}
    if tab == "places" then
        hand = {}
        for _, pl in ipairs(places_mod.list(app.campaign)) do
            table.insert(hand, pl.card)
        end
    elseif tab == "suggested" then
        hand = {}
        for _, sg in ipairs(prep:spot_suggestions(sel.scene)) do
            table.insert(hand, content.components[sg.id])
            reasons[sg.id] = sg.why
        end
    end
    local n = math.min(#hand, prep_mod.PAGE or 10)
    if #hand == 0 then
        kit.text(x + 16, y + 52, tab == "places" and "No places of your own yet. Any place you prep becomes yours, free to use again."
            or (tab == "suggested" and "Nothing from your notes yet. Sketch spots from your hand."
            or "No cards of this kind this week. Leave it empty and improvise it at the table."), "ui18",
            theme.faint, { w = w - 32 })
    end
    for k = 1, n do
        local c = hand[k]
        local col, row = (k - 1) % 5, math.floor((k - 1) / 5)
        local cx = x + 14 + col * (HCW + 8)
        local cy = y + 44 + row * (HCH + 8)
        local here = current and current.id == c.id
        local at = prep:placed_at(c.id)
        if kind == "location" and at == sel.scene then
            -- A place on several scenes: say where else it's used.
            for _, j in ipairs(prep:placed_all(c.id)) do
                if j ~= sel.scene then
                    at = j
                    break
                end
            end
        end
        local shared = kind == "location" and at and at ~= sel.scene
        local elsewhere = at and at ~= sel.scene and not shared
        local ok, why = prep:can_place(sel.scene, c.id)
        local spot = open and util.contains(s.spots, c.id)
        if open then
            ok, why = prep:can_add_spot(sel.scene, c.id)
            ok = ok or spot
            elsewhere = false
            here = spot
        end
        if here then
            kit.box(cx - 3, cy - 3, HCW + 6, HCH + 6, theme.select, { radius = 9 })
        end
        local function place_it()
            local placed, why2 = prep:place(sel.scene, c.id)
            if placed then
                -- A card that moves a storyline opens its Story log beside the board.
                require("game.ui.story_log_view").on_placed(app, c)
                for _, k2 in ipairs(content.kinds) do
                    if not s.slots[k2] then
                        app.sel = { scene = sel.scene, kind = k2 }
                        break
                    end
                end
            else
                app.toast = why2
            end
            app.refresh()
        end
        kit.button(cx, cy, HCW, HCH, "", function()
            if open then
                -- An open scene's spots: click to sketch it, click again to take it out.
                if spot then
                    prep:remove_spot(sel.scene, c.id)
                else
                    local added, why2 = prep:add_spot(sel.scene, c.id)
                    if not added then
                        app.toast = why2
                    end
                end
                app.refresh()
                return
            end
            if here then
                return
            end
            if kind == "cast" and prep:cast_would_lead(sel.scene, c) then
                -- Cast and fight stay in sync (A7): ask before they take over a fight you built.
                local fam = content.encounters.by_cast[c.id]
                ask_view.ask(app, { title = "They lead the fight?", text = "You built stop " .. util.int(sel.scene)
                    .. "'s fight yourself. Cast \"" .. c.name .. "\" and " .. fam.name .. " leads it, with the rest of your monsters.",
                    yes = "Cast them", no = "Leave it", on_yes = function()
                        local placed = prep:place(sel.scene, c.id)
                        if placed then
                            prep:cast_leads(sel.scene)
                            require("game.ui.story_log_view").on_placed(app, c)
                        end
                        app.refresh()
                    end })
                return
            end
            if elsewhere then
                ask_view.ask(app, { title = "Move this card?", text = "\"" .. c.name .. "\" is already on stop " .. util.int(at)
                    .. ". Move it to stop " .. util.int(sel.scene) .. "? Stop " .. util.int(at) .. " will have to improvise it.",
                    yes = "Move it", no = "Leave it", on_yes = place_it })
                return
            end
            place_it()
        end, { color = elsewhere and theme.paper_dim or theme.paper, hover = kit.rgba("#fff6e0"), enabled = ok or here,
               key = "hand_" .. c.id,
               on_hover = function(_, on)
                   drop_hover(app)
                   if on then
                       card_detail(app, prep, c, s, cx + HCW / 2, (not ok and not here) and why or nil)
                   end
               end })
        local ink = (ok or here) and (elsewhere and theme.ink_dim or theme.ink) or theme.ink_dim
        local nw = HCW - 34
        local nfont = kit.text_height(c.name, "ui18b", nw) <= 44 and "ui18b" or "ui14"
        kit.text(cx + 10, cy + 6, c.name, nfont, ink, { w = nw })
        local ty = cy + 8 + kit.text_height(c.name, nfont, nw)
        -- Cost, and why it's in the hand.
        local hrs = prep:cost_of(c)
        if open then
            hrs = hrs > 0 and content.open_scenes.SPOT_COST or 0
        end
        local cost = util.int(hrs) .. "h"
        kit.text(cx + 10, ty, cost, "ui14", theme.ink_dim)
        local btext, bcol = badge(app, prep, c, at, sel)
        if reasons[c.id] then
            btext, bcol = reasons[c.id], kit.rgba("#2f6f5a")
        elseif open and spot then
            btext, bcol = (s.spots[1] == c.id) and "Spot 1: your hook waits here" or "A spot", kit.rgba("#2f6f5a")
        elseif kind == "location" and places_mod.is_known(app.campaign, c.id) and not (at and at ~= sel.scene) then
            btext, bcol = "Your place: free", kit.rgba("#2f6f5a")
        end
        local flags = social.content_flags(app.campaign, { c })
        local flag = flags[1]
        if flag and app.campaign:player(flag.key).present then
            local who = app.campaign:player(flag.key).name
            btext = flag.kind == "line" and (who .. "'s line!") or (flag.kind == "veil" and (who .. ": off screen") or (who .. " asked..."))
            bcol = flag.kind == "veil" and theme.ink_dim or kit.rgba("#a0322d")
        end
        if btext then
            kit.text(cx + 40, ty, btext, "ui14", bcol, { w = HCW - 50 })
            ty = ty + kit.text_height(btext, "ui14", HCW - 50)
        else
            ty = ty + 18
        end
        -- The DM's margin note: how it sits on this scene.
        local note, ncol
        if why and string.find(why, "can't happen", 1, true) then
            note, ncol = "can't happen here", kit.rgba("#a0322d")
        elseif why and string.find(why, "\" happens at ", 1, true) then
            -- Tied to another place: say so before the click, not after (playtest, October 13).
            note, ncol = "belongs elsewhere", kit.rgba("#a0322d")
        else
            local _, aff = content.affinity(c, s.slots, s.type)
            -- "odd here?" only once the scene has somewhere (or someone) to be odd against.
            local others = false
            for k2, o in pairs(s.slots) do
                others = others or (o.id ~= c.id and k2 ~= kind)
            end
            if aff == "odd here?" and not others then
                aff = nil
            end
            note = aff
            ncol = (aff == "odd here?") and kit.rgba("#a0522d") or kit.rgba("#2f5f8a")
        end
        local bottom = cy + HCH - 18
        if note and ty + 4 + kit.text_height(note, "hand24", (HCW - 20) / NOTE_SCALE) * NOTE_SCALE <= bottom then
            hand_note(cx + 10, ty + 2, note, HCW - 20, ncol)
        end
        lean_dots(app, cx + 8, cy + HCH - 18, card_leans(app, c))
        M.card_storylines(app, c, cx + HCW - 8, cy + HCH - 18)
        -- Shelve it: the x in the corner (not for pins, story cards or cards on the board).
        if not at and not (prep.pins and prep.pins[c.id]) and deck.can_shelve(app.campaign, c.id) then
            kit.button(cx + HCW - 24, cy + 4, 20, 20, "x", function()
                local done, why3 = prep:shelve(c.id)
                if not done then
                    app.toast = why3
                else
                    app.toast = "Shelved \"" .. c.name .. "\". Bring it back from Campaign in your notes."
                end
                drop_hover(app)
                app.refresh()
            end, { font = "ui14", color = kit.rgba("#000000", 0.12), hover = kit.rgba("#a0322d", 0.6),
                   text_color = theme.ink_dim, radius = 4, key = "shelve_" .. c.id })
        end
    end
    M.draw_toast(app, x + w / 2, y)
end

-- Things still waiting on you this week: the check before game night (the slice rework).
function M.attention(app)
    local c = app.campaign
    local items = {}
    local unread = messages_view.unread(app)
    if unread > 0 then
        table.insert(items, util.int(unread) .. (unread == 1 and " message you haven't opened." or " messages you haven't opened."))
    end
    local theories = messages_view.unanswered(app)
    if theories > 0 then
        table.insert(items, theories == 1 and "A theory in the group chat you haven't answered."
            or (util.int(theories) .. " theories in the group chat you haven't answered."))
    end
    local moves = M.staged(app) and 0 or world.pending(c)
    if moves > 0 then
        table.insert(items, util.int(moves) .. (moves == 1 and " faction move" or " faction moves")
            .. " you haven't decided (This week, in your notes). They'll play out on their own.")
    end
    local lv = c:level_status()
    if lv.ready then
        table.insert(items, "The party can level up.")
    end
    -- A pull you parked, due tonight and not on the route (game/model/pulls.lua): it sours.
    for _, o in ipairs(require("game.model.pulls").open_owed(c)) do
        if o.due <= (c.week or 1) then
            local on = false
            for _, s in ipairs(c.prep.scenes) do
                for _, card in pairs(s.slots or {}) do
                    if card.id == o.id or card.id == o.place or card.id == o.card then
                        on = true
                    end
                end
            end
            local p = c:player(o.key)
            if not on and p then
                table.insert(items, "You owe " .. p.name .. " " .. o.name .. ", parked in session " .. util.int(o.week)
                    .. ". It isn't on tonight's route, and after tonight it sours.")
            end
        end
    end
    return items
end

function M.run_night(app)
    local prep = app.campaign.prep
    if not prep:ready() then
        return
    end
    local items = M.attention(app)
    if #items == 0 then
        app.go("night")
        return
    end
    ask_view.ask(app, { title = "Are you sure?", text = "There's still something you could do this week:", items = items,
        yes = "Run game night", no = "Go back", on_yes = function()
            app.go("night")
        end })
end

-- One long-term bar as the DM reads it: icon, name, fill (or band), trend arrow.
local function long_bar(app, p, idx, key, bx, by)
    local level = app.campaign:empathy()
    local read = empathy.long(level, p, key, app.campaign.week, idx)
    local color = theme.long[key]
    kit.icon(bx, by - 4, 16, key, color)
    kit.text(bx + 21, by - 4, score.LONG_NAMES[key], "ui14", theme.dim)
    if read.lo then
        kit.bar(bx + 112, by, 52, 9, 0, 100, color, { range = { read.lo, read.hi } })
    else
        kit.bar(bx + 112, by, 52, 9, read.fill, 100, color)
    end
    if read.arrow then
        local good = (read.arrow == "up") ~= (key == "suspicion")
        kit.icon(bx + 168, by - 2, 12, read.arrow, good and theme.green or theme.red)
    end
end

local WARNINGS = {
    wavering = "Said in the chat they're losing steam.",
    drifting = "Seems to be drifting away lately.",
}

-- The one-line version of a player's notes, for a card that also shows a warning or a feud.
local function short_notes(p)
    local d = content.players[p.key]
    return d and d.short or p.notes
end

-- Goodwill (game/model/keepsakes.lua): a heart that fills with every good night, never a number.
-- Full, and they bring you something as they pack up. Hover for what it is.
function M.goodwill(app, p, gx, gy)
    local keepsakes = require "game.model.keepsakes"
    local gw = keepsakes.goodwill(app.campaign, p.key)
    local fill = math.min(1, gw / keepsakes.data.FULL)
    kit.text(gx, gy, "Goodwill", "ui14", theme.dim)
    -- The heart: a faint one, and a warm one inside it growing from the middle as it fills.
    local hx, hy, size = gx + 66, gy - 3, 22
    kit.icon(hx, hy, size, "heart", theme.panel3)
    if fill > 0 then
        local s = math.floor(6 + (size - 6) * fill + 0.5)
        kit.icon(hx + (size - s) / 2, hy + (size - s) / 2, s, "heart", theme.heart)
    end
    kit.button(gx - 4, gy - 5, 98, 26, "", nil, { color = kit.rgba("#000000", 0), hover = kit.rgba("#ffffff", 0.05),
        key = "goodwill_" .. p.key,
        on_hover = function(_, on)
            drop_hover(app)
            if on then
                M.goodwill_hover(app, p, gw, gx, gy)
            end
        end })
end

function M.goodwill_hover(app, p, gw, x0, y0)
    local keepsakes = require "game.model.keepsakes"
    local lines = { "Every good night fills it, and their own story moving fills it more. A moment that's all "
        .. "theirs, or dice from you, fills it a lot." }
    local got = keepsakes.from(app.campaign, p.key)
    if #got > 0 then
        local def = keepsakes.def(got[#got].id)
        table.insert(lines, "They gave you " .. def.name .. " in session " .. util.int(got[#got].week) .. ".")
    else
        table.insert(lines, "When it's full, they'll bring you something as they pack up.")
    end
    local w = 360
    local h = 46
    for _, r in ipairs(lines) do
        h = h + kit.text_height(r, "ui14", w - 32) + 6
    end
    -- Beside the player's card, not over it (the newcomer playtest, October 16: it covered their
    -- Mood line). The heart sits 262 in from the card's left edge.
    local x = util.clamp(x0 - 262 - w - 14, 8, kit.W - w - 8)
    local y = util.clamp(y0 - 16, 8, kit.H - h - 8)
    local l = kit.layer("prep_hover")
    app.hover_layer = l
    kit.box(x - 2, y - 2, w + 4, h + 4, theme.heart, { radius = 12 })
    kit.box(x, y, w, h, kit.rgba("#201813", 0.98), { radius = 11 })
    kit.text(x + 16, y + 12, p.name .. "'s heart is " .. keepsakes.heart_words(gw) .. ".", "ui18b", theme.heart, { w = w - 32 })
    local ry = y + 42
    for _, r in ipairs(lines) do
        kit.text(x + 16, ry, r, "ui14", theme.dim, { w = w - 32 })
        ry = ry + kit.text_height(r, "ui14", w - 32) + 6
    end
end

-- Storylines on the prep board ----------------------------------------------------------------

local function storyline_color(d)
    return kit.rgba(d.color or "#e8b04a")
end

-- A pip per storyline this scene's cards move, with a hover that names them and how they stand.
function M.scene_storylines(app, prep, s, x, y, most)
    local storylines = require "game.model.storylines"
    local ids, seen = {}, {}
    for _, kind in ipairs(content.kinds) do
        local c = s.slots[kind]
        local of = c and storylines.of_card(app.campaign, c) or {}
        if c and #of == 0 and prep.arc_cards and prep.arc_cards[c.id] then
            of = { content.lore.briefing.next_story }   -- a story card that's no storyline's own
        end
        for _, id in ipairs(of) do
            if not seen[id] then
                seen[id] = true
                table.insert(ids, id)
            end
        end
    end
    if #ids == 0 then
        return
    end
    -- Each storyline's own icon (October 15): the bell, the wolf, the hand, a hero's face.
    local defs = {}
    local marks = require "game.ui.lore_marks"
    for k, id in ipairs(ids) do
        local d = storylines.def(app.campaign, id)
        if d and k <= (most or 6) then
            table.insert(defs, d)
            if not marks.storyline(app, id, x - 6 + (k - 1) * 17, y - 8, 16, true) then
                kit.dot(x + (k - 1) * 17, y, 10, storyline_color(d))
            end
        end
    end
    kit.button(x - 6, y - 9, math.max(24, #defs * 17 + 6), 18, "", function()
        -- Click for their Story log.
        drop_hover(app)
        require("game.ui.story_log_view").open_panel(app, ids)
        app.refresh()
    end, {
        color = kit.rgba("#000000", 0), hover = kit.rgba("#000000", 0.08), key = "scene_storylines_" .. tostring(s.index or x),
        on_hover = function(_, on)
            drop_hover(app)
            local slv = require "game.ui.story_log_view"
            slv.drop_hover(app)
            if on then
                -- Each storyline at a glance, and a click opens its Story log.
                local list = {}
                for _, d in ipairs(defs) do
                    table.insert(list, d.id)
                end
                slv.show_glance(app, list, x, y + 14, "Click for the Story log.")
            end
        end })
end

-- A hand card's storylines, bottom right of the tile: the first by name, the rest as pips.
function M.card_storylines(app, c, right, y)
    local storylines = require "game.model.storylines"
    local defs = {}
    for _, id in ipairs(storylines.of_card(app.campaign, c)) do
        local d = storylines.def(app.campaign, id)
        if d and d.kind ~= "backstory" then      -- (the badge already says whose past it is)
            table.insert(defs, d)
        end
    end
    -- This week's story cards that aren't any storyline's own (the Kettle, Gus, the chapel) move
    -- the main story: they wear its bell too (October 15).
    local prep = app.campaign.prep
    if #defs == 0 and prep and prep.arc_cards and prep.arc_cards[c.id] then
        local d = storylines.def(app.campaign, content.lore.briefing.next_story)
        if d then
            table.insert(defs, d)
        end
    end
    if #defs == 0 then
        return
    end
    -- Each storyline's icon, the first one named (October 15: the same icon as the opening).
    local marks = require "game.ui.lore_marks"
    local x = right
    for k = #defs, 2, -1 do
        x = x - 15
        marks.storyline(app, defs[k].id, x, y - 1, 14, true)
    end
    local name = kit.ellipsize(defs[1].short, "ui14", 70)
    local nw = kit.width(name, "ui14")
    x = x - nw - 2
    -- Darker on the card's paper, so it reads.
    local col = storyline_color(defs[1])
    kit.text(x, y - 2, name, "ui14", vmath.vector4(col.x * 0.6, col.y * 0.6, col.z * 0.6, 1))
    marks.storyline(app, defs[1].id, x - 17, y - 1, 15, true)
end

-- The pacing panel's storyline notes, most urgent first.
function M.storyline_notes(app, prep)
    local storylines = require "game.model.storylines"
    local f = storylines.forecast(app.campaign, prep)
    local out = {}
    local function names(list)
        local n = {}
        for _, d in ipairs(list) do
            table.insert(n, d.kind == "backstory" and (d.short .. "'s story") or util.lower_first(d.short))
        end
        return util.join_names(n)
    end
    if f.thin then
        table.insert(out, { util.int(#f.touched) .. " storylines on the board. Too many for the table to follow in one night.",
                            theme.orange })
    end
    if #f.loose > 0 then
        table.insert(out, { (#f.loose > 1 and "Loose ends: " or "Loose end: ") .. names(f.loose)
            .. (#f.loose > 1 and ". They wear the table down every week until they come back." or ". It wears the table down every week until it comes back."),
                            theme.red })
    end
    if #f.cold > 0 then
        table.insert(out, { "Going cold: " .. names(f.cold) .. ". Leave it this week and the table notices.", theme.orange })
    end
    if #out == 0 then
        if #f.touched > 0 then
            table.insert(out, { "Storylines this week: " .. names(f.touched) .. ".", theme.teal })
        else
            table.insert(out, { "No storyline moves this week.", theme.dim })
        end
    end
    return out
end

local function player_card(app, prep, p, i, forecast)
    local x, w = 1196, 380
    local y = 106 + (i - 1) * 196
    local h = 186
    local level = app.campaign:empathy()
    kit.box(x, y, w, h, theme.panel, { radius = 10 })
    -- Their face and name: click for the character sheet.
    kit.button(x + 6, y + 4, 262, 38, "", function()
        if app.open_sheet then
            app.open_sheet(p.key)
        end
    end, { color = theme.panel, hover = theme.panel2, radius = 8, key = "sheet_" .. p.key })
    kit.dot(x + 29, y + 23, 34, panels.COLORS[p.key] or theme.panel3)
    kit.picture(x + 13, y + 7, 32, 32, panels.face(p.key))
    kit.text(x + 52, y + 10, p.name, "ui22b", theme.text)
    local who = p.char .. ", " .. p.class_name
    local room = 262 - 52 - kit.width(p.name, "ui22b") - 10
    if kit.width(who, "ui18") > room then
        who = (string.match(p.char, "^(%S+)") or p.char) .. ", " .. p.class_name     -- a long name: first name
    end
    kit.text(x + 52 + kit.width(p.name, "ui22b") + 10, y + 14, kit.ellipsize(who, "ui18", room), "ui18", theme.dim)
    if p.on_break then
        local talked = prep.talked[p.key]
        kit.button(x + w - 128, y + 10, 114, 30, talked and "Checked in" or "Check in  2h", function()
            if prep:talk(p.key) then
                app.refresh()
            end
        end, { font = "ui14", enabled = (not talked) and prep:can_talk(p.key) })
        kit.icon(x + 14, y + 48, 18, "warn", theme.orange)
        kit.text(x + 40, y + 47, "Taking a break from Thursdays.", "ui18", theme.orange)
        kit.text(x + 14, y + 76, talked and "You checked in. They'll be back sooner, and they know they're missed."
            or "A one-on-one check-in brings them back sooner. They'll return either way.", "ui14", theme.dim,
            { w = w - 28, lines = 2 })
    elseif not p.present then
        kit.text(x + 14, y + 48, "Can't make it this week.", "ui18", theme.orange)
        local warn = empathy.warning(level, p)
        if warn and WARNINGS[warn] then
            kit.icon(x + 14, y + 76, 16, "warn", theme.orange)
            kit.text(x + 36, y + 74, WARNINGS[warn], "ui14", theme.orange, { w = w - 50, lines = 1 })
        else
            kit.text(x + 14, y + 74, p.notes, "ui14", theme.faint, { w = w - 28, lines = 2 })
        end
    else
        local talked = prep.talked[p.key]
        if not M.staged(app) then
            kit.button(x + w - 108, y + 10, 94, 30, talked and "Talked" or "Talk  2h", function()
                talk_view.open(app, p.key)
            end, { font = "ui14", enabled = (not talked) and prep:can_talk(p.key), key = "talk_" .. p.key })
        end
        local warn = empathy.warning(level, p)
        local feud = M.feud_line(app, p)
        -- What a one-on-one told you (A6) takes the notes line.
        local learned = one_on_one.summary(prep.talk_notes and prep.talk_notes[p.key])
        if learned then
            kit.text(x + 14, y + 44, learned, "ui14", theme.teal, { w = w - 28, lines = 2 })
        elseif warn and WARNINGS[warn] then
            kit.icon(x + 14, y + 46, 16, "warn", theme.orange)
            kit.text(x + 36, y + 44, WARNINGS[warn], "ui14", theme.orange, { w = w - 50, lines = 1 })
            kit.text(x + 14, y + 64, feud or short_notes(p), "ui14", feud and theme.orange or theme.dim, { w = w - 28, lines = 1 })
        elseif feud then
            kit.text(x + 14, y + 44, feud, "ui14", theme.orange, { w = w - 28, lines = 1 })
            kit.text(x + 14, y + 64, short_notes(p), "ui14", theme.dim, { w = w - 28, lines = 1 })
        else
            kit.text(x + 14, y + 44, p.notes, "ui14", theme.dim, { w = w - 28, lines = 2 })
        end
        local mood = score.mood(p)
        kit.icon(x + 14, y + 87, 14, "mood", p.mood_known and theme.gold or theme.faint)
        local mood_text = p.mood_known and ("Mood this week: " .. mood.name) or "Mood this week: ?"
        kit.text(x + 34, y + 86, mood_text, "ui14", p.mood_known and theme.text or theme.faint)
        gloss.card_spot(x + 10, y + 82, kit.width(mood_text, "ui14") + 28, 22, "Mood this week",
            p.mood_known and ("How " .. p.name .. "'s week has gone, outside the game. It changes how they'll take Thursday.")
            or ("How " .. p.name .. "'s week has gone, outside the game: you don't know yet. A one-on-one (Talk) finds out."))
        M.goodwill(app, p, x + 262, y + 86)
        -- Forecast for Thursday, from the board as it stands.
        kit.text(x + 14, y + 108, "Thursday", "ui14", theme.dim)
        local f = forecast[p.key]
        if f then
            -- Hover for why (A6).
            kit.button(x + 8, y + 102, w - 16, 26, "", nil, { color = kit.rgba("#000000", 0), hover = kit.rgba("#ffffff", 0.05),
                key = "forecast_" .. p.key,
                on_hover = function(_, on)
                    drop_hover(app)
                    if on then
                        M.forecast_hover(app, prep, p, f, x, y + 102)
                    end
                end })
            kit.bar(x + 86, y + 111, 190, 10, f, 100, tier_color(f))
            kit.text(x + 286, y + 106, kit.ellipsize(content.chat.forecasts[score.tier(f)], "ui14", w - 296), "ui14", tier_color(f))
        else
            kit.text(x + 86, y + 108, "Pick every stop's type to see a forecast", "ui14", theme.faint)
        end
    end
    if M.staged(app) then
        -- Week 1: what kind of scene they love and which bore them, where the long-term bars go
        -- from week 2 (what you need for picking this week's scene types).
        if p.present and not p.on_break then
            local loves, bored = {}, {}
            for _, id in ipairs(content.scenes.order) do
                local t = score.taste(p, id)
                if t >= 1 then
                    table.insert(loves, { id, t })
                elseif t < 0 then
                    table.insert(bored, { id, t })
                end
            end
            table.sort(loves, function(a, b) return a[2] > b[2] end)
            table.sort(bored, function(a, b) return a[2] < b[2] end)
            local function names(list, n)
                local out = {}
                for k, e in ipairs(list) do
                    if k <= n then
                        table.insert(out, content.scenes[e[1]].name)
                    end
                end
                return #out > 0 and table.concat(out, ", ") or nil
            end
            local lv = names(loves, 2)
            local bd = names(bored, 2)
            kit.text(x + 14, y + 138, "Loves: " .. (lv or "a bit of everything"), "ui14", theme.green, { w = w - 28, lines = 1 })
            kit.text(x + 14, y + 160, "Bored by: " .. (bd or "nothing much"), "ui14", bd and theme.orange or theme.dim,
                { w = w - 28, lines = 1 })
        end
    else
        -- Long-term bars, as well as your Empathy lets you read them.
        local bars = {
            { "commitment", x + 14 }, { "trust", x + 196 },
            { "investment", x + 14 }, { "suspicion", x + 196 },
        }
        for k, b in ipairs(bars) do
            long_bar(app, p, i, b[1], b[2], y + 136 + (k > 2 and 24 or 0))
        end
    end
end

function M.forecast_hover(app, prep, p, f, x0, y0)
    local reasons = prep:forecast_reasons(p.key)
    if #reasons == 0 then
        reasons = { "Nothing on the board pulls " .. p.name .. " either way yet." }
    end
    local w = 420
    local h = 48
    for _, r in ipairs(reasons) do
        h = h + kit.text_height(r, "ui14", w - 48) + 8
    end
    local x = util.clamp(x0 - w - 12, 8, kit.W - w - 8)
    local y = util.clamp(y0 - h / 2, 8, kit.H - h - 8)
    local l = kit.layer("prep_hover")
    app.hover_layer = l
    kit.box(x - 2, y - 2, w + 4, h + 4, theme.gold, { radius = 12 })
    kit.box(x, y, w, h, kit.rgba("#201813", 0.98), { radius = 11 })
    kit.text(x + 16, y + 12, p.name .. " on Thursday: " .. string.lower(content.chat.forecasts[score.tier(f)]), "ui18b", tier_color(f),
        { w = w - 32 })
    local ry = y + 42
    for i, r in ipairs(reasons) do
        kit.dot(x + 22, ry + 9, 8, i == 1 and theme.gold or theme.dim)
        kit.text(x + 34, ry, r, "ui14", i == 1 and theme.text or theme.dim, { w = w - 48 })
        ry = ry + kit.text_height(r, "ui14", w - 48) + 8
    end
end

-- The party ends last week's night without a rest (A16): prep says so under Run game night.
function M.party_not_rested(app)
    local ps = app.campaign.party_state
    if not (ps and not ps.rested and ps.pcs) then
        return false
    end
    for _, p in ipairs(app.campaign.players) do
        local st = ps.pcs[p.key]
        if st and st.hp < st.hp_max then
            return true
        end
    end
    return false
end

-- How well you read the table: shown above the player cards.
local function empathy_meter(app)
    local c = app.campaign
    local level = c:empathy()
    local x = 1576
    for k = empathy.MAX, 1, -1 do
        local filled = k <= level
        local px = x - (empathy.MAX - k + 1) * 14
        kit.dot(px + 5, 92, 10, filled and theme.teal or theme.panel3)
    end
    local label = "EMPATHY  " .. string.upper(empathy.NAMES[level])
    local lx = x - empathy.MAX * 14 - 10
    kit.text(lx, 84, label, "ui14", theme.dim, { pivot = gui.PIVOT_NE })
    kit.icon(lx - kit.width(label, "ui14") - 22, 84, 16, "empathy", theme.teal)
end

-- What a live conflict looks like from this player's chair.
local FEUD = {
    spotlight = { jess = "Filling every scene lately.", other = "Can't get a word in past Pip." },
    rules = { dev = "Sick of the rulebook coming out.", sam = "Wants the same rules every time." },
    tone = { mara = "Wants Ilsa's story taken seriously.", jess = "Scared her jokes aren't welcome." },
}
function M.feud_line(app, p)
    for _, id in ipairs(content.conflicts.order) do
        local c = app.campaign.conflicts[id]
        if social.is_live(c) then
            local f = FEUD[id]
            if f[p.key] then
                return f[p.key]
            elseif f.other and util.contains(content.conflicts[id].hurt, p.key) and c.state == "active" then
                return f.other
            end
        end
    end
end

-- Week 1's drawer, where evenings off go later: the whole of prep in four steps, ticked as you go.
function M.first_prep(app, prep, x, y)
    kit.text(x + 16, y + 10, "YOUR FIRST PREP", "ui14", theme.gold)
    local typed, filled = 0, 0
    for _, s in ipairs(prep.scenes) do
        if s.type then
            typed = typed + 1
        end
        for _ in pairs(s.slots or {}) do
            filled = filled + 1
        end
    end
    local stops = 0
    for _, s in ipairs(prep.scenes) do
        if s.slots.location or (s.open and #(s.spots or {}) > 0) then
            stops = stops + 1
        end
    end
    local steps = {
        { "Stop 1 is the Kettle. Click a place on the map and make it stop 2, then stop 3.", stops >= 2 },
        { "Pick each stop's type, then fill its slots from your hand (click a slot).", typed == #prep.scenes and filled >= 2 },
        { "Plant a seed (right) with an hour spare. It pays off in a week or three.", prep.planted ~= nil },
        { "Run game night. Empty slots get improvised.", false },
    }
    local ty = y + 36
    for i, st in ipairs(steps) do
        local done = st[2]
        kit.dot(x + 26, ty + 9, 18, done and theme.green or theme.panel3)
        kit.text(x + 26, ty + 9, done and "" or util.int(i), "ui14", theme.text, { pivot = gui.PIVOT_CENTER })
        kit.text(x + 44, ty, st[1], "ui14", done and theme.faint or theme.text, { w = 360, lines = 2 })
        ty = ty + kit.text_height(st[1], "ui14", 360) + 7
    end
end

-- The drawer when nothing's selected: an evening off for inspiration, and seeds to plant.
function M.inspiration(app, prep, x, y)
    local insp = content.inspiration
    kit.text(x + 16, y + 10, "INSPIRATION", "ui14", theme.dim)
    kit.text(x + 112, y + 10, "An evening off draws extra cards. " .. util.int(insp.PER_WEEK) .. " a week.", "ui14", theme.faint)
    local bw, bh = 128, 78
    for k, id in ipairs(insp.order) do
        local a = insp[id]
        local col, row = (k - 1) % 3, math.floor((k - 1) / 3)
        local bx, by = x + 14 + col * (bw + 8), y + 34 + row * (bh + 8)
        local done = prep.inspired_by[id]
        local ok = seeds_mod.can_inspire(app.campaign, prep, id)
        -- A new book is out (A13): the supplement evening reads it (and reopens it this week).
        local book_id = id == "supplement" and (prep.reading and prep.reading.book or books_mod.newest(app.campaign))
        local book = book_id and books_mod.book(book_id)
        kit.button(bx, by, bw, bh, "", function()
            if book and prep.reading then
                book_view.open(app)
                return
            end
            local drawn = prep:inspire(id)
            if book and prep.reading then
                book_view.open(app)
                return
            end
            if drawn then
                local names = {}
                for _, c in ipairs(drawn) do
                    table.insert(names, c.name)
                end
                if #names > 0 then
                    app.toast = "Drew: " .. table.concat(names, ", ")
                elseif a.seed then
                    app.toast = "A new seed idea."
                else
                    app.toast = "Nothing new turned up."
                end
            end
            app.refresh()
        end, { color = done and kit.rgba("#28403c") or theme.panel2, hover = theme.button_hover, enabled = ok or done ~= nil,
               key = "inspire_" .. id })
        local name = book and "New book" or a.name
        if book and not done then
            kit.dot(bx + bw - 10, by + bh - 10, 10, theme.green)
        end
        kit.text(bx + 8, by + 6, name, "ui14", (ok or done) and theme.text or theme.faint, { w = bw - 36 })
        local about = book and book.name or (a.short or a.about)
        if a.thread then
            local p = seeds_mod.backstory_target(app.campaign)
            about = util.fill(about, { name = p and p.name or "someone" })
        end
        kit.text(bx + bw - 8, by + 6, (done and not (book and prep.reading and prep.reading.left > 0)) and "Done"
            or (done and "Open" or (util.int(a.cost) .. "h")), "ui14", done and theme.teal or theme.gold,
            { pivot = gui.PIVOT_NE })
        if book then
            -- the book's whole title, under "New book" (A8): "Vale Bestiary & Treasury"
            local title = string.gsub(about, "^The ", "")
            title = string.gsub(title, "^A ", "")
            kit.text(bx + 8, by + 28, title, "ui14", theme.faint, { w = bw - 14, lines = 2 })
        elseif not done then
            kit.text(bx + 8, by + 56, kit.ellipsize(about, "ui14", bw - 16), "ui14", theme.faint)
        end
    end
end

-- Hovering a seed (A6): what it is, when it pays off, and what it can become.
local function pretty(id)
    return (string.gsub(" " .. string.gsub(id, "_", " "), " (%l)", function(ch) return " " .. string.upper(ch) end)):sub(2)
end

local function seed_detail(app, id, x0, y0)
    local sd = content.seeds
    local def = sd[id]
    local w = 470
    local rows = { { def.plant, "story22", theme.text } }
    local pay = content.components[def.payoff]
    table.insert(rows, { "When: from next week its payoff" .. (pay and (", \"" .. pay.name .. "\",") or "")
        .. " turns up in your hand for " .. util.int(sd.PAYOFF_WEEKS) .. " weeks. Put it on the board to pay it off; "
        .. "leave it too long and it goes stale, and the theorists notice.", "ui14", theme.dim })
    if pay then
        table.insert(rows, { "It can become: " .. content.line_for(pay), "ui14", theme.teal })
    end
    local subs = {}
    for sub in pairs(def.nudge or {}) do
        table.insert(subs, pretty(sub))
    end
    table.sort(subs)
    if #subs > 0 then
        table.insert(rows, { "Might tempt a level-3 pick: " .. table.concat(subs, ", ") .. ".", "ui14", theme.gold })
    end
    local fans = {}
    for _, p in ipairs(app.campaign.players) do
        for _, a in ipairs(def.fans or {}) do
            if p.primary == a or p.secondary == a then
                table.insert(fans, p.name)
                break
            end
        end
    end
    if #fans > 0 then
        table.insert(rows, { "Who'll theorize about it: " .. table.concat(fans, ", ") .. ".", "ui14", theme.green })
    end
    local h = 52
    for _, r in ipairs(rows) do
        h = h + kit.text_height(r[1], r[2], w - 32) + 8
    end
    local x = util.clamp(x0, 8, kit.W - w - 8)
    local y = math.max(8, y0 - h - 8)
    local l = kit.layer("prep_hover")
    app.hover_layer = l
    kit.box(x - 2, y - 2, w + 4, h + 4, theme.gold, { radius = 12 })
    kit.box(x, y, w, h, kit.rgba("#201813", 0.98), { radius = 11 })
    kit.text(x + 16, y + 12, def.name, "ui18b", theme.text, { w = w - 90 })
    kit.text(x + w - 16, y + 14, "SEED  " .. util.int(sd.COST) .. "h", "ui14", theme.gold, { pivot = gui.PIVOT_NE })
    local ry = y + 44
    for _, r in ipairs(rows) do
        kit.text(x + 16, ry, r[1], r[2], r[3], { w = w - 32 })
        ry = ry + kit.text_height(r[1], r[2], w - 32) + 8
    end
end

function M.seeds(app, prep, x, y)
    local sd = content.seeds
    local w = 370
    kit.text(x, y + 10, "SEEDS", "ui14", theme.dim)
    kit.text(x + 56, y + 10, "Plant a mystery now, pay it off in 1 to " .. util.int(sd.PAYOFF_WEEKS) .. " weeks.", "ui14",
        theme.faint)
    local by = y + 32
    for _, id in ipairs(prep.seed_ideas) do
        local def = sd[id]
        local planted = prep.planted == id
        local ok = prep:can_plant(id)
        if by + 28 > y + 160 then
            break
        end
        local my = by
        kit.button(x, by, w, 28, "", function()
            if planted then
                prep:unplant()
            else
                local done, why = prep:plant(id)
                if not done then
                    app.toast = why
                end
            end
            app.refresh()
        end, { color = planted and kit.rgba("#28403c") or theme.panel2, hover = theme.button_hover,
               enabled = ok or planted, key = "seed_" .. id,
               on_hover = function(_, on)
                   drop_hover(app)
                   if on then
                       seed_detail(app, id, x - 60, my)
                   end
               end })
        kit.text(x + 10, by + 5, def.name, "ui14", (ok or planted) and theme.text or theme.faint, { w = w - 120, lines = 1 })
        kit.text(x + w - 10, by + 5, planted and "Planted (undo)" or (util.int(sd.COST) .. "h"), "ui14",
            planted and theme.teal or theme.gold, { pivot = gui.PIVOT_NE })
        by = by + 32
    end
    -- What's growing.
    local growing = seeds_mod.growing(app.campaign)
    local gy = y + 164
    if #growing == 0 then
        -- This week's planting shows at once (A6), before game night mentions it.
        kit.text(x, gy, prep.planted and ("Planting: " .. sd[prep.planted].name .. ". Game night mentions it; the payoff comes later.")
            or "Nothing planted yet.", "ui14", prep.planted and theme.teal or theme.faint, { w = w, lines = 2 })
        return
    end
    local parts, ready = {}, 0
    if prep.planted then
        table.insert(parts, sd[prep.planted].name .. " (planting now)")
    end
    for _, s in ipairs(growing) do
        local def = sd[s.id]
        local left = s.week + sd.PAYOFF_WEEKS - app.campaign.week
        local in_hand = prep.payoffs[def.payoff]
        local on_board = in_hand and prep:placed_at(def.payoff)
        if in_hand and not on_board then
            ready = ready + 1
        end
        table.insert(parts, def.name .. (on_board and (" (pays off at stop " .. util.int(on_board) .. ")")
            or (in_hand and left <= 0 and " (last week!)" or "")))
    end
    local text = "Growing: " .. table.concat(parts, ", ") .. "."
    -- Once it's placed, the hand no longer has it (playtest, October 13: stale "in your hand").
    if ready > 0 then
        text = text .. " " .. (ready == 1 and "A payoff is" or (util.int(ready) .. " payoffs are")) .. " in your hand."
    end
    kit.text(x, gy, text, "ui14", theme.text, { w = w, lines = 2 })
end

function M.build(app)
    local prep = app.campaign.prep
    kit.box(0, 0, kit.W, kit.H, theme.bg, { round = false })
    top_bar(app, prep)
    chat_column(app)
    -- The valley map, and beside it the open place's card or the stop's scene card.
    valley_view.draw(app, prep)
    if not valley_view.side(app, prep) then
        scene_card(app, prep, valley_view.shown_stop(app, prep))
    end
    pacing_panel(app, prep)
    drawer(app, prep)
    kit.text(1196, 84, "THE TABLE", "ui14", theme.dim)
    -- Where the party is at (A16): carried over from last week unless they rested.
    local ps = app.campaign.party_state
    if ps and not ps.rested and ps.pcs then
        local hp, hpm, sl = 0, 0, 0
        local parts = {}
        for _, p in ipairs(app.campaign.players) do
            local s = ps.pcs[p.key]
            if s then
                hp, hpm = hp + s.hp, hpm + s.hp_max
                if s.hp < s.hp_max then
                    table.insert(parts, p.char .. " " .. util.int(s.hp) .. "/" .. util.int(s.hp_max))
                end
                for _, n in ipairs(s.res and s.res.slots or {}) do
                    sl = sl + n
                end
            end
        end
        if hpm > 0 and hp < hpm and prep:ready() then
            -- (Where "or press Enter" usually sits, under Run game night; until the board is
            -- ready, "Pick a type" has that spot: one line there, never two on top of each other.)
            kit.text(1466, 56, "Not rested: the party's at " .. util.int(math.floor(100 * hp / hpm + 0.5)) .. "% HP",
                "ui14", theme.orange, { pivot = gui.PIVOT_N })
        end
    end
    if not M.staged(app) then
        empathy_meter(app)
    end
    local forecast = prep:forecast()
    for i, p in ipairs(app.campaign.players) do
        player_card(app, prep, p, i, forecast)
    end
    -- Who's joining later (a small table, October 15): their chair, waiting.
    for k, j in ipairs(app.campaign.joining and app.campaign:joining() or {}) do
        local i = #app.campaign.players + k
        if i <= 4 then
            local d = content.players[j.key]
            local x, y, w, h = 1196, 106 + (i - 1) * 196, 380, 186
            kit.box(x, y, w, h, kit.rgba("#000000", 0.18), { radius = 10 })
            kit.dot(x + 29, y + 23, 34, panels.COLORS[j.key] or theme.panel3)
            kit.picture(x + 13, y + 7, 32, 32, panels.face(j.key))
            kit.text(x + 52, y + 10, d.name, "ui22b", theme.dim)
            kit.text(x + 52 + kit.width(d.name, "ui22b") + 10, y + 14, d.char .. ", " .. d.class_name, "ui18", theme.faint)
            kit.text(x + 14, y + 56, "Joins the table in session " .. util.int(j.week) .. ".", "ui18", theme.gold)
            kit.text(x + 14, y + 84, d.gist and (d.gist .. ".") or "", "ui14", theme.faint, { w = w - 28, lines = 2 })
            kit.text(x + 14, y + 130, "You'll hear their story and write it in before that week starts.", "ui14", theme.faint,
                { w = w - 28, lines = 2 })
        end
    end
    -- The Story log, over the table column while it's open.
    require("game.ui.story_log_view").panel(app)
end

return M
