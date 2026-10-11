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

local function finish(a, ok, why)
    say((ok and "done " or "FAILED ") .. (why or ""))
    a.over = true
    sys.exit(ok and 0 or 1)
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
        app.sel = { scene = 2, kind = "cast" }
        app.refresh()
        shot(a, "prep_board")
    elseif step == 2 then
        app.sel = nil
        app.open_notes("session")
        shot(a, "notes_session")
    elseif step == 3 then
        app.open_notes("people")
        shot(a, "notes_people")
    elseif step == 4 then
        app.open_sheet("jess")
        shot(a, "sheet_jess")
    elseif step == 5 then
        app.close_overlay()
        app.open_encounter(3)
        shot(a, "encounter")
    else
        app.close_overlay()
        a.showcased = true
        a.wait = 0.5
    end
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
    if once("check", ev.kind == "check") then return true end
    if once("clue", ev.kind == "clue") then return true end
    if once("opening", ev.kind == "narrate" and ev.style == "opening") then return true end
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

function M.update(app, dt)
    local a = app.autotest
    if not a or a.over then
        return
    end
    a.t = a.t + dt
    if a.t > 600 then
        return finish(a, false, "timed out on " .. tostring(app.screen))
    end
    a.wait = a.wait - dt
    if a.wait > 0 then
        return
    end
    a.wait = STEP
    local s = app.screen
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
    elseif s == "session_zero" then
        app.s0 = app.s0 or { asks = {}, rules = {} }
        app.s0.tone = app.s0.tone or "mixed"
        for _, k in ipairs({ "mara", "sam", "dev", "jess" }) do
            app.s0.asks[k] = app.s0.asks[k] or "agree"
        end
        app.s0.rules.xcard = app.s0.rules.xcard or "on"
        app.s0.rules.dice = app.s0.rules.dice or "big_open"
        app.s0.rules.rulings = app.s0.rules.rulings or "quick"
        app.refresh()
        if not shot(a, "session_zero") then
            by_label("Start week")
        end
    elseif s == "prep" then
        if app.levelup then
            by_label("Back to the table")
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
        app.refresh()
        if not by_label("Run game night") then
            return finish(a, false, "no Run game night button")
        end
        say("night " .. wk)
    elseif s == "night" then
        local nv = require "game.ui.night_view"
        if app.night_done then
            if not shot(a, "night_done_" .. app.campaign.week) then
                by_label("See how everyone felt")
            end
        elseif app.pending and a.mode == 5 then
            -- The harness clicks the card; just keep the night at 2x.
            app.speed_i = 2
            if not a.handed then
                a.handed = true
                say("handover")
            end
        elseif app.pending then
            if a.mode == 4 and (app.pending.kind == "decision" or app.pending.kind == "roll_where") and not a.shots[app.pending.kind] then
                shot(a, app.pending.kind)
                return
            end
            if not by_label("Play") then
                local bs = buttons()
                if bs[1] then
                    press(bs[1])
                end
            end
        elseif not app.rolling then
            if a.mode == 4 and M.night_shots(app, a) then
                return
            end
            if a.t - (a.last_night_shot or 0) > 25 and shot(a, "night_" .. app.campaign.week .. "_" .. math.floor(a.t)) then
                a.last_night_shot = a.t
                return
            end
            if a.mode == 5 then
                -- 2x like the playtest; skipping ahead between cards unless autotest_skip = 0.
                app.speed_i = 2
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
        by_key("keep_playing")
    end
end

return M
