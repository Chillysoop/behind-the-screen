-- Game night (M4): the table plays the night. Scenery drops onto the mat, paper
-- minis walk and fight, the players lean in or drift to their phones, and speech
-- bubbles pop over their heads. Captions carry the DM's narration; decision cards,
-- improv hands, rulings and big rolls slide in when the DM is needed.
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
local night_mod = require "game.model.night"
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
local TIMERS = { decision = 30, improv = 45, ruling = 25, roll_where = 15, cook = 15 }
local ROLL_PATIENCE = 9          -- seconds to wait for the physical die before rolling for it

local CHIP_Y, CHIP_W, CHIP_H = panels.Y, panels.W, panels.H
local RIGHT_X, RIGHT_W = 984, 592
local LEFT_X, LEFT_W = 24, 560
-- The DM's narration sits above a row kept free for the players' speech bubbles.
local CAPTION_BOTTOM, CAPTION_W = 664, 900
local CARD_BOTTOM = 760
-- Longer read-alouds: the recap and the session's opening.
-- The DM's read-aloud text (A9): the opening, the recap, a place or a person coming in, the
-- bridge between scenes. It gets the boxed-passage look; the DM's own notes ("You improvise")
-- and the table's reactions stay plain captions, and asides go to the log only.
-- A goal line is the DM's own aim ("Pip wants to know what's behind the door"), not something
-- you'd read to the table, so it stays a plain caption (playtest, October 13).
local READ_ALOUD = { recap = true, opening = true, narration = true, bridge = true, twist = true, seed = true }
local LOG_X, LOG_Y, LOG_W, LOG_H = 24, 70, 520, 690
local STRIP_LABEL = "This scene's rolls  (? = behind your screen)"
local STRIP_RIGHT, STRIP_Y, DIE = 1576, 66, 30

