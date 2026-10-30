-- The DM's notes (real-session pass, grown into the campaign notebook in the slice rework):
-- the binder behind the screen. Open it with N or the Notes button on prep, game night and
-- the report; game night waits while it's open.
--   This week      the world's moves off screen, who this session is for, who shows up
--   This session   what tonight is for, the opening to read, the story cards and the board
--   Campaign       the plan: premise, truths, fronts and their portents, shelved cards
--   People         everyone the party has met: attitude, status, history (hover for it all)
--   Factions       standing, projects and fronts, members, what they've been up to
--   Places         where the party has been, what changed, what happened there
--   The web        the big questions, and who's tied to whom
--   Story log      each storyline told so far, scene by scene (game/ui/story_log_view.lua); the
--                  Storylines tab (a tile per storyline that only led here) went into it, October 20
--   Story so far   the campaign's secrets, every session's clues and moments, seeds in play
--   Session log    every session's report, kept
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

local pages = require "game.ui.notebook_pages"

local X, Y, W, H = 110, 44, 1380, 816
-- The binder's tabs, down its left edge (the slice rework adds the campaign organizer).
local TABS = { { "week", "This week" }, { "session", "This session" }, { "campaign", "Campaign" },
               { "people", "People" }, { "factions", "Factions" }, { "places", "Places" }, { "web", "The web" },
               { "storylog", "Story log" }, { "story", "Story so far" }, { "log", "Session log" }, { "party", "The party" } }
M.TABS = TABS
-- v2: the museum's notebook is its own (the old story's tabs have nothing to say about it).
local MUSEUM_TABS = { { "museum", "The museum" }, { "upstairs", "Upstairs" }, { "session", "This session" },
                      { "people", "People" }, { "log", "Session log" }, { "party", "The party" } }
M.MUSEUM_TABS = MUSEUM_TABS
local function tabs_for(app)
    return (app.campaign and app.campaign.module) and MUSEUM_TABS or TABS
end

