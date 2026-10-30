-- Fights on the mat, readable at a glance (real-session pass): a hit point bar over every
-- mini (heroes and monsters), the conditions they're under, the turn order along the top
-- with whoever's acting lit up, and spell areas and zones laid on the mat as tinted squares
-- (main/table/table.script draws them). The model's fight events arrive as turn steps
-- (game/model/fight.lua); night_view hands them over here. State lives in app.hud, so the
-- overlay redraws itself whenever the game night screen is rebuilt.

local kit = require "game.ui.kit"
local theme = require "game.ui.theme"
local util = require "game.model.util"
local gloss = require "game.ui.gloss"

local M = {}

local TABLE = "/table#table"
local H = 900
local BAR_W, BAR_H = 44, 6
local INIT_X0, INIT_X1, INIT_Y = 640, 1020, 64
local CLASS_MINI = { fighter = "mini_fighter", rogue = "mini_rogue", cleric = "mini_cleric", wizard = "mini_wizard" }

local COND_NAMES = {
    prone = "Prone", restrained = "Restrained", unconscious = "Unconscious", incapacitated = "Incapacitated",
    paralyzed = "Paralyzed", frightened = "Frightened", charmed = "Charmed", blinded = "Blinded", deafened = "Deafened",
    poisoned = "Poisoned", grappled = "Grappled", stunned = "Stunned", invisible = "Invisible",
}

local function post(id, data)
    msg.post(TABLE, id, data or {})
end

local function state(app)
    app.hud = app.hud or { minis = {}, order = {}, turn = nil }
    return app.hud
end

local function on_screen(a)
    return a and a[1] > 0.02 and a[1] < 0.98 and a[2] > 0.08 and a[2] < 0.86
end

-- A fight starts: every combatant gets a bar. party/foes as in the battle start beat;
-- sprite_of(foe, i) names a foe's mini picture.
function M.start(app, party, foes, sprite_of)
    local st = state(app)
    M.clear_nodes(app)   -- the last fight's bars and tags go with it
    st.minis, st.order, st.turn, st.zones = {}, {}, nil, {}
    for _, c in ipairs(party or {}) do
        st.minis[c.id] = { id = c.id, side = "party", hp = c.hp, max = c.hp_max, conds = {},
                           pic = require("game.ui.panels").mini(app.campaign and app.campaign:player(c.id), c.class),
                           name = app.names and app.names[c.id] }
    end
    for i, f in ipairs(foes or {}) do
        st.minis[f.id] = { id = f.id, side = "foe", hp = f.hp, max = f.hp_max, conds = {}, boss = f.boss,
                           pic = "mini_" .. (sprite_of and sprite_of(f, i) or "bandit"), name = f.name }
    end
    st.round = 1
    M.draw(app)
end

-- A new round (the newcomer playtest, October 16: the rounds were only in the log).
function M.round(app, r)
    local st = state(app)
    st.round = r
    M.draw_order(app)
end

-- Someone joins mid-fight (reinforcements).
function M.join(app, id, name, sprite, hp, max)
    local st = state(app)
    st.minis[id] = { id = id, side = "foe", hp = hp or 10, max = max or hp or 10, conds = {}, pic = "mini_" .. (sprite or "bandit"),
                     name = name }
    table.insert(st.order, { id = id, name = name, total = 0, side = "foes", late = true })
    M.draw(app)
end

-- Someone fighting on the party's side (the museum's Steam Mech, v2).
function M.ally(app, id, name, sprite, hp, max)
    local st = state(app)
    st.minis[id] = { id = id, side = "party", hp = hp or 10, max = max or hp or 10, conds = {}, pic = "mini_" .. (sprite or "bandit"),
                     name = name }
    M.draw(app)
end

function M.stop(app)
    local st = state(app)
    M.clear_nodes(app)   -- before the list goes, or its bars and tags stay on screen
    kit.unspot(st.order_spot)
    kit.unspot(st.boss_spot)
    st.order_spot, st.boss_spot = nil, nil
    st.minis, st.order, st.turn, st.round = {}, {}, nil, nil
    post("area_end", {})
    M.draw(app)
end

function M.set_hp(app, id, hp, max)
    local m = state(app).minis[id]
    if m and hp then
        m.hp = hp
        m.max = max or m.max
        M.refresh(app)
    end
end

