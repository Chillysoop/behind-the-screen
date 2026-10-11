-- Game night (M4): the table plays the night. Scenery drops onto the mat, paper
-- minis walk and fight, the players lean in or drift to their phones, and speech
-- bubbles pop over their heads. Captions carry the DM's narration; decision cards,
-- improv hands, rulings and big rolls slide in when the DM is needed.
--
-- The model (game/model/night.lua) hands over one beat at a time with its playing
-- time; this view stages it (messages to main/table/table.script), times it, and
-- answers the beats that need the DM.
--
-- Keys: Space skip   F speed 1x/2x/4x   Tab log   H your rolls hidden/open
--       T gentle timer on decisions   1-4 camera, or a card's options   N your notes
--
-- The real-session pass: the player panels (game/ui/panels.lua) show who's who, their faces
-- and their dice; fights show everyone's hit points, conditions, spell areas and the turn
-- order on the mat (game/ui/battle_hud.lua); clues the party finds go in the DM's notes.

local kit = require "game.ui.kit"
local ambience = require "game.ui.ambience"
local theme = require "game.ui.theme"
local empathy = require "game.model.empathy"
local pacing = require "game.model.pacing"
local night_mod = require "game.model.night"
local util = require "game.model.util"
local review = require "game.ui.review_view"
local panels = require "game.ui.panels"
local battle_hud = require "game.ui.battle_hud"
local input_trace = require "game.ui.input_trace"

local M = {}

local TABLE = "/table#table"
local H = 900
local SPEEDS = { 1, 2, 4 }
-- The gentle timer (T): seconds before the safe default plays itself.
local TIMERS = { decision = 30, improv = 45, ruling = 25, roll_where = 15, cook = 15 }
local ROLL_PATIENCE = 9          -- seconds to wait for the physical die before rolling for it

local CHIP_Y, CHIP_W, CHIP_H = panels.Y, panels.W, panels.H
local RIGHT_X, RIGHT_W = 984, 592
local LEFT_X, LEFT_W = 24, 560
-- The DM's narration sits above a row kept free for the players' speech bubbles.
local CAPTION_BOTTOM, CAPTION_W = 664, 900
local CARD_BOTTOM = 760
-- Longer read-alouds: the recap and the session's opening.
local READ_ALOUD = { recap = true, opening = true }
local LOG_X, LOG_Y, LOG_W, LOG_H = 24, 70, 520, 690
local STRIP_RIGHT, STRIP_Y, DIE = 1576, 66, 30

local CLASS_SPRITE = { fighter = "fighter", rogue = "rogue", cleric = "cleric", wizard = "wizard" }
local CAST_SPRITE = {
    goblins = "goblin_boss", gus = "npc_gus", stranger = "npc_stranger", rook = "bandit_captain",
    hermit = "npc_hermit", rivals = "npc_rival", ogre = "ogre", corin = "npc_corin",
    wolf_lieutenant = "tough", madame_sable = "npc_sable", abbot_ghost = "npc_ghost",
    -- M6 casts borrow a mini until they get their own.
    holt = "npc_hermit", brother_tumble = "npc_gus", goblin_scout = "goblin_boss", verrin = "npc_rival",
    bone_choir = "cultist", white_wolf = "dire_wolf",
    -- The slice rework's casts.
    wren = "npc_stranger", grey_coat = "tough", miller = "npc_gus", turncoat_guide = "bandit_captain",
    market_friend = "npc_sable", merchant = "npc_sable", cutpurses = "bandit", wolf_pack = "dire_wolf",
    restless_dead = "skeleton",
}
local MONSTER_SPRITES = {
    goblin_boss = true, bandit = true, bandit_captain = true, cultist = true, tough = true, wolf = true,
    dire_wolf = true, skeleton = true, zombie = true, ghoul = true, ogre = true,
}
local BLOCKED = {
    sanctuary = "Sanctuary", decoy = "Hit the decoy", mirror_image = "Hit an image", shield = "Shield!",
    warding_flash = "Warding Flare", parry = "Parried",
}
local TIER_TITLE = { triumph = "A triumph!", success = "It works.", near = "So close...", flop = "That's a flop." }
local FIT_HAND = { great = "Fits this scene", good = "Always works", poor = "A stretch" }
local FIT_DRIFT = { great = "They'll love this", good = "Solid", poor = "Not their thing" }
local FIT_TOGETHER = { great = "Together: this will sing", good = "Together: solid", poor = "Together: a stretch" }

local function rgba(r, g, b, a)
    return vmath.vector4(r, g, b, a or 1)
end

local SPARK = {
    fire_bolt = rgba(1.0, 0.55, 0.25), sacred_flame = rgba(1.0, 0.9, 0.55), healing_word = rgba(0.5, 1.0, 0.55),
    cure_wounds = rgba(0.5, 1.0, 0.55), shield = rgba(0.55, 0.75, 1.0), magic_missile = rgba(0.8, 0.6, 1.0),
    heal = rgba(0.5, 1.0, 0.55), crit = rgba(1.0, 0.85, 0.4),
    -- Spell areas and zones on the mat (real-session pass).
    burning_hands = rgba(1.0, 0.5, 0.2), scorching_ray = rgba(1.0, 0.45, 0.2), thunderwave = rgba(0.6, 0.8, 1.0),
    shatter = rgba(0.75, 0.85, 1.0), sleep = rgba(0.72, 0.58, 1.0), web = rgba(0.92, 0.92, 0.88),
    grease = rgba(0.75, 0.62, 0.3), color_spray = rgba(1.0, 0.55, 0.85), bless = rgba(1.0, 0.9, 0.5),
    aid = rgba(1.0, 0.9, 0.5), guiding_bolt = rgba(1.0, 1.0, 0.8), ray_of_frost = rgba(0.6, 0.9, 1.0),
    shocking_grasp = rgba(0.7, 0.8, 1.0), chill_touch = rgba(0.6, 0.5, 0.9), hold_person = rgba(0.6, 0.6, 1.0),
    spiritual_weapon = rgba(1.0, 0.9, 0.6), mirror_image = rgba(0.8, 0.85, 1.0), inflict_wounds = rgba(0.6, 0.25, 0.45),
    acid_splash = rgba(0.6, 1.0, 0.4), ice_knife = rgba(0.6, 0.9, 1.0), prayer_of_healing = rgba(0.5, 1.0, 0.55),
}

local function post(id, data)
    msg.post(TABLE, id, data or {})
end

local function speed(app)
    return SPEEDS[app.speed_i or 1]
end

local function place(n, x, y)
    gui.set_position(n, vmath.vector3(x, H - y, 0))
end

local function alpha_of(c, a)
    return vmath.vector4(c.x, c.y, c.z, (c.w or 1) * a)
end

local function clock_text(seconds)
    local s = math.floor(seconds or 0)
    return util.int(math.floor(s / 60)) .. ":" .. string.format("%02d", s % 60)
end

local function monster_sprite(id, n)
    if id == "goblin_warrior" then
        return (n % 2 == 0) and "goblin_club" or "goblin_spear"
    end
    return MONSTER_SPRITES[id] and id or "bandit"
end

local function cam(app, index)
    app.cam = index
    app.zoom(index)
end

-- Playback camera when nothing special is happening.
local function rest_cam(app)
    if app.in_battle then
        cam(app, app.battle_cam or 2)
    else
        cam(app, 2)
    end
end

-- Setup ----------------------------------------------------------------------------

function M.start(app)
    app.night = app.campaign:start_night()
    app.log = {}
    app.strip = {}
    app.pending = nil
    app.rolling = false
    app.night_done = false
    app.speed_i = app.speed_i or 1
    app.log_open = false
    app.timer = 0.8
    app.beat_t = 0
    app.queue, app.qi = {}, 1
    app.hud = nil
    app.last_roll = {}
    app.chip_pose = {}
    app.clock_t = 0
    app.scene_label = "Everyone's here. Dice out."
    app.scene_sub = "Getting settled"
    app.progress = nil
    app.hp = {}
    app.in_battle = false
    app.names = {}
    app.anchors = { heads = {}, minis = {} }
    app.on_table = {}
    app.terrain = nil
    app.moods = {}
    app.caption = nil
    app.title_card = nil
    for _, p in ipairs(app.campaign.players) do
        app.names[p.key] = p.char
    end
    local present = {}
    for _, p in ipairs(app.campaign.players) do
        present[p.key] = p.present and true or false
    end
    post("seats", { present = present })
    post("clear", { how = "sweep" })
    post("track", { on = true })
    cam(app, 1)
    M.build(app)
end

function M.build(app)
    app.layers.base = kit.layer("night_base")
    M.draw_frame(app)
    app.layers.log = kit.layer("night_log")
    M.draw_log(app)
    app.layers.fx = kit.layer("night_fx")
    app.bubbles, app.floaters = {}, {}
    M.draw_caption(app)
    battle_hud.draw(app)
    app.speed_now = function()
        return speed(app)
    end
    if app.pending then
        M.show_modal(app, app.pending, true)
    elseif app.night_done then
        M.show_done(app)
    end
end

-- The frame: top bar, dice strip, player chips ------------------------------------------

local function status_text(app)
    local n = app.night
    return "Night " .. clock_text(n and n.clock or 0) .. " / 15:00      Calls " .. util.int(n and n:decision_count() or 0)
        .. "      Speed " .. util.int(speed(app)) .. "x      Your rolls: " .. ((n and n.dm_rolls) or "hidden")
        .. "      Timer: " .. (app.timer_on and "on" or "off")
