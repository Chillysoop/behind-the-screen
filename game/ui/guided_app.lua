-- Separate guided campaign controller. It never creates or saves a legacy campaign.
-- All outcomes belong to the deterministic, engine-free guided model; the table only replays them.
local guided = require "game.model.guided"
local view = require "game.ui.guided_view"
local kit = require "game.ui.kit"
local ambience = require "game.ui.ambience"
local boards = require "game.data.boards"

local M = {}
local TABLE, BOARD, CAMERA, DICE, HUD = "/table#table", "/board#board", "/camera#camera", "/dice#dice", "/hud#hud"
local A = {
    touch = hash("touch"), confirm = hash("confirm"), back = hash("back"),
    next = hash("roll"), fast = hash("fast"), slow = hash("slow"),
    music = hash("music"), story = hash("story"), up = hash("up"), down = hash("down"),
}
local NUMBER = { [hash("zoom_room")] = 1, [hash("zoom_table")] = 2, [hash("zoom_imagination")] = 3, [hash("zoom_dice")] = 4 }
local HERO = { Thessaly = "mara", Brannoc = "dev", Pip = "jess", Oswin = "sam" }
local CLASS = { mara = "wizard", dev = "fighter", jess = "rogue", sam = "cleric" }
local SPRITE = { goblin = "goblin_spear", bandit = "bandit", skeleton = "skeleton", wolf = "wolf", guard = "guard" }
local POSE = { neutral = true, lean = true, arms = true, yawn = true, phone = true, cheer = true, gasp = true, laugh = true, think = true }

local function config(key, default)
    local ok, n = pcall(sys.get_config_int, key, default)
    return ok and n or default
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

-- Verify the new file before exchanging it for the current save. Never unlink the
-- current save to work around a failed rename; it is the recovery point.
local function atomic_write(path, text)
    local tmp, bak = path .. ".tmp", path .. ".bak"
    local f = io.open(tmp, "wb")
    if not f then return nil, "cannot open temporary save" end
    local wrote = f:write(text)
    local closed = f:close()
    if not wrote or not closed or read_file(tmp) ~= text then
        return nil, "temporary save could not be verified"
    end
    local old = read_file(path)
    if old then
        os.remove(bak)
        local moved, err = os.rename(path, bak)
        if not moved then return nil, err or "cannot preserve previous save" end
    end
    local ok, err = os.rename(tmp, path)
    if ok then return true end
    if old then os.rename(bak, path) end
    return nil, err or "cannot finish save"
end

local function load_save(path)
    local found_any = false
    for _, p in ipairs({ path, path .. ".tmp", path .. ".bak" }) do
        local ok, text = pcall(read_file, p)
        if ok and text and #text > 0 then
            found_any = true
            local restored, state = pcall(guided.restore, text)
            if restored and state then
                local good, snap = pcall(guided.snapshot, state)
                if good then return { state = state, snapshot = snap }, nil end
            end
        end
    end
    return nil, found_any and "No readable campaign save was found." or nil
end

local function save(app)
    if not app.state then return true end
    local ok, err = pcall(function()
        local text = guided.dump(app.state)
        local done, why = atomic_write(app.save_path, text)
        assert(done, why)
    end)
    app.save_error = not ok and tostring(err) or nil
    if not ok then print("[guided] save: " .. tostring(err)) end
    return ok
end

local function id_of(v)
    if type(v) == "table" then v = v.id or v.key or v.name end
    if type(v) ~= "string" then return nil end
    return HERO[v] or v
end

local function title_of(v)
    if type(v) == "table" then return v.name or v.char or v.id or "Someone" end
    return type(v) == "string" and v or "Someone"
end

-- The rules use class IDs such as pc_fighter; table art uses fighter.
-- Normalize at the presentation boundary, including already-saved battles.
local function party_sprite(p, id)
    local sprite = p.sprite or CLASS[id] or p.class or "fighter"
    return sprite:gsub("^pc_", "")
end

local function render(app)
    view.render(app)
    if app.autotest then
        local s = app.snap or {}
        local key = (app.title and "title" or tostring(s.phase)) .. ":" .. tostring(s.episode or 0) .. ":" .. tostring(s.scene_index or 0)
        if key ~= app.trace_key then
            app.trace_key = key
            print("GUIDED_SCREEN " .. key)
        end
    end
