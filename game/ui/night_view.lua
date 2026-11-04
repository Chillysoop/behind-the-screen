-- Game night (M4): the table plays the night. Scenery drops onto the mat, paper
-- minis walk and fight, the players lean in or drift to their phones, and speech
-- bubbles pop over their heads. Captions carry the DM's narration; decision cards,
-- rulings and big rolls slide in when the DM is needed.
--
-- The model (game/model/night.lua) hands over one beat at a time with its playing
-- time; this view stages it (messages to main/table/table.script), times it, and
-- answers the beats that need the DM.
--
-- Keys: Space skip   F faster (1x/2x/4x)   G slower (down to 0.5x)   Tab log   H your rolls hidden/open
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
local thoughts = require "game.model.thoughts"
local recap_view = require "game.ui.recap_view"
local standing = require "game.model.standing"
local board_mod = require "game.model.board"
local util = require "game.model.util"
local content = require "game.model.content"
local review = require "game.ui.review_view"
local panels = require "game.ui.panels"
local gloss = require "game.ui.gloss"
local battle_hud = require "game.ui.battle_hud"
local input_trace = require "game.ui.input_trace"

local M = {}

local TABLE = "/table#table"
local H = 900
-- Half speed for a newcomer reading every line (the newcomer playtest, October 16: "the fight went
-- by too fast to follow"). The night starts at 1x (index 2).
local SPEEDS = { 0.5, 1, 2, 4 }
M.SPEED_1X = 2
-- The gentle timer (T): seconds before the safe default plays itself.
local TIMERS = { decision = 30, ruling = 25, roll_where = 15 }
local ROLL_PATIENCE = 9          -- seconds to wait for the physical die before rolling for it

local CHIP_Y, CHIP_W, CHIP_H = panels.Y, panels.W, panels.H
local RIGHT_X, RIGHT_W = 984, 592
local LEFT_X, LEFT_W = 24, 560
-- The DM's narration sits above a row kept free for the players' speech bubbles.
local CAPTION_BOTTOM, CAPTION_W = 664, 900
local CARD_BOTTOM = 760
-- Longer read-alouds: the recap and the session's opening.
-- The DM's read-aloud text (A9): the opening, the recap, a place or a person coming in. It gets
-- the boxed-passage look; the DM's own notes and the table's reactions stay plain captions, and
-- asides go to the log only.
-- A goal line is the DM's own aim ("Pip wants to know what's behind the door"), not something
-- you'd read to the table, so it stays a plain caption (playtest, October 13).
local READ_ALOUD = { recap = true, opening = true, narration = true, twist = true }
local LOG_X, LOG_Y, LOG_W, LOG_H = 24, 70, 520, 690
local STRIP_LABEL = "This scene's rolls  (? = behind your screen)"
local STRIP_RIGHT, STRIP_Y, DIE = 1440, 66, 30   -- (right of it: the small-moment crits toggle)

local CLASS_SPRITE = { fighter = "fighter", rogue = "rogue", cleric = "cleric", wizard = "wizard" }
local CAST_SPRITE = {
    -- v2: the museum's people, each with a mini of their own (tools/gen_sprites_museum.py).
    mus_flitwidget = "flitwidget", mus_telpur = "telpur", mus_euryale = "euryale", mus_lecturer = "the_lecturer",
    mus_mech = "steam_mech", mus_sentinel = "sentinel", mus_bone_construct = "bone_construct",
    mus_knight = "knight_of_shades", mus_huntlings = "kruthik_huntling", mus_briar = "briar_beast",
}
local MONSTER_SPRITES = {
    goblin_boss = true, bandit = true, bandit_captain = true, cultist = true, tough = true, wolf = true,
    dire_wolf = true, skeleton = true, zombie = true, ghoul = true, ogre = true,
    -- The Vale Bestiary (A13).
    pirate = true, merrow = true, giant_crab = true, guard = true, spy = true, swarm_of_rats = true, animated_armor = true,
    giant_spider = true, specter = true, brown_bear = true, gnoll_warrior = true, bugbear_warrior = true,
    warrior_veteran = true, kobold_warrior = true, scout = true, worg = true,
}
local BLOCKED = {
    sanctuary = "Sanctuary", decoy = "Hit the decoy", mirror_image = "Hit an image", shield = "Shield!",
    warding_flash = "Warding Flare", parry = "Parried", cover = "Cover!", no_line = "No line of sight",
}
local TIER_TITLE = { triumph = "A triumph!", success = "It works.", near = "So close...", flop = "That's a flop." }
-- A ruling's stripe: how kind the option is to the heroes.
local TONES = { good = { theme.green, "generous" }, twist = { theme.gold, "comes with a catch" }, bad = { theme.red, "harsh" },
                plain = { kit.rgba("#8a7c6a"), "plain" } }
local TONE_ORDER = { "good", "plain", "twist", "bad" }

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
    -- Hazards (A10).
    fire = rgba(1.0, 0.45, 0.15), dust = rgba(0.85, 0.75, 0.55), rubble = rgba(0.55, 0.5, 0.45), water = rgba(0.35, 0.6, 0.95),
    holes = rgba(0.15, 0.12, 0.1), ice = rgba(0.8, 0.95, 1.0),
    spiritual_weapon = rgba(1.0, 0.9, 0.6), mirror_image = rgba(0.8, 0.85, 1.0), inflict_wounds = rgba(0.6, 0.25, 0.45),
    acid_splash = rgba(0.6, 1.0, 0.4), ice_knife = rgba(0.6, 0.9, 1.0), prayer_of_healing = rgba(0.5, 1.0, 0.55),
}

local function post(id, data)
    msg.post(TABLE, id, data or {})
end

-- The board (main/board/board.script): the scenery the DM sets out piece by piece.
local BOARD = "/board#board"
local function post_board(id, data)
    msg.post(BOARD, id, data or {})
end

local function speed(app)
    return SPEEDS[app.speed_i or 2]
end

local function place(n, x, y)
    gui.set_position(n, vmath.vector3(x, H - y, 0))
end

local function alpha_of(c, a)
    return vmath.vector4(c.x, c.y, c.z, (c.w or 1) * a)
end

-- A name in the middle of a sentence: "the road's bandit chief", not "The road's bandit chief".
local function mid(name)
    if type(name) == "string" and string.match(name, "^The %l") then
        return "the" .. string.sub(name, 4)
    end
    return name
end

local function mid_names(list)
    local out = {}
    for i, n in ipairs(list or {}) do
        out[i] = i == 1 and n or mid(n)
    end
    return out
end

-- v2: the museum's monsters, each with a mini of its own (tools/gen_sprites_museum.py, and the briars'
-- in tools/gen_sprites_m4.py).
local MUSEUM_SPRITE = {
    briar_beast = "briar_beast", briar_boar = "briar_boar", briar_triceratops = "briar_triceratops", sentinel = "sentinel",
    bone_construct = "bone_construct", giant_scarab_swarm = "giant_scarab_swarm", knight_of_shades = "knight_of_shades",
    kruthik_huntling = "kruthik_huntling", the_lecturer = "the_lecturer", steam_mech = "steam_mech", euryale = "euryale",
    telpur = "telpur",
}

local function monster_sprite(id, n)
    if MUSEUM_SPRITE[id] then
        return MUSEUM_SPRITE[id]
    end
    if id == "goblin_warrior" then
        return (n % 2 == 0) and "goblin_club" or "goblin_spear"
    end
    return MONSTER_SPRITES[id] and id or "bandit"
end

-- What the museum's fight moments sound like at the table: text ({who}, {target}, {by}), the
-- float's colour, the log line's tone.
local MUSEUM_SAY = {
    veil = { "{who} pulls back her hood. Her hair is moving: snakes.", theme.purple, "twist" },
    petrify = { "{who}'s eyes catch the light. Everyone who looks at her starts to stiffen.", theme.purple, "warn" },
    petrifying = { "{who}'s legs go heavy and grey.", theme.orange, "bad" },
    petrified = { "{who} turns to stone.", theme.red, "bad" },
    freed = { "{who} cracks free of the stone.", theme.teal, "good" },
    mirror = { "{who} catches her own eyes in the polished door.", theme.gold, "good" },
    charmed = { "{who} smiles at {by} like an old friend. Charmed.", theme.purple, "bad" },
    scarabs = { "{who} bursts open, and scarabs pour across the floor.", theme.orange, "twist",
                -- (Said gently when the table veiled creepy-crawlies, or drew a line under them.)
                soft = { bugs = "{who} breaks apart, and something swarms out of it. You keep it vague." } },
    hyper = { "{who} vents steam and roars into Hyper Destroyer Mode!", theme.gold, "good" },
    overheat = { "{who} overheats, blasts steam everywhere and shuts down.", theme.orange, "warn" },
    power_down = { "{target} is down, and {who} powers down where it stands.", theme.orange, "bad" },
    lecture = { "{who} drones at {target}. It is very, very boring.", theme.purple, "system" },
    listening = { "{who} sits down on a bench to listen to the lecture.", theme.purple, "bad" },
    woken = { "{who} shakes {target} out of the lecture.", theme.teal, "good" },
    reckless = { "{who} swings without a thought for its guard.", theme.orange, "system" },
    sands = { "{who} hunkers down in the shifting sand.", theme.teal, "system" },
}

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
    app.keepsake_seen = nil
    -- A clean mat to start: tonight's first scene lays its place's map, if it has one.
    if app.pieces_key and app.pieces_key ~= "" then
        post("pieces", { cells = nil })
    end
    app.pieces_key = nil
    app.speed_i = app.speed_i or M.SPEED_1X
    if app.night then
        app.night.speed_hint = app.speed_i
        app.night.fast = (app.speed_i >= 4) or nil
    end
    app.log_open = false
    app.timer = 0.8
    app.beat_t = 0
    app.queue, app.qi = {}, 1
    app.hud = nil
    app.last_roll = {}
    app.chip_pose = {}
    app.clock_t = 0
    -- (Not the model's first line: the card-led playtest, October 16, read "Everyone's here. Dice
    -- out." three times at once, in the header, the log and the caption.)
    app.scene_label = "Before the first scene"
    app.scene_sub = ""
    app.keys_hidden = nil
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
    -- An empty chair for anyone who's out, or hasn't joined the table yet (October 15).
    local present = {}
    for _, key in ipairs(content.players.order) do
        local p = app.campaign:player(key)
        present[key] = (p and p.present) and true or false
    end
    post("seats", { present = present })
    post("clear", { how = "sweep" })
    post("track", { on = true })
    cam(app, 1)
    M.build(app)
end

function M.build(app)
    app.speed_now = function()
        return speed(app)
    end
    app.roll_landed = function(key, r)
        M.roll_banner(app, key, r)
    end
    -- The Inspire button on a tile: the token's on the table at once, the table's reaction next beat.
    app.give_inspiration = function(key)
        local p = app.night and app.campaign:player(key)
        if p and app.night:inspire_from_tile(p) then
            panels.set_token(app, key, true)
            M.float(app, key, "Heroic Inspiration!", theme.gold)
            post("spark", { id = key, color = SPARK.crit })
        end
    end
    app.layers.base = kit.layer("night_base")
    M.draw_frame(app)
    app.layers.log = kit.layer("night_log")
    M.draw_log(app)
    app.layers.fx = kit.layer("night_fx")
    app.bubbles, app.floaters = {}, {}
    app.side, app.toast_card, app.roll_card, app.tiny_card = nil, nil, nil, nil     -- (their nodes went with the old layers)
    app.dying_nodes = nil
    for id in pairs(app.ds or {}) do
        M.dying(app, id)        -- (a hero still down when the screen is rebuilt: their card again)
    end
    M.draw_caption(app)
    battle_hud.draw(app)
    M.draw_thinks(app)
    if app.pending then
        M.show_modal(app, app.pending, true)
    elseif app.night_done then
        M.show_done(app)
    end
    if app.thought_card then
        M.draw_thought_card(app)
    end
    recap_view.draw(app)
end

-- The frame: top bar, dice strip, player chips ------------------------------------------

local function status_text(app)
    local n = app.night
    -- The table clock (A14): what time it is at the table, and when you said you'd stop.
    local tc = (n and n.clock_text) and (n:clock_text() .. " (till " .. n:clock_text(n.table_planned) .. ")") or ""
    -- (No call count up here: the night's end card has it, October 20. Short, so the End session
    -- button fits beside it: November 3.)
    -- (The speed is its own buttons now, beside this: the playtest, November 3.)
    return tc .. "\n" .. (speed(app) < 1 and "Half speed   " or "")
        .. "Rolls: " .. ((n and n.dm_rolls) or "hidden") .. "   Timer: " .. (app.timer_on and "on" or "off")
end

-- How wide the scene's name may run in the top bar (v2: room for the Story button beside Notes).
function M.label_w(app)
    return standing.has(app.campaign) and 556 or 600
end

function M.draw_frame(app)
    kit.use(app.layers.base)
    kit.box(0, 0, kit.W, 58, theme.bg_glass, { round = false })
    kit.text(24, 6, "SESSION " .. util.int(app.campaign.week), "ui22b", theme.gold)
    kit.text(24, 35, "GAME NIGHT", "ui14", theme.faint)
    app.n_label = kit.text(160, 6, kit.ellipsize(app.scene_label, "ui18b", M.label_w(app)), "ui18b", theme.text)
    app.n_sub = kit.text(160, 32, kit.ellipsize(app.scene_sub or "", "ui14", 360), "ui14", theme.dim)
    -- Anything from an earlier build is gone with its layer.
    app.pip_nodes, app.strip_nodes = {}, {}
    -- Your notes (N): the museum, who's who, the party's sheets. One button: a second, "Stories (S)",
    -- opened the same notes on another tab (October 20).
    local recap = standing.has(app.campaign)
    kit.button(recap and 818 or 840, 10, recap and 104 or 112, 38, "Notes (N)", function()
        if app.open_notes then
            app.open_notes()
        end
    end, { font = "ui14", key = "night_notes" })
    -- The map repository: where the next scene plays out.
    kit.button(recap and 928 or 960, 10, recap and 76 or 90, 38, "Maps", function()
        if app.open_maps then
            app.open_maps()
        end
    end, { font = "ui14", key = "night_maps" })
    -- Ending the session is your call (the playtest, November 3): after the room you're in.
    -- Click again to change your mind.
    if app.night then
        local asked = app.night.dm_end_requested
        app.n_end = kit.button(1452, 10, 124, 38, asked and "Ending soon" or "End session", function()
            if app.night then
                app.night.dm_end_requested = not app.night.dm_end_requested or nil
                M.toast(app, app.night.dm_end_requested and "YOU'LL CALL IT THERE" or "PLAYING ON",
                    app.night.dm_end_requested and "The session ends when this room's done: they'll want to finish what they're in."
                        or "Never mind: the night goes on.")
                if app.n_end and app.n_end.label then
                    pcall(gui.set_text, app.n_end.label, app.night.dm_end_requested and "Ending soon" or "End session")
                    pcall(gui.set_color, app.n_end.node, app.night.dm_end_requested and theme.orange or app.n_end.color)
                end
            end
        end, { font = "ui14", key = "night_end", color = asked and theme.orange or nil })
        local gl = require "game.ui.gloss"
        gl.card_spot(1452, 10, 124, 38, "End session", "Call it a night when this room is done. Where you stop matters: "
            .. "a cliffhanger, or just after a big fight, and they go home happy; in a lull it falls flat. Stopping early so "
            .. "the big scene gets a full evening next week pays off then. Everything is saved where it stands.")
    end
    -- The DM's recap (game/ui/recap_view.lua): the Story sidebar top left, the Table top right.
    if recap then
        kit.button(728, 10, 84, 38, "Story", function()
            recap_view.toggle(app, "left")
        end, { font = "ui14", key = "night_story" })
        kit.button(1010, 10, 80, 38, "Table", function()
            recap_view.toggle(app, "right")
        end, { font = "ui14", key = "night_table" })
    end
    app.n_status = kit.text(1440, 4, status_text(app), "ui14", theme.text, { pivot = gui.PIVOT_NE, gloss = false })
    -- Pause and the night's speed, clickable (the playtest, November 3): Pause, 1x, 2x, 4x.
    M.draw_speed(app, 1100, 10)
    M.draw_crits(app)
    -- The keys: the first session's first scene only (the card-led playtest, October 16: one more
    -- line nobody read after the first scene; October 20: back at the start of every night). The
    -- hover card below keeps them. (No "1-4 camera": the night aims the camera itself, and a card's
    -- options show their own numbers.)
    app.n_keys = nil
    if not app.keys_hidden and app.campaign.week <= 1 then
        app.n_keys = kit.text(1576, 62, "Space skip  P pause  F/G speed  Tab log  H your rolls  T timer  C photo  S recap", "ui14",
            theme.faint, { pivot = gui.PIVOT_NE })
    end
    -- What the counters are (the newcomer playtest, October 16: "Your rolls: hidden").
    gloss.card_spot(1270, 4, 172, 44, "The evening at a glance",
        "The time at the table, and when you said you'd stop. Your rolls (H): whether you roll for the monsters behind your screen "
        .. "or in the open. Timer (T): a gentle countdown on each call. Tab opens the whole log, C takes a photo"
        .. ", S opens your recap: the story's sides and the table, side by side.")
    -- The player panels: faces, minis, how they're doing, their dice. Click one for the sheet.
    panels.draw(app, function(key)
        if app.open_sheet then
            app.open_sheet(key)
        end
    end)
    M.draw_strip(app)
    M.draw_pips(app)
end

-- How wide the scene's line under its name may run: all of its 360 unless the dots and the final
-- roll's word need the room (the valley map, October 17: a long goal pushed the word off the header).
local function sub_room(app)
    local pr = app.progress
    if not pr then
        return 360
    end
    local pips = pr.need * 14 + 10 + pr.max * 14 + 8
    return math.max(120, math.min(360, 760 - 176 - pips - kit.width("final roll: normal", "ui14")))
end
M.sub_room = sub_room

function M.refresh_status(app)
    if app.n_status then
        gui.set_text(app.n_status, status_text(app))
    end
    M.paint_speed(app)
end

