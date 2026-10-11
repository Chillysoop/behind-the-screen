-- The four player panels along the bottom of game night (real-session pass): who's who
-- and who's playing whom. Each panel has the player's face (their expression follows how
-- they're sitting at the table), their character's paper mini, name, class and level, how
-- they're doing (their tell, Fun, Spotlight), hit points in a fight, and their last roll:
-- the d20 tumbles when they roll and lands on the number, with the skill, the total and the
-- DC or Armor Class it was against. Click a panel for the character sheet.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"
local empathy = require "game.model.empathy"

local M = {}

M.Y, M.W, M.H = 774, 376, 112
M.STEP = 392
local TEXT_X, TEXT_W = 118, 130
local ROLL_X, ROLL_W = 254, 116
local POSE_HOLD = 2.6
local ROLL_SPIN = 0.55

M.COLORS = {
    mara = kit.rgba("#c9a038"), dev = kit.rgba("#3f5f9a"), jess = kit.rgba("#3f8f84"), sam = kit.rgba("#a8443a"),
}
local CLASS_MINI = { fighter = "mini_fighter", rogue = "mini_rogue", cleric = "mini_cleric", wizard = "mini_wizard" }
local FACES = { lean = true, arms = true, yawn = true, phone = true, cheer = true, gasp = true, laugh = true, think = true }

local function alpha(c, a)
    return vmath.vector4(c.x, c.y, c.z, (c.w or 1) * a)
end

function M.x(i)
    return 24 + (i - 1) * M.STEP
end

-- The hero's paper mini on the screens: their class's, or a new character's own (B3).
function M.mini(p, class)
    if p and p.mini then
        return "mini_" .. p.mini
    end
    return CLASS_MINI[(p and p.class) or class] or "mini_fighter"
end

function M.face(key, pose)
    if pose and FACES[pose] then
        return "face_" .. key .. "_" .. pose
    end
    return "face_" .. key
end

-- Draw the panels into the current layer. on_click(key) opens a character sheet.
-- A player's dice changed (a gift, a set shown off): their panel shows the new set.
function M.set_dice(app, key, id)
    local chip = app.chips and app.chips[key]
    if chip and chip.dice then
        gui.play_flipbook(chip.dice, "dice_" .. id)
    end
end

function M.draw(app, on_click)
    app.chips = {}
    local level = app.campaign.level or 2
    for i, p in ipairs(app.campaign.players) do
        local x, y, w, h = M.x(i), M.Y, M.W, M.H
        local chip = { key = p.key, x = x, y = y, i = i }
        -- Lit when they speak in character (A9): a glow round the panel, in their colour.
        chip.glow = kit.box(x - 4, y - 4, w + 8, h + 8, M.COLORS[p.key] or theme.gold, { radius = 13 })
        gui.set_enabled(chip.glow, false)
        local icw = kit.width("IN CHARACTER", "ui14") + 20
        chip.ic_bg = kit.box(x + w - icw, y - 30, icw, 24, M.COLORS[p.key] or theme.gold, { radius = 8 })
        chip.ic = kit.text(x + w - icw / 2, y - 26, "IN CHARACTER", "ui14", theme.bg, { pivot = gui.PIVOT_N })
        gui.set_enabled(chip.ic_bg, false)
        gui.set_enabled(chip.ic, false)
        kit.button(x, y, w, h, "", function()
            if on_click then
                on_click(p.key)
            end
        end, { color = theme.bg_glass, hover = kit.rgba("#2a1f18", 0.92), radius = 10, key = "panel_" .. p.key })
        local col = M.COLORS[p.key] or theme.panel3
        local dim = p.present and 1 or 0.35
        kit.dot(x + 40, y + 41, 66, alpha(col, 0.55 * dim))
        chip.face = kit.picture(x + 7, y + 8, 66, 66, M.face(p.key), alpha(kit.rgba("#ffffff"), p.present and 1 or 0.4))
        chip.mini = kit.picture(x + 70, y + 27, 42, 52, M.mini(p),
            alpha(kit.rgba("#ffffff"), p.present and 1 or 0.4))
        kit.text(x + TEXT_X, y + 6, p.name, "ui18b", p.present and theme.text or theme.faint)
        -- The Heroic Inspiration token in front of them (B4).
        chip.token = kit.dot(x + TEXT_X + kit.width(p.name, "ui18b") + 14, y + 17, 14, theme.gold)
        gui.set_enabled(chip.token, p.heroic and true or false)
        local role = p.char .. ", " .. p.class_name .. " " .. util.int(level)
        if kit.width(role, "ui14") > TEXT_W then
            -- A long name (a new hero after a death): their first name is enough here.
            role = (string.match(p.char, "^(%S+)") or p.char) .. ", " .. p.class_name .. " " .. util.int(level)
        end
        kit.text(x + TEXT_X, y + 29, kit.ellipsize(role, "ui14", TEXT_W), "ui14", theme.dim)
        if not p.present then
            kit.text(x + TEXT_X, y + 52, "Out this week.", "ui14", theme.faint)
            kit.text(x + TEXT_X, y + 70, "Their chair is empty.", "ui14", theme.faint)
        else
            chip.tell = kit.text(x + TEXT_X, y + 49, "settling in", "ui14", theme.dim)
            kit.icon(x + TEXT_X, y + 71, 14, "fun", theme.gold)
            chip.fun = kit.bar(x + TEXT_X + 20, y + 74, TEXT_W - 22, 7, 0, 100, theme.gold)
            kit.icon(x + TEXT_X, y + 89, 14, "spotlight", theme.meters.spotlight)
            chip.spot = kit.bar(x + TEXT_X + 20, y + 92, TEXT_W - 22, 7, 0, 100, theme.meters.spotlight)
            -- Hit points, shown during fights, under the face and the mini.
            chip.hp_icon = kit.icon(x + 8, y + 89, 14, "heart", theme.red)
            chip.hp_text = kit.text(x + 25, y + 87, "", "ui14", theme.text)
            chip.hp_back = kit.box(x + 66, y + 93, 46, 7, kit.rgba("#000000", 0.5), { round = false })
            chip.hp_fill = kit.box(x + 66, y + 93, 46, 7, theme.red, { round = false })
            -- The last roll.
            local rx = x + ROLL_X
            kit.box(rx, y + 8, ROLL_W, h - 16, kit.rgba("#000000", 0.28), { radius = 8 })
            chip.die = kit.icon(rx + ROLL_W / 2 - 21, y + 12, 42, "d20", kit.rgba("#ffffff", 0.12))
            chip.num = kit.text(rx + ROLL_W / 2, y + 33, "", "ui18b", theme.bg, { pivot = gui.PIVOT_CENTER })
            chip.what = kit.text(rx + ROLL_W / 2, y + 58, "no rolls yet", "ui14", theme.faint, { pivot = gui.PIVOT_N })
            chip.res = kit.text(rx + ROLL_W / 2, y + 76, "", "ui14", theme.dim, { pivot = gui.PIVOT_N })
            -- Their dice (grey to start; a gift or a set they bought shows here).
            chip.dice = kit.picture(rx + ROLL_W - 22, y + 11, 18, 18,
                "dice_" .. require("game.model.dice_sets").of(app.campaign, p.key))
            app.chips[p.key] = chip
            local last = app.last_roll and app.last_roll[p.key]
            if last then
                M.show_roll(app, p.key, last, true)
            end
            if app.chip_pose and app.chip_pose[p.key] then
                gui.play_flipbook(chip.face, M.face(p.key, app.chip_pose[p.key].pose))
            end
        end
    end
    M.refresh(app)
    M.refresh_hp(app)
end

-- Tells always update live. The bars update every beat at Attentive Empathy and up;
-- below that, only when a scene starts or the night ends.
function M.refresh(app, scene_break)
    if not app.night or not app.chips then
        return
    end
    local level = app.campaign:empathy()
    local live = empathy.perks(level).live
    local tells = app.night:tells()
    for key, chip in pairs(app.chips) do
        local t = tells[key]
        if t and chip.tell then
            gui.set_text(chip.tell, kit.ellipsize(t.text, "ui14", TEXT_W))
            local c = t.engagement >= 0.5 and theme.text or (t.engagement >= 0.25 and theme.dim or theme.orange)
            gui.set_color(chip.tell, c)
            if live or scene_break or not chip.drawn then
                chip.drawn = true
                local fun = empathy.fill(level, t.fun)
                kit.set_bar(chip.fun, TEXT_W - 22, fun, 100)
                gui.set_color(chip.fun, fun >= 72 and theme.green or fun >= 55 and theme.teal or fun >= 40 and theme.gold
                    or fun >= 25 and theme.orange or theme.red)
                local p = app.campaign:player(key)
                kit.set_bar(chip.spot, TEXT_W - 22, empathy.fill(level, p.m.spotlight), 100)
            end
            -- The face follows how they're sitting, unless something just made them react.
            local held = app.chip_pose and app.chip_pose[key]
            if not held or (app.clock_t or 0) > held.until_t then
                local pose = t.pose
                if chip.shown_pose ~= pose then
                    chip.shown_pose = pose
                    gui.play_flipbook(chip.face, M.face(key, pose))
                end
            end
        end
    end
end

-- A momentary reaction (cheer, gasp...) on the panel's face, as on the table.
function M.pose(app, key, pose)
    local chip = app.chips and app.chips[key]
    app.chip_pose = app.chip_pose or {}
    app.chip_pose[key] = { pose = pose, until_t = (app.clock_t or 0) + POSE_HOLD }
    if chip and chip.face then
        chip.shown_pose = pose
        gui.play_flipbook(chip.face, M.face(key, pose))
    end
end

function M.refresh_hp(app)
    for key, chip in pairs(app.chips or {}) do
        local hp = app.in_battle and app.hp and app.hp[key]
        for _, n in ipairs({ chip.hp_icon, chip.hp_text, chip.hp_back, chip.hp_fill }) do
            if n then
                gui.set_enabled(n, hp and true or false)
            end
        end
        if hp and chip.hp_text then
            local cur, max = math.max(0, hp[1]), math.max(1, hp[2])
            gui.set_text(chip.hp_text, util.int(cur) .. "/" .. util.int(max))
            kit.set_bar(chip.hp_fill, 46, cur, max)
            local f = cur / max
            gui.set_color(chip.hp_fill, f > 0.5 and theme.green or (f > 0.25 and theme.gold or theme.red))
            gui.set_color(chip.hp_text, cur == 0 and theme.red or theme.text)
        end
    end
end

-- A roll for this player: { roll, mod, total, against ("DC 13", "AC 15"), what ("Stealth"),
-- success (true/false/nil), crit, fumble, hidden }. The die tumbles first unless instant.
function M.roll(app, key, r)
    app.last_roll = app.last_roll or {}
    app.last_roll[key] = r
    local chip = app.chips and app.chips[key]
    if not chip or not chip.die then
        return
    end
    local speed = app.speed_now and app.speed_now() or 1
    chip.spin = { t = 0, dur = ROLL_SPIN / math.sqrt(speed), r = r, tick = 0 }
    gui.set_color(chip.die, kit.rgba("#ffffff", 0.85))
    gui.set_text(chip.what, kit.ellipsize(r.what or "", "ui14", ROLL_W - 6))
    gui.set_color(chip.what, theme.text)
    gui.set_text(chip.res, "")
end

local function result_color(r)
    if r.crit then
        return theme.gold
    elseif r.success == true then
        return theme.green
    elseif r.success == false then
        return theme.red
    end
    return theme.teal
end

function M.show_roll(app, key, r, quiet)
    local chip = app.chips and app.chips[key]
    if not chip or not chip.die then
        return
    end
    chip.spin = nil
    gui.set_color(chip.die, r.hidden and theme.panel3 or result_color(r))
    gui.set_text(chip.num, r.hidden and "?" or util.int(r.roll or 0))
    gui.set_text(chip.what, kit.ellipsize(r.what or "", "ui14", ROLL_W - 6))
    gui.set_color(chip.what, theme.text)
    local res
    if r.total and r.mod and r.mod ~= 0 then
        res = util.int(r.total)
    elseif r.total then
        res = util.int(r.total)
    else
        res = ""
    end
    if r.against then
        res = res .. " vs " .. r.against
    end
    gui.set_text(chip.res, kit.ellipsize(res, "ui14", ROLL_W - 6))
    gui.set_color(chip.res, result_color(r))
    if not quiet then
        gui.set_scale(chip.die, vmath.vector3(1.25, 1.25, 1))
        gui.animate(chip.die, "scale", vmath.vector3(1, 1, 1), gui.EASING_OUTBACK, 0.3)
    end
end

-- Every frame: tumbling dice.
-- The Heroic Inspiration token lands in front of them, or gets spent (B4).
function M.set_token(app, key, on)
    local chip = app.chips and app.chips[key]
    if chip and chip.token then
        gui.set_enabled(chip.token, on and true or false)
    end
end

-- They speak as their character (A9): the panel lights up for a moment.
function M.light(app, key, seconds)
    local chip = app.chips and app.chips[key]
    if not chip or not chip.glow then
        return
    end
    chip.lit = { t = 0, dur = seconds or 2.4 }
    gui.set_enabled(chip.glow, true)
    gui.set_enabled(chip.ic_bg, true)
    gui.set_enabled(chip.ic, true)
end

function M.lit(app, key)
    local chip = app.chips and app.chips[key]
    return chip and chip.lit ~= nil
end

function M.update(app, dt)
    for key, chip in pairs(app.chips or {}) do
        local l = chip.lit
        if l then
            l.t = l.t + dt
            local col = M.COLORS[key] or theme.gold
            local a = l.t < 0.15 and (l.t / 0.15) or (l.t > l.dur - 0.4 and math.max(0, (l.dur - l.t) / 0.4) or 1)
            gui.set_color(chip.glow, alpha(col, 0.9 * a))
            gui.set_color(chip.ic_bg, alpha(col, a))
            gui.set_color(chip.ic, alpha(theme.bg, a))
            if l.t >= l.dur then
                chip.lit = nil
                gui.set_enabled(chip.glow, false)
                gui.set_enabled(chip.ic_bg, false)
                gui.set_enabled(chip.ic, false)
            end
        end
    end
    for key, chip in pairs(app.chips or {}) do
        local s = chip.spin
        if s then
            s.t = s.t + dt
            s.tick = s.tick - dt
            if s.t >= s.dur then
                M.show_roll(app, key, s.r)
            elseif s.tick <= 0 then
                s.tick = 0.05
                gui.set_text(chip.num, util.int(math.random(1, 20)))
                gui.set_color(chip.num, theme.bg)
            end
        end
    end
end

-- The panel's top edge, for speech bubbles when the camera can't see someone's head.
function M.anchor(app, key)
    for i, p in ipairs(app.campaign.players) do
        if p.key == key then
            return M.x(i) + M.W / 2, M.Y - 4, M.x(i), M.W
        end
    end
    return M.x(1) + M.W / 2, M.Y - 4, M.x(1), M.W
end

return M