end

local function protect(app, fn, ...)
    local args = { ... }
    local ok, result = xpcall(function() return fn(unpack(args)) end, debug.traceback)
    if not ok then
        print("[guided] ERROR " .. tostring(result))
        app.error = tostring(result)
        app.playback = nil
        pcall(render, app)
        return false
    end
    return result
end

local function lock(app)
    if app.time < (app.input_lock_until or 0) then return false end
    app.input_lock_until = app.time + 0.18
    return true
end

local function zoom(app, index)
    if index ~= app.camera_index then
        app.camera_index = index
        msg.post(CAMERA, "set_zoom", { index = index })
    end
end

local function stage_party(snap, board)
    local p0, out = board.party or { 4, 7 }, {}
    for i, p in ipairs(snap.party or {}) do
        local key = p.key or p.id
        out[#out + 1] = { id = key, class = p.class or CLASS[key] or "fighter", sprite = CLASS[key],
            x = p0[1] + ((i - 1) % 2), y = p0[2] + math.floor((i - 1) / 2) }
    end
    return out
end

local function stage(app, snap, force)
    local night = snap.phase == "decision" or snap.phase == "result"
    zoom(app, night and 2 or 1)
    local board_id = type(snap.board) == "table" and snap.board.id or snap.board
    if not boards[board_id or ""] then board_id = "kettle" end
    local key = tostring(snap.episode) .. ":" .. tostring(snap.scene_index) .. ":" .. board_id
    if force or key ~= app.stage_key then
        app.stage_key = key
        local b = boards[board_id]
        msg.post(BOARD, "board", { id = board_id, show = "all", animate = true })
        local npc
        if snap.npc then
            local n = type(snap.npc) == "table" and snap.npc or { sprite = snap.npc }
            local pos = b.npc or { 13, 6 }
            npc = { sprite = n.sprite or "npc_stranger", x = n.x or pos[1], y = n.y or pos[2] }
        end
        msg.post(TABLE, "stage", { party = stage_party(snap, b), npc = npc, fresh = true })
        msg.post(TABLE, "pieces", {})
    end
    msg.post(TABLE, "track", { on = true })
    local poses = { mara = "neutral", dev = "neutral", jess = "neutral", sam = "neutral" }
    app.poses = {}
    for _, r in ipairs(snap.reactions or {}) do
        if r.key then
            poses[r.key] = r.pose == "crossed" and "arms" or (POSE[r.pose] and r.pose or "lean")
            app.poses[r.key] = poses[r.key]
        end
    end
    if snap.focus and poses[snap.focus] == "neutral" then poses[snap.focus] = "lean" end
    msg.post(TABLE, "mood", { poses = poses })
    app.reaction = snap.reactions and snap.reactions[1] or nil
    app.reaction_index, app.reaction_clock = 1, 0
    if snap.phase ~= app.last_phase then
        if snap.phase == "prep_focus" then ambience.screen(app, "prep")
        elseif snap.phase == "decision" and (app.last_phase == "prep_twist" or not app.last_phase) then ambience.screen(app, "night")
        elseif snap.phase == "aftermath" then ambience.screen(app, "report")
        elseif snap.phase == "complete" then ambience.screen(app, "slice_end") end
        app.last_phase = snap.phase
    end
    if snap.phase == "decision" then
        ambience.snacks_eaten(math.max(0, ((snap.scene_index or 1) - 1) / 4))
    end
end

local function battle_name(app, v)
    local id = id_of(v)
    return (app.playback and app.playback.names[id]) or title_of(v)
end