end

function M.draw_frame(app)
    kit.use(app.layers.base)
    kit.box(0, 0, kit.W, 58, theme.bg_glass, { round = false })
    kit.text(24, 6, "WEEK " .. util.int(app.campaign.week), "ui22b", theme.gold)
    kit.text(24, 35, "GAME NIGHT", "ui14", theme.faint)
    app.n_label = kit.text(160, 6, kit.ellipsize(app.scene_label, "ui18b", 600), "ui18b", theme.text)
    app.n_sub = kit.text(160, 32, app.scene_sub or "", "ui14", theme.dim)
    -- Anything from an earlier build is gone with its layer.
    app.pip_nodes, app.strip_nodes = {}, {}
    -- Your notes: the story so far, who's who, the party's sheets (N).
    kit.button(776, 10, 112, 38, "Notes (N)", function()
        if app.open_notes then
            app.open_notes()
        end
    end, { font = "ui14", key = "night_notes" })
    app.n_status = kit.text(1576, 8, status_text(app), "ui14", theme.text, { pivot = gui.PIVOT_NE })
    kit.text(1576, 32, "Space skip    F speed    Tab log    N notes    H your rolls    T timer    1-4 camera or a card's options", "ui14", theme.faint,
        { pivot = gui.PIVOT_NE })
    -- The player panels: faces, minis, how they're doing, their dice. Click one for the sheet.
    panels.draw(app, function(key)
        if app.open_sheet then
            app.open_sheet(key)
        end
    end)
    M.draw_strip(app)
    M.draw_pips(app)
end

function M.refresh_status(app)
    if app.n_status then
        gui.set_text(app.n_status, status_text(app))
    end
end

function M.refresh_chips(app, scene_break)
    panels.refresh(app, scene_break)
end

function M.refresh_hp(app)
    panels.refresh_hp(app)
    battle_hud.refresh(app)
end

-- Dice strip: every d20 rolled tonight, newest on the right. The DM's own rolls show
-- as a face-down "?" while they stay behind the screen.
function M.add_die(app, d)
    table.insert(app.strip, d)
    if #app.strip > 40 then
        table.remove(app.strip, 1)
    end
    M.draw_strip(app)
end