-- The museum, room by room: the map, what each room left behind, and why the heroes came.
local function tab_museum(app, x, y, w, h)
    local adventure = require "game.model.adventure"
    local MODULE = adventure.data
    local c = app.campaign
    local st = c.adv
    util.lazy("game.ui.museum_prep_view").draw_map(app, x, y, 420, 330)
    local rx, ry = x + 440, y
    kit.text(rx, ry, "ROOM BY ROOM", "ui14", theme.dim)
    ry = ry + 22
    for _, id in ipairs(MODULE.order) do
        local r = MODULE.rooms[id]
        if not r.virtual then
            local state = st.done[id] and (st.done[id] == "win" and "Done" or "Done, roughly") or (st.skipped[id] and "Left behind")
                or (id == st.at and "Next") or "Ahead"
            local col = st.done[id] and theme.green or (st.skipped[id] and theme.faint or (id == st.at and theme.gold or theme.dim))
            kit.text(rx, ry, r.name, "ui18b", st.skipped[id] and theme.faint or theme.text)
            kit.text(rx + 270, ry + 2, state, "ui14", col)
            local marks = {}
            for _, mid in ipairs(st.mark_list) do
                if st.marks[mid].room == id then
                    table.insert(marks, MODULE.marks[mid].name)
                end
            end
            local line = #marks > 0 and ("Left on Euryale's card: " .. table.concat(marks, ", ") .. ".") or r.sum
            kit.text(rx, ry + 22, line, "ui14", #marks > 0 and theme.gold or theme.faint, { w = w - 460, lines = 1 })
            ry = ry + 46
        end
    end
    local hy = y + 350
    kit.text(x, hy, "WHY THEY CAME", "ui14", theme.dim)
    hy = hy + 22
    for _, p in ipairs(c.players) do
        local hk = adventure.hook(c, p.key)
        if hk then
            kit.text(x, hy, p.char .. ": " .. hk.name, "ui18b", theme.text)
            kit.text(x, hy + 22, hk.text, "ui14", theme.dim, { w = 420, lines = 2 })
            hy = hy + 66
        end
    end
    kit.text(x, y + h - 22, MODULE.credit, "ui14", theme.faint, { w = w })
end

-- Upstairs: Euryale's card, and the fair-warning bank.
local function tab_upstairs(app, x, y, w, h)
    local c = app.campaign
    util.lazy("game.ui.museum_prep_view").boss_card(app, x, y, 640, h - 40, true)
    local bx = x + 664
    kit.text(bx, y, "FAIR WARNING", "ui14", theme.dim)
    kit.text(bx, y + 22, util.int(c.adv.bank or 0) .. " in the bank", "ui22b", theme.teal)
    kit.text(bx, y + 56, "Every chance the party takes after a warning goes in the bank. A harsh call spends one, and the table "
        .. "takes it as fair. A harsh call with nothing in the bank feels arbitrary, and costs you their Trust.", "ui14", theme.dim,
        { w = w - 664 })
    kit.text(bx, y + 170, "HARSH CALLS SO FAR", "ui14", theme.dim)
    kit.text(bx, y + 192, util.int(c.adv.harsh.paid) .. " fair, " .. util.int(c.adv.harsh.unpaid) .. " arbitrary", "ui18b",
        c.adv.harsh.unpaid > 0 and theme.orange or theme.text)
    kit.text(bx, y + 240, "FLITWIDGET FRANCS", "ui14", theme.dim)
    kit.text(bx, y + 262, util.int(c.adv.francs or 0), "ui22b", theme.gold)
end

-- The museum's people: who they've met, and what they know of them.
local function tab_museum_people(app, x, y, w, h)
    local adventure = require "game.model.adventure"
    local c = app.campaign
    local met = c.story and c.story.met or {}
    for _, pp in ipairs(adventure.data.people) do
        local seen = pp.known or met[pp.id] or (pp.id == "mus_telpur" and c.adv.done.gift_shop)
            or (pp.id == "mus_mech" and c.adv.done.tomorrow)
        kit.text(x, y, pp.name, "ui22b", seen and theme.text or theme.faint)
        kit.text(x + 320, y + 6, pp.role, "ui14", theme.dim)
        kit.text(x, y + 30, seen and pp.about or "Not met yet.", "ui18", seen and theme.dim or theme.faint, { w = w })
        y = y + 86
    end
end
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
    pages.drop_hover(app)
    require("game.ui.story_log_view").drop_hover(app)
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
                state, scol = "On stop " .. util.int(placed), theme.gold
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
        kit.text(rx, ry, "Stop " .. util.int(i) .. ":  " .. tname, "ui18b", s.type and theme.text or theme.faint)
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
                -- (A place two scenes shared is said once.)
                local places, seen = {}, {}
                for _, name in ipairs(week.scenes) do
                    if not seen[name] then
                        seen[name] = true
                        table.insert(places, name)
                    end
                end
                ry = para(rx + 22, ry, rw - 22, "Where they went: " .. table.concat(places, ", "), "ui14", theme.text)
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

-- The party -------------------------------------------------------------------------------------------------

local function tab_party(app, x, y, w, h)
    local c = app.campaign
    local gap = 14
    -- The shelf of fallen heroes (B3) along the bottom, when there's anyone on it.
    local fallen = M.fallen_rows(app)
    if #fallen > 0 then
        local fh = 30 + math.min(3, #fallen) * 20
        h = h - fh - 10
        kit.text(x, y + h + 12, "THE SHELF OF FALLEN HEROES", "ui14", theme.gold)
        for i = 1, math.min(3, #fallen) do
            kit.text(x, y + h + 12 + i * 20, kit.ellipsize(fallen[i], "ui14", w), "ui14", theme.dim)
        end
    end
    local cw = math.floor((w - 3 * gap) / 4)
    for i, p in ipairs(c.players) do
        local px = x + (i - 1) * (cw + gap)
        kit.box(px, y, cw, h, theme.panel2, { radius = 10 })
        kit.dot(px + 50, y + 50, 80, panels.COLORS[p.key] or theme.panel3)
        kit.picture(px + 12, y + 12, 76, 76, panels.face(p.key))
        kit.picture(px + cw - 72, y + 10, 60, 75, panels.mini(p))
        local py = y + 98
        kit.text(px + 14, py, p.name, "ui22b", theme.text)
        kit.text(px + 14 + kit.width(p.name, "ui22b") + 8, py + 6, "plays " .. p.char, "ui18", theme.gold,
            { w = cw - 36 - kit.width(p.name, "ui22b") })
        py = py + 34
        local level = c.level or 2
        local sub = level >= 3 and c.subclasses and c.subclasses[p.class]
        local subs = require "game.rules.subclasses"
        local line = p.class_name .. ", level " .. util.int(level)
        if sub and subs.list[sub] then
            line = line .. ", " .. subs.list[sub].name
        end
        py = para(px + 14, py, cw - 28, line, "ui18", theme.text)
        py = head(px + 14, py + 6, "Backstory hook")
        py = para(px + 14, py, cw - 28, util.capitalize(p.thread or ""), "ui18", theme.text)
        -- What Session Zero wrote in, and everything since: their Story log.
        local written = require("game.model.backstory").written(c, p.key, p.char)
        kit.button(px + 14, py, cw - 28, 26, written and "Their past, as you wrote it" or "Their Story log", function()
            app.storylog_id = "bs_" .. p.key
            app.storylog_scroll = nil
            app.notes_tab = "storylog"
            M.draw(app)
        end, { font = "ui14", color = theme.panel3, hover = theme.button_hover, key = "party_storylog_" .. p.key })
        py = py + 32
        py = head(px + 14, py + 6, "At the table")
        py = para(px + 14, py, cw - 28, p.notes or "", "ui14", theme.dim)
        -- What Session Zero wrote into their past (as much as there's room for; the Story log has it all).
        local lines = require("game.model.backstory").lines(c, p.key, p.char)
        if lines and #lines > 0 and py + 60 < y + h - 140 then
            py = head(px + 14, py + 6, "Written at Session Zero")
            for _, l in ipairs(lines) do
                if py + kit.text_height(l, "ui14", cw - 28) > y + h - 140 then
                    break
                end
                py = para(px + 14, py, cw - 28, l, "ui14", theme.text)
            end
        end
        -- How they get on with the others (A17).
        local rapport = require "game.model.rapport"
        local bits = {}
        for _, q in ipairs(c.players) do
            if q ~= p then
                local word = rapport.word(c, p.key, q.key)
                if word and word ~= "Fine" then
                    table.insert(bits, word .. " with " .. q.name)
                end
            end
        end
        if #bits > 0 then
            py = head(px + 14, py + 6, "With the others")
            py = para(px + 14, py, cw - 28, table.concat(bits, ". ") .. ".", "ui14", theme.text)
        end
        if not p.present then
            py = para(px + 14, py + 4, cw - 28, p.on_break and "Taking a break from Thursdays." or "Out this week.", "ui14",
                theme.orange)
        end
        -- What they've been through (B2, B3): a reputation, a scar, the hero they lost.
        local fails = require "game.model.fails"
        local rep = fails.reputation(c, p.key)
        if rep then
            py = para(px + 14, py + 4, cw - 28, "Known at the table as " .. rep .. ".", "ui14", theme.purple)
        end
        if p.scar then
            py = para(px + 14, py + 2, cw - 28, p.scar, "ui14", theme.dim)
        end
        if p.old_char then
            py = para(px + 14, py + 2, cw - 28, "Used to play " .. p.old_char .. ". They're on the shelf now.", "ui14", theme.faint)
        end
        kit.button(px + 14, y + h - 54, cw - 28, 40, "Character sheet", function()
            M.close(app)
            if app.open_sheet then
                app.open_sheet(p.key)
            end
        end, { font = "ui18b", key = "notes_sheet_" .. p.key })
    end
end

-- The shelf of fallen heroes (B3), under the party: name, class, level, how they fell, and the
-- reputation they had.
function M.fallen_rows(app)
    local rows = {}
    for _, f in ipairs(app.campaign.fallen or {}) do
        local p = app.campaign:player(f.key)
        table.insert(rows, f.char .. " (" .. (p and p.name or "?") .. "), " .. util.capitalize(f.class or "hero") .. " " .. util.int(f.level or 1)
            .. ": " .. f.how .. ", session " .. util.int(f.week) .. (f.rep and (". Remembered as " .. f.rep .. ".") or "."))
    end
    return rows
end

-- Anything in the binder waiting on you this week (the dot on its tab and on the prep board).
-- A thread that moved this week (a story card that follows from how one went): a dot on the
-- Story log tab until you've looked (A6).
function M.threads_moved(app)
    local camp = app.campaign
    if not (camp and camp.prep) then
        return false
    end
    if app.notes_seen and app.notes_seen.storylog == camp.week then
        return false
    end
    local deck = require "game.model.deck"
    for _, kind in ipairs(content.kinds) do
        for _, c in ipairs(camp.prep.hand[kind] or {}) do
            if c.thread and deck.is_new(camp, c.id) then
                return true
            end
        end
    end
    return false
end

function M.attention(app)
    local out = {}
    if app.campaign and app.campaign.prep and pages.week_pending(app) > 0 then
        out.week = true
    end
    if M.threads_moved(app) then
        out.storylog = true
    end
    return out
end

function M.draw(app)
    pages.drop_hover(app)
    require("game.ui.story_log_view").drop_hover(app)
    if app.notes_layer then
        kit.drop(app.notes_layer)
    end
    local l = kit.layer("notes", true)
    app.notes_layer = l
    app.refresh_notes = app.refresh_notes or function()
        if app.overlay == "notes" then
            M.draw(app)
        end
    end
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#000000", 0.55), { round = false })
    kit.box(X, Y, W, H, theme.bg, { radius = 14 })
    kit.box(X, Y, W, 60, theme.panel, { radius = 14 })
    kit.text(X + 24, Y + 14, "YOUR NOTES", "title30", theme.gold)
    local tab = app.notes_tab or "session"
    if tab == "threads" then
        tab = "storylog"     -- (the old Storylines tab)
        app.notes_tab = tab
    end
    local TABS = tabs_for(app)
    if app.campaign and app.campaign.module and (tab == "storylog" or tab == "story" or tab == "week" or tab == "campaign") then
        tab = "museum"
        app.notes_tab = tab
    end
    local known = false
    for _, t in ipairs(TABS) do
        known = known or t[1] == tab
    end
    if not known then
        tab = "session"
        app.notes_tab = tab
    end
    -- Seen (its dot goes), however you got here: a tab, S, a link on the board.
    app.notes_seen = app.notes_seen or {}
    app.notes_seen[tab] = app.campaign and app.campaign.week
    -- The tabs down the left, like a binder's dividers.
    local attn = M.attention(app)
    local ty = Y + 76
    for _, t in ipairs(TABS) do
        local on = tab == t[1]
        kit.button(X + 14, ty, 168, 38, t[2], function()
            app.notes_tab = t[1]
            app.notes_seen = app.notes_seen or {}
            app.notes_seen[t[1]] = app.campaign and app.campaign.week
            M.draw(app)
        end, { font = "ui18b", color = on and theme.go or theme.panel2, hover = theme.button_hover, align = "left", pad_y = 9,
               key = "notes_tab_" .. t[1] })
        if attn[t[1]] then
            kit.dot(X + 170, ty + 19, 12, theme.orange)
        end
        ty = ty + 44
    end
    local title = ""
    for _, t in ipairs(TABS) do
        if t[1] == tab then
            title = t[2]
        end
    end
    kit.text(X + 260, Y + 20, string.upper(title), "ui18b", theme.dim)
    kit.button(X + W - 130, Y + 12, 110, 36, "Close", function()
        if app.close_overlay then
            app.close_overlay()
        else
            M.close(app)
        end
    end, { font = "ui18b", key = "notes_close" })
    kit.text(X + W - 144, Y + 22, "N or Esc", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    local cx, cy = X + 204, Y + 76
    local cw, ch = W - 204 - 24, H - 76 - 22
    if tab == "museum" then
        tab_museum(app, cx, cy, cw, ch)
    elseif tab == "upstairs" then
        tab_upstairs(app, cx, cy, cw, ch)
    elseif tab == "people" and app.campaign and app.campaign.module then
        tab_museum_people(app, cx, cy, cw, ch)
    elseif tab == "week" then
        pages.week(app, cx, cy, cw, ch)
    elseif tab == "session" then
        tab_session(app, cx, cy, cw)
    elseif tab == "campaign" then
        pages.campaign(app, cx, cy, cw, ch)
    elseif tab == "web" then
        pages.web(app, cx, cy, cw, ch)
    elseif tab == "people" then
        pages.people(app, cx, cy, cw, ch)
    elseif tab == "factions" then
        pages.factions(app, cx, cy, cw, ch)
    elseif tab == "places" then
        pages.places(app, cx, cy, cw, ch)
    elseif tab == "storylog" then
        require("game.ui.story_log_view").page(app, cx, cy, cw, ch)
    elseif tab == "story" then
        tab_story(app, cx, cy, cw)
    elseif tab == "log" then
        pages.session_log(app, cx, cy, cw, ch)
    else
        tab_party(app, cx, cy, cw, ch)
    end
end

return M