function M.gone(app, id)
    local m = state(app).minis[id]
    if m then
        m.gone = true
        M.refresh(app)
        M.draw_order(app)
    end
end

function M.condition(app, id, name, conds, on)
    local m = state(app).minis[id]
    if not m then
        return
    end
    m.effects = m.effects or {}
    if on then
        local labels = {}
        for _, c in ipairs(conds or {}) do
            table.insert(labels, COND_NAMES[c] or util.capitalize(c))
        end
        -- An effect with no condition of its own (Burning, Targeted) shows by its name.
        if #labels == 0 and name then
            labels = { name }
        end
        m.effects[name or "?"] = table.concat(labels, ", ")
    else
        m.effects[name or "?"] = nil
    end
    M.draw(app)
end

-- The turn order, from the initiative step.
function M.initiative(app, order)
    local st = state(app)
    st.order = {}
    for _, o in ipairs(order or {}) do
        table.insert(st.order, { id = o.id, name = o.name, total = o.total, side = o.side, pc = o.pc })
    end
    M.draw_order(app)
end

function M.turn(app, id)
    local st = state(app)
    st.turn = id
    M.draw_order(app)
end

-- A spell's area, or a zone that stays (Web, Grease) until it ends.
function M.area(app, cells, color, zone)
    if not cells or #cells == 0 then
        return
    end
    local c = color or vmath.vector4(1, 0.7, 0.4, 1)
    post("area", { cells = cells, color = vmath.vector4(c.x, c.y, c.z, zone and 0.7 or 0.85), life = zone and 0 or 1.3,
                   stagger = zone and 0 or 0.015, zone = zone })
end

function M.zone_end(app, zone)
    post("area_end", { zone = zone })
end

-- Drawing ------------------------------------------------------------------------------------

function M.clear_nodes(app)
    local st = state(app)
    for _, m in pairs(st.minis) do
        if m.nodes then
            kit.remove(m.nodes)
        end
        m.nodes, m.n = nil, nil
    end
    if st.order_nodes then
        kit.remove(st.order_nodes)
        st.order_nodes = nil
    end
    st.boss_nodes = nil
end

-- (Re)create every node in the fx layer.
function M.draw(app)
    if not app.layers or not app.layers.fx then
        return
    end
    M.clear_nodes(app)
    local st = state(app)
    kit.use(app.layers.fx)
    for _, m in pairs(st.minis) do
        if not m.gone then
            local n = {}
            n.back = kit.box(0, 0, BAR_W + 2, BAR_H + 2, kit.rgba("#000000", 0.6), { round = false })
            n.fill = kit.box(0, 0, BAR_W, BAR_H, theme.green, { round = false })
            local label = m.boss and m.name or nil
            n.name = kit.text(0, 0, label and kit.ellipsize(label, "ui14", 260) or "", "ui14", theme.text,
                { pivot = gui.PIVOT_S })
            -- Condition tags: each condition once, short, and nudged apart in place() (A7).
            local cond, seen = {}, {}
            for _, v in pairs(m.effects or {}) do
                for part in string.gmatch(v, "[^,]+") do
                    part = (string.gsub(part, "^%s+", ""))
                    if part ~= "" and not seen[part] then
                        seen[part] = true
                        table.insert(cond, part)
                    end
                end
            end
            -- Unconscious, Paralyzed, Stunned and Petrified already mean Incapacitated: say it once.
            if seen.Incapacitated and (seen.Unconscious or seen.Paralyzed or seen.Stunned or seen.Petrified) then
                for i = #cond, 1, -1 do
                    if cond[i] == "Incapacitated" then
                        table.remove(cond, i)
                    end
                end
            end
            table.sort(cond)
            local ctext = table.concat(cond, ", ")
            if kit.width(ctext, "ui14") > 130 then
                ctext = string.gsub(ctext, "Incapacitated", "Incap.")      -- the long one, shortened first
            end
            ctext = kit.ellipsize(ctext, "ui14", 130)
            m.cond_w = ctext ~= "" and kit.width(ctext, "ui14") or 0
            n.cond = kit.text(0, 0, ctext, "ui14", theme.purple, { pivot = gui.PIVOT_N })
            m.n = n
            m.nodes = { n.back, n.fill, n.name, n.cond }
        end
    end
    M.draw_order(app)
    M.refresh(app)
    M.place(app)
end