function M.draw_strip(app)
    if not app.layers.base then
        return
    end
    kit.use(app.layers.base)
    kit.remove(app.strip_nodes or {})
    app.strip_nodes = {}
    local n = math.min(#app.strip, 16)
    for k = 1, n do
        local d = app.strip[#app.strip - n + k]
        local x = STRIP_RIGHT - (n - k + 1) * (DIE + 4)
        local col, label, ink = theme.teal, util.int(d.roll or 0), theme.bg
        if d.hidden then
            col, label, ink = theme.panel3, "?", theme.dim
        elseif d.big then
            col = theme.gold
        elseif d.dm then
            col, ink = theme.purple, theme.bg
        elseif d.crit then
            col = theme.gold
        elseif d.fumble or d.success == false then
            col = theme.red
        end
        table.insert(app.strip_nodes, kit.icon(x, STRIP_Y, DIE, "d20", col))
        table.insert(app.strip_nodes, kit.text(x + DIE / 2, STRIP_Y + DIE / 2, label, "ui14", ink, { pivot = gui.PIVOT_CENTER }))
    end
end

-- Scene progress: gold pips for wins needed, red for setbacks.
function M.draw_pips(app)
    if not app.layers.base then
        return
    end
    kit.use(app.layers.base)
    kit.remove(app.pip_nodes or {})
    app.pip_nodes = {}
    local pr = app.progress
    if not pr or not app.n_sub then
        return
    end
    local x = 160 + kit.width(app.scene_sub or "", "ui14") + 16
    for i = 1, pr.need do
        table.insert(app.pip_nodes, kit.dot(x + (i - 1) * 14 + 5, 41, 10, i <= pr.wins and theme.gold or kit.rgba("#ffffff", 0.18)))
    end
    x = x + pr.need * 14 + 10
    for i = 1, pr.max do
        table.insert(app.pip_nodes, kit.dot(x + (i - 1) * 14 + 5, 41, 10, i <= pr.setbacks and theme.red or kit.rgba("#ffffff", 0.1)))
    end
end

-- The log: compact (last few lines) or open (Tab) -------------------------------------------

function M.draw_log(app)
    local l = app.layers.log
    if not l then
        return
    end
    for _, n in ipairs(l.nodes) do
        gui.delete_node(n)
    end
    l.nodes, l.buttons = {}, {}
    kit.use(l)
    if app.log_open then
        kit.box(LOG_X, LOG_Y, LOG_W, LOG_H, theme.bg_glass, { radius = 10 })
        kit.text(LOG_X + LOG_W - 12, LOG_Y + LOG_H - 22, "Tab: hide the log", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
        local w = LOG_W - 32
        local y = LOG_Y + LOG_H - 34
        local back = math.max(0, math.min(app.log_scroll or 0, #app.log - 1))
        app.log_scroll = back
        if back > 0 then
            kit.text(LOG_X + 12, LOG_Y + LOG_H - 22, "Scrolled back: wheel down for newer", "ui14", theme.gold)
        end
        local first_shown = nil
        for i = #app.log - back, 1, -1 do
            local e = app.log[i]
            local font = (e.style == "scene") and "ui18b" or "ui18"
            local h = kit.text_height(e.text, font, w) + (e.style == "scene" and 14 or 6)
            if y - h < LOG_Y + 30 then
                break
            end
            y = y - h
            local color = theme.log[e.style] or theme.text
            color = alpha_of(color, math.max(0.45, 1 - (#app.log - i) * 0.04))
            if e.style == "scene" then
                kit.box(LOG_X + 10, y + 2, LOG_W - 20, h - 6, kit.rgba("#ffffff", 0.07), { radius = 6 })
            end
            kit.text(LOG_X + 16, y + (e.style == "scene" and 7 or 0), e.text, font, color, { w = w })
            first_shown = i
        end
        if first_shown and first_shown > 1 then
            kit.text(LOG_X + 16, LOG_Y + 8, "Wheel up for earlier", "ui14", theme.faint)
        end
        -- A card that's up stays on top of the log.
        local modal = app.layers.modal
        local ref = modal and modal.nodes and modal.nodes[1]
        if ref and gui.move_below then
            for _, n in ipairs(l.nodes) do
                gui.move_below(n, ref)
            end
        end
    else
        -- The last few lines, small and fading, out of the way of the table. Long lines wrap
        -- (nothing gets cut); older ones drop off the top.
        local lines = {}
        for i = #app.log, 1, -1 do
            local e = app.log[i]
            local wrapped = kit.wrap(e.text, "ui14", 446)
            if #lines + #wrapped > 5 and #lines > 0 then
                break
            end
            for k = #wrapped, 1, -1 do
                table.insert(lines, 1, { text = wrapped[k], style = e.style, age = #app.log - i })
            end
            if #lines >= 5 then
                break
            end
        end
        local y = LOG_Y + 8
        if #lines > 0 then
            kit.box(LOG_X, LOG_Y, 470, 8 + #lines * 20 + 8, kit.rgba("#140e0b", 0.55), { radius = 8 })
        end
        for _, ln in ipairs(lines) do
            local color = alpha_of(theme.log[ln.style] or theme.text, math.max(0.5, 1 - 0.15 * ln.age))
            kit.text(LOG_X + 12, y, ln.text, "ui14", color)
            y = y + 20
        end
    end
end

function M.push(app, text, style)
    -- The log keeps the whole night (the fix pass); scrolled back, the view stays put.
    table.insert(app.log, { text = text, style = style })
    if (app.log_scroll or 0) > 0 then
        app.log_scroll = app.log_scroll + 1
    end
    M.draw_log(app)
end

function M.toggle_log(app)
    app.log_open = not app.log_open
    app.log_scroll = 0
    M.draw_log(app)
end

-- Is the pointer over the open log? (The mouse wheel scrolls it there, and zooms elsewhere.)
function M.over_log(app, x, y)
    if not app.log_open then
        return false
    end
    local ly = kit.H - y
    return x >= LOG_X and x <= LOG_X + LOG_W and ly >= LOG_Y and ly <= LOG_Y + LOG_H
end

-- lines > 0 goes back to earlier lines.
function M.scroll_log(app, lines)
    app.log_scroll = math.max(0, (app.log_scroll or 0) + lines)
    M.draw_log(app)
end

-- Captions and the scene title card -----------------------------------------------------------

function M.draw_caption(app)
    kit.use(app.layers.fx)
    local c = {}
    c.box = kit.box(0, 0, 100, 40, kit.rgba("#140e0b", 0.82), { radius = 12 })
    c.text = kit.text(0, 0, "", "story22", theme.text, { pivot = gui.PIVOT_N })
    c.life, c.age, c.color = 0, 0, theme.text
    gui.set_enabled(c.box, false)
    gui.set_enabled(c.text, false)
    app.caption = c
    app.title_card = nil
end

function M.caption(app, text, style)
    local c = app.caption
    if not c then
        return
    end
    local font = (style == "dice" or style == "check" or style == "system" or style == "warn") and "ui22b" or "story22"
    local width = READ_ALOUD[style] and 1060 or CAPTION_W
    local max_lines = READ_ALOUD[style] and 6 or 5
    local lines = kit.wrap(text, font, width - 48)
    if #lines > max_lines then
        local keep = {}
        for i = 1, max_lines do
            keep[i] = lines[i]
        end
        keep[max_lines] = kit.ellipsize(keep[max_lines] .. " ...", font, width - 48)
        lines = keep
    end
    local tw = 0
    for _, l in ipairs(lines) do
        tw = math.max(tw, kit.width(l, font))
    end
    local w, h = tw + 48, #lines * kit.line_height(font) + 22
    local y = CAPTION_BOTTOM - h
    -- With the log open, the caption centers on the rest of the screen.
    local cx = app.log_open and math.max(LOG_X + LOG_W + 16 + w / 2, 800) or 800
    gui.set_size(c.box, vmath.vector3(w, h, 0))
    place(c.box, cx - w / 2, y)
    app.caption_rect = { x = cx - w / 2, y = y, w = w, h = h }
    gui.set_font(c.text, font)
    gui.set_text(c.text, table.concat(lines, "\n"))
    place(c.text, cx, y + 11)
    c.color = theme.log[style] or theme.text
    c.age = 0
    c.life = (pacing.read(text) + 0.6) / speed(app)
    c.style = style
    gui.set_enabled(c.box, true)
    gui.set_enabled(c.text, true)
    gui.set_color(c.text, c.color)
    gui.set_color(c.box, kit.rgba("#140e0b", 0.82))
end

function M.title(app, top, title, sub)
    M.drop_title(app)
    kit.use(app.layers.fx)
    sub = kit.ellipsize(sub or "", "ui18", 1100)
    local w = math.min(1200, math.max(kit.width(title, "title30"), kit.width(sub, "ui18"), kit.width(top, "ui18b")) + 80)
    local x, y = 800 - w / 2, 250
    local t = { age = 0, life = 3.4 / speed(app), nodes = {} }
    t.nodes[1] = kit.box(x, y, w, 118, kit.rgba("#140e0b", 0.8), { radius = 14 })
    t.nodes[2] = kit.text(800, y + 14, top, "ui18b", theme.gold, { pivot = gui.PIVOT_N })
    t.nodes[3] = kit.text(800, y + 40, title, "title30", theme.text, { pivot = gui.PIVOT_N })
    t.nodes[4] = kit.text(800, y + 84, sub or "", "ui18", theme.dim, { pivot = gui.PIVOT_N })
    t.colors = { kit.rgba("#140e0b", 0.8), theme.gold, theme.text, theme.dim }
    app.title_card = t
end

-- A note sliding in under the top bar: a clue for the DM's notes.
function M.toast(app, top, text)
    M.drop_toast(app)
    kit.use(app.layers.fx)
    local w = 620
    local lines = kit.wrap(text, "ui18", w - 40)
    local h = 40 + #lines * kit.line_height("ui18") + 12
    local x, y = 800 - w / 2, 136
    local t = { age = 0, life = (3.2 + #text / 30) / math.sqrt(speed(app)), nodes = {} }
    t.nodes[1] = kit.box(x - 2, y - 2, w + 4, h + 4, theme.gold, { radius = 12 })
    t.nodes[2] = kit.box(x, y, w, h, kit.rgba("#201813", 0.96), { radius = 11 })
    t.nodes[3] = kit.text(x + 20, y + 12, top, "ui14", theme.gold)
    t.nodes[4] = kit.text(x + 20, y + 34, table.concat(lines, "\n"), "ui18", theme.text)
    t.nodes[5] = kit.text(x + w - 18, y + 12, "N: open your notes", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    t.colors = { theme.gold, kit.rgba("#201813", 0.96), theme.gold, theme.text, theme.faint }
    app.toast_card = t
end

function M.drop_toast(app)
    if app.toast_card then
        kit.remove(app.toast_card.nodes)
        app.toast_card = nil
    end
end

function M.drop_title(app)
    if app.title_card then
        kit.remove(app.title_card.nodes)
        app.title_card = nil
    end
end

-- Speech bubbles and floating numbers -------------------------------------------------------

local function on_screen(a)
    return a and a[1] > 0.03 and a[1] < 0.97 and a[2] > 0.08 and a[2] < 0.84
end

local function chip_index(app, key)
    for i, p in ipairs(app.campaign.players) do
        if p.key == key then
            return i
        end
    end
    return 1
end

-- Where on screen an anchor is right now: a player's head (or their chip when the
-- camera can't see them), or a mini on the mat.
local function anchor_xy(app, a)
    local an = app.anchors or {}
    if a.head then
        local h = an.heads and an.heads[a.head]
        if on_screen(h) then
            return h[1] * kit.W, h[2] * H
        end
        -- Off camera: over their panel, inside its column.
        return panels.anchor(app, a.head)
    end
    local m = an.minis and an.minis[a.mini]
    if on_screen(m) then
        return m[1] * kit.W, m[2] * H
    end
    return nil
end

local function drop_bubble(app, i)
    local b = table.remove(app.bubbles, i)
    if b then
        kit.remove(b.nodes)
    end
end

function M.clear_fx(app)
    while app.bubbles and #app.bubbles > 0 do
        drop_bubble(app, 1)
    end
    for _, f in ipairs(app.floaters or {}) do
        kit.remove(f.nodes)
    end
    app.floaters = {}
end

local function same_anchor(a, b)
    return (a.head and a.head == b.head) or (a.mini and a.mini == b.mini)
end

function M.bubble(app, anchor, speaker, text, ic)
    if not app.layers.fx then
        return
    end
    for i = #app.bubbles, 1, -1 do
        if same_anchor(app.bubbles[i].anchor, anchor) then
            drop_bubble(app, i)
        end
    end
    while #app.bubbles >= 4 do
        drop_bubble(app, 1)
    end
    kit.use(app.layers.fx)
    local lines = kit.wrap(text, "ui18", 300)
    if #lines > 5 then
        local keep = {}
        for i = 1, 5 do
            keep[i] = lines[i]
        end
        keep[5] = kit.ellipsize(keep[5] .. " ...", "ui18", 300)
        lines = keep
    end
    local tw = kit.width(speaker, "ui14")
    for _, l in ipairs(lines) do
        tw = math.max(tw, kit.width(l, "ui18"))
    end
    local bg = ic and theme.paper or theme.bubble
    local ink = ic and theme.ink or theme.text
    local label = ic and theme.ink_dim or theme.dim
    local b = { anchor = anchor, w = tw + 26, h = 30 + #lines * 23 + 8, age = 0,
                life = math.max(1.4, (pacing.read(text) + 0.4) / speed(app)) }
    b.nodes = {
        kit.box(0, 0, b.w, b.h, bg, { radius = 10 }),
        kit.icon(0, 0, 18, "tail", bg),
        kit.text(0, 0, speaker, "ui14", label),
        kit.text(0, 0, table.concat(lines, "\n"), "ui18", ink),
    }
    b.colors = { bg, bg, label, ink }
    table.insert(app.bubbles, b)
    M.place_bubbles(app)
end

function M.place_bubbles(app)
    local placed = {}
    local cap = app.caption_rect
    for _, b in ipairs(app.bubbles) do
        local ax, ay, col_x, col_w = anchor_xy(app, b.anchor)
        local show = ax ~= nil
        for _, n in ipairs(b.nodes) do
            gui.set_enabled(n, show)
        end
        if show then
            local x = util.clamp(ax - b.w / 2, 8, kit.W - 8 - b.w)
            if col_x then
                -- Over a player's panel: stay in their column.
                x = util.clamp(ax - b.w / 2, col_x, col_x + col_w - b.w)
            end
            local y = util.clamp(ay - b.h - 16, 64, (col_x and CHIP_Y - 8 or CARD_BOTTOM) - b.h)
            -- Never over the DM's caption: go above it.
            if cap and x < cap.x + cap.w + 6 and cap.x < x + b.w + 6 and y < cap.y + cap.h + 6 and cap.y < y + b.h + 6 then
                y = cap.y - b.h - 8
            end
            -- Don't stack on top of a bubble that's already up.
            for _, o in ipairs(placed) do
                if x < o.x + o.w + 6 and o.x < x + b.w + 6 and y < o.y + o.h + 6 and o.y < y + b.h + 6 then
                    y = o.y - b.h - 8
                    if y < 64 then
                        y = o.y + o.h + 8
                    end
                end
            end
            b.x, b.y = x, y
            table.insert(placed, b)
            place(b.nodes[1], x, y)
            place(b.nodes[2], util.clamp(ax - 9, x + 10, x + b.w - 28), y + b.h - 2)
            place(b.nodes[3], x + 13, y + 6)
            place(b.nodes[4], x + 13, y + 28)
        end
    end
end

-- A word or number rising off a mini: damage, misses, spell names.
function M.float(app, id, text, color, big)
    if not app.layers.fx or not id then
        return
    end
    local ax, ay = anchor_xy(app, { mini = id })
    if not ax then
        return
    end
    -- Stack floaters that land on the same mini at once.
    local stack = 0
    for _, f in ipairs(app.floaters) do
        if f.id == id and f.age < 0.5 then
            stack = stack + 1
        end
    end
    kit.use(app.layers.fx)
    local font = big and "ui22b" or "ui18b"
    local w, h = kit.width(text, font) + 18, big and 34 or 28
    local x, y = ax - w / 2, ay - h - stack * (h + 4)
    local f = { id = id, x = x, y = y, w = w, h = h, age = 0, life = 1.3 / math.sqrt(speed(app)) }
    local bg = kit.rgba("#140e0b", 0.8)
    f.nodes = { kit.box(x, y, w, h, bg, { radius = 8 }), kit.text(x + w / 2, y + h / 2, text, font, color, { pivot = gui.PIVOT_CENTER }) }
    f.colors = { bg, color }
    table.insert(app.floaters, f)
end

local function fade(nodes, colors, a)
    for i, n in ipairs(nodes) do
        gui.set_color(n, alpha_of(colors[i], a))
    end
end

function M.update_fx(app, dt)
    if not app.layers.fx then
        return
    end
    for i = #app.bubbles, 1, -1 do
        local b = app.bubbles[i]
        b.age = b.age + dt
        if b.age >= b.life then
            drop_bubble(app, i)
        elseif b.life - b.age < 0.3 then
            fade(b.nodes, b.colors, (b.life - b.age) / 0.3)
        end
    end
    M.place_bubbles(app)
    for i = #app.floaters, 1, -1 do
        local f = app.floaters[i]
        f.age = f.age + dt
        local k = f.age / f.life
        if k >= 1 then
            kit.remove(f.nodes)
            table.remove(app.floaters, i)
        else
            local rise = 38 * (1 - (1 - k) * (1 - k))
            place(f.nodes[1], f.x, f.y - rise)
            place(f.nodes[2], f.x + f.w / 2, f.y + f.h / 2 - rise)
            fade(f.nodes, f.colors, k < 0.6 and 1 or (1 - k) / 0.4)
        end
    end
    local c = app.caption
    if c and c.life > 0 then
        c.age = c.age + dt
        local a = 1
        if c.age > c.life then
            a = math.max(0, 1 - (c.age - c.life) / 0.4)
            if a == 0 then
                c.life = 0
                app.caption_rect = nil
                gui.set_enabled(c.box, false)
                gui.set_enabled(c.text, false)
            end
        end
        gui.set_color(c.text, alpha_of(c.color, a))
        gui.set_color(c.box, kit.rgba("#140e0b", 0.82 * a))
    end
    local t = app.title_card
    if t then
        t.age = t.age + dt
        if t.age >= t.life then
            M.drop_title(app)
        elseif t.life - t.age < 0.5 then
            fade(t.nodes, t.colors, (t.life - t.age) / 0.5)
        end
    end
    local tc = app.toast_card
    if tc then
        tc.age = tc.age + dt
        if tc.age >= tc.life then
            M.drop_toast(app)
        elseif tc.life - tc.age < 0.5 then
            fade(tc.nodes, tc.colors, (tc.life - tc.age) / 0.5)
        end
    end
end

function M.on_anchors(app, message)
    app.anchors = { heads = message.heads or {}, minis = message.minis or {} }
end

-- Playback ---------------------------------------------------------------------------------

local function schedule(app, at, fn)
    table.insert(app.queue, { at = at, fn = fn })
end

local function run_queue(app, all)
    while app.queue[app.qi] and (all or app.queue[app.qi].at <= app.beat_t) do
        local item = app.queue[app.qi]
        app.qi = app.qi + 1
        item.fn()
    end
end

function M.update(app, dt)
    app.clock_t = (app.clock_t or 0) + dt
    M.update_fx(app, dt)
    panels.update(app, dt)
    battle_hud.update(app, dt)
    -- The DM's notes or a character sheet is open: the table waits.
    if app.overlay then
        return
    end
    if app.night_done then
        return
    end
    -- The review mode holds the night while you read a line or work the queue.
    if app.review and app.review.hold then
        return
    end
    if app.pending then
        if app.timer_on and app.pending_left then
            app.pending_left = app.pending_left - dt
            M.update_timer_bar(app)
            if app.pending_left <= 0 then
                -- The gentle timer ran out: the safe default plays.
                M.answer(app, nil)
            end
        end
        return
    end
    if app.rolling then
        app.roll_wait = (app.roll_wait or 0) + dt
        if app.roll_wait > ROLL_PATIENCE then
            M.on_roll(app, nil)
        end
        return
    end
    local sdt = dt * speed(app)
    app.beat_t = app.beat_t + sdt
    run_queue(app, false)
    app.timer = app.timer - sdt
    if app.timer <= 0 then
        run_queue(app, true)
        M.step(app)
    end
end

function M.skip(app)
    if not (app.pending or app.rolling or app.night_done) then
        app.timer = 0
    end
end

function M.cycle_speed(app)
    app.speed_i = ((app.speed_i or 1) % #SPEEDS) + 1
    M.refresh_status(app)
end

function M.toggle_timer(app)
    app.timer_on = not app.timer_on
    if app.pending then
        app.pending_left = app.timer_on and TIMERS[app.pending.kind] or nil
        M.show_modal(app, app.pending, true)
    end
    M.refresh_status(app)
end

function M.toggle_dm_rolls(app)
    if not app.night then
        return
    end
    local open = app.night.dm_rolls ~= "open"
    app.night:set_dm_rolls(open and "open" or "hidden")
    M.push(app, open and "You roll the monsters' attacks in the open now. The table sees every die."
        or "Your rolls go back behind the screen.", "dm")
    M.refresh_status(app)
end

function M.step(app, answer)
    local ev = app.night:advance(answer)
    app.queue, app.qi, app.beat_t = {}, 1, 0
    app.timer = ev.t or 0
    app.last_ev = ev
    M.handle(app, ev)
    -- Resting poses follow how into it everyone is.
    local poses = app.night:poses()
    local changed = false
    for k, v in pairs(poses) do
        if app.moods[k] ~= v then
            changed = true
        end
    end
    if changed then
        app.moods = poses
        post("mood", { poses = poses })
    end
    M.refresh_chips(app, ev.kind == "scene" or ev.kind == "done")
    M.refresh_status(app)
    if app.review and app.review.on then
        review.draw_rail(app)
    end
    if app.refresh_debug then
        app.refresh_debug()
    end
end

-- Staging ----------------------------------------------------------------------------------

local function party_list(list)
    local out = {}
    for _, p in ipairs(list or {}) do
        table.insert(out, { id = p.id, class = p.class, sprite = CLASS_SPRITE[p.class] or "fighter", x = p.x, y = p.y })
    end
    return out
end

local function stage(app, ev)
    local fresh = ev.terrain ~= app.terrain
    if fresh then
        app.terrain = ev.terrain
        post("terrain", { set = ev.terrain })
    end
    local npc
    if ev.npc then
        npc = { sprite = CAST_SPRITE[ev.npc.cast] or "npc_stranger", x = ev.npc.x, y = ev.npc.y }
        app.names.npc = ev.npc.name
    end
    app.on_table = { npc = npc and true or nil }
    post("stage", { party = party_list(ev.party), npc = npc, fresh = fresh })
end

-- What a mini or a player is called in the log.
local function name_of(app, id)
    if type(id) ~= "string" then
        return "someone"
    end
    return app.names[id] or id
end

local function spark(app, target, color)
    if type(target) == "string" then
        post("spark", { id = target, color = color })
    elseif type(target) == "table" then
        if type(target[1]) == "number" then
            post("spark", { x = target[1], y = target[2], color = color, size = 1.6 })
        else
            for _, id in ipairs(target) do
                if type(id) == "string" then
                    post("spark", { id = id, color = color })
                end
            end
        end
    end
end

local function set_hp(app, id, hp, max)
    if app.hp[id] and hp then
        app.hp[id] = { hp, max or app.hp[id][2] }
        M.refresh_hp(app)
    end
    battle_hud.set_hp(app, id, hp, max)
end

-- Whose turn: the mini acting, for the turn order.
local function is_party(app, id)
    return type(id) == "string" and app.campaign:player(id) ~= nil
end

local function signed(n)
    n = math.floor((n or 0) + 0.5)
    return (n >= 0 and "+" or "") .. util.int(n)
end

-- One step of a combat turn on the mat.
function M.play_step(app, s, pace)
    local k = s.kind
    local sp = speed(app) / (pace or 1)
    if k == "move" then
        if s.path and #s.path > 0 then
            post("walk", { id = s.id, path = s.path, step = pacing.PER_SQUARE / sp })
        end
    elseif k == "initiative" then
        -- Everyone rolls initiative: the heroes' dice show on their panels, the order along the top.
        for _, o in ipairs(s.order or {}) do
            if o.pc and is_party(app, o.id) then
                panels.roll(app, o.id, { roll = o.roll, mod = o.bonus, total = o.total, what = "Initiative" })
            end
        end
        battle_hud.initiative(app, s.order)
        local first = s.order and s.order[1]
        if first then
            M.push(app, "Initiative: " .. (function()
                local parts = {}
                for _, o in ipairs(s.order) do
                    table.insert(parts, (o.name or "?") .. " " .. util.int(o.total or 0))
                end
                return table.concat(parts, ", ")
            end)(), "system")
        end
    elseif k == "attack" then
        if s.target then
            post("lunge", { id = s.id, target = s.target, ranged = s.ranged, time = 0.32 / sp })
        end
        M.add_die(app, { roll = s.roll, success = s.hit, crit = s.crit, dm = s.dm, hidden = s.hidden })
        app.last_attack = s
        if is_party(app, s.id) and s.roll then
            panels.roll(app, s.id, { roll = s.roll, mod = (s.total or s.roll) - s.roll, total = s.total,
                                     against = s.ac and ("AC " .. util.int(s.ac)) or nil, what = s.weapon or "Attack",
                                     success = s.hit, crit = s.crit, fumble = s.roll == 1 })
        end
        if not s.hit then
            M.float(app, s.target, s.blocked and (BLOCKED[s.blocked] or "Blocked") or "miss", theme.dim)
            local nums = ""
            if s.roll and s.total and s.ac and not s.hidden then
                nums = " (" .. util.int(s.roll) .. signed(s.total - s.roll) .. " = " .. util.int(s.total) .. " vs AC "
                    .. util.int(s.ac) .. ")"
            end
            M.push(app, name_of(app, s.id) .. (s.blocked and " is stopped: " .. (BLOCKED[s.blocked] or "blocked") .. "."
                or (" misses " .. name_of(app, s.target) .. nums .. ".")), "system")
        end
    elseif k == "damage" then
        post("hit", { id = s.id })
        M.float(app, s.id, "-" .. util.int(s.amount or 0), s.crit and theme.gold or theme.red, s.crit)
        set_hp(app, s.id, s.hp, s.hp_max)
        local a = app.last_attack
        if a and a.target == s.id then
            local nums = ""
            if a.roll and a.total and a.ac and not a.hidden then
                nums = " (" .. util.int(a.total) .. " vs AC " .. util.int(a.ac) .. ")"
            end
            M.push(app, name_of(app, a.id) .. (s.crit and " crits " or " hits ") .. name_of(app, s.id) .. nums .. " for "
                .. util.int(s.amount or 0) .. (a.dmg and a.dmg ~= "" and (" (" .. a.dmg .. ")") or "") .. (s.crit and "!" or "."),
                s.crit and "good" or "system")
            app.last_attack = nil
        else
            M.push(app, name_of(app, s.id) .. " takes " .. util.int(s.amount or 0) .. " damage.", "system")
        end
    elseif k == "heal" then
        M.float(app, s.id, "+" .. util.int(s.amount or 0), theme.green)
        spark(app, s.id, SPARK.heal)
        set_hp(app, s.id, s.hp, s.hp_max)
    elseif k == "down" then
        post("down", { id = s.id })
        M.float(app, s.id, "Down!", theme.orange, true)
        set_hp(app, s.id, 0)
        M.push(app, name_of(app, s.id) .. " goes down!", "bad")
    elseif k == "up" then
        post("up", { id = s.id })
        M.float(app, s.id, "Back up!", theme.green, true)
    elseif k == "death" then
        if app.hp[s.id] then
            post("down", { id = s.id })
        else
            post("die", { id = s.id })
            battle_hud.gone(app, s.id)
            M.push(app, name_of(app, s.id) .. " is out of the fight.", "good")
        end
    elseif k == "spell" then
        local col = SPARK[s.spell] or rgba(1.0, 0.8, 0.5)
        -- The caster's hands light up, then the spell lands: on a target, or across an area.
        spark(app, s.id, col)
        if s.area then
            battle_hud.area(app, s.area, col)
        else
            spark(app, s.target or s.id, col)
        end
        if s.name then
            M.float(app, s.id, s.name, theme.purple)
            M.push(app, name_of(app, s.id) .. " casts " .. s.name .. ((s.level or 0) > 0 and (" (level " .. util.int(s.level) .. ")") or "")
                .. (s.area and (", " .. util.int(#s.area) .. " squares") or "") .. ".", "system")
        end
    elseif k == "zone" then
        local col = SPARK[s.what] or rgba(0.9, 0.9, 0.9)
        battle_hud.area(app, s.cells, col, s.zone)
    elseif k == "zone_end" then
        battle_hud.zone_end(app, s.zone)
    elseif k == "feature" then
        if s.name then
            M.float(app, s.id, s.name, theme.teal)
            M.push(app, name_of(app, s.id) .. ": " .. s.name .. ".", "system")
        end
    elseif k == "condition" then
        if s.name then
            M.float(app, s.id, s.name, theme.purple)
        end
        battle_hud.condition(app, s.id, s.name, s.conds, true)
    elseif k == "condition_end" then
        battle_hud.condition(app, s.id, s.name, s.conds, false)
    elseif k == "save" then
        M.add_die(app, { roll = s.roll, success = s.ok, dm = s.dm, hidden = s.hidden })
        M.float(app, s.id, s.ok and "Saved" or "Failed save", s.ok and theme.teal or theme.orange)
        if is_party(app, s.id) and s.roll then
            panels.roll(app, s.id, { roll = s.roll, mod = (s.total or s.roll) - s.roll, total = s.total,
                                     against = s.dc and ("DC " .. util.int(s.dc)) or nil,
                                     what = (s.ab and string.upper(s.ab) or "") .. " save", success = s.ok })
        end
    elseif k == "death_save" then
        M.add_die(app, { roll = s.roll, success = (s.roll or 0) >= 10, crit = s.roll == 20, fumble = s.roll == 1 })
        M.float(app, s.id, "Death save: " .. util.int(s.roll or 0), (s.roll or 0) >= 10 and theme.teal or theme.red)
        if is_party(app, s.id) then
            panels.roll(app, s.id, { roll = s.roll, total = s.roll, against = "DC 10", what = "Death save",
                                     success = (s.roll or 0) >= 10, crit = s.roll == 20 })
        end
    elseif k == "stable" then
        M.float(app, s.id, "Stable", theme.teal)
    elseif k == "fortitude" then
        M.float(app, s.id, "Undead Fortitude", theme.purple)
    elseif k == "flee" then
        post("flee", { id = s.id })
        battle_hud.gone(app, s.id)
        M.push(app, name_of(app, s.id) .. " runs for it.", "system")
    elseif k == "join" then
        app.names[s.id] = s.name
        app.join_n = (app.join_n or 0) + 1
        local sprite = monster_sprite(s.monster, app.join_n)
        post("spawn", { list = { { id = s.id, sprite = sprite, x = s.x, y = s.y } } })
        battle_hud.join(app, s.id, s.name, sprite, s.hp, s.hp_max)
        app.hp[s.id] = nil
        M.push(app, (s.name or "Someone") .. " joins the fight!", "twist")
    end
end

-- Beats --------------------------------------------------------------------------------------

local function player(app, key)
    return app.campaign:player(key)
end

function M.handle(app, ev)
    local k = ev.kind
    ambience.night_event(app, ev)
    if k == "scene" then
        app.scene_label = "Scene " .. util.int(ev.index) .. " of " .. util.int(ev.total) .. ":  " .. ev.title
        local who = ev.cast and (" with " .. ev.cast) or ""
        app.scene_sub = (ev.type_name or "") .. who
        gui.set_text(app.n_label, kit.ellipsize(app.scene_label, "ui18b", 600))
        gui.set_text(app.n_sub, kit.ellipsize(app.scene_sub, "ui14", 360))
        app.progress = nil
        M.draw_pips(app)
        M.push(app, app.scene_label .. "  (" .. app.scene_sub .. ")", "scene")
        local sub = (ev.type_name or "") .. who
        if ev.goal then
            sub = sub .. "   Goal: " .. util.lower_first(ev.goal)
        end
        M.title(app, "SCENE " .. util.int(ev.index) .. " OF " .. util.int(ev.total) .. (ev.story and "   -   THIS WEEK'S STORY" or ""),
            ev.title, sub)
        stage(app, ev)
        cam(app, 2)
    elseif k == "stage" then
        stage(app, ev)
        if ev.title then
            M.title(app, "THE SCENE SHIFTS", ev.title, "")
        end
        cam(app, 2)
    elseif k == "narrate" then
        -- A DM-only aside goes to the log, never the big caption (A2).
        if ev.style ~= "aside" then
            M.caption(app, ev.text, ev.style)
        end
        M.push(app, ev.text, ev.style)
    elseif k == "clue" then
        -- The party learned something: it goes in the DM's notes.
        M.toast(app, "NEW IN YOUR NOTES", ev.text)
        M.push(app, "Noted: " .. ev.text, "clue")
    elseif k == "npc" then
        local anchor
        if app.on_table.npc then
            anchor = { mini = "npc" }
        elseif app.in_battle and app.boss_id then
            anchor = { mini = app.boss_id }
        end
        if anchor and anchor_xy(app, anchor) then
            M.bubble(app, anchor, ev.name, ev.text, true)
        else
            M.caption(app, ev.name .. ": \"" .. ev.text .. "\"", "quote")
        end
        M.push(app, ev.name .. ": \"" .. ev.text .. "\"", "quote")
        review.on_line(app, ev)
    elseif k == "say" then
        local p = player(app, ev.who)
        local speaker = p and (ev.ic and p.char or p.name) or "Someone"
        M.bubble(app, { head = ev.who }, speaker, ev.text, ev.ic)
        M.push(app, speaker .. ": \"" .. ev.text .. "\"", ev.ic and "quote" or "reaction")
        review.on_line(app, ev)
    elseif k == "react" then
        for who, pose in pairs(ev.poses or {}) do
            post("pose", { who = who, pose = pose, hold = true })
            panels.pose(app, who, pose)
        end
    elseif k == "check" then
        M.add_die(app, { roll = ev.roll, success = ev.success, crit = ev.crit, fumble = ev.fumble })
        if ev.progress then
            app.progress = ev.progress
            M.draw_pips(app)
        end
        -- The DM calls the check; the player rolls it (their panel's die tumbles and lands).
        local total = ev.total or (ev.roll + (ev.bonus or 0))
        M.caption(app, (ev.char or "") .. ", roll " .. (ev.skill_name or "it") .. ". DC " .. util.int(ev.dc or 0) .. ".", "check")
        M.push(app, ev.text, ev.crit and "good" or (ev.fumble and "bad" or "check"))
        post("pose", { who = ev.actor, pose = "think", hold = true })
        panels.pose(app, ev.actor, "think")
        panels.roll(app, ev.actor, { roll = ev.roll, mod = ev.bonus, total = total, against = "DC " .. util.int(ev.dc or 0),
                                     what = ev.skill_name, success = ev.success, crit = ev.crit, fumble = ev.fumble })
        if ev.spot then
            post("walk", { id = ev.actor, path = { ev.spot }, step = 0.3 / speed(app) })
        end
        local label = ev.crit and "Natural 20!" or (ev.fumble and "Natural 1" or (ev.success and "Success" or "Miss"))
        local color = ev.crit and theme.gold or (ev.success and theme.green or theme.red)
        schedule(app, 0.8, function()
            M.float(app, ev.actor, label .. "  " .. util.int(total), color, ev.crit or ev.fumble)
            if ev.crit then
                spark(app, ev.actor, SPARK.crit)
            end
        end)
        cam(app, (ev.crit or ev.fumble) and 3 or 2)
    elseif k == "battle" then
        if ev.phase == "start" then
            M.drop_title(app)     -- the scene's name has had its moment; the fight needs the space
            app.in_battle = true
            app.battle_cam = 2
            app.hp = {}
            app.join_n = 0
            for _, c in ipairs(ev.party or {}) do
                app.hp[c.id] = { c.hp, c.hp_max }
            end
            app.terrain = ev.terrain or app.terrain
            post("stage", { party = party_list(ev.party) })
            local list = {}
            app.boss_id = nil
            for i, f in ipairs(ev.foes or {}) do
                app.names[f.id] = f.name
                if f.boss then
                    app.boss_id = f.id
                end
                table.insert(list, { id = f.id, sprite = monster_sprite(f.monster, i), x = f.x, y = f.y, delay = 0.3 })
            end
            app.on_table = {}
            post("spawn", { list = list })
            battle_hud.start(app, ev.party, ev.foes, function(f, i)
                return monster_sprite(f.monster, i)
            end)
            local n = #(ev.foes or {})
            M.caption(app, "Roll for initiative!  " .. util.int(n) .. (n == 1 and " foe" or " foes")
                .. (ev.danger and ("  (" .. ev.danger .. ")") or ""), "warn")
            M.push(app, "A fight! " .. util.int(n) .. (n == 1 and " foe" or " foes") .. (ev.danger and (", " .. ev.danger) or "")
                .. (ev.srd and (". SRD says " .. ev.srd) or "") .. ".", "warn")
            M.refresh_hp(app)
            cam(app, 2)
        else
            app.in_battle = false
            battle_hud.stop(app)
            post("clear", { side = "foe", how = "flee" })
            for id in pairs(app.hp) do
                post("up", { id = id })
            end
            app.boss_id = nil
            M.refresh_hp(app)
            local won = ev.winner == "party"
            M.caption(app, won and "The fight is over. The party stands." or "The party falls back.", won and "good" or "bad")
            cam(app, 2)
        end
    elseif k == "round" then
        if (ev.round or 1) > 1 then
            M.push(app, "Round " .. util.int(ev.round), "system")
        end
        app.battle_cam = ((ev.round or 1) % 2 == 1) and 3 or 2
        cam(app, app.battle_cam)
    elseif k == "turn" then
        local t = 0.3
        local say = ev.say
        if ev.who then
            battle_hud.turn(app, ev.who)
        end
        local function speak()
            local p = player(app, say.who)
            local name = p and (say.ic and p.char or p.name) or "Someone"
            M.bubble(app, { head = say.who }, name, say.text, say.ic)
            M.push(app, name .. ": \"" .. say.text .. "\"", say.ic and "quote" or "reaction")
            review.on_line(app, say)
        end
        if say and say.at ~= "end" then
            -- What they're about to do, said as the turn starts.
            speak()
            t = t + 0.6
        end
        local pace = pacing.pace(ev)
        for _, s in ipairs(ev.steps or {}) do
            local step = s
            schedule(app, t, function()
                M.play_step(app, step, pace)
            end)
            t = t + pacing.step(s) * pace
        end
        if say and say.at == "end" then
            -- How it went, said once it's done.
            schedule(app, t, speak)
        end
    elseif k == "roll" then
        app.rolling = true
        app.roll_wait = 0
        app.roll_where = ev.where
        app.roll_ev = ev
        local p = ev.actor and player(app, ev.actor)
        if ev.by == "player" and p then
            -- The player throws the d20 themselves, in front of everyone.
            M.caption(app, p.name .. " rolls the d20 for " .. p.char .. "'s " .. (ev.skill_name or "check") .. "...", "dice")
            M.push(app, p.name .. " rolls " .. (ev.skill_name or "the check") .. ".", "dice")
            post("pose", { who = p.key, pose = "lean", hold = true })
            panels.pose(app, p.key, "lean")
        else
            M.caption(app, ev.where == "open" and "You roll the d20 where everyone can see it..." or "You roll the d20 behind your screen...", "dice")
            M.push(app, ev.where == "open" and "You roll in the open." or "You roll behind the screen.", "dice")
        end
        cam(app, 4)
        app.roll_dice()
    elseif k == "done" then
        app.night_done = true
        post("track", { on = false })
        M.clear_fx(app)
        cam(app, 1)
        M.show_done(app)
    elseif k == "decision" or k == "improv" or k == "ruling" or k == "roll_where" or k == "cook" then
        if k == "ruling" and ev.by ~= "dm" and ev.actor then
            panels.roll(app, ev.actor, { roll = ev.value, mod = ev.mod, total = ev.total, what = ev.skill_name,
                                         against = "DC " .. util.int(ev.dc or 0),
                                         success = ev.tier == "success" or ev.tier == "triumph",
                                         crit = ev.value == 20, fumble = ev.value == 1 })
        end
        app.pending = ev
        app.improv_sel = {}
        app.pending_left = app.timer_on and TIMERS[k] or nil
        M.clear_fx(app)
        if k == "decision" then
            cam(app, 1)
        elseif k == "improv" then
            cam(app, 2)
        else
            cam(app, 4)
        end
        M.show_modal(app, ev)
    end
end

function M.on_roll(app, value)
    if not app.rolling then
        return
    end
    app.rolling = false
    local ev = app.roll_ev
    app.roll_ev = nil
    if value then
        M.add_die(app, { roll = value, big = true, hidden = ev and ev.by == "dm" and ev.where == "hidden" })
        -- A player's own roll lands on their panel; whether it's enough depends on the DC.
        if ev and ev.by == "player" and ev.actor then
            panels.roll(app, ev.actor, { roll = value, mod = ev.mod, total = value + (ev.mod or 0), what = ev.skill_name,
                                         against = ev.where == "open" and ("DC " .. util.int(ev.dc or 0)) or "DC ?",
                                         success = ev.where == "open" and (value + (ev.mod or 0) >= (ev.dc or 0)) or nil,
                                         crit = value == 20, fumble = value == 1 })
        end
    end
    M.step(app, value)
end

function M.answer(app, value)
    local ev = app.pending
    if input_trace.on then
        input_trace.log("answer", tostring(ev and ev.kind) .. " " .. tostring(value))
    end
    app.pending = nil
    app.pending_left = nil
    M.close_modal(app)
    if ev and (ev.kind == "decision" or ev.kind == "ruling") then
        rest_cam(app)
    end
    M.step(app, value)
end

-- Number keys pick a card's options (the fix pass): 1 to 4 on any card, and on the improv hand
-- they pick cards (Enter plays them). A fallback that works even when a click doesn't.
function M.pick_key(app, n)
    local ev = app.pending
    if not ev then
        return false
    end
    if ev.kind == "decision" then
        if ev.card and ev.card.options[n] then
            M.answer(app, n)
            return true
        end
    elseif ev.kind == "ruling" then
        if ev.options and ev.options[n] then
            M.answer(app, n)
            return true
        end
    elseif ev.kind == "roll_where" then
        if n == 1 or n == 2 then
            M.answer(app, n == 1 and "open" or "hidden")
            return true
        end
    elseif ev.kind == "cook" then
        if n == 1 or n == 2 then
            M.answer(app, n == 2)
            return true
        end
    elseif ev.kind == "improv" then
        if ev.cards and ev.cards[n] then
            local b = M.find_button(app, "improv_card_" .. n)
            if b then
                b.on_click(b)
                return true
            end
        end
    end
    return false
end

-- Enter on the improv hand plays what's picked.
function M.play_improv(app)
    local ev = app.pending
    if ev and ev.kind == "improv" then
        local b = M.find_button(app, "improv_play")
        if b and b.enabled then
            b.on_click(b)
            return true
        end
    end
    return false
end

function M.find_button(app, key)
    local l = app.layers.modal
    for _, b in ipairs(l and l.buttons or {}) do
        if b.key == key then
            return b
        end
    end
    return nil
end

-- Cards ------------------------------------------------------------------------------------------

function M.close_modal(app)
    if app.layers.modal then
        kit.drop(app.layers.modal)
        app.layers.modal = nil
    end
    app.timer_bar = nil
    kit.reset_hover()
end

local function badge(x, y, label, color)
    local w = kit.width(label, "ui14") + 24
    kit.box(x, y, w, 26, color, { radius = 6 })
    kit.text(x + 12, y + 4, label, "ui14", theme.text)
end

-- Every card option shows its number key (1, 2, 3...) at its right edge (the fix pass).
local KEY_PAD = 34

local function option_height(label, w)
    return 20 + kit.text_height(label, "ui18b", w - 28 - KEY_PAD)
end

-- Cards slide in from their side of the screen.
local function slide_in(layer, dx)
    kit.rest_hits(layer)   -- a click while it slides lands where the button is going
    for _, n in ipairs(layer.nodes) do
        local p = gui.get_position(n)
        gui.set_position(n, vmath.vector3(p.x + dx, p.y, p.z))
        gui.animate(n, "position.x", p.x, gui.EASING_OUTCUBIC, 0.32)
    end
end

-- The gentle timer's bar along the bottom of a card.
local function timer_bar(app, x, y, w, what)
    if not app.pending_left then
        return 0
    end
    kit.box(x, y, w, 6, kit.rgba("#000000", 0.15), { round = false })
    local fill = kit.box(x, y, w, 6, theme.orange, { round = false })
    local label = kit.text(x, y + 10, "", "ui14", theme.ink_dim)
    app.timer_bar = { fill = fill, label = label, w = w, total = TIMERS[app.pending.kind] or 30, what = what }
    M.update_timer_bar(app)
    return 34
end

function M.update_timer_bar(app)
    local tb = app.timer_bar
    if not tb or not app.pending_left then
        return
    end
    local left = math.max(0, app.pending_left)
    if tb.improv then
        -- The improv hand only redraws on clicks; keep its countdown fresh.
        gui.set_text(tb.label, "Timer (T): " .. util.int(math.ceil(left)) .. "s, then your best card")
        return
    end
    kit.set_bar(tb.fill, tb.w, left, tb.total)
    gui.set_text(tb.label, "Timer (T): " .. util.int(math.ceil(left)) .. "s, then " .. tb.what)
end

local function card_y(h)
    return math.max(76, math.min(420 - h / 2, CARD_BOTTOM - h))
end

-- A card is coming up: slide the caption into the space beside it (between x0 and x1), or put it
-- away if it can't fit there or there's no space (no x0); it's in the log either way.
local function dodge_caption(app, x0, x1)
    local r, c = app.caption_rect, app.caption
    if not r or not c or c.life <= 0 or (x0 and (r.x + r.w <= x0 or r.x >= x1)) then
        return
    end
    if x0 and r.w <= x1 - x0 then
        r.x = (x0 + x1) / 2 - r.w / 2
        place(c.box, r.x, r.y)
        place(c.text, r.x + r.w / 2, r.y + 11)
    else
        c.life = 0
        app.caption_rect = nil
        gui.set_enabled(c.box, false)
        gui.set_enabled(c.text, false)
    end
end

function M.show_modal(app, ev, instant)
    M.close_modal(app)
    app.layers.modal = kit.layer("night_modal", true)
    if ev.kind == "decision" then
        dodge_caption(app, 16, RIGHT_X - 16)
    elseif ev.kind == "ruling" or ev.kind == "roll_where" or ev.kind == "cook" then
        dodge_caption(app, LEFT_X + LEFT_W + 16, kit.W - 16)
    elseif ev.kind == "improv" then
        dodge_caption(app, nil)
    end
    local slide = 0
    if ev.kind == "decision" then
        local x, w = RIGHT_X, RIGHT_W
        local card = ev.card
        local title_h = math.min(80, kit.text_height(card.title, "title30", w - 40))
        local text_h = kit.text_height(card.text, "ui18", w - 40)
        local labels, h = {}, 62 + title_h + 12 + text_h + 18
        local lean_h = {}
        for i, o in ipairs(card.options) do
            labels[i] = o.label .. (o.roll and ("  (" .. (o.skill or "d20") .. " check)") or "")
                .. (o.cooked and "  (overrules the die)" or "")
            lean_h[i] = (o.leans and next(o.leans)) and 30 or 0
            h = h + option_height(labels[i], w - 40) + lean_h[i] + 10
        end
        h = h + 10 + (app.pending_left and 34 or 0)
        local y = card_y(h)
        kit.box(x, y, w, h, theme.paper, { radius = 12 })
        badge(x + 20, y + 18, string.upper(card.type_name or "Call"), theme.decision[card.type] or theme.panel3)
        kit.text(x + 20, y + 52, card.title, "title30", theme.ink, { w = w - 40, lines = 2 })
        kit.text(x + 20, y + 62 + title_h, card.text, "ui18", theme.ink, { w = w - 40 })
        local oy = y + 62 + title_h + 12 + text_h + 8
        for i, label in ipairs(labels) do
            local oh = option_height(label, w - 40) + lean_h[i]
            kit.button(x + 20, oy, w - 40, oh, label, function()
                M.answer(app, i)
            end, { align = "left", color = card.options[i].cooked and theme.decision.screen or theme.button,
                   hover = theme.button_hover, key_hint = i })
            if lean_h[i] > 0 then
                M.draw_leans(app, x + 34, oy + oh - 32, card.options[i].leans)
            end
            oy = oy + oh + 10
        end
        timer_bar(app, x + 20, oy + 2, w - 40, "the first option")
        slide = 640
    elseif ev.kind == "improv" then
        M.draw_improv(app, ev)
        slide = 0
    elseif ev.kind == "ruling" then
        local x, w = LEFT_X, LEFT_W
        local prompt_h = kit.text_height(ev.prompt or "", "ui18", w - 40)
        local total = ev.total or ev.value or 0
        local shown
        if ev.by ~= "dm" then
            shown = (ev.char or "They") .. " rolled " .. util.int(ev.value or 0) .. " + " .. util.int(ev.mod or 0) .. " = "
                .. util.int(total) .. (ev.skill_name and (" " .. ev.skill_name) or "") .. " against DC " .. util.int(ev.dc or 0) .. "."
        else
            shown = (ev.where == "hidden" and "Behind the screen: " or "On the table: ") .. "the die says "
                .. util.int(ev.value or 0) .. " (" .. util.int(total) .. "), DC " .. util.int(ev.dc or 0) .. "."
        end
        local shown_h = kit.text_height(shown, "ui18b", w - 40)
        local labels, h = {}, 106 + shown_h + prompt_h + 34
        for i, o in ipairs(ev.options) do
            labels[i] = o.label
            h = h + option_height(o.label, w - 40) + 10
        end
        h = h + 10 + (app.pending_left and 34 or 0)
        local y = card_y(h)
        kit.box(x, y, w, h, theme.paper, { radius = 12 })
        badge(x + 20, y + 18, "RULING", theme.decision.rules)
        kit.text(x + 20, y + 52, TIER_TITLE[ev.tier] or "How does it land?", "title30", theme.ink, { w = w - 40 })
        kit.text(x + 20, y + 98, shown, "ui18b", theme.ink_dim, { w = w - 40 })
        kit.text(x + 20, y + 106 + shown_h, ev.prompt or "", "ui18", theme.ink, { w = w - 40 })
        local oy = y + 126 + shown_h + prompt_h
        for i, label in ipairs(labels) do
            local oh = option_height(label, w - 40)
            local tone = ev.options[i].tone
            kit.button(x + 20, oy, w - 40, oh, label, function()
                M.answer(app, i)
            end, { align = "left", color = theme.button, hover = theme.button_hover, key_hint = i })
            kit.box(x + 20, oy, 6, oh, tone == "good" and theme.green or (tone == "bad" and theme.red or theme.gold),
                { round = false })
            oy = oy + oh + 10
        end
        timer_bar(app, x + 20, oy + 2, w - 40, "the first option")
        slide = -640
    elseif ev.kind == "roll_where" then
        local x, w = LEFT_X, LEFT_W
        local text_h = kit.text_height(ev.text or "", "ui18", w - 40)
        local h = 110 + text_h + 136 + 10 + (app.pending_left and 34 or 0)
        local y = card_y(h)
        kit.box(x, y, w, h, theme.paper, { radius = 12 })
        local player_roll = ev.by ~= "dm"
        badge(x + 20, y + 18, player_roll and "BIG ROLL" or "SECRET CHECK", theme.decision.screen)
        kit.text(x + 20, y + 52, player_roll and "Set the DC" or "Where do you roll it?", "title30", theme.ink)
        kit.text(x + 20, y + 96, ev.text or "", "ui18", theme.ink, { w = w - 40 })
        local oy = y + 110 + text_h
        local open_label = player_roll and ("Say it out loud: DC " .. util.int(ev.dc or 0) .. "\nThey know what they need. The table trusts it.")
            or "Roll it in the open\nEveryone sees the die. The table trusts it."
        local hidden_label = player_roll and "Keep the DC behind your screen\nOnly you know it. You could move it..."
            or "Roll it behind your screen\nOnly you see it. You could misread it..."
        kit.button(x + 20, oy, w - 40, 58, open_label, function()
            M.answer(app, "open")
        end, { align = "left", pad_y = 8, color = theme.button, hover = theme.button_hover, key_hint = 1 })
        kit.button(x + 20, oy + 68, w - 40, 58, hidden_label, function()
            M.answer(app, "hidden")
        end, { align = "left", pad_y = 8, color = theme.decision.screen, hover = theme.button_hover, key_hint = 2 })
        timer_bar(app, x + 20, oy + 136, w - 40, "in the open")
        slide = -640
    elseif ev.kind == "cook" then
        local x, w = LEFT_X, LEFT_W
        local verdict = ev.success and "a success" or "a miss"
        local cooked = app.night and app.night.cooks or 0
        local total = ev.total or ev.value
        local player_roll = ev.by ~= "dm"
        local note
        if player_roll then
            note = (ev.char or "They") .. " rolled " .. util.int(ev.value) .. ", " .. (ev.mod and ((ev.mod >= 0 and "+" or "") .. util.int(ev.mod)) or "")
                .. ": " .. util.int(total) .. ". Your DC was " .. util.int(ev.dc) .. ", so that's " .. verdict
                .. ". Nobody else knows the DC."
        else
            note = "With " .. ((ev.mod or 0) >= 0 and "+" or "") .. util.int(ev.mod or 0) .. " that's " .. util.int(total)
                .. " against DC " .. util.int(ev.dc) .. ": " .. verdict .. ". Nobody else saw the die."
        end
        if cooked > 0 then
            note = note .. " You've cooked " .. util.int(cooked) .. (cooked == 1 and " roll" or " rolls") .. " tonight."
        end
        local text_h = kit.text_height(note, "ui18", w - 40)
        local h = 110 + text_h + 136 + 10 + (app.pending_left and 34 or 0)
        local y = card_y(h)
        kit.box(x, y, w, h, theme.paper, { radius = 12 })
        badge(x + 20, y + 18, "BEHIND THE SCREEN", theme.decision.screen)
        kit.text(x + 20, y + 52, player_roll and ((ev.char or "They") .. " got " .. util.int(total))
            or ("The die says " .. util.int(ev.value)), "title30", theme.ink)
        kit.text(x + 20, y + 96, note, "ui18", theme.ink, { w = w - 40 })
        local oy = y + 110 + text_h
        kit.button(x + 20, oy, w - 40, 58, "Keep it honest\nCall it " .. verdict .. ".", function()
            M.answer(app, false)
        end, { align = "left", pad_y = 8, color = theme.button, hover = theme.button_hover, key_hint = 1 })
        local cook_label = player_roll
            and ("Move the DC\nSay it was " .. (ev.success and "higher: a miss" or "lower: a success") .. ". Someone might wonder.")
            or ("Cook it\nCall it " .. (ev.success and "a miss" or "a success") .. ". Someone might notice.")
        kit.button(x + 20, oy + 68, w - 40, 58, cook_label, function()
            M.answer(app, true)
        end, { align = "left", pad_y = 8, color = theme.decision.screen, hover = theme.button_hover, key_hint = 2 })
        timer_bar(app, x + 20, oy + 136, w - 40, "keep it honest")
        slide = -640
    end
    M.trace_card(app, ev)   -- before the slide, so the trace has where the buttons come to rest
    if not instant and slide ~= 0 then
        slide_in(app.layers.modal, slide)
    end
end

-- For the real-click harness (tools/tests/ui_play/): which card is up and where its buttons are.
function M.trace_card(app, ev)
    if not input_trace.on then
        return
    end
    app.card_seq = (app.card_seq or 0) + 1
    input_trace.log("card", util.int(app.card_seq) .. " " .. tostring(ev.kind) .. " " .. input_trace.buttons())
end

-- Who at the table would enjoy an option (green) and who wouldn't (red): their faces, the DM's read.
function M.draw_leans(app, x, y, leans)
    local fx = x
    for _, group in ipairs({ { 1, theme.green, "would love it" }, { -1, theme.red, "wouldn't" } }) do
        local any = false
        for _, p in ipairs(app.campaign.players) do
            if leans[p.key] == group[1] then
                any = true
                kit.dot(fx + 12, y + 12, 26, group[2])
                kit.picture(fx + 1, y + 1, 22, 22, panels.face(p.key))
                fx = fx + 28
            end
        end
        if any then
            kit.text(fx + 4, y + 4, group[3], "ui14", group[2])
            fx = fx + kit.width(group[3], "ui14") + 22
        end
    end
end

-- The improv hand: pick one to three cards, then play them.
function M.draw_improv(app, ev)
    local sel = app.improv_sel or {}
    local n = #ev.cards
    local cw, ch, gap = 178, 196, 12
    local total = n * cw + (n - 1) * gap
    local px, pw = 800 - math.max(total, 640) / 2 - 20, math.max(total, 640) + 40
    local prompt_h = kit.text_height(ev.prompt or "", "ui18", pw - 40)
    local ph = 96 + prompt_h + 34
    local cards_y = 470
    local py = cards_y - 30 - ph
    kit.box(px, py, pw, ph, theme.paper, { radius = 12 })
    badge(px + 20, py + 18, ev.drift and "OFF SCRIPT" or "IMPROVISE", theme.orange)
    kit.text(px + 20, py + 50, ev.drift and "The party wandered off" or ("Empty slot: " .. (ev.slot or "")), "title30", theme.ink)
    kit.text(px + 20, py + 94, ev.prompt or "", "ui18", theme.ink, { w = pw - 40 })
    kit.text(px + 20, py + 100 + prompt_h, "Pick 1 to 3 cards. Your best card counts fully; one that doesn't fit always hurts.",
        "ui14", theme.ink_dim, { w = pw - 40 })
    local picked = {}
    local x0 = 800 - total / 2
    for i, c in ipairs(ev.cards) do
        local on = sel[i]
        if on then
            table.insert(picked, c)
        end
        local cx, cy = x0 + (i - 1) * (cw + gap), cards_y - (on and 18 or 0)
        kit.button(cx, cy, cw, ch, "", function()
            if sel[i] then
                sel[i] = nil
            else
                local count = 0
                for _ in pairs(sel) do
                    count = count + 1
                end
                if count < 3 then
                    sel[i] = true
                end
            end
            app.improv_sel = sel
            M.show_modal(app, ev, true)
        end, { color = on and theme.go or theme.button, hover = theme.button_hover, key = "improv_card_" .. i,
               key_hint = i <= 6 and i or nil, key_hint_bottom = true })
        if on then
            kit.box(cx, cy, cw, 5, theme.gold, { round = false })
        end
        kit.text(cx + 12, cy + 14, c.name, "ui18b", theme.text, { w = cw - 24, lines = 4 })
        if c.warn then
            local wt = c.warn .. " (Session Zero)"
            if kit.width(wt, "ui14") > cw - 24 then
                wt = c.warn
            end
            kit.text(cx + 12, cy + 120, wt, "ui14", theme.orange, { w = cw - 24, lines = 1 })
        elseif c.payoff then
            kit.text(cx + 12, cy + 120, "Pays off a seed", "ui14", theme.green, { w = cw - 24, lines = 1 })
        else
            kit.text(cx + 12, cy + 120, c.kind_name or "", "ui14", theme.dim)
        end
        local fit_label = (ev.drift and FIT_DRIFT or FIT_HAND)[c.fit]
        local fit_color = ({ great = theme.green, good = theme.gold, poor = theme.orange })[c.fit]
        kit.text(cx + 12, cy + 142, fit_label or "", "ui14", fit_color or theme.dim)
        kit.text(cx + 12, cy + ch - 26, on and "Picked" or "Click to pick", "ui14", on and theme.gold or theme.faint)
    end
    -- Play bar: the combined verdict and the button.
    local by = cards_y + ch + 14
    local bx = 800 - 300
    kit.box(bx, by, 600, 56, theme.bg_glass, { radius = 10 })
    local verdict = "Pick at least one card"
    local vcolor = theme.dim
    if #picked > 0 then
        local fit = night_mod.combo_fit(picked)
        verdict = FIT_TOGETHER[fit]
        vcolor = ({ great = theme.green, good = theme.gold, poor = theme.orange })[fit]
    end
    kit.text(bx + 16, by + 8, verdict, "ui18b", vcolor)
    local hint = app.pending_left and ("Timer (T): " .. util.int(math.ceil(math.max(0, app.pending_left))) .. "s, then your best card")
        or "Tip: two cards that fit beat three that don't."
    app.timer_bar = nil
    local hint_node = kit.text(bx + 16, by + 32, hint, "ui14", theme.faint)
    if app.pending_left then
        app.timer_bar = { label = hint_node, improv = true }
    end
    kit.button(bx + 600 - 196, by + 9, 180, 38, #picked > 1 and ("Play " .. util.int(#picked) .. " cards") or "Play it", function()
        local list = {}
        for i = 1, n do
            if sel[i] then
                table.insert(list, i)
            end
        end
        M.answer(app, list)
    end, { enabled = #picked > 0, color = theme.go, hover = theme.go_hover, key = "improv_play" })
    if #picked > 0 then
        kit.text(bx + 600 - 206, by + 28, "Enter", "ui14", theme.faint, { pivot = gui.PIVOT_E })
    end
end

function M.show_done(app)
    M.close_modal(app)
    app.layers.modal = kit.layer("night_done", false)
    local n = app.night
    local x, y, w, h = 800 - 230, 560, 460, 132
    kit.box(x, y, w, h, theme.paper, { radius = 12 })
    kit.text(x + w / 2, y + 18, "That's a wrap for tonight.", "ui18b", theme.ink, { pivot = gui.PIVOT_N })
    kit.text(x + w / 2, y + 44, clock_text(n and n.clock or 0) .. " at the table, " .. util.int(n and n:decision_count() or 0)
        .. " calls made", "ui14", theme.ink_dim, { pivot = gui.PIVOT_N })
    kit.button(x + 50, y + 76, w - 100, 40, "See how everyone felt  >", function()
        app.go("report")
    end, { color = theme.go, hover = theme.go_hover })
end

return M