local CLASS_SPRITE = { fighter = "fighter", rogue = "rogue", cleric = "cleric", wizard = "wizard" }
local CAST_SPRITE = {
    -- v2: the museum's people (borrowed minis until they get their own).
    mus_flitwidget = "npc_rosin", mus_telpur = "npc_hermit", mus_euryale = "npc_sable", mus_lecturer = "npc_ghost",
    mus_mech = "animated_armor", mus_sentinel = "animated_armor", mus_bone_construct = "skeleton",
    mus_knight = "animated_armor", mus_huntlings = "giant_crab", mus_briar = "dire_wolf",
    goblins = "goblin_boss", gus = "npc_gus", stranger = "npc_stranger", rook = "bandit_captain",
    hermit = "npc_hermit", rivals = "npc_rival", ogre = "ogre", corin = "npc_corin",
    wolf_lieutenant = "npc_vask", madame_sable = "npc_sable", abbot_ghost = "npc_ghost",
    -- M6 casts borrow a mini until they get their own.
    holt = "npc_holt", brother_tumble = "npc_tumble", goblin_scout = "npc_nib", verrin = "npc_verrin",
    bone_choir = "cultist", white_wolf = "dire_wolf",
    -- The slice rework's casts.
    wren = "npc_wren", grey_coat = "npc_grey_coat", miller = "npc_hob", turncoat_guide = "bandit_captain",
    market_friend = "npc_tilly", merchant = "npc_ottilie", cutpurses = "bandit", wolf_pack = "dire_wolf",
    restless_dead = "skeleton",
    -- Campaign styles (A18) and the new books (A13).
    fr_reeve = "npc_reeve", fr_goblin_chief = "goblin_boss", sea_captain_rosin = "npc_rosin", sea_grey_moll = "pirate",
    sea_envoy_pearl = "npc_pearl", sea_serpent_wake = "merrow", ur_watch_captain = "guard", ur_fixer = "npc_stranger",
    ur_mother_coil = "npc_coil", dn_lantern_company = "npc_rival", dn_mossjaw = "animated_armor", wd_guide = "scout",
    wd_white_stag = "npc_stag", wd_moss_hermit = "npc_hermit",
    bk_pirate_crew = "pirate", bk_merrow = "merrow", bk_crabs = "giant_crab", bk_spy = "spy", bk_rats = "swarm_of_rats",
    bk_armor = "animated_armor", bk_spiders = "giant_spider", bk_specter = "specter", bk_bear = "brown_bear",
    bk_gnolls = "gnoll_warrior", bk_worgs = "worg", bk_bugbear = "bugbear_warrior", bk_veteran = "warrior_veteran",
    bk_kobolds = "kobold_warrior", gz_hedge_witch = "npc_ashby", mod_bell_sexton = "npc_ansel", mod_bridge_hobb = "npc_hermit",
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

-- v2: the museum's monsters borrow the closest minis until they get their own.
local MUSEUM_SPRITE = {
    briar_beast = "dire_wolf", briar_boar = "dire_wolf", briar_triceratops = "brown_bear", sentinel = "animated_armor",
    bone_construct = "skeleton", giant_scarab_swarm = "swarm_of_rats", knight_of_shades = "animated_armor",
    kruthik_huntling = "giant_crab", the_lecturer = "specter", steam_mech = "animated_armor", euryale = "npc_sable",
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
    scarabs = { "{who} bursts open, and scarabs pour across the floor.", theme.orange, "twist" },
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
    app.handout_seen = nil
    -- A clean mat to start: tonight's first scene lays its place's map, if it has one.
    if app.pieces_key and app.pieces_key ~= "" then
        post("pieces", { cells = nil })
    end
    app.pieces_key = nil
    app.speed_i = app.speed_i or M.SPEED_1X
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
    app.scene_has_goal = nil
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
    app.layers.base = kit.layer("night_base")
    M.draw_frame(app)
    app.layers.log = kit.layer("night_log")
    M.draw_log(app)
    app.layers.fx = kit.layer("night_fx")
    app.bubbles, app.floaters = {}, {}
    app.side, app.toast_card = nil, nil     -- (their nodes went with the old layers)
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
    -- The table clock (A14): what time it is at the table, and when you said you'd stop.
    local tc = (n and n.clock_text) and (n:clock_text() .. " (till " .. n:clock_text(n.table_planned) .. ")") or ""
    -- (No call count up here: the night's end card has it, October 20.)
    return tc .. "      Speed " .. (speed(app) < 1 and "0.5" or util.int(speed(app))) .. "x      Your rolls: " .. ((n and n.dm_rolls) or "hidden")
        .. "      Timer: " .. (app.timer_on and "on" or "off")
end

function M.draw_frame(app)
    kit.use(app.layers.base)
    kit.box(0, 0, kit.W, 58, theme.bg_glass, { round = false })
    kit.text(24, 6, "SESSION " .. util.int(app.campaign.week), "ui22b", theme.gold)
    kit.text(24, 35, "GAME NIGHT", "ui14", theme.faint)
    app.n_label = kit.text(160, 6, kit.ellipsize(app.scene_label, "ui18b", 600), "ui18b", theme.text)
    app.n_sub = kit.text(160, 32, kit.ellipsize(app.scene_sub or "", "ui14", 360), "ui14", theme.dim)
    -- Anything from an earlier build is gone with its layer.
    app.pip_nodes, app.strip_nodes, app.goal_nodes = {}, {}, {}
    M.draw_goal(app)
    -- Your notes: the story so far, who's who, the party's sheets, the Story log (N; S opens the
    -- Story log on this scene's storyline). One button: a second, "Stories (S)", opened the same
    -- notes on another tab (October 20).
    kit.button(840, 10, 112, 38, "Notes (N)", function()
        if app.open_notes then
            app.open_notes()
        end
    end, { font = "ui14", key = "night_notes" })
    app.n_status = kit.text(1576, 8, status_text(app), "ui14", theme.text, { pivot = gui.PIVOT_NE })
    -- The keys: the first session's first scene only (the card-led playtest, October 16: one more
    -- line nobody read after the first scene; October 20: back at the start of every night). The
    -- hover card below keeps them. (No "1-4 camera": the night aims the camera itself, and a card's
    -- options show their own numbers.)
    app.n_keys = nil
    if not app.keys_hidden and app.campaign.week <= 1 then
        app.n_keys = kit.text(1576, 32, "Space skip  F/G speed  Tab log  H your rolls  T timer  C photo"
            .. (app.campaign.module and "" or "  S story log"), "ui14",
            theme.faint, { pivot = gui.PIVOT_NE })
    end
    -- What the counters are (the newcomer playtest, October 16: "Your rolls: hidden").
    gloss.card_spot(1100, 4, 476, 24, "The evening at a glance",
        "The time at the table, and when you said you'd stop. Speed: how fast the night plays (F faster, G slower, "
        .. "down to half speed; Space skips ahead). Your rolls (H): whether you roll for the monsters behind your screen "
        .. "or in the open. Timer (T): a gentle countdown on each call. Tab opens the whole log, C takes a photo"
        .. (app.campaign.module and "." or ", S opens the Story log."))
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

-- What they're out to do this week, after the scene's line in the header (October 15: so the DM
-- never has to open a menu to know): the main story's icon and the objective, which changes when
-- they find the clue it hangs on.
function M.draw_goal(app)
    if not app.layers.base then
        return
    end
    kit.use(app.layers.base)
    kit.remove(app.goal_nodes or {})
    app.goal_nodes = {}
    local lore = require "game.model.lore"
    local obj = lore.objective(app.campaign, nil, true)
    -- A scene with a goal says what it's for under its name: the week's goal beside it made three
    -- aims on screen at once (the card-led playtest, October 16).
    if not obj or app.scene_has_goal then
        return
    end
    local sub = kit.ellipsize(app.scene_sub or "", "ui14", sub_room(app))
    local x = 160 + (sub ~= "" and (kit.width(sub, "ui14") + 22) or 0)
    -- (After a challenge's pips, when there are any.)
    local pr = app.progress
    if pr then
        x = 160 + kit.width(sub, "ui14") + 16 + (pr.need + pr.max) * 14 + 10 + 16 + (app.pips_label_w or 0)
    end
    local full = "This week: " .. obj
    local y = 32
    local avail = 766 - x - 20
    -- Too long for beside the scene's line: beside its title instead, when that has the room
    -- (October 15: the goal was cut short whenever the scene's line was long).
    if kit.width(full, "ui14") > avail - 20 then
        local x1 = 160 + kit.width(kit.ellipsize(app.scene_label or "", "ui18b", 600), "ui18b") + 24
        if 766 - x1 - 20 > avail then
            x, y, avail = x1, 10, 766 - x1 - 20
        end
    end
    if avail < 140 then
        return
    end
    if kit.width(full, "ui14") > avail - 20 then
        full = obj    -- (the bell icon says "this week" well enough when room is short)
    end
    local m = lore.storyline(app.campaign, content.lore.briefing.next_story)
    if m and m.icon then
        table.insert(app.goal_nodes, kit.icon(x, y + 1, 15, m.icon, m.color and kit.rgba(m.color) or theme.gold))
    end
    local text = kit.ellipsize(full, "ui14", avail - 20)
    table.insert(app.goal_nodes, kit.text(x + 20, y, text, "ui14", theme.gold))
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
        M.draw_goal(app)
        return
    end
    -- Where the scene's last roll stands right now (the newcomer playtest, October 16: the dots
    -- said nothing about what they were doing to it until the scene's end).
    local lx = x + pr.max * 14 + 8
    local word, col, short
    -- (A warm word from someone in the scene counts too: the second playtest, October 17, saw
    -- "normal" straight after the card promised "easier".)
    -- (And a player's pull you followed: the plan slipped, game/model/pulls.lua.)
    local edge = ((pr.wins >= pr.need) and -2 or ((pr.setbacks >= pr.max) and 2 or 0)) + (pr.lead and -2 or 0)
        + (pr.slip and 2 or 0)
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
    M.draw_goal(app)    -- moves along to make room
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
    post("vignette")
    if not sn then
        app.terrain = nil
        app.zoom(1)
        return
    end
    if sn.terrain then
        app.terrain = sn.terrain
        post("terrain", { set = sn.terrain, animate = false, def = board_mod.encode(sn.terrain) })
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
    post("spawn", { list = list })
    for _, m in ipairs(sn.minis or {}) do
        if m.down then
            post("down", { id = "snap_" .. tostring(m.id) })
        end
    end
    app.zoom(sn.camera or 2)
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
    c.tag = kit.text(0, 0, "READ ALOUD      Space: next", "ui14", theme.ink_dim)   -- (the second playtest: "is it waiting for me?")
    c.text = kit.text(0, 0, "", "story22", theme.text, { pivot = gui.PIVOT_N })
    c.life, c.age, c.color = 0, 0, theme.text
    for _, n in ipairs({ c.box, c.rule, c.tag, c.text }) do
        gui.set_enabled(n, false)
    end
    app.caption = c
    app.title_card = nil
end

-- Lay the caption's nodes out in its rect (the read-aloud box or the plain caption).
local function place_caption(c, x, y, w, h)
    place(c.box, x, y)
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
    c.age = 0
    -- Read-aloud passages stay up a little longer: they're read out, not glanced at.
    c.life = (pacing.read(text) * (read and 1.25 or 1) + 0.6) / speed(app)
    c.style = style
    gui.set_enabled(c.box, true)
    gui.set_enabled(c.text, true)
    gui.set_enabled(c.rule, read)
    gui.set_enabled(c.tag, read)
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

local HOW = { won = "They won.", fled = "The foes ran.", surrendered = "They surrendered.", lost = "The party fell back.",
              escaped = "The boss got away." }

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
    local found = {}
    if app.scene_hinge then
        table.insert(found, app.scene_hinge)    -- what next session hangs on, first
    end
    if ev.reward then
        table.insert(found, ev.reward)
    end
    for _, c in ipairs(app.scene_found or {}) do
        if c ~= app.scene_hinge then
            table.insert(found, c)
        end
    end
    if #found > 0 then
        local more = #found > 1 and ("  (+" .. util.int(#found - 1) .. " more in your notes)") or ""
        local first = kit.ellipsize("Found: " .. found[1], "ui14", (SIDE_W - 32) * 2 - 30 - kit.width(more, "ui14"))
        table.insert(rows, { first .. more, theme.text })
    end
    -- What the lore screen said this scene would open, now that it has (the card-led playtest,
    -- October 16: "joins your hand next session" was promised, and never mentioned again).
    if ev.opens and #ev.opens > 0 then
        table.insert(rows, { "Next session: " .. util.join_names(ev.opens) .. (#ev.opens == 1 and " joins" or " join")
            .. " your hand.", theme.gold })
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
    -- Once: the heroes and the table are two different scores.
    local g = app.campaign.guide
    if g and g.seen and not g.seen.scene_card_teach and (not won or app.campaign.week == 1) and not (g.off) then
        g.seen.scene_card_teach = true
        table.insert(rows, { won and "Heroes win some scenes and lose others. The night is scored on how the table feels."
            or "The heroes don't have to win every scene. The night is scored on how the table feels: that's the bars along "
            .. "the bottom, not this.", theme.gold })
    end
    local top = ev.total and ("SCENE " .. util.int(ev.index) .. " OF " .. util.int(ev.total) .. " DONE")
        or ("ROOM " .. util.int(ev.index) .. " DONE")      -- v2: the museum doesn't know how far tonight goes
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
        table.insert(rows, { (sm.how == "surrendered" and "Gave up: " or "Ran: ") .. util.join_names(mid_names(sm.ran)) .. ".", theme.dim })
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
                for _, n in ipairs({ c.box, c.rule, c.tag, c.text }) do
                    gui.set_enabled(n, false)
                end
            end
        end
        gui.set_color(c.text, alpha_of(c.color, a))
        gui.set_color(c.box, caption_box_color(c, a))
        gui.set_color(c.tag, alpha_of(theme.ink_dim, a))
        gui.set_color(c.rule, alpha_of(theme.gold, a))
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
    -- The side card steps aside for a call that needs the space (a card on the right, the improv
    -- hand, the opening) and waits; it comes back after.
    local sd = app.side
    if sd then
        local pk = app.pending and app.pending.kind
        local hide = pk == "decision" or pk == "improv" or pk == "cinematic"
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
    if ev.npc then
        npc = { sprite = CAST_SPRITE[ev.npc.cast] or "npc_stranger", x = ev.npc.x, y = ev.npc.y }
        app.names.npc = ev.npc.name
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

local function signed(n)
    n = math.floor((n or 0) + 0.5)
    return (n >= 0 and "+" or "") .. util.int(n)
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
                .. ": a graze weapon always nicks." .. left_of(s), "system")
            app.last_attack = nil
        elseif a and a.target == s.id and a.hit then
            local dice = (a.dmg and a.dmg ~= "") and (" (" .. a.dmg .. (s.crit and ", doubled" or "") .. ")") or ""
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
            M.float(app, s.id, s.name, say[2] or theme.teal)
            M.push(app, (string.gsub(say[1], "{(%w+)}", { who = nm(s.id), target = nm(s.target), by = nm(s.by) })), say[3] or "system")
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
        M.float(app, s.id, "Death save: " .. util.int(s.roll or 0), (s.roll or 0) >= 10 and theme.teal or theme.red)
        if is_party(app, s.id) then
            panels.roll(app, s.id, { roll = s.roll, total = s.roll, against = "DC 10", what = "Death save",
                                     success = (s.roll or 0) >= 10, crit = s.roll == 20 })
        end
    elseif k == "stable" then
        M.float(app, s.id, "Stable", theme.teal)
    elseif k == "fortitude" then
        M.float(app, s.id, "Undead Fortitude", theme.purple)
    elseif k == "flee" and s.why == "surrender" then
        -- A foe who surrenders stays put, hands up (A7): never "runs for it".
        M.float(app, s.id, "Surrenders", theme.teal)
        battle_hud.gone(app, s.id)
        M.push(app, name_of(app, s.id) .. " throws down their weapon and surrenders.", "good")
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
    local k = ev.kind
    ambience.night_event(app, ev)
    if ev.reveal then
        board_reveal(app, ev)
    end
    if ev.npc_show then
        npc_steps_in(app)
    end
    if k == "scene" then
        app.scene_found, app.scene_hinge = {}, nil
        app.scene_has_goal = ev.goal ~= nil
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
        app.scene_label = (ev.total and ("Scene " .. util.int(ev.index) .. " of " .. util.int(ev.total))
            or ("Room " .. util.int(ev.index))) .. ":  " .. ev.title
        local who = ev.cast and (" with " .. util.lower_first(ev.cast)) or ""
        -- What the scene is for, under its name (the card-led night, October 16).
        app.scene_sub = ev.goal and ((ev.type_name or "") .. ": " .. util.lower_first(ev.goal)) or ((ev.type_name or "") .. who)
        gui.set_text(app.n_label, kit.ellipsize(app.scene_label, "ui18b", 600))
        gui.set_text(app.n_sub, kit.ellipsize(app.scene_sub, "ui14", 360))
        app.progress = nil
        M.draw_pips(app)
        M.draw_goal(app)
        M.push(app, app.scene_label .. "  (" .. app.scene_sub .. ")", "scene", true)
        -- (The goal is under the scene's name in the header, right above: the title card says where
        -- and who.)
        local sub = (ev.type_name or "") .. who
        M.title(app, (ev.total and ("SCENE " .. util.int(ev.index) .. " OF " .. util.int(ev.total)) or ("ROOM " .. util.int(ev.index)))
            .. (ev.story and "   -   THIS WEEK'S STORY" or ""),
            ev.title, sub)
        stage(app, ev)
        cam(app, 2)
    elseif k == "stage" then
        stage(app, ev)
        if ev.title then
            M.title(app, "THE SCENE SHIFTS", ev.title, "")
        end
        cam(app, 2)
    elseif k == "cinematic" then
        -- The opening of session 1 and the briefing after the introductions (October 15).
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
    elseif k == "handout" then
        -- A handout you made in prep lands in front of a player (game/model/handouts.lua).
        app.handout_seen = true
        local p = player(app, ev.who)
        if p then
            M.float(app, ev.who, "A handout!", theme.gold)
            M.push(app, p.name .. " gets " .. (ev.what or "a handout") .. ". It stays at their seat.", "reward")
        end
        if app.place_handouts then
            app.place_handouts(ev.who)
        end
        post("pose", { who = ev.who, pose = "lean", hold = true })
    elseif k == "story_back" then
        -- A storyline the table thought was dropped comes back (game/model/storylines.lua).
        if ev.who then
            M.float(app, ev.who, "It's back!", theme.gold)
        end
        M.push(app, (ev.name or "A dropped storyline") .. " is back. Nobody saw that coming.", "thread")
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
    elseif k == "scene_goal" then
        -- An improvised goal: the header says it too.
        app.scene_has_goal = true
        app.scene_sub = (app.scene_type_name or "Scene") .. ": " .. util.lower_first(ev.goal or "")
        if app.n_sub then
            gui.set_text(app.n_sub, kit.ellipsize(app.scene_sub, "ui14", 360))
        end
        M.draw_pips(app)
        M.draw_goal(app)
    elseif k == "progress" then
        -- A mid-scene big roll moved the dots too (the card-led playtest: a triumph left them be).
        app.progress = ev.progress
        M.draw_pips(app)
    elseif k == "mark" then
        -- v2: Euryale's card changed (her thought comes as the next caption).
        M.toast(app, "EURYALE'S CARD: " .. string.upper(ev.name), ev.showdown .. ". (" .. ev.why .. ".)")
        M.push(app, "Euryale's card: " .. ev.name .. ". " .. ev.showdown .. ".", "clue", true)
    elseif k == "warning" then
        -- v2: the fair-warning bank (a harsh call feels earned when they took the chance knowingly).
        app.fair_warning = ev.bank
        if ev.unearned then
            M.push(app, "A harsh call with nothing in the bank. It felt arbitrary.", "warn", true)
        end
    elseif k == "stage_dress" then
        -- v2: the board dresses itself without a line about it (ev.reveal did the work above).
    elseif k == "clue" then
        -- The party learned something: it goes in the DM's notes.
        M.toast(app, "NEW IN YOUR NOTES", ev.text)
        M.push(app, "Noted: " .. ev.text, "clue", true)
        app.scene_found = app.scene_found or {}
        table.insert(app.scene_found, ev.text)
        if ev.hinge then
            app.scene_hinge = ev.text
        end
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
    elseif k == "say" then
        local p = player(app, ev.who)
        local speaker = p and (ev.ic and p.char or p.name) or "Someone"
        local anchor = { head = ev.who }
        if ev.ic then
            -- In character, it shows (A9): their panel and their mini on the board light up, and
            -- the line comes from the mini when it's on the board. Table talk stays at their head.
            local secs = 1.2 + pacing.read(ev.text)
            panels.light(app, ev.who, secs / speed(app))
            post("glow", { id = ev.who, time = secs / speed(app) })
            if anchor_xy(app, { mini = ev.who }) then
                anchor = { mini = ev.who }
            end
        end
        M.bubble(app, anchor, speaker, ev.text, ev.ic)
        M.push(app, speaker .. ": \"" .. ev.text .. "\"", ev.ic and "quote" or "reaction", true)
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
            for i, f in ipairs(ev.foes or {}) do
                app.names[f.id] = f.name
                if f.boss then
                    app.boss_id = f.id
                end
                -- one at a time, the way the DM sets the minis out
                table.insert(list, { id = f.id, sprite = foe_sprite(f, i), x = f.x, y = f.y, delay = 0.3 + (i - 1) * 0.12 })
            end
            -- On the party's side (the museum's Steam Mech, v2): a mini beside the heroes.
            app.ally_ids = {}
            for i, a in ipairs(ev.allies or {}) do
                app.names[a.id] = a.name
                table.insert(app.ally_ids, a.id)
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
                or (how == "surrendered" and "They throw down their weapons. The fight is over.")
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
        post("track", { on = false })
        M.clear_fx(app)
        cam(app, 1)
        M.show_done(app)
    elseif k == "decision" or k == "improv" or k == "ruling" or k == "roll_where" or k == "cook" then
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
        app.improv_sel = {}
        app.pending_left = app.timer_on and TIMERS[k] or nil
        if k == "decision" and ev.card and ev.card.turn_of and app.in_battle then
            battle_hud.turn(app, ev.card.turn_of)
        end
        M.clear_fx(app)
        if k == "decision" then
            cam(app, app.in_battle and 2 or 1)   -- a card mid-fight keeps the mat in view (A7)
        elseif k == "improv" then
            cam(app, 2)
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

-- The opening and the briefing (game/model/lore.lua) -------------------------------------------
-- The DM setting up the world, a card at a time, with the table behind it: each storyline,
-- faction and truth with its icon, the same icon it wears on the cards from here on.

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

-- A briefing row's text height (capped at its lines).
function M.row_h(r, w)
    return math.min(kit.text_height(r.text, "ui18", w - 150), (r.lines or 2) * kit.line_height("ui18"))
end

-- How tall a briefing card needs to be, and how far apart its rows can sit.
function M.briefing_layout(sl, w)
    local function total(gap)
        local hh = 70 + (sl.sub and 18 or 0)
        for _, r in ipairs(sl.rows or {}) do
            hh = hh + math.max(gap, M.row_h(r, w) + 16)
        end
        hh = hh + 6
        if sl.where then
            hh = hh + math.max(34, kit.text_height(sl.where, "story22", w - 260) + 10)
        end
        if sl.first then
            hh = hh + kit.text_height(sl.first, "story22", w - 260) + 18
        end
        return hh + 96     -- the dots and the button
    end
    local gap = 46
    while gap > 36 and total(gap) > 700 do
        gap = gap - 2
    end
    return { h = total(gap), gap = gap }
end

function M.show_cinematic(app, ev)
    M.close_modal(app)
    M.clear_fx(app)
    app.layers.modal = kit.layer("night_modal", true)
    local slides = ev.slides or {}
    local i = util.clamp(app.cine_i or 1, 1, math.max(1, #slides))
    local sl = slides[i] or {}
    kit.box(0, 0, kit.W, kit.H, kit.rgba("#0c0806", 0.62), { round = false })
    local w, h = 980, 560
    -- A briefing grows to fit what it has to say (October 15: four heroes and a long recap ran
    -- off the bottom), up to the player panels; past that its rows sit closer.
    local fit = sl.briefing and M.briefing_layout(sl, w) or nil
    if fit then
        h = util.clamp(fit.h, 340, 700)
    end
    local x, y = (kit.W - w) / 2, math.max(64, math.min(150, 760 - h))
    kit.box(x - 3, y - 3, w + 6, h + 6, sl.color and kit.rgba(sl.color) or theme.gold, { radius = 15 })
    kit.box(x, y, w, h, theme.paper, { radius = 13 })
    -- Buttons first: the first one is the way on (number keys and the test drivers press it).
    local last = i >= #slides
    kit.button(x + w - 236, y + h - 64, 210, 44, last and (ev.id == "opening" and "Introductions  >" or "Let's play  >")
        or "Continue  >", function()
        M.cinematic_next(app)
    end, { color = theme.go, hover = theme.go_hover, key = "cine_next" })
    if not last then
        kit.button(x + 26, y + h - 58, 150, 32, ev.id == "opening" and "Skip the opening" or "Skip ahead", function()
            if ev.id == "opening" then
                app.cine_i = #slides
                M.cinematic_next(app)
            else
                -- (A catch-up skips to its last card: where they are and what's first.)
                app.cine_i = #slides
                M.show_cinematic(app, ev)
            end
        end, { font = "ui14", color = theme.panel3, key = "cine_skip" })
    end
    -- Which card of how many.
    for k = 1, #slides do
        kit.dot(x + w / 2 - (#slides - 1) * 12 + (k - 1) * 24, y + h - 42, k == i and 14 or 10,
            k == i and theme.ink or kit.rgba("#8a7a62"))
    end
    if sl.briefing then
        -- The briefing: the lore in a line each, the heroes, then where they are and what's first.
        -- (The recap after the first session: what they found, each under its storyline's icon.)
        kit.text(x + 40, y + 30, sl.kicker or "", "ui18b", kit.rgba("#8a5a20"), { w = w - 80, lines = 1 })
        local ry = y + 70
        if sl.sub then
            kit.text(x + 40, ry - 8, sl.sub, "ui14", kit.rgba("#8a5a20"))
            ry = ry + 18
        end
        local gap = fit.gap
        for _, r in ipairs(sl.rows or {}) do
            local th = M.row_h(r, w)
            lore_icon(x + 40, ry - 4, 40, r)
            kit.text(x + 96, ry + 4, r.text, "ui18", theme.ink, { w = w - 150, lines = r.lines or 2 })
            ry = ry + math.max(gap, th + 16)
        end
        ry = ry + 6
        if sl.where then
            kit.text(x + 40, ry, sl.where_label or "WHERE YOU ARE", "ui14", kit.rgba("#8a5a20"))
            kit.text(x + 220, ry - 3, sl.where, "story22", theme.ink, { w = w - 260, lines = 2 })
            ry = ry + math.max(34, kit.text_height(sl.where, "story22", w - 260) + 10)
        end
        if sl.first then
            kit.box(x + 28, ry - 8, w - 56, kit.text_height(sl.first, "story22", w - 260) + 18, kit.rgba("#e8b04a", 0.22),
                { radius = 8 })
            kit.text(x + 40, ry, sl.first_label or "WHAT'S FIRST", "ui14", kit.rgba("#8a5a20"))
            kit.text(x + 220, ry - 3, sl.first, "story22", theme.ink, { w = w - 260, lines = 3 })
        end
    elseif sl.rows then
        kit.text(x + 40, y + 30, sl.kicker or "", "ui18b", kit.rgba("#8a5a20"))
        kit.text(x + 40, y + 56, sl.title or "", "title30", theme.ink)
        local ry = y + 120
        for _, r in ipairs(sl.rows) do
            lore_icon(x + 40, ry, 64, r)
            kit.text(x + 124, ry + 2, r.title or "", "ui22b", theme.ink, { w = w - 170, lines = 1 })
            kit.text(x + 124, ry + 32, r.text or "", "ui18", theme.ink, { w = w - 170, lines = 2 })
            ry = ry + 104
        end
    else
        lore_icon(x + 50, y + 70, 180, sl)
        kit.text(x + 280, y + 64, sl.kicker or "", "ui18b", kit.rgba("#8a5a20"))
        kit.text(x + 280, y + 94, sl.title or "", "title30", theme.ink, { w = w - 320, lines = 2 })
        kit.text(x + 280, y + 152, sl.text or "", "read26", theme.ink, { w = w - 330 })
    end
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

-- Number keys pick a card's options (the fix pass): 1 to 4 on any card, and on the improv hand
-- they pick cards (Enter plays them). A fallback that works even when a click doesn't.
function M.pick_key(app, n)
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

-- The log stays out of the way (A11): with it open, the left-hand cards dock beside it rather
-- than over it, and the improv hand centres in the space to its right.
local function left_x(app)
    return app.log_open and (LOG_X + LOG_W + 16) or LEFT_X
end

local function centre_x(app, w)
    if app.log_open then
        return math.max(800, math.min(LOG_X + LOG_W + 16 + w / 2, kit.W - 16 - w / 2))
    end
    return 800
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
        for _, n in ipairs({ c.box, c.rule, c.tag, c.text }) do
            gui.set_enabled(n, false)
        end
    end
end

function M.show_modal(app, ev, instant)
    -- A cinematic draws itself (October 20: Tab for the log, or a rebuild, during the opening or a
    -- briefing redrew it as an empty card, and the night waited on a card that wasn't there).
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
    if ev.kind == "decision" then
        dodge_caption(app, 16, RIGHT_X - 16)
    elseif ev.kind == "ruling" or ev.kind == "roll_where" then
        dodge_caption(app, left_x(app) + LEFT_W + 16, kit.W - 16)
    elseif ev.kind == "improv" then
        dodge_caption(app, nil)
    end
    local slide = 0
    if ev.kind == "decision" then
        local x, w = RIGHT_X, RIGHT_W
        local card = ev.card
        -- Taking over (B8): the one you're speaking or acting for, as their paper mini.
        local portrait = (card.cast and CAST_SPRITE[card.cast]) or (card.monster and monster_sprite(card.monster, 1)) or nil
        -- A player's pull (game/model/pulls.lua): their face, top right.
        local face = card.who and panels.face(card.who)
        local tw = (portrait or face) and (w - 120) or (w - 40)
        local title_h = math.max(math.min(80, kit.text_height(card.title, "title30", tw)), portrait and 40 or 0)
        local text_h = kit.text_height(card.text, "ui18", w - 40)
        -- How bad it could get, on a fight's call (the newcomer playtest, October 16).
        local danger_h = card.danger and (kit.text_height(card.danger, "ui18", w - 64) + 16) or 0
        -- What you agreed at Session Zero, on the call it's about.
        local promise_h = card.promise and (kit.text_height(card.promise, "ui14", w - 40) + 8) or 0
        local labels, h = {}, 62 + title_h + 12 + text_h + 18 + (danger_h > 0 and (danger_h + 10) or 0) + promise_h
        local lean_h = {}
        local sub_h = {}
        for i, o in ipairs(card.options) do
            labels[i] = o.label .. (o.roll and ("  (" .. (o.skill or "d20") .. " check)") or "")
                .. (o.cooked and "  (overrules the die)" or "") .. (o.promise and "  (as agreed)" or "")
            lean_h[i] = (o.leans and next(o.leans)) and 30 or 0
            -- What an answer costs and gives, under it (a pull's four answers).
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
        kit.text(x + 20, y + 62 + title_h, card.text, "ui18", theme.ink, { w = w - 40 })
        local oy = y + 62 + title_h + 12 + text_h + 8
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
                   hover = theme.button_hover, key_hint = i, enabled = not opt.disabled,
                   key = opt.answer and ("pull_" .. opt.answer) or nil })
            if sub_h[i] > 0 then
                local ly = oy + 10 + kit.text_height(label, "ui18b", w - 68 - KEY_PAD)
                kit.text(x + 34, ly, opt.sub, "ui14", opt.disabled and kit.rgba("#8a7c6a") or theme.dim,
                    { w = w - 68 - KEY_PAD })
            end
            if lean_h[i] > 0 then
                M.draw_leans(app, x + 34, oy + oh - 32, opt.leans)
            end
            oy = oy + oh + 10
        end
        timer_bar(app, x + 20, oy + 2, w - 40, "the first option")
        slide = 640
    elseif ev.kind == "improv" then
        M.draw_improv(app, ev)
        slide = 0
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
        local h = 110 + text_h + promise_h + 136 + 10 + (app.pending_left and 34 or 0)
        local y = card_y(h)
        kit.box(x, y, w, h, theme.paper, { radius = 12 })
        local player_roll = ev.by ~= "dm"
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
        timer_bar(app, x + 20, oy + 136, w - 40, "in the open")
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

-- Who at the table would enjoy an option (green) and who wouldn't (red): a dot and their names,
-- the DM's read. Dots, not faces: the same marks as the prep board's hovers.
function M.draw_leans(app, x, y, leans)
    local fx = x
    for _, group in ipairs({ { 1, theme.green, " would love it" }, { -1, theme.red, " wouldn't" } }) do
        local names = {}
        for _, p in ipairs(app.campaign.players) do
            if leans[p.key] == group[1] then
                table.insert(names, p.name)
            end
        end
        if #names > 0 then
            kit.dot(fx + 7, y + 12, 12, group[2])
            local line = util.join_names(names) .. group[3]
            kit.text(fx + 18, y + 4, line, "ui14", group[2])
            fx = fx + 18 + kit.width(line, "ui14") + 22
        end
    end
end

-- What kind of card it is, as the night counts them: one of each plays.
local function improv_kind(c)
    return c and ((c.comp and c.comp.kind) or (c.quantum and "quantum") or (c.stock and c.stock.id)) or nil
end

-- The improv hand: pick one to three cards, then play them.
function M.draw_improv(app, ev)
    local sel = app.improv_sel or {}
    local n = #ev.cards
    local cw, ch, gap = 178, 196, 12
    local total = n * cw + (n - 1) * gap
    local pw = math.max(total, 640) + 40
    local mid = centre_x(app, pw)
    local px = mid - pw / 2
    local prompt_h = kit.text_height(ev.prompt or "", "ui18", pw - 40)
    local ph = 96 + prompt_h + 34
    local cards_y = 470
    local py = cards_y - 30 - ph
    kit.box(px, py, pw, ph, theme.paper, { radius = 12 })
    badge(px + 20, py + 18, ev.drift and "OFF SCRIPT" or "IMPROVISE", theme.orange)
    kit.text(px + 20, py + 50, ev.drift and "The party wandered off" or ("Empty slot: " .. (ev.slot or "")), "title30", theme.ink)
    kit.text(px + 20, py + 94, ev.prompt or "", "ui18", theme.ink, { w = pw - 40 })
    kit.text(px + 20, py + 100 + prompt_h, "Pick 1 to 3 cards, one of each kind. Your best card counts fully; one that doesn't fit always hurts.",
        "ui14", theme.ink_dim, { w = pw - 40 })
    local picked = {}
    local x0 = mid - total / 2
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
                -- One of each kind (the night keeps only one): a second goal swaps out the first
                -- rather than vanishing when it plays (playtest, October 13).
                for j in pairs(sel) do
                    if improv_kind(ev.cards[j]) == improv_kind(c) then
                        sel[j] = nil
                    end
                end
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
        elseif c.story then
            -- (The newcomer playtest, October 16: which of these is the week's story?)
            kit.text(cx + 12, cy + 120, "This week's story", "ui14", theme.gold, { w = cw - 24, lines = 1 })
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
    local bx = mid - 300
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
        or ""      -- (the rule is under the prompt already: the second playtest, October 17, read it twice)
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
