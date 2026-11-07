-- In-engine autotest (M7): plays the real build by itself so the engine-only parts
-- (sound, light, snacks, saving to disk) get exercised where the headless tests can't
-- reach. Off unless the build sets behind_the_screen.autotest = 1 (tools/tests/autotest.ini).
-- It clicks buttons by calling them, prints "AUTOTEST ..." lines (an outside script takes
-- screenshots on "AUTOTEST shot <name>"), and quits when it's done:
--   autotest = 3   new campaign: Session Zero and one session, quit at its report (screen-size checks)
--   autotest = 4   one session with shots of each new thing on game night as it first happens (a
--                  check, a decision, a fight, a spell; key art with behind_the_screen.keyart = 1);
--                  quit at the report
--   autotest = 5   real clicks (tools/tests/ui_play/): drive every screen at 2x, but leave every
--                  game-night card for an outside harness to click with real X input; quit after
--                  behind_the_screen.autotest_weeks sessions (default 6)
--   autotest = 6   the board gallery: every board (game/data/boards.lua) set out in full on the
--                  table, with a party and some foes on it, one shot each from the table camera
--   autotest = 8   The Museum of Nightmares from the notice to the journey recap, with shots of
--                  the hooks, every between-session page and prep board, the nights and the reports

-- (5e's engine only through the adventure's rule set: docs/design/rule-sets.md, no leaks.)
local ruleset = require "game.model.ruleset"
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