function M.refresh(app)
    M.refresh_boss(app)
    for _, m in pairs(state(app).minis) do
        if m.n then
            local f = util.clamp((m.hp or 0) / math.max(1, m.max or 1), 0, 1)
            gui.set_size(m.n.fill, vmath.vector3(math.max(0.01, BAR_W * f), BAR_H, 0))
            local col
            if m.side == "foe" then
                col = f > 0.5 and theme.red or (f > 0.25 and theme.orange or kit.rgba("#8a2a20"))
            else
                col = f > 0.5 and theme.green or (f > 0.25 and theme.gold or theme.red)
            end
            gui.set_color(m.n.fill, col)
        end
    end
end

-- Every frame: follow the minis on screen.
function M.place(app)
    local an = app.anchors and app.anchors.minis or {}
    for id, m in pairs(state(app).minis) do
        if m.n then
            local a = an[id]
            -- HP bars only over the mat (A7): hidden when the camera is on the room or the dice.
            local show = on_screen(a) and not m.gone and (app.camera_index == nil or app.camera_index == 2)
            -- ...and not over the open log, where they'd sit on its text.
            if show and app.log_open and a[1] * kit.W < 24 + 520 + 20 and a[2] * H > 60 and a[2] * H < 770 then
                show = false
            end
            for _, node in ipairs(m.nodes) do
                gui.set_enabled(node, show)
            end
            if show then
                local x, y = a[1] * kit.W, a[2] * H - 14
                gui.set_position(m.n.back, vmath.vector3(x - BAR_W / 2 - 1, H - (y - 1), 0))
                gui.set_position(m.n.fill, vmath.vector3(x - BAR_W / 2, H - y, 0))
                gui.set_position(m.n.name, vmath.vector3(x, H - (y - 3), 0))
                m.cond_at = { x, y + BAR_H + 3 }
            end
        end
    end
    -- Condition tags never overlap: a tag that would sit on another moves down a line.
    local tags = {}
    for _, m in pairs(state(app).minis) do
        if m.n and m.cond_at and (m.cond_w or 0) > 0 and gui.is_enabled(m.n.cond) then
            table.insert(tags, m)
        end
    end
    table.sort(tags, function(a, b)
        if a.cond_at[2] ~= b.cond_at[2] then
            return a.cond_at[2] < b.cond_at[2]
        end
        return a.cond_at[1] < b.cond_at[1]
    end)
    local placed = {}
    for _, m in ipairs(tags) do
        local x, y, w = m.cond_at[1], m.cond_at[2], m.cond_w + 6
        local moved = true
        local guard = 0
        while moved and guard < 6 do
            moved, guard = false, guard + 1
            for _, r in ipairs(placed) do
                if math.abs(r[1] - x) < (r[3] + w) / 2 and math.abs(r[2] - y) < 16 then
                    y = r[2] + 16
                    moved = true
                end
            end
        end
        table.insert(placed, { x, y, w })
        gui.set_position(m.n.cond, vmath.vector3(x, H - y, 0))
    end
end

-- The boss's health, with numbers, under the turn order (the newcomer playtest, October 16: "a
-- tiny red sliver; I can't read how close we are to winning").
local BOSS_W = 220

local function boss_of(st)
    for _, m in pairs(st.minis) do
        if m.boss and m.side == "foe" then
            return m
        end
    end
    return nil
end

function M.refresh_boss(app)
    local st = state(app)
    local b = st.boss_nodes
    local m = boss_of(st)
    if not b or not m then
        return
    end
    local f = util.clamp((m.hp or 0) / math.max(1, m.max or 1), 0, 1)
    pcall(gui.set_size, b.fill, vmath.vector3(math.max(0.01, BOSS_W * f), 8, 0))
    pcall(gui.set_text, b.text, util.int(math.max(0, m.hp or 0)) .. " / " .. util.int(m.max or 0))
end

-- A hover card's spot that stays put across redraws: made once in the fx layer, then moved.
function M.keep_spot(app, spot, x, y, w, h, title, text, dnd)
    if spot and spot.layer == app.layers.fx then
        spot.rect = { x, y, w, h }
        return spot
    end
    kit.unspot(spot)
    return gloss.card_spot(x, y, w, h, title, text, dnd)
end

