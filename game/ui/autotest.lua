-- In-engine autotest (M7): plays the real build by itself so the engine-only parts
-- (sound, light, snacks, saving to disk) get exercised where the headless tests can't
-- reach. Off unless the build sets behind_the_screen.autotest = 1 (tools/tests/autotest.ini).
-- It clicks buttons by calling them, prints "AUTOTEST ..." lines (an outside script takes
-- screenshots on "AUTOTEST shot <name>"), and quits when it's done:
--   autotest = 1   new campaign: Session Zero, two sessions, quit at the third prep
--   autotest = 2   continue the saved campaign, play one more session, quit
--   autotest = 3   new campaign: Session Zero and one session, quit at its report (screen-size checks)
--   autotest = 4   the real-session pass, shown off: a story board with a built fight, the notes,
--                  a character sheet and the encounter builder, then game night with shots of a
--                  skill check, a clue, a decision, a fight and a spell; quit at the report
--   autotest = 5   real clicks (tools/tests/ui_play/): drive every screen at 2x, but leave every
--                  game-night card for an outside harness to click with real X input; quit after
--                  behind_the_screen.autotest_weeks sessions (default 6)
--   autotest = 6   the board gallery: every board (game/data/boards.lua) set out in full on the
--                  table, with a party and some foes on it, one shot each from the table camera
--   autotest = 7   the whole first act, shown off: a DM who follows the arc and levels the party
--                  up; with keyart = 1, clean shots of every night from the second on, the last
--                  week's prep and notebook, the gifts on the table, and the scrapbook; quit there

local kit = require "game.ui.kit"

local M = {}

local STEP = 0.35      -- seconds between actions
local SHOT_WAIT = 1.6  -- seconds to hold still after asking for a screenshot

