-- The campaign notebook's new pages (the slice rework, S3 to S7): This week (the world's
-- moves, who the session is for, who shows up), Campaign (the plan, the fronts, shelved
-- cards), People, Factions, Places and Threads. Drawn inside the notes binder
-- (game/ui/notes_view.lua); every page fits without paging, and hovering a card shows the
-- rest. The models are game/model/ledger.lua, world.lua, planner.lua and deck.lua.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local content = require "game.model.content"
local util = require "game.model.util"
local ledger = require "game.model.ledger"
local world = require "game.model.world"
local deck = require "game.model.deck"
local planner = require "game.model.planner"
local panels = require "game.ui.panels"

local M = {}

local ATT_COLOR = {
    Hostile = theme.red, Wary = theme.orange, Indifferent = theme.dim, Warm = theme.teal, Friendly = theme.green,
}
M.ATT_COLOR = ATT_COLOR
local RESULT_WORDS = { full = "It works.", half = "It half works.", bad = "It goes badly.", done = "Done.",
                       pushed = "Set back.", helped = "Helped." }
local RESULT_COLOR = { full = theme.red, half = theme.orange, bad = theme.teal }

local function head(x, y, text, color)
    kit.text(x, y, string.upper(text), "ui14", color or theme.gold)
    return y + 22
end

local function para(x, y, w, text, font, color)
    font = font or "ui18"
    kit.text(x, y, text, font, color or theme.text, { w = w })
    return y + kit.text_height(text, font, w) + 6
end

-- Hover popups ------------------------------------------------------------------------------

function M.drop_hover(app)
    if app.notes_hover then
        kit.drop(app.notes_hover)
        app.notes_hover = nil
    end
end

-- A popup of rows ({ text, font, color }) near a point, kept on screen.
local function popup(app, x0, y0, rows, w)
    M.drop_hover(app)
    w = w or 440
    local h = 24
    for _, r in ipairs(rows) do
        h = h + kit.text_height(r[1], r[2], w - 32) + (r[4] or 6)
    end
    local x = util.clamp(x0, 8, kit.W - w - 8)
    local y = util.clamp(y0, 8, kit.H - h - 8)
    local l = kit.layer("notes_hover")
    app.notes_hover = l
    kit.box(x - 2, y - 2, w + 4, h + 4, theme.gold, { radius = 12 })
    kit.box(x, y, w, h, kit.rgba("#201813", 0.98), { radius = 11 })
    local ry = y + 12
    for _, r in ipairs(rows) do
        kit.text(x + 16, ry, r[1], r[2], r[3], { w = w - 32 })
        ry = ry + kit.text_height(r[1], r[2], w - 32) + (r[4] or 6)
    end
    -- Back to drawing in the notes layer for anything after this.
    kit.use(app.notes_layer)
end

local function hover_with(app, rows_fn, x, y, w)
    return function(_, on)
        if on then
            local ok, rows = pcall(rows_fn)
            if ok and rows then
                popup(app, x, y, rows, w)
            end
        else
            M.drop_hover(app)
        end
    end
end

-- Little meters -----------------------------------------------------------------------------

-- Seven pips, -3 to +3, filled out from the middle: red one way, green the other.
local function meter(x, y, v)
    for k = -3, 3 do
        local px = x + (k + 3) * 13
        local on = (v < 0 and k < 0 and k >= v) or (v > 0 and k > 0 and k <= v)
        local col = on and (k < 0 and theme.red or theme.green) or kit.rgba("#000000", 0.3)
        if k == 0 then
            col = kit.rgba("#ffffff", 0.25)
        end
        kit.box(px, y, 10, 10, col, { radius = 3, round = false })
    end
    return 7 * 13
end
M.meter = meter

local function att_line(app, x, y, pid)
    local a = ledger.att(app.campaign, pid, app.screen == "night" and app.night or nil)
    local label = ledger.label(a)
    local mw = meter(x, y + 4, a)
    kit.text(x + mw + 8, y, label, "ui14", ATT_COLOR[label] or theme.dim)
    return a, label
end

-- A clock: `size` segments, `filled` of them shaded.
local function clock(x, y, size, filled, color, seg)
    seg = seg or 18
    for i = 1, size do
        kit.box(x + (i - 1) * (seg + 3), y, seg, 12, i <= filled and color or kit.rgba("#000000", 0.3), { round = false })
    end
    return size * (seg + 3)
end

local function dice(x, y, list, best)
    local dx = x
    local kept = false
    for _, v in ipairs(list or {}) do
        local hi = (v == best) and not kept
        kept = kept or hi
        kit.box(dx, y, 24, 24, hi and theme.paper or kit.rgba("#efe4c8", 0.35), { radius = 5 })
        kit.text(dx + 12, y + 12, util.int(v), "ui14", theme.ink, { pivot = gui.PIVOT_CENTER })
        dx = dx + 28
    end
    return dx - x
end

local function max_of(list)
    local m = 0
    for _, v in ipairs(list or {}) do
        m = math.max(m, v)
    end
    return m
end