-- The turn order along the top: a small mini per combatant, their initiative, whose turn it is;
-- the round at its left, and the boss's health under it.
function M.draw_order(app)
    if not app.layers or not app.layers.fx then
        return
    end
    local st = state(app)
    if st.order_nodes then
        kit.remove(st.order_nodes)
    end
    st.order_nodes = {}
    st.boss_nodes = nil
    if #st.order == 0 then
        return
    end
    kit.use(app.layers.fx)
    local n = #st.order
    local step = math.min(46, math.floor((INIT_X1 - INIT_X0) / n))
    local x0 = math.floor((INIT_X0 + INIT_X1) / 2 - step * n / 2)
    local nodes = st.order_nodes
    local box = kit.box(x0 - 8 - 62, INIT_Y, step * n + 16 + 62, 60, kit.rgba("#140e0b", 0.7), { radius = 8 })
    table.insert(nodes, box)
    table.insert(nodes, kit.text(x0 - 39, INIT_Y + 8, "ROUND", "ui14", theme.faint, { pivot = gui.PIVOT_N }))
    table.insert(nodes, kit.text(x0 - 39, INIT_Y + 26, util.int(st.round or 1), "ui22b", theme.gold, { pivot = gui.PIVOT_N }))
    table.insert(nodes, kit.box(x0 - 8, INIT_Y + 8, 1, 44, kit.rgba("#ffffff", 0.15), { round = false }))
    table.insert(nodes, kit.text(x0 + step * n / 2, INIT_Y + 64, "Turn order: left goes first", "ui14", theme.faint,
        { pivot = gui.PIVOT_N }))
    -- Their hover cards outlive the redraws (a turn redraws the strip every second or two): one spot
    -- each, moved, rather than a new one that would drop the card mid-read (the re-test, October 16).
    st.order_spot = M.keep_spot(app, st.order_spot, x0 - 8 - 62, INIT_Y, step * n + 16 + 62, 60 + 22, "Turn order",
        "Everyone in the fight, in the order they act. When the fight started, each rolled a d20 (the number "
        .. "under them); highest goes first. The lit one is acting now. Once everyone has gone, it's the next round.",
        "Initiative")
    local boss = boss_of(st)
    if not (boss and not boss.gone) then
        kit.unspot(st.boss_spot)
        st.boss_spot = nil
    end
    if boss and not boss.gone then
        local bx = x0 + step * n / 2 - BOSS_W / 2
        local by = INIT_Y + 94
        st.boss_spot = M.keep_spot(app, st.boss_spot, bx - 10, by - 4, BOSS_W + 20, 40, "The boss's health",
            "How much the boss can still take before it's beaten: what's left, out of what it started with. "
            .. "Every hit takes some off.", "Hit points (HP)")
        local name = kit.ellipsize(boss.name or "The boss", "ui14", BOSS_W)
        table.insert(nodes, kit.box(bx - 10, by - 4, BOSS_W + 20, 40, kit.rgba("#140e0b", 0.7), { radius = 8 }))
        table.insert(nodes, kit.text(bx, by, name, "ui14", theme.text))
        local text = kit.text(bx + BOSS_W, by, "", "ui14", theme.gold, { pivot = gui.PIVOT_NE })
        table.insert(nodes, text)
        table.insert(nodes, kit.box(bx, by + 22, BOSS_W, 8, kit.rgba("#000000", 0.5), { round = false }))
        local fill = kit.box(bx, by + 22, BOSS_W, 8, theme.red, { round = false })
        table.insert(nodes, fill)
        st.boss_nodes = { fill = fill, text = text }
        M.refresh_boss(app)
    end
    for i, o in ipairs(st.order) do
        local m = st.minis[o.id]
        local x = x0 + (i - 1) * step
        local now = st.turn == o.id
        if now then
            table.insert(nodes, kit.box(x - 2, INIT_Y + 2, step - 2, 56, theme.gold, { radius = 6 }))
        end
        local gone = m and m.gone
        local pic = m and m.pic or "mini_bandit"
        table.insert(nodes, kit.picture(x + (step - 34) / 2, INIT_Y + 4, 30, 37, pic,
            kit.rgba("#ffffff", gone and 0.25 or 1)))
        table.insert(nodes, kit.text(x + step / 2 - 2, INIT_Y + 42, util.int(o.total or 0), "ui14",
            now and theme.bg or (o.side == "party" and theme.teal or theme.dim), { pivot = gui.PIVOT_N }))
    end
end

function M.update(app, dt)
    M.place(app)
end

return M