-- Printed, and appended to autotest.log beside the save (release builds don't print).
local function say(text)
    print("AUTOTEST " .. text)
    pcall(function()
        local f = io.open(sys.get_save_file("behind_the_screen", "autotest.log"), "a")
        if f then
            f:write("AUTOTEST ", text, "\n")
            f:close()
        end
    end)
end

local function buttons()
    local out = {}
    for i = #kit.layers, 1, -1 do
        local l = kit.layers[i]
        for _, b in ipairs(l.buttons) do
            if b.enabled then
                table.insert(out, b)
            end
        end
        if l.modal then
            break
        end
    end
    return out
end

local function press(b)
    if kit.on_press then
        kit.on_press(b)
    end
    b.on_click(b)
end

local function by_key(k)
    for _, b in ipairs(buttons()) do
        if b.key == k then
            press(b)
            return true
        end
    end
    return false
end

local function by_label(prefix)
    for _, b in ipairs(buttons()) do
        local text = b.label and gui.get_text(b.label) or ""
        if string.sub(text, 1, #prefix) == prefix then
            press(b)
            return true
        end
    end
    return false
end

function M.start(app, mode)
    app.autotest = { mode = mode, t = 0, wait = 1.5, shots = {}, weeks = 0 }
    -- Key art (behind_the_screen.keyart = 1, with mode 4): clean shots of the table too.
    local ok, ka = pcall(sys.get_config_int, "behind_the_screen.keyart", 0)
    app.autotest.keyart = ok and ka == 1 or nil
    say("start mode " .. mode)
end

local function shot(a, name)
    if not a.shots[name] then
        a.shots[name] = true
        say("shot " .. name)
        a.wait = SHOT_WAIT
        return true
    end
    return false
end

-- Key art (behind_the_screen.keyart = 1, with mode 4): the first time the night waits on a card in
-- a story scene, again on a fight's card, and once a fight's minis are on the mat, the screens go
-- and the table is shot from the room, the table and the imagination cameras (for store pages and
-- the website). Then the screens come back and the night goes on.
local KEYART_ZOOMS = { 1, 2, 3 }

-- The render script leaves out every screen (the game's and the HUD's) while this is on.
local function set_ui(on, a)
    msg.post("@render:", "clean", { on = not on })
end

function M.keyart(app, a, tag)
    local k = a.ka
    if not k then
        a.ka = { tag = tag, i = 0, zoom0 = app.camera_index or 2, speed = app.speed_i }
        app.speed_i = 1     -- (the slowest: a fight barely moves while it's shot)
        set_ui(false, a)
        a.wait = 0.5
        return true
    end
    if k.pend then
        say("shot " .. k.pend)
        k.pend = nil
        a.wait = SHOT_WAIT
        return true
    end
    k.i = k.i + 1
    local z = KEYART_ZOOMS[k.i]
    if not z then
        app.zoom(k.zoom0)
        set_ui(true, a)
        if k.speed then
            app.speed_i = k.speed
        end
        a.ka_done = a.ka_done or {}
        a.ka_done[k.tag] = true
        a.ka = nil
        a.wait = 1.0
        return true
    end
    app.zoom(z)
    k.pend = "keyart_" .. k.tag .. "_z" .. z
    a.wait = 3.0     -- (the camera glides there)
    return true
end

local function finish(a, ok, why)
    say((ok and "done " or "FAILED ") .. (why or ""))
    a.over = true
    sys.exit(ok and 0 or 1)
end

-- Mode 1, at the prep for session 3: the Story log (October 13) after two real nights. The page
-- in the notes on the storyline with the most scenes, then the panel the prep board opens when a
-- story card goes on a scene, then a keyword's hover. One step per call.
function M.story_shots(app, a)
    a.ss = (a.ss or 0) + 1
    local step = a.ss
    local chronicle = require "game.model.chronicle"
    local storylines = require "game.model.storylines"
    local content = require "game.model.content"
    local kit = require "game.ui.kit"
    local c = app.campaign
    if step == 1 then
        local best, most = nil, -1
        for _, it in ipairs(chronicle.list(c, c.prep, nil)) do
            local v = chronicle.story(c, it.def.id, {})
            if v and #v.entries > most then
                best, most = it.def.id, #v.entries
            end
        end
        say("story log: " .. tostring(best) .. " with " .. tostring(most) .. " scenes, " .. #chronicle.get(c).scenes .. " filed")
        app.storylog_id = best
        app.storylog_scroll = nil
        app.open_notes("storylog")
        shot(a, "storylog_page")
        return true
    elseif step == 2 then
        app.close_overlay()
        local p = c.prep
        if not p.scenes[1].type then
            p:set_type(1, "social")
        end
        local placed
        for _, kind in ipairs(content.kinds) do
            for _, card in ipairs(p.hand[kind] or {}) do
                if not placed and kind ~= "location" and #storylines.of_card(c, card) > 0 and not p:placed_at(card.id)
                    and p:can_place(1, card.id) then
                    for _, sid in ipairs(storylines.of_card(c, card)) do
                        placed = placed or (string.sub(sid, 1, 3) == "bs_" and card) or nil
                    end
                    if placed then
                        p:place(1, card.id)
                    end
                end
            end
        end
        say("story panel: placed " .. tostring(placed and placed.id))
        if placed then
            require("game.ui.story_log_view").on_placed(app, placed)
        else
            require("game.ui.story_log_view").toggle_panel(app)
        end
        app.refresh()
        shot(a, "story_panel")
        return true
    elseif step == 3 then
        -- Point at the first lit name in the panel.
        for i = #kit.layers, 1, -1 do
            for _, b in ipairs(kit.layers[i].buttons) do
                if b.rect_hit and string.sub(b.key or "", 1, 3) == "kw_" and string.sub(b.key, 1, 8) ~= "kw_term_" then
                    local r = b.rect
                    kit.on_move(r[1] + r[3] / 2, kit.H - (r[2] + r[4] / 2))
                    say("story keyword: " .. b.key)
                    shot(a, "story_keyword")
                    return true
                end
            end
        end
        return true
    elseif step == 4 then
        -- The storyline's name: the whole story at a glance.
        for i = #kit.layers, 1, -1 do
            for _, b in ipairs(kit.layers[i].buttons) do
                if b.key == "story_panel_title" then
                    local r = b.rect
                    kit.on_move(r[1] + r[3] / 2, kit.H - (r[2] + r[4] / 2))
                    shot(a, "story_glance")
                    return true
                end
            end
        end
        return true
    end
    return false
end

-- Mode 7: the whole first act, shown off (October 27, for store and pitch shots). Every week the
-- DM follows the arc the way tools/sim/slice_bots.lua's careful DM does: this week's story cards
-- where they fit, and a fight at the last stop. The party levels up when it's earned (the
-- moment gets a shot), and the last week's prep and notebook are shot a step at a time.
local function act_board(app)
    local content = require "game.model.content"
    local c, p = app.campaign, app.campaign.prep
    p.extra = (p.extra or 0) - 10     -- (time for the whole story)
    p:set_type(1, "social")
    p:set_type(2, "exploration")
    p:set_type(3, "combat")
    local beat = c:arc_beat()
    if not beat then
        return
    end
    local first = content.components[beat.cards[1]]
    local fits_any = false
    for i = 1, 3 do
        for _, f in ipairs(first and first.fits or {}) do
            fits_any = fits_any or f == p.scenes[i].type
        end
    end
    if first and not fits_any and p.arc_cards[first.id] then
        p:set_type(1, first.fits[1])
    end
    for _, id in ipairs(beat.cards) do
        local card = content.components[id]
        if card and p.arc_cards[id] and not p:placed_at(id) then
            for i = 1, 3 do
                local s = p.scenes[i]
                local fits = false
                for _, f in ipairs(card.fits) do
                    fits = fits or f == s.type
                end
                fits = fits and content.belongs_at(card, s.slots.location)
                for _, other in pairs(s.slots) do
                    if card.kind == "location" and other.kind ~= "location" then
                        fits = fits and content.belongs_at(other, card)
                    end
                end
                if fits and not s.slots[card.kind] and p:can_place(i, id) then
                    p:place(i, id)
                    break
                end
            end
        end
    end
    if beat.finale and p.arc_cards.cliffhanger and not p:placed_at("cliffhanger") then
        p:clear(3, "complication")
        p:place(3, "cliffhanger")
    end
end

local function last_week(app)
    return app.campaign.week >= require("game.model.content").arc.SESSIONS
end

-- This week's prep, one action per call.
function M.act_plan(app, a)
    local c = app.campaign
    local steps = require "game.ui.prep_steps"
    local plan = {}
    local function add(fn)
        table.insert(plan, fn)
    end
    add(function()
        app.close_overlay()
        act_board(app)
        a.wait = 0.5
    end)
    if c:level_status().ready then
        add(function()
            steps.go(app, "levelup")
            a.wait = 0.8
        end)
        add(function()
            by_key("level_up")
            a.wait = 2.5      -- (the moment's sound and their lines)
        end)
        add(function()
            if app.levelup then
                shot(a, "act_levelup_" .. tostring(app.levelup.level))
            end
        end)
        add(function()
            by_key("levelup_close")
            a.wait = 0.8
        end)
    end
    if last_week(app) then
        for _, id in ipairs({ "story", "friends", "route_1", "ready" }) do
            add(function()
                steps.go(app, id)
                a.wait = 1.4
            end)
            add(function()
                shot(a, "act_prep_" .. id)
            end)
        end
        for _, tab in ipairs({ "storylog", "web", "party" }) do
            add(function()
                if tab == "storylog" then
                    local chronicle = require "game.model.chronicle"
                    local best, most = nil, -1
                    for _, it in ipairs(chronicle.list(c, c.prep, nil)) do
                        local v = chronicle.story(c, it.def.id, {})
                        if v and #v.entries > most then
                            best, most = it.def.id, #v.entries
                        end
                    end
                    app.storylog_id = best
                    app.storylog_scroll = nil
                end
                app.open_notes(tab)
                a.wait = 1.2
            end)
            add(function()
                shot(a, "act_notes_" .. tab)
            end)
        end
        add(function()
            app.close_overlay()
            a.wait = 0.5
        end)
    end
    add(function()
        steps.go(app, "ready")
        app.refresh()
        if not by_label("Run game night") then
            return finish(a, false, "no Run game night button")
        end
        if app.ask then
            by_label(app.ask.yes or "Run game night")
        end
        say("night " .. c.week)
    end)
    return plan
end

function M.act_prep(app, a)
    if app.convo then
        app.convo = nil
        app.refresh()
        return
    end
    local wk = app.campaign.week
    if not a.act or a.act.week ~= wk then
        a.act = { week = wk, plan = M.act_plan(app, a), i = 0 }
    end
    a.act.i = a.act.i + 1
    local fn = a.act.plan[a.act.i]
    if fn then
        return fn()
    end
end

-- Key art on game night: mode 4's one night, or mode 7's nights from the second on (each week's
-- shots tagged with the week); the rest of the showing off on mode 7's last night only.
local function keyart_on(app, a)
    return a.keyart and (a.mode == 4 or (a.mode == 7 and app.campaign.week >= 2))
end

local function ka_tag(app, a, tag)
    return a.mode == 7 and (tag .. "_w" .. app.campaign.week) or tag
end

local function showy(app, a)
    return a.mode == 4 or (a.mode == 7 and last_week(app))
end

-- Mode 4: a board that tells this week's story, a fight built for the party, and a look at
-- the notes, a sheet and the builder. One step per call, so each screen gets its shot.
function M.showcase(app, a)
    local p = app.campaign.prep
    a.sc = a.sc or 0
    a.sc = a.sc + 1
    local step = a.sc
    if step == 1 then
        app.close_overlay()
        p.extra = (p.extra or 0) - 10     -- plenty of prep time for the show
        p:set_type(1, "social")
        p:set_type(2, "exploration")
        p:set_type(3, "combat")
        for _, id in ipairs({ "tavern", "gus", "stranger" }) do
            p:place(1, id)
        end
        for _, kind in ipairs({ "location", "goal" }) do
            for _, c in ipairs(p.hand[kind]) do
                if not p:placed_at(c.id) and p:can_place(2, c.id) and c.kind == kind and (c.fits[1] == "exploration"
                    or c.fits[2] == "exploration" or c.fits[3] == "exploration") then
                    p:place(2, c.id)
                    break
                end
            end
        end
        p:set_encounter(3, { "ogre", "goblin_warrior", "goblin_warrior", "goblin_warrior" })
        -- A map for the fight's place (B9): a wall, cover by the monsters, rough ground and a trap.
        local s3 = p.scenes[3]
        if not s3.slots.location then
            s3.slots.location = require("game.model.content").components.forest_road
        end
        local maps = require "game.model.maps"
        local loc = s3.slots.location
        local m = maps.new(app.campaign, loc.id, maps.auto_template(app.campaign, loc, "combat"))
        -- Set the stage: a wall with a door in it, a table and a pillar by the monsters, ice, a torch.
        for y = 4, 9 do
            maps.place(m, y == 7 and "door" or "wall", 11, y)
        end
        maps.place(m, "table_round", 15, 5)
        maps.place(m, "pillar", 15, 9)
        for x = 6, 8 do
            maps.place(m, "ice", x, 10)
        end
        maps.place(m, "torch_post", 16, 7)
        maps.place(m, "trap", 9, 7)
        -- Prep, a step at a time (October 26): where the story stands, in their heads.
        require("game.ui.prep_steps").go(app, "story")
        a.wait = 1.0
    elseif step == 2 then
        shot(a, "prep_story")
    elseif step <= 8 then
        -- The rest of the week's steps worth seeing, and Chill mode's faces on the kinds of scene.
        local prefs = require "game.ui.prefs"
        local tour = { "friends", "route_2", "type_2", "slot_2_cast", "ready", "type_2" }
        local id = tour[step - 2]
        if step == 8 then
            prefs.set_chill(true)
        end
        require("game.ui.prep_steps").go(app, id)
        shot(a, "prep_" .. id .. (step == 8 and "_chill" or ""))
    elseif step == 9 then
        require("game.ui.prefs").set_chill(false)
        require("game.ui.prep_steps").go(app, "ready")
        app.open_notes("session")
        shot(a, "notes_session")
    elseif step == 10 then
        app.open_notes("people")
        shot(a, "notes_people")
    elseif step == 11 then
        -- (Whoever's at the table: a small table starts without Jess, October 15.)
        local who = app.campaign.players[#app.campaign.players].key
        app.open_sheet(who)
        shot(a, "sheet_" .. who)
    elseif step == 12 then
        app.close_overlay()
        app.open_encounter(3)
        shot(a, "encounter")
    elseif step == 13 then
        app.enc_tab = "map"
        app.refresh()
        shot(a, "map_builder")
    else
        app.enc_tab = nil
        app.close_overlay()
        a.showcased = true
        a.wait = 0.5
    end
end

-- Any mode on game night: the giver spots last week's gift on your side of the table. A shot
-- from the table camera once it's dropped in, then one from the room.
function M.keepsake_shots(app, a)
    if a.keep_step == 1 then
        shot(a, "keepsake_noticed")
        a.keep_step = 2
        return true
    elseif a.keep_step == 2 then
        app.zoom(1)
        a.keep_step = 3
        a.wait = 2.4
        return true
    elseif a.keep_step == 3 then
        shot(a, "keepsake_room")
        a.keep_step = 4
        return true
    elseif a.keep_step == 4 then
        app.zoom(2)
        a.keep_step = 5
        return false
    end
    if not a.keep_step and app.keepsake_seen then
        a.keep_step = 1
        a.wait = 1.4
        return true
    end
    -- A handout lands at a player's seat: a shot once it's settled.
    if a.hand_step == 1 then
        shot(a, "handout_landed")
        a.hand_step = 2
        return true
    end
    if not a.hand_step and app.handout_seen then
        a.hand_step = 1
        a.wait = 1.6
        return true
    end
    return false
end

-- Mode 4 on game night: one shot of each new thing as it first happens.
function M.night_shots(app, a)
    local ev = app.last_ev
    if not ev then
        return false
    end
    local function once(name, when)
        if when and not a.shots[name] then
            shot(a, name)
            return true
        end
        return false
    end
    -- A shot a moment later, once the pieces have dropped onto the mat.
    if a.pend then
        shot(a, a.pend)
        a.pend = nil
        return true
    end
    local function later(name, when, secs)
        if when and not a.shots[name] then
            a.pend = name
            a.wait = secs or 1.6
            return true
        end
        return false
    end
    -- The story-matched table: the intros, the board going down with the place, pieces
    -- dropping in on the DM's words, the rest set out, the person stepping in.
    if later("intro_meet", ev.kind == "intro" and ev.index == 2, 2.0) then return true end
    if later("dice_moment", ev.kind == "dice", 1.6) then return true end
    if later("board_base", ev.kind == "scene", 1.4) then return true end
    if later("board_words", ev.kind == "narrate" and ev.reveal ~= nil and not ev.dressing, 2.2) then return true end
    if later("board_dressed", ev.kind == "narrate" and ev.dressing, 3.0) then return true end
    if later("npc_steps_in", ev.npc_show == true, 1.6) then return true end
    if later("battle_board", ev.kind == "battle" and ev.phase == "start", 3.0) then return true end
    -- A9: the room with everyone on their chairs, once, from the room camera.
    if not a.room_zoomed and ev.kind == "stage" then
        a.room_zoomed = true
        app.zoom(1)
        a.wait = 2.2
        return true
    end
    if a.room_zoomed and not a.shots.room then
        shot(a, "room")
        a.after_room = true
        return true
    end
    if a.after_room then
        a.after_room = nil
        app.zoom(2)
        a.wait = 1.2
        return true
    end
    if once("check", ev.kind == "check") then return true end
    if once("read_aloud", ev.kind == "narrate" and app.caption and app.caption.read and app.caption.life > 0) then return true end
    if once("in_character", ev.kind == "say" and ev.ic) then return true end
    if once("npc_talk", ev.kind == "npc" and app.on_table and app.on_table.npc) then return true end
    if once("clue", ev.kind == "clue") then return true end
    if once("opening", ev.kind == "narrate" and ev.style == "opening") then return true end
    -- The DM's map on the table (B9), when the fight on it starts.
    if ev.kind == "battle" and ev.phase == "start" and ev.pieces and not a.shots.map_on_table then
        a.wait = 1.4
        return once("map_on_table", true)
    end
    if ev.kind == "turn" then
        for _, st in ipairs(ev.steps or {}) do
            if st.kind == "spell" and st.area and not a.shots.spell_area then
                a.wait = 1.0
                return once("spell_area", true)
            end
        end
        if app.in_battle and app.hud and #app.hud.order > 0 and (a.turns or 0) >= 6 and not a.shots.battle then
            -- A zone on the mat for the shot, so the screenshot shows how areas look.
            -- Centred on the first monster still standing, so it's in the camera's frame.
            local battle_hud = require "game.ui.battle_hud"
            local cx, cy = 8, 6
            local b = app.night and app.night.battle
            for _, c in ipairs(b and b.creatures or {}) do
                if c.side == "foes" and not c.dead and not c.removed and c.x then
                    cx, cy = c.x, c.y
                    break
                end
            end
            local cells = {}
            for x = cx - 1, cx + 1 do
                for y = cy - 1, cy + 1 do
                    table.insert(cells, { x, y })
                end
            end
            battle_hud.area(app, cells, vmath.vector4(0.72, 0.58, 1.0, 1), 9999)
            a.zone_up = true
            return once("battle", true)
        end
        if a.zone_up and a.shots.battle then
            a.zone_up = false
            require("game.ui.battle_hud").zone_end(app, 9999)
        end
        a.turns = (a.turns or 0) + 1
    end
    return false
end

-- Mode 6: the board gallery. No screens, just the table, one board at a time.
local function gallery(app, a)
    if not a.boards then
        a.boards = {}
        for id in pairs(require("game.data.boards")) do
            table.insert(a.boards, id)
        end
        table.sort(a.boards)
        a.bi = 0
        kit.clear_all()
        app.layers = {}
        app.zoom(2)
        msg.post("/table#table", "clear", { how = "sweep" })
        a.wait = 1.5
        return
    end
    if a.pend then
        shot(a, a.pend)
        a.pend = nil
        a.wait = SHOT_WAIT
        return
    end
    a.bi = a.bi + 1
    local id = a.boards[a.bi]
    if not id then
        return finish(a, true, "showed " .. #a.boards .. " boards")
    end
    local board = require "game.model.board"
    local c = board.compile(id)
    msg.post("/board#board", "board", { id = id, show = "all", animate = false })
    local party, foes = {}, {}
    local taken = {}
    local fight = require "game.model.fight"
    local blocked = {}
    for _, sq in ipairs(c.blocked) do
        blocked[sq[1] * 1000 + sq[2]] = true
    end
    local ps = fight.squares_near(blocked, taken, c.party[1], c.party[2], 4, 1, board.W, board.H)
    for i, cls in ipairs({ "fighter", "wizard", "rogue", "cleric" }) do
        if ps[i] then
            table.insert(party, { id = "g_p" .. i, class = cls, sprite = cls, x = ps[i][1], y = ps[i][2] })
        end
    end
    local fs = fight.squares_near(blocked, taken, c.foes[1], c.foes[2], 3, 2, board.W, board.H)
    for i, sp in ipairs({ "bandit_captain", "bandit", "tough" }) do
        if fs[i] then
            table.insert(foes, { id = "g_f" .. i, sprite = sp, x = fs[i][1], y = fs[i][2] })
        end
    end
    msg.post("/table#table", "stage", { party = party, fresh = true })
    msg.post("/table#table", "spawn", { list = foes })
    a.pend = "board_" .. id
    a.wait = 2.2
end

function M.update(app, dt)
    local a = app.autotest
    if not a or a.over then
        return
    end
    a.t = a.t + dt
    if a.mode == 6 then
        a.wait = a.wait - dt
        if a.wait <= 0 then
            a.wait = STEP
            gallery(app, a)
        end
        return
    end
    if a.t > (a.mode == 7 and 4000 or 600) then
        return finish(a, false, "timed out on " .. tostring(app.screen))
    end
    a.wait = a.wait - dt
    if a.wait > 0 then
        return
    end
    a.wait = STEP
    local s = app.screen
    -- Key art: no first-session tips over the shots.
    if a.keyart and app.campaign then
        app.campaign.guide = app.campaign.guide or { seen = {}, off = false, shown = 0 }
        app.campaign.guide.off = true
    end
    if s == "intro" then
        if a.mode == 2 then
            if not shot(a, "intro_continue") then
                if not by_key("continue") then
                    return finish(a, false, "no continue button on the intro")
                end
                say("continued at week " .. tostring(app.campaign.week))
            end
        else
            if not shot(a, "intro") then
                -- A new campaign; with a save already there, "New campaign" asks first, then starts over.
                if not by_key("session_zero") then
                    by_key("new_campaign")
                end
            end
        end
    elseif s == "setup" or s == "join" then
        -- Setting up, one decision at a time (October 26): answer each step like a player who
        -- takes the defaults where there are some, shoot the ones worth seeing, and go on.
        local steps_mod = require "game.ui.steps"
        local sv = require "game.ui.setup_view"
        local backstory = require "game.model.backstory"
        local flow = s == "setup" and sv.flow or sv.join_flow
        local st = steps_mod.current(app, flow)
        if not st then
            return finish(a, false, "no setup step")
        end
        -- (The room camera glides in first: the first shot waits for it.)
        local who = s == "join" and tostring(app.join and app.join.key) or "setup"
        if a.settled_for ~= who then
            a.settled_for = who
            a.wait = 2.5
            return
        end
        a.answered = a.answered or {}
        if not a.answered[who .. ":" .. st.id] then
            a.answered[who .. ":" .. st.id] = true
            local id = st.id
            if id == "table" and a.keyart then
                by_key("table_full")      -- key art wants the whole table
            elseif id == "tone" then
                by_key("tone_mixed")
            elseif id:find("^ask_") then
                by_key(id .. "_agree")
            elseif id:find("^rule_") then
                local rk = id:sub(6)
                by_key(id .. "_" .. (require("game.model.content").session_zero.defaults.rules[rk] or "meaningful"))
            elseif id:find("^bs_q_") or id == "join_q" then
                local k = id == "join_q" and app.join.key or id:sub(6)
                local ask = ({ mara = { "last_words", "afraid" }, dev = { "plan" }, jess = { "how" } })[k]
                    or { backstory.data[k].questions[1].id }
                for _, q in ipairs(ask) do
                    by_key("bs_q_" .. q)
                end
            elseif id:find("^bs_idea_") or id == "join_idea" then
                by_key("bs_idea_yes")
            elseif id == "join_ask" then
                by_key("join_ask_agree")
            elseif id:find("^bs_hook_") or id == "join_hook" then
                local k = id == "join_hook" and app.join.key or id:sub(9)
                local hooks = backstory.data[k].hooks
                by_key("bs_hook_" .. (hooks[2] or hooks[1]).card)
            elseif id == "featured" then
                by_key("thread_mara")
                by_key("thread_dev")
            end
            a.wait = 1.0       -- (their poses and bubbles change)
            return
        end
        local worth = { table = true, style = true, truths = true, front = true, tone = true, ask_mara = true,
                        rule_death = true, bs_q_mara = true, bs_idea_mara = true, bs_hook_mara = true, featured = true,
                        ready = true, join_q = true, join_hook = true }
        if a.mode ~= 7 and worth[st.id] and shot(a, (s == "join" and ("join_" .. tostring(app.join and app.join.key) .. "_") or "setup_") .. st.id) then
            return
        end
        if not steps_mod.next(app, flow) then
            return finish(a, false, "couldn't go on from the " .. st.id .. " step")
        end
    elseif s == "prep" then
        if a.mode == 7 then
            return M.act_prep(app, a)
        end
        if app.levelup then
            by_key("levelup_close")
            return
        end
        if app.convo then
            app.convo = nil
            app.refresh()
            return
        end
        local wk = app.campaign.week
        if a.mode == 5 then
            local ok, n = pcall(sys.get_config_int, "behind_the_screen.autotest_weeks", 6)
            if a.weeks >= ((ok and n and n > 0) and n or 6) then
                return finish(a, true, "played " .. a.weeks .. " sessions with real clicks")
            end
        end
        if a.mode == 1 and wk >= 3 then
            if M.story_shots(app, a) then
                return
            end
            return finish(a, true, "reached the prep for session 3")
        end
        if a.mode == 2 and a.weeks >= 1 then
            return finish(a, true, "played a session after continuing")
        end
        if a.mode == 4 and not a.showcased then
            return M.showcase(app, a)
        end
        if shot(a, "prep_week_" .. wk) then
            return
        end
        local p = app.campaign.prep
        for i = 1, 3 do
            if not p.scenes[i].type then
                p:set_type(i, "social")
            end
        end
        -- Mode 1, the first week: Gus on the first scene, with a handout made for him (a letter).
        if a.mode == 1 and wk == 1 and not a.handout_made then
            a.handout_made = true
            if p:can_place(1, "gus") then
                p:place(1, "gus")
            end
            require("game.model.handouts").toggle(p, "gus")
        end
        -- Prep is a step at a time (October 26): game night is the last step's button.
        require("game.ui.prep_steps").go(app, "ready")
        app.refresh()
        if not by_label("Run game night") then
            return finish(a, false, "no Run game night button")
        end
        if app.ask then
            by_label(app.ask.yes or "Run game night")
        end
        say("night " .. wk)
    elseif s == "lore" then
        -- What tonight can change in the story (October 16): a shot, then on to the night.
        if not shot(a, "lore_week_" .. tostring(app.campaign.week)) then
            if not by_key("lore_go") then
                return finish(a, false, "no way on from the lore screen")
            end
        end
    elseif s == "night" then
        local nv = require "game.ui.night_view"
        if app.night_done then
            if not shot(a, "night_done_" .. app.campaign.week) then
                -- Mode 1: someone's Goodwill is full after the first night, so the report has a gift.
                -- Mode 7: the first player's after the first night, and the next one's after the third.
                local wk = app.campaign.week
                if (a.mode == 1 and wk == 1) or (a.mode == 7 and (wk == 1 or wk == 3)) then
                    local ks = require "game.model.keepsakes"
                    local nth = wk == 3 and 2 or 1
                    for _, p in ipairs(app.campaign.players) do
                        if p.present then
                            nth = nth - 1
                            if nth == 0 then
                                ks.get(app.campaign).goodwill[p.key] = ks.data.FULL
                                break
                            end
                        end
                    end
                end
                by_label("See how everyone felt")
            end
        elseif app.pending and a.mode == 5 then
            -- The harness clicks the card; just keep the night at 2x.
            app.speed_i = 3
            if not a.handed then
                a.handed = true
                say("handover")
            end
        elseif app.pending then
            -- Key art: clean shots, a story scene's and a fight's, while the night waits on a card.
            if keyart_on(app, a) and (a.ka or app.pending.kind == "decision") then
                local kt = app.pending.card and app.pending.card.type
                local tag = ka_tag(app, a, (kt == "combat" or kt == "boss") and "fight" or "story")
                if a.ka or not (a.ka_done or {})[tag] then
                    if M.keyart(app, a, a.ka and a.ka.tag or tag) then
                        return
                    end
                end
            end
            if showy(app, a) and (app.pending.kind == "decision" or app.pending.kind == "roll_where" or app.pending.kind == "ruling")
                and not a.shots[app.pending.kind] then
                shot(a, app.pending.kind)
                return
            end
            -- Taking over (B8): the talk card and the boss's turn, once each.
            local ct = app.pending.kind == "decision" and app.pending.card and app.pending.card.type
            if showy(app, a) and (ct == "talk" or ct == "boss") and not a.shots["takeover_" .. ct] then
                shot(a, "takeover_" .. ct)
                return
            end
            -- A player's pull (October 18): the card with its four answers, once.
            if showy(app, a) and ct == "skew" and not a.shots.pull_card then
                shot(a, "pull_card")
                return
            end
            -- The opening and the briefings (October 15): a shot of each, the first time.
            if app.pending.kind == "cinematic" then
                local name = "cinematic_" .. tostring(app.pending.id) .. "_" .. app.campaign.week .. "_" .. tostring(app.cine_i or 1)
                if (app.cine_i or 1) <= 2 and shot(a, name) then
                    return
                end
            end
            if not by_label("Play") then
                local bs = buttons()
                if bs[1] then
                    press(bs[1])
                end
            end
        elseif not app.rolling then
            -- Key art: carry on with the shots, or start the fight's once its minis are on the mat.
            if keyart_on(app, a) then
                local ev = app.last_ev
                local btag = ka_tag(app, a, "battle")
                if a.ka then
                    if M.keyart(app, a, a.ka.tag) then
                        return
                    end
                elseif ev and not (a.ka_done or {})[btag] and ((a.mode == 4 and ev.kind == "battle" and a.shots.battle_board)
                    or (a.mode == 7 and ev.kind == "turn" and app.in_battle)) then
                    M.keyart(app, a, btag)
                    return
                end
            end
            if showy(app, a) and M.night_shots(app, a) then
                return
            end
            if M.keepsake_shots(app, a) then
                return
            end
            if (a.mode ~= 7 or showy(app, a)) and a.t - (a.last_night_shot or 0) > 25
                and shot(a, "night_" .. app.campaign.week .. "_" .. math.floor(a.t)) then
                a.last_night_shot = a.t
                return
            end
            if a.mode == 5 then
                -- 2x like the playtest; skipping ahead between cards unless autotest_skip = 0.
                app.speed_i = 3
                local ok, sk = pcall(sys.get_config_int, "behind_the_screen.autotest_skip", 1)
                if not ok or sk ~= 0 then
                    nv.skip(app)
                end
            else
                nv.skip(app)
            end
        end
        a.wait = 0.05
    elseif s == "report" then
        if a.mode == 5 and not app.quick and a.counted_week ~= app.campaign.week then
            a.counted_week = app.campaign.week
            a.weeks = a.weeks + 1
            say("session " .. app.campaign.week .. " done")
        end
        if (a.mode == 3 or a.mode == 4) and a.shots["report_" .. app.campaign.week] then
            return finish(a, true, "saw the first report")
        end
        -- A gift from the table: its shot, put it to work, its shot, put it away.
        local ks = require "game.model.keepsakes"
        if ks.waiting(app.campaign) then
            if not shot(a, "keepsake_" .. app.campaign.week) then
                by_key("keepsake_use")
            end
            return
        elseif app.keepsake_shown then
            if not shot(a, "keepsake_taken_" .. app.campaign.week) then
                by_key("keepsake_done")
            end
            return
        end
        if app.quick then
            local wk = app.campaign.week
            by_key("quick_prep_1")
            by_key("quick_watch_1")
            a.weeks = a.weeks + 1
            say("session " .. wk .. " done")
        elseif not shot(a, "report_" .. app.campaign.week) then
            by_key("next_week")
        end
    elseif s == "slice_end" then
        if a.mode == 7 then
            if not shot(a, "act_scrapbook") then
                return finish(a, true, "the first act, shown off")
            end
            return
        end
        by_key("keep_playing")
    end
end

return M