-- One person's whole story with the party, for a hover.
function M.person_rows(app, pid)
    local c = app.campaign
    local night = app.screen == "night" and app.night or nil
    local ab = ledger.about(pid)
    local p = ledger.person(c, pid)
    local rows = {}
    table.insert(rows, { ab.name, "ui18b", theme.text, 2 })
    if ab.role ~= "" then
        table.insert(rows, { ab.role, "ui14", theme.gold })
    end
    local fid = p and ledger.faction_of(c, pid)
    local def = ledger.data.people[pid] or {}
    if fid and (not def.hidden or p.exposed) then
        table.insert(rows, { ledger.data[fid].name, "ui14", theme.dim })
    end
    local a = ledger.att(c, pid, night)
    local label = ledger.label(a)
    local how = label
    if a >= 2 then
        how = how .. ". Influence checks against them have advantage."
    elseif a <= -2 then
        how = how .. ". Influence checks against them have disadvantage."
    else
        how = how .. "."
    end
    table.insert(rows, { "Toward the party: " .. how, "ui14", ATT_COLOR[label] or theme.dim })
    local status = ledger.status(c, pid)
    if p and status ~= "around" then
        table.insert(rows, { ledger.data.STATUS[status] or status, "ui14", theme.orange })
    end
    -- Grudge (B6): what a villain who got away holds against the party.
    local g = ledger.grudge_level(c, pid)
    if g > 0 then
        table.insert(rows, { "Grudge: " .. string.rep("*", g) .. string.rep(".", ledger.GRUDGE_MAX - g)
            .. (g >= 3 and "  It's personal now. When they fall, it'll mean something." or ""), "ui14", theme.red })
    end
    -- What the villain said, the retort that answered it, and who wants them (villain monologues).
    for _, line in ipairs(require("game.model.villains").notes(c, pid)) do
        table.insert(rows, { line, "ui14", theme.orange })
    end
    for _, wm in ipairs(ledger.warmth(c, pid)) do
        local pl = c:player(wm.key)
        table.insert(rows, { (wm.n > 0 and "Warm to " or "Cold toward ") .. pl.char .. " (" .. pl.name .. ")", "ui14",
                             wm.n > 0 and theme.teal or theme.red })
    end
    if p and #p.knows > 0 then
        table.insert(rows, { "WHAT THE PARTY KNOWS", "ui14", theme.gold, 2 })
        for _, k in ipairs(p.knows) do
            table.insert(rows, { k, "ui14", theme.text })
        end
    end
    -- A story clue about them, if the party found it.
    local story = require "game.model.story"
    for _, cid in ipairs(def.cards or { pid }) do
        for _, cl in ipairs(story.init(c).clues) do
            if cl.id == cid then
                table.insert(rows, { "Clue: " .. cl.text, "ui14", theme.text })
            end
        end
    end
    local hist = ledger.history(c, pid, night)
    if #hist > 0 then
        table.insert(rows, { "WHAT'S HAPPENED", "ui14", theme.gold, 2 })
        for i = 1, math.min(8, #hist) do
            local e = hist[i]
            local wk = e.w and ("Session " .. util.int(e.w) .. ": ") or "Tonight: "
            table.insert(rows, { wk .. ledger.entry_text(c, e, { short_target = true }), "ui14", theme.text, 3 })
        end
    else
        table.insert(rows, { ab.about, "ui14", theme.dim })
    end
    local kind = ledger.agenda_kind(c, pid)
    if kind then
        local wnt = def.wants[kind]
        table.insert(rows, { "BRING THEM IN AND THEY BRING", "ui14", theme.gold, 2 })
        table.insert(rows, { wnt.name .. (kind == "warm" and " (a goal)" or " (a complication)"), "ui14", theme.text })
    end
    return rows
end

-- This week ---------------------------------------------------------------------------------

local function move_row(app, x, y, w, i, m)
    local c = app.campaign
    local fd = ledger.data[m.faction]
    local mv = world.move_def(m.faction, m.move)
    local st = ledger.standing(c, m.faction)
    kit.text(x, y, fd.name, "ui18b", theme.gold)
    kit.text(x + w, y + 2, ledger.STANDING[st], "ui14", st < 0 and theme.red or (st > 0 and theme.green or theme.dim),
        { pivot = gui.PIVOT_NE })
    local ty = y + 24
    kit.text(x, ty, mv.name .. (m.was_held and " (held last week)" or ""), "ui18", theme.text, { w = w })
    ty = ty + kit.text_height(mv.name, "ui18", w) + 6
    local function act(choice)
        return function()
            local ok, why = world.decide(c, i, choice)
            if not ok then
                app.notes_toast = why
            end
            app.refresh_notes()
        end
    end
    if m.state == "pending" then
        local card = world.screen_card(c, m.faction, mv)
        local screen_taken = false
        for _, o in ipairs(world.get(c).moves) do
            screen_taken = screen_taken or o.state == "screen"
        end
        local wd = world.get(c)
        kit.button(x, ty, 150, 34, "Let it happen", act("let"), { font = "ui14", color = theme.button,
            key = "world_let_" .. util.int(i),
            on_hover = hover_with(app, function()
                return { { "You roll for it behind the screen: " .. util.int(fd.tier) .. (fd.tier == 1 and " die" or " dice")
                    .. ", keep the highest. 6 works, 4 or 5 half works, 1 to 3 goes badly.", "ui14", theme.text } }
            end, x, ty + 40, 380) })
        kit.button(x + 158, ty, 170, 34, "Bring on screen", act("screen"), { font = "ui14", color = theme.button,
            enabled = card ~= nil and not screen_taken, key = "world_screen_" .. util.int(i),
            on_hover = hover_with(app, function()
                if not card then
                    return { { "There's no card for this move this week.", "ui14", theme.dim } }
                elseif screen_taken then
                    return { { "One move on screen a week.", "ui14", theme.dim } }
                end
                return { { "It comes into your hand as \"" .. card.name .. "\". Put it on a scene: if the party wins it, the move goes badly for "
                    .. fd.short .. "; if they lose, it works.", "ui14", theme.text } }
            end, x + 158, ty + 40, 400) })
        kit.button(x + 336, ty, 90, 34, "Hold", act("hold"), { font = "ui14", color = theme.button,
            enabled = wd.holds < ledger.data.HOLDS, key = "world_hold_" .. util.int(i) })
        return ty + 44
    elseif m.state == "let" then
        local dw = dice(x, ty, m.dice, max_of(m.dice))
        kit.text(x + dw + 8, ty + 3, RESULT_WORDS[m.result] or "", "ui18b", RESULT_COLOR[m.result] or theme.text)
        ty = ty + 30
        return para(x, ty, w, m.text or "", "ui14", theme.dim) + 4
    elseif m.state == "screen" then
        local card = m.card and content.components[m.card]
        local text = m.settled and (m.text or "") or ("On screen: \"" .. (card and card.name or "?")
            .. "\" is pinned in your hand. The party's scene decides it.")
        local ny = para(x, ty, w - 100, text, "ui14", theme.teal)
        if not m.settled then
            kit.button(x + w - 90, ty, 90, 30, "Undo", act("undo"), { font = "ui14", key = "world_undo_" .. util.int(i) })
        end
        return math.max(ny, ty + 34) + 4
    else
        kit.text(x, ty, "Held. It comes back next week.", "ui14", theme.dim)
        kit.button(x + w - 90, ty - 4, 90, 30, "Undo", act("undo"), { font = "ui14", key = "world_undo_" .. util.int(i) })
        return ty + 34
    end
end

local function spotlight_buttons(app, x, y, w)
    local c = app.campaign
    local prep = c.prep
    local bw = math.floor((w - 10) / 2)
    for k, p in ipairs(c.players) do
        local col, row = (k - 1) % 2, math.floor((k - 1) / 2)
        local bx, by = x + col * (bw + 10), y + row * 78
        local card = p.present and prep and prep:spotlight_card(p.key) or nil
        local on = prep and prep.spot == p.key
        kit.button(bx, by, bw, 70, "", function()
            if on then
                prep:clear_spotlight()
            else
                local ok, why = prep:spotlight(p.key)
                if not ok then
                    app.notes_toast = why
                end
            end
            app.refresh_notes()
        end, { color = on and theme.go or theme.panel2, hover = theme.button_hover, enabled = (card ~= nil) or on,
               key = "spot_" .. p.key })
        kit.dot(bx + 26, by + 26, 36, panels.COLORS[p.key] or theme.panel3)
        kit.picture(bx + 10, by + 10, 32, 32, panels.face(p.key))
        kit.text(bx + 52, by + 8, p.name .. ": " .. p.char, "ui18b", theme.text, { w = bw - 60 })
        local sub
        if not p.present then
            sub = "Out this week."
        elseif not card then
            sub = "Nothing in their story is ready this week."
        else
            sub = (on and "This session is for them: " or "Next: ") .. card.name
        end
        kit.text(bx + 52, by + 30, sub, "ui14", on and theme.text or theme.dim, { w = bw - 60 })
    end
    return y + 2 * 78
end

local function guest_section(app, x, y, w, bottom)
    local c = app.campaign
    local prep = c.prep
    local n = prep and prep:guest_count() or 0
    y = head(x, y, "Who shows up?  " .. util.int(n) .. " of " .. util.int(ledger.data.GUESTS))
    y = para(x, y, w, "Bring in people the party has met, or places. People bring what they want: a favour if they like the party, trouble if they don't.",
        "ui14", theme.faint)
    if not prep then
        return y
    end
    local opts = prep:guest_options()
    local bw = math.floor((w - 10) / 2)
    for k, pid in ipairs(opts.people) do
        local col, row = (k - 1) % 2, math.floor((k - 1) / 2)
        local bx, by = x + col * (bw + 10), y + row * 50
        local on = prep.guests[pid] ~= nil
        local ab = ledger.about(pid)
        kit.button(bx, by, bw, 44, "", function()
            if on then
                prep:send_home(pid)
            else
                local ok, why = prep:bring_in(pid)
                if not ok then
                    app.notes_toast = why
                end
            end
            app.refresh_notes()
        end, { color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "guest_" .. pid,
               on_hover = hover_with(app, function() return M.person_rows(app, pid) end, bx + bw + 8, by - 40) })
        if ab.sprite then
            kit.picture(bx + 6, by + 4, 29, 36, "mini_" .. ab.sprite)
        end
        kit.text(bx + 42, by + 4, ab.name, "ui14", theme.text, { w = bw - 50 })
        local a = ledger.att(c, pid)
        local label = ledger.label(a)
        local st = ledger.status(c, pid)
        kit.text(bx + 42, by + 23, (on and "Coming. " or "") .. (st == "got away" and "Got away last time" or label), "ui14",
            on and theme.text or (ATT_COLOR[label] or theme.dim))
    end
    y = y + math.ceil(#opts.people / 2) * 50
    if #opts.people == 0 then
        y = para(x, y, w, "Nobody yet: the party hasn't met anyone who's still around.", "ui14", theme.faint)
    end
    y = head(x, y + 4, "Places", theme.dim)
    local cx, cy = x, y
    for _, card in ipairs(opts.places) do
        local label = card.short and util.capitalize(card.short) or card.name
        local bw2 = kit.width(label, "ui14") + 24
        if cx + bw2 > x + w then
            cx, cy = x, cy + 36
        end
        if cy + 30 > bottom then
            break
        end
        local on = prep.guests[card.id] ~= nil
        kit.button(cx, cy, bw2, 30, label, function()
            if on then
                prep:send_home(card.id)
            else
                local ok, why = prep:bring_in(card.id)
                if not ok then
                    app.notes_toast = why
                end
            end
            app.refresh_notes()
        end, { font = "ui14", color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "guest_" .. card.id,
               on_hover = hover_with(app, function()
                   local st = ledger.place_state(c, card.id)
                   local rows = { { card.name, "ui18b", theme.text } }
                   if st then
                       table.insert(rows, { st.label, "ui14", theme.teal })
                   end
                   table.insert(rows, { st and st.line or (deck.returning(c, card) and card.again or card.line) or card.line, "story22", theme.text })
                   return rows
               end, cx, cy + 36, 420) })
        cx = cx + bw2 + 8
    end
    return cy + 36
end

function M.week(app, x, y, w, h)
    local c = app.campaign
    local lw = 590
    local ly = head(x, y, "What the world does this week")
    ly = para(x, ly, lw, "Every faction makes a move off screen. Let it happen and roll for it behind your screen, bring one move on screen as a card in your hand, or hold one for a week.",
        "ui14", theme.faint)
    local wd = world.get(c)
    if wd.week ~= c.week or #wd.moves == 0 then
        ly = para(x, ly + 6, lw, "The world is quiet this week.", "ui18", theme.dim)
    end
    for i, m in ipairs(wd.week == c.week and wd.moves or {}) do
        kit.box(x - 10, ly - 4, lw + 20, 1, kit.rgba("#ffffff", 0.06), { round = false })
        ly = move_row(app, x, ly + 6, lw, i, m)
    end
    local rx, rw = x + lw + 40, w - lw - 40
    local ry = head(rx, y, "Who's this session for?")
    ry = spotlight_buttons(app, rx, ry, rw)
    guest_section(app, rx, ry + 8, rw, y + h)
    if app.notes_toast then
        kit.text(x + w / 2, y + h + 2, app.notes_toast, "ui14", theme.orange, { pivot = gui.PIVOT_S })
        app.notes_toast = nil
    end
end

-- Things the DM hasn't looked at this week (the notes' dot).
function M.week_pending(app)
    local c = app.campaign
    return world.pending(c)
end

-- Campaign ----------------------------------------------------------------------------------

function M.campaign(app, x, y, w, h)
    local c = app.campaign
    local s = planner.summary(c)
    local lw = 520
    local ly = head(x, y, "The campaign")
    kit.text(x, ly, s.premise.name, "title30", theme.text)
    ly = ly + 42
    ly = para(x, ly, lw, s.premise.text, "ui18", theme.dim)
    ly = head(x, ly + 6, "What everyone knows about the world")
    for _, t in ipairs(s.truths) do
        kit.text(x, ly, t.name, "ui18b", theme.text, { w = lw })
        ly = ly + kit.text_height(t.name, "ui18b", lw) + 2
        ly = para(x + 12, ly, lw - 12, t.about, "ui14", theme.dim)
    end
    ly = head(x, ly + 6, "Featured threads")
    local names = {}
    for _, p in ipairs(s.threads) do
        table.insert(names, p.char .. " (" .. p.thread .. ")")
    end
    ly = para(x, ly, lw, #names > 0 and table.concat(names, "; ") or "None.", "ui14", theme.text)
    -- The big questions (B10), counted; the web page has them in full.
    ly = para(x, ly + 4, lw, require("game.model.questions").summary(c).text .. " (The web)", "ui14", theme.teal)
    -- Shelved cards: bring one back and it's in your hand again.
    ly = head(x, ly + 6, "Shelved")
    local shelved = deck.shelved(c)
    if #shelved == 0 then
        para(x, ly, lw, "Nothing shelved. Shelve a card from your hand (the x on it) and it stops coming up until you bring it back here.",
            "ui14", theme.faint)
    else
        local cx, cy = x, ly
        for _, card in ipairs(shelved) do
            local label = "Bring back: " .. card.name
            local bw = kit.width(label, "ui14") + 24
            if cx + bw > x + lw then
                cx, cy = x, cy + 36
            end
            if cy + 30 > y + h then
                break
            end
            kit.button(cx, cy, bw, 30, label, function()
                if c.prep then
                    c.prep:unshelve(card.id)
                else
                    deck.unshelve(c, card.id)
                end
                app.refresh_notes()
            end, { font = "ui14", key = "unshelve_" .. card.id })
            cx = cx + bw + 8
        end
    end
    -- The fronts.
    local rx, rw = x + lw + 40, w - lw - 40
    local ry = head(rx, y, "The fronts")
    for _, f in ipairs(s.fronts) do
        kit.text(rx, ry, f.name, "ui22b", theme.text, { w = rw })
        ry = ry + kit.text_height(f.name, "ui22b", rw) + 2
        ry = para(rx, ry, rw, "Wants: " .. f.impulse, "ui14", theme.dim)
        for i, t in ipairs(f.track) do
            kit.dot(rx + 8, ry + 9, 12, t.done and theme.red or kit.rgba("#000000", 0.35))
            local label = t.text .. (t.week and (" (session " .. util.int(t.week) .. ")") or "")
            kit.text(rx + 22, ry, label, "ui14", t.done and theme.text or theme.dim, { w = rw - 22 })
            ry = ry + kit.text_height(label, "ui14", rw - 22) + 4
        end
        local doom = (f.doomed and "It happened: " or "If nobody stops it: ") .. f.doom
        ry = para(rx + 22, ry, rw - 22, doom, "ui14", f.doomed and theme.red or theme.orange)
        if (f.held or 0) > 0 then
            ry = para(rx + 22, ry, rw - 22, "Held back " .. util.int(f.held) .. (f.held == 1 and " time" or " times") .. " by the party.",
                "ui14", theme.teal)
        end
        ry = ry + 8
    end
    M.course(app, rx, ry + 4, rw, y + h)
end

-- The web (M8, B10): the big questions, and a corkboard of the arc's people, places and
-- factions. A string runs from each person to their faction and to where the party met them:
-- green when they're warm to the party, red when they're cold, dashed for people the party
-- hasn't met yet. The model is game/model/questions.lua and the ledger.
function M.web(app, x, y, w, h)
    local c = app.campaign
    local questions = require "game.model.questions"
    local places = require "game.model.places"
    local lw = 420
    local ly = head(x, y, "The big questions")
    for _, st in ipairs(questions.all(c)) do
        kit.text(x, ly, st.q.q, "ui18b", theme.text, { w = lw })
        ly = ly + kit.text_height(st.q.q, "ui18b", lw) + 4
        local dx = x
        for _, cl in ipairs(st.clues) do
            local col = cl.found and theme.gold or (cl.state == "spent" and theme.red or kit.rgba("#000000", 0.4))
            kit.dot(dx + 7, ly + 8, 12, col)
            dx = dx + 18
        end
        local count = util.int(st.found) .. " found, " .. util.int(st.out) .. " still out there"
            .. (st.gone > 0 and (", " .. util.int(st.gone) .. " missed") or "")
        kit.text(dx + 6, ly, count, "ui14", st.out + st.found < 3 and theme.orange or theme.dim)
        ly = ly + 22
        ly = para(x + 12, ly, lw - 12, st.answered and st.q.answer or "Not answered yet.", "ui14",
            st.answered and theme.teal or theme.faint) + 6
    end
    para(x, ly + 4, lw, "Gold: found. Dark: still in the deck. Red: played without being found. Keep three roads to every answer.",
        "ui14", theme.faint)
    -- The corkboard.
    local bx, by, bw, bh = x + lw + 30, y, w - lw - 30, h
    kit.box(bx, by, bw, bh, kit.rgba("#7a5a3c"), { radius = 8 })
    kit.text(bx + 14, by + 10, "THE WEB", "ui14", kit.rgba("#f3e2c0"))
    local factions = ledger.data.order
    local pos = {}
    -- Factions along the top, people in a column under their faction, the unaligned in a row
    -- above the places, places along the bottom. Neighbouring columns sit half a row apart, so a
    -- long name can run wider than its column without landing on the next one's (A8).
    local fw = (bw - 40) / math.max(1, #factions)
    local col_of = {}
    for i, fid in ipairs(factions) do
        local fx = bx + 20 + (i - 0.5) * fw
        local stagger = (i % 2 == 0) and 30 or 0
        pos["f:" .. fid] = { fx, by + 54 + stagger }
        col_of[fid] = { fx, 0, stagger }
    end
    local people = ledger.people(c)
    local placed_people = {}
    local loose = {}
    local step = math.min(78, math.max(58, (bh - 300) / 4))
    for _, pid in ipairs(people) do
        local fid = ledger.faction_of(c, pid)
        local col = col_of[fid]
        if col then
            col[2] = col[2] + 1
            if col[2] <= 4 then
                pos["p:" .. pid] = { col[1], by + 128 + col[3] + (col[2] - 1) * step }
                table.insert(placed_people, { pid = pid, fid = fid })
            end
        elseif #loose < 5 then
            table.insert(loose, pid)
            table.insert(placed_people, { pid = pid })
        end
    end
    local lw2 = (bw - 60) / math.max(1, #loose)
    for i, pid in ipairs(loose) do
        pos["p:" .. pid] = { bx + 30 + (i - 0.5) * lw2, by + bh - 116 + ((i % 2 == 0) and 22 or 0) }
    end
    local plist = places.list(c)
    local nplaces = math.min(6, #plist)
    local pw = (bw - 60) / math.max(1, nplaces)
    for i = 1, nplaces do
        local pl = plist[i]
        pos["l:" .. pl.id] = { bx + 30 + (i - 0.5) * pw, by + bh - 34 - ((i % 2 == 0) and 30 or 0) }
    end
    -- How wide a label can run: two columns' worth, less a gap (the neighbours are half a row off).
    local function room(cw)
        return math.max(90, 2 * cw - 16)
    end
    -- A label's centre, nudged in so the whole card stays on the board.
    local function inside(px, tw)
        return math.max(bx + 8 + tw / 2, math.min(bx + bw - 8 - tw / 2, px))
    end
    -- Strings first, so the pins sit on top.
    for _, pp in ipairs(placed_people) do
        local a = pos["p:" .. pp.pid]
        local met = ledger.met(c, pp.pid)
        local att = ledger.att(c, pp.pid)
        local col = (not met and kit.rgba("#f3e2c0", 0.35)) or (att >= 1 and theme.green) or (att <= -1 and theme.red)
            or kit.rgba("#e8d8b0", 0.8)
        local f = pp.fid and pos["f:" .. pp.fid]
        if f then
            if met then
                kit.line(a[1], a[2], f[1], f[2], 2, col)
            else
                -- Dashed: someone the party hasn't met yet.
                for k = 0, 5, 2 do
                    local t0, t1 = k / 6, (k + 1) / 6
                    kit.line(a[1] + (f[1] - a[1]) * t0, a[2] + (f[2] - a[2]) * t0, a[1] + (f[1] - a[1]) * t1,
                        a[2] + (f[2] - a[2]) * t1, 2, col)
                end
            end
        end
        -- Where the party met them.
        local hist = ledger.history(c, pp.pid)
        local at = hist[#hist] and hist[#hist].at
        local l = at and pos["l:" .. at]
        if l and met then
            kit.line(a[1], a[2], l[1], l[2], 1, kit.rgba("#f3e2c0", 0.45))
        end
    end
    -- Pins and cards.
    for i, fid in ipairs(factions) do
        local p = pos["f:" .. fid]
        local fd = ledger.data[fid]
        local name = fd and fd.name or fid
        local tw = math.min(room(fw), kit.width(name, "ui14") + 20)
        local cx = inside(p[1], tw)
        kit.box(cx - tw / 2, p[2] - 14, tw, 28, kit.rgba("#f3df8a"), { radius = 3 })
        kit.text(cx, p[2] - 10, kit.ellipsize(name, "ui14", tw - 10), "ui14", theme.ink, { pivot = gui.PIVOT_N })
        kit.dot(p[1], p[2] - 16, 10, theme.red)
    end
    for _, pp in ipairs(placed_people) do
        local p = pos["p:" .. pp.pid]
        local ab = ledger.about(pp.pid)
        local name = kit.ellipsize(ab.name, "ui14", (pp.fid and room(fw) or room(lw2)) - 16)
        local tw = kit.width(name, "ui14") + 16
        local met = ledger.met(c, pp.pid)
        local cx = inside(p[1], tw)
        kit.box(cx - tw / 2, p[2] - 12, tw, 24, met and kit.rgba("#fbf4e2") or kit.rgba("#fbf4e2", 0.55), { radius = 3 })
        kit.text(cx, p[2] - 9, name, "ui14", theme.ink, { pivot = gui.PIVOT_N })
        kit.dot(p[1], p[2] - 14, 8, theme.teal)
        local g = ledger.grudge_level(c, pp.pid)
        if g > 0 then
            kit.text(cx + tw / 2 + 4, p[2] - 9, string.rep("!", g), "ui14", theme.red)
        end
    end
    for i = 1, nplaces do
        local pl = plist[i]
        local p = pos["l:" .. pl.id]
        local name = kit.ellipsize(pl.card.short and util.capitalize(pl.card.short) or pl.card.name, "ui14", room(pw) - 16)
        local tw = kit.width(name, "ui14") + 16
        local cx = inside(p[1], tw)
        kit.box(cx - tw / 2, p[2] - 12, tw, 24, kit.rgba("#cfe3d8"), { radius = 3 })
        kit.text(cx, p[2] - 9, name, "ui14", theme.ink, { pivot = gui.PIVOT_N })
    end
    kit.text(bx + bw - 14, by + 10, "green: warm  red: cold  dashed: not met yet  !: Grudge", "ui14", kit.rgba("#f3e2c0", 0.8),
        { pivot = gui.PIVOT_NE })
end

-- Where the campaign spends its time, and changing course (A18). Ask the table first (free, the
-- group chat answers), nudge with a card they can take up, or force it with a story event.
function M.course(app, x, y, w, bottom)
    local c = app.campaign
    local styles = require "game.model.styles"
    local home = styles.current(c)
    local hd = styles.def(home)
    if not hd then
        return y
    end
    y = head(x, y, "Where the campaign spends its time")
    kit.text(x, y, hd.name, "ui22b", theme.text)
    local keen, unsure = {}, {}
    for _, p in ipairs(c.players) do
        local f = styles.fit(p, home)
        if f >= 1 then
            table.insert(keen, p.name)
        elseif f < 0 then
            table.insert(unsure, p.name)
        end
    end
    local who = (#keen > 0 and ("Keen: " .. table.concat(keen, ", ") .. ". ") or "")
        .. (#unsure > 0 and ("Not sold: " .. table.concat(unsure, ", ") .. ".") or "")
    kit.text(x + kit.width(hd.name, "ui22b") + 14, y + 6, kit.ellipsize(who, "ui14", w - kit.width(hd.name, "ui22b") - 14),
        "ui14", theme.dim)
    y = y + 32
    y = para(x, y, w, hd.pitch, "ui14", theme.dim)
    for _, row in ipairs({ { "Getting around: ", hd.travel and hd.travel.text }, { "Resting: ", hd.rest and hd.rest.text } }) do
        if row[2] then
            y = para(x, y - 2, w, row[1] .. row[2], "ui14", theme.faint)
        end
    end
    -- What's in motion.
    local course = c.course or {}
    local status
    if course.target and course.target ~= home then
        local td = styles.def(course.target)
        local card = content.components[course.force or course.nudge or ""]
        if course.force and card then
            status = { "In this week's hand: " .. card.name .. ". When it plays, the campaign moves to " .. td.name .. ".", theme.orange }
        elseif course.nudge and card then
            status = { "In this week's hand: " .. card.name .. ". If they take it up, the campaign moves to " .. td.name .. ".", theme.teal }
        elseif course.asked then
            status = { "You asked the table about " .. td.name .. " (session " .. util.int(course.asked) .. "). Their answers are in the group chat.", theme.teal }
        end
    elseif course.how and course.to == home and (c.week - (course.week or c.week)) < styles.BLEND_WEEKS then
        local from = styles.def(course.from)
        status = { "Changed course from " .. (from and from.name or "the old style") .. " (session " .. util.int(course.week or c.week) .. "). "
            .. "Whoever liked it better may miss it for a week or two.", theme.dim }
    end
    if status then
        y = para(x, y, w, status[1], "ui14", status[2])
    end
    if y + 120 > bottom then
        return y
    end
    -- Change course: pick where, then how.
    y = head(x, y + 4, "Change course")
    local others = {}
    for _, sid in ipairs(styles.data().order) do
        if sid ~= home then
            table.insert(others, sid)
        end
    end
    local pick = app.course_pick
    if pick == home or not styles.def(pick or "") then
        pick = (course.target ~= home and course.target) or nil
    end
    local bw = (w - 8 * (#others - 1)) / #others
    for k, sid in ipairs(others) do
        local sd = styles.def(sid)
        local on = pick == sid
        kit.button(x + (k - 1) * (bw + 8), y, bw, 30, sd.name, function()
            app.course_pick = sid
            app.refresh_notes()
        end, { font = "ui14", color = on and theme.go or theme.panel2, hover = theme.button_hover, key = "course_style_" .. sid,
               on_hover = hover_with(app, function()
                   local rows = { { sd.name, "ui18b", theme.text }, { sd.pitch, "ui14", theme.dim } }
                   local f = {}
                   for _, p in ipairs(c.players) do
                       local v = styles.fit(p, sid)
                       table.insert(f, p.name .. (v >= 1 and " would love it" or (v < 0 and " isn't sure" or " doesn't mind")))
                   end
                   table.insert(rows, { table.concat(f, ". ") .. ".", "ui14", theme.teal })
                   return rows
               end, x + (k - 1) * (bw + 8), y + 36, 420) })
    end
    y = y + 38
    if not pick then
        return para(x, y, w, "Pick a style to see the ways in.", "ui14", theme.faint)
    end
    local sd = styles.def(pick)
    local prep = c.prep
    local asked = course.target == pick and course.asked
    local nudge = styles.gateway_card(pick, "nudge")
    local force = styles.gateway_card(pick, "force")
    local in_hand = course.target == pick and (course.nudge or course.force)
    local actions = {
        { key = "course_ask", label = asked and "Asked" or "Ask the table", enabled = not asked,
          why = "Free. Post the idea in the group chat and see who's keen. Asking first softens whatever you do next.",
          go = function() styles.ask(c, pick) end },
        { key = "course_nudge", label = "Nudge", enabled = nudge ~= nil and prep ~= nil and not in_hand,
          why = nudge and ("A card in this week's hand: " .. nudge.name .. ". If the party takes it up, the campaign moves to "
              .. sd.name .. ". If they don't, nothing changes.") or "No way in from here.",
          go = function() styles.plan(c, prep, pick, "nudge") end },
        { key = "course_force", label = "Force it", enabled = force ~= nil and prep ~= nil and not in_hand,
          why = force and ("A story event in this week's hand: " .. force.name .. ". When it plays, they're in " .. sd.name
              .. ", like it or not. Anyone who didn't want it takes it as railroading, less so if you asked.") or "No way in from here.",
          go = function() styles.plan(c, prep, pick, "force") end },
    }
    local aw = (w - 16) / 3
    for k, a in ipairs(actions) do
        local ax = x + (k - 1) * (aw + 8)
        kit.button(ax, y, aw, 34, a.label, function()
            a.go()
            app.refresh_notes()
        end, { font = "ui18", enabled = a.enabled, key = a.key,
               on_hover = hover_with(app, function()
                   local rows = { { a.why, "ui14", theme.text } }
                   if not prep and k > 1 then
                       table.insert(rows, { "Only while you're prepping a session.", "ui14", theme.faint })
                   end
                   return rows
               end, ax, y + 40, 380) })
    end
    return y + 42
end

-- People ------------------------------------------------------------------------------------

function M.people(app, x, y, w, h)
    local c = app.campaign
    local met, unmet = {}, {}
    for _, pid in ipairs(ledger.people(c)) do
        if ledger.met(c, pid) then
            table.insert(met, pid)
        else
            table.insert(unmet, pid)
        end
    end
    local cols, gap = 4, 12
    local cw = math.floor((w - (cols - 1) * gap) / cols)
    local rows = math.max(1, math.ceil(#met / cols))
    local unmet_h = 0
    if #unmet > 0 then
        local names = {}
        for _, pid in ipairs(unmet) do
            table.insert(names, ledger.about(pid).name)
        end
        unmet_h = 30 + kit.text_height(table.concat(names, ", "), "ui14", w)
    end
    local ch = math.min(156, math.floor((h - unmet_h - (rows - 1) * gap) / rows))
    for i, pid in ipairs(met) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local px, py = x + col * (cw + gap), y + row * (ch + gap)
        local ab = ledger.about(pid)
        local p = ledger.person(c, pid)
        kit.button(px, py, cw, ch, "", function() end, { color = theme.panel2, hover = theme.panel3, key = "person_" .. pid,
            on_hover = hover_with(app, function() return M.person_rows(app, pid) end,
                col >= 2 and (px - 452) or (px + cw + 10), py) })
        if ab.sprite then
            kit.picture(px + 10, py + 10, 44, 55, "mini_" .. ab.sprite)
        else
            kit.dot(px + 32, py + 36, 44, kit.rgba("#000000", 0.25))
            kit.text(px + 32, py + 36, "?", "ui22b", theme.faint, { pivot = gui.PIVOT_CENTER })
        end
        local tx, tw = px + 64, cw - 74
        local ty = py + 8
        kit.text(tx, ty, ab.name, "ui18b", theme.text, { w = tw })
        ty = ty + kit.text_height(ab.name, "ui18b", tw) + 2
        -- The role and faction if there's room; the hover always has them.
        local def = ledger.data.people[pid] or {}
        local pf = ledger.faction_of(c, pid)
        local status = ledger.status(c, pid)
        local fac = pf and (not def.hidden or p.exposed) and ledger.data[pf].name or nil
        local sub = ab.role ~= "" and ab.role or (fac or "")
        if status ~= "around" and not string.find(string.lower(sub), string.lower(ledger.data.STATUS[status] or status), 1, true) then
            sub = (ledger.data.STATUS[status] or status) .. ". " .. sub
        end
        local sh = kit.text_height(sub, "ui14", tw)
        if ty + sh <= py + ch - 30 then
            kit.text(tx, ty, sub, "ui14", status ~= "around" and theme.orange or theme.gold, { w = tw })
            ty = ty + sh + 4
        end
        -- The last thing that happened between them, if there's room.
        local last = ledger.history(c, pid, app.screen == "night" and app.night or nil)[1]
        if last then
            local lt = ledger.entry_text(c, last, { short_target = true })
            local lw = cw - 20
            local ly2 = math.max(ty, py + 70)
            if ly2 + kit.text_height(lt, "ui14", lw) <= py + ch - 30 then
                kit.text(px + 10, ly2, lt, "ui14", theme.dim, { w = lw })
            end
        end
        att_line(app, px + 10, py + ch - 24, pid)
        -- Who at the table they're warm or cold toward, as dots.
        local wx = px + cw - 12
        for _, wm in ipairs(ledger.warmth(c, pid)) do
            kit.dot(wx - 7, py + ch - 17, 14, wm.n > 0 and theme.green or theme.red)
            kit.picture(wx - 13, py + ch - 23, 12, 12, panels.face(wm.key))
            wx = wx - 18
        end
    end
    if #met == 0 then
        para(x, y, w, "Nobody yet. The people the party meets get a page here: how they feel about the party, and everything that's happened between them.",
            "ui18", theme.faint)
    end
    if #unmet > 0 then
        local names = {}
        for _, pid in ipairs(unmet) do
            table.insert(names, ledger.about(pid).name)
        end
        local uy = y + h - unmet_h
        head(x, uy, "Not met yet", theme.dim)
        kit.text(x, uy + 22, table.concat(names, ", "), "ui14", theme.faint, { w = w })
    end
end

-- Factions ----------------------------------------------------------------------------------

function M.factions(app, x, y, w, h)
    local c = app.campaign
    local order = ledger.data.order
    local gap = 10
    local rh = math.floor((h - (#order - 1) * gap) / #order)
    local plan = planner.summary(c)
    for i, fid in ipairs(order) do
        local fd = ledger.data[fid]
        local ry = y + (i - 1) * (rh + gap)
        kit.button(x, ry, w, rh, "", function() end, { color = theme.panel2, hover = theme.panel3, key = "faction_" .. fid,
            on_hover = hover_with(app, function()
                local rows = { { fd.name, "ui18b", theme.text, 2 }, { "Wants: " .. fd.goal, "ui14", theme.dim } }
                local tl = world.timeline(c, fid)
                if #tl == 0 then
                    table.insert(rows, { "Nothing yet.", "ui14", theme.faint })
                end
                for k = 1, math.min(7, #tl) do
                    local t = tl[k]
                    local secret = t.know == "secret" and " (only you know)" or ""
                    table.insert(rows, { "Session " .. util.int(t.week) .. ": " .. t.text .. secret, "ui14", theme.text, 4 })
                end
                return rows
            end, x + 380, ry + rh - 4, 560) })
        -- Who they are and where they stand.
        local col1 = 360
        kit.text(x + 14, ry + 10, fd.name, "ui22b", theme.text, { w = col1 })
        local gy = ry + 40
        kit.text(x + 14, gy, fd.goal, "ui14", theme.dim, { w = col1 })
        local st = ledger.standing(c, fid)
        local mw = meter(x + 14, ry + rh - 22, st)
        kit.text(x + 22 + mw, ry + rh - 26, ledger.STANDING[st], "ui14", st < 0 and theme.red or (st > 0 and theme.green or theme.dim))
        -- What they're working toward.
        local x2, w2 = x + col1 + 34, 330
        local pr = world.project(c, fid)
        local front
        for _, f in ipairs(plan.fronts) do
            if f.id == fd.front then
                front = f
            end
        end
        if pr then
            head(x2, ry + 10, "Project")
            kit.text(x2, ry + 32, pr.name, "ui18", theme.text, { w = w2 })
            local cw = clock(x2, ry + 60, pr.size, pr.clock, fd.start < 0 and theme.red or theme.teal)
            kit.text(x2 + cw + 8, ry + 56, pr.done and "Done" or (util.int(pr.clock) .. " of " .. util.int(pr.size)), "ui14",
                pr.done and theme.orange or theme.dim)
        elseif front then
            head(x2, ry + 10, "Front")
            kit.text(x2, ry + 32, front.name, "ui18", theme.text, { w = w2 })
            local done = 0
            for _, t in ipairs(front.track) do
                done = done + (t.done and 1 or 0)
            end
            local cw = clock(x2, ry + 60 + (kit.text_height(front.name, "ui18", w2) > 26 and 22 or 0), #front.track, done, theme.red)
            kit.text(x2 + cw + 8, ry + 56, front.doomed and "Doom" or (util.int(done) .. " of " .. util.int(#front.track)
                .. " portents"), "ui14", theme.dim)
        else
            head(x2, ry + 10, "Project", theme.dim)
            kit.text(x2, ry + 32, "Nothing it's working toward right now.", "ui14", theme.faint, { w = w2 })
        end
        -- Members and the latest news.
        local x3, w3 = x2 + w2 + 30, w - (x2 + w2 + 30 - x) - 14
        head(x3, ry + 10, "Members")
        local mx, my = x3, ry + 32
        local members = ledger.members(c, fid)
        if #members == 0 then
            kit.text(mx, my, "Nobody the party knows.", "ui14", theme.faint)
        end
        for _, pid in ipairs(members) do
            local nm = ledger.about(pid).name
            local known = ledger.met(c, pid)
            local label = ledger.label(ledger.att(c, pid))
            local tw = kit.width(nm, "ui14") + 22
            if mx + tw > x3 + w3 then
                mx, my = x3, my + 20
            end
            kit.dot(mx + 6, my + 9, 10, known and (ATT_COLOR[label] or theme.dim) or kit.rgba("#000000", 0.35))
            kit.text(mx + 14, my, nm, "ui14", known and theme.text or theme.faint)
            mx = mx + tw
        end
        local tl = world.timeline(c, fid)
        if tl[1] and my + 26 < ry + rh - 4 then
            local t = tl[1]
            local text = "Session " .. util.int(t.week) .. ": " .. t.text
            local lines = math.max(1, math.floor((ry + rh - 6 - (my + 26)) / 18))
            if kit.text_height(text, "ui14", w3) <= lines * 18 then
                kit.text(x3, my + 26, text, "ui14", theme.dim, { w = w3 })
            else
                kit.text(x3, my + 26, "Hover for what they've been up to.", "ui14", theme.faint, { w = w3 })
            end
        end
    end
end

-- Places ------------------------------------------------------------------------------------

function M.places(app, x, y, w, h)
    local c = app.campaign
    local list = {}
    for _, card in ipairs(content.by_kind.location) do
        local e = deck.entry(c, card.id)
        if e and (e.state == "deck" or e.state == "shelved" or (e.plays or 0) > 0) then
            table.insert(list, card)
        end
    end
    table.sort(list, function(a, b)
        local pa, pb = (deck.entry(c, a.id).plays or 0), (deck.entry(c, b.id).plays or 0)
        if (pa > 0) ~= (pb > 0) then
            return pa > 0
        end
        return a.name < b.name
    end)
    local cols, gap = 2, 14
    local cw = math.floor((w - gap) / cols)
    local per = math.ceil(#list / cols)
    local rh = math.min(74, math.floor((h - (per - 1) * 8) / math.max(1, per)))
    for i, card in ipairs(list) do
        local col, row = math.floor((i - 1) / per), (i - 1) % per
        local px, py = x + col * (cw + gap), y + row * (rh + 8)
        local e = deck.entry(c, card.id)
        local st = ledger.place_state(c, card.id)
        local hist = ledger.at_place(c, card.id)
        kit.button(px, py, cw, rh, "", function() end, { color = theme.panel2, hover = theme.panel3, key = "place_" .. card.id,
            on_hover = hover_with(app, function()
                local rows = { { card.name, "ui18b", theme.text, 2 } }
                if st then
                    table.insert(rows, { st.label, "ui14", theme.teal })
                end
                table.insert(rows, { st and st.line or ((e.plays or 0) > 0 and card.again or card.line) or card.line, "story22", theme.text, 8 })
                for k = 1, math.min(6, #hist) do
                    table.insert(rows, { "Session " .. util.int(hist[k].w) .. ": " .. ledger.entry_text(c, hist[k]), "ui14", theme.dim, 3 })
                end
                return rows
            end, col == 0 and (px + cw + 10) or (px - 470), py, 460) })
        kit.text(px + 12, py + 8, card.name, "ui18b", theme.text, { w = cw - 150 })
        local visits = e.plays or 0
        local tag = e.state == "shelved" and "Shelved" or (visits == 0 and "Not visited" or
            (visits == 1 and "Visited once" or ("Visited " .. util.int(visits) .. " times")))
        kit.text(px + cw - 12, py + 10, tag, "ui14", visits > 0 and theme.teal or theme.faint, { pivot = gui.PIVOT_NE })
        local line = st and st.label or (hist[1] and ("Last: " .. ledger.entry_text(c, hist[1])) or nil)
        if line and kit.text_height(line, "ui14", cw - 24) <= rh - 36 then
            kit.text(px + 12, py + 32, line, "ui14", st and theme.orange or theme.dim, { w = cw - 24 })
        end
    end
end

-- Threads -----------------------------------------------------------------------------------

local STEP = { done = { "Done", theme.green }, open = { "In your deck", theme.gold }, coming = { "Next week", theme.teal },
               locked = { "Not opened yet", theme.faint } }

function M.threads(app, x, y, w, h)
    local c = app.campaign
    local threads = deck.threads(c)
    local gap = 14
    local cw = math.floor((w - 3 * gap) / 4)
    for k, p in ipairs(c.players) do
        local px = x + (k - 1) * (cw + gap)
        kit.box(px, y, cw, h, theme.panel2, { radius = 10 })
        kit.dot(px + 30, y + 30, 40, panels.COLORS[p.key] or theme.panel3)
        kit.picture(px + 12, y + 12, 36, 36, panels.face(p.key))
        kit.text(px + 58, y + 12, p.char, "ui18b", theme.text, { w = cw - 66 })
        local featured = planner.featured(c, p.key)
        kit.text(px + 58, y + 34, p.name .. (featured and ", featured" or ""), "ui14", featured and theme.gold or theme.dim)
        local ty = y + 64
        ty = para(px + 12, ty, cw - 24, util.capitalize(p.thread or ""), "ui14", theme.text)
        ty = ty + 4
        for _, st in ipairs(threads[p.key] or {}) do
            local s = STEP[st.state]
            local name = st.state == "locked" and "?" or st.card.name
            local nh = kit.text_height(name, "ui14", cw - 40)
            if ty + nh + 22 > y + h - 8 then
                break
            end
            kit.dot(px + 18, ty + 9, 12, s[2])
            kit.text(px + 30, ty, name, "ui14", st.state == "locked" and theme.faint or theme.text, { w = cw - 40 })
            ty = ty + nh
            local how = st.how and (" (" .. (st.how == "win" and "won" or (st.how == "lose" and "lost" or st.how)) .. ")") or ""
            kit.text(px + 30, ty, s[1] .. how, "ui14", s[2])
            ty = ty + 24
        end
    end
end

-- The session log (M8, B7): every session report, kept. Pick a week to reopen its recap: the
-- title you chose, the beats you kept (pinned ones marked), your note, the verdict and how each
-- player felt.
local VERDICT_COLOR = { ["One for the stories"] = theme.gold, ["Great session"] = theme.green, ["Good session"] = theme.teal,
                        Okay = theme.dim, ["Rough night"] = theme.orange }
local TIER_COLOR = { loved = theme.green, fun = theme.teal, fine = theme.gold, bored = theme.orange, out = theme.red }

function M.session_log(app, x, y, w, h)
    local log = app.campaign.session_log or {}
    if #log == 0 then
        para(x, y, w, "No sessions yet. Every session report is kept here once the night is over.", "ui18", theme.faint)
        return
    end
    -- The weeks, newest first, down the left.
    local pick = app.log_week
    local found
    for _, e in ipairs(log) do
        found = found or (e.week == pick and e)
    end
    found = found or log[#log]
    app.log_week = found.week
    local lx, ly = x, y
    for i = #log, 1, -1 do
        local e = log[i]
        if ly + 40 > y + h then
            break
        end
        local on = e == found
        local t = e.recap and e.recap.titles and e.recap.titles[e.recap.title or 1] or ("Session " .. util.int(e.week))
        kit.button(lx, ly, 300, 36, util.int(e.week) .. ".  " .. kit.ellipsize(t, "ui14", 250), function()
            app.log_week = e.week
            app.refresh_notes()
        end, { font = "ui14", color = on and theme.go or theme.panel2, hover = theme.button_hover, align = "left",
               key = "log_week_" .. util.int(e.week) })
        ly = ly + 42
    end
    -- The chosen session.
    local px, pw = x + 324, w - 324
    local e = found
    local r = e.recap or {}
    local title = r.titles and r.titles[r.title or 1] or ("Session " .. util.int(e.week))
    kit.text(px, y - 4, "SESSION " .. util.int(e.week), "ui14", theme.gold)
    kit.text(px, y + 16, title, "title30", theme.text)
    local vc = VERDICT_COLOR[e.verdict] or theme.dim
    kit.text(px + pw, y + 24, e.verdict or "", "ui18b", vc, { pivot = gui.PIVOT_NE })
    local ty = y + 66
    ty = head(px, ty, "The recap")
    local any = false
    for _, b in ipairs(r.beats or {}) do
        if not b.cut and ty < y + h - 230 then
            any = true
            if b.pinned then
                kit.icon(px, ty + 3, 14, "reward", theme.gold)
            end
            ty = para(px + 22, ty, pw - 22, b.text, "ui18", b.pinned and theme.gold or theme.text)
        end
    end
    if not any then
        ty = para(px, ty, pw, "Nothing kept from this one.", "ui18", theme.faint)
    end
    if (r.note or "") ~= "" then
        ty = para(px, ty + 4, pw, "Your note: " .. r.note, "hand24", kit.rgba("#f3df8a"))
    end
    ty = head(px, ty + 10, "How the table felt")
    for _, row in ipairs(e.players or {}) do
        if ty + 24 > y + h then
            break
        end
        kit.text(px, ty, row.name, "ui18b", theme.text)
        kit.text(px + 70, ty + 2, row.char or "", "ui14", theme.dim)
        local q = row.quote and ('"' .. row.quote .. '"') or (row.fun and "" or "Wasn't there.")
        kit.text(px + 190, ty + 2, kit.ellipsize(q, "ui14", pw - 190), "ui14", TIER_COLOR[row.tier] or theme.text)
        ty = ty + 26
    end
end

return M