local function replay_step(app)
    local p = app.playback
    if not p then return end
    local e = p.events[p.index]
    if not e then
        app.playback = nil
        render(app)
        return
    end
    p.index = p.index + 1
    local who, att, tgt = id_of(e.who), id_of(e.att or e.src), id_of(e.tgt or e.target)
    local k = e.kind
    p.wait = 1.4
    if k == "move" and who and e.path and #e.path > 0 then
        msg.post(TABLE, "walk", { id = who, path = e.path, step = 0.12 })
        p.caption = battle_name(app, e.who) .. " moves into position."
        p.wait = math.min(2.4, 0.6 + #e.path * 0.12)
    elseif k == "attack" and att and tgt then
        msg.post(TABLE, "lunge", { id = att, target = tgt, ranged = e.ranged, time = 0.45 })
        local outcome = e.hit and "a hit" or "a miss"
        p.caption = battle_name(app, e.att) .. " attacks " .. battle_name(app, e.tgt) .. ": " .. outcome .. "."
        if e.total and e.ac then p.caption = p.caption .. "  " .. e.total .. " against AC " .. e.ac .. "." end
        if e.roll then msg.post(DICE, "tumble", { tray = CLASS[att] and att or "dm_open", value = e.roll }) end
        ambience.sfx("dice", 0.5)
    elseif k == "damage" and tgt then
        msg.post(TABLE, "hit", { id = tgt })
        p.caption = battle_name(app, e.tgt) .. " takes " .. tostring(e.amount or 0) .. " damage."
        ambience.sfx("tap", 0.5)
    elseif (k == "down" or k == "death") and who then
        msg.post(TABLE, "down", { id = who })
        p.caption = battle_name(app, e.who) .. " falls."
        p.wait = 1.8
    elseif (k == "up" or k == "heal") and (who or tgt) then
        local id = who or tgt
        msg.post(TABLE, "up", { id = id })
        msg.post(TABLE, "spark", { id = id, color = vmath.vector4(0.4, 1, 0.7, 1), life = 0.7 })
        p.caption = battle_name(app, e.who or e.tgt) .. (k == "heal" and " receives healing." or " gets back up.")
    elseif k == "spell" then
        if tgt or who then msg.post(TABLE, "spark", { id = tgt or who, life = 0.8 }) end
        p.caption = battle_name(app, e.who or e.src) .. " casts " .. tostring(e.name or e.spell or "a spell") .. "."
        ambience.pulse(0.2, 0.4)
    elseif k == "flee" and who then
        msg.post(TABLE, "flee", { id = who })
        p.caption = battle_name(app, e.who) .. " retreats."
    elseif k == "round" then
        p.caption = "Round " .. tostring(e.round or 1) .. ". The party holds together."
        p.wait = 0.7
    else
        p.caption = e.text or e.summary or "The fight continues."
        p.wait = 0.7
    end
    render(app)
end

local function begin_replay(app, snap)
    local battle = snap.battle
    if not battle or not battle.events or #battle.events == 0 then return end
    local key = tostring(snap.episode) .. ":" .. tostring(snap.scene_index)
    if app.replayed == key then return end
    app.replayed = key
    local events, names = {}, {}
    local allowed = { move = true, attack = true, damage = true, down = true, death = true, up = true, heal = true, spell = true, flee = true, round = true }
    for _, e in ipairs(battle.events) do
        if allowed[e.kind] and #events < 24 then events[#events + 1] = e end
    end
    if #events == 0 then return end
    local party, foes = {}, {}
    for i, p in ipairs(battle.party or {}) do
        local id = id_of(p)
        names[id] = p.name or p.char or id
        party[#party + 1] = { id = id, class = CLASS[id] or p.class or "fighter", sprite = party_sprite(p, id),
            x = p.x or 4 + i, y = p.y or 7 }
    end
    if #party > 0 then msg.post(TABLE, "stage", { party = party, fresh = true }) end
    for i, f in ipairs(battle.foes or {}) do
        local id = id_of(f) or ("foe" .. i)
        names[id] = f.name or id
        foes[#foes + 1] = { id = id, sprite = f.sprite or SPRITE[f.monster_id] or f.monster_id or "bandit",
            x = f.x or 14 + (i % 2), y = f.y or 5 + i, side = "foe" }
    end
    if #foes > 0 then msg.post(TABLE, "spawn", { list = foes }) end
    app.playback = { events = events, names = names, index = 1, wait = 1.8, caption = "The party takes their places." }
    zoom(app, 2)
end

local function refresh(app, force)
    app.snap = guided.snapshot(app.state)
    app.focus_i, app.phase_age = 1, 0
    stage(app, app.snap, force)
    if app.snap.phase == "result" then
        local r = app.snap.roll
        if r then
            msg.post(DICE, "tumble", { tray = r.who or r.actor or "dm_open", value = r.d20 or r.value })
            ambience.sfx("dice", 0.7)
        end
        begin_replay(app, app.snap)
    end
    render(app)
end

local function start_new(app)
    local seed = config("streamlined.seed", 0)
    app.state = guided.new(seed > 0 and seed or os.time())
    app.title, app.overlay, app.error, app.replayed, app.playback, app.stage_key = false, nil, nil, nil, nil, nil
    app.last_phase = nil
    app.resume = nil
    save(app)
    refresh(app, true)
end

function M.init(self)
    msg.post(".", "acquire_input_focus")
    gui.set_render_order(4)
    local auto = config("streamlined.autotest", 0) == 1
    local app = {
        time = 0, phase_age = 0, speed = 1, title = true, poses = {}, focus_i = 1,
        save_path = sys.get_save_file("behind_the_screen_streamlined", auto and "autotest_campaign.json" or "campaign.json"),
        autotest = auto, auto_at = 2,
    }
    self.app = app
    app.resume, app.resume_error = load_save(app.save_path)
    if auto then app.resume = nil end
    app.redraw = function() protect(app, render, app) end
    app.retry_save = function() save(app); app.redraw() end
    app.close_overlay = function()
        if not lock(app) then return false end
        app.overlay = nil; app.redraw(); return true
    end
    app.show_menu = function()
        if app.title or not lock(app) then return false end
        save(app); app.overlay = "menu"; app.redraw(); return true
    end
    app.open_scrapbook = function()
        if app.title or not lock(app) then return false end
        app.overlay, app.history_page = "story", nil; app.redraw(); return true
    end
    app.return_title = function()
        if not lock(app) then return false end
        if not save(app) then app.redraw(); return false end
        app.title, app.overlay, app.playback = true, nil, nil
        app.resume = { state = app.state, snapshot = guided.snapshot(app.state) }
        zoom(app, 1); ambience.screen(app, "intro"); app.redraw(); return true
    end
    app.recover_title = function()
        app.error, app.overlay, app.playback = nil, nil, nil
        app.resume, app.resume_error = load_save(app.save_path)
        app.state, app.title = nil, true
        zoom(app, 1); app.redraw()
    end
    app.start_new = function()
        if not lock(app) then return false end
        if app.state or app.resume then
            app.overlay = "reset"; app.redraw(); return true
        end
        return protect(app, function() start_new(app); return true end)
    end
    app.confirm_new = function()
        if app.overlay ~= "reset" or not lock(app) then return false end
        return protect(app, function() start_new(app); return true end)
    end
    app.continue_game = function()
        if not app.title or not app.resume or not lock(app) then return false end
        return protect(app, function()
            app.state, app.title, app.overlay, app.error = app.resume.state, false, nil, nil
            app.replayed, app.last_phase = nil, nil
            refresh(app, true)
            return true
        end)
    end
    app.finish_replay = function()
        if not app.playback or not lock(app) then return false end
        app.playback = nil
        app.redraw()
        return true
    end
    app.choose = function(id)
        if app.title or app.overlay or app.error or app.playback then return false end
        local found
        for _, c in ipairs(app.snap.cards or {}) do if c.id == id and not c.disabled then found = true end end
        if not found or not lock(app) then return false end
        return protect(app, function()
            local ok, err = guided.choose(app.state, id)
            assert(ok, err or "choice was refused")
            save(app)
            refresh(app)
            ambience.sfx("card", 0.6)
            return true
        end)
    end
    app.advance = function()
        if app.title or app.overlay or app.error then return false end
        if app.playback then return app.finish_replay() end
        if #(app.snap.cards or {}) > 0 or app.snap.phase == "complete" or not lock(app) then return false end
        return protect(app, function()
            local ok, err = guided.advance(app.state)
            assert(ok, err or "cannot advance from this moment")
            save(app)
            refresh(app)
            return true
        end)
    end
    kit.on_press = function() ambience.sfx("click", 0.6) end
    msg.post(HUD, "game_mode", { on = true })
    msg.post(CAMERA, "game_mode", { on = true })
    msg.post(CAMERA, "block_input", { on = true })
    msg.post(TABLE, "seats", { present = { mara = true, dev = true, jess = true, sam = true } })
    msg.post(TABLE, "vignette")
    msg.post(TABLE, "track", { on = true })
    msg.post(DICE, "sets", { sets = { mara = "amethyst", dev = "ember", jess = "jade", sam = "deep_sea", dm_open = "bone" } })
    zoom(app, 1)
    ambience.screen(app, "intro")
    protect(app, render, app)
end

function M.update(self, dt)
    local app = self.app
    if not app then return end
    app.time = app.time + dt
    if not app.refocused then
        app.refocused = true
        msg.post(".", "acquire_input_focus")
    end
    if app.error then return end
    protect(app, function()
        if not app.title and not app.overlay then
            app.phase_age = app.phase_age + dt
            if app.playback then
                app.playback.wait = app.playback.wait - dt * app.speed
                if app.playback.wait <= 0 then replay_step(app) end
            end
            local rs = app.snap and app.snap.reactions or {}
            if #rs > 1 then
                app.reaction_clock = (app.reaction_clock or 0) + dt
                local current = rs[app.reaction_index or 1]
                local dwell = math.max(4, #(current.text or "") / 18)
                if app.reaction_clock >= dwell and app.reaction_index < #rs then
                    app.reaction_index = app.reaction_index + 1
                    app.reaction, app.reaction_clock = rs[app.reaction_index], 0
                    render(app)
                end
            end
        end
        if app.autotest and app.time >= app.auto_at then
            app.auto_at = app.time + 2
            if app.title then app.start_new()
            elseif app.overlay == "reset" then app.confirm_new()
            elseif app.playback then
                if app.phase_age > 8 then app.finish_replay() end
            elseif app.snap.phase == "complete" then
                if not app.auto_done then print("GUIDED_AUTOTEST_COMPLETE"); app.auto_done = true end
            elseif #(app.snap.cards or {}) > 0 then
                local list = app.snap.cards
                local i = ((app.snap.episode or 1) + (app.snap.scene_index or 1) - 2) % #list + 1
                app.choose(list[i].id)
            else app.advance() end
        end
    end)
end

function M.final(self)
    if self.app and self.app.state and not self.app.error then save(self.app) end
    kit.on_press = nil
end

function M.on_message(self, message_id, message)
    local app = self.app
    if app and message_id == hash("anchors") then app.anchors = message end
end

function M.on_input(self, action_id, action)
    local app = self.app
    if not app then return true end
    if action_id == nil then
        if action.x and action.y then protect(app, kit.on_move, action.x, action.y) end
        return true
    end
    if not action.pressed then return true end
    if action_id == A.touch then
        if action.x and action.y then protect(app, kit.on_click, action.x, action.y) end
        return true
    end
    if action_id == A.music then ambience.toggle_music(); return true end
    if app.error then
        if action_id == A.confirm or action_id == A.back then app.recover_title() end
        return true
    end
    if app.overlay then
        if action_id == A.back or (action_id == A.confirm and app.overlay == "menu") then app.close_overlay() end
        return true
    end
    if app.title then
        if action_id == A.confirm then
            if app.resume then app.continue_game() else app.start_new() end
        end
        return true
    end
    if action_id == A.back then app.show_menu(); return true end
    if action_id == A.story then app.open_scrapbook(); return true end
    if action_id == A.fast then app.speed = math.min(4, app.speed * 2); return true end
    if action_id == A.slow then app.speed = math.max(0.5, app.speed / 2); return true end
    if app.playback then
        if action_id == A.confirm then app.finish_replay()
        elseif action_id == A.next and lock(app) then protect(app, replay_step, app) end
        return true
    end
    local cards = app.snap.cards or {}
    local n = NUMBER[action_id]
    if n and cards[n] then app.choose(cards[n].id)
    elseif (action_id == A.up or action_id == A.down) and #cards > 0 then
        local delta = action_id == A.up and -1 or 1
        app.focus_i = ((app.focus_i or 1) - 1 + delta) % #cards + 1
        app.redraw()
    elseif action_id == A.confirm or action_id == A.next then
        if app.snap.phase == "complete" then app.start_new()
        elseif #cards > 0 then
            if action_id == A.confirm then app.choose(cards[app.focus_i or 1].id) end
        else app.advance() end
    end
    return true
end

return M