-- A button on a pinned layer (the thought clouds over the panels): the game's own clicks reach them
-- under any card or tip, so the harness looks there too.
local function pinned_key(k)
    for _, l in ipairs(kit.layers) do
        if l.pinned then
            for _, b in ipairs(l.buttons) do
                if b.key == k and b.enabled then
                    press(b)
                    return true
                end
            end
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
    -- (Carried on into a second adventure, CARRY: its shots get their own names.)
    if a.carried then
        name = name .. "_b"
    end
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
    local fight = ruleset.part("fight")
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
    -- (behind_the_screen.trailer = 1: footage for a trailer. The nights play at their own pace and every
    -- card and thought stays up a moment before it's answered, so the camera can catch it.)
    if a.trailer == nil then
        local ok, tr = pcall(sys.get_config_int, "behind_the_screen.trailer", 0)
        a.trailer = (ok and tr == 1) or false
        if a.trailer then
            -- The moments worth cutting to, as they happen.
            -- (The night skips ahead between the moments worth filming, and slows to its own pace
            -- for a few seconds of game time around each one.)
            local function slow(secs)
                a.slow_until = math.max(a.slow_until or 0, a.t + secs)
            end
            app.trailer_log = function(ev)
                local k = ev.kind
                -- (Filmed: the first night, and the Gorgon's lair. The rest goes by quickly.)
                if k == "scene" then
                    a.filming = (app.campaign and app.campaign.week == 1)
                        or (type(ev.title) == "string" and string.find(string.lower(ev.title), "lair") ~= nil)
                end
                if not a.filming then
                    return
                end
                if k == "scene" then
                    slow(4)
                elseif k == "battle" and ev.phase == "start" then
                    slow(16)
                elseif k == "thought" or k == "mark" or (k == "check" and (ev.crit or ev.fumble)) then
                    slow(3)
                end
                if k == "battle" then
                    say("ev battle " .. tostring(ev.phase))
                elseif k == "scene" then
                    say("ev scene " .. tostring(ev.title))
                elseif k == "decision" then
                    say("ev decision " .. tostring(ev.card and ev.card.type) .. " " .. tostring(ev.card and ev.card.title))
                elseif k == "check" and (ev.crit or ev.fumble) then
                    say("ev " .. (ev.crit and "crit" or "fumble") .. " " .. tostring(ev.actor))
                elseif k == "thought" then
                    say("ev thought " .. tostring(ev.who) .. " " .. tostring(ev.need))
                elseif k == "mark" then
                    say("ev mark " .. tostring(ev.name))
                elseif k == "turn" and ev.say then
                    say("ev turn")
                elseif k == "cinematic" then
                    say("ev cinematic " .. tostring(ev.id))
                elseif k == "roll" then
                    say("ev roll " .. tostring(ev.actor or ""))
                end
            end
        end
    end
    -- (No first-session tips in trailer footage.)
    if a.trailer and app.campaign then
        app.campaign.guide = app.campaign.guide or {}
        app.campaign.guide.off = true
    end
    if a.t > (a.trailer and 6000 or (a.mode == 8 and 2400 or 600)) then
        return finish(a, false, "timed out on " .. tostring(app.screen))
    end
    a.wait = a.wait - dt
    if a.wait > 0 then
        return
    end
    a.wait = STEP
    local s = app.screen
    if s == "intro" then
        -- The prototype notice on launch: agree first.
        if not app.notice_ok then
            if not shot(a, "notice") then
                by_key("agree")
            end
            return
        end
        if not shot(a, "intro") then
            -- A new campaign; with a save already there, "New campaign" asks first, then starts over.
            if not by_key("session_zero") then
                by_key("new_campaign")
            end
        end
    elseif s == "session_zero" then
        -- Session Zero, then why each hero came.
        app.s0 = app.s0 or { asks = {}, rules = {} }
        app.s0.tone = app.s0.tone or "mixed"
        for _, k in ipairs({ "mara", "sam", "dev", "jess" }) do
            app.s0.asks[k] = app.s0.asks[k] or "agree"
        end
        app.s0.rules.xcard = app.s0.rules.xcard or "on"
        app.s0.rules.dice = app.s0.rules.dice or "big_open"
        app.s0.rules.rulings = app.s0.rules.rulings or "quick"
        app.s0.rules.length = app.s0.rules.length or "half"
        app.s0.rules.death = app.s0.rules.death or "meaningful"
        app.s0.rules.harsh = app.s0.rules.harsh or "fair"
        -- (Any rule added later: its first answer, so Session Zero never waits on one.)
        local s0d = require("game.model.content").session_zero.rules
        for _, rk in ipairs(s0d.order) do
            app.s0.rules[rk] = app.s0.rules[rk] or s0d[rk].order[1]
        end
        if app.s0.page ~= "hooks" then
            app.refresh()
            if not shot(a, "session_zero") then
                by_key("s0_next")
            end
            return
        end
        -- (The page made its own empty pick list when it drew: fill it, don't replace it. The museum's own picks, else
        -- each friend's first hook in whichever adventure this is.)
        app.s0.hooks = app.s0.hooks or {}
        local hooks = require("game.model.adventure").data.hooks or {}
        for k, id in pairs({ mara = "sage", dev = "soldier", jess = "charlatan", sam = "acolyte" }) do
            local ok = false
            for _, h in ipairs(hooks[k] or {}) do
                ok = ok or h.id == id
            end
            app.s0.hooks[k] = app.s0.hooks[k] or (ok and id) or (hooks[k] and hooks[k][1] and hooks[k][1].id)
        end
        app.refresh()
        if not shot(a, "hooks") then
            by_key("hooks_start")
        end
    elseif s == "prep" then
        if app.levelup then
            by_key("levelup_close")
            return
        end
        if a.mode == 5 then
            local ok, n = pcall(sys.get_config_int, "behind_the_screen.autotest_weeks", 6)
            if a.weeks >= ((ok and n and n > 0) and n or 6) then
                return finish(a, true, "played " .. a.weeks .. " sessions with real clicks")
            end
        end
        local wk = app.campaign.week
        local mpv = require "game.ui.museum_prep_view"
        local pr = mpv.prompts(app)[1]
        if pr then
            if shot(a, "between_" .. wk .. "_" .. pr.id) then
                return
            end
            if pr.kind == "request" then
                by_key("req_laugh")
            elseif pr.kind == "loose" then
                by_key("loose_1")
            elseif pr.kind == "ruling" then
                by_key("ruling_1")      -- (post the ruling you promised: the autotest stopped here, November 3)
            elseif pr.kind == "chat" then
                by_key("chat_reply_1")  -- (a question for you in the group chat)
            else
                by_key("favor_help_1")
                by_key("favor_hurt_1")
                by_key("favor_done")
            end
            return
        end
        if shot(a, "prep_week_" .. wk) then
            return
        end
        -- The tie-and-lock editor, once: opened, a room's cards, closed.
        if a.mode == 8 and wk == 1 and not a.ties_done then
            if app.overlay ~= "ties" then
                if a.ties_opened or not by_key("open_ties") then
                    a.ties_done = true
                end
                a.ties_opened = true
                return
            end
            if shot(a, "ties_editor") then
                return
            end
            if not a.ties_room then
                a.ties_room = true
                by_key("tl_room_paintings")
                return
            end
            if shot(a, "ties_room") then
                return
            end
            by_key("tl_done")
            a.ties_done = true
            return
        end
        if not a.prepped_week or a.prepped_week ~= wk then
            a.prepped_week = wk
            local mw = require "game.model.museum_week"
            local p = app.campaign.prep
            mw.prep_greedy(p)
            for _, id in ipairs(p.museum.ahead) do
                for _, kid in ipairs(require("game.model.adventure").data.rooms[id].knobs or {}) do
                    local k = require("game.model.adventure").data.knobs[kid]
                    mw.set_knob(p, kid, k.pick_hero and "mara" or true)
                end
            end
            app.refresh()
            shot(a, "prep_set_" .. wk)
            return
        end
        if not by_key("run_night") then
            return finish(a, false, "no Run game night button")
        end
        say("night " .. wk)
    elseif s == "night" then
        local nv = require "game.ui.night_view"
        if app.night_done then
            if not shot(a, "night_done_" .. app.campaign.week) then
                by_label("See how everyone felt")
            end
        elseif a.mode == 8 and not a.recap_done and not app.pending and not app.thought_card and app.night
            and (app.night.clock or 0) > 40 then
            -- The DM's recap, once: the Table sidebar open (one at a time), a shot, shut.
            local rv = require "game.ui.recap_view"
            if not app.recap_right then
                rv.toggle(app, "right")
                return
            end
            if shot(a, "recap") then
                return
            end
            rv.close(app)
            a.recap_done = true
        elseif app.thought_card then
            -- A friend's thought, open (one you clicked, or Pip about to go off alone): a shot
            -- of the card before and after the Insight roll the first time, then answer it.
            local th = app.night and app.night.th
            local t = th and th.list[app.thought_card.id]
            local stage = tostring(app.thought_card.id) .. (t and t.read and "r" or "u")
            if a.trailer and (a.filming or (app.campaign and app.campaign.week == 1)) and a.held ~= stage then
                a.held = stage
                a.wait = 2.2
                return
            end
            if t and not t.read then
                if shot(a, "thought_card") then
                    return
                end
                by_key("thought_read")
            else
                if shot(a, "thought_read") then
                    return
                end
                if t and t.read and t.read.result == "miss" then
                    by_key("thought_ask")
                end
                if not by_key("thought_ans_1") then
                    by_key("thought_let")
                end
            end
        elseif a.mode ~= 5 and not app.pending and app.thinking and next(app.thinking) and not a.thought_opened then
            local k = "thought_" .. next(app.thinking)
            a.thought_opened = by_key(k) or pinned_key(k)
        elseif app.pending and a.mode == 5 then
            -- The harness clicks the card; just keep the night at 2x.
            app.speed_i = 3
            if not a.handed then
                a.handed = true
                say("handover")
            end
        elseif app.pending then
            if a.trailer and (a.filming or (app.campaign and app.campaign.week == 1)) and a.held ~= app.pending then
                a.held = app.pending
                a.wait = app.pending.kind == "cinematic" and 2.0 or 1.8
                return
            end
            -- Key art: clean shots, a story scene's and a fight's, while the night waits on a card.
            if a.mode == 4 and a.keyart and (a.ka or app.pending.kind == "decision") then
                local kt = app.pending.card and app.pending.card.type
                local tag = (kt == "combat" or kt == "boss") and "fight" or "story"
                if a.ka or not (a.ka_done or {})[tag] then
                    if M.keyart(app, a, a.ka and a.ka.tag or tag) then
                        return
                    end
                end
            end
            if a.mode == 4 and (app.pending.kind == "decision" or app.pending.kind == "roll_where" or app.pending.kind == "ruling")
                and not a.shots[app.pending.kind] then
                shot(a, app.pending.kind)
                return
            end
            -- Taking over (B8): the talk card and the boss's turn, once each.
            local ct = app.pending.kind == "decision" and app.pending.card and app.pending.card.type
            if a.mode == 4 and (ct == "talk" or ct == "boss") and not a.shots["takeover_" .. ct] then
                shot(a, "takeover_" .. ct)
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
            if a.mode == 4 and a.keyart then
                local ev = app.last_ev
                if a.ka then
                    if M.keyart(app, a, a.ka.tag) then
                        return
                    end
                elseif ev and ev.kind == "battle" and a.shots.battle_board and not (a.ka_done or {}).battle then
                    M.keyart(app, a, "battle")
                    return
                end
            end
            if a.mode == 4 and M.night_shots(app, a) then
                return
            end
            if M.keepsake_shots(app, a) then
                return
            end
            if a.t - (a.last_night_shot or 0) > 25 and shot(a, "night_" .. app.campaign.week .. "_" .. math.floor(a.t)) then
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
            elseif not a.trailer or a.t > (a.slow_until or 0) then
                nv.skip(app)
            end
        end
        a.wait = 0.05
    elseif s == "report" then
        -- The rewards first (November 3): a shot, the box opened if there is one, then on.
        local rw = require "game.ui.rewards_view"
        if rw.pending(app) then
            if app.rewards_spin then
                return
            end
            if not shot(a, "rewards_" .. app.campaign.week) then
                if not by_key("rewards_open") then
                    by_key("rewards_next")
                end
            end
            return
        end
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
        -- The museum's milestone levels are taken from the report (a shot of the first page).
        if a.mode == 8 then
            a.leveled = a.leveled or {}
            local wk = app.campaign.week
            if app.levelup then
                if not shot(a, "levelup_" .. wk) then
                    local bs = buttons()
                    if #bs > 0 then
                        press(bs[#bs])
                    end
                end
                return
            elseif not a.leveled[wk] and by_key("level_up") then
                a.leveled[wk] = true
                return
            end
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
        -- CARRY=1 (in the environment): from the journey recap, "Carry on" into the next adventure, and play it too.
        local adv = require "game.model.adventure"
        if a.mode == 8 and not a.carried and os.getenv and os.getenv("CARRY") and app.carry_on and adv.next_up(app.campaign) then
            if not shot(a, "journey") then
                say("first adventure done: ending " .. tostring(app.campaign.adv and app.campaign.adv.ending) .. " in "
                    .. app.campaign.week .. " sessions; carrying on")
                a.carried = true
                a.t = 0
                by_key("carry_on")
            end
            return
        end
        if a.mode == 8 then
            if not shot(a, "journey") then
                say("museum done: ending " .. tostring(app.campaign.adv and app.campaign.adv.ending) .. " in "
                    .. app.campaign.week .. " sessions")
                return finish(a, true, "reached the journey recap")
            end
            return
        end
        by_key("keep_playing")
    end
end

return M