function M.refresh_chips(app, scene_break)
    panels.refresh(app, scene_break)
end

function M.refresh_hp(app)
    panels.refresh_hp(app)
    battle_hud.refresh(app)
end

-- Dice strip: every d20 rolled this scene, newest on the right (it was the whole night, and by
-- the second scene it buried its own label: the card-led playtest, October 16). The DM's own
-- rolls show as a face-down "?" while they stay behind the screen.
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
    -- In a fight the turn order has the middle of the screen: fewer dice, so the two never meet
    -- (the newcomer playtest, October 16: the label ran under the turn order).
    local n = math.min(#app.strip, app.in_battle and 12 or 16)
    if n > 0 then
        -- What the strip is (A7).
        local left = STRIP_RIGHT - n * (DIE + 4)
        local label = STRIP_LABEL
        local lnode
        if app.in_battle and left - 8 - kit.width(label, "ui14") < 1060 then
            lnode = kit.text(STRIP_RIGHT - 4, STRIP_Y + DIE + 4, label, "ui14", theme.faint, { pivot = gui.PIVOT_NE })
        else
            lnode = kit.text(left - 8, STRIP_Y + DIE / 2, label, "ui14", theme.faint, { pivot = gui.PIVOT_E })
        end
        table.insert(app.strip_nodes, lnode)
        -- One spot, kept across redraws (a roll redraws the strip), over the dice and their label.
        local lx = app.in_battle and (STRIP_RIGHT - kit.width(STRIP_LABEL, "ui14") - 8)
            or (left - 8 - kit.width(STRIP_LABEL, "ui14"))
        local x0 = math.min(lx, left - 4)
        local rect = { x0, STRIP_Y - 4, STRIP_RIGHT + 4 - x0, DIE + 8 + (app.in_battle and 22 or 0) }
        local sp = app.strip_spot
        if sp and sp.layer == app.layers.base then
            sp.rect = rect
        else
            kit.unspot(sp)
            app.strip_spot = gloss.card_spot(rect[1], rect[2], rect[3], rect[4], "This scene's rolls",
                "Every d20 rolled this scene, newest on the right. Green worked, red didn't, gold is a natural 20 (or a "
                .. "big roll still being decided), purple is yours for the monsters. A grey ? was rolled behind your "
                .. "screen: only you saw it.")
        end
    end
    for k = 1, n do
        local d = app.strip[#app.strip - n + k]
        local x = STRIP_RIGHT - (n - k + 1) * (DIE + 4)
        local col, label, ink = theme.teal, util.int(d.roll or 0), theme.bg
        if d.hidden then
            col, label, ink = theme.panel3, "?", theme.dim
        elseif d.big and (d.roll == 20 or d.success == nil) then
            col = theme.gold      -- (a big roll goes green or red once it's decided: the re-test, a gold 2)
        elseif d.big then
            col = d.success and theme.teal or theme.red
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
    local room = sub_room(app)
    if app.n_sub then
        gui.set_text(app.n_sub, kit.ellipsize(app.scene_sub or "", "ui14", room))
    end
    local x = 160 + kit.width(kit.ellipsize(app.scene_sub or "", "ui14", room), "ui14") + 16
    local x0 = x
    for i = 1, pr.need do
        table.insert(app.pip_nodes, kit.dot(x + (i - 1) * 14 + 5, 41, 10, i <= pr.wins and theme.gold or kit.rgba("#ffffff", 0.18)))
    end
    x = x + pr.need * 14 + 10
    for i = 1, pr.max do
        table.insert(app.pip_nodes, kit.dot(x + (i - 1) * 14 + 5, 41, 10, i <= pr.setbacks and theme.red or kit.rgba("#ffffff", 0.1)))
    end
    -- What the dots are (the newcomer playtest, October 16).
    app.pips_label_w = 0
    if #app.pip_nodes == 0 then
        return
    end
    -- Where the scene's last roll stands right now (the newcomer playtest, October 16: the dots
    -- said nothing about what they were doing to it until the scene's end).
    local lx = x + pr.max * 14 + 8
    local word, col, short
    local edge = (pr.wins >= pr.need) and -2 or ((pr.setbacks >= pr.max) and 2 or 0)
    if edge < 0 then
        word, short, col = "final roll: easier (DC " .. util.int(edge) .. ")", "final roll: easier", theme.green
    elseif edge > 0 then
        word, short, col = "final roll: harder (DC +" .. util.int(edge) .. ")", "final roll: harder", theme.red
    else
        word, short, col = "final roll: normal", "final roll: normal", theme.dim
    end
    if lx + kit.width(word, "ui14") > 760 then
        word = short
    end
    local lw = kit.width(word, "ui14")
    if lx + lw <= 760 then
        table.insert(app.pip_nodes, kit.text(lx, 32, word, "ui14", col))
        app.pips_label_w = 8 + lw
    end
    gloss.card_spot(x0 - 2, 32, x + pr.max * 14 - x0 + 4 + app.pips_label_w, 18, "How the scene is going",
        "Gold dots: good moments. Fill every gold dot and the scene's final roll gets easier (DC -2). Red dots: "
        .. "setbacks. Fill every red one first and it gets harder (DC +2). Someone in the scene telling them where "
        .. "to look makes it 2 easier again. The words beside the dots say where it stands right now.", nil, app.pip_nodes[1])
end

-- The log: compact (last few lines) or open (Tab) -------------------------------------------

function M.draw_log(app)
    kit.gloss_scope({ fight = true, table = true }, function()
        M.draw_log_now(app)
    end)
end

function M.draw_log_now(app)
    local l = app.layers.log
    if not l then
        return
    end
    kit.release_spots(l)
    for _, n in ipairs(l.nodes) do
        kit.under_of[n] = nil    -- (its underlines are on this list too)
    end
    for _, n in ipairs(l.nodes) do
        gui.delete_node(n)
    end
    l.nodes, l.buttons, l.spots, l.gloss_seen = {}, {}, {}, nil
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
        -- Only what nothing else on screen said: a line that was a caption, a speech bubble, a card
        -- or a note is in the open log (Tab), not here (the card-led playtest, October 16: the log
        -- repeated every caption word for word, at the same moment).
        local lines = {}
        local age = 0
        -- (Forty lines back is another moment: an aside from the last scene isn't news now.)
        for i = #app.log, math.max(1, #app.log - 40), -1 do
            local e = app.log[i]
            if not e.shown then
                local wrapped = kit.wrap(e.text, "ui14", 446)
                if #lines + #wrapped > 5 and #lines > 0 then
                    break
                end
                for k = #wrapped, 1, -1 do
                    table.insert(lines, 1, { text = wrapped[k], style = e.style, age = age })
                end
                age = age + 1
                if #lines >= 5 then
                    break
                end
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

function M.push(app, text, style, shown)
    -- The log keeps the whole night (the fix pass); scrolled back, the view stays put. shown: the
    -- line is on screen already (a caption, a bubble, a card), so only the open log has it.
    table.insert(app.log, { text = text, style = style, shown = shown or nil })
    if (app.log_scroll or 0) > 0 then
        app.log_scroll = app.log_scroll + 1
    end
    M.draw_log(app)
end

-- Showing a snapshot from the report (B7): the table sets the moment back up as it was, terrain,
-- minis and all. nil clears the table again.
function M.restage_snapshot(app, sn)
    app.replay = nil
    app.replay_last = nil
    if not sn then
        post("vignette")
        app.terrain = nil
        app.zoom(1)
        return
    end
    -- (Just the moment's own minis: the old campfire vignette under them read as duplicates, November 3.)
    post("clear_minis")
    if sn.terrain then
        app.terrain = sn.terrain
        post("terrain", { set = sn.terrain, animate = false, def = board_mod.encode(sn.terrain) })
        if sn.wake and #sn.wake > 0 then
            post("lift", { cells = sn.wake })      -- (the garden's hedges were already up)
        end
    end
    local list, n = {}, 0
    for _, m in ipairs(sn.minis or {}) do
        local sprite
        if m.side == "party" then
            local pl = app.campaign:player(m.id)
            sprite = (pl and pl.mini) or CLASS_SPRITE[m.class] or "fighter"
        elseif m.side == "npc" then
            sprite = CAST_SPRITE[m.cast] or "npc_stranger"
        else
            n = n + 1
            sprite = monster_sprite(m.monster, n)
        end
        table.insert(list, { id = "snap_" .. tostring(m.id), sprite = sprite, x = m.x, y = m.y,
                             side = m.side == "party" and "party" or "foe" })
    end
    -- A fight: play it back from its first turn to the moment, quickly (M.update_replay).
    if sn.frames and #sn.frames > 1 then
        local function parse(fr)
            local out = {}
            for part in string.gmatch(fr, "[^;]+") do
                local id, x, y, d, hp = string.match(part, "^([^:]+):(%d+):(%d+):(%d):?(%d*)$")
                if id then
                    out[id] = { x = tonumber(x), y = tonumber(y), down = d == "1", hp = tonumber(hp) }
                end
            end
            return out
        end
        local frames = {}
        for _, fr in ipairs(sn.frames) do
            table.insert(frames, parse(fr))
        end
        local first, n2 = {}, 0
        for id, at in pairs(frames[1]) do
            local k = (sn.kinds or {})[id] or {}
            local sprite
            if k.side == "party" then
                local pl = app.campaign:player(id)
                sprite = (pl and pl.mini) or CLASS_SPRITE[k.class] or "fighter"
            else
                n2 = n2 + 1
                sprite = monster_sprite(k.monster, n2)
            end
            table.insert(first, { id = "snap_" .. id, sprite = sprite, x = at.x, y = at.y, side = k.side or "foe" })
        end
        post("spawn", { list = first })
        app.replay = { frames = frames, i = 1, t = -0.8, step = 0.55, kinds = sn.kinds or {}, acts = sn.acts or {} }
        app.replay_last = app.replay
        app.zoom(sn.camera or 2)
        return
    end
    post("spawn", { list = list })
    for _, m in ipairs(sn.minis or {}) do
        if m.down then
            post("down", { id = "snap_" .. tostring(m.id) })
        end
    end
    app.zoom(sn.camera or 2)
end

-- Every frame on the report while a fight plays back: each turn's moves, a beat apart.
function M.update_replay(app, dt)
    local r = app.replay
    if not r then
        return
    end
    r.t = r.t + dt
    while r.t >= r.step and r.i < #r.frames do
        r.t = r.t - r.step
        local was, now = r.frames[r.i], r.frames[r.i + 1]
        for id, at in pairs(now) do
            local before = was[id]
            if not before then
                local k = r.kinds[id] or {}
                local pl = k.side == "party" and app.campaign:player(id)
                local sprite = (k.side == "party" and ((pl and pl.mini) or CLASS_SPRITE[k.class] or "fighter")) or monster_sprite(k.monster, 1)
                post("spawn", { list = { { id = "snap_" .. id, sprite = sprite, x = at.x, y = at.y, side = k.side or "foe" } } })
            elseif before.x ~= at.x or before.y ~= at.y then
                post("walk", { id = "snap_" .. id, path = { { at.x, at.y } }, step = r.step * 0.8 })
            end
            if at.down and not (before and before.down) then
                post("down", { id = "snap_" .. id })
            elseif before and before.down and not at.down then
                post("up", { id = "snap_" .. id })
            end
        end
        for id in pairs(was) do
            if not now[id] then
                post("flee", { id = "snap_" .. id })
            end
        end
        r.i = r.i + 1
        -- What they did this turn, like the real fight (the playtest, November 3): the swing, the
        -- spell's spark, the hit, and the numbers in the ticker; the bars follow.
        local said = {}
        for _, a in ipairs(r.acts[r.i] or {}) do
            local an = a.a and (r.kinds[a.a] and r.kinds[a.a].name) or nil
            local tn = a.t and (r.kinds[a.t] and r.kinds[a.t].name) or nil
            if a.k == "a" and a.a and a.t then
                post("lunge", { id = "snap_" .. a.a, target = "snap_" .. a.t, ranged = a.ranged, time = 0.3 })
                table.insert(said, (an or "Someone") .. (a.hit and (a.crit and " crits " or " hits ") or " misses ") .. (tn or "someone")
                    .. (a.w and (" (" .. a.w .. ")") or ""))
            elseif a.k == "s" and a.a then
                post("spark", { id = "snap_" .. (a.t or a.a), color = SPARK.crit })
                table.insert(said, (an or "Someone") .. " casts " .. (a.w or "a spell") .. (tn and (" on " .. tn) or ""))
            elseif a.k == "d" and a.t then
                post("hit", { id = "snap_" .. a.t })
                table.insert(said, util.int(a.n or 0) .. " damage to " .. (tn or "someone") .. (a.crit and "!" or ""))
            elseif a.k == "h" and a.t then
                post("spark", { id = "snap_" .. a.t, color = theme.green })
                table.insert(said, (tn or "Someone") .. " heals " .. util.int(a.n or 0))
            end
        end
        r.ticker = #said > 0 and table.concat(said, ".  ") .. "." or r.ticker
        M.paint_replay(app)
    end
    if r.i >= #r.frames then
        app.replay = nil
    end
end

-- The replay's panel (report_view's Look): everyone in the fight with their hit points, and what
-- just happened. Drawn into the current layer; M.paint_replay keeps it up to date.
function M.draw_replay_hud(app, sn)
    app.replay_hud = nil
    local r = app.replay_last
    if not (sn and sn.frames and #sn.frames > 1 and r) then
        return
    end
    local ids = {}
    for id, k in pairs(r.kinds) do
        table.insert(ids, { id = id, k = k })
    end
    table.sort(ids, function(a, b)
        if (a.k.side == "party") ~= (b.k.side == "party") then
            return a.k.side == "party"
        end
        return a.id < b.id
    end)
    local x, y, w = 1196, 76, 388
    local n = math.min(#ids, 10)
    kit.box(x, y, w, 44 + n * 34, kit.rgba("#140e0b", 0.88), { radius = 12 })
    kit.text(x + 16, y + 12, "THE FIGHT, PLAYED BACK", "ui14", theme.gold, { gloss = false })
    local hud = { rows = {}, w = 170 }
    hud.turn = kit.text(x + w - 16, y + 12, "", "ui14", theme.dim, { pivot = gui.PIVOT_NE, gloss = false })
    for i = 1, n do
        local e = ids[i]
        local ry = y + 40 + (i - 1) * 34
        local col = e.k.side == "party" and theme.green or theme.red
        kit.text(x + 16, ry + 4, kit.ellipsize(e.k.name or e.id, "ui14", 150), "ui14", theme.text, { gloss = false })
        local fill = kit.bar(x + 172, ry + 9, hud.w, 9, e.k.hp_max or 1, math.max(1, e.k.hp_max or 1), col)
        local t = kit.text(x + w - 16, ry + 4, "", "ui14", theme.dim, { pivot = gui.PIVOT_NE, gloss = false })
        hud.rows[e.id] = { fill = fill, text = t, max = math.max(1, e.k.hp_max or 1) }
    end
    kit.box(300, 744, 1000, 56, kit.rgba("#140e0b", 0.88), { radius = 12 })
    hud.ticker = kit.text(800, 760, "", "ui18b", theme.text, { pivot = gui.PIVOT_N, w = 960, lines = 1, gloss = false })
    app.replay_hud = hud
    M.paint_replay(app)
end

function M.paint_replay(app)
    local hud, r = app.replay_hud, app.replay_last
    if not (hud and r) then
        return
    end
    local fr = r.frames[r.i] or {}
    for id, row in pairs(hud.rows) do
        local at = fr[id]
        local hp = at and at.hp
        if hp then
            pcall(kit.set_bar, row.fill, hud.w, hp, row.max)
            pcall(gui.set_text, row.text, at.down and (hp > 0 and (util.int(hp) .. " HP, down") or "Down") or (util.int(hp) .. " / " .. util.int(row.max)))
        elseif not at then
            pcall(gui.set_text, row.text, "Gone")
        end
    end
    pcall(gui.set_text, hud.turn, "Turn " .. util.int(r.i) .. " of " .. util.int(#r.frames))
    pcall(gui.set_text, hud.ticker, kit.ellipsize(r.ticker or "", "ui18b", 960))
end

-- The DM's camera (B1): three snapshots a night of whatever's on the table right now.
function M.take_snapshot(app)
    local night = app.night
    if not night or app.night_done then
        return
    end
    local snap, why = night:snapshot("You caught this one.", 6, nil, true)
    if not snap then
        M.push(app, why or "No more snapshots tonight.", "system")
        return
    end
    local left = night.SNAP_DM - (night.snaps_dm or 0)
    M.push(app, "Snapshot taken. " .. util.int(left) .. (left == 1 and " left tonight." or " left tonight."), "system")
    -- A camera flash.
    kit.use(app.layers.fx)
    local flash = kit.box(0, 0, kit.W, kit.H, kit.rgba("#ffffff", 0.7), { round = false })
    app.flash = { node = flash, t = 0 }
end

function M.toggle_log(app)
    app.log_open = not app.log_open
    app.log_scroll = 0
    M.draw_log(app)
    -- A card that's up moves aside (or back) at once.
    if app.pending and app.layers.modal then
        M.show_modal(app, app.pending, true)
    end
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
    -- A read-aloud passage (A9) is a boxed passage of its own: parchment, a gold rule down its
    -- left side, a small "Read aloud" tag, and the text large and set left.
    c.rule = kit.box(0, 0, 6, 40, theme.gold, { round = false })
    c.tag = kit.text(0, 0, "READ ALOUD TO THE PLAYERS: SETTING THE SCENE      Space: next", "ui14", theme.ink_dim, { gloss = false })   -- (the second playtest: "is it waiting for me?")
    c.text = kit.text(0, 0, "", "story22", theme.text, { pivot = gui.PIVOT_N, gloss = false })
    -- Whose voice it is (the playtest, November 3: "more clear what the DM says to the players vs.
    -- what is context setting"): a small tab on the caption's top edge.
    c.voice_bg = kit.box(0, 0, 100, 22, theme.panel3, { radius = 8 })
    c.voice = kit.text(0, 0, "", "ui14", theme.bg, { pivot = gui.PIVOT_N, gloss = false })
    c.life, c.age, c.color = 0, 0, theme.text
    for _, n in ipairs({ c.box, c.rule, c.tag, c.text, c.voice_bg, c.voice }) do
        gui.set_enabled(n, false)
    end
    app.caption = c
    app.title_card = nil
end

-- Lay the caption's nodes out in its rect (the read-aloud box or the plain caption).
-- The caption's voice, by its style: you talking to the table out of character, you narrating
-- what happens, or a note that's only for you.
local VOICE = {
    dm = { "YOU, TO THE TABLE", "#7fb2e5" },
    good = { "YOU, NARRATING", "#cdbb98" }, bad = { "YOU, NARRATING", "#cdbb98" }, twist = { "YOU, NARRATING", "#cdbb98" },
    thread = { "YOU, NARRATING", "#cdbb98" }, interlude = { "YOU, NARRATING", "#cdbb98" }, goal = { "FOR YOU", "#8a7c6a" },
    system = { "FOR YOU", "#8a7c6a" }, warn = { "FOR YOU", "#8a7c6a" }, quote = { "YOU, IN CHARACTER", "#e8b84a" },
    table = { "AT THE TABLE", "#9fbf8f" },          -- (table life: what the heroes get up to between the big moments)
}
M.VOICE = VOICE

local function place_caption(c, x, y, w, h)
    place(c.box, x, y)
    if c.voice_on then
        local vw = kit.width(gui.get_text(c.voice), "ui14") + 18
        gui.set_size(c.voice_bg, vmath.vector3(vw, 22, 0))
        place(c.voice_bg, x + 16, y - 16)
        place(c.voice, x + 16 + vw / 2, y - 14)
    end
    if c.read then
        place(c.rule, x + 14, y + 14)
        gui.set_size(c.rule, vmath.vector3(4, h - 28, 0))
        place(c.tag, x + 30, y + 10)
        place(c.text, x + 30, y + 32)
    else
        place(c.text, x + w / 2, y + 11)
    end
end

local function caption_box_color(c, a)
    return c.read and alpha_of(theme.paper, 0.97 * a) or kit.rgba("#140e0b", 0.82 * a)
end

function M.caption(app, text, style)
    local c = app.caption
    if not c then
        return
    end
    local read = READ_ALOUD[style] and true or false
    local font = read and "read26" or ((style == "dice" or style == "check" or style == "system" or style == "warn") and "ui22b" or "story22")
    local width = read and 1000 or CAPTION_W
    local max_lines = read and 5 or 5
    local pad = read and 58 or 48
    local lines = kit.wrap(text, font, width - pad)
    if #lines > max_lines then
        local keep = {}
        for i = 1, max_lines do
            keep[i] = lines[i]
        end
        keep[max_lines] = kit.ellipsize(keep[max_lines] .. " ...", font, width - pad)
        lines = keep
    end
    local tw = 0
    for _, l in ipairs(lines) do
        tw = math.max(tw, kit.width(l, font))
    end
    local w = tw + pad
    local h = #lines * kit.line_height(font) + (read and 46 or 22)
    if read then
        w = math.max(w, 360)
    end
    local y = CAPTION_BOTTOM - h
    -- With the log open, the caption centers on the rest of the screen.
    local cx = app.log_open and math.max(LOG_X + LOG_W + 16 + w / 2, 800) or 800
    c.read = read
    gui.set_size(c.box, vmath.vector3(w, h, 0))
    gui.set_font(c.text, font)
    gui.set_pivot(c.text, read and gui.PIVOT_NW or gui.PIVOT_N)
    gui.set_text(c.text, table.concat(lines, "\n"))
    place_caption(c, cx - w / 2, y, w, h)
    app.caption_rect = { x = cx - w / 2, y = y, w = w, h = h }
    c.color = read and theme.ink or (theme.log[style] or theme.text)
    -- Its game words explain themselves on hover, like the log's (the hover audit, November 3).
    if c.gloss_nodes then
        kit.remove(c.gloss_nodes)
    end
    for _, sp in ipairs(c.gloss_spots or {}) do
        kit.unspot(sp)
    end
    c.gloss_nodes, c.gloss_spots = {}, {}
    if kit.gloss_hook then
        kit.use(app.layers.fx)
        local l = kit.current
        local n0, s0 = #l.nodes, #(l.spots or {})
        local tx, ty = (read and (cx - w / 2 + 30)) or cx, (read and (y + 32)) or (y + 11)
        pcall(kit.gloss_hook, tx, ty, table.concat(lines, "\n"), font, c.color, read and gui.PIVOT_NW or gui.PIVOT_N,
            kit.gloss_default)
        for i = n0 + 1, #l.nodes do
            table.insert(c.gloss_nodes, l.nodes[i])
        end
        for i = s0 + 1, #(l.spots or {}) do
            table.insert(c.gloss_spots, l.spots[i])
        end
    end
    c.age = 0
    -- Read-aloud passages stay up a little longer: they're read out, not glanced at.
    c.life = (pacing.read(text) * (read and 1.25 or 1) + 0.6) / speed(app)
    c.style = style
    gui.set_enabled(c.box, true)
    gui.set_enabled(c.text, true)
    gui.set_enabled(c.rule, read)
    gui.set_enabled(c.tag, read)
    local v = (not read) and VOICE[style]
    c.voice_on = v and true or false
    gui.set_enabled(c.voice_bg, c.voice_on)
    gui.set_enabled(c.voice, c.voice_on)
    if v then
        gui.set_text(c.voice, v[1])
        c.voice_color = kit.rgba(v[2])
        gui.set_color(c.voice_bg, c.voice_color)
        gui.set_color(c.voice, theme.bg)
        place_caption(c, app.caption_rect.x, app.caption_rect.y, app.caption_rect.w, app.caption_rect.h)
    end
    gui.set_color(c.text, c.color)
    gui.set_color(c.box, caption_box_color(c, 1))
    gui.set_color(c.tag, theme.ink_dim)
    gui.set_color(c.rule, theme.gold)
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
    -- With the log open, it sits on the rest of the screen (A11).
    local cx = app.log_open and math.max(LOG_X + LOG_W + 16 + w / 2, 800) or 800
    local x, y = cx - w / 2, 136
    local t = { age = 0, life = (3.2 + #text / 30) / math.sqrt(speed(app)), nodes = {} }
    t.nodes[1] = kit.box(x - 2, y - 2, w + 4, h + 4, theme.gold, { radius = 12 })
    t.nodes[2] = kit.box(x, y, w, h, kit.rgba("#201813", 0.96), { radius = 11 })
    t.nodes[3] = kit.text(x + 20, y + 12, top, "ui14", theme.gold)
    t.nodes[4] = kit.text(x + 20, y + 34, table.concat(lines, "\n"), "ui18", theme.text)
    t.nodes[5] = kit.text(x + w - 18, y + 12, "N: open your notes", "ui14", theme.faint, { pivot = gui.PIVOT_NE })
    t.colors = { theme.gold, kit.rgba("#201813", 0.96), theme.gold, theme.text, theme.faint }
    app.toast_card = t
end

-- Down at 0 Hit Points: a red card over their tile, their death saves as they're rolled (three
-- successes and they're stable, three failures and they die). Redrawn on every save.
function M.dying(app, id)
    local chip = app.chips and app.chips[id]
    local t = app.ds and app.ds[id]
    if not (chip and t and app.layers and app.layers.fx) then
        return
    end
    M.drop_dying(app, id, true)
    kit.use(app.layers.fx)
    local w, h = 300, 64
    local x, y = chip.x + (panels.W - w) / 2, chip.y - 84 - h - 8
    local col = t.stable and theme.teal or theme.red
    local nodes = {}
    local function add(n)
        table.insert(nodes, n)
    end
    add(kit.box(x - 2, y - 2, w + 4, h + 4, col, { radius = 12 }))
    add(kit.box(x, y, w, h, kit.rgba("#201813", 0.97), { radius = 11 }))
    local p = app.campaign:player(id)
    local who = (p and p.char) or (app.names and app.names[id]) or "They"
    add(kit.text(x + 14, y + 8, t.stable and (who .. " is stable") or (who .. " is dying"), "ui18b", col, { gloss = false }))
    add(kit.text(x + 14, y + 36, "Saves", "ui14", theme.dim, { gloss = false }))
    for i = 1, 3 do
        add(kit.dot(x + 70 + (i - 1) * 20, y + 44, 14, i <= t.s and theme.teal or kit.rgba("#ffffff", 0.15)))
    end
    add(kit.text(x + 150, y + 36, "Fails", "ui14", theme.dim, { gloss = false }))
    for i = 1, 3 do
        add(kit.dot(x + 200 + (i - 1) * 20, y + 44, 14, i <= t.f and theme.red or kit.rgba("#ffffff", 0.15)))
    end
    app.dying_nodes = app.dying_nodes or {}
    app.dying_nodes[id] = nodes
end

function M.drop_dying(app, id, keep)
    local nodes = app.dying_nodes and app.dying_nodes[id]
    if nodes then
        kit.remove(nodes)
        app.dying_nodes[id] = nil
    end
    if not keep and app.ds then
        app.ds[id] = nil
    end
end

-- Clicking a person's mini on the mat opens their sheet (npc_view): the scene's person, or a foe
-- who is one of the adventure's people (by their stat block). lx, ly: layout coordinates.
function M.click_mini(app, lx, ly)
    local an = app.anchors and app.anchors.minis
    if not an or not app.mini_npc then
        return false
    end
    for id, npc in pairs(app.mini_npc) do
        local a = an[id]
        if a and a[1] and a[2] then
            local ax, ay = a[1] * kit.W, a[2] * kit.H
            if math.abs(lx - ax) <= 30 and ly >= ay - 10 and ly <= ay + 90 then
                local gloss = require "game.ui.gloss"
                if gloss.on_npc then
                    gloss.on_npc(npc)
                    return true
                end
            end
        end
    end
    return false
end

-- Which minis are the adventure's people: the scene's person by their card, a foe by its stat block.
local function npc_for_monster(monster)
    local ok, npcs = pcall(require, "game.model.npcs")
    if not ok then
        return nil
    end
    for _, n in ipairs(npcs.all()) do
        if n.monster and n.monster == monster then
            return n.id
        end
    end
    return nil
end

-- A roll's numbers, big enough to read across the table (the playtest, November 3: "13 + 5 = 18,
-- with 18 big and highlighted"): over the roller's tile as their die lands, then gone.
function M.roll_banner(app, key, r)
    M.drop_roll_banner(app)
    local chip = app.chips and app.chips[key]
    if not (chip and app.layers and app.layers.fx and r.total) then
        return
    end
    kit.use(app.layers.fx)
    local col = r.crit and theme.gold or (r.success == true and theme.green) or (r.success == false and theme.red) or theme.teal
    local word = (r.crit and "Natural 20!") or (r.fumble and "Natural 1") or (r.success == true and "Success")
        or (r.success == false and "Miss") or ""
    local m = r.mod or 0
    local sum = (r.roll and m ~= 0) and (util.int(r.roll) .. (m < 0 and " - " or " + ") .. util.int(math.abs(m)) .. " =") or "Rolled"
    local total = util.int(r.total)
    local top = (r.what or "Roll") .. (r.against and (" vs " .. r.against) or "")
    local sw, tw = kit.width(sum, "ui22b"), kit.width(total, "title30")
    local ww = kit.width(word, "ui18b")
    local w = math.max(250, 28 + sw + 10 + tw + (ww > 0 and (18 + ww) or 0))
    local h = 76
    local x = chip.x + (panels.W - w) / 2
    local y = chip.y - h - 8
    local t = { age = 0, life = (app.in_battle and 1.6 or 2.6) / math.sqrt(speed(app)), nodes = {}, colors = {} }
    local function add(n, c)
        table.insert(t.nodes, n)
        table.insert(t.colors, c)
    end
    add(kit.box(x - 2, y - 2, w + 4, h + 4, col, { radius = 12 }), col)
    add(kit.box(x, y, w, h, kit.rgba("#201813", 0.97), { radius = 11 }), kit.rgba("#201813", 0.97))
    add(kit.text(x + 14, y + 8, kit.ellipsize(top, "ui14", w - 28), "ui14", theme.dim, { gloss = false }), theme.dim)
    add(kit.text(x + 14, y + 34, sum, "ui22b", theme.text, { gloss = false }), theme.text)
    add(kit.text(x + 14 + sw + 10, y + 27, total, "title30", col, { gloss = false }), col)
    if ww > 0 then
        add(kit.text(x + w - 14, y + 38, word, "ui18b", col, { pivot = gui.PIVOT_NE, gloss = false }), col)
    end
    app.roll_card = t
end

function M.drop_roll_banner(app)
    if app.roll_card then
        kit.remove(app.roll_card.nodes)
        app.roll_card = nil
    end
end

function M.drop_toast(app)
    if app.toast_card then
        kit.remove(app.toast_card.nodes)
        app.toast_card = nil
    end
end

-- A card on the right that stays up while the night goes on (the newcomer playtest, October 16):
-- how a scene went, or a fight. rows: { { text, color, font } }. It goes when a call comes up, the
-- next scene starts, or its time is up; everything on it is in the log too.
local SIDE_X, SIDE_Y, SIDE_W = 1176, 126, 400

function M.side_card(app, top, title, rows, life)
    M.drop_side(app)
    if not app.layers.fx then
        return
    end
    kit.use(app.layers.fx)
    local w = SIDE_W
    local h = 14 + 20 + kit.text_height(title, "ui22b", w - 32) + 8
    for _, r in ipairs(rows) do
        h = h + kit.text_height(r[1], r[3] or "ui14", w - 32) + 6
    end
    h = h + 10
    local x, y = SIDE_X, SIDE_Y
    local t = { age = 0, life = life / math.sqrt(speed(app)), nodes = {}, colors = {} }
    local function add(n, c)
        table.insert(t.nodes, n)
        table.insert(t.colors, c)
    end
    add(kit.box(x - 2, y - 2, w + 4, h + 4, theme.gold, { radius = 12 }), theme.gold)
    add(kit.box(x, y, w, h, kit.rgba("#201813", 0.96), { radius = 11 }), kit.rgba("#201813", 0.96))
    add(kit.text(x + 16, y + 12, top, "ui14", theme.gold), theme.gold)
    add(kit.text(x + 16, y + 32, title, "ui22b", theme.text, { w = w - 32 }), theme.text)
    local ry = y + 32 + kit.text_height(title, "ui22b", w - 32) + 8
    for _, r in ipairs(rows) do
        local font = r[3] or "ui14"
        add(kit.text(x + 16, ry, r[1], font, r[2] or theme.text, { w = w - 32 }), r[2] or theme.text)
        ry = ry + kit.text_height(r[1], font, w - 32) + 6
    end
    app.side = t
end

function M.drop_side(app)
    if app.side then
        kit.remove(app.side.nodes)
        app.side = nil
    end
end

-- How the table is taking it right now, in a few words each, as the panels' fun bars read it.
local function table_words(app)
    local level = app.campaign:empathy()
    local tells = app.night and app.night:tells() or {}
    local parts, best = {}, 0
    for _, p in ipairs(app.campaign.players) do
        local t = tells[p.key]
        if p.present and t then
            local fun = empathy.fill(level, t.fun)
            local word = fun >= 72 and "loving it" or fun >= 55 and "having a good time" or fun >= 40 and "doing fine"
                or fun >= 25 and "drifting" or "not enjoying it"
            best = math.max(best, fun)
            table.insert(parts, p.name .. " " .. word)
        end
    end
    return table.concat(parts, ", "), best
end

local HOW = { won = "They won.", fled = "The foes ran.", lost = "The party fell back.", escaped = "The boss got away." }

-- The scene's card: what the heroes set out to do and whether they did, what they found, and how
-- the table feels, which is what the night is scored on.
function M.scene_card(app, ev)
    local rows = {}
    local won = ev.outcome == "win"
    if ev.goal then
        table.insert(rows, { "Goal: " .. ev.goal .. ".  " .. (won and "Made it." or "Not this time."), won and theme.green or theme.orange,
            "ui18b" })
    else
        table.insert(rows, { won and "It went their way." or "It went against them.", won and theme.green or theme.orange, "ui18b" })
    end
    if ev.reward then
        table.insert(rows, { kit.ellipsize("Found: " .. ev.reward, "ui14", (SIDE_W - 32) * 2 - 30), theme.text })
    end
    -- A fight scene: the fight's card is still up, so this one carries what it said (the re-test,
    -- October 16: the fight card was gone two seconds after it came up).
    local fight = app.side and app.side.fight and app.last_fight
    if fight then
        for _, r in ipairs(M.fight_rows(fight)) do
            table.insert(rows, r)
        end
    end
    local words, best = table_words(app)
    if words ~= "" then
        table.insert(rows, { "The table: " .. words .. ".", best >= 55 and theme.teal or theme.dim })
    end
    -- Why: the call of yours that moved them most in this room, and who it moved.
    if ev.call then
        table.insert(rows, { "Your biggest call here: " .. ev.call, theme.gold })
    end
    -- Once: the heroes and the table are two different scores.
    local g = app.campaign.guide
    if g and g.seen and not g.seen.scene_card_teach and (not won or app.campaign.week == 1) and not (g.off) then
        g.seen.scene_card_teach = true
        table.insert(rows, { won and "Heroes win some scenes and lose others. The night is scored on how the table feels."
            or "The heroes don't have to win every scene. The night is scored on how the table feels: that's the bars along "
            .. "the bottom, not this.", theme.gold })
    end
    local top = "ROOM " .. util.int(ev.index) .. " DONE"      -- (the museum doesn't know how far tonight goes)
    if fight then
        top = top .. ":  " .. string.upper(HOW[fight.how] or "the fight's over")
    end
    M.side_card(app, top, ev.title or "", rows, fight and 18 or 13)
    M.push(app, "Scene " .. util.int(ev.index) .. " done: " .. (ev.goal and (ev.goal .. ", " .. (won and "made it" or "not this time"))
        or (won and "it went their way" or "it went against them")) .. ". " .. (words ~= "" and ("The table: " .. words .. ".") or ""),
        won and "good" or "system", true)
end


-- The fight's card, when it's over.
function M.fight_card(app, sm)
    local rows = M.fight_rows(sm)
    local title = HOW[sm.how] or "It's over."
    if sm.how == "escaped" then
        title = ((sm.boss and sm.boss.name) or "The boss") .. " got away."
    end
    local rounds = util.int(sm.rounds or 0) .. ((sm.rounds or 0) == 1 and " ROUND" or " ROUNDS")
    M.side_card(app, "FIGHT OVER, AFTER " .. rounds, title, rows, 13)
    app.side.fight = true
    app.last_fight = sm
    local parts = {}
    for _, r in ipairs(rows) do
        table.insert(parts, r[1])
    end
    M.push(app, "Fight over after " .. string.lower(rounds) .. ": " .. string.lower(string.sub(title, 1, 1)) .. string.sub(title, 2)
        .. " " .. table.concat(parts, " "), sm.how == "lost" and "bad" or "good", true)
end

-- What each hero did in the fight, and who was beaten or ran: rows for a side card.
function M.fight_rows(sm)
    local rows = {}
    for _, h in ipairs(sm.heroes or {}) do
        local bits = {}
        if (h.swings or 0) > 0 then
            table.insert(bits, "hit " .. util.int(h.hits) .. " of " .. util.int(h.swings))
        end
        if (h.dealt or 0) > 0 then
            table.insert(bits, util.int(h.dealt) .. " damage")
        end
        if (h.beaten or 0) > 0 then
            table.insert(bits, "beat " .. util.int(h.beaten))
        end
        if h.dead then
            table.insert(bits, "fell")
        elseif (h.downs or 0) > 0 then
            table.insert(bits, "went down " .. (h.downs == 1 and "once" or (util.int(h.downs) .. " times")))
        end
        local health = h.dead and "" or ("  " .. util.int(h.hp) .. " of " .. util.int(h.hp_max) .. " health left.")
        table.insert(rows, { (h.name or "?") .. ": " .. (#bits > 0 and table.concat(bits, ", ") or "kept their head down") .. "."
            .. health, (h.dead or (h.hp or 0) <= (h.hp_max or 1) * 0.35) and theme.orange or theme.text })
    end
    if #(sm.beaten or {}) > 0 then
        table.insert(rows, { "Beaten: " .. util.join_names(mid_names(sm.beaten)) .. ".", theme.green })
    end
    if #(sm.ran or {}) > 0 then
        table.insert(rows, { ((sm.how == "yielded" and "Stood down: ") or "Ran: ")
            .. util.join_names(mid_names(sm.ran)) .. ".", theme.dim })
    end
    return rows
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

function M.bubble(app, anchor, speaker, text, ic, thought)
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
    if thought then
        -- What they're thinking: a pale cloud, not their voice (v2).
        bg, ink, label = theme.think.bg, theme.think.ink, theme.think.dim
    end
    local b = { anchor = anchor, w = tw + 26, h = 30 + #lines * 23 + 8, age = 0,
                life = math.max(1.4, (pacing.read(text) + 0.4) / speed(app)) }
    b.nodes = {
        kit.box(0, 0, b.w, b.h, bg, { radius = 10 }),
        kit.icon(0, 0, 18, "tail", bg),
        kit.text(0, 0, speaker, "ui14", label, { gloss = false }),
        kit.text(0, 0, table.concat(lines, "\n"), "ui18", ink, { gloss = false }),     -- (their words: no glossary)
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
            -- (Above a friend's thought cloud, when there's one over their panel.)
            local floor = col_x and (CHIP_Y - 8) or CARD_BOTTOM
            if col_x and b.anchor.head and app.thinking and app.thinking[b.anchor.head] then
                floor = CHIP_Y - 38
            end
            local y = util.clamp(ay - b.h - 16, 64, floor - b.h)
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
    -- Clear of the speech bubbles (the newcomer playtest, October 16: a "-7" rose behind what
    -- someone was saying): beside the bubble instead, on the side the mini is on.
    for _, b in ipairs(app.bubbles or {}) do
        if b.x and x < b.x + b.w + 4 and b.x < x + w + 4 and y - 40 < b.y + b.h + 4 and b.y < y + h + 4 then
            if ax < b.x + b.w / 2 then
                x = b.x - w - 8
            else
                x = b.x + b.w + 8
            end
            if x < 8 or x + w > kit.W - 8 then
                x = util.clamp(x, 8, kit.W - 8 - w)
                y = b.y + b.h + 8 + 40
            end
        end
    end
    -- (A big one, "Beaten!" or "Down!", stays a little longer: the re-test never caught one.)
    local f = { id = id, x = x, y = y, w = w, h = h, age = 0, life = (big and 2.2 or 1.3) / math.sqrt(speed(app)) }
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
    -- The camera flash (B1).
    local fl = app.flash
    if fl then
        fl.t = fl.t + dt
        if fl.t >= 0.35 then
            kit.remove({ fl.node })
            app.flash = nil
        else
            gui.set_color(fl.node, kit.rgba("#ffffff", 0.7 * (1 - fl.t / 0.35)))
        end
    end
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
                for _, n in ipairs({ c.box, c.rule, c.tag, c.text, c.voice_bg, c.voice }) do
                    gui.set_enabled(n, false)
                end
                c.voice_on = false
                -- (Its underlines go with it, and so do their hovers: a spot sits on its node.)
                for _, n in ipairs(c.gloss_nodes or {}) do
                    pcall(gui.set_enabled, n, false)
                end
            end
        end
        gui.set_color(c.text, alpha_of(c.color, a))
        gui.set_color(c.box, caption_box_color(c, a))
        gui.set_color(c.tag, alpha_of(theme.ink_dim, a))
        gui.set_color(c.rule, alpha_of(theme.gold, a))
        if c.voice_on and c.voice_color then
            gui.set_color(c.voice_bg, alpha_of(c.voice_color, a))
            gui.set_color(c.voice, alpha_of(theme.bg, a))
        end
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
    local rc = app.roll_card
    if rc then
        rc.age = rc.age + dt
        if rc.age >= rc.life then
            M.drop_roll_banner(app)
        elseif rc.life - rc.age < 0.4 then
            fade(rc.nodes, rc.colors, (rc.life - rc.age) / 0.4)
        end
    end
    local ty = app.tiny_card
    if ty then
        ty.age = ty.age + dt
        if ty.age >= ty.life then
            M.drop_tiny_roll(app)
        elseif ty.life - ty.age < 0.4 then
            fade(ty.nodes, ty.colors, (ty.life - ty.age) / 0.4)
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
    -- The side card steps aside for a call that needs the space (a card on the right, the opening)
    -- and waits; it comes back after.
    local sd = app.side
    if sd then
        local pk = app.pending and app.pending.kind
        local hide = pk == "decision" or pk == "cinematic"
        if hide ~= (sd.hidden or false) then
            sd.hidden = hide
            for _, n in ipairs(sd.nodes) do
                gui.set_enabled(n, not hide)
            end
        end
        if not hide then
            sd.age = sd.age + dt
            if sd.age >= sd.life then
                M.drop_side(app)
            elseif sd.life - sd.age < 0.6 then
                fade(sd.nodes, sd.colors, (sd.life - sd.age) / 0.6)
            end
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
    -- The DM's notes or a character sheet is open: the table waits. (So does a person's sheet,
    -- and the Pause button.)
    if app.overlay or app.npc_sheet or app.paused then
        return
    end
    -- So does a friend's thought you're reading (v2), and your recap. (The thought's own clock runs.)
    M.tick_thought(app, dt)
    if app.thought_card or recap_view.open_any(app) then
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
    if not (app.pending or app.rolling or app.night_done or app.paused) then
        app.timer = 0
    end
end

-- F: faster, and from the top back round to 1x. G: slower, down to half speed.
function M.cycle_speed(app)
    local i = app.speed_i or M.SPEED_1X
    app.speed_i = (i >= #SPEEDS) and M.SPEED_1X or (i + 1)
    M.refresh_status(app)
end

function M.slow_down(app)
    app.speed_i = math.max(1, (app.speed_i or M.SPEED_1X) - 1)
    M.refresh_status(app)
end

-- Pause (the button, or P): the table waits, cards and thoughts and all, until you carry on.
function M.toggle_pause(app)
    app.paused = not app.paused or nil
    M.toast(app, app.paused and "PAUSED" or "PLAYING", app.paused and "The table waits. Click Play, or press P, to carry on."
        or "Back to the table.")
    M.refresh_status(app)
end

function M.set_speed(app, i)
    app.speed_i = i
    app.paused = nil
    -- (The night hears it too: table life plays fewer small moments at 2x, none at 4x.)
    if app.night then
        app.night.speed_hint = i
        app.night.fast = (i >= 4) or nil
    end
    M.refresh_status(app)
end

-- Small-moment crits, on or off (the playtest, November 3): top right, under End session.
function M.draw_crits(app)
    if not app.night then
        return
    end
    local tl = require "game.model.table_life"
    local on = tl.crits_on(app.campaign)
    app.n_crits = kit.button(1452, 66, 124, 30, on and "Crits: on" or "Crits: off", function()
        local now = not tl.crits_on(app.campaign)
        tl.set_crits(app.campaign, now)
        if app.n_crits and app.n_crits.label then
            pcall(gui.set_text, app.n_crits.label, now and "Crits: on" or "Crits: off")
            pcall(gui.set_color, app.n_crits.node, now and theme.panel3 or app.n_crits.color)
        end
        M.toast(app, now and "SMALL-MOMENT CRITS ON" or "SMALL-MOMENT CRITS OFF",
            now and "A natural 20 or 1 in a small moment gives you a card to improvise." or "Small moments play out on their own.")
    end, { font = "ui14", key = "night_crits", color = on and theme.panel3 or nil })
    require("game.ui.gloss").card_spot(1452, 66, 124, 30, "Small-moment crits",
        "In the quiet bits of a room, the friends poke at things, ask questions and chat, and a little die rolls on its "
        .. "own. On: when one of those little rolls is a natural 20 or a natural 1, you get a quick card to improvise: hide "
        .. "a small find, give them a clue, or a mishap, a small trap, or just a laugh. Off: those rolls play out on their "
        .. "own, and you're never asked. Big rolls aren't affected.")
end

-- A small moment's die (table_life.lua): small, over the roller's tile, gone in a moment.
function M.tiny_roll(app, ev)
    local chip = app.chips and app.chips[ev.who]
    if not (chip and app.layers and app.layers.fx) then
        return
    end
    M.drop_tiny_roll(app)
    kit.use(app.layers.fx)
    local nat = ev.roll == 20 and theme.gold or (ev.roll == 1 and theme.red) or theme.teal
    local m = ev.mod or 0
    local sum = util.int(ev.roll) .. (m < 0 and " - " or " + ") .. util.int(math.abs(m)) .. " = "
    local total = util.int(ev.total)
    local label = ev.skill or "Roll"
    local sw, tw, lw = kit.width(sum, "ui14"), kit.width(total, "ui18b"), kit.width(label, "ui14")
    local w = 24 + lw + 10 + sw + tw
    local h = 30
    local x = chip.x + (panels.W - w) / 2
    local y = chip.y - h - 8
    local t = { age = 0, life = 1.8 / math.sqrt(speed(app)), nodes = {}, colors = {} }
    local function add(n, c)
        table.insert(t.nodes, n)
        table.insert(t.colors, c)
    end
    local bg = kit.rgba("#201813", 0.92)
    add(kit.box(x, y, w, h, bg, { radius = 8 }), bg)
    add(kit.text(x + 12, y + 6, label, "ui14", theme.dim, { gloss = false }), theme.dim)
    add(kit.text(x + 12 + lw + 10, y + 6, sum, "ui14", theme.text, { gloss = false }), theme.text)
    add(kit.text(x + 12 + lw + 10 + sw, y + 4, total, "ui18b", nat, { gloss = false }), nat)
    app.tiny_card = t
end

function M.drop_tiny_roll(app)
    if app.tiny_card then
        kit.remove(app.tiny_card.nodes)
        app.tiny_card = nil
    end
end

local SPEED_BTNS = { { "Pause", 52 }, { "1x", 38, 2 }, { "2x", 38, 3 }, { "4x", 38, 4 } }

-- The buttons: whichever is on is lit (gold), Pause turns into Play while the night waits.
function M.paint_speed(app)
    for _, b in ipairs(app.n_speed or {}) do
        local on = (b.speed_i == nil and app.paused) or (b.speed_i ~= nil and not app.paused and (app.speed_i or M.SPEED_1X) == b.speed_i)
        pcall(gui.set_color, b.node, on and theme.gold or b.color)
        if b.label then
            pcall(gui.set_color, b.label, on and theme.bg or kit.rgba("#f3e7cf"))
            if b.speed_i == nil then
                pcall(gui.set_text, b.label, app.paused and "Play" or "Pause")
            end
        end
    end
end

function M.draw_speed(app, x, y)
    app.n_speed = {}
    local gl = require "game.ui.gloss"
    local bx = x
    for _, d in ipairs(SPEED_BTNS) do
        local si = d[3]
        local b = kit.button(bx, y, d[2], 38, d[1], function()
            if si then
                M.set_speed(app, si)
            else
                M.toggle_pause(app)
            end
        end, { font = "ui14", key = si and ("night_speed_" .. d[1]) or "night_pause" })
        b.speed_i = si
        table.insert(app.n_speed, b)
        bx = bx + d[2] + 4
    end
    gl.card_spot(x, y, bx - x - 4, 38, "Game speed",
        "How fast the night plays at the table: 1x, twice as fast, or four times. Pause stops everything, even a call's "
        .. "timer and a friend's thought, until you press Play. Keys: F faster, G down to half speed, P pause, Space skips ahead.")
    M.paint_speed(app)
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

local function party_list(list, app)
    local out = {}
    for _, p in ipairs(list or {}) do
        local pl = app and app.campaign:player(p.id)
        table.insert(out, { id = p.id, class = p.class, sprite = (pl and pl.mini) or CLASS_SPRITE[p.class] or "fighter", x = p.x, y = p.y })
    end
    return out
end

-- A short fingerprint of a map's pieces, so the same map isn't laid twice.
local function pieces_key(cells)
    if not cells then
        return ""
    end
    local out = {}
    for _, kind in ipairs({ "trap" }) do
        for _, sq in ipairs(cells[kind] or {}) do
            table.insert(out, kind .. sq[1] .. "," .. sq[2])
        end
    end
    return table.concat(out, ";")
end

local function stage(app, ev)
    local id = ev.board or ev.terrain
    local fresh = id ~= app.terrain
    if fresh then
        app.terrain = id
        -- A new place: its floor and walls go down (and the DM's own set pieces, Set the stage);
        -- the rest comes as the DM describes it.
        post_board("board", { id = id, show = ev.show or "base", def = board_mod.encode(id) })
    end
    local npc
    app.mini_npc = {}
    if ev.npc then
        npc = { sprite = CAST_SPRITE[ev.npc.cast] or "npc_stranger", x = ev.npc.x, y = ev.npc.y }
        app.names.npc = ev.npc.name
        local okn, npcs = pcall(require, "game.model.npcs")
        if okn and npcs.get(ev.npc.cast) then
            app.mini_npc.npc = ev.npc.cast
        end
    end
    -- The person in the scene steps onto the mat when the DM names them.
    app.stage_party = party_list(ev.party, app)
    app.npc_waiting = nil
    if ev.npc_hidden and npc then
        app.npc_waiting = npc
        npc = nil
    end
    app.on_table = { npc = npc and true or nil }
    post("stage", { party = app.stage_party, npc = npc, fresh = fresh })
    -- The DM's map for this place (B9), or a clean mat. The same map again (another scene at the
    -- same place, or the scenery shifting under the same map) stays put instead of being re-laid.
    local key = pieces_key(ev.pieces)
    if key ~= (app.pieces_key or "") then
        post("pieces", { cells = ev.pieces })
        app.pieces_key = key
    end
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

-- Why an attack landed or didn't, in one line anyone can follow (the newcomer playtest, October
-- 16: "a 9 against 15 both missed and hit", three ACs for one bandit, no reason given).
-- "Thessaly's Fire Bolt" / "the road's bandit chief's scimitar"
-- A spell's name from its id ("sacred_flame" is Sacred Flame); a name stays as it is.
local function spell_name(id)
    local ok, spells = pcall(require, "game.rules.spells")
    local sp = ok and spells.list and spells.list[id]
    return (type(sp) == "table" and sp.name) or (string.gsub(tostring(id), "_", " "))
end

local spell_names
local function is_spell(name)
    if not spell_names then
        spell_names = {}
        local ok, spells = pcall(require, "game.rules.spells")
        for _, sp in pairs(ok and spells.list or {}) do
            if type(sp) == "table" and sp.name then
                spell_names[sp.name] = true
            end
        end
    end
    return spell_names[name] or false
end

local function weapon_of(app, a)
    local who = name_of(app, a.id)
    local w = a.weapon or "attack"
    if not (a.spell or is_spell(w)) then
        w = string.lower(w)
    end
    return who .. (string.sub(who, -1) == "s" and "' " or "'s ") .. w
end

local function target_of(app, id)
    return mid(name_of(app, id))
end

-- "8 + 5 = 13 against AC 20 (15, +5 behind the boulder), with Advantage"
local function versus(a)
    local bonus = (a.total or a.roll or 0) - (a.roll or 0)
    local out = util.int(a.roll or 0) .. " " .. (bonus < 0 and "- " or "+ ") .. util.int(math.abs(bonus)) .. " = "
        .. util.int(a.total or 0) .. " against AC " .. util.int(a.ac or 0)
    if a.cover then
        out = out .. " (" .. util.int((a.ac or 0) - a.cover) .. ", +" .. util.int(a.cover)
            .. (a.cover_what and (" behind the " .. a.cover_what) or " for cover") .. ")"
    end
    if (a.mode or 0) > 0 then
        out = out .. ", with Advantage"
    elseif (a.mode or 0) < 0 then
        out = out .. ", with Disadvantage"
    end
    if a.heroic then
        out = out .. " (a reroll: Heroic Inspiration)"
    end
    return out
end

-- "45 of 52 left", or "down to 0"
local function left_of(s)
    if not s.hp or not s.hp_max then
        return ""
    end
    if s.hp <= 0 then
        return " Down to 0."
    end
    return " " .. util.int(s.hp) .. " of " .. util.int(s.hp_max) .. " left."
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
            local tgt = target_of(app, s.target)
            if s.blocked == "no_line" then
                M.push(app, name_of(app, s.id) .. " can't see " .. tgt .. " from there: there's a wall in the way.", "system")
            elseif s.hidden then
                M.push(app, util.capitalize(weapon_of(app, s)) .. " misses " .. tgt .. " (you rolled it behind your screen).", "system")
            elseif s.blocked == "cover" then
                -- The board earning its keep: the shot that would have landed hits the scenery.
                M.push(app, util.capitalize(tgt) .. " ducks behind " .. (s.cover_what and ("the " .. s.cover_what) or "cover")
                    .. ", and " .. mid(weapon_of(app, s)) .. " hits that instead: " .. versus(s) .. ".", "system")
            elseif s.blocked then
                M.push(app, util.capitalize(weapon_of(app, s)) .. " would have hit " .. tgt .. " (" .. versus(s) .. "), but it's stopped: "
                    .. (BLOCKED[s.blocked] or "blocked") .. ".", "system")
            elseif s.roll == 1 then
                M.push(app, util.capitalize(weapon_of(app, s)) .. " misses " .. tgt .. ": a natural 1 always misses.", "system")
            else
                M.push(app, util.capitalize(weapon_of(app, s)) .. " misses " .. tgt .. ": " .. versus(s) .. ".", "system")
            end
        end
    elseif k == "damage" then
        post("hit", { id = s.id })
        M.float(app, s.id, "-" .. util.int(s.amount or 0), s.crit and theme.gold or theme.red, s.crit)
        set_hp(app, s.id, s.hp, s.hp_max)
        local a = app.last_attack
        local amount = util.int(s.amount or 0)
        if s.graze and a and a.target == s.id then
            -- A miss that still hurts: say it's the weapon's trick, not a hit.
            M.push(app, "Even missing, " .. mid(weapon_of(app, a)) .. " grazes " .. target_of(app, s.id) .. " for " .. amount
                .. " (the weapon's Graze trick: a miss still nicks)." .. left_of(s), "system")
            app.last_attack = nil
        elseif a and a.target == s.id and a.hit then
            -- (Damage past what the dice can do says why: a crit, or a weakness.)
            local weak = s.weak and (s.weak == "paint" and ", doubled: painted things fear it" or (", doubled: weak to " .. s.weak)) or ""
            local dice = (a.dmg and a.dmg ~= "") and (" (" .. a.dmg .. (s.crit and ", doubled" or "") .. weak .. ")") or ""
            if a.hidden then
                M.push(app, util.capitalize(weapon_of(app, a)) .. " hits " .. target_of(app, s.id) .. " (your roll, behind the screen): "
                    .. amount .. " damage" .. dice .. "." .. left_of(s), "system")
            elseif s.crit then
                M.push(app, util.capitalize(weapon_of(app, a)) .. " crits " .. target_of(app, s.id) .. ": a natural 20, so the damage "
                    .. "dice double. " .. amount .. " damage" .. dice .. "!" .. left_of(s), "good")
            else
                local tie = (a.total and a.ac and a.total == a.ac) and " (matching the AC is enough)" or ""
                M.push(app, util.capitalize(weapon_of(app, a)) .. " hits " .. target_of(app, s.id) .. ": " .. versus(a) .. tie .. ". "
                    .. amount .. " damage" .. dice .. "." .. left_of(s), "system")
            end
            app.last_attack = nil
        else
            local from = s.spell and (" from " .. spell_name(s.spell)) or ""
            M.push(app, name_of(app, s.id) .. " takes " .. amount .. " damage" .. from .. "." .. left_of(s), "system")
        end
    elseif k == "heal" then
        M.float(app, s.id, "+" .. util.int(s.amount or 0), theme.green)
        spark(app, s.id, SPARK.heal)
        set_hp(app, s.id, s.hp, s.hp_max)
        -- Healing shows in the log (A7).
        if (s.amount or 0) > 0 then
            local hp = s.hp and s.hp_max and (" (" .. util.int(s.hp) .. "/" .. util.int(s.hp_max) .. ")") or ""
            if s.by and s.by ~= s.id then
                M.push(app, name_of(app, s.by) .. " heals " .. name_of(app, s.id) .. " for " .. util.int(s.amount) .. hp .. ".", "good")
            else
                M.push(app, name_of(app, s.id) .. " regains " .. util.int(s.amount) .. " hit points" .. hp .. ".", "good")
            end
        end
    elseif k == "temp" then
        M.float(app, s.id, "+" .. util.int(s.amount or 0) .. " temp", theme.teal)
        M.push(app, name_of(app, s.id) .. " gains " .. util.int(s.amount or 0) .. " temporary hit points.", "good")
    elseif k == "down" then
        post("down", { id = s.id })
        M.float(app, s.id, "Down!", theme.orange, true)
        set_hp(app, s.id, 0)
        -- A hero at 0: a moment the whole table feels (the playtest, November 3: "a more pronounced
        -- downed scene"). Over their tile until they're up, stable or gone: their death saves.
        if is_party(app, s.id) then
            app.ds = app.ds or {}
            app.ds[s.id] = { s = 0, f = 0 }
            M.dying(app, s.id)
            post("pose", { who = s.id, pose = "gasp", hold = true })
        end
        -- The first time, what it means (a newcomer thinks "down" is "dead").
        if is_party(app, s.id) and not app.down_said then
            app.down_said = true
            M.push(app, name_of(app, s.id) .. " goes down! At 0 health a hero isn't dead yet: they roll each turn to stay "
                .. "alive, and any healing brings them back up.", "bad")
        else
            M.push(app, name_of(app, s.id) .. " goes down!", "bad")
        end
    elseif k == "up" then
        post("up", { id = s.id })
        M.float(app, s.id, "Back up!", theme.green, true)
        M.drop_dying(app, s.id)
    elseif k == "death" then
        if app.hp[s.id] then
            post("down", { id = s.id })
        else
            -- A beat for it before the mini goes (the newcomer playtest, October 16: the wolf just vanished).
            M.float(app, s.id, "Beaten!", theme.gold, true)
            spark(app, s.id, SPARK.crit)
            post("die", { id = s.id })
            battle_hud.gone(app, s.id)
            M.push(app, name_of(app, s.id) .. " is beaten: out of the fight.", "good")
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
    elseif k == "hazard" then
        M.push(app, "Hazard: " .. (s.name or "") .. (s.from and (", from the " .. s.from) or "") .. ". " .. (s.about or ""),
            "system")
    elseif k == "hazard_act" then
        M.push(app, (s.name or "The hazard acts") .. ".", "bad")
    elseif k == "zone" then
        local col = SPARK[s.what] or rgba(0.9, 0.9, 0.9)
        battle_hud.area(app, s.cells, col, s.zone)
    elseif k == "zone_end" then
        battle_hud.zone_end(app, s.zone)
    elseif k == "door" then
        -- Set the stage: a door swings open on the mat as someone walks through, or a lock gives.
        post_board("door", { fid = s.fid, state = s.state })
        if s.state == "open" then
            M.push(app, (s.id and name_of(app, s.id) or "Someone") .. " opens the door.", "system")
        elseif s.state == "closed" then
            M.push(app, "The lock gives.", "good")
        end
    elseif k == "feature" then
        if s.name == "Potion of Healing" then
            M.float(app, s.id, "Potion!", theme.teal)
            if s.target and s.target ~= s.id and type(s.target) ~= "table" then
                M.push(app, name_of(app, s.id) .. " pours a Potion of Healing into " .. name_of(app, s.target) .. ".", "good")
            else
                M.push(app, name_of(app, s.id) .. " drinks a Potion of Healing.", "good")
            end
        elseif s.name == "Heroic Inspiration" and s.from and s.to then
            M.float(app, s.id, s.name, theme.gold)
            M.push(app, name_of(app, s.id) .. " spends Heroic Inspiration to reroll the die: " .. util.int(s.from) .. " becomes "
                .. util.int(s.to) .. ".", "good")
        elseif s.museum and MUSEUM_SAY[s.museum] then
            -- The museum's big moments (v2, game/rules/museum.lua), said the way the DM would.
            local say = MUSEUM_SAY[s.museum]
            local function nm(id)
                return (type(id) == "string" and name_of(app, id)) or "someone"
            end
            local text = say[1]
            if say.soft and app.campaign and app.campaign.adv then
                local adv = require "game.model.adventure"
                for tag, alt in pairs(say.soft) do
                    if adv.test(app.campaign, { soft = tag }) then
                        text = alt
                    end
                end
            end
            M.float(app, s.id, s.name, say[2] or theme.teal)
            M.push(app, (string.gsub(text, "{(%w+)}", { who = nm(s.id), target = nm(s.target), by = nm(s.by) })), say[3] or "system")
        elseif s.name then
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
        -- A roll to resist, said in the log like an attack (the newcomer playtest, October 16).
        local ab = s.ab and (string.upper(s.ab) .. " save") or "save"
        -- (Rolled twice, and why: "with Disadvantage: the drone left them half asleep".)
        if s.mode then
            ab = ab .. ((s.mode == "adv" and ", with Advantage") or (s.mode == "dis" and ", with Disadvantage")
                or ", Advantage and Disadvantage cancel out") .. (s.why_mode and (": " .. s.why_mode) or "")
        end
        if s.hidden or not (s.roll and s.total and s.dc) then
            M.push(app, name_of(app, s.id) .. (s.ok and " resists it" or " fails to resist") .. " (a " .. ab
                .. (s.hidden and ", behind your screen)." or ")."), "system")
        else
            M.push(app, name_of(app, s.id) .. (s.ok and " resists it" or " fails to resist") .. " (a " .. ab .. "): "
                .. util.int(s.roll) .. " " .. ((s.total - s.roll) < 0 and "- " or "+ ") .. util.int(math.abs(s.total - s.roll))
                .. " = " .. util.int(s.total) .. " against DC " .. util.int(s.dc) .. ".", "system")
        end
        if is_party(app, s.id) and s.roll then
            panels.roll(app, s.id, { roll = s.roll, mod = (s.total or s.roll) - s.roll, total = s.total,
                                     against = s.dc and ("DC " .. util.int(s.dc)) or nil,
                                     what = (s.ab and string.upper(s.ab) or "") .. " save", success = s.ok })
        end
    elseif k == "death_save" then
        M.add_die(app, { roll = s.roll, success = (s.roll or 0) >= 10, crit = s.roll == 20, fumble = s.roll == 1 })
        local t = app.ds and app.ds[s.id]
        if t then
            local r = s.roll or 0
            if r == 1 then
                t.f = t.f + 2
            elseif r >= 10 and r < 20 then
                t.s = t.s + 1
            elseif r < 10 then
                t.f = t.f + 1
            end
            if r == 20 then
                M.drop_dying(app, s.id)
            else
                M.dying(app, s.id)
            end
        end
        M.float(app, s.id, "Death save: " .. util.int(s.roll or 0), (s.roll or 0) >= 10 and theme.teal or theme.red)
        if is_party(app, s.id) then
            panels.roll(app, s.id, { roll = s.roll, total = s.roll, against = "DC 10", what = "Death save",
                                     success = (s.roll or 0) >= 10, crit = s.roll == 20 })
        end
    elseif k == "stable" then
        M.float(app, s.id, "Stable", theme.teal)
        if app.ds and app.ds[s.id] then
            app.ds[s.id].stable = true
            M.dying(app, s.id)
        end
    elseif k == "fortitude" then
        M.float(app, s.id, "Undead Fortitude", theme.purple)
    elseif k == "flee" and s.why == "yield" then
        -- Standing down with a boss who yielded: her line says it, once (fight.lua's yield).
        M.float(app, s.id, "Stands down", theme.teal)
        battle_hud.gone(app, s.id)
    elseif k == "flee" then
        post("flee", { id = s.id })
        battle_hud.gone(app, s.id)
        M.push(app, name_of(app, s.id) .. " runs for it.", "system")
    elseif k == "join" and s.pc then
        -- A hero who split off comes running back into the fight (the split party, November 3).
        local pl = app.campaign:player(s.id)
        local sprite = (pl and pl.mini) or CLASS_SPRITE[s.class] or "fighter"
        post("spawn", { list = { { id = s.id, sprite = sprite, x = s.x, y = s.y, side = "party" } } })
        app.hp[s.id] = { s.hp, s.hp_max }
        M.refresh_hp(app)
        M.push(app, (s.name or "Someone") .. " is back, and in the fight.", "good")
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

-- The pieces the DM's words just named drop onto the mat as the words land.
local function board_reveal(app, ev)
    local ids, delays = {}, {}
    local read = (ev.text and pacing.read(ev.text) or 0) / speed(app)
    for _, r in ipairs(ev.reveal) do
        table.insert(ids, r.id)
        table.insert(delays, 0.15 + (r.at or 0) * read * 0.85)
    end
    post_board("reveal", { ids = ids, delays = delays })
end

local function npc_steps_in(app)
    local npc = app.npc_waiting
    if not npc then
        return
    end
    app.npc_waiting = nil
    app.on_table = app.on_table or {}
    app.on_table.npc = true
    post("stage", { party = app.stage_party, npc = npc })
end

function M.handle(app, ev)
    if app.trailer_log then
        app.trailer_log(ev)      -- (the autotest's trailer pace: what happened when, for cutting footage)
    end
    local k = ev.kind
    ambience.night_event(app, ev)
    if ev.reveal then
        board_reveal(app, ev)
    end
    if ev.npc_show then
        npc_steps_in(app)
    end
    if k == "scene" then
        M.prune_thinks(app)        -- a thought about the last scene has passed with it
        -- This scene's rolls only (the card-led playtest, October 16: last scene's dice stayed up), and
        -- last scene's card goes (the second playtest, October 17: it was still up under the new
        -- scene's title).
        app.strip = {}
        M.draw_strip(app)
        M.drop_side(app)
        if panels.clear_rolls then
            panels.clear_rolls(app)
        end
        if (ev.index or 1) >= 2 and not app.keys_hidden then
            app.keys_hidden = true
            if app.n_keys then
                gui.set_enabled(app.n_keys, false)
            end
        end
        app.scene_type_name = ev.type_name
        app.scene_label = "Room " .. util.int(ev.index) .. ":  " .. ev.title
        local who = ev.cast and (" with " .. util.lower_first(ev.cast)) or ""
        -- What the scene is for, under its name (the card-led night, October 16).
        app.scene_sub = ev.goal and ((ev.type_name or "") .. ": " .. util.lower_first(ev.goal)) or ((ev.type_name or "") .. who)
        gui.set_text(app.n_label, kit.ellipsize(app.scene_label, "ui18b", M.label_w(app)))
        gui.set_text(app.n_sub, kit.ellipsize(app.scene_sub, "ui14", 360))
        app.progress = nil
        M.draw_pips(app)
        M.push(app, app.scene_label .. "  (" .. app.scene_sub .. ")", "scene", true)
        -- (The goal is under the scene's name in the header, right above: the title card says where
        -- and who.)
        local sub = (ev.type_name or "") .. who
        M.title(app, "ROOM " .. util.int(ev.index), ev.title, sub)
        stage(app, ev)
        cam(app, 2)
    elseif k == "stage" then
        stage(app, ev)
        if ev.title then
            M.title(app, "THE SCENE SHIFTS", ev.title, "")
        end
        cam(app, 2)
    elseif k == "cinematic" then
        -- The opening of the first session (museum_night.intro).
        app.pending = ev
        app.cine_i = 1
        M.show_cinematic(app, ev)
    elseif k == "narrate" then
        -- A DM-only aside goes to the log, never the big caption (A2). A record (what a card or a die
        -- already showed: "Thessaly rolls a 19, +5: 24") is for the open log only.
        if ev.style ~= "aside" and ev.style ~= "record" then
            M.caption(app, ev.text, ev.style)
        end
        M.push(app, ev.text, ev.style == "record" and "dice" or ev.style, ev.style ~= "aside")
    elseif k == "intro" then
        -- First-session intros: their mini goes down on the mat and lights up while they talk.
        while app.bubbles and #app.bubbles > 0 do
            drop_bubble(app, 1)      -- the last one's lines have had their moment
        end
        post("stage", { party = party_list(ev.party, app) })
        local secs = 6 / speed(app)
        panels.light(app, ev.who, secs)
        schedule(app, 0.5, function()
            post("glow", { id = ev.who, time = secs })
            spark(app, ev.who, SPARK.crit)
        end)
        M.title(app, "MEET THE PARTY   " .. util.int(ev.index) .. " OF " .. util.int(ev.total), ev.char, ev.sub or "")
        M.push(app, "Meet " .. ev.char .. " (" .. (ev.sub or "") .. ").", "scene", true)
        post("pose", { who = ev.who, pose = "cheer", hold = true })
        panels.pose(app, ev.who, "cheer")
        cam(app, 2)
    elseif k == "dice" then
        -- New dice (a gift, or a set someone's showing off): their tray gets the new set.
        if app.paint_dice then
            app.paint_dice()
        end
        if ev.set then
            panels.set_dice(app, ev.who, ev.set)
        end
        local p = player(app, ev.who)
        if p then
            M.float(app, ev.who, ev.gift and ("The dice you gave: " .. (ev.name or "")) or ("New dice! " .. (ev.name or "")),
                theme.gold)
            M.push(app, ev.gift and (p.name .. " brought the dice you gave them: " .. (ev.name or "") .. ".")
                or (p.name .. " shows off a new set of dice: " .. (ev.name or "") .. "."), "reaction", true)
        end
        if app.tumble_die then
            app.tumble_die(ev.who, 20)
        end
        post("pose", { who = ev.who, pose = "cheer", hold = true })
    elseif k == "keepsake" then
        -- Their gift from last week, put to work on your side of the table: they spot it.
        app.keepsake_seen = true
        local p = player(app, ev.who)
        if p then
            M.float(app, ev.who, "Their " .. (ev.short or "gift") .. ", all set up!", theme.heart)
            M.push(app, p.name .. " spots the " .. (ev.short or "gift") .. " they gave you, out on your side of the table.",
                "reaction")
        end
        if app.place_keepsakes then
            app.place_keepsakes(ev.id)
        end
        post("pose", { who = ev.who, pose = "cheer", hold = true })
    elseif k == "token" then
        -- Heroic Inspiration (B4): the token lands in front of them, or goes back when it's spent.
        panels.set_token(app, ev.who, not ev.spent)
        if not ev.spent then
            M.float(app, ev.who, "Heroic Inspiration!", theme.gold)
            post("spark", { id = ev.who, color = SPARK.crit })
        end
    elseif k == "jail" then
        -- B2: the die that rolled a 1 goes to dice jail, to the table's delight.
        local p = player(app, ev.who)
        if p then
            M.push(app, p.name .. "'s d20 goes to dice jail.", "reaction", true)
            M.float(app, ev.who, "Dice jail!", theme.orange)
        end
        post("pose", { who = ev.who, pose = "laugh", hold = true })
        if app.jail_die then
            app.jail_die(ev.who)
        end
    elseif k == "progress" then
        -- A mid-scene big roll moved the dots too (the card-led playtest: a triumph left them be).
        app.progress = ev.progress
        M.draw_pips(app)
    elseif k == "mark" then
        -- v2: Euryale's card changed (her thought comes as the next caption).
        M.toast(app, "EURYALE'S CARD: " .. string.upper(ev.name), ev.showdown .. ". (" .. ev.why .. ".)")
        M.push(app, "Euryale's card: " .. ev.name .. ". " .. ev.showdown .. ".", "clue", true)
    elseif k == "warning" then
        -- v2: fair warning (warnings.lua): what they know now, or a harsh call judged against it.
        if ev.what and ev.how then
            local how = require("game.model.warnings").HOW[ev.how] or ev.how
            M.push(app, "They know: " .. ev.what .. " (" .. how .. ").", "aside", true)
        elseif ev.unearned then
            M.push(app, "A harsh call with no warning. It felt arbitrary.", "warn", true)
        end
    elseif k == "stage_dress" then
        -- v2: the board dresses itself without a line about it (ev.reveal did the work above).
    elseif k == "scene_end" then
        M.scene_card(app, ev)
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
        M.push(app, ev.name .. ": \"" .. ev.text .. "\"", "quote", true)
        review.on_line(app, ev)
    elseif k == "tiny_roll" then
        M.tiny_roll(app, ev)
    elseif k == "hp" then
        M.refresh_hp(app)        -- (a small trap's sting, on the tile)
    elseif k == "rested" then
        M.refresh_hp(app)        -- (a rest: hit points and resources back on the tiles)
    elseif k == "door" then
        -- A hero walking through a door outside a fight (sight.lua): it swings open on the mat.
        post_board("door", { fid = ev.fid, state = ev.state })
    elseif k == "walk" then
        -- A hero crossing the mat to something (museum_night.explore, a moment's spot): square by
        -- square, at a walk (table.script works the pace out from how far it is).
        post("walk", { id = ev.actor, path = ev.path, per_square = 0.16 / speed(app) })
    elseif k == "say" then
        local p = player(app, ev.who)
        local speaker = p and (ev.ic and p.char or p.name) or "Someone"
        local anchor = { head = ev.who }
        local secs = 1.2 + pacing.read(ev.text)
        if ev.ic then
            -- In character, it shows (A9): their panel and their mini on the board light up, and
            -- the line comes from the mini when it's on the board. Table talk stays at their head.
            panels.light(app, ev.who, secs / speed(app), "ic")
            post("glow", { id = ev.who, time = secs / speed(app) })
            -- ...and at the table they turn into their hero while they say it (two sides of a token).
            if p then
                post("become", { who = ev.who, sprite = p.mini or CLASS_SPRITE[p.class] or "fighter", time = secs / speed(app) })
            end
            if anchor_xy(app, { mini = ev.who }) then
                anchor = { mini = ev.who }
            end
        elseif p then
            -- Out of character (table talk): their panel lights too, in its own colour.
            panels.light(app, ev.who, secs / speed(app), "ooc")
        end
        -- And their outline at the table, in the same colour (the playtest, November 3).
        if p then
            post("outline", { who = ev.who, color = panels.SPEAK[ev.ic and "ic" or "ooc"].color, time = secs / speed(app) })
        end
        M.bubble(app, anchor, speaker, ev.text, ev.ic)
        M.push(app, speaker .. ": \"" .. ev.text .. "\"", ev.ic and "quote" or "reaction", true)
        review.on_line(app, ev)
    elseif k == "thought" then
        -- What a friend is thinking and not saying (v2, game/model/thoughts.lua): a pale cloud at
        -- their head, and one over their panel to click and answer until the moment passes.
        if ev.glow then
            M.bubble(app, { head = ev.who }, ev.name .. ", thinking", ev.text, false, true)
            M.push(app, ev.name .. ", thinking: \"" .. ev.text .. "\"", "thought", true)
        else
            -- Only the tell shows until you read them (an Insight roll on the card).
            M.bubble(app, { head = ev.who }, ev.name .. " is thinking something", util.capitalize(ev.tell) .. ".", false, true)
            M.push(app, ev.name .. " " .. ev.tell .. ". Something's on " .. ((thoughts.DATA.pronouns[ev.who] or {}).their or "their")
                .. " mind.", "thought", true)
        end
        post("pose", { who = ev.who, pose = "think", hold = true })
        panels.pose(app, ev.who, "think")
        -- Thinking shows on their tile and their outline, in lavender (the playtest, November 3).
        panels.light(app, ev.who, 4 / speed(app), "think")
        post("outline", { who = ev.who, color = panels.SPEAK.think.color, time = 4 / speed(app) })
        if not ev.glow and #(ev.answers or {}) > 0 then
            app.thinking = app.thinking or {}
            app.thinking[ev.who] = ev
            M.draw_thinks(app)
            -- It opens on its own, over their tile (the playtest, November 3: the clouds weren't
            -- obvious to click), with a clock: answer it in time or the moment passes.
            if not app.thought_card then
                M.open_thought(app, ev.who, true)
            end
        end
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
        -- The DM calls the check; the player rolls it (their panel's die tumbles and lands). What they
        -- try is their own line, just before; the numbers are on their panel's die. (A caption
        -- calling the roll stayed up while the result was already showing: the card-led playtest,
        -- October 16, counted five copies of every roll.)
        local total = ev.total or (ev.roll + (ev.bonus or 0))
        M.push(app, ev.text, ev.crit and "good" or (ev.fumble and "bad" or "check"), true)
        post("pose", { who = ev.actor, pose = "think", hold = true })
        panels.pose(app, ev.actor, "think")
        -- They roll it themselves (A9): a quick tumble in their own tray.
        if app.tumble_die then
            app.tumble_die(ev.actor, ev.roll)
        end
        panels.roll(app, ev.actor, { roll = ev.roll, mod = ev.bonus, total = total, against = "DC " .. util.int(ev.dc or 0),
                                     what = ev.skill_name, success = ev.success, crit = ev.crit, fumble = ev.fumble })
        if ev.spot then
            post("walk", { id = ev.actor, path = { ev.spot }, step = 0.3 / speed(app) })
        end
        local label = ev.crit and "Natural 20!" or (ev.fumble and "Natural 1" or (ev.success and "Success" or "Miss"))
        local color = ev.crit and theme.gold or (ev.success and theme.green or theme.red)
        schedule(app, 0.8, function()
            -- The word only: the number is on their panel's die.
            M.float(app, ev.actor, label, color, ev.crit or ev.fumble)
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
            -- The room's own pieces that come alive (the garden's topiary, fight.lua): they lift off
            -- the board as the beasts drop into their squares (the playtest, November 3).
            if ev.wake and #ev.wake > 0 then
                post("lift", { cells = ev.wake })
                for _, cell in ipairs(ev.wake) do
                    post("spark", { x = cell[1], y = cell[2], color = theme.green, size = 1.4 })
                end
            end
            -- The person on the mat who starts this fight becomes its leader's mini where they stand,
            -- not a second one walking off the board (the playtest, November 3: two knights).
            if app.on_table and app.on_table.npc then
                post("remove_now", { id = "npc" })
                app.on_table.npc = nil
            end
            post("stage", { party = party_list(ev.party, app) })
            local list = {}
            app.boss_id = nil
            -- A story villain leads the fight as themselves (Vask, Madame Sable): their own mini.
            local function foe_sprite(f, i)
                local own = f.cast and CAST_SPRITE[f.cast]
                if own and string.sub(own, 1, 4) == "npc_" then
                    return own
                end
                return monster_sprite(f.monster, i)
            end
            app.mini_npc = app.mini_npc or {}
            for i, f in ipairs(ev.foes or {}) do
                app.names[f.id] = f.name
                if f.boss then
                    app.boss_id = f.id
                end
                -- (One of the adventure's people: a click on the mini opens their sheet.)
                local who = (f.cast and require("game.model.npcs").get(f.cast) and f.cast) or npc_for_monster(f.monster)
                if who then
                    app.mini_npc[f.id] = who
                end
                -- one at a time, the way the DM sets the minis out
                table.insert(list, { id = f.id, sprite = foe_sprite(f, i), x = f.x, y = f.y, delay = 0.3 + (i - 1) * 0.12 })
            end
            -- On the party's side (the museum's Steam Mech, v2): a mini beside the heroes.
            app.ally_ids = {}
            for i, a in ipairs(ev.allies or {}) do
                -- (A companion in the fight says who's playing them: "Telpur (Jess)".)
                local pl = a.pilot and app.campaign:player(a.pilot)
                app.names[a.id] = a.name .. (pl and (" (" .. pl.name .. ")") or "")
                table.insert(app.ally_ids, a.id)
                local who = npc_for_monster(a.monster)
                if who then
                    app.mini_npc = app.mini_npc or {}
                    app.mini_npc[a.id] = who
                end
                table.insert(list, { id = a.id, sprite = monster_sprite(a.monster, i), x = a.x, y = a.y, side = "party",
                                     delay = 0.2 + (i - 1) * 0.12 })
            end
            app.on_table = {}
            post("spawn", { list = list })
            battle_hud.start(app, ev.party, ev.foes, foe_sprite)
            for _, a in ipairs(ev.allies or {}) do
                battle_hud.ally(app, a.id, a.name, monster_sprite(a.monster, 1), a.hp, a.hp_max)
            end
            if ev.ambushed then
                M.push(app, "It was an ambush: the party is caught off guard.", "warn")
            end
            M.draw_strip(app)     -- fewer dice while the turn order has the middle
            local n = #(ev.foes or {})
            M.caption(app, "Roll for initiative!  " .. util.int(n) .. (n == 1 and " foe" or " foes")
                .. (ev.danger and ("  (" .. ev.danger .. ")") or ""), "warn")
            M.push(app, "A fight! " .. util.int(n) .. (n == 1 and " foe" or " foes") .. (ev.danger and (", " .. ev.danger) or "")
                .. (ev.srd and (". SRD says " .. ev.srd) or "") .. ".", "warn", true)
            M.refresh_hp(app)
            cam(app, 2)
        else
            app.in_battle = false
            battle_hud.stop(app)
            for id in pairs(app.ds or {}) do
                M.drop_dying(app, id, true)       -- (the fight's over: whoever's down is seen to)
            end
            app.ds = nil
            post("clear", { side = "foe", how = "flee" })
            for _, id in ipairs(app.ally_ids or {}) do
                post("flee", { id = id })
            end
            app.ally_ids = nil
            for id in pairs(app.hp) do
                post("up", { id = id })
            end
            app.boss_id = nil
            M.refresh_hp(app)
            local won = ev.winner == "party"
            local how = ev.summary and ev.summary.how
            M.caption(app, (how == "fled" and "The foes break and run. The fight is over.")
                or (how == "escaped" and "The boss gets away. The fight is over.")
                or (won and "The fight is over. The party stands.") or "The party falls back.", won and "good" or "bad")
            if ev.summary then
                M.fight_card(app, ev.summary)
            end
            M.draw_strip(app)     -- (the full row of dice again, now the turn order's gone)
            cam(app, 2)
        end
    elseif k == "round" then
        if (ev.round or 1) > 1 then
            M.push(app, "Round " .. util.int(ev.round), "system")
        end
        battle_hud.round(app, ev.round or 1)
        -- Fights stay on the mat (A7).
        app.battle_cam = 2
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
            M.push(app, name .. ": \"" .. say.text .. "\"", say.ic and "quote" or "reaction", true)
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
            M.push(app, p.name .. " rolls " .. (ev.skill_name or "the check") .. ".", "dice", true)
            post("pose", { who = p.key, pose = "lean", hold = true })
            panels.pose(app, p.key, "lean")
        else
            M.caption(app, ev.where == "open" and "You roll the d20 where everyone can see it..." or "You roll the d20 behind your screen...", "dice")
            M.push(app, ev.where == "open" and "You roll in the open." or "You roll behind the screen.", "dice", true)
        end
        -- Into the right tray (A9): theirs at their seat, or yours, in the open or behind the screen.
        local tray = (ev.by == "player" and p) and p.key or (ev.where == "hidden" and "dm_hidden" or "dm_open")
        app.roll_tray = tray
        app.roll_dice(tray)
        cam(app, 4)
    elseif k == "done" then
        app.night_done = true
        app.thinking = nil
        M.close_thought(app)
        M.draw_thinks(app)
        recap_view.close(app)
        post("track", { on = false })
        M.clear_fx(app)
        cam(app, 1)
        M.show_done(app)
    elseif k == "decision" or k == "ruling" or k == "roll_where" then
        if k == "ruling" and ev.tier then
            -- The big roll's die in the strip takes its colour now it's decided.
            for i = #app.strip, 1, -1 do
                local d = app.strip[i]
                if d.big then
                    if d.success == nil then
                        d.success = ev.tier == "success" or ev.tier == "triumph"
                        -- A reroll (Heroic Inspiration, an item's Advantage) is the roll that counts
                        -- (the lore playtest, October 16: the strip kept the 8 the text said became a 6).
                        if ev.value and not d.hidden then
                            d.roll = ev.value
                        end
                        M.draw_strip(app)
                    end
                    break
                end
            end
        end
        if k == "ruling" and ev.by ~= "dm" and ev.actor then
            -- A DC behind the screen stays there on their card (playtest, October 13): the table
            -- sees the roll, not the number it had to beat.
            panels.roll(app, ev.actor, { roll = ev.value, mod = ev.mod, total = ev.total, what = ev.skill_name,
                                         against = ev.where == "hidden" and "DC ?" or ("DC " .. util.int(ev.dc or 0)),
                                         success = ev.tier == "success" or ev.tier == "triumph",
                                         crit = ev.value == 20, fumble = ev.value == 1 })
        end
        app.pending = ev
        app.pending_left = app.timer_on and TIMERS[k] or nil
        if k == "decision" and ev.card and ev.card.turn_of and app.in_battle then
            battle_hud.turn(app, ev.card.turn_of)
        end
        M.clear_fx(app)
        if k == "decision" then
            cam(app, app.in_battle and 2 or 1)   -- a card mid-fight keeps the mat in view (A7)
        else
            -- The DC card looks at the tray the die is about to go into (A9).
            if k == "roll_where" and app.set_tray then
                app.set_tray((ev.by ~= "dm" and ev.actor) or "dm_open")
            end
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
        -- Out loud, everyone knows at once whether it made it; behind the screen, the ruling says.
        local known = ev and ev.by == "player" and ev.where == "open" and ev.dc
        M.add_die(app, { roll = value, big = true, hidden = ev and ev.by == "dm" and ev.where == "hidden",
                         success = known and (value + (ev.mod or 0) >= ev.dc) or nil })
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
    -- A big roll's DC card and its ruling read as one card (A11).
    app.roll_card_up = ev and ev.kind == "roll_where" or nil
    M.close_modal(app)
    if ev and (ev.kind == "decision" or ev.kind == "ruling") then
        rest_cam(app)
    end
    M.step(app, value)
end

-- The opening (museum_night.intro) ------------------------------------------------------------
-- The DM setting up the adventure, a card at a time, with the table behind it.

local function lore_icon(x, y, size, row)
    if row.face then
        kit.dot(x + size / 2, y + size / 2, size, panels.COLORS[row.face] or theme.panel3)
        kit.picture(x + 2, y + 2, size - 4, size - 4, panels.face(row.face))
    else
        local col = row.color and kit.rgba(row.color) or theme.gold
        kit.dot(x + size / 2, y + size / 2, size, alpha_of(col, 0.25))
        kit.icon(x + size * 0.18, y + size * 0.18, size * 0.64, row.icon or "story", col)
    end
end

function M.show_cinematic(app, ev)
    M.close_modal(app)
    M.clear_fx(app)
    app.layers.modal = kit.layer("night_modal", true)
    app.layers.modal.pass = M.PASS     -- (the top bar works while a call waits)
    local slides = ev.slides or {}
    local i = util.clamp(app.cine_i or 1, 1, math.max(1, #slides))
    local sl = slides[i] or {}
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#0c0806", 0.62), { round = false })
    local w, h = 980, 560
    local x, y = (kit.W - w) / 2, math.max(64, math.min(150, 760 - h))
    kit.box(x - 3, y - 3, w + 6, h + 6, sl.color and kit.rgba(sl.color) or theme.gold, { radius = 15 })
    kit.box(x, y, w, h, theme.paper, { radius = 13 })
    -- Buttons first: the first one is the way on (number keys and the test drivers press it).
    local last = i >= #slides
    kit.button(x + w - 236, y + h - 64, 210, 44, last and "Introductions  >" or "Continue  >", function()
        M.cinematic_next(app)
    end, { color = theme.go, hover = theme.go_hover, key = "cine_next" })
    if not last then
        kit.button(x + 26, y + h - 58, 150, 32, "Skip the opening", function()
            app.cine_i = #slides
            M.cinematic_next(app)
        end, { font = "ui14", color = theme.panel3, key = "cine_skip" })
    end
    -- Which card of how many.
    for k = 1, #slides do
        kit.dot(x + w / 2 - (#slides - 1) * 12 + (k - 1) * 24, y + h - 42, k == i and 14 or 10,
            k == i and theme.ink or kit.rgba("#8a7a62"))
    end
    lore_icon(x + 50, y + 70, 180, sl)
    kit.text(x + 280, y + 64, sl.kicker or "", "ui18b", kit.rgba("#8a5a20"))
    kit.text(x + 280, y + 94, sl.title or "", "title30", theme.ink, { w = w - 320, lines = 2 })
    kit.text(x + 280, y + 152, sl.text or "", "read26", theme.ink, { w = w - 330 })
    if sl.footer then
        kit.text(x + w / 2, y + h - 108, sl.footer, "story22", kit.rgba("#8a5a20"), { pivot = gui.PIVOT_N })
    end
end

-- The next card, or back to the table after the last one.
function M.cinematic_next(app)
    local ev = app.pending
    if not (ev and ev.kind == "cinematic") then
        return
    end
    app.cine_i = (app.cine_i or 1) + 1
    if app.cine_i > #(ev.slides or {}) then
        app.cine_i = nil
        M.answer(app, true)
    else
        M.show_cinematic(app, ev)
    end
end

-- Number keys pick a card's options (the fix pass): 1 to 4 on any card. A fallback that works even
-- when a click doesn't.
function M.pick_key(app, n)
    if app.thought_card then
        local fn = M.thought_buttons(app)[n]
        if fn then
            fn()
            return true
        end
        return false
    end
    local ev = app.pending
    if not ev then
        return false
    end
    if ev.kind == "cinematic" then
        M.cinematic_next(app)
        return true
    elseif ev.kind == "decision" then
        if ev.card and ev.card.options[n] and not ev.card.options[n].disabled then
            M.answer(app, n)
            return true
        end
    elseif ev.kind == "ruling" then
        if ev.options and ev.options[n] then
            M.answer(app, n)
            return true
        elseif ev.cook and ev.options and n == #ev.options + 1 then
            M.answer(app, "cook")
            return true
        end
    elseif ev.kind == "roll_where" then
        if n == 1 or n == 2 then
            M.answer(app, n == 1 and "open" or "hidden")
            return true
        elseif n == 3 and ev.by ~= "dm" then
            M.answer(app, "dc:" .. util.int(app.dc_pick_for == ev and app.dc_pick or ev.dc or 15))
            return true
        end
    end
    return false
end

-- What the friends think and don't say (v2) ------------------------------------------------------
-- A cloud over a friend's panel while their thought can still be answered; click it for the card:
-- the thought, what's behind it, and two things you could do (or let it be). The table waits while
-- the card is open.

function M.draw_thinks(app)
    if app.layers.thinks then
        kit.drop(app.layers.thinks)
    end
    app.layers.thinks = kit.layer("night_thinks", false, true)
    kit.into(app.layers.thinks, function()
        for _, p in ipairs(app.campaign.players) do
            local ev = app.thinking and app.thinking[p.key]
            local chip = app.chips and app.chips[p.key]
            if ev and chip then
                local label = "Thinking..."
                local w = kit.width(label, "ui14") + 44
                local x, y = chip.x + 8, chip.y - 30
                kit.button(x, y, w, 24, "", function()
                    M.open_thought(app, p.key)
                end, { color = theme.think.bg, hover = theme.think.hover, radius = 12, key = "thought_" .. p.key })
                kit.dot(x + 13, y + 15, 9, theme.think.dim)
                kit.dot(x + 21, y + 8, 5, theme.think.dim)
                kit.text(x + 30, y + 4, label, "ui14", theme.think.ink)
            end
        end
    end)
end

-- Clouds whose moment has gone (the scene moved on, or what it was about happened).
function M.prune_thinks(app)
    if not app.thinking then
        return
    end
    local changed = false
    for key, ev in pairs(app.thinking) do
        if not thoughts.is_open(app.night, ev.id) then
            app.thinking[key] = nil
            changed = true
        end
    end
    if changed then
        M.draw_thinks(app)
    end
end

-- The top bar's buttons that keep working while a call or a thought waits on you: you can look
-- things up before you decide (the playtest, November 3).
M.PASS = { night_story = true, night_notes = true, night_maps = true, night_table = true, night_log = true, night_end = true,
           night_pause = true, night_speed_1x = true, night_speed_2x = true, night_speed_4x = true, night_crits = true }
for _, k in ipairs(content.players.order) do
    M.PASS["inspire_" .. k] = true      -- (the token from a tile, while a call waits)
end

-- How long an open thought waits for you (the playtest, November 3: "a countdown of maybe 30
-- seconds to be resolved, or they auto dismiss"). Real seconds; anything you do restarts it.
M.THOUGHT_WAIT = 30

function M.open_thought(app, key, auto)
    local ev = app.thinking and app.thinking[key]
    if not ev then
        return
    end
    if not thoughts.is_open(app.night, ev.id) then
        app.thinking[key] = nil
        M.draw_thinks(app)
        M.toast(app, "THAT MOMENT PASSED", ev.name .. "'s thought has moved on. There'll be others.")
        return
    end
    app.thought_card = ev
    app.thought_left = M.THOUGHT_WAIT
    M.draw_thought_card(app)
end

function M.close_thought(app)
    if app.layers.thought then
        kit.drop(app.layers.thought)
        app.layers.thought = nil
    end
    app.thought_card = nil
    app.thought_left = nil
    kit.reset_hover()
end

-- Every frame: the open thought's clock. At zero you've let it be, and the moment passes.
function M.tick_thought(app, dt)
    if not (app.thought_card and app.thought_left) then
        return
    end
    app.thought_left = app.thought_left - dt
    local bar = app.thought_bar
    if bar then
        local f = math.max(0, app.thought_left / M.THOUGHT_WAIT)
        pcall(kit.set_bar, bar.fill, bar.w, f, 1)
        pcall(gui.set_text, bar.text, util.int(math.max(0, math.ceil(app.thought_left))) .. "s")
        pcall(gui.set_color, bar.fill, f > 0.33 and theme.think.ink or theme.orange)
    end
    if app.thought_left <= 0 then
        local ev = app.thought_card
        M.answer_thought(app, "let_be")
        if ev then
            M.toast(app, "THE MOMENT PASSED", ev.name .. "'s thought went unanswered. There'll be others.")
        end
    end
end

-- The card's buttons in order, for the number keys: { { key, fn } }.
local function thought_buttons(app)
    local ev = app.thought_card
    local t = ev and app.night.th and app.night.th.list[ev.id]
    local out = {}
    if not t then
        return out
    end
    if not t.read then
        table.insert(out, function() M.read_thought(app) end)
    elseif t.read.result == "miss" then
        table.insert(out, function() M.ask_thought(app) end)
    else
        for _, a in ipairs(thoughts.answers_for(app.night, ev.id)) do
            table.insert(out, function() M.answer_thought(app, a.id) end)
        end
    end
    table.insert(out, function() M.answer_thought(app, "let_be") end)
    return out
end
M.thought_buttons = thought_buttons

-- Before you read them: what you can see across the table, and your odds. After: the roll, and what
-- you got from it (the words, the gist, nothing, or, on a 1, the wrong idea).
function M.draw_thought_card(app)
    local ev = app.thought_card
    if app.layers.thought then
        kit.drop(app.layers.thought)
    end
    app.layers.thought = kit.layer("night_thought", true)
    app.layers.thought.pass = M.PASS
    local night = app.night
    local t = night.th and night.th.list[ev.id]
    local r = t and t.read
    local pr = thoughts.DATA.pronouns[ev.who] or { them = "them", their = "their" }
    -- Over their own tile (the playtest, November 3), kept on the screen.
    local w = 500
    local chip = app.chips and app.chips[ev.who]
    local x = chip and util.clamp(chip.x + panels.W / 2 - w / 2, 8, kit.W - w - 8) or LEFT_X
    local tw = w - 32
    local o = thoughts.odds(night, ev.id) or { bonus = 0, need = 11, chance = 0.5, empathy = 0, familiar = 0, known = "" }
    -- What goes on the card, top to bottom: { text, font, color } blocks, then the buttons.
    local blocks = {}
    local function add(text, font, color, gap)
        table.insert(blocks, { text = text, font = font, color = color, gap = gap or 10 })
    end
    local title, sub
    local buttons = {}
    if not r then
        title = "Something's on " .. ev.name .. "'s mind"
        sub = "You catch it across the table."
        add(util.capitalize(ev.name .. " " .. ev.tell .. "."), "ui22b", theme.think.ink)
        add("Read " .. pr.them .. ": an Insight roll, d20 + " .. util.int(o.bonus) .. " (your Empathy +" .. util.int(o.empathy)
            .. ", you know " .. ev.name .. " +" .. util.int(o.familiar) .. ((o.rested or 0) > 0 and ", a good night's sleep +1" or "")
            .. "). You need " .. util.int(o.need)
            .. " or more: about " .. util.int(math.floor(o.chance * 100 + 0.5)) .. "%.", "ui18", theme.think.dim)
        table.insert(buttons, { label = "Read " .. pr.them .. " (roll Insight)", key = "thought_read", go = true })
        -- The first time: you have stats too, and where to find them (the playtest, November 3).
        local seen = app.campaign.seen_tips or {}
        if not seen.dm_stats then
            add("You have stats too. Empathy is how well you read a table; each friend also has how well you know them. "
                .. "A read is an Insight roll: d20 + your Empathy + how well you know them. Both grow as you play. "
                .. "Your Empathy is at the top of THE TABLE on the prep board, how well you know each friend is the dots "
                .. "on their card, and the Table sidebar tonight (S) has both.", "ui14", theme.think.ink, 12)
        end
    else
        title = ev.name .. (r.result == "miss" and " is hard to read" or " is thinking")
        local reads = thoughts.DATA.reads
        local line = (r.result == "asked" and reads.asked) or (r.roll == 20 and reads.book) or reads[r.result] or ""
        sub = "You rolled " .. util.int(r.roll) .. " + " .. util.int(r.bonus) .. " = " .. util.int(r.total) .. ", needing "
            .. util.int(r.need or r.dc) .. "."
        add(util.fill(line, { name = ev.name }), "ui18b", theme.think.dim)
        local sn = thoughts.seen(night, ev.id)
        if sn and sn.words then
            add("\"" .. ev.text .. "\"", "ui22b", theme.think.ink)
        end
        local want = thoughts.want_of(night, ev.id)
        if want then
            add(want .. ".", "ui18", theme.think.ink)
        end
        if r.result == "miss" then
            add(util.capitalize(ev.name .. " " .. ev.tell .. ", and that's all you can tell."), "ui18", theme.think.ink)
            local a = thoughts.DATA.ask_straight
            table.insert(buttons, { label = util.sentence_case(util.fill(a.label, { them = pr.them })), key = "thought_ask", go = true })
        else
            for i, a in ipairs(thoughts.answers_for(night, ev.id)) do
                table.insert(buttons, { label = a.label, key = "thought_ans_" .. i, aid = a.id })
            end
        end
    end
    table.insert(buttons, { label = "Let it be", key = "thought_let", aid = "let_be", plain = true })
    -- How well you know them, and your Empathy: why the odds are what they are.
    local fam = require "game.model.familiar"
    local fl, fmax = fam.dots(app.campaign, ev.who)
    local level = app.campaign:empathy()
    local foot = "You know " .. ev.name .. ": " .. string.lower(fam.name(app.campaign, ev.who)) .. ". Empathy: "
        .. string.lower(empathy.NAMES[level] or "") .. ". Both grow as you read them and play together."
    local foot_h = kit.text_height(foot, "ui14", tw - 70)
    local h = 16 + 60 + 12
    for _, b in ipairs(blocks) do
        h = h + kit.text_height(b.text, b.font, tw) + b.gap
    end
    h = h + 8 + #buttons * 48 + 44 + foot_h + 14
    local y = math.max(76, CHIP_Y - 40 - h)
    kit.box(x - 3, y - 3, w + 6, h + 6, kit.rgba("#000000", 0.35), { radius = 16 })
    kit.box(x, y, w, h, theme.think.bg, { radius = 14 })
    kit.dot(x + 44, y + 46, 64, alpha_of(panels.COLORS[ev.who] or theme.gold, 0.6))
    kit.picture(x + 12, y + 14, 64, 64, panels.face(ev.who, "think"), kit.rgba("#ffffff"))
    kit.text(x + 90, y + 18, title, "ui22b", theme.think.ink, { w = w - 106, lines = 1 })
    kit.text(x + 90, y + 48, sub, "ui14", theme.think.dim, { w = w - 106, lines = 1 })
    -- The die you rolled, top right.
    if r then
        local col = (r.result == "clear" or r.result == "asked" or r.roll == 20) and theme.green
            or (r.result == "gist" or r.result == "misread") and theme.gold or theme.red
        kit.icon(x + w - 58, y + 12, 44, "d20", col)
        kit.text(x + w - 36, y + 34, util.int(r.roll), "ui18b", theme.bg, { pivot = gui.PIVOT_CENTER })
    end
    local ty = y + 16 + 60 + 12
    for _, b in ipairs(blocks) do
        kit.text(x + 16, ty, b.text, b.font, b.color, { w = tw })
        ty = ty + kit.text_height(b.text, b.font, tw) + b.gap
    end
    ty = ty + 8
    for i, b in ipairs(buttons) do
        kit.button(x + 16, ty, tw, 40, b.label, function()
            if b.key == "thought_read" then
                M.read_thought(app)
            elseif b.key == "thought_ask" then
                M.ask_thought(app)
            else
                M.answer_thought(app, b.aid)
            end
        end, { key = b.key, key_hint = i, color = b.go and theme.go or (b.plain and theme.panel2 or nil),
               hover = b.go and theme.go_hover or nil })
        ty = ty + 48
    end
    kit.button(x + w - 136, ty, 120, 32, "Not now", function()
        M.close_thought(app)
    end, { key = "thought_close", color = theme.think.dim })
    -- The clock: how long the moment waits for you.
    if app.thought_left then
        local bw = w - 190
        kit.box(x + 16, ty + 12, bw, 8, alpha_of(theme.think.dim, 0.3), { round = false })
        local fill = kit.box(x + 16, ty + 12, bw, 8, theme.think.ink, { round = false })
        local text = kit.text(x + 22 + bw, ty + 6, "", "ui14", theme.think.dim, { gloss = false })
        app.thought_bar = { fill = fill, w = bw, text = text }
        kit.set_bar(fill, bw, math.max(0, app.thought_left / M.THOUGHT_WAIT), 1)
        gui.set_text(text, util.int(math.ceil(app.thought_left)) .. "s")
    end
    -- Familiarity as dots, then the words.
    for i = 1, fmax do
        kit.dot(x + 24 + (i - 1) * 13, ty + 50, 9, i <= fl and theme.think.ink or alpha_of(theme.think.dim, 0.35))
    end
    kit.text(x + 86, ty + 42, foot, "ui14", theme.think.dim, { w = tw - 70 })
end

function M.read_thought(app)
    local ev = app.thought_card
    if not ev then
        return
    end
    app.campaign.seen_tips = app.campaign.seen_tips or {}
    app.campaign.seen_tips.dm_stats = true
    app.thought_left = M.THOUGHT_WAIT
    local r = thoughts.read(app.night, ev.id)
    if not r then
        M.close_thought(app)
        if app.thinking then
            app.thinking[ev.who] = nil
        end
        M.draw_thinks(app)
        M.toast(app, "THAT MOMENT PASSED", ev.name .. "'s thought has moved on. There'll be others.")
        return
    end
    M.push(app, "You read " .. ev.name .. ": " .. util.int(r.roll) .. " + " .. util.int(r.bonus) .. " = " .. util.int(r.total)
        .. " (needed " .. util.int(r.need or r.dc) .. ").", "aside", true)
    local sn = thoughts.seen(app.night, ev.id)
    if sn and sn.words then
        M.push(app, ev.name .. ", thinking: \"" .. ev.text .. "\"", "thought", true)
    end
    M.draw_thought_card(app)
end

function M.ask_thought(app)
    local ev = app.thought_card
    if not ev then
        return
    end
    if thoughts.ask(app.night, ev.id) then
        M.push(app, ev.name .. ", when you ask: \"" .. ev.text .. "\"", "thought", true)
    end
    app.thought_left = M.THOUGHT_WAIT
    M.draw_thought_card(app)
end

function M.answer_thought(app, aid)
    local ev = app.thought_card
    M.close_thought(app)
    if not ev then
        return
    end
    local ok = thoughts.respond(app.night, ev.id, aid)
    if app.thinking then
        app.thinking[ev.who] = nil
    end
    M.draw_thinks(app)
    if not ok then
        M.toast(app, "THAT MOMENT PASSED", ev.name .. "'s thought has moved on. There'll be others.")
        return
    end
    if aid ~= "let_be" then
        app.thought_answered = true
    end
    M.refresh_chips(app)
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
    kit.set_bar(tb.fill, tb.w, left, tb.total)
    gui.set_text(tb.label, "Timer (T): " .. util.int(math.ceil(left)) .. "s, then " .. tb.what)
end

local function card_y(h)
    return math.max(76, math.min(420 - h / 2, CARD_BOTTOM - h))
end

-- The log stays out of the way (A11): with it open, the left-hand cards dock beside it rather
-- than over it.
local function left_x(app)
    return app.log_open and (LOG_X + LOG_W + 16) or LEFT_X
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
        place_caption(c, r.x, r.y, r.w, r.h)
    else
        c.life = 0
        app.caption_rect = nil
        for _, n in ipairs({ c.box, c.rule, c.tag, c.text, c.voice_bg, c.voice }) do
            gui.set_enabled(n, false)
        end
        c.voice_on = false
    end
end

function M.show_modal(app, ev, instant)
    -- A cinematic draws itself (October 20: Tab for the log, or a rebuild, during the opening
    -- redrew it as an empty card, and the night waited on a card that wasn't there).
    if ev.kind == "cinematic" then
        return M.show_cinematic(app, ev)
    end
    kit.gloss_scope({ table = true, fight = true }, function()
        M.draw_modal(app, ev, instant)
    end)
end

function M.draw_modal(app, ev, instant)
    M.close_modal(app)
    app.layers.modal = kit.layer("night_modal", true)
    app.layers.modal.pass = M.PASS     -- (the top bar works while a call waits)
    if ev.kind == "decision" then
        dodge_caption(app, 16, RIGHT_X - 16)
    elseif ev.kind == "ruling" or ev.kind == "roll_where" then
        dodge_caption(app, left_x(app) + LEFT_W + 16, kit.W - 16)
    end
    local slide = 0
    if ev.kind == "decision" and ev.card and ev.card.intermission then
        -- The break (museum_night.maybe_break): the whole table gets up. A dimmed room and a banner,
        -- so it reads as a pause in the evening, not one more call.
        kit.box(0, 58, kit.W, kit.H - 58, kit.rgba("#000000", 0.42), { round = false })
        local bx, by, bw, bh = 120, 190, 780, 150
        kit.box(bx - 2, by - 2, bw + 4, bh + 4, theme.gold, { radius = 16 })
        kit.box(bx, by, bw, bh, kit.rgba("#201813", 0.97), { radius = 15 })
        kit.icon(bx + 28, by + 40, 72, "hourglass", theme.gold)
        kit.text(bx + 124, by + 26, "INTERMISSION", "ui14", theme.gold)
        kit.text(bx + 124, by + 48, "Back in twenty minutes.", "read26", theme.text, { gloss = false })
        kit.text(bx + 124, by + 92, "The table gets up, stretches, and argues about pizza toppings. Pick what, if anything, "
            .. "happens in the game while they're away.", "ui18", theme.dim, { w = bw - 150, gloss = false })
    end
    if ev.kind == "decision" then
        local x, w = RIGHT_X, RIGHT_W
        local card = ev.card
        -- Taking over (B8): the one you're speaking or acting for, as their paper mini.
        local portrait = (card.cast and CAST_SPRITE[card.cast]) or (card.monster and monster_sprite(card.monster, 1)) or nil
        -- A friend's own moment (a card's `who`): their face, top right.
        local face = card.who and panels.face(card.who)
        local tw = (portrait or face) and (w - 120) or (w - 40)
        local title_h = math.max(math.min(80, kit.text_height(card.title, "title30", tw)), portrait and 40 or 0)
        local text_h = kit.text_height(card.text, "ui18", w - 40)
        -- Who's in this call, at a glance (the playtest, November 3: portraits beside the names, so a
        -- card is skimmable): its lead first, then anyone else it names.
        local who = M.people_in(app, ev.actor, { card.title, card.text })
        local who_h = #who > 0 and 46 or 0
        -- How bad it could get, on a fight's call (the newcomer playtest, October 16).
        local danger_h = card.danger and (kit.text_height(card.danger, "ui18", w - 64) + 16) or 0
        -- What you agreed at Session Zero, on the call it's about.
        local promise_h = card.promise and (kit.text_height(card.promise, "ui14", w - 40) + 8) or 0
        local labels, h = {}, 62 + title_h + 12 + who_h + text_h + 18 + (danger_h > 0 and (danger_h + 10) or 0) + promise_h
        local lean_h = {}
        local sub_h = {}
        for i, o in ipairs(card.options) do
            labels[i] = o.label .. (o.roll and ("  (" .. (o.skill or "d20") .. " check)") or "")
                .. (o.cooked and "  (overrules the die)" or "") .. (o.promise and "  (as agreed)" or "")
            lean_h[i] = (o.leans and next(o.leans)) and 30 or 0
            -- What an answer costs and gives, under it.
            sub_h[i] = o.sub and (kit.text_height(o.sub, "ui14", w - 68 - KEY_PAD) + 4) or 0
            h = h + option_height(labels[i], w - 40) + lean_h[i] + sub_h[i] + 10
        end
        h = h + 10 + (app.pending_left and 34 or 0)
        local y = card_y(h)
        kit.box(x, y, w, h, theme.paper, { radius = 12 })
        badge(x + 20, y + 18, string.upper(card.type_name or "Call"), theme.decision[card.type] or theme.panel3)
        kit.text(x + 20, y + 52, card.title, "title30", theme.ink, { w = tw, lines = 2 })
        if portrait then
            kit.picture(x + w - 86, y + 10, 64, 80, "mini_" .. portrait)
        elseif face then
            kit.dot(x + w - 54, y + 46, 70, panels.COLORS[card.who] or theme.panel3)
            kit.picture(x + w - 86, y + 14, 64, 64, face)
        end
        if who_h > 0 then
            M.people_strip(app, x + 20, y + 58 + title_h, w - 40, who)
        end
        kit.text(x + 20, y + 62 + title_h + who_h, card.text, "ui18", theme.ink, { w = w - 40 })
        local oy = y + 62 + title_h + who_h + 12 + text_h + 8
        if promise_h > 0 then
            kit.text(x + 20, oy - 4, card.promise, "ui14", theme.ink_dim, { w = w - 40 })
            oy = oy + promise_h
        end
        if danger_h > 0 then
            kit.box(x + 20, oy, w - 40, danger_h, kit.rgba("#b0473a", 0.14), { radius = 8 })
            kit.text(x + 32, oy + 8, card.danger, "ui18", kit.rgba("#8a2e22"), { w = w - 64 })
            oy = oy + danger_h + 10
        end
        for i, label in ipairs(labels) do
            local oh = option_height(label, w - 40) + lean_h[i] + sub_h[i]
            local opt = card.options[i]
            kit.button(x + 20, oy, w - 40, oh, label, function()
                M.answer(app, i)
            end, { align = "left", color = opt.cooked and theme.decision.screen or theme.button,
                   hover = theme.button_hover, key_hint = i, enabled = not opt.disabled })
            if sub_h[i] > 0 then
                local ly = oy + 10 + kit.text_height(label, "ui18b", w - 68 - KEY_PAD)
                kit.text(x + 34, ly, opt.sub, "ui14", opt.disabled and kit.rgba("#8a7c6a")
                    or (opt.sub_tone and theme[opt.sub_tone]) or theme.dim,
                    { w = w - 68 - KEY_PAD })
            end
            if lean_h[i] > 0 then
                M.draw_leans(app, x + 34, oy + oh - 32, opt.leans)
            end
            oy = oy + oh + 10
        end
        timer_bar(app, x + 20, oy + 2, w - 40, "the first option")
        slide = 640
    elseif ev.kind == "ruling" then
        local x, w = left_x(app), LEFT_W
        -- The die's on this card now: "Mara rolls the d20..." has had its moment (the second card-led
        -- playtest, October 17: the roll was on five things at once).
        local cap = app.caption
        if cap and cap.style == "dice" and (cap.life or 0) > 0 then
            cap.age = math.max(cap.age or 0, cap.life)
        end
        local prompt_h = kit.text_height(ev.prompt or "", "ui18", w - 40)
        local total = ev.total or ev.value or 0
        local shown
        if ev.by ~= "dm" then
            local mod = ev.mod or 0
            shown = (ev.char or "They") .. " rolled " .. util.int(ev.value or 0) .. (mod < 0 and " - " or " + ") .. util.int(math.abs(mod))
                .. " = " .. util.int(total) .. (ev.skill_name and (" " .. ev.skill_name) or "") .. " against DC " .. util.int(ev.dc or 0) .. "."
        else
            shown = (ev.where == "hidden" and "Behind the screen: " or "On the table: ") .. "the die says "
                .. util.int(ev.value or 0) .. " (" .. util.int(total) .. "), DC " .. util.int(ev.dc or 0) .. "."
        end
        -- One card per big roll (A11): behind the screen, overruling the die is this card's last
        -- button, not a card of its own.
        if ev.where == "hidden" then
            shown = shown .. " Only you know it."
            if (ev.cooks or 0) > 0 then
                shown = shown .. " You've cooked " .. util.int(ev.cooks) .. (ev.cooks == 1 and " roll" or " rolls") .. " tonight."
            end
        end
        -- The scene's final roll stays the final roll, for its goal, on the card that rules on it.
        if ev.final and ev.final.goal then
            shown = "The scene's final roll: " .. ev.final.goal .. ". " .. shown
        end
        local shown_h = kit.text_height(shown, "ui18b", w - 40)
        local labels, h = {}, 106 + shown_h + prompt_h + 34
        for i, o in ipairs(ev.options) do
            labels[i] = o.label
            h = h + option_height(o.label, w - 40) + 10
        end
        local cook_label = ev.cook and (ev.cook.label .. "\n" .. ev.cook.note)
        if cook_label then
            h = h + 58 + 10
        end
        h = h + 10 + 22 + (app.pending_left and 34 or 0)
        local y = card_y(h)
        kit.box(x, y, w, h, theme.paper, { radius = 12 })
        badge(x + 20, y + 18, ev.by == "dm" and "SECRET CHECK" or (ev.final and "THE SCENE'S FINAL ROLL" or "BIG ROLL"),
            theme.decision.screen)
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
            kit.box(x + 20, oy, 6, oh, (TONES[tone or "plain"] or TONES.plain)[1], { round = false })
            oy = oy + oh + 10
        end
        if cook_label then
            kit.button(x + 20, oy, w - 40, 58, cook_label, function()
                M.answer(app, "cook")
            end, { align = "left", pad_y = 8, color = theme.decision.screen, hover = theme.button_hover,
                   key_hint = #labels + 1, key = "ruling_cook" })
            oy = oy + 58 + 10
        end
        -- What the stripes are (the newcomer playtest, October 16): the ones on this card.
        local lx = x + 20
        local here = {}
        for _, o in ipairs(ev.options) do
            here[TONES[o.tone or "plain"] and (o.tone or "plain") or "plain"] = true
        end
        for _, tone in ipairs(TONE_ORDER) do
            if here[tone] then
                local st = TONES[tone]
                kit.box(lx, oy + 4, 6, 14, st[1], { round = false })
                kit.text(lx + 12, oy + 1, st[2], "ui14", theme.ink_dim)
                lx = lx + 12 + kit.width(st[2], "ui14") + 18
            end
        end
        oy = oy + 22
        timer_bar(app, x + 20, oy + 2, w - 40, "the first option")
        -- The same card as the DC it follows: it turns over in place rather than sliding in again.
        slide = app.roll_card_up and 0 or -640
    elseif ev.kind == "roll_where" then
        local x, w = left_x(app), LEFT_W
        local text_h = kit.text_height(ev.text or "", "ui18", w - 40)
        local promise_h = ev.promise and (kit.text_height(ev.promise, "ui14", w - 40) + 8) or 0
        local player_roll = ev.by ~= "dm"
        local h = 110 + text_h + promise_h + 136 + (player_roll and 78 or 0) + 10 + (app.pending_left and 34 or 0)
        local y = card_y(h)
        kit.box(x, y, w, h, theme.paper, { radius = 12 })
        badge(x + 20, y + 18, player_roll and (ev.final and "THE SCENE'S FINAL ROLL" or "BIG ROLL") or "SECRET CHECK",
            theme.decision.screen)
        kit.text(x + 20, y + 52, player_roll and "Set the DC" or "Where do you roll it?", "title30", theme.ink)
        kit.text(x + 20, y + 96, ev.text or "", "ui18", theme.ink, { w = w - 40 })
        if ev.promise then
            kit.text(x + 20, y + 102 + text_h, ev.promise, "ui14", theme.ink_dim, { w = w - 40 })
        end
        local oy = y + 110 + text_h + promise_h
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
        -- Or your own DC, said out loud (the playtest, November 3): the book's suggestion is only that.
        if player_roll then
            M.draw_dc_pick(app, ev, x + 20, oy + 136, w - 40)
            oy = oy + 78
        end
        timer_bar(app, x + 20, oy + 136, w - 40, "in the open")
        slide = -640
    end
    M.trace_card(app, ev)   -- before the slide, so the trace has where the buttons come to rest
    if not instant and slide ~= 0 then
        slide_in(app.layers.modal, slide)
    end
end

-- The DC ladder (SRD 5.2.1, "Difficulty Class"): what a number means at the table.
local DC_WORDS = { { 5, "Very easy" }, { 10, "Easy" }, { 15, "Medium" }, { 20, "Hard" }, { 25, "Very hard" }, { 30, "Nearly impossible" } }
local function dc_word(n)
    local best = DC_WORDS[1][2]
    for _, d in ipairs(DC_WORDS) do
        if n >= d[1] - 2 then
            best = d[2]
        end
    end
    return best
end

-- Pick it yourself: a number you choose, said out loud, with what it means beside it.
function M.draw_dc_pick(app, ev, x, y, w)
    app.dc_pick = app.dc_pick_for == ev and app.dc_pick or (ev.dc or 15)
    app.dc_pick_for = ev
    local n = app.dc_pick
    kit.box(x, y, w, 68, kit.rgba("#000000", 0.08), { radius = 10 })
    kit.text(x + 14, y + 8, "Or set your own DC, out loud:", "ui14", theme.ink_dim)
    kit.button(x + 14, y + 28, 32, 32, "-", function()
        app.dc_pick = math.max(2, n - 1)
        M.show_modal(app, app.pending, true)
    end, { key = "dc_minus" })
    kit.text(x + 62, y + 30, "DC " .. util.int(n), "ui22b", theme.ink, { gloss = false })
    kit.button(x + 128, y + 28, 32, 32, "+", function()
        app.dc_pick = math.min(30, n + 1)
        M.show_modal(app, app.pending, true)
    end, { key = "dc_plus" })
    kit.text(x + 172, y + 36, dc_word(n) .. (n == ev.dc and " (the book's)" or ""), "ui14", theme.ink_dim, { gloss = false })
    kit.button(x + w - 190, y + 24, 176, 40, "Say DC " .. util.int(n), function()
        M.answer(app, "dc:" .. util.int(n))
    end, { font = "ui18b", key = "dc_say", key_hint = 3, color = theme.button, hover = theme.button_hover })
end

-- For the real-click harness (tools/tests/ui_play/): which card is up and where its buttons are.
function M.trace_card(app, ev)
    if not input_trace.on then
        return
    end
    app.card_seq = (app.card_seq or 0) + 1
    input_trace.log("card", util.int(app.card_seq) .. " " .. tostring(ev.kind) .. " " .. input_trace.buttons())
end

-- Who at the table would enjoy an option (green) and who wouldn't (red): a dot and their names,
-- the DM's read. Dots, not faces: the same marks as the prep board's hovers.
function M.draw_leans(app, x, y, leans)
    local fx = x
    for _, group in ipairs({ { 1, theme.green, " would love it" }, { -1, theme.red, " wouldn't" } }) do
        local names = {}
        local keys = {}
        for _, p in ipairs(app.campaign.players) do
            if leans[p.key] == group[1] then
                table.insert(names, p.name)
                table.insert(keys, p.key)
            end
        end
        if #names > 0 then
            -- Their faces first, ringed in the lean's colour, then the words.
            for _, k in ipairs(keys) do
                kit.dot(fx + 11, y + 13, 24, group[2])
                kit.picture(fx + 1, y + 3, 20, 20, panels.face(k))
                fx = fx + 24
            end
            local line = util.join_names(names) .. group[3]
            kit.text(fx + 4, y + 4, line, "ui14", group[2])
            fx = fx + 4 + kit.width(line, "ui14") + 22
        end
    end
end

-- The friends a call is about: its lead (the actor's key), then anyone named in its words (by
-- their name or their hero's), in seat order.
function M.people_in(app, lead, texts)
    local out, seen = {}, {}
    local function add(p)
        if p and not seen[p.key] then
            seen[p.key] = true
            table.insert(out, p)
        end
    end
    if lead then
        add(app.campaign:player(lead))
    end
    local all = table.concat(texts or {}, " ")
    for _, p in ipairs(app.campaign.players) do
        local first = p.char and string.match(p.char, "^(%S+)")
        if (p.name and string.find(all, "%f[%w]" .. p.name .. "%f[^%w]")) or (first and string.find(all, "%f[%w]" .. first .. "%f[^%w]")) then
            add(p)
        end
    end
    return out
end

-- A row of who's who: their face and their hero's mini, then "Pip (Jess)". Lead first, marked.
function M.people_strip(app, x, y, w, people)
    local cx = x
    for i, p in ipairs(people) do
        local label = (p.char and string.match(p.char, "^(%S+)") or p.name) .. " (" .. p.name .. ")"
        local cw = 66 + kit.width(label, "ui14") + 14
        if cx + cw > x + w then
            break
        end
        kit.box(cx, y, cw, 40, i == 1 and kit.rgba("#e8b84a", 0.22) or kit.rgba("#000000", 0.07), { radius = 20 })
        kit.dot(cx + 20, y + 20, 34, panels.COLORS[p.key] or theme.panel3)
        kit.picture(cx + 4, y + 4, 32, 32, panels.face(p.key))
        kit.picture(cx + 38, y + 4, 26, 32, panels.mini(p))
        kit.text(cx + 66, y + 11, label, "ui14", theme.ink, { gloss = false })
        cx = cx + cw + 8
    end
end

function M.show_done(app)
    M.close_modal(app)
    app.layers.modal = kit.layer("night_done", false)
    local n = app.night
    local x, y, w, h = 800 - 230, 560, 460, 132
    kit.box(x, y, w, h, theme.paper, { radius = 12 })
    kit.text(x + w / 2, y + 18, "That's a wrap for tonight.", "ui18b", theme.ink, { pivot = gui.PIVOT_N })
    -- The evening as the table lived it (playtest, October 13: "16:48 at the table" read as a clock).
    local mins = math.floor((n and n.table_min) or 0)
    local spent = util.int(math.floor(mins / 60)) .. "h " .. string.format("%02d", mins % 60) .. "m"
    local ends = (n and n.clock_text) and (", wrapping up at " .. n:clock_text()) or ""
    kit.text(x + w / 2, y + 44, spent .. " at the table" .. ends .. ". " .. util.int(n and (n.answered or 0) or 0)
        .. " calls made.", "ui14", theme.ink_dim, { pivot = gui.PIVOT_N, w = w - 24 })
    kit.button(x + 50, y + 76, w - 100, 40, "See how everyone felt  >", function()
        app.go("report")
    end, { color = theme.go, hover = theme.go_hover })
end

return M
